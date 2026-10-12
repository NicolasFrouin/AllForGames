// Fills web/sw.js in a web build: the files the app needs offline, and a
// cache name that changes with any of them.
//
//   flutter build web --release --wasm --no-web-resources-cdn
//   dart run tool/make_service_worker.dart [build/web]
//
// The cache holds both engines: the JavaScript build with CanvasKit (Safari,
// so every iPhone browser, and Firefox) and the WebAssembly build with skwasm
// (Chrome, Edge). It leaves out the variants these browsers do not load, and
// the debug symbols.

// A command-line tool: printing is its output.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// Files of the build that no browser of the app loads, or that are not
/// the app.
final _skipped = RegExp(
  r'(\.symbols$|^canvaskit/(chromium|webparagraph)/|^canvaskit/(wimp|skwasm_heavy)\.'
  r'|^flutter\.js$|^flutter_service_worker\.js$|^sw\.js$|^\.last_build_id$)',
);

void main(List<String> args) {
  final root = Directory(args.isEmpty ? 'build/web' : args.first);
  final worker = File('${root.path}/sw.js');
  if (!worker.existsSync()) {
    stderr.writeln('No ${worker.path}: build the web app first.');
    exitCode = 1;
    return;
  }
  final files =
      [
          for (final entity in root.listSync(recursive: true))
            if (entity is File)
              entity.path.substring(root.path.length + 1).replaceAll(r'\', '/'),
        ]
        ..removeWhere(_skipped.hasMatch)
        ..sort();

  // FNV-1a over the names and contents: 64-bit ints wrap on the Dart VM.
  var hash = 0xcbf29ce484222325;
  void add(List<int> data) {
    for (final byte in data) {
      hash = (hash ^ byte) * 0x100000001b3;
    }
  }

  var bytes = 0;
  for (final file in files) {
    final content = File('${root.path}/$file').readAsBytesSync();
    add(utf8.encode(file));
    add(const [0]);
    add(content);
    bytes += content.length;
  }
  final cache = 'afg-${hash.toUnsigned(64).toRadixString(16)}';

  final template = worker.readAsStringSync();
  const cacheLine = "const CACHE = 'afg-dev';";
  const filesLine = 'const FILES = [];';
  if (!template.contains(cacheLine) || !template.contains(filesLine)) {
    stderr.writeln('${worker.path} is filled already, or not the template.');
    exitCode = 1;
    return;
  }
  worker.writeAsStringSync(
    template
        .replaceFirst(cacheLine, "const CACHE = '$cache';")
        .replaceFirst(
          filesLine,
          'const FILES = ${jsonEncode(['./', ...files])};',
        ),
  );
  print(
    '${worker.path}: $cache, ${files.length} files, '
    '${(bytes / 1e6).toStringAsFixed(1)} MB',
  );
}
