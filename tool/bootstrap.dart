import 'dart:io';

/// Run from the package root: dart tool/bootstrap.dart
/// Generates host projects without overwriting the authored app or package.
Future<void> main(List<String> args) async {
  final root = File.fromUri(Platform.script).parent.parent;
  final app = Directory('${root.path}/example');
  final temp = await Directory.systemTemp.createTemp(
    'murmur-studio-platforms-',
  );
  try {
    await runFlutter([
      'create',
      '--project-name',
      'murmur',
      '--org',
      'com.thongvanh.michael',
      '--platforms',
      'android,ios,macos,windows,linux,web',
      '--no-pub',
      '${temp.path}/app',
    ], root.path);
    final generated = Directory('${temp.path}/app');
    for (final platform in [
      'android',
      'ios',
      'macos',
      'windows',
      'linux',
      'web',
    ]) {
      final target = Directory('${app.path}/$platform');
      if (!target.existsSync()) {
        copyDirectory(Directory('${generated.path}/$platform'), target);
      }
    }
    final metadata = File('${app.path}/.metadata');
    if (!metadata.existsSync()) {
      File('${generated.path}/.metadata').copySync(metadata.path);
    }
    patchFile('${app.path}/android/app/src/main/AndroidManifest.xml', (s) {
      if (s.contains('android.permission.RECORD_AUDIO')) return s;
      return s.replaceFirst(
        '<application',
        '<uses-permission android:name="android.permission.RECORD_AUDIO"/>\n    <application',
      );
    });
    // record requires Android API 23 or newer. Support both Gradle templates.
    for (final filename in ['build.gradle.kts', 'build.gradle']) {
      patchFile(
        '${app.path}/android/app/$filename',
        (s) => s
            .replaceAll('minSdk = flutter.minSdkVersion', 'minSdk = 23')
            .replaceAll(
              'minSdkVersion flutter.minSdkVersion',
              'minSdkVersion 23',
            ),
      );
    }
    for (final platform in ['ios', 'macos']) {
      patchFile('${app.path}/$platform/Runner/Info.plist', (s) {
        if (s.contains('NSMicrophoneUsageDescription')) return s;
        return s.replaceFirst(
          '</dict>',
          '<key>NSMicrophoneUsageDescription</key>\n'
              '    <string>Murmur Studio uses your microphone to animate sound-reactive indicators. Audio stays on your device.</string>\n</dict>',
        );
      });
    }
    for (final name in ['DebugProfile.entitlements', 'Release.entitlements']) {
      patchFile('${app.path}/macos/Runner/$name', (s) {
        if (s.contains('com.apple.security.device.audio-input')) return s;
        return s.replaceFirst(
          '</dict>',
          '<key>com.apple.security.device.audio-input</key>\n    <true/>\n</dict>',
        );
      });
    }
    const webDescription =
        'A native Flutter playground for the seventeen Murmur indicators.';
    patchFile(
      '${app.path}/web/index.html',
      (s) => s
          .replaceAll('<title>murmur</title>', '<title>Murmur Studio</title>')
          .replaceAll('content="murmur"', 'content="Murmur Studio"')
          .replaceAll('A new Flutter project.', webDescription),
    );
    patchFile(
      '${app.path}/web/manifest.json',
      (s) => s
          .replaceAll('"name": "murmur"', '"name": "Murmur Studio"')
          .replaceAll('"short_name": "murmur"', '"short_name": "Murmur Studio"')
          .replaceAll('A new Flutter project.', webDescription)
          .replaceAll('#0175C2', '#171B1B'),
    );
    await runFlutter(['pub', 'get'], root.path);
    await runFlutter(['pub', 'get'], app.path);
    stdout.writeln('\nStudio ready. Run: cd example && flutter run');
  } finally {
    await temp.delete(recursive: true);
  }
}

void patchFile(String path, String Function(String) transform) {
  final file = File(path);
  if (file.existsSync()) {
    file.writeAsStringSync(transform(file.readAsStringSync()));
  }
}

void copyDirectory(Directory source, Directory destination) {
  destination.createSync(recursive: true);
  for (final entity in source.listSync()) {
    final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
    if (entity is Directory) {
      copyDirectory(entity, Directory('${destination.path}/$name'));
    } else if (entity is File) {
      entity.copySync('${destination.path}/$name');
    }
  }
}

Future<void> runFlutter(List<String> args, String cwd) async {
  final process = await Process.start(
    'flutter',
    args,
    workingDirectory: cwd,
    runInShell: Platform.isWindows,
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await process.exitCode;
  if (code != 0) {
    throw ProcessException('flutter', args, 'Flutter command failed', code);
  }
}
