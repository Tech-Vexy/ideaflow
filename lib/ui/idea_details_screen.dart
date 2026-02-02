import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers.dart';
import 'conversational_screen.dart';

class IdeaDetailsScreen extends ConsumerStatefulWidget {
  final Idea idea;

  const IdeaDetailsScreen({super.key, required this.idea});

  @override
  ConsumerState<IdeaDetailsScreen> createState() => _IdeaDetailsScreenState();
}

class _IdeaDetailsScreenState extends ConsumerState<IdeaDetailsScreen> {
  late TextEditingController _titleController;
  final FocusNode _titleFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.idea.title);
    _titleFocus.addListener(_onTitleFocusChange);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocus.removeListener(_onTitleFocusChange);
    _titleFocus.dispose();
    super.dispose();
  }

  void _onTitleFocusChange() {
    if (!_titleFocus.hasFocus) {
      _saveTitle();
    }
  }

  Future<void> _saveTitle() async {
    final newTitle = _titleController.text.trim();
    if (newTitle.isNotEmpty && newTitle != widget.idea.title) {
      final hive = ref.read(hiveServiceProvider);
      final updatedIdea = Idea(
        id: widget.idea.id,
        title: newTitle,
        createdAt: widget.idea.createdAt,
      );
      // Update local
      await hive.updateIdea(updatedIdea);
      // Sync to cloud
      await ref.read(firebaseServiceProvider).saveIdea(updatedIdea);
    }
  }

  Future<void> _addTextNote() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          "Add Note",
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: TextField(
          controller: controller,
          maxLines: 5,

          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: "Enter your thoughts...",
            hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final hive = ref.read(hiveServiceProvider);
                final session = await hive.addSession(
                  widget.idea.id,
                  controller.text.trim(),
                );
                // Sync to Firebase
                await ref.read(firebaseServiceProvider).saveSession(session);

                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessionsAsync = ref.watch(ideaSessionsProvider(widget.idea.id));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            backgroundColor: theme.colorScheme.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            title: Hero(
              tag: 'idea-title-${widget.idea.id}',
              child: Material(
                color: Colors.transparent,
                child: TextField(
                  controller: _titleController,
                  focusNode: _titleFocus,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: "Idea Title",
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                  maxLines: 1,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveTitle(),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_note_rounded),
                onPressed: _addTextNote,
              ),
              IconButton(
                icon: const Icon(Icons.ios_share_rounded),
                onPressed: () async {
                  final hive = ref.read(hiveServiceProvider);
                  final sessions = hive.getSessionsForIdea(widget.idea.id);

                  final buffer = StringBuffer();
                  buffer.writeln("💡 Idea: ${widget.idea.title}");
                  buffer.writeln(
                    "📅 Created: ${DateFormat('MMM d, y').format(widget.idea.createdAt)}",
                  );
                  buffer.writeln("");

                  for (final session in sessions) {
                    final date = DateFormat(
                      'MMM d, y • h:mm a',
                    ).format(session.sessionDate);
                    buffer.writeln("┌── $date ──");
                    if (session.rawTranscript.isNotEmpty) {
                      buffer.writeln("│ Note: ${session.rawTranscript}");
                    }
                    if (session.aiInsight != null) {
                      buffer.writeln("│ AI: ${session.aiInsight}");
                    }
                    buffer.writeln("└");
                    buffer.writeln("");
                  }

                  buffer.writeln("Shared via IdeaFlow ✨");

                  await SharePlus.instance.share(
                    ShareParams(text: buffer.toString()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Delete Idea?"),
                      content: const Text(
                        "This will delete the idea and all its notes.",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            "Delete",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final hive = ref.read(hiveServiceProvider);
                    await hive.deleteIdea(widget.idea.id);
                    await ref
                        .read(firebaseServiceProvider)
                        .deleteIdea(widget.idea.id);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  }
                },
              ),
            ],
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Sessions List
          sessionsAsync.when(
            data: (sessions) {
              if (sessions.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Text(
                      "No notes yet.\nAdd one or start a voice session!",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final session = sessions[index];
                  return _SessionCard(session: session);
                }, childCount: sessions.length),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, stack) =>
                SliverFillRemaining(child: Center(child: Text("Error: $err"))),
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  ConversationalScreen(initialIdea: widget.idea),
            ),
          );
        },
        icon: const Icon(Icons.auto_awesome),
        label: const Text("Continue Brainstorming"),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final BrainstormSession session;

  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.1),
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      session.aiInsight != null
                          ? Icons.auto_awesome_rounded
                          : Icons.notes_rounded,
                      size: 16,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat(
                        'MMM d, y • h:mm a',
                      ).format(session.sessionDate),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // User Transcript
                if (session.rawTranscript.isNotEmpty) ...[
                  Text(
                    session.rawTranscript,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // AI Insight
                if (session.aiInsight != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      session.aiInsight!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
