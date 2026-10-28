import 'dart:async';

import 'package:agenda/core/database/database_helper.dart';
import 'package:agenda/core/utils/agenda_localizations.dart';
import 'package:agenda/core/utils/arabic_format.dart';
import 'package:agenda/features/daily_schedule/data/models/hearing_suggestion.dart';
import 'package:agenda/features/daily_schedule/data/models/session_model.dart';
import 'package:agenda/features/daily_schedule/data/repositories/session_repository.dart';
import 'package:agenda/features/daily_schedule/presentation/providers/session_provider.dart';
import 'package:agenda/features/daily_schedule/presentation/screens/add_edit_session_screen.dart';
import 'package:agenda/features/daily_schedule/presentation/widgets/previous_hearing_lookup.dart';
import 'package:agenda/features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Session hearing({
  String number = '123',
  int year = 2026,
  String court = 'محكمة القاهرة',
  String circuit = 'دائرة 5',
  String client = 'أحمد',
  String opponent = 'محمد',
  int day = 10,
  String decision = '',
}) => Session(
  courtName: court,
  circuit: circuit,
  caseNumber: number,
  caseYear: year,
  clientName: client,
  clientCapacity: '',
  opponentName: opponent,
  opponentCapacity: '',
  previousSession: '',
  decision: decision,
  notes: '',
  sessionDate: DateTime(2026, 10, day),
);

class ControlledLookup extends SessionRepository {
  final requests = <Completer<List<HearingSuggestion>>>[];
  @override
  Future<List<HearingSuggestion>> findPreviousHearings(
    String number,
    String year,
  ) {
    final pending = Completer<List<HearingSuggestion>>();
    requests.add(pending);
    return pending.future;
  }
}

Widget host(Widget child) => MaterialApp(
  locale: const Locale('ar', 'EG'),
  supportedLocales: const [Locale('ar', 'EG')],
  localizationsDelegates: const [
    AgendaLocalizationsDelegate(),
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: child,
);

Finder field(String label) {
  if (label == 'رقم الدعوى') return find.byType(TextFormField).at(2);
  if (label == 'السنة') return find.byType(TextFormField).at(3);
  if (label == 'اسم المحكمة') return find.byType(TextFormField).at(0);
  if (label == 'الدائرة') return find.byType(TextFormField).at(1);
  if (label == 'اسم الموكل') return find.byType(TextFormField).at(4);
  if (label == 'اسم الخصم') return find.byType(TextFormField).at(6);
  if (label == 'الجلسة السابقة') return find.byType(TextFormField).at(8);
  if (label == 'القرار الحالي') return find.byType(TextFormField).at(9);
  if (label == 'ملاحظات') return find.byType(TextFormField).at(10);
  return find.byType(TextFormField).first;
}

String value(WidgetTester tester, String label) =>
    tester.widget<TextFormField>(field(label)).controller!.text;

Future<void> waitFor(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 200; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 10));
    if (done()) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('Operation did not complete');
}

