import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/gps_service.dart';
import '../services/scanner_service.dart';
import '../services/notification_service.dart'; 
import '../providers/auth_provider.dart';
import '../providers/log_provider.dart';
import 'rastreamento_screen.dart';
import 'relatorio_screen.dart';
import 'login_screen.dart';

enum StatusCorrida { aguardandoForm, escaneando }

/// Tela de preenchimento de viagem do condutor.
/// O construtor recebe os dados da equipe de trabalho e do turno de forma blindada do Login/Jornada.
class RotaScreen extends StatefulWidget {
  final String motorista;
  final String equipeLinha;
  final String turno;

  const RotaScreen({
    super.key,
    required this.motorista,
    required this.equipeLinha,
    required this.turno,
  });

  @override
  State<RotaScreen> createState() => _RotaScreenState();
}

class _RotaScreenState extends State<RotaScreen> {
  StatusCorrida status = StatusCorrida.aguardandoForm;
  final GpsService _gpsService = GpsService();
  final _formKey = GlobalKey<FormState>();

  // ID de amostras com suas respectivas observações individuais
  final List<Map<String, String>> _amostrasComObs = [];
  final _novoIdController = TextEditingController();
  final _novaObsController = TextEditingController();

  String localOrigem = 'Ponto de Saída Uvaranas';
  String localDestino = 'Laboratório Central';

  double destLat = 0.0;
  double destLng = 0.0;
  double _valorCalculado = 14.00;

  bool _isSemColeta = false; 
  String _tipoVeiculo = 'Motoboy'; // 'Motoboy' ou 'Carro' (Requer senha)

  int _intervaloMinutosTrajetoVazio = 60;

  @override
  void initState() {
    super.initState();
    _carregarConfiguracaoTrajetoVazio();
    _atualizarLocaisPorEquipe();
  }

  @override
  void dispose() {
    _novoIdController.dispose();
    _novaObsController.dispose();
    super.dispose();
  }

  /// Carrega a frequência limite configurada na nuvem pelo administrador
  Future<void> _carregarConfiguracaoTrajetoVazio() async {
    try {
      final response = await Supabase.instance.client
          .from('configuracoes')
          .select()
          .eq('chave', 'config_intervalo_vazio')
          .maybeSingle();
      if (response != null) {
        setState(() {
          _intervaloMinutosTrajetoVazio = int.tryParse(response['valor'].toString()) ?? 60;
        });
      }
    } catch (e) {
      debugPrint('Erro ao buscar tempo de trajeto vazio do Supabase: $e');
    }
  }

  /// Dispara a notificação de simulação local nativa no celular corrigindo os parâmetros requeridos
  void _simularAlertaDeNotificacao() async {
    await NotificationService.dispararNotificacao(
      'Alerta de Trajeto Souza',
      'Faltam 10 minutos para iniciar seu trajeto sem coleta agendado de $_intervaloMinutosTrajetoVazio minutos!',
    );
  }

  /// Atualiza os locais de início/destino de acordo com a Equipe selecionada pelo motorista no login
  void _atualizarLocaisPorEquipe() {
    setState(() {
      if (widget.equipeLinha == 'Uvaranas - Laboratório') {
        localOrigem = 'Ponto de Saída Uvaranas';
        localDestino = 'Laboratório Central';
        _valorCalculado = _isSemColeta ? 11.00 : 14.00;
      } else if (widget.equipeLinha == 'Santa Paula / Santana / Laboratório') {
        localOrigem = 'Upa Santa Paula';
        localDestino = 'Laboratório Geral Alfredo Berger'; 
        _valorCalculado = _isSemColeta ? 11.00 : 16.00;
      } else {
        localOrigem = 'Laboratório Central';
        localDestino = 'Laboratório Geral Alfredo Berger';
        _valorCalculado = 11.00; 
      }
    });
  }

