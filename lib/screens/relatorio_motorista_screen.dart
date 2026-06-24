import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/admin_provider.dart';
import '../models/transporte_log.dart';
import '../services/log_service.dart';

/// Ecrã de Monitoria e Insights de desempenho de um motorista específico no Admin.
/// Permite faturamento, acompanhamento logístico e exportação Excel/CSV com partilha nativa instantânea.
class RelatorioMotoristaScreen extends StatelessWidget {
  final String username;
  final String nomeCompleto;

  const RelatorioMotoristaScreen({
    super.key,
    required this.username,
    required this.nomeCompleto,
  });

  Duration _calcularTempoOciosoAcumulado(List<TransporteLog> logs) {
    if (logs.length < 2) return Duration.zero;

    final ordenados = List<TransporteLog>.from(logs);
    ordenados.sort((a, b) => a.horaSaida.compareTo(b.horaSaida));

    Duration totalOcioso = Duration.zero;

    for (int i = 1; i < ordenados.length; i++) {
      final atual = ordenados[i];
      final anterior = ordenados[i - 1];

      if (atual.horaSaida.isAfter(anterior.horaChegada)) {
        totalOcioso += atual.horaSaida.difference(anterior.horaChegada);
      }
    }

    return totalOcioso;
  }

  /// NOVO: Gera relatório específico do motorista e abre o compartilhador do WhatsApp/Email instantaneamente
  void _gerarEPartilharFicheiro(BuildContext context, List<TransporteLog> logs, String formato) async {
    try {
      final directory = await getTemporaryDirectory();
      final String dataHojeStr = DateFormat('dd_MM_yyyy').format(DateTime.now());
      final String nomeMotoristaHigienizado = nomeCompleto.replaceAll(' ', '_');
      
      // Nome explicativo (Relatorio_Motorista_Nome_Data_Formato)
      final String nomeFicheiro = 'Relatorio_Motorista_${nomeMotoristaHigienizado}_Geral_$dataHojeStr';
      
      String caminhoFinal = '';
      
      if (formato == 'xlsx') {
        caminhoFinal = '${directory.path}/$nomeFicheiro.xlsx';
        await LogService.gerarExcel(logs, caminhoFinal);
      } else {
        caminhoFinal = '${directory.path}/$nomeFicheiro.csv';
        await LogService.gerarCSV(logs, caminhoFinal);
      }

      // Abre diálogo de compartilhamento direto
      await LogService.partilharArquivo(
        caminhoFinal, 
        'Olá! Segue o extrato completo de corridas do motorista $nomeCompleto da Souza Transportes exportado em $dataHojeStr.'
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar/compartilhar ficheiro de relatório: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);
    final formatadorData = DateFormat('dd/MM/yyyy HH:mm');

    final corridasDoMotorista = adminProvider.filtrarCorridas(
      filtroTempo: 'todos',
      filtroMotorista: nomeCompleto,
    );

    final totalCorridas = corridasDoMotorista.length;
    final minutosVolante = corridasDoMotorista.fold<int>(0, (soma, c) => soma + c.tempoTrajeto.inMinutes);
    final tempoMedioCorrida = totalCorridas > 0 ? (minutosVolante / totalCorridas).toStringAsFixed(1) : '0';
    final tempoOciosoTotal = _calcularTempoOciosoAcumulado(corridasDoMotorista);

    final double faturamentoTotalAcumulado = corridasDoMotorista.fold<double>(0.0, (soma, c) => soma + c.valorCorrida);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(nomeCompleto),
        backgroundColor: const Color(0xFF263238),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.share_rounded),
            tooltip: "Exportar e Compartilhar",
            onSelected: (formato) => _gerarEPartilharFicheiro(context, corridasDoMotorista, formato),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'xlsx', child: Text('Compartilhar Excel (.xlsx)')),
              PopupMenuItem(value: 'csv', child: Text('Compartilhar CSV (.csv)')),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCartaoPerfilMotorista(totalCorridas, faturamentoTotalAcumulado),
            const SizedBox(height: 16),
            const Text('Insights de Performance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF263238))),
            const SizedBox(height: 12),
            _buildGridDeInsights(minutosVolante, tempoMedioCorrida, tempoOciosoTotal, faturamentoTotalAcumulado),
            const SizedBox(height: 24),
            const Text('Histórico Completo de Entregas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF263238))),
            const SizedBox(height: 8),
            _buildLogLinhaTempo(corridasDoMotorista, formatadorData),
          ],
        ),
      ),
    );
  }

  Widget _buildCartaoPerfilMotorista(int total, double faturamento) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 30,
              backgroundColor: Color(0xFFE0F7FA),
              child: Icon(Icons.person, size: 36, color: Color(0xFF00ACC1)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nomeCompleto, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  Text('utilizador: @$username', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.cyan.shade50, borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          '$total Corridas',
                          style: TextStyle(color: Colors.cyan.shade800, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          'A Pagar: R\$ ${faturamento.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridDeInsights(int minutosVolante, String media, Duration ocioso, double faturamento) {
    final horasOciosas = ocioso.inHours;
    final minutosOciososResiduo = ocioso.inMinutes % 60;
    
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _buildInsightCard('Faturamento Total', 'R\$ ${faturamento.toStringAsFixed(2)}', Icons.payments_rounded, Colors.green),
        _buildInsightCard('Tempo em Viagem', '$minutosVolante min', Icons.directions_bike_rounded, Colors.teal),
        _buildInsightCard('Duração Média', '$media min', Icons.av_timer_rounded, Colors.blue),
        _buildInsightCard('Tempo Ocioso Est.', '${horasOciosas}h ${minutosOciososResiduo}m', Icons.hourglass_empty_rounded, Colors.orange),
      ],
    );
  }

  Widget _buildInsightCard(String titulo, String valor, IconData icone, Color cor) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icone, color: cor, size: 20),
                const SizedBox(width: 6),
                Expanded(child: Text(titulo, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))),
              ],
            ),
            const SizedBox(height: 8),
            Text(valor, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogLinhaTempo(List<TransporteLog> logs, DateFormat df) {
    if (logs.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(child: Text('Nenhum registo de entrega cadastrado.', style: TextStyle(color: Colors.grey))),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return Card(
          elevation: 0.5,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const Icon(Icons.circle, size: 12, color: Color(0xFF00ACC1)),
            title: Text('${log.localInicio} ➔ ${log.destino}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text(
              'Saída: ${df.format(log.horaSaida)}\nChegada: ${df.format(log.horaChegada)}\nValor: R\$ ${log.valorCorrida.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: Text(
              '${log.tempoTrajeto.inMinutes}m',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
            ),
          ),
        );
      },
    );
  }
}