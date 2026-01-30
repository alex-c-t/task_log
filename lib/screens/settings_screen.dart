import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/backup_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _handleRestore(BuildContext context) async {
    final scaffold = ScaffoldMessenger.of(context);
    try {
      final success = await BackupService.restoreDatabase();
      if (success) {
        if (context.mounted) {
           showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const AlertDialog(
              title: Text('Restore Complete'),
              content: Text('The database has been restored successfully.\n\nPlease restart the application to reload the data.'),
            ),
          );
        }
      }
    } catch (e) {
      scaffold.showSnackBar(SnackBar(content: Text('Restore Failed: $e')));
    }
  }

  Future<void> _handleBackup(BuildContext context) async {
    final scaffold = ScaffoldMessenger.of(context);
    try {
      await BackupService.exportDatabase();
    } catch (e) {
      scaffold.showSnackBar(SnackBar(content: Text('Backup Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Colors.transparent), // Blend with theme
            accountName: Text('Tasklet User', style: TextStyle(color: Colors.grey)), 
            accountEmail: null,
            currentAccountPicture: CircleAvatar(
              child: Icon(Icons.person),
            ),
          ),
          
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Appearance', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Toggle application theme'),
            value: isDark,
            onChanged: (val) => themeProvider.toggleTheme(val),
          ),

          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Data Management', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Backup Database'),
            subtitle: const Text('Export your data to a file'),
            onTap: () => _handleBackup(context),
          ),
          ListTile(
            leading: const Icon(Icons.upload),
            title: const Text('Restore Database'),
            subtitle: const Text('Import data from a backup file (Requires Restart)'),
            onTap: () => _handleRestore(context),
          ),
        ],
      ),
    );
  }
}
