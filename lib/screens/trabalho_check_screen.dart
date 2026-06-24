import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/log_provider.dart';
import 'rota_screen.dart';
import 'relatorio_screen.dart';
import 'login_screen.dart';

/// Ecrã de Gestão de Jornada de Trabalho (Check-In / Check-Out) e Navegação do Motorista.
/// Centraliza o fluxo operacional em um menu inferior reativo com persistência.
class TrabalhoCheckScreen extends StatefulWidget {
  const TrabalhoCheckScreen({super.key});

  @override
  State<TrabalhoCheckScreen> createState() => _TrabalhoCheckScreenState();
}

class _TrabalhoCheckScreenState extends State<TrabalhoCheckScreen> {
  int _indiceAba = 0;

  bool _checkedIn = false;
  String _equipeSelecionada = 'Uvaranas - Laboratório';
  String _turnoSelecionado = 'Dia';
  String? _horaCheckInStr;
  String? _horaCheckOutStr;

  @override
  void initState() {
    super.initState();
    _carregarEstadoJornada();
  }

  /// Recupera o estado operacional persistido localmente para o motorista ativo
  Future<void> _carregarEstadoJornada() async {
    final prefs = await SharedPreferences.getInstance();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final username = authProvider.usuarioLogado?.username ?? 'motorista';

    setState(() {
      _checkedIn = prefs.getBool('jornada_checked_in_$username') ?? false;
      _equipeSelecionada = prefs.getString('jornada_equipe_$username') ?? 'Uvaranas - Laboratório';
      _turnoSelecionado = prefs.getString('jornada_turno_$username') ?? 'Dia';
      _horaCheckInStr = prefs.getString('jornada_hora_in_$username');
      _horaCheckOutStr = prefs.getString('jornada_hora_out_$username');
    });
  }

  /// Salva o estado da jornada localmente para consistência caso o app seja fechado
  Future<void> _salvarEstadoJornada() async {
    final prefs = await SharedPreferences.getInstance();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final username = authProvider.usuarioLogado?.username ?? 'motorista';

    await prefs.setBool('jornada_checked_in_$username', _checkedIn);
    await prefs.setString('jornada_equipe_$username', _equipeSelecionada);
    await prefs.setString('jornada_turno_$username', _turnoSelecionado);
    
    if (_horaCheckInStr != null) {
      await prefs.setString('jornada_hora_in_$username', _horaCheckInStr!);
    } else {
      await prefs.remove('jornada_hora_in_$username');
    }
    
    if (_horaCheckOutStr != null) {
      await prefs.setString('jornada_hora_out_$username', _horaCheckOutStr!);
    } else {
      await prefs.remove('jornada_hora_out_$username');
    }
  }

