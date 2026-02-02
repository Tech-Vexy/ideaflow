import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          if (user != null) ...[
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text("Account"),
              subtitle: Text(user.email ?? "Anonymous User"),
            ),
            if (user.uid.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.fingerprint),
                title: const Text("User ID"),
                subtitle: Text(
                  user.uid,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                ),
              ),
            const Divider(),
          ],
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Sign Out", style: TextStyle(color: Colors.red)),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Sign Out?"),
                  content: const Text("You will return to the login screen."),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("Sign Out"),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await ref.read(authServiceProvider).signOut();
                if (context.mounted) {
                  Navigator.of(context).pop(); // Just close the settings screen
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
