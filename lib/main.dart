import 'package:flutter/material.dart';
import 'presentation/screens/home/home_screen.dart';

void main() {
  runApp(const MysteryLaneApp());
}

class MysteryLaneApp extends StatelessWidget {
  const MysteryLaneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MYsteryLane',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0284C7),
          brightness: Brightness.light,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
