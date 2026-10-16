// Opt-in local visual QA; no screenshots or host-font dependencies in normal CI.
// Run: flutter test test/preview_test.dart --dart-define=PREVIEW=true
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_path/domain/domain.dart';
import 'package:kana_path/ui/home_screen.dart';
import 'package:kana_path/ui/lesson_screen.dart';
import 'package:kana_path/ui/library_screen.dart';
import 'package:kana_path/ui/settings_screen.dart';
import 'package:kana_path/ui/theme.dart';
import 'package:kana_path/ui/ui_contract.dart';

const _renderPreviews = bool.fromEnvironment('PREVIEW');

class _PreviewController extends LearningController {
  _PreviewController(this.curriculum, {LearningItem? lessonItem}) {
    for (final item in curriculum.take(8)) {
      for (final skill in PracticeSkill.values) {
        final state = SkillProgress(
          itemId: item.id,
          skill: skill,
          successfulReviews: 3,
          dueAt: DateTime(2026, 10, 15),
          correctCount: 3,
        );
        progress[state.key] = state;
      }
    }
    if (lessonItem != null) {
      activeSession = LessonSession(
        id: 'preview',
        scope: lessonItem.isKanji ? LessonScope.kanji : LessonScope.hiragana,
        focus: LessonFocus.typing,
        questions: [
          for (var index = 0; index < 10; index++)
            LessonQuestion(
              id: 'preview-$index',
              itemId: lessonItem.id,
              skill: PracticeSkill.typing,
            ),
        ],
        startedAt: DateTime(2026, 10, 16),
      );
    }
  }

  @override
  final List<LearningItem> curriculum;
  @override
  final Map<String, SkillProgress> progress = {};
  @override
  LessonSession? activeSession;
  @override
  List<LearningItem> get introItems => [];
  @override
  AnswerFeedback? feedback;
  @override
  bool get loading => false;
  @override
  bool get busy => false;
  @override
  String? get error => null;
  @override
  bool get kanjiUnlocked => false;
  @override
  HandwritingModelStatus get modelStatus => HandwritingModelStatus.ready;
  @override
  Future<void> startLesson(LessonScope scope, LessonFocus focus) async {}
  @override
  void completeIntroduction() {}
  @override
  Future<void> submitText(String answer) async {}
  @override
  Future<void> submitDrawing(InkSubmission ink) async {}
  @override
  Future<void> revealAnswer() async {}
  @override
  void retryAnswer() {}
  @override
  Future<void> advance() async {}
  @override
  Future<void> exitLesson() async {}
  @override
  Future<void> abandonLesson() async {}
  @override
  Future<void> downloadModel() async {}
  @override
  Future<String> exportBackup() async => '{}';
  @override
  Future<void> importBackup(String json) async {}
  @override
  void clearError() {}
}

Future<void> _font(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    loader.addFont(
      File(path).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
    );
  }
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<LearningItem> curriculum;
  setUpAll(() async {
    if (!_renderPreviews) return;
    final root =
        jsonDecode(File('assets/curriculum/items.json').readAsStringSync())
            as Map<String, dynamic>;
    curriculum = (root['items'] as List)
        .map(
          (item) =>
              LearningItem.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    const materialFonts = '.tools/flutter/bin/cache/artifacts/material_fonts';
    await _font('Roboto', [
      '$materialFonts/roboto-regular.ttf',
      '$materialFonts/roboto-medium.ttf',
      '$materialFonts/roboto-bold.ttf',
    ]);
    await _font('PreviewJapanese', ['C:/Windows/Fonts/YuGothR.ttc']);
    await _font('MaterialIcons', ['$materialFonts/materialicons-regular.otf']);
    Directory('build/screenshots').createSync(recursive: true);
  });

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.6]) {
      for (final screen in ['home', 'typing', 'library', 'settings']) {
        final name =
            '${screen}_${brightness.name}_${scale == 1.0 ? 'normal' : 'large'}';
        testWidgets(name, skip: !_renderPreviews, (tester) async {
          await tester.binding.setSurfaceSize(const Size(360, 800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final controller = _PreviewController(
            curriculum,
            lessonItem: screen == 'typing'
                ? curriculum.firstWhere((item) => item.glyph == 'し')
                : null,
          );
          addTearDown(controller.dispose);
          final capture = GlobalKey();
          final baseTheme = kanaTheme(brightness);
          final theme = baseTheme.copyWith(
            textTheme: baseTheme.textTheme.apply(
              fontFamily: 'Roboto',
              fontFamilyFallback: ['PreviewJapanese'],
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: baseTheme.filledButtonTheme.style!.copyWith(
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(
                    fontFamily: 'Roboto',
                    fontFamilyFallback: ['PreviewJapanese'],
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
          final page = switch (screen) {
            'home' => HomeScreen(controller: controller),
            'typing' => LessonScreen(controller: controller),
            'library' => LibraryScreen(controller: controller),
            _ => SettingsScreen(controller: controller),
          };
          await tester.pumpWidget(
            RepaintBoundary(
              key: capture,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: screen == 'typing'
                    ? page
                    : Scaffold(
                        appBar: AppBar(title: const Text('Kana Path')),
                        body: page,
                        bottomNavigationBar: NavigationBar(
                          selectedIndex: screen == 'library'
                              ? 1
                              : screen == 'settings'
                              ? 2
                              : 0,
                          destinations: const [
                            NavigationDestination(
                              icon: Icon(Icons.explore_outlined),
                              label: 'Learn',
                            ),
                            NavigationDestination(
                              icon: Icon(Icons.grid_view_outlined),
                              label: 'Library',
                            ),
                            NavigationDestination(
                              icon: Icon(Icons.tune_outlined),
                              label: 'Settings',
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (screen == 'typing') {
            await tester.enterText(find.byType(TextField), 'し');
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull, reason: name);
          Future<void> screenshot(String suffix) async {
            await tester.runAsync(() async {
              final boundary =
                  capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              File(
                'build/screenshots/$name$suffix.png',
              ).writeAsBytesSync(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }

          await screenshot('');
          // Verify the bottom of each scrollable page as well as its first fold.
          final scrollable = find.byType(SingleChildScrollView).first;
          await tester.drag(scrollable, const Offset(0, -2000));
          await tester.pumpAndSettle();
          final scrollState = tester.state<ScrollableState>(
            find
                .descendant(of: scrollable, matching: find.byType(Scrollable))
                .first,
          );
          scrollState.position.jumpTo(scrollState.position.maxScrollExtent);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$name scrolled');
          await screenshot('_bottom');
        });
      }
    }
  }
}
