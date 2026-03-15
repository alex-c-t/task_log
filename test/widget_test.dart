import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:task_log/main.dart';
import 'package:task_log/providers/theme_provider.dart';
import 'package:task_log/providers/preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    // Initialize sqflite for ffi
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Initialize SharedPreferences with an empty mock
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App basic smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => PreferencesProvider()),
        ],
        child: const TaskLogApp(),
      ),
    );
    
    // Use pump instead of pumpAndSettle because some animations or async 
    // tasks might take time and pumpAndSettle might timeout.
    await tester.pump();

    // Verify that "Tasklet" is present
    expect(find.text('Tasklet'), findsAtLeast(1));
  });
}
