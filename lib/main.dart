import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:s_transporte/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializa os dados de data para Português
  await initializeDateFormatting('pt_BR', null);

  runApp(const MedExpressApp());
}

class MedExpressApp extends StatelessWidget {
  const MedExpressApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedExpress Logistics',
      debugShowCheckedModeBanner: false,
      // CONFIGURAÇÃO CRUCIAL PARA CORRIGIR O ERRO DA IMAGEM:
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      // ------------------------------------------------
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00ACC1)),
        useMaterial3: true, 
      ),
      home: const HomeScreen(),
    );
  }
}