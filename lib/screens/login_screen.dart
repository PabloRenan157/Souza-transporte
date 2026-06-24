import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/log_provider.dart';
import 'admin_dashboard_screen.dart';
import 'trabalho_check_screen.dart'; // Tela intermediária para motoristas

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _senhaVisivel = false;
  bool _verificandoSessao = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verificarSessaoAtiva();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  void _verificarSessaoAtiva() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final String? tipoSessao = await authProvider.carregarSessaoSalva();

    if (mounted) {
      if (tipoSessao != null) {
        if (tipoSessao == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
          );
        } else if (tipoSessao == 'motorista') {
          final nomeLogado = authProvider.usuarioLogado?.nomeCompleto ?? 'Motorista';
          final usernameLogado = authProvider.usuarioLogado?.username ?? '';

          final logProvider = Provider.of<LogProvider>(context, listen: false);
          logProvider.definirUsuarioAtivo(usernameLogado, nomeLogado);
          await logProvider.carregarHistoricoLocal();

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const TrabalhoCheckScreen(),
            ),
          );
        }
      } else {
        setState(() => _verificandoSessao = false);
      }
    }
  }

  void _tentarAutenticar() async {
    if (_formKey.currentState!.validate()) {
      final String usernameDigitado = _usernameController.text.trim().toLowerCase();
      final String senhaDigitada = _senhaController.text;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Tratamento especial de Admin: Busca no banco através do AuthProvider
      if (usernameDigitado == 'admin') {
        final sucessoAdmin = await authProvider.realizarLoginAdmin(usernameDigitado, senhaDigitada);
        if (mounted) {
          if (sucessoAdmin) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Credenciais de Administrador inválidas!'), backgroundColor: Colors.red),
            );
          }
        }
        return;
      }

      // Autenticação Padrão do Motoboy no Supabase (Turno e equipe agora são definidos na tela seguinte)
      final sucesso = await authProvider.realizarLogin(
        usernameDigitado, 
        senhaDigitada, 
        'Uvaranas - Laboratório', // Inicializa com default, editável na tela intermediária
        'Dia'
      );

      if (mounted) {
        if (sucesso) {
          final nomeLogado = authProvider.usuarioLogado?.nomeCompleto ?? 'Motorista';
          final usernameLogado = authProvider.usuarioLogado?.username ?? '';

          final logProvider = Provider.of<LogProvider>(context, listen: false);
          logProvider.definirUsuarioAtivo(usernameLogado, nomeLogado);
          await logProvider.carregarHistoricoLocal();

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const TrabalhoCheckScreen(),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro: Credenciais inválidas ou utilizador inexistente!'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    if (_verificandoSessao) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00ACC1))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.local_shipping_rounded, size: 80, color: Color(0xFF00ACC1)),
                const SizedBox(height: 12),
                const Text(
                  'SOUZA TRANSPORTES',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF263238)),
                ),
                const SizedBox(height: 32),

                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Utilizador',
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF00ACC1)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (valor) => (valor == null || valor.trim().isEmpty) ? 'Insira o utilizador' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _senhaController,
                  obscureText: !_senhaVisivel,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF00ACC1)),
                    suffixIcon: IconButton(
                      icon: Icon(_senhaVisivel ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (valor) => (valor == null || valor.isEmpty) ? 'Insira a senha' : null,
                ),
                const SizedBox(height: 24),

                authProvider.isProcessando
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF00ACC1)))
                    : ElevatedButton(
                        onPressed: _tentarAutenticar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00ACC1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Iniciar Sessão', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}