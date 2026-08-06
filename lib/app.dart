import 'package:flutter/material.dart';
export 'constants.dart';
import 'constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/setup_provider.dart';
import 'providers/gateway_provider.dart';
import 'providers/node_provider.dart';
import 'screens/splash_screen.dart';
import 'widgets/paid_provider_approval_dialog.dart';

final GlobalKey<NavigatorState> plawieNavigatorKey =
    GlobalKey<NavigatorState>();

class PlawieApp extends StatelessWidget {
  const PlawieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SetupProvider()),
        ChangeNotifierProvider(create: (_) => GatewayProvider(), lazy: false),
        ChangeNotifierProxyProvider<GatewayProvider, NodeProvider>(
          create: (_) => NodeProvider(),
          lazy: false,
          update: (_, gatewayProvider, nodeProvider) {
            nodeProvider!.onGatewayStateUpdate(gatewayProvider);
            return nodeProvider;
          },
        ),
      ],
      child: MaterialApp(
        navigatorKey: plawieNavigatorKey,
        title: 'Plawie',
        debugShowCheckedModeBanner: false,
        theme: _buildLightTheme(),
        darkTheme: _buildDarkTheme(),
        themeMode: ThemeMode.system,
        initialRoute: "/",
        routes: {
          "/": (context) => const SplashScreen(),
        },
        builder: (context, child) => PaidProviderApprovalHost(
          navigatorKey: plawieNavigatorKey,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.statusGreen,
        onPrimary: Colors.black,
        secondary: AppColors.darkMetallic,
        onSecondary: AppColors.inverseText,
        surface: AppColors.darkSurface,
        onSurface: AppColors.inverseText,
        onSurfaceVariant: AppColors.mutedText,
        error: AppColors.statusRed,
        onError: AppColors.inverseText,
        outline: AppColors.darkBorder,
      ),
      textTheme: textTheme.apply(
        bodyColor: AppColors.inverseText,
        displayColor: AppColors.inverseText,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.darkBg,
        foregroundColor: AppColors.inverseText,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.inverseText,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.statusGreen,
          foregroundColor: AppColors.inverseText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.inverseText.withValues(alpha: 0.7),
          side: const BorderSide(color: AppColors.darkBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.statusGreen,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.statusGreen, width: 2),
        ),
        filled: true,
        fillColor: AppColors.darkSurfaceAlt,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.statusGreen;
          }
          return AppColors.statusGrey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.statusGreen.withAlpha(80);
          }
          return AppColors.darkBorder;
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.statusGreen,
        linearTrackColor: AppColors.darkBorder,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkSurfaceAlt,
        contentTextStyle: GoogleFonts.inter(color: AppColors.inverseText),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.mutedText,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.statusGreen;
          }
          return AppColors.statusGrey;
        }),
      ),
    );
  }

  ThemeData _buildLightTheme() {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.statusGreen,
        onPrimary: Colors.black,
        secondary: AppColors.statusGreen,
        onSecondary: Colors.black,
        surface: AppColors.lightBg,
        onSurface: Color(0xFF0A0A0A),
        onSurfaceVariant: AppColors.mutedText,
        error: AppColors.statusRed,
        onError: AppColors.inverseText,
        outline: AppColors.lightBorder,
      ),
      textTheme: textTheme.apply(
        bodyColor: AppColors.primaryText,
        displayColor: AppColors.primaryText,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.lightBg,
        foregroundColor: const Color(0xFF0A0A0A),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0A0A0A),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.lightBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.lightBorder),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.statusGreen,
          foregroundColor: AppColors.inverseText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryText,
          side: const BorderSide(color: AppColors.lightBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.statusGreen,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.statusGreen, width: 2),
        ),
        filled: true,
        fillColor: AppColors.lightSurface,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.statusGreen;
          }
          return AppColors.statusGrey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.statusGreen.withAlpha(80);
          }
          return AppColors.lightBorder;
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.statusGreen,
        linearTrackColor: AppColors.lightBorder,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightBorder,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.lightBorder),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF0A0A0A),
        contentTextStyle: GoogleFonts.inter(color: AppColors.inverseText),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.mutedText,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.statusGreen;
          }
          return AppColors.statusGrey;
        }),
      ),
    );
  }
}
