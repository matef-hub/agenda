import 'dart:io';

void main() {
  final wasm = File('web/sqlite3.wasm');
  final sw = File('web/sqflite_sw.js');
  if (wasm.existsSync()) {
    wasm.deleteSync();
    stdout.writeln('Deleted sqlite3.wasm');
  } else {
    stdout.writeln('sqlite3.wasm not found');
  }
  if (sw.existsSync()) {
    sw.deleteSync();
    stdout.writeln('Deleted sqflite_sw.js');
  } else {
    stdout.writeln('sqflite_sw.js not found');
  }
}
