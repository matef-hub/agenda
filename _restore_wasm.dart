import 'dart:io';

void main() {
  // Localiza o wasm no cache da v1.2.0
  final cacheBase = Directory('.dart_tool/sqflite_common_ffi_web/setup/1.2.0');
  if (!cacheBase.existsSync()) {
    stdout.writeln('Cache dir not found: ${cacheBase.path}');
    return;
  }

  File? wasmFile;
  void findWasm(Directory dir) {
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('sqlite3.wasm')) {
        wasmFile = entity;
        return;
      }
    }
  }

  findWasm(cacheBase);

  if (wasmFile == null) {
    stdout.writeln('sqlite3.wasm not found in cache');
    return;
  }

  stdout.writeln(
    'Found wasm: ${wasmFile!.path} (${wasmFile!.lengthSync()} bytes)',
  );
  wasmFile!.copySync('web/sqlite3.wasm');
  stdout.writeln('Copied to web/sqlite3.wasm');

  // Limpa o script de cleanup anterior se existir
  final cleanup = File('_cleanup.dart');
  if (cleanup.existsSync()) {
    cleanup.deleteSync();
    stdout.writeln('Deleted _cleanup.dart');
  }
}
