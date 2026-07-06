import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<PackageInfo> _getPackageInfo() {
    return PackageInfo.fromPlatform();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
      ),
      body: Center(
        child: FutureBuilder<PackageInfo>(
          future: _getPackageInfo(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Error loading version info');
            }
            if (!snapshot.hasData) {
              return const CircularProgressIndicator();
            }

            final info = snapshot.data!;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.task_alt, size: 80, color: Colors.blue),
                const SizedBox(height: 24),
                Text(
                  info.appName.isEmpty ? 'Tasklet' : info.appName,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Version ${info.version} (Build ${info.buildNumber})',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    'A simple and efficient tool to log your daily tasks and track your productivity across a calendar view.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
