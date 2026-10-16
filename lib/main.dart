import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_controller.dart';
import 'ui/kana_path_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'KANJIDIC2 / JMdict curriculum',
    ], await rootBundle.loadString('assets/licenses/CC-BY-SA-4.0.txt'));
    yield LicenseEntryWithLineBreaks([
      'KanjiVG stroke diagrams',
    ], await rootBundle.loadString('assets/licenses/KanjiVG-COPYING.txt'));
  });
  final controller = AppController();
  runApp(KanaPathApp(controller: controller));
  unawaited(controller.initialize());
}
