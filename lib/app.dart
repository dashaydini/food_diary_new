import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

class TasteKeeperApp extends StatelessWidget {
  const TasteKeeperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TasteKeeper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.brown,
        scaffoldBackgroundColor: const Color(0xffF7F6F3),
      ),
      home: const HomeScreen(),
    );
  }
}