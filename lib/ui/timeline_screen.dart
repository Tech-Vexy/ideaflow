import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../providers.dart';
import '../models/models.dart';
import 'idea_details_screen.dart';
import 'settings_screen.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch filtered ideas (computed from ideas + sessions + query)
    final ideas = ref.watch(filteredIdeasProvider);
    final isSearching = ref.watch(searchQueryProvider).isNotEmpty;
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(syncServiceProvider).syncFromCloud();
      },
      child: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text("Archive"),
            centerTitle: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SearchBar(
                  controller: _searchController,
                  hintText: "Search ideas...",
                  leading: const Icon(Icons.search, color: Colors.grey),
                  onChanged: (value) {
                    ref.read(searchQueryProvider.notifier).update(value);
                  },
                  elevation: WidgetStateProperty.all(0),
                  backgroundColor: WidgetStateProperty.all(
                    theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                  ),
                  trailing: isSearching
                      ? [
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(searchQueryProvider.notifier).update('');
                            },
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
          if (isSearching)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Text(
                  "${ideas.length} ${ideas.length == 1 ? 'match' : 'matches'} found",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (ideas.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isSearching ? Icons.search_off : Icons.lightbulb_outline,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isSearching
                          ? "No matching ideas found."
                          : "No ideas yet. Start a flow!",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final idea = ideas[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: _IdeaCard(idea: idea),
                );
              }, childCount: ideas.length),
            ),
        ],
      ),
    );
  }
}

class _IdeaCard extends ConsumerWidget {
  final Idea idea;

  const _IdeaCard({required this.idea});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
          ],
        ),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => IdeaDetailsScreen(idea: idea),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),

                      child: Icon(
                        Icons.lightbulb_outline,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.ios_share_rounded, size: 20),
                      onPressed: () => _shareIdea(context, ref),
                      color: theme.colorScheme.onSurfaceVariant,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _formatDate(idea.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  idea.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      "View Details",
                      style: TextStyle(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: theme.colorScheme.secondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _shareIdea(BuildContext context, WidgetRef ref) async {
    final hive = ref.read(hiveServiceProvider);
    final sessions = hive.getSessionsForIdea(idea.id);

    final buffer = StringBuffer();
    buffer.writeln("💡 Idea: ${idea.title}");
    buffer.writeln(
      "📅 Created: ${DateFormat('MMM d, y').format(idea.createdAt)}",
    );
    buffer.writeln("");

    for (final session in sessions) {
      final date = DateFormat('MMM d, y').format(session.sessionDate);
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

    await SharePlus.instance.share(ShareParams(text: buffer.toString()));
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return "Today";
    if (diff.inDays == 1) return "Yesterday";
    return "${date.day}/${date.month}/${date.year}";
  }
}
