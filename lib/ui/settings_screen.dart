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

    // Simple Admin Check
    const adminEmail = "eveliaveldrine@gmail.com";
    final isAdmin =
        user?.email == adminEmail ||
        (user?.email?.startsWith("admin") ?? false);

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

          if (isAdmin) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                "API Configuration",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.key),
              title: const Text("Groq API Key"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showGroqConfigDialog(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_queue),
              title: const Text("IBM Watson Credentials"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showWatsonConfigDialog(context, ref),
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

  Future<void> _showGroqConfigDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final secureStorage = ref.read(secureStorageServiceProvider);
    final currentKey = await secureStorage.getGroqApiKey() ?? '';
    final controller = TextEditingController(text: currentKey);

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Groq Configuration"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: "API Key",
                hintText: "gsk_...",
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () async {
              final apiKey = controller.text.trim();
              await secureStorage.saveGroqApiKey(apiKey);

              // Global Sync
              final firebase = ref.read(firebaseServiceProvider);
              await firebase.saveGlobalConfig('groq', {'apiKey': apiKey});

              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _showWatsonConfigDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final secureStorage = ref.read(secureStorageServiceProvider);
    final creds = await secureStorage.getWatsonCredentials();

    final apiKeyController = TextEditingController(text: creds['apiKey'] ?? '');
    final projectIdController = TextEditingController(
      text: creds['projectId'] ?? '',
    );
    final urlController = TextEditingController(text: creds['url'] ?? '');

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Watson Configuration"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: apiKeyController,
                decoration: const InputDecoration(
                  labelText: "API Key",
                  hintText: "IBM Cloud IAM Key",
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: projectIdController,
                decoration: const InputDecoration(
                  labelText: "Project ID",
                  hintText: "Watson Studio Project GUID",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: "Service URL (Optional)",
                  hintText: "Leave empty for US-South",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () async {
              final apiKey = apiKeyController.text.trim();
              final projectId = projectIdController.text.trim();
              final url = urlController.text.trim();

              await secureStorage.saveWatsonCredentials(
                apiKey: apiKey,
                projectId: projectId,
                url: url,
              );

              // Global Sync
              final firebase = ref.read(firebaseServiceProvider);
              await firebase.saveGlobalConfig('watson', {
                'apiKey': apiKey,
                'projectId': projectId,
                'url': url,
              });

              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}
