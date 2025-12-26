import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const routeName = "/settings";

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      await context.read<AuthProvider>().logout();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, "/login", (_) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final email = auth.user?.email ?? "";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text("Account"),
            subtitle: Text(email.isEmpty ? "Signed in" : email),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.download_outlined),
            title: const Text("Allow saving photos"),
            subtitle:
                const Text("Show the download button in full-screen viewer"),
            value: auth.allowDownloads,
            onChanged: (v) => context.read<AuthProvider>().setAllowDownloads(v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.star_outline),
            title: const Text("Show ratings"),
            subtitle: const Text("Show star rating UI on photo pages"),
            value: auth.showRatings,
            onChanged: (v) => context.read<AuthProvider>().setShowRatings(v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_none),
            title: const Text("Challenge reminders"),
            subtitle: const Text("Enable reminders for active challenges"),
            value: auth.challengeReminders,
            onChanged: (v) =>
                context.read<AuthProvider>().setChallengeReminders(v),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text("Privacy & Safety"),
            subtitle: const Text("Reporting, visibility, and downloads"),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Privacy & Safety"),
                  content: const Text(
                    "• You can report photos from the photo menu.\n"
                    "• Uploader identity may be visible.\n"
                    "• Photo downloads depend on permissions and the toggle above.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("OK"),
                    ),
                  ],
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("About FotoFocus"),
            subtitle: const Text("Version & app info"),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: "FotoFocus",
                applicationVersion: "1.0.0",
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: () => _confirmLogout(context),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              "Delete account permanently",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
            ),
            subtitle: const Text("This cannot be undone."),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) {
                  final ctrl = TextEditingController();
                  return AlertDialog(
                    title: const Text("Delete account?"),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "This will permanently delete your account and all your data.",
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Type "DELETE" to confirm',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: ctrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: 'DELETE',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor:
                              Colors.white, // ✅ makes text readable
                          textStyle: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          if (ctrl.text.trim() == "DELETE") {
                            Navigator.pop(context, true);
                          }
                        },
                        child: const Text("Delete"),
                      ),
                    ],
                  );
                },
              );

              if (ok != true) return;

              try {
                await context
                    .read<AuthProvider>()
                    .deleteAccount(); // add this method below
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (_) => false);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Delete failed: $e")),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
