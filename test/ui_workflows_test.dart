import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:agenda/core/widgets/app_lock.dart';
import 'package:agenda/core/theme/app_theme.dart';
import 'package:agenda/core/security/secret_vault.dart';

import 'dart:convert' as convert;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:agenda/main.dart';
import 'package:agenda/core/database/database_helper.dart';
import 'package:agenda/core/utils/agenda_localizations.dart';
import 'package:agenda/core/widgets/record_table_screen.dart';
import 'package:agenda/features/daily_schedule/data/models/session_model.dart';
import 'package:agenda/features/daily_schedule/data/models/hearing_suggestion.dart';
import 'package:agenda/features/daily_schedule/presentation/screens/add_edit_session_screen.dart';
import 'package:agenda/features/daily_schedule/presentation/widgets/previous_hearing_lookup.dart';
import 'package:agenda/features/daily_schedule/data/repositories/session_repository.dart';
import 'package:agenda/features/daily_schedule/data/repositories/schedule_export.dart';
import 'package:agenda/features/daily_schedule/presentation/providers/session_provider.dart';

class PreviewRepository extends SessionRepository {
  final List<Session> data;
  PreviewRepository(this.data);
  @override
  Future<List<Session>> getSessionsForDate(DateTime date) async => data;
  @override
  Future<List<Session>> searchSessions(String query) async => data;
  @override
  Future<List<HearingSuggestion>> findPreviousHearings(
    String number,
    String year,
  ) async => HearingSuggestion.group(data);
}

Session previewSession() => Session(
  id: 1,
  courtName: 'محكمة القاهرة',
  circuit: 'الدائرة ٥ مدني',
  caseNumber: '1234',
  caseYear: 2026,
  clientName: 'موكل تجريبي',
  clientCapacity: 'مدعي',
  opponentName: 'خصم تجريبي',
  opponentCapacity: '',
  previousSession: '١ / ١٠ / ٢٠٢٦ — تأجيل للمستندات',
  decision: 'تقديم المستندات والمذكرات',
  notes: 'بيانات تجريبية لفحص العرض',
  sessionDate: DateTime(2026, 10, 24),
);

