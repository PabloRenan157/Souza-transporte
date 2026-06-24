import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/auth_provider.dart';
import '../providers/log_provider.dart';
import '../models/transporte_log.dart';
import 'relatorio_screen.dart';
import 'login_screen.dart';

/// Ecrã Unificado de Navegação para o Motorista.
/// Resolve o problema de "não ter como voltar à tela de corridas" usando abas inferiores profissionais.
class MotoristaHomeScreen extends StatefulWidget {
  const MotoristaHomeScreen({super.key});

  @override
  State<MotoristaHomeScreen> createState() => _MotoristaHomeScreenState();
}

class _MotoristaHomeScreenState extends State<MotoristaHomeScreen> {
  int _abaSelecionada = 0;

  final List<Widget> _telas = [
    const RegistrarCorridaTab(), // Ecrã de Registo de Viagens Ativo
    const RelatorioScreen(),     // Ecrã de Histórico Pessoal
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
   final nomeMotorista = authProvider.usuarioLogado?.nomeCompleto ?? 'Motorista';

    return Scaffold(
      body: IndexedStack(
        index: _abaSelecionada,
        children: _telas,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _abaSelecionada,
        selectedItemColor: const Color(0xFF00ACC1),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() => _abaSelecionada = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.navigation_rounded),
            label: 'Nova Corrida',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: 'Minhas Corridas',
          ),
        ],
      ),
    );
  }
}

/// Aba Principal onde o motoboy pode iniciar, simular e salvar uma corrida.
class RegistrarCorridaTab extends StatefulWidget {
  const RegistrarCorridaTab({super.key});

  @override
  State<RegistrarCorridaTab> createState() => _RegistrarCorridaTabState();
}

class _RegistrarCorridaTabState extends State<RegistrarCorridaTab> {
  final _formKey = GlobalKey<FormState>();
  final _origemController = TextEditingController();
  final _destinoController = TextEditingController();
  final _obsController = TextEditingController();
  
  bool _emCorrida = false;
  DateTime? _inicioTime;
  
  @override
  void dispose() {
    _origemController.dispose();
    _destinoController.dispose();
    _obsController.dispose();
    super.dispose();
  }

  void _alternarCorrida() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final logProvider = Provider.of<LogProvider>(context, listen: false);
    final nomeCondutor = authProvider.usuarioLogado?.nomeCompleto ?? 'Condutor Desconhecido';

    if (!_emCorrida) {
      if (_formKey.currentState!.validate()) {
        setState(() {
          _emCorrida = true;
          _inicioTime = DateTime.now();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Viagem iniciada! Registando trajeto GPS...'),
            backgroundColor: Color(0xFF00ACC1),
          ),
        );
      }
    } else {
      // Finalizar Viagem
      final fimTime = DateTime.now();
      final duracao = fimTime.difference(_inicioTime!);
      final novaCorridaId = 'AMS-${const Uuid().v4().substring(0, 5).toUpperCase()}';

      final novaCorrida = TransporteLog(
        id: novaCorridaId,
        localInicio: _origemController.text.trim(),
        destino: _destinoController.text.trim(),
        horaSaida: _inicioTime!,
        horaChegada: fimTime,
        tempoTrajeto: duracao,
        nomeMotorista: nomeCondutor,
        observacao: _obsController.text.trim(),
        sincronizado: false,
      );

      // Salva localmente e sincroniza automaticamente na nuvem
      await logProvider.registarNovaCorrida(novaCorrida);

      if (mounted) {
        setState(() {
          _emCorrida = false;
          _origemController.clear();
          _destinoController.clear();
          _obsController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Corrida finalizada com sucesso! Sincronizando com o banco de dados...'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final nomeMotorista = authProvider.usuarioLogado?.nomeCompleto ?? 'Motorista';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Registrar Viagem'),
        backgroundColor: const Color(0xFF00ACC1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app_rounded),
            tooltip: "Terminar Sessão",
            onPressed: () {
              authProvider.realizarLogout();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Identificação do Motoboy no Topo
              Card(
                elevation: 0,
                color: const Color(0xFFE0F7FA),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFF00ACC1),
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Motoboy: $nomeMotorista',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF006064), fontSize: 15),
                            ),
                            const Text('Sessão segura ativa no Supabase', style: TextStyle(color: Colors.cyan, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Simulador de Mapa Visivo Dinâmico
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blueGrey.shade200),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        _emCorrida ? Icons.local_shipping_rounded : Icons.map_rounded,
                        size: 72,
                        color: _emCorrida ? const Color(0xFF00ACC1) : Colors.blueGrey.shade400,
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _emCorrida ? 'VIAGEM EM CURSO...' : 'AGUARDANDO INÍCIO DE TRAJETO',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Campo de Origem
              TextFormField(
                controller: _origemController,
                enabled: !_emCorrida,
                decoration: InputDecoration(
                  labelText: 'Local de Origem',
                  prefixIcon: const Icon(Icons.my_location_rounded, color: Color(0xFF00ACC1)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (valor) => (valor == null || valor.isEmpty) ? 'Insira a origem' : null,
              ),
              const SizedBox(height: 16),

              // Campo de Destino
              TextFormField(
                controller: _destinoController,
                enabled: !_emCorrida,
                decoration: InputDecoration(
                  labelText: 'Destino da Entrega',
                  prefixIcon: const Icon(Icons.location_on_rounded, color: Color(0xFF00ACC1)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (valor) => (valor == null || valor.isEmpty) ? 'Insira o destino' : null,
              ),
              const SizedBox(height: 16),

              // Campo de Observações
              TextFormField(
                controller: _obsController,
                enabled: !_emCorrida,
                decoration: InputDecoration(
                  labelText: 'Observações (Opcional)',
                  prefixIcon: const Icon(Icons.edit_note_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),

              // Botão Dinâmico de Ação Principal (Iniciar / Finalizar)
              ElevatedButton.icon(
                onPressed: _alternarCorrida,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _emCorrida ? Colors.red : const Color(0xFF00ACC1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(_emCorrida ? Icons.stop_rounded : Icons.play_arrow_rounded),
                label: Text(
                  _emCorrida ? 'FINALIZAR ENTREGA' : 'INICIAR TRAJETO AGORA',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}