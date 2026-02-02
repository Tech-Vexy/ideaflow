import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui/auth_gate.dart';
import 'firebase_options.dart';
import 'providers.dart';
import 'services/hive_service.dart';
import 'package:quick_actions/quick_actions.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final hiveService = HiveService();
  await hiveService.init();

  runApp(
    ProviderScope(
      overrides: [hiveServiceProvider.overrideWithValue(hiveService)],
      child: const IdeaFlowApp(),
    ),
  );
}

class IdeaFlowApp extends ConsumerStatefulWidget {
  const IdeaFlowApp({super.key});

  @override
  ConsumerState<IdeaFlowApp> createState() => _IdeaFlowAppState();
}

class _IdeaFlowAppState extends ConsumerState<IdeaFlowApp> {
  @override
  void initState() {
    super.initState();
    _initQuickActions();
  }

  void _initQuickActions() {
    const QuickActions quickActions = QuickActions();
    quickActions.initialize((shortcutType) {
      if (shortcutType == 'new_idea') {
        // Navigate to Flow tab (ConversationalScreen is index 0 of HomeScreen)
        // Since AuthGate loads HomeScreen, and HomeScreen defaults to index 0,
        // we might not need explicit navigation if we are freshly launching.
        // But if app is running, we might need a global key to navigate.
        // For simplicity, we'll let it just open.
        // Enhancement: We can use a GlobalKey<NavigatorState> or Riverpod to switch tabs.
        debugPrint('Quick Action: New Idea');
      }
    });

    quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(
        type: 'new_idea',
        localizedTitle: 'New Idea',
        icon:
            'add', // Ensure 'add' icon exists in android/app/src/main/res/drawable or ios/Runner/Assets.xcassets
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'IdeaFlow',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.grey[50], // Light background
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF6C63FF),
          secondary: Color(0xFF00E5FF),
          surface: Colors.white,
          onSurface: Colors.black87,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme)
            .copyWith(
              displayLarge: GoogleFonts.outfit(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              titleLarge: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C63FF), // Electric Violet
          secondary: Color(0xFF00E5FF), // Neon Cyan
          surface: Color(0xFF1E1E1E), // Darker Surface
          surfaceContainerHighest: Color(0x0DFFFFFF), // Glassy White Hint
          onSurface: Colors.white,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme)
            .copyWith(
              displayLarge: GoogleFonts.outfit(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              titleLarge: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              bodyLarge: GoogleFonts.inter(fontSize: 16),
              bodyMedium: GoogleFonts.inter(fontSize: 14),
            ),
      ),

      home: const AuthGate(),
    );
  }
}
