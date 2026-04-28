import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/transporte_log.dart';
import '../services/log_service.dart';

class RelatorioScreen extends StatefulWidget {
  const RelatorioScreen({super.key});

  @override
  State<RelatorioScreen> createState() => _RelatorioScreenState();
}

class _RelatorioScreenState extends State<RelatorioScreen> {
  List<TransporteLog> _logsDoDia = [];
  DateTime _dataSelecionada = DateTime.now();
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _carregando = true);
    // Busca apenas os logs da data selecionada no calendário
    final dados = await LogService.obterLogsPorData(_dataSelecionada);
    setState(() {
      _logsDoDia = dados;
      _carregando = false;
    });
  }

  Future<void> _selecionarData(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() => _dataSelecionada = picked);
      _carregarDados();
    }
  }

  /// Calcula o tempo ocioso: Saída da entrega ATUAL menos Chegada da entrega ANTERIOR
  Duration _calcularTempoOcioso(int index) {
    if (index == 0) return Duration.zero;
    final atual = _logsDoDia[index];
    final anterior = _logsDoDia[index - 1];
    
    // Se o motorista saiu ANTES de ter chegado na anterior (erro de log), retorna zero
    if (atual.horaSaida.isBefore(anterior.horaChegada)) return Duration.zero;
    
    return atual.horaSaida.difference(anterior.horaChegada);
  }

  /// Restaura a funcionalidade de exportação com escolha de formato
  Future<void> _exportar(String formato) async {
    try {
      final dir = await getTemporaryDirectory();
      String extensao = formato;
      String fileName = "Relatorio_${DateFormat('dd_MM_yy').format(_dataSelecionada)}.$extensao";
      String path = "${dir.path}/$fileName";
      String finalPath = "";

      if (formato == 'xlsx') {
        finalPath = await LogService.gerarExcel(_logsDoDia, path);
      } else if (formato == 'csv') {
        finalPath = await LogService.gerarCSV(_logsDoDia, path);
      } else {
        // Formato TXT
        String conteudo = await LogService.gerarRelatorioTexto(_logsDoDia, "dia");
        final file = File(path);
        await file.writeAsString(conteudo);
        finalPath = file.path;
      }

      await Share.shareXFiles([XFile(finalPath)], text: 'Souza transporte - Relatórios');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Abre o menu de escolha de formato de arquivo
  void _abrirMenuExportacao() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Escolha o formato de exportação', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart, color: Colors.green),
            title: const Text('Excel (.xlsx)'),
            onTap: () { Navigator.pop(context); _exportar('xlsx'); },
          ),
          ListTile(
            leading: const Icon(Icons.grid_on, color: Colors.blue),
            title: const Text('CSV (.csv)'),
            onTap: () { Navigator.pop(context); _exportar('csv'); },
          ),
          ListTile(
            leading: const Icon(Icons.description, color: Colors.orange),
            title: const Text('Texto Simples (.txt)'),
            onTap: () { Navigator.pop(context); _exportar('txt'); },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatadorDia = DateFormat('EEEE, dd/MM/yyyy', 'pt_BR');
    final formatadorHora = DateFormat('HH:mm');

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Relatórios'),
        backgroundColor: const Color(0xFF00ACC1),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selecionarData(context),
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () => _abrirMenuExportacao(),
          )
        ],
      ),
      body: _carregando 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildResumoHeader(formatadorDia),
                Expanded(
                  child: _logsDoDia.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _logsDoDia.length,
                          itemBuilder: (context, index) {
                            final log = _logsDoDia[index];
                            final tempoOcioso = _calcularTempoOcioso(index);
                            return _buildTimelineItem(log, tempoOcioso, index == 0, formatadorHora);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildResumoHeader(DateFormat df) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(df.format(_dataSelecionada).toUpperCase(), 
               style: const TextStyle(fontSize: 12, color: Colors.cyan, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${_logsDoDia.length} Coletas Realizadas', 
               style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(TransporteLog log, Duration ocioso, bool isPrimeiro, DateFormat hf) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isPrimeiro) _buildIdleIndicator(ocioso, log.localInicio),
        Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ExpansionTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF00ACC1),
              child: Icon(Icons.local_shipping, color: Colors.white, size: 20),
            ),
            title: Text('${log.localInicio} ➔ ${log.destino}', 
                        style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Tempo: ${log.tempoTrajeto.inMinutes} min | ${hf.format(log.horaSaida)} - ${hf.format(log.horaChegada)}'),
            childrenPadding: const EdgeInsets.all(16),
            children: [
              _infoRow("Motorista:", log.nomeMotorista),
              _infoRow("ID Amostra:", log.id),
              if(log.observacao.isNotEmpty) _infoRow("Obs:", log.observacao),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIdleIndicator(Duration ocioso, String local) {
    return Padding(
      padding: const EdgeInsets.only(left: 35, top: 10, bottom: 10),
      child: Row(
        children: [
          Container(width: 2, height: 30, color: Colors.orange.shade300),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('OCIOSO EM $local', 
                   style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
              Text('${ocioso.inMinutes} min parado aguardando check-out', 
                   style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          const Text('Nenhuma atividade para esta data.'),
        ],
      ),
    );
  }

  Widget _infoRow(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.grey)), Text(v, style: const TextStyle(fontWeight: FontWeight.bold))]),
  );
}