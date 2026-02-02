import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers.dart';
import 'widgets/recording_sheet.dart';

class IdeaTimelineScreen extends ConsumerWidget {
  final Idea idea;

  const IdeaTimelineScreen({super.key, required this.idea});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(ideaSessionsProvider(idea.id));

    return Scaffold(
      appBar: AppBar(title: Text(idea.title)),
      body: sessionsAsync.when(
        data: (sessions) {
          if (sessions.isEmpty) {
            return const Center(child: Text("No sessions yet."));
          }

          return ListView.builder(
            itemCount: sessions.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final session = sessions[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat(
                          'MMM d, y • h:mm a',
                        ).format(session.sessionDate),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "You said:",
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: Colors.grey),
                      ),
                      Text(session.rawTranscript),
                      const SizedBox(height: 12),
                      if (session.aiInsight != null) ...[
                        Row(
                          children: [
                            Text(
                              "Watson Insight:",
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: Colors.deepPurple),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.volume_up, size: 20),
                              color: Colors.deepPurple,
                              onPressed: () {
                                ref
                                    .read(ttsServiceProvider)
                                    .speak(session.aiInsight!);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          session.aiInsight!,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ] else
                        const Row(
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text(
                              "Analyzing...",
                              style: TextStyle(fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => RecordingSheet(existingIdeaId: idea.id),
          );
        },
        icon: const Icon(Icons.add_comment),
        label: const Text("Add Session"),
      ),
    );
  }
}
