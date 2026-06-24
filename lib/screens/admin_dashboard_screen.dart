import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/admin_provider.dart';
import '../providers/auth_provider.dart'; 
import '../models/transporte_log.dart';
import '../services/log_service.dart';
import 'cadastro_motorista_screen.dart';
import 'relatorio_motorista_screen.dart';
import 'login_screen.dart'; 

/// Painel de Controlo do Administrador.
/// Permite gerir tarifas globais, visualizar métricas de desempenho e exportar relatórios formatados.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _filtroTempo = 'dia'; 
  String _motoristaSelecionado = 'Todos';
  bool _processandoConfig = false;
  
  final _v1Controller = TextEditingController();
  final _v2Controller = TextEditingController();
  final _intervaloVazioController = TextEditingController(); 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);
      await adminProvider.carregarDadosGlobais();
      
      setState(() {
        _v1Controller.text = adminProvider.valor1.toStringAsFixed(2);
        _v2Controller.text = adminProvider.valor2.toStringAsFixed(2);
      });
      await _carregarIntervaloVazio();
    });
  }

  @override
  void dispose() {
    _v1Controller.dispose();
    _v2Controller.dispose();
    _intervaloVazioController.dispose();
    super.dispose();
  }

  /// Procura o intervalo dinâmico de trajetos vazios salvo na nuvem
  Future<void> _carregarIntervaloVazio() async {
    try {
      final response = await Supabase.instance.client
          .from('configuracoes')
          .select('valor')
          .eq('chave', 'config_intervalo_vazio')
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _intervaloVazioController.text = response['valor'].toString();
        });
      } else if (mounted) {
        _intervaloVazioController.text = '60';
      }
    } catch (e) {
      if (mounted) _intervaloVazioController.text = '60';
    }
  }

  /// Limpa as credenciais de sessão guardadas e envia o utilizador de volta ao Login
  Future<bool> _confirmarLogout(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminar Sessão'),
        content: const Text('Deseja realmente sair da plataforma administrativa?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Sair', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;

    if (confirmar && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.realizarLogout();
      
      if (mounted) {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
    return false; 
  }

  /// Salva todas as configurações de tarifas e frequências diretamente na nuvem
  void _salvarConfiguracoesGlobais() async {
    final double? v1 = double.tryParse(_v1Controller.text);
    final double? v2 = double.tryParse(_v2Controller.text);
    final int? minutosVazio = int.tryParse(_intervaloVazioController.text);

    if (v1 == null || v2 == null || minutosVazio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insira valores numéricos válidos.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _processandoConfig = true);

    try {
      // 1. Atualiza tarifas no provedor administrativo
      await Provider.of<AdminProvider>(context, listen: false).atualizarTarifas(v1, v2);
      
      // 2. Atualiza o tempo limite do trajeto sem coleta no Supabase
      await Supabase.instance.client.from('configuracoes').upsert({
        'chave': 'config_intervalo_vazio',
        'valor': minutosVazio.toString(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configurações atualizadas na nuvem com sucesso!'), backgroundColor: Colors.green),
        );
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gravar dados na nuvem: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _processandoConfig = false);
    }
  }

  /// Exporta o histórico filtrado como planilha Excel (.xlsx) profissional
  void _exportarRelatorioFiltrado(List<TransporteLog> corridas) async {
    if (corridas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum dado disponível no filtro selecionado para exportar!'), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      final directory = await getTemporaryDirectory();
      final String dataHojeStr = DateFormat('dd_MM_yyyy').format(DateTime.now());
      final String nomeArquivo = 'Relatorio_Admin_Souza_${dataHojeStr}.xlsx';
      final String caminhoCompleto = '${directory.path}/$nomeArquivo';

      await LogService.gerarExcel(corridas, caminhoCompleto);
      await LogService.partilharArquivo(
        caminhoCompleto, 
        'Olá! Segue em anexo o relatório analítico consolidado extraído diretamente do painel da Souza Transportes em $dataHojeStr.'
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar planilha: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Constrói o cabeçalho decorado com identidade corporativa do painel administrativo
  Widget _buildPainelBoasVindas() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF263238), Color(0xFF37474F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF00ACC1).withOpacity(0.15),
            child: const Icon(Icons.admin_panel_settings_rounded, size: 36, color: Color(0xFF00ACC1)),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PAINEL DE ADMINISTRADOR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00ACC1),
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Souza Transportes',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Transportes Ponta Grossa',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);
    
    // Lista de motoristas cadastrados mapeados para String com tipagem correta
    final List<String> listaMotoristasUnicos = [
      'Todos', 
      ...adminProvider.motoristas.map((m) => m['nome_completo'] as String)
    ];
    
    // Aplica o filtro de listagem reativa
    final corridasFiltradas = adminProvider.filtrarCorridas(
      filtroTempo: _filtroTempo,
      filtroMotorista: _motoristaSelecionado,
    );

    // Métricas financeiras e de performance agrupadas
    final totalEntregas = corridasFiltradas.length;
    final totalFaturamento = corridasFiltradas.fold<double>(0.0, (soma, c) => soma + c.valorCorrida);
    final tempoMinutos = corridasFiltradas.fold<int>(0, (soma, c) => soma + c.tempoTrajeto.inMinutes);

    return WillPopScope(
      onWillPop: () => _confirmarLogout(context),
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text('Gestão de Frota', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF263238),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Sair do Painel',
            onPressed: () => _confirmarLogout(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Exportar Relatório Excel',
              onPressed: () => _exportarRelatorioFiltrado(corridasFiltradas),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Sincronizar Dados',
              onPressed: () async {
                await adminProvider.carregarDadosGlobais();
                await _carregarIntervaloVazio();
              },
            ),
          ],
        ),
        body: adminProvider.carregando || _processandoConfig
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF263238)))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPainelBoasVindas(), // Nova secção de destaque do topo
                    const SizedBox(height: 16),
                    _buildConfigGlobalTarifasEIntervalo(),
                    const SizedBox(height: 16),
                    _buildFiltrosEletivos(listaMotoristasUnicos),
                    const SizedBox(height: 16),
                    
                    // Seção de KPIs coloridos originais com ícones dinâmicos reconstruídos
                    const Text('Métricas da Frota', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey)),
                    const SizedBox(height: 8),
                    _buildGridDeCardsKPI(totalEntregas, 'R\$ ${totalFaturamento.toStringAsFixed(2)}', '$tempoMinutos min'),
                    const SizedBox(height: 20),
                    
                    _buildSecaoDeOpcoesDeNavegacao(adminProvider, adminProvider.motoristas),
                    const SizedBox(height: 20),
                    
                    const Text('Atividades Recentes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey)),
                    const SizedBox(height: 8),
                    _buildListaDeLogsRecentes(corridasFiltradas),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildConfigGlobalTarifasEIntervalo() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ajuste de Preços de Corridas (R\$)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _v1Controller, 
                    keyboardType: TextInputType.number, 
                    decoration: const InputDecoration(labelText: 'Tarifa Uvaranas', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _v2Controller, 
                    keyboardType: TextInputType.number, 
                    decoration: const InputDecoration(labelText: 'Tarifa Sta Paula', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            const Text('Frequência de Trajeto Vazio (Nuvem)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _intervaloVazioController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Intervalo (minutos) de trajetos sem coleta', 
                border: OutlineInputBorder(), 
                prefixIcon: Icon(Icons.timer),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45), 
                backgroundColor: const Color(0xFF00ACC1), 
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('SALVAR CONFIGURAÇÕES NA NUVEM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              onPressed: _salvarConfiguracoesGlobais,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltrosEletivos(List<String> motoristas) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filtros Administrativos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _motoristaSelecionado,
              decoration: const InputDecoration(labelText: 'Condutor Específico', border: OutlineInputBorder()),
              items: motoristas.map((String valor) => DropdownMenuItem<String>(value: valor, child: Text(valor))).toList(),
              onChanged: (novoValor) => setState(() => _motoristaSelecionado = novoValor ?? 'Todos'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _filtroTempo,
              decoration: const InputDecoration(labelText: 'Período Operacional', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'dia', child: Text('Hoje')),
                DropdownMenuItem(value: 'semana', child: Text('Esta Semana')),
                DropdownMenuItem(value: 'mes', child: Text('Este Mês')),
                DropdownMenuItem(value: 'todos', child: Text('Histórico Geral')),
              ],
              onChanged: (novoValor) => setState(() => _filtroTempo = novoValor ?? 'dia'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridDeCardsKPI(int total, String faturamento, String tempoTotal) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildKpiCard('Corridas', total.toString(), Icons.motorcycle_rounded, Colors.blue),
          const SizedBox(width: 8),
          _buildKpiCard('Faturamento', faturamento, Icons.payments_rounded, Colors.green),
          const SizedBox(width: 8),
          _buildKpiCard('Tempo em Rota', tempoTotal, Icons.timer_rounded, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color cor) {
    return Container(
      width: 120,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1))],
      ),
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: cor, size: 24),
          const Spacer(),
          Text(
            value, 
            maxLines: 1, 
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 2),
          Text(
            label, 
            maxLines: 1, 
            overflow: TextOverflow.ellipsis, 
            style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSecaoDeOpcoesDeNavegacao(AdminProvider adminProvider, List<Map<String, dynamic>> motoristas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Motoristas Cadastrados', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey)),
            TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF00ACC1)),
              label: const Text('Novo Motorista', style: TextStyle(color: Color(0xFF00ACC1), fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CadastroMotoristaScreen())),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 135, // CORRIGIDO: De 110 para 135 para evitar o RenderFlex overflow de 9px no pe do card!
          child: motoristas.isEmpty
              ? const Center(child: Text('Nenhum condutor cadastrado.', style: TextStyle(color: Colors.grey, fontSize: 12)))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: motoristas.length,
                  itemBuilder: (context, index) {
                    final m = motoristas[index];
                    final nome = m['nome_completo'] as String;
                    final username = m['username'] as String;
                    
                    return Container(
                      width: 160,
                      margin: const EdgeInsets.only(right: 12),
                      child: Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                nome, 
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), 
                                maxLines: 1, 
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text('@$username', style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF263238),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(120, 32),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context, 
                                    MaterialPageRoute(
                                      builder: (_) => RelatorioMotoristaScreen(username: username, nomeCompleto: nome),
                                    ),
                                  );
                                },
                                child: const Text('Ver Extrato', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildListaDeLogsRecentes(List<TransporteLog> logs) {
    if (logs.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(child: Text('Nenhuma corrida registrada para este filtro.', style: TextStyle(color: Colors.grey, fontSize: 12))),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: logs.length > 10 ? 10 : logs.length, 
      itemBuilder: (context, index) {
        final log = logs[index];
        return Card(
          elevation: 0.5,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFECEFF1),
              child: Icon(Icons.motorcycle_rounded, color: Colors.blueGrey),
            ),
            title: Text(
              '${log.localInicio} ➔ ${log.destino}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Text(
              'Motorista: ${log.nomeMotorista}\nTaxa: R\$ ${log.valorCorrida.toStringAsFixed(2)} | Duração: ${log.tempoTrajeto.inMinutes} min',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: Text(
              '${log.tempoTrajeto.inMinutes}m',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00ACC1)),
            ),
          ),
        );
      },
    );
  }
}