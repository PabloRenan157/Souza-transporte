import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/log_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/admin_provider.dart';
import 'screens/login_screen.dart';
import 'config/env.dart'; // Importação segura do ficheiro de ambiente contendo as chaves privadas

/// Sanitiza e corrige formatações incorretas na URL de conexão do Supabase
String sanitizeSupabaseUrl(String rawUrl) {
  String url = rawUrl.trim();
  if (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  if (url.endsWith('/rest/v1')) {
    url = url.substring(0, url.indexOf('/rest/v1'));
  }
  return url;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Consome as chaves de forma protegida diretamente do ficheiro de ambiente local (ignorado pelo Git)
  final String cleanUrl = sanitizeSupabaseUrl(Env.supabaseUrl);
  final String cleanKey = Env.supabaseAnonKey.trim();

  // Inicializa o cliente do Supabase na nuvem
  await Supabase.initialize(
    url: cleanUrl,
    anonKey: cleanKey,
  );

  // Inicializa os padrões de formatação regional para português de Portugal/Brasil
  await initializeDateFormatting('pt_BR', null);

  runApp(
    MultiProvider(
      providers: [
        // LogProvider: Gere o estado de corridas e a fila offline-first por motorista
        ChangeNotifierProvider(create: (_) => LogProvider()..carregarHistoricoLocal()),
        
        // AuthProvider: Trata da sessão ativa dos estafetas com segurança na nuvem
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        
        // AdminProvider: Disponibilizado de forma global para evitar erros de redundância na árvore de widgets
        ChangeNotifierProvider(create: (_) => AdminProvider()), 
      ],
      child: const SouzaTransportesApp(),
    ),
  );
}

class SouzaTransportesApp extends StatelessWidget {
  const SouzaTransportesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Souza Transportes',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00ACC1)),
        useMaterial3: true, 
      ),
      home: const LoginScreen(),
    );
  }
}