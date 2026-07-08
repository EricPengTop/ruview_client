import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: RuViewApp()));
}

class RuViewApp extends StatelessWidget {
  const RuViewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RuView 客户端',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const HomeScreen(),
    );
  }
}