Widget host(Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  locale: const Locale('ar', 'EG'),
  supportedLocales: const [Locale('ar', 'EG')],
  localizationsDelegates: const [
    AgendaLocalizationsDelegate(),
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: AppTheme.lightTheme,
  home: child,
);

Future<void> waitFor(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 500; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    if (condition()) {
      for (var j = 0; j < 50; j++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      return;
    }
  }
  fail('UI did not finish the requested operation');
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    for (final name in ['Cairo', 'Amiri', 'MaterialIcons']) {
      final loader = FontLoader(name);
      loader.addFont(
        rootBundle.load(
          name == 'Cairo'
              ? 'assets/fonts/Cairo.ttf'
              : name == 'Amiri'
              ? 'assets/fonts/Amiri-Regular.ttf'
              : 'fonts/MaterialIcons-Regular.otf',
        ),
      );
      await loader.load();
    }
  });

  for (final size in [
    const Size(390, 844),
    const Size(360, 640),
    const Size(844, 390),
  ]) {
    testWidgets(
      'Judicial table remains readable at ${size.width} x ${size.height}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final provider = SessionProvider(
          repository: PreviewRepository([previewSession()]),
          autoLoad: false,
        );
        provider.setSelectedDate(DateTime(2026, 10, 24));
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: ChangeNotifierProvider.value(
              value: provider,
              child: const MyApp(enableLock: false),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('المحكمة / الدائرة', skipOffstage: false), findsOneWidget);
        expect(find.text('الموكل / الخصم', skipOffstage: false), findsOneWidget);
        expect(find.text('القرار / السابقة', skipOffstage: false), findsOneWidget);
        expect(find.text('رقم ١٢٣٤ لسنة ٢٠٢٦', skipOffstage: false), findsOneWidget);
        expect(tester.takeException(), isNull);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/review/table-${size.width.toInt()}x${size.height.toInt()}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.pumpWidget(const SizedBox());
        provider.dispose();
      },
    );
  }

  testWidgets(
    'Assisted entry remains readable and retains selection while scrolling on a phone',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = PreviewRepository([previewSession()]);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: host(
            AddEditSessionScreen(
              initialDate: DateTime(2026, 10, 25),
              repository: repository,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final number = find.byType(TextFormField).at(2);
      await tester.enterText(number, '١٢٣٤');
      await tester.pumpAndSettle();
      final outerScroll = find
          .descendant(of: find.byType(Form), matching: find.byType(Scrollable))
          .first;
      await tester.scrollUntilVisible(
        find.text('استرجاع البيانات السابقة', skipOffstage: false),
        50,
        scrollable: outerScroll,
      );
      await tester.tap(find.text('استرجاع البيانات السابقة', skipOffstage: false));
      await tester.pumpAndSettle();
      await tester.tap(find.text('استخدام هذه البيانات', skipOffstage: false));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('حفظ الجلسة'),
        400,
        scrollable: outerScroll,
      );
      await tester.pumpAndSettle();
      // The helper is now outside the viewport and must retain its selected source.
      await tester.scrollUntilVisible(
        find.byType(PreviousHearingLookup),
        -400,
        scrollable: outerScroll,
      );
      await tester.ensureVisible(find.byType(PreviousHearingLookup));
      await tester.pumpAndSettle();
      expect(find.byType(Card).last, findsOneWidget);
      expect(find.text('تقديم المستندات والمذكرات'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/review/assisted-entry-390x844.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    },
  );

  testWidgets('Calendar renders Arabic digits and parses Arabic date input', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDatePicker(
                context: context,
                initialDate: DateTime(2026, 10, 24),
                firstDate: DateTime(1900),
                lastDate: DateTime(2200),
              ),
              child: const Text('calendar'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('calendar'));
    await tester.pumpAndSettle();
    expect(find.text('٢٤'), findsWidgets);
    expect(find.textContaining('٢٠٢٦'), findsWidgets);
    final localizations = MaterialLocalizations.of(
      tester.element(find.byType(DatePickerDialog)),
    );
    expect(
      localizations.parseCompactDate('٢٥ / ١٠ / ٢٠٢٦'),
      DateTime(2026, 10, 25),
    );
    expect(localizations.formatDecimal(1234), '١٢٣٤');
  });

  testWidgets(
    'Admin work supports validated create, edit, completion, search and delete',
    (tester) async {
      final db = DatabaseHelper.forTesting(inMemoryDatabasePath);
      await tester.runAsync(() async {
        await db.database;
      });
      await tester.pumpWidget(
        host(
          RecordTableScreen(
            database: db,
            table: 'admin_notes',
            title: 'الأعمال الإدارية',
            singular: 'عمل إداري',
            empty: 'لا توجد أعمال',
            completion: true,
            fields: const [
              RecordField('title', 'العنوان', required: true),
              RecordField('content', 'التفاصيل', required: true),
              RecordField(
                'note_date',
                'موعد العمل',
                date: true,
                required: true,
              ),
            ],
            headers: const ['التفاصيل', 'الموعد', 'الحالة'],
            columns: const [
              ['title', 'content'],
              ['note_date'],
              ['is_completed'],
            ],
          ),
        ),
      );
      await waitFor(
        tester,
        () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
      );
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();
      expect(find.text('هذا الحقل مطلوب'), findsNWidgets(2));
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'مهمة ١٢٣',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'تفاصيل العمل',
      );
      await tester.tap(find.text('حفظ'));
      await waitFor(
        tester,
        () =>
            find.byType(RecordEditorDialog).evaluate().isEmpty &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty,
      );
      debugDumpApp();
      expect(find.text('مهمة ١٢٣', skipOffstage: false), findsOneWidget);
      final original = (await tester.runAsync(
        () => db.queryAll('admin_notes'),
      ))!.single;
      expect(original['title'], 'مهمة 123');
      await tester.tap(find.text('مهمة ١٢٣', skipOffstage: false));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'مهمة ٤٥٦',
      );
      await tester.tap(find.text('حفظ'));
      await waitFor(
        tester,
        () =>
            find.byType(RecordEditorDialog).evaluate().isEmpty &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty,
      );
      await tester.tap(find.byType(Checkbox));
      await waitFor(
        tester,
        () =>
            find.byType(LinearProgressIndicator).evaluate().isEmpty &&
            tester.widget<Checkbox>(find.byType(Checkbox)).value == true,
      );
      final updated = (await tester.runAsync(() => db.queryAll('admin_notes')))!
          .single;
      expect(updated['created_at'], original['created_at']);
      expect(updated['is_completed'], 1);
      await tester.enterText(find.byType(TextField).first, '٤٥٦');
      await tester.pump(const Duration(milliseconds: 300));
      await waitFor(
        tester,
        () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
      );
      expect(find.text('مهمة ٤٥٦', skipOffstage: false), findsOneWidget);
      await tester.tap(find.byTooltip('حذف'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف'));
      await waitFor(
        tester,
        () =>
            find.byType(AlertDialog).evaluate().isEmpty &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty &&
            find.text('مهمة ٤٥٦').evaluate().isEmpty,
      );
      expect(await tester.runAsync(() => db.queryAll('admin_notes')), isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(db.close);
    },
  );

  testWidgets(
    'App lock hides the navigator until unlocked and locks after backgrounding',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await tester.runAsync(() => PasswordCipher.setLock('1234'));
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => AppLock(child: child!),
          home: const Scaffold(body: Text('private-content')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('private-content'), findsNothing);
      await tester.enterText(find.byType(TextField), 'wrong-password');
      await tester.tap(find.text('فتح الأجندة'));
      await waitFor(
        tester,
        () => find.text('كلمة المرور غير صحيحة.').evaluate().isNotEmpty,
      );
      expect(find.text('private-content'), findsNothing);
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('فتح الأجندة'));
      await waitFor(
        tester,
        () => find.text('private-content').evaluate().isNotEmpty,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('private-content'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('private-content'), findsNothing);
      expect(find.text('فتح الأجندة'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => PasswordCipher.removeLock('1234'),
      );
    },
  );

  test('PDF and calendar exports use Arabic presentation and valid calendar folding', () async {
    final sample = previewSession();
    final bytes = await ScheduleExport.pdf([sample], sample.sessionDate);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    final file = File('build/review/schedule.pdf');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    final calendar = ScheduleExport.calendar([sample]);
    final content = convert.utf8.decode(calendar);
    expect(content, contains('DTSTART;VALUE=DATE:20261024'));
    expect(content, contains('TRIGGER:-P1D'));
    expect(content.replaceAll('\r\n ', ''), contains('جلسة ١٢٣٤ لسنة ٢٠٢٦'));
    for (final line in content.split('\r\n')) {
      expect(
        Uint8List.fromList(convert.utf8.encode(line)).length,
        lessThanOrEqualTo(75),
      );
    }
  });
}
