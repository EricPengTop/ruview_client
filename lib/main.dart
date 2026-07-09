import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_locale.dart';
import 'services/notification_service.dart';
import 'services/ws_service.dart';
import 'screens/home_screen.dart';

/// RuView WiFi 感知 Flutter 客户端入口
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  runApp(const ProviderScope(child: RuViewApp()));
}

/// macOS/桌面端鼠标拖动滚动行为
class DesktopScrollBehavior extends MaterialScrollBehavior {
  const DesktopScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.mouse,
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}

/// 应用根组件 (主题/路由/Provider)
class RuViewApp extends ConsumerWidget {
  const RuViewApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(appStateProvider.select((s) => s.isDarkMode));
    final s = ref.watch(appStringsProvider);

    return ScrollConfiguration(
      behavior: const DesktopScrollBehavior(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: s.getString('app_title'),
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
        darkTheme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true, brightness: Brightness.dark),
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true, brightness: Brightness.light),
        home: const HomeScreen(),
      ),
    );
  }
}
