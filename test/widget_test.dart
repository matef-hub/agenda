import 'package:agenda/core/database/database_helper.dart';
import 'package:agenda/core/utils/arabic_format.dart';
import 'package:agenda/features/daily_schedule/data/repositories/session_repository.dart';
// Tests for the judicial agenda application.
//
// These tests verify the actual application features, not the Flutter
// counter template that was previously here.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:agenda/main.dart';
import 'package:agenda/core/utils/date_utils.dart';
import 'package:agenda/features/daily_schedule/data/models/session_model.dart';
import 'package:agenda/features/daily_schedule/presentation/providers/session_provider.dart';

void main() {
  late DatabaseHelper helper;
  late SessionProvider testProvider;
  setUp(() async {
    helper = DatabaseHelper.forTesting(inMemoryDatabasePath);
    testProvider = SessionProvider(
      repository: SessionRepository(database: helper),
      autoLoad: false,
    );
    await testProvider.loadSessions();
  });
  tearDown(() async {
    await helper.close();
  });

  // Initialize sqflite_ffi for desktop/test environments.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // -------------------------------------------------------------------------
  // 1. MyApp launches successfully
  // -------------------------------------------------------------------------
  group('MyApp launch', () {
    testWidgets('MyApp renders without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => testProvider)],
          child: const MyApp(enableLock: false),
        ),
      );
      // Give time for async init (database, provider).
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // The app should render the bottom navigation bar.
      expect(find.byType(ChoiceChip), findsNWidgets(5));
    });

    testWidgets('MyApp has correct title', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => testProvider)],
          child: const MyApp(enableLock: false),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.title, 'الأجندة القضائية');
    });
  });

  // -------------------------------------------------------------------------
  // 2. Daily agenda screen renders in Arabic
  // -------------------------------------------------------------------------
  group('Daily agenda screen', () {
    testWidgets('renders Arabic UI elements', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => testProvider)],
          child: const MyApp(enableLock: false),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // The daily schedule label should appear in the navigation bar.
      expect(find.text('الجلسات اليومية'), findsWidgets);

      // The schedule header text.
      expect(find.text('جدول الجلسات اليومية'), findsOneWidget);

      // Hijri and Gregorian labels.
      expect(find.text('هجري'), findsOneWidget);
      expect(find.text('ميلادي'), findsOneWidget);
    });

    testWidgets('navigation bar has all tabs in Arabic', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => testProvider)],
          child: const MyApp(enableLock: false),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('الجلسات اليومية'), findsWidgets);
      expect(find.text('البيانات الشخصية'), findsOneWidget);
      expect(find.text('التوكيلات'), findsOneWidget);
      expect(find.text('المحضرين'), findsOneWidget);
      expect(find.text('الأعمال الإدارية'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // 3. Empty sessions are handled correctly
  // -------------------------------------------------------------------------
  group('Empty sessions', () {
    testWidgets('shows empty state message when no sessions exist', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => testProvider)],
          child: const MyApp(enableLock: false),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // The empty state should show a message.
      expect(find.text('لا توجد جلسات مسجلة لهذا اليوم'), findsOneWidget);

      // There should be a button to add a session.
      expect(find.text('إضافة جلسة'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // 4. Date navigation updates the selected date
  // -------------------------------------------------------------------------
  group('Date navigation', () {
    testWidgets('forward arrow changes date', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => testProvider)],
          child: const MyApp(enableLock: false),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Get the provider.
      final provider = tester
          .element(find.byType(MaterialApp))
          .read<SessionProvider>();
      final initialDate = provider.selectedDate;

      // Tap the forward arrow (arrow_back_ios moves forward in the UI).
      final forwardButton = find.byIcon(Icons.arrow_back_ios);
      expect(forwardButton, findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(forwardButton);
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        while (provider.isLoading && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // The date should have changed to the next day.
      final newDate = provider.selectedDate;
      expect(newDate.difference(initialDate).inDays, equals(1));
    });
  });

  // -------------------------------------------------------------------------
  // 5. Session model serialization/deserialization
  // -------------------------------------------------------------------------
  group('Session model', () {
    test('toMap produces correct keys', () {
      final session = Session(
        courtName: 'محكمة القاهرة',
        circuit: 'الدائرة 3 مدني',
        caseNumber: '1234',
        caseYear: 2026,
        clientName: 'أحمد محمود',
        clientCapacity: 'مدعي',
        opponentName: 'خالد إبراهيم',
        opponentCapacity: 'مدعى عليه',
        previousSession: 'تأجيل',
        decision: 'حجز للحكم',
        notes: 'ملاحظة تجريبية',
        sessionDate: DateTime(2026, 10, 22),
      );

      final map = session.toMap();

      expect(map['court_name'], 'محكمة القاهرة');
      expect(map['circuit'], 'الدائرة 3 مدني');
      expect(map['case_number'], '1234');
      expect(map['case_year'], 2026);
      expect(map['client_name'], 'أحمد محمود');
      expect(map['client_capacity'], 'مدعي');
      expect(map['opponent_name'], 'خالد إبراهيم');
      expect(map['opponent_capacity'], 'مدعى عليه');
      expect(map['previous_session'], 'تأجيل');
      expect(map['decision'], 'حجز للحكم');
      expect(map['notes'], 'ملاحظة تجريبية');
      expect(map['session_date'], isNotNull);
      expect(map['created_at'], isNotNull);
      expect(map['updated_at'], isNotNull);
    });

    test('fromMap reconstructs session correctly', () {
      final now = DateTime.now();
      final map = {
        'id': 42,
        'court_name': 'محكمة الجيزة',
        'circuit': 'الدائرة 1 جنائي',
        'case_number': '5678',
        'case_year': 2025,
        'client_name': 'سعيد حسن',
        'client_capacity': 'متهم',
        'opponent_name': 'النيابة العامة',
        'opponent_capacity': 'سلطة اتهام',
        'previous_session': '',
        'decision': '',
        'notes': '',
        'session_date': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final session = Session.fromMap(map);

      expect(session.id, 42);
      expect(session.courtName, 'محكمة الجيزة');
      expect(session.caseYear, 2025);
      expect(session.clientCapacity, 'متهم');
    });

    test('round-trip serialization preserves all fields', () {
      final original = Session(
        id: 7,
        courtName: 'محكمة شمال القاهرة',
        circuit: 'الدائرة 12 أحوال',
        caseNumber: '999',
        caseYear: 2024,
        clientName: 'فاطمة علي',
        clientCapacity: 'مدعية',
        opponentName: 'محمد عبدالله',
        opponentCapacity: 'مدعى عليه',
        previousSession: 'تأجيل للمستندات',
        decision: 'حكم غيابي',
        notes: 'ملاحظة طويلة جداً تحتوي على نص عربي متعدد الأسطر',
        sessionDate: DateTime(2024, 5, 15),
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 5, 15),
      );

      final map = original.toMap();
      final restored = Session.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.courtName, original.courtName);
      expect(restored.circuit, original.circuit);
      expect(restored.caseNumber, original.caseNumber);
      expect(restored.caseYear, original.caseYear);
      expect(restored.clientName, original.clientName);
      expect(restored.clientCapacity, original.clientCapacity);
      expect(restored.opponentName, original.opponentName);
      expect(restored.opponentCapacity, original.opponentCapacity);
      expect(restored.previousSession, original.previousSession);
      expect(restored.decision, original.decision);
      expect(restored.notes, original.notes);
      expect(
        restored.sessionDate.toIso8601String(),
        original.sessionDate.toIso8601String(),
      );
    });

    test('copyWith preserves createdAt and updates updatedAt', () {
      final created = DateTime(2024, 1, 1, 10, 0, 0);
      final original = Session(
        id: 1,
        courtName: 'محكمة',
        circuit: 'دائرة',
        caseNumber: '1',
        caseYear: 2024,
        clientName: 'موكل',
        clientCapacity: 'مدعي',
        opponentName: 'خصم',
        opponentCapacity: 'مدعى عليه',
        previousSession: '',
        decision: '',
        notes: '',
        sessionDate: DateTime(2024, 5, 1),
        createdAt: created,
      );

      final modified = original.copyWith(courtName: 'محكمة أخرى');

      expect(modified.courtName, 'محكمة أخرى');
      expect(modified.createdAt, created);
      expect(
        modified.updatedAt.difference(DateTime.now()).inSeconds.abs(),
        lessThan(2),
      );
    });

    test('fromMap handles null optional fields gracefully', () {
      final map = {
        'id': 1,
        'court_name': 'محكمة',
        'circuit': 'دائرة',
        'case_number': '100',
        'case_year': 2026,
        'client_name': 'اسم',
        'client_capacity': null,
        'opponent_name': 'خصم',
        'opponent_capacity': null,
        'previous_session': null,
        'decision': null,
        'notes': null,
        'session_date': DateTime(2026, 1, 1).toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final session = Session.fromMap(map);
      expect(session.clientCapacity, '');
      expect(session.decision, '');
      expect(session.notes, '');
    });
  });

  // -------------------------------------------------------------------------
  // 6. Session persistence survives reopening (integration-level via FFI)
  // -------------------------------------------------------------------------
  group('Session persistence', () {
    test('session survives database round-trip', () async {
      // Use an in-memory database via FFI for testing.
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                court_name TEXT NOT NULL,
                circuit TEXT NOT NULL,
                case_number TEXT NOT NULL,
                case_year INTEGER NOT NULL,
                client_name TEXT NOT NULL,
                client_capacity TEXT,
                opponent_name TEXT NOT NULL,
                opponent_capacity TEXT,
                previous_session TEXT,
                decision TEXT,
                notes TEXT,
                session_date TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
              )
            ''');
          },
        ),
      );

      final session = Session(
        courtName: 'محكمة القاهرة',
        circuit: 'الدائرة 5 مدني',
        caseNumber: '2024',
        caseYear: 2026,
        clientName: 'أحمد',
        clientCapacity: 'مدعي',
        opponentName: 'محمد',
        opponentCapacity: 'مدعى عليه',
        previousSession: '',
        decision: '',
        notes: '',
        sessionDate: DateTime(2026, 10, 22),
      );

      // Insert
      final map = session.toMap();
      map.remove('id'); // Let autoincrement handle it
      final id = await db.insert('sessions', map);
      expect(id, greaterThan(0));

      // Read back
      final rows = await db.query('sessions', where: 'id = ?', whereArgs: [id]);
      expect(rows.length, 1);

      final restored = Session.fromMap(rows.first);
      expect(restored.courtName, 'محكمة القاهرة');
      expect(restored.caseYear, 2026);
      expect(restored.clientName, 'أحمد');

      // Update
      final updatedMap = restored.copyWith(decision: 'حكم').toMap();
      final updateCount = await db.update(
        'sessions',
        updatedMap,
        where: 'id = ?',
        whereArgs: [id],
      );
      expect(updateCount, 1);

      // Verify update
      final updatedRows = await db.query(
        'sessions',
        where: 'id = ?',
        whereArgs: [id],
      );
      final updated = Session.fromMap(updatedRows.first);
      expect(updated.decision, 'حكم');
      expect(updated.createdAt, restored.createdAt); // createdAt preserved

      // Delete
      final deleteCount = await db.delete(
        'sessions',
        where: 'id = ?',
        whereArgs: [id],
      );
      expect(deleteCount, 1);

      // Verify deletion
      final afterDelete = await db.query(
        'sessions',
        where: 'id = ?',
        whereArgs: [id],
      );
      expect(afterDelete, isEmpty);

      await db.close();
    });

    test('session date filtering works correctly', () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                court_name TEXT NOT NULL,
                circuit TEXT NOT NULL,
                case_number TEXT NOT NULL,
                case_year INTEGER NOT NULL,
                client_name TEXT NOT NULL,
                client_capacity TEXT,
                opponent_name TEXT NOT NULL,
                opponent_capacity TEXT,
                previous_session TEXT,
                decision TEXT,
                notes TEXT,
                session_date TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
              )
            ''');
          },
        ),
      );

      // Insert sessions for two different dates.
      final dates = [DateTime(2026, 10, 22), DateTime(2026, 10, 23)];
      for (final date in dates) {
        final s = Session(
          courtName: 'محكمة',
          circuit: 'دائرة',
          caseNumber: '1',
          caseYear: 2026,
          clientName: 'موكل',
          clientCapacity: '',
          opponentName: 'خصم',
          opponentCapacity: '',
          previousSession: '',
          decision: '',
          notes: '',
          sessionDate: date,
        );
        final map = s.toMap();
        map.remove('id');
        await db.insert('sessions', map);
      }

      // Filter for 2026-10-22.
      final dateStr = '2026-10-22';
      final rows = await db.query(
        'sessions',
        where: 'session_date LIKE ?',
        whereArgs: ['$dateStr%'],
      );
      expect(rows.length, 1);

      await db.close();
    });
  });

  // -------------------------------------------------------------------------
  // 7. Required fields are validated
  // -------------------------------------------------------------------------
  group('Form validation', () {
    testWidgets('required fields show validation errors', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => testProvider)],
          child: const MyApp(enableLock: false),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Tap the FAB to open the add session screen.
      final fab = find.byType(FloatingActionButton);
      await tester.tap(fab.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // We should now be on the Add Session screen.
      expect(find.text('إضافة جلسة جديدة'), findsOneWidget);

      // Try to save without filling any fields.
      await tester.scrollUntilVisible(
        find.text('حفظ الجلسة'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('حفظ الجلسة'));
      await tester.pumpAndSettle();

      // Validation errors should appear for required fields.
      expect(find.text('هذا الحقل مطلوب'), findsWidgets);
    });
  });

  // -------------------------------------------------------------------------
  // 8. Gregorian/Hijri formatting follows the documented convention
  // -------------------------------------------------------------------------
  group('Hijri conversion', () {
    test('known Gregorian dates convert to correct Hijri', () {
      // 23 March 2023 = 1 Ramadan 1444 (tabular)
      final h1 = AppDateUtils.gregorianToHijri(DateTime(2023, 3, 23));
      expect(h1.month, 9); // Ramadan
      expect(h1.day, 1);
      expect(h1.year, 1444);

      // 11 March 2024 = 1 Ramadan 1445
      final h2 = AppDateUtils.gregorianToHijri(DateTime(2024, 3, 11));
      expect(h2.month, 9);
      expect(h2.day, 1);
      expect(h2.year, 1445);

      // 1 March 2025 = 1 Ramadan 1446
      final h3 = AppDateUtils.gregorianToHijri(DateTime(2025, 3, 1));
      expect(h3.month, 9);
      expect(h3.day, 1);
      expect(h3.year, 1446);
    });

    test('Hijri month names are in Arabic', () {
      expect(AppDateUtils.hijriMonthNames[0], 'محرم');
      expect(AppDateUtils.hijriMonthNames[8], 'رمضان');
      expect(AppDateUtils.hijriMonthNames[11], 'ذو الحجة');
      expect(AppDateUtils.hijriMonthNames.length, 12);
    });

    test('round-trip conversion preserves date', () {
      final greg = AppDateUtils.hijriToGregorian(1448, 1, 1);
      final hijri = AppDateUtils.gregorianToHijri(greg);
      expect(hijri.year, 1448);
      expect(hijri.month, 1);
      expect(hijri.day, 1);
    });

    test('Hijri leap year detection is correct', () {
      expect(AppDateUtils.isHijriLeapYear(2), isTrue);
      expect(AppDateUtils.isHijriLeapYear(1442), isTrue);
      expect(AppDateUtils.isHijriLeapYear(1), isFalse);
      expect(AppDateUtils.isHijriLeapYear(1441), isFalse);
    });

    test('Hijri month lengths follow documented convention', () {
      expect(AppDateUtils.hijriMonthLength(1448, 1), 30);
      expect(AppDateUtils.hijriMonthLength(1448, 3), 30);
      expect(AppDateUtils.hijriMonthLength(1448, 2), 29);
      expect(AppDateUtils.hijriMonthLength(1448, 4), 29);
      expect(AppDateUtils.hijriMonthLength(1448, 12), 29);
      expect(AppDateUtils.hijriMonthLength(1442, 12), 30);
    });

    test('month boundaries are handled correctly', () {
      final lastMuharram = AppDateUtils.hijriToGregorian(1448, 1, 30);
      final nextDay = lastMuharram.add(const Duration(days: 1));
      final hijriNext = AppDateUtils.gregorianToHijri(nextDay);
      expect(hijriNext.month, 2);
      expect(hijriNext.day, 1);
    });

    test('year boundary is handled correctly', () {
      expect(AppDateUtils.isHijriLeapYear(1447), isTrue);
      final lastDhulHijjah = AppDateUtils.hijriToGregorian(1447, 12, 30);
      final nextDay = lastDhulHijjah.add(const Duration(days: 1));
      final hijriNext = AppDateUtils.gregorianToHijri(nextDay);
      expect(hijriNext.year, 1448);
      expect(hijriNext.month, 1);
      expect(hijriNext.day, 1);
    });

    test('getHijriDay/Month/Year return non-placeholder strings', () {
      final date = DateTime(2026, 10, 22);
      expect(AppDateUtils.getHijriDay(date), isNot('--'));
      expect(AppDateUtils.getHijriMonth(date), isNot('--'));
      expect(AppDateUtils.getHijriYear(date), isNot('--'));

      final hijriYear = int.parse(
        ArabicFormat.normalize(AppDateUtils.getHijriYear(date)),
      );
      expect(hijriYear, lessThan(1500));
      expect(hijriYear, greaterThan(1400));
    });

    test('invalid month throws ArgumentError', () {
      expect(() => AppDateUtils.hijriMonthLength(1448, 0), throwsArgumentError);
      expect(
        () => AppDateUtils.hijriMonthLength(1448, 13),
        throwsArgumentError,
      );
    });
  });
}