  /// Solicita validação de senha de administrador ao selecionar o tipo de veículo "Carro"
  void _validarSelecaoCarro(String? veiculo) async {
    if (veiculo == 'Carro') {
      final senhaController = TextEditingController();
      final bool? autorizado = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Autorização de Veículo (Carro)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Selecione veículo CARRO requer validação do administrador.', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              TextField(
                controller: senhaController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Senha do Administrador', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            TextButton(
              onPressed: () {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                if (auth.validarSenhaAdministrador(senhaController.text)) {
                  Navigator.pop(context, true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Senha de administrador incorreta!'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Autorizar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (autorizado == true) {
        setState(() {
          _tipoVeiculo = 'Carro';
          _atualizarLocaisPorEquipe();
        });
      } else {
        setState(() {
          _tipoVeiculo = 'Motoboy';
        });
      }
    } else {
      setState(() {
        _tipoVeiculo = 'Motoboy';
        _atualizarLocaisPorEquipe();
      });
    }
  }

  /// Adiciona uma amostra com observação individual à lista
  void _adicionarAmostra(String id, String obs) {
    if (id.trim().isEmpty) return;
    
    final existe = _amostrasComObs.any((a) => a['id'] == id.trim());
    if (existe) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta amostra já foi adicionada!'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _amostrasComObs.add({
        'id': id.trim(),
        'obs': obs.trim().isEmpty ? 'Sem observação' : obs.trim(),
      });
      _novoIdController.clear();
      _novaObsController.clear();
    });
  }

  /// Processa a leitura do QR Code injetando no campo de ID
  void _processarScan(String code) async {
    try {
      final Map<String, dynamic> data = jsonDecode(code.trim());
      final String idEscaneado = (data['id'] ?? data['id_amostra'] ?? 'S/ID').toString();
      final String obsEscaneada = (data['obs'] ?? data['observacao'] ?? '').toString();
      _adicionarAmostra(idEscaneado, obsEscaneada);
      setState(() {
        status = StatusCorrida.aguardandoForm;
      });
    } catch (e) {
      _adicionarAmostra(code.trim(), 'Lido via QR simples');
      setState(() {
        status = StatusCorrida.aguardandoForm;
      });
    }
  }

  void _iniciarCorrida() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isSemColeta && _amostrasComObs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adicione pelo menos uma amostra com observação para iniciar!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final localD = _gpsService.locaisFixos.firstWhere((l) => l.nome == localDestino);
    destLat = localD.coords.latitude;
    destLng = localD.coords.longitude;

    // Compila os IDs e observações em strings simples para enviar para a tela de rastreamento
    final List<String> idAmostrasFormatados = _amostrasComObs.map((a) {
      return '${a['id']} (${a['obs']})';
    }).toList();

    // Como as observações agora são individuais por amostra, unificamos no log geral
    final String observacaoCompilada = _isSemColeta 
        ? "Trajeto Sem Coleta" 
        : _amostrasComObs.map((a) => "ID: ${a['id']} [${a['obs']}]").join(' | ');

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => RastreamentoScreen(
          destLat: destLat,
          destLng: destLng,
          destinoNome: localDestino,
          motorista: widget.motorista,
          observacao: observacaoCompilada,
          localInicioNome: localOrigem,
          idAmostras: idAmostrasFormatados, 
          valorCorrida: _valorCalculado,
          equipeLinha: widget.equipeLinha,
          turno: widget.turno,
          tipoVeiculo: _tipoVeiculo,
          isExtra: false, 
          isSemColeta: _isSemColeta,
        ),
      ),
    );

    setState(() {
      _amostrasComObs.clear();
      _isSemColeta = false;
      _atualizarLocaisPorEquipe();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Nova Viagem'),
        backgroundColor: const Color(0xFF00ACC1),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Trocar Equipe/Jornada',
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const RelatorioScreen())),
          ),
        ],
      ),
      body: status == StatusCorrida.escaneando
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Escanear Código de Barras / QR Code", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 20),
                  Container(
                    height: 300,
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFF00ACC1), width: 2)),
                    child: ScannerDevice(onCodeScanned: _processarScan),
                  ),
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: () => setState(() => status = StatusCorrida.aguardandoForm),
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    label: const Text("CANCELAR LEITURA", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCartaoHeaderJornada(),
                    const SizedBox(height: 16),

                    _buildDropdownVeiculos(),
                    const Divider(height: 32),

                    // Seção de Amostras (Apenas se não for viagem vazia)
                    if (!_isSemColeta) ...[
                      const Text(
                        "Adicionar Coletas Individuais",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey),
                      ),
                      const SizedBox(height: 12),
                      _buildInputAmostraComObs(),
                      const SizedBox(height: 12),
                      const Text(
                        "Lista de Amostras para esta Viagem",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      _buildAmostrasChipsList(),
                      const SizedBox(height: 16),
                    ],

                    _buildControleToggles(),
                    const SizedBox(height: 16),

                    _buildPainelFinanceiroExibicao(),
                    const SizedBox(height: 24),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C853),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text("CONFIRMAR E INICIAR TRAJETO", style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _iniciarCorrida,
                    ),
                    const SizedBox(height: 20),
                    
                    // Botão para simular pop-up local de notificação nativa
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: Colors.blueGrey),
                      icon: const Icon(Icons.alarm_on_rounded),
                      label: const Text('TESTAR NOTIFICAÇÃO NATIVA (10 MIN ANTES)'),
                      onPressed: _simularAlertaDeNotificacao,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCartaoHeaderJornada() {
    return Card(
      elevation: 0,
      color: Colors.cyan.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.badge_rounded, color: Color(0xFF00ACC1)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.motorista} | ${widget.turno}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF00838F)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.route_rounded, color: Colors.blueGrey, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Equipe: ${widget.equipeLinha}',
                    style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownVeiculos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Veículo Utilizado nesta Viagem', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _tipoVeiculo,
          decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12)),
          items: const [
            DropdownMenuItem(value: 'Motoboy', child: Text('Motoboy')),
            DropdownMenuItem(value: 'Carro', child: Text('Carro (Requer liberação Admin)')),
          ],
          onChanged: _validarSelecaoCarro,
        ),
      ],
    );
  }

  Widget _buildInputAmostraComObs() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _novoIdController,
                  decoration: const InputDecoration(
                    labelText: 'ID da Amostra',
                    prefixIcon: Icon(Icons.tag),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF00ACC1), size: 28),
                onPressed: () => setState(() => status = StatusCorrida.escaneando),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _novaObsController,
            decoration: const InputDecoration(
              labelText: 'Observação desta Amostra',
              prefixIcon: Icon(Icons.comment_rounded),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00ACC1), foregroundColor: Colors.white),
            icon: const Icon(Icons.add),
            label: const Text('ADICIONAR COLETA'),
            onPressed: () => _adicionarAmostra(_novoIdController.text, _novaObsController.text),
          ),
        ],
      ),
    );
  }

  Widget _buildAmostrasChipsList() {
    if (_amostrasComObs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'Nenhuma amostra adicionada a esta viagem.',
          style: TextStyle(
            fontSize: 12, 
            color: Colors.grey, 
            fontStyle: FontStyle.italic, // CORRIGIDO: de style: para fontStyle:
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: _amostrasComObs.map((amostra) {
        return Chip(
          backgroundColor: Colors.teal.shade50,
          side: BorderSide(color: Colors.teal.shade100),
          label: Text(
            '${amostra['id']} (${amostra['obs']})',
            style: TextStyle(fontSize: 11, color: Colors.teal.shade900, fontWeight: FontWeight.bold),
          ),
          onDeleted: () {
            setState(() {
              _amostrasComObs.remove(amostra);
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildControleToggles() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Trajeto Sem Coleta (Viagem Vazia)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: const Text('Faturamento de R\$ 11,00 para entrega sem amostras', style: TextStyle(fontSize: 10)),
          activeColor: const Color(0xFF00ACC1),
          value: _isSemColeta,
          onChanged: (bool valor) {
            setState(() {
              _isSemColeta = valor;
              _atualizarLocaisPorEquipe();
            });
          },
        ),
      ],
    );
  }

  Widget _buildPainelFinanceiro() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Taxa a receber p/ corrida:', style: TextStyle(color: Colors.teal, fontSize: 11, fontWeight: FontWeight.bold)),
              Text(
                'R\$ ${_valorCalculado.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Text(
              _isSemColeta 
                  ? 'Trajeto Sem Coleta' 
                  : (widget.equipeLinha.contains('Uvaranas') ? 'Linha Uvaranas' : 'Linha Santa Paula'),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPainelFinanceiroExibicao() {
    return _buildPainelFinanceiro();
  }
}