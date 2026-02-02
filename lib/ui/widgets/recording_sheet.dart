import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';

class RecordingSheet extends ConsumerStatefulWidget {
  final String? existingIdeaId;
  const RecordingSheet({super.key, this.existingIdeaId});

  @override
  ConsumerState<RecordingSheet> createState() => _RecordingSheetState();
}

class _RecordingSheetState extends ConsumerState<RecordingSheet> {
  String _transcript = "Listening...";

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  Future<void> _startRecording() async {
    final voiceService = ref.read(voiceServiceProvider);
    await voiceService.init();
    await voiceService.startRecording(
      onTextUpdate: (text) {
        if (mounted) {
          setState(() {
            _transcript = text.isEmpty ? "Listening..." : text;
          });
        }
      },
    );
  }

  Future<void> _stopAndSave() async {
    final voiceService = ref.read(voiceServiceProvider);
    await voiceService.stopRecording();
    final content = voiceService.currentTranscript;

    if (content.isNotEmpty) {
      final hiveService = ref.read(hiveServiceProvider);

      if (widget.existingIdeaId != null) {
        final watson = ref.read(watsonServiceProvider);
        String? previousContext;

        final lastSessions = hiveService.getSessionsForIdea(
          widget.existingIdeaId!,
        );
        if (lastSessions.isNotEmpty) {
          previousContext =
              lastSessions.first.aiInsight ?? lastSessions.first.rawTranscript;
        }

        final aiInsight = await watson.analyzeIdea(
          content,
          previousContext: previousContext,
        );

        final session = await hiveService.addSession(
          widget.existingIdeaId!,
          content,
          aiInsight: aiInsight,
        );

        // Sync to Firebase
        await ref.read(firebaseServiceProvider).saveSession(session);
      } else {
        final title = content.length > 30
            ? "${content.substring(0, 30)}..."
            : content;
        final idea = await hiveService.createIdea(title);

        final watson = ref.read(watsonServiceProvider);
        final aiInsight = await watson.analyzeIdea(content);

        final session = await hiveService.addSession(
          idea.id,
          content,
          aiInsight: aiInsight,
        );

        // Sync to Firebase
        await ref.read(firebaseServiceProvider).saveIdea(idea);
        await ref.read(firebaseServiceProvider).saveSession(session);
      }
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            _transcript,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w400),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _stopAndSave,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "Stop & Save Idea",
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