Future<void> openForm(
  WidgetTester tester,
  SessionRepository repository, {
  SessionRepository? lookup,
  Session? editing,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 2400);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => SessionProvider(repository: repository, autoLoad: false),
      child: host(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddEditSessionScreen(
                    initialDate: DateTime(2026, 10, 24),
                    session: editing,
                    repository: lookup ?? repository,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> lookup(
  WidgetTester tester, {
  String number = '١٢٣',
  String year = '٢٠٢٦',
}) async {
  await tester.enterText(field('رقم الدعوى'), number);
  await tester.enterText(field('السنة'), year);
  await tester.tap(find.byKey(const ValueKey('retrieve-hearing')));
  await waitFor(
    tester,
    () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseHelper db;
  late SessionRepository repository;
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    FlutterSecureStorage.setMockInitialValues({});
  });
  setUp(() async {
    db = DatabaseHelper.forTesting(inMemoryDatabasePath);
    repository = SessionRepository(database: db);
    await db.database;
  });
  tearDown(() async => db.close());

  test('judicial year and previously saved capacities survive storage and lookup', () async {
    final original = hearing(number: '85').copyWith(
      caseYear: '70ق', clientCapacity: 'مستأنف', opponentCapacity: 'مستأنف ضده');
    final id = await repository.insertSession(original);
    expect((await repository.getSession(id))!.caseYear, '70ق');
    final results = await repository.findPreviousHearings('٨٥', '٧٠ق');
    expect(results.single.latest.id, id);
    expect(await repository.capacities(), containsAll(['مستأنف', 'مستأنف ضده']));
  });

  testWidgets('sections collapse without losing input and saved capacities are suggested', (tester) async {
    await tester.runAsync(() => repository.insertSession(hearing().copyWith(clientCapacity: 'مستأنف')));
    await openForm(tester, repository);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    await tester.enterText(field('اسم المحكمة'), 'محكمة');
    await tester.tap(find.text('بيانات المحكمة والدعوى').first);
    await tester.pumpAndSettle();
    expect(find.text('محكمة'), findsNothing);
    await tester.tap(find.text('بيانات المحكمة والدعوى').first);
    await tester.pumpAndSettle();
    expect(value(tester, 'اسم المحكمة'), 'محكمة');
    await tester.enterText(find.byType(TextFormField).at(5), 'مست');
    await tester.pumpAndSettle();
    expect(find.text('مستأنف'), findsOneWidget);
    await tester.tap(find.text('مستأنف'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(find.byType(TextFormField).at(5)).controller!.text, 'مستأنف');
  });

  test('D E F: exact normalized number/year and distinct court, circuit and parties', () async {
    await repository.insertSession(hearing(number: ' \t١٢٣\n', day: 1));
    await repository.insertSession(hearing(number: '۱۲۳', day: 2));
    await repository.insertSession(hearing(number: '123', day: 3));
    await repository.insertSession(hearing(number: '1234'));
    await repository.insertSession(hearing(number: 'x123'));
    await repository.insertSession(hearing(year: 2025));
    await repository.insertSession(hearing(court: 'محكمة الجيزة'));
    await repository.insertSession(hearing(circuit: 'دائرة 6'));
    await repository.insertSession(hearing(client: 'عمرو'));
    await repository.insertSession(hearing(opponent: 'محمود'));
    for (final number in ['123', ' ١٢٣ ', '۱۲۳']) {
      for (final year in ['2026', ' ٢٠٢٦ ', '۲۰۲۶']) {
        final suggestions = await repository.findPreviousHearings(number, year);
        expect(suggestions.length, 5);
        expect(suggestions.expand((s) => s.hearings).length, 7);
        expect(
          suggestions
              .expand((s) => s.hearings)
              .every((h) => h.caseYear == 2026),
          isTrue,
        );
        expect(
          suggestions
              .singleWhere((s) => s.hearings.length == 3)
              .latest
              .sessionDate
              .day,
          3,
        );
      }
    }
    expect(await repository.findPreviousHearings('123', '2024'), isEmpty);
    expect(await repository.findPreviousHearings('123', ''), isEmpty);
    expect(
      await repository.findPreviousHearings("123' OR 1=1 --", '2026'),
      isEmpty,
    );
    expect(await repository.findPreviousHearings('12%', '2026'), isEmpty);
  });

  test('B C J: latest earlier non-empty decision, excluding same-day and future hearings', () async {
    for (final record in [
      hearing(day: 1, decision: 'القرار القديم'),
      hearing(day: 10, decision: 'قرار آخر مسجل'),
      hearing(day: 20, decision: '  '),
      hearing(day: 24, decision: 'نفس اليوم'),
      hearing(day: 30, decision: 'قرار لاحق'),
    ]) {
      await repository.insertSession(record);
    }
    final candidate = (await repository.findPreviousHearings(
      '123',
      '2026',
    )).single;
    expect(
      candidate.lastDecisionBefore(DateTime(2026, 10, 24))!.decision,
      'قرار آخر مسجل',
    );
    expect(
      candidate.lastDecisionBefore(DateTime(2026, 10, 24))!.sessionDate,
      DateTime(2026, 10, 10),
    );
    expect(
      candidate.lastDecisionBefore(DateTime(2026, 10, 10))!.decision,
      'القرار القديم',
    );
    expect(candidate.lastDecisionBefore(DateTime(2026, 10, 1)), isNull);
    expect(
      candidate.lastDecisionBefore(DateTime(2026, 10, 31))!.decision,
      'قرار لاحق',
    );
  });

  testWidgets(
    'A B I: explicit copy, separate decision and independent save after edits',
    (tester) async {
      late int id;
      await tester.runAsync(() async {
        id = await repository.insertSession(
          hearing(decision: 'تقديم أصل المستندات'),
        );
      });
      final before = await tester.runAsync(
        () async => (await repository.getSession(id))!.toMap(),
      );
      await openForm(tester, repository);
      await lookup(tester);
      expect(value(tester, 'اسم المحكمة'), isEmpty);
      await tester.tap(find.text('استخدام هذه البيانات'));
      await tester.pumpAndSettle();
      expect(value(tester, 'اسم المحكمة'), 'محكمة القاهرة');
      expect(value(tester, 'الدائرة'), 'دائرة ٥');
      expect(value(tester, 'اسم الموكل'), 'أحمد');
      expect(value(tester, 'اسم الخصم'), 'محمد');
      expect(find.text('تقديم أصل المستندات'), findsOneWidget);
      expect(
        find.text('بتاريخ ${ArabicFormat.date(DateTime(2026, 10, 10))}'),
        findsOneWidget,
      );
      expect(value(tester, 'القرار الحالي'), isEmpty);
      expect(value(tester, 'الجلسة السابقة'), isEmpty);
      await tester.enterText(field('اسم الموكل'), 'موكل معدل');
      await tester.enterText(field('القرار الحالي'), 'قرار الجلسة الجديدة');
      await tester.tap(find.text('حفظ الجلسة'));
      await waitFor(
        tester,
        () => find.byType(AddEditSessionScreen).evaluate().isEmpty,
      );
      await tester.runAsync(() async {
        expect((await repository.getSession(id))!.toMap(), before);
        final records = await db.queryAll('sessions');
        expect(records.length, 2);
        final added = records.singleWhere((row) => row['id'] != id);
        expect(added['client_name'], 'موكل معدل');
        expect(added['decision'], 'قرار الجلسة الجديدة');
        expect(added['session_date'], startsWith('2026-10-24'));
      });
    },
  );

  testWidgets(
    'C H: typed fields survive selection; no prior decision still permits saving',
    (tester) async {
      await tester.runAsync(() => repository.insertSession(hearing()));
      await openForm(tester, repository);
      await tester.enterText(field('اسم المحكمة'), 'محكمة مكتوبة يدويًا');
      await tester.enterText(field('القرار الحالي'), 'قرار جديد مكتوب');
      await lookup(tester);
      await tester.tap(find.text('استخدام هذه البيانات'));
      await tester.pumpAndSettle();
      expect(value(tester, 'اسم المحكمة'), 'محكمة مكتوبة يدويًا');
      expect(value(tester, 'القرار الحالي'), 'قرار جديد مكتوب');
      expect(find.text('لا يوجد قرار سابق مسجل'), findsOneWidget);
      await tester.tap(find.text('حفظ الجلسة'));
      await waitFor(
        tester,
        () => find.byType(AddEditSessionScreen).evaluate().isEmpty,
      );
      await tester.runAsync(
        () async => expect((await db.queryAll('sessions')).length, 2),
      );
    },
  );

  testWidgets('E: different courts require explicit candidate selection', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await repository.insertSession(hearing());
      await repository.insertSession(
        hearing(court: 'محكمة الجيزة', circuit: 'دائرة 7', day: 11),
      );
    });
    await openForm(tester, repository);
    await lookup(tester);
    expect(
      find.text('توجد ٢ نتائج مختلفة — اختر البيانات المناسبة'),
      findsOneWidget,
    );
    expect(value(tester, 'اسم المحكمة'), isEmpty);
    expect(
      find.text('المحكمة: محكمة الجيزة — الدائرة: دائرة ٧'),
      findsOneWidget,
    );
    await tester.tap(find.text('استخدام هذه البيانات').first);
    await tester.pumpAndSettle();
    expect(value(tester, 'اسم المحكمة'), 'محكمة الجيزة');
    expect(value(tester, 'الدائرة'), 'دائرة ٧');
  });

  testWidgets(
    'G: changed number/year invalidate results and ignore older async responses',
    (tester) async {
      final controlled = ControlledLookup();
      await openForm(tester, repository, lookup: controlled);
      await tester.enterText(field('رقم الدعوى'), '١٢٣');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('retrieve-hearing')));
      await tester.pump();
      await tester.enterText(field('رقم الدعوى'), '٤٥٦');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('retrieve-hearing')));
      controlled.requests[1].complete(
        HearingSuggestion.group([hearing(number: '456', court: 'نتيجة حديثة')]),
      );
      await tester.pumpAndSettle();
      controlled.requests[0].complete(
        HearingSuggestion.group([hearing(court: 'نتيجة قديمة')]),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('نتيجة حديثة'), findsOneWidget);
      expect(find.textContaining('نتيجة قديمة'), findsNothing);
      await tester.tap(find.text('استخدام هذه البيانات'));
      await tester.pumpAndSettle();
      await tester.enterText(field('السنة'), '٢٠٢٥');
      await tester.pumpAndSettle();
      expect(find.text('مصدر البيانات المختار'), findsNothing);
      expect(find.text('لا يوجد قرار سابق مسجل'), findsNothing);
      expect(value(tester, 'اسم المحكمة'), 'نتيجة حديثة');
      await tester.tap(find.byKey(const ValueKey('retrieve-hearing')));
      await tester.pump();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      controlled.requests.last.completeError(StateError('late failure'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Empty results and errors allow manual entry and saving', (
    tester,
  ) async {
    final controlled = ControlledLookup();
    await openForm(tester, repository, lookup: controlled);
    await tester.enterText(field('رقم الدعوى'), '٩٩٩');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('retrieve-hearing')));
    controlled.requests.single.complete([]);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('لا توجد جلسات محفوظة بنفس الرقم والسنة'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('retrieve-hearing')));
    controlled.requests.last.completeError(StateError('lookup failed'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('تعذر استرجاع البيانات السابقة'),
      findsOneWidget,
    );
    for (final label in ['اسم المحكمة', 'الدائرة', 'اسم الموكل', 'اسم الخصم']) {
      await tester.enterText(field(label), 'يدوي');
    }
    await tester.tap(find.text('حفظ الجلسة'));
    await waitFor(
      tester,
      () => find.byType(AddEditSessionScreen).evaluate().isEmpty,
    );
    await tester.runAsync(
      () async =>
          expect((await db.queryAll('sessions')).single['case_number'], '999'),
    );
  });

  testWidgets(
    'J: changing the form date recalculates previous decision without another lookup',
    (tester) async {
      await tester.runAsync(() async {
        await repository.insertSession(hearing(day: 10, decision: 'قرار سابق'));
        await repository.insertSession(hearing(day: 20));
        await repository.insertSession(hearing(day: 30, decision: 'قرار لاحق'));
      });
      await openForm(tester, repository);
      await lookup(tester);
      await tester.tap(find.text('استخدام هذه البيانات'));
      await tester.pumpAndSettle();
      expect(find.text('قرار سابق'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('hearing-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('١').last);
      await tester.tap(find.text('حسنًا'));
      await tester.pumpAndSettle();
      expect(find.text('لا يوجد قرار سابق مسجل'), findsOneWidget);
      expect(find.text('قرار لاحق'), findsNothing);
      expect(value(tester, 'القرار الحالي'), isEmpty);
    },
  );

  testWidgets('Suggestions only appear for new hearings', (tester) async {
    await openForm(tester, repository, editing: hearing().copyWith(id: 1));
    expect(find.byType(PreviousHearingLookup), findsNothing);
    expect(find.byTooltip('تأجيل مع حفظ الجلسة السابقة'), findsOneWidget);
  });

  testWidgets(
    'K: settings reaches all existing personal fields without changing data',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 2400);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final personal = {
        'name': 'محامي مسجل',
        'home_address': 'عنوان المنزل',
        'office_address': 'عنوان المكتب',
        'home_tel': '0212345678',
        'office_tel': '0312345678',
        'mobile': '01012345678',
        'id_card_no': '12345678901234',
        'passport_no': '12345',
        'car_license_no': '54321',
        'driving_license_no': '56789',
        'bank_account_no': '98765',
        'credit_card_no': '45678',
        'email': 'test@example.com',
        'updated_at': DateTime(2026).toIso8601String(),
      };
      await tester.runAsync(() => db.insert('personal_info', personal));
      final before = await tester.runAsync(() => db.queryAll('personal_info'));
      await tester.pumpWidget(host(SettingsScreen(database: db)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('البيانات الشخصية'));
      await waitFor(tester, () => find.byType(TextFormField).evaluate().isNotEmpty);
      expect(find.text('محامي مسجل'), findsOneWidget);
      expect(find.text('١٢٣٤٥'), findsOneWidget);
      expect(find.text('٩٨٧٦٥'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(13));
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حماية التطبيق'));
      await tester.pumpAndSettle();
      expect(find.text('تفعيل أو تغيير كلمة المرور'), findsOneWidget);
      expect(find.text('حفظ نسخة احتياطية'), findsNothing);
      await tester.tap(find.byTooltip('رجوع'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('النسخ الاحتياطي والاستعادة'));
      await tester.pumpAndSettle();
      expect(find.text('حفظ نسخة احتياطية'), findsOneWidget);
      expect(find.text('استعادة نسخة احتياطية'), findsOneWidget);
      expect(find.text('تفعيل أو تغيير كلمة المرور'), findsNothing);
      await tester.runAsync(
        () async => expect(await db.queryAll('personal_info'), before),
      );
    },
  );
}
