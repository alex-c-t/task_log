import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/preferences_provider.dart';
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

  Future<void> _handleJsonBackup(BuildContext context) async {
    final scaffold = ScaffoldMessenger.of(context);
    try {
      await BackupService.exportToJson();
    } catch (e) {
      scaffold.showSnackBar(SnackBar(content: Text('JSON Backup Failed: $e')));
    }
  }

  Future<void> _handleCsvBackup(BuildContext context) async {
    final scaffold = ScaffoldMessenger.of(context);
    try {
      await BackupService.exportToCsv();
    } catch (e) {
      scaffold.showSnackBar(SnackBar(content: Text('CSV Export Failed: $e')));
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
            child: Text('Developer Toggles (Mock)', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          ),
          Consumer<PreferencesProvider>(
            builder: (context, prefs, child) {
              return SwitchListTile(
                title: const Text('Active Pro Subscription'),
                subtitle: const Text('Simulates a server response for Pro Plan'),
                value: prefs.isProPlan,
                onChanged: (val) => prefs.updateProPlan(val),
                activeThumbColor: Colors.orange,
              );
            },
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Accent Color', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Colors.blue,
                      Colors.red,
                      Colors.green,
                      Colors.purple,
                      Colors.orange,
                      Colors.teal,
                      Colors.pink,
                      Colors.indigo,
                      Colors.amber,
                    ].map((color) {
                      final isSelected = themeProvider.seedColor.toARGB32() == color.toARGB32();
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () => themeProvider.updateSeedColor(color),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                              boxShadow: isSelected ? [BoxShadow(color: Colors.black26, blurRadius: 4)] : null,
                            ),
                            child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
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
            leading: const Icon(Icons.code),
            title: const Text('Export to JSON'),
            subtitle: const Text('Readable backup format for sharing'),
            onTap: () => _handleJsonBackup(context),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart),
            title: const Text('Export to CSV'),
            subtitle: const Text('Portable format for Spreadsheets'),
            onTap: () => _handleCsvBackup(context),
          ),
          ListTile(
            leading: const Icon(Icons.upload),
            title: const Text('Restore Data'),
            subtitle: const Text('Import from .db or .json file (Requires Restart)'),
            onTap: () => _handleRestore(context),
          ),
        ],
      ),
    );
  }
}
