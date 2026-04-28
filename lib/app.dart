import 'package:flutter/material.dart';
import 'package:s_transporte/screens/home_screen.dart';

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Transporte de Amostras',
      home: const HomeScreen(),
    );
  }
}