import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';
import 'ui_contract.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});
  final LearningController controller;

  Future<void> _export(BuildContext context) async {
    try {
      final json = await controller.exportBackup();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export your progress'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Copy this JSON into a text file and keep it somewhere safe. It includes progress and any unfinished lesson.',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: SingleChildScrollView(
                    child: SelectableText(
                      json,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: json));
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Backup copied. Save it to a text file.'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy JSON'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export progress: $error')),
        );
      }
    }
  }

  Future<void> _import(BuildContext context) async {
    final input = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore a backup'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste your exported JSON below. A valid backup replaces the progress and unfinished lesson on this device. Export your current progress first if you want to keep it.',
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: input,
                  maxLines: 7,
                  minLines: 4,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Backup JSON',
                    alignLabelWithHint: true,
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Validate and restore'),
          ),
        ],
      ),
    );
    final json = input.text;
    input.dispose();
    if (accepted != true || !context.mounted) return;
    try {
      await controller.importBackup(json);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Progress restored successfully.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup was not restored: $error')),
        );
      }
    }
  }

  Future<void> _notices(BuildContext context) async {
    final text = await rootBundle.loadString('assets/licenses/NOTICE.txt');
    if (context.mounted) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Curriculum source notices'),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: SelectableText(
                text,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: PageWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Make room for learning',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'A little setup, then your next small step.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            const Text(
              'HANDWRITING',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            HandwritingModelCard(controller: controller),
            const SizedBox(height: 28),
            const Text(
              'YOUR PROGRESS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),
                    leading: const Icon(Icons.upload_file_outlined),
                    title: const Text('Export backup'),
                    subtitle: const Text('Copy a portable JSON backup'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: controller.busy ? null : () => _export(context),
                  ),
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),
                    leading: const Icon(Icons.restore_rounded),
                    title: const Text('Restore backup'),
                    subtitle: const Text('Validate and replace local progress'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: controller.busy ? null : () => _import(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'HOW LEARNING WORKS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Practice, rest, remember',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Each character has separate reading, typing, and drawing progress. Three unassisted successes on scheduled, separate days establish mastery. Reviews return after 1, 3, 7, 14, and then 30 days.\n\nA mistake or revealed answer schedules a retry in ten minutes. Same-day practice is always welcome and never rushes mastery.',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'SOURCES & PRIVACY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your learning stays here',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Kana Path has no accounts, advertising, or cloud synchronization. Lessons, progress, and handwriting recognition run on your device after the Japanese recognition model is downloaded. Backups include your learning history.\n\nGoogle ML Kit may collect device and usage diagnostics under its own terms. Downloading the model requires a network connection.',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const SelectableText(
                      'developers.google.com/ml-kit/terms',
                      style: TextStyle(fontSize: 12),
                    ),
                    const Divider(height: 32),
                    Text(
                      'Kanji readings and meanings use KANJIDIC2/JMdict. The 100 starter kanji follow KANJIDIC2 newspaper frequency ranks. Stroke-order diagrams use KanjiVG. Source licenses and attribution are bundled with this app.',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => _notices(context),
                          child: const Text('Source notices'),
                        ),
                        TextButton(
                          onPressed: () => showLicensePage(
                            context: context,
                            applicationName: 'Kana Path',
                            applicationVersion: '1.0.0',
                            applicationLegalese:
                                'A personal path into Japanese.',
                          ),
                          child: const Text('Open-source licenses'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Center(
              child: Text(
                'KANA PATH · 1.0.0\nMade for steady, curious practice.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                  height: 1.8,
                  letterSpacing: .4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HandwritingModelCard extends StatelessWidget {
  const HandwritingModelCard({super.key, required this.controller});
  final LearningController controller;

  @override
  Widget build(BuildContext context) {
    final status = controller.modelStatus;
    final ready = status == HandwritingModelStatus.ready;
    final downloading = status == HandwritingModelStatus.downloading;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  ready ? Icons.check_circle_outline : Icons.gesture_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Japanese handwriting',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              switch (status) {
                HandwritingModelStatus.ready =>
                  'Ready for offline drawing practice.',
                HandwritingModelStatus.downloading =>
                  'Downloading the Japanese model. Keep the app open.',
                HandwritingModelStatus.failed =>
                  'The model could not be prepared. Check your connection and try again on Android or iPhone.',
                HandwritingModelStatus.unavailable =>
                  'Download the Japanese recognition model once to practice drawing offline on Android or iPhone.',
              },
              style: TextStyle(
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (downloading) ...[
              const SizedBox(height: 18),
              const LinearProgressIndicator(),
            ],
            if (!ready && !downloading) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: controller.busy ? null : controller.downloadModel,
                icon: const Icon(Icons.download_rounded),
                label: Text(
                  status == HandwritingModelStatus.failed
                      ? 'Try download again'
                      : 'Download model',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