  void _realCheckIn() {
    setState(() {
      _checkedIn = true;
      _horaCheckInStr = DateFormat('HH:mm:ss').format(DateTime.now());
      _horaCheckOutStr = null;
    });
    _salvarEstadoJornada();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Jornada de trabalho iniciada com sucesso!'), backgroundColor: Colors.green),
    );
  }

  void _realCheckOut() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Fim de Turno'),
        content: const Text('Deseja realmente registrar o check-out e finalizar a sua jornada de trabalho ativa?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finalizar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;

    if (confirmar) {
      setState(() {
        _checkedIn = false;
        _horaCheckOutStr = DateFormat('HH:mm:ss').format(DateTime.now());
      });
      _salvarEstadoJornada();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-out confirmado! Jornada de hoje concluída.'), backgroundColor: Colors.blueGrey),
      );
    }
  }

  void _confirmarLogout() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deslogar'),
        content: const Text('Deseja realmente sair do aplicativo e encerrar sua sessão segura?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;

    if (confirmar) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.realizarLogout();
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    }
  }

  Widget _obterTelaAtiva(String nomeCompleto) {
    switch (_indiceAba) {
      case 0:
        return _buildAbaControleJornada();
      case 1:
        if (!_checkedIn) {
          return _buildTelaPlaceholderSemJornada();
        }
        return RotaScreen(
          motorista: nomeCompleto,
          equipeLinha: _equipeSelecionada,
          turno: _turnoSelecionado,
        );
      case 2:
        return const RelatorioScreen();
      default:
        return _buildAbaControleJornada();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final nomeCompleto = authProvider.usuarioLogado?.nomeCompleto ?? 'Motorista';

    return Scaffold(
      body: _obterTelaAtiva(nomeCompleto),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceAba,
        selectedItemColor: const Color(0xFF00ACC1),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _indiceAba = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.badge_rounded), label: 'Jornada'),
          BottomNavigationBarItem(icon: Icon(Icons.navigation_rounded), label: 'Nova Viagem'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_rounded), label: 'Histórico'),
        ],
      ),
    );
  }

  Widget _buildAbaControleJornada() {
    final authProvider = Provider.of<AuthProvider>(context);
    final nomeCompleto = authProvider.usuarioLogado?.nomeCompleto ?? 'Motorista';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Minha Jornada'),
        backgroundColor: const Color(0xFF00ACC1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new_rounded),
            tooltip: 'Sair da Conta',
            onPressed: _confirmarLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCartaoBoasVindas(nomeCompleto),
            const SizedBox(height: 24),
            _buildConfiguracaoDeEquipeForm(),
            const SizedBox(height: 24),
            _buildCardMetricasTurnoAtivo(),
            const SizedBox(height: 32),
            _buildBotoesDeControleDePonto(),
          ],
        ),
      ),
    );
  }

  Widget _buildCartaoBoasVindas(String nome) {
    return Card(
      elevation: 0,
      color: Colors.cyan.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: Color(0xFF00ACC1),
              child: Icon(Icons.person, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Olá, $nome', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF006064))),
                  const Text('Gerencie seus registros de ponto diários.', style: TextStyle(color: Colors.cyan, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfiguracaoDeEquipeForm() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Configurar Escopo de Trabalho', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _equipeSelecionada,
              decoration: const InputDecoration(labelText: 'Equipe / Linha Ativa', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'Uvaranas - Laboratório', child: Text('Uvaranas - Laboratório')),
                DropdownMenuItem(value: 'Santa Paula / Santana / Laboratório', child: Text('Santa Paula / Santana / Lab')),
              ],
              // CORRIGIDO: onChanged como null desativa de forma totalmente compatível com versões antigas do Flutter
              onChanged: _checkedIn ? null : (v) {
                setState(() {
                  _equipeSelecionada = v!;
                });
                _salvarEstadoJornada();
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _turnoSelecionado,
              decoration: const InputDecoration(labelText: 'Turno de Trabalho', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'Dia', child: Text('Dia (07:30 às 19:30)')),
                DropdownMenuItem(value: 'Noite', child: Text('Noite (19:30 às 07:30)')),
              ],
              // CORRIGIDO: onChanged como null desativa de forma totalmente compatível com versões antigas do Flutter
              onChanged: _checkedIn ? null : (v) {
                setState(() {
                  _turnoSelecionado = v!;
                });
                _salvarEstadoJornada();
              },
            ),
            if (_checkedIn) ...[
              const SizedBox(height: 12),
              const Text(
                'Nota: Bloqueado para edição durante jornada ativa. Faça Check-out para alterar.',
                style: TextStyle(fontSize: 10, color: Colors.red, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCardMetricasTurnoAtivo() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Registros de Hoje', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey)),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Check-In de Jornada:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                Text(_horaCheckInStr ?? '--:--:--', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Check-Out de Jornada:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                Text(_horaCheckOutStr ?? '--:--:--', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotoesDeControleDePonto() {
    return _checkedIn
        ? ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.alarm_off_rounded),
            label: const Text('REGISTRAR CHECK-OUT (FINALIZAR JORNADA)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            onPressed: _realCheckOut,
          )
        : ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.alarm_on_rounded),
            label: const Text('REGISTRAR CHECK-IN (INICIAR JORNADA)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            onPressed: _realCheckIn,
          );
  }

  Widget _buildTelaPlaceholderSemJornada() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Nova Viagem'),
        backgroundColor: const Color(0xFF00ACC1),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_clock_rounded, size: 80, color: Colors.amber),
              const SizedBox(height: 16),
              const Text(
                'Jornada Não Iniciada',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
              ),
              const SizedBox(height: 8),
              const Text(
                'Atenção! Você precisa registrar o check-in de entrada na aba "Jornada" para que o sistema ative e blinde o seu trajeto operacional antes de iniciar qualquer transporte.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00ACC1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  setState(() {
                    _indiceAba = 0;
                  });
                },
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('IR PARA REGISTRO DE JORNADA', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}