import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:agenda/core/database/database_helper.dart';
import 'package:agenda/core/security/backup_service.dart';
import 'package:agenda/core/security/secret_vault.dart';
import 'package:agenda/core/utils/arabic_format.dart';
import 'package:agenda/core/utils/date_utils.dart';
import 'package:agenda/features/daily_schedule/data/models/session_model.dart';
import 'package:agenda/features/daily_schedule/data/repositories/session_repository.dart';
import 'package:agenda/features/daily_schedule/presentation/providers/session_provider.dart';

Session sample(DateTime date, {String number = '123'}) => Session(
  courtName: 'محكمة القاهرة',
  circuit: 'دائرة 5',
  caseNumber: number,
  caseYear: 2026,
  clientName: 'موكل تجريبي',
  clientCapacity: '',
  opponentName: 'خصم تجريبي',
  opponentCapacity: '',
  previousSession: '',
  decision: '',
  notes: '',
  sessionDate: date,
);

class PendingRepository extends SessionRepository {
  final requests = <Completer<List<Session>>>[];
  @override
  Future<List<Session>> getSessionsForDate(DateTime date) {
    final pending = Completer<List<Session>>();
    requests.add(pending);
    return pending.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    FlutterSecureStorage.setMockInitialValues({});
  });
  test(
    'Arabic and Persian digits normalize and all visible numbers are Arabic',
    () {
      expect(ArabicFormat.normalize('٢٠٢٦/۱۲۳'), '2026/123');
      expect(ArabicFormat.digits('قضية 123/٢٠٢٦'), 'قضية ١٢٣/٢٠٢٦');
      expect(
        ArabicFormat.date(DateTime(2026, 10, 24)),
        '\u200F٢٤ / ١٠ / ٢٠٢٦\u200F',
      );
      expect(ArabicFormat.parseDate('٢٤ / ١٠ / ٢٠٢٦'), DateTime(2026, 10, 24));
      expect(ArabicFormat.parseDate('٣١ / ٢ / ٢٠٢٦'), isNull);
      expect(ArabicFormat.parseDate('2026-02-31'), isNull);
      expect(ArabicFormat.shiftDay(DateTime(2026, 12, 31), 1), DateTime(2027));
      expect(
        AppDateUtils.getHijriYear(DateTime(2026, 10, 24)),
        matches(RegExp(r'^[٠-٩]+$')),
      );
      expect(
        () => AppDateUtils.hijriToGregorian(1448, 2, 30),
        throwsArgumentError,
      );
      expect(
        () => AppDateUtils.gregorianToHijri(DateTime(600)),
        throwsArgumentError,
      );
    },
  );
  test('Older async request cannot overwrite the selected day', () async {
    final repository = PendingRepository();
    final provider = SessionProvider(repository: repository, autoLoad: false);
    provider.setSelectedDate(DateTime(2026, 10, 24));
    provider.setSelectedDate(DateTime(2026, 10, 25));
    repository.requests[1].complete([
      sample(DateTime(2026, 10, 25), number: 'new'),
    ]);
    await Future<void>.delayed(Duration.zero);
    repository.requests[0].complete([
      sample(DateTime(2026, 10, 24), number: 'old'),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(provider.sessions.single.caseNumber, 'new');
    expect(provider.isLoading, false);
    provider.dispose();
  });
  test('Completing a request after disposal is harmless', () async {
    final repository = PendingRepository();
    final provider = SessionProvider(repository: repository, autoLoad: false);
    final loading = provider.loadSessions();
    provider.dispose();
    repository.requests.single.complete([]);
    await expectLater(loading, completes);
  });
  test(
    'Actual database persists, migrates indexes and filters by calendar day',
    () async {
      final directory = await Directory.systemTemp.createTemp('agenda-test-');
      final path = '${directory.path}/test.db';
      final helper = DatabaseHelper.forTesting(path);
      final repo = SessionRepository(database: helper);
      try {
        final id = await repo.insertSession(
          sample(DateTime(2026, 10, 24, 23, 59)),
        );
        await repo.insertSession(sample(DateTime(2026, 10, 25)));
        final db = await helper.database;
        await db.execute('DROP INDEX idx_sessions_date');
        await db.execute('PRAGMA user_version = 1');
        await helper.close();
        final reopened = await helper.database;
        expect(await reopened.getVersion(), 2);
        final indexes = await reopened.rawQuery(
          "PRAGMA index_list('sessions')",
        );
        expect(indexes.any((r) => r['name'] == 'idx_sessions_date'), true);
        final rows = await repo.getSessionsForDate(
          DateTime(2026, 10, 24, 23, 59),
        );
        expect(rows.single.id, id);
        expect((await repo.searchSessions('١٢٣')).length, 2);
        await repo.updateSession(rows.single.copyWith(decision: 'حكم'));
        expect((await repo.getSession(id))!.decision, 'حكم');
        expect(await repo.deleteSession(id), 1);
      } finally {
        await helper.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test('Postponement preserves original hearing and rejects stale duplicate requests', () async {
    final db = DatabaseHelper.forTesting(inMemoryDatabasePath);
    final repo = SessionRepository(database: db);
    try {
      final id = await repo.insertSession(sample(DateTime(2026, 10, 24)));
      final original = (await repo.getSession(id))!;
      await repo.postpone(original, DateTime(2026, 11, 1));
      final history = await repo.caseHistory(original);
      expect(history.length, 2);
      expect(history.first.sessionDate, DateTime(2026, 11, 1));
      expect(history.last.id, id);
      expect(history.last.decision, contains('تأجيل'));
      expect(history.first.previousSession, contains('٢٤'));
      await expectLater(
        repo.postpone(original, DateTime(2026, 11, 1)),
        throwsStateError,
      );
      expect((await repo.caseHistory(original)).length, 2);
    } finally {
      await db.close();
    }
  });
  test(
    'Sensitive fields encrypt and decrypt without changing other fields',
    () async {
      final plain = {
        'id': 1,
        'name': 'اسم',
        'id_card_no': '12345678901234',
        'bank_account_no': '9876',
      };
      final encrypted = await SecretVault.protect(plain);
      expect(encrypted['id_card_no'], startsWith('enc:v1:'));
      expect(encrypted['id_card_no'], isNot(plain['id_card_no']));
      expect(encrypted['name'], plain['name']);
      expect(await SecretVault.reveal(encrypted), plain);
      final again = await SecretVault.protect(plain);
      expect(again['id_card_no'], isNot(encrypted['id_card_no']));
      final migrated = <Map<String, dynamic>>[];
      await SecretVault.migrate(
        (row) async {
          migrated.add(row);
        },
        [
          {...encrypted, 'bank_account_no': '5555'},
        ],
      );
      final decoded = await SecretVault.reveal(migrated.single);
      expect(decoded['id_card_no'], plain['id_card_no']);
      expect(decoded['bank_account_no'], '5555');
    },
  );
  test('Encrypted backup restores all tables and rejects wrong password and malformed content', () async {
    final helper = DatabaseHelper.forTesting(inMemoryDatabasePath);
    final service = BackupService(helper);
    const password = 'test backup password';
    try {
      await SessionRepository(database: helper)
          .insertSession(sample(DateTime(2026, 10, 24)));
      await helper.insert('admin_notes', {
        'title': 'عمل',
        'content': 'تفاصيل',
        'is_completed': 1,
        'note_date': '2026-10-24',
        'created_at': '2026-10-24',
      });
      await helper.insert('powers_of_attorney', {
        'client_name': 'موكل',
        'poa_number': '12',
        'created_at': '2026-10-24',
      });
      await helper.insert('bailiff_papers', {
        'reference_number': '34',
        'bailiffs_office': 'قلم',
        'client_name': 'موكل',
        'created_at': '2026-10-24',
      });
      await helper.insert('personal_info', {
        'name': 'اسم',
        'updated_at': '2026-10-24',
      });
      final encoded = await service.export(password);
      expect(encoded.contains('موكل'), false);
      await expectLater(
        service.read(encoded, 'wrong password'),
        throwsA(anything),
      );
      final tables = await service.read(encoded, password);
      for (final table in DatabaseHelper.tables) {
        await helper.clearTable(table);
      }
      await service.restore(tables);
      for (final table in DatabaseHelper.tables) {
        expect((await helper.queryAll(table)).length, 1);
      }
      await helper.clearTable('sessions');
      await service.restore(tables, selectedTables: {'admin_notes'});
      expect(await helper.queryAll('sessions'), isEmpty);
      expect((await helper.queryAll('admin_notes')).length, 1);
      await service.restore(tables, selectedTables: {'sessions'});
      final payload = jsonDecode(
        await PasswordCipher.decrypt(encoded, password),
      ) as Map<String, dynamic>;
      (payload['tables'] as Map).remove('sessions');
      final invalid = await PasswordCipher.encrypt(
        jsonEncode(payload),
        password,
      );
      await expectLater(service.read(invalid, password), throwsFormatException);
      expect((await helper.queryAll('sessions')).length, 1);
      final broken = {
        for (final e in tables.entries)
          e.key: e.value.map((r) => Map<String, dynamic>.of(r)).toList(),
      };
      broken['admin_notes']!.single['content'] = null;
      await expectLater(service.restore(broken), throwsA(anything));
      expect((await helper.queryAll('sessions')).length, 1);
      expect(
        (await helper.queryAll('admin_notes')).single['content'],
        'تفاصيل',
      );
    } finally {
      await helper.close();
    }
  });
}
