import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/transporte_log.dart';
import '../providers/log_provider.dart';

/// Ecrã de Faturamento Mensal e Histórico de Atividades do Motorista.
/// Permite visualizar ganhos acumulados, ciclos de faturamento, sincronizar dados e acompanhar tempos de permanência.
class RelatorioScreen extends StatefulWidget {
  const RelatorioScreen({super.key});

  @override
  State<RelatorioScreen> createState() => _RelatorioScreenState();
}

class _RelatorioScreenState extends State<RelatorioScreen> {
  DateTime _dataFaturamentoRef = DateTime.now();
  bool _sincronizando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LogProvider>(context, listen: false).carregarHistoricoLocal();
    });
  }

  /// Gera a formatação textual do ciclo de faturamento (do dia 20 do mês anterior ao dia 19 deste mês)
  String _obterIntervaloFaturamentoFormatado() {
    DateTime inicio;
    DateTime fim;

    if (_dataFaturamentoRef.day >= 20) {
      inicio = DateTime(_dataFaturamentoRef.year, _dataFaturamentoRef.month, 20);
      fim = DateTime(_dataFaturamentoRef.year, _dataFaturamentoRef.month + 1, 19);
    } else {
      inicio = DateTime(_dataFaturamentoRef.year, _dataFaturamentoRef.month - 1, 20);
      fim = DateTime(_dataFaturamentoRef.year, _dataFaturamentoRef.month, 19);
    }

    final formatador = DateFormat('dd/MM/yyyy');
    return '${formatador.format(inicio)} à ${formatador.format(fim)}';
  }

  /// Força o envio em lote das corridas offline guardadas localmente para a nuvem
  Future<void> _sincronizarFilaPendentes() async {
    setState(() => _sincronizando = true);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('A enviar dados para a nuvem do Supabase...'),
        backgroundColor: Color(0xFF00ACC1),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final logProvider = Provider.of<LogProvider>(context, listen: false);
      await logProvider.tentarSincronizarFilaPendentes();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sincronização concluída com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha ao conectar com o servidor: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sincronizando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final logProvider = Provider.of<LogProvider>(context);
    final corridasNoPeriodo = logProvider.obterLogsNoPeriodoFaturamento(_dataFaturamentoRef);
    final double faturamentoViagens = corridasNoPeriodo.fold<double>(0.0, (soma, c) => soma + c.valorCorrida);

    // Conta quantos logs no histórico pessoal local ainda não estão no Supabase
    final int logsPendentes = logProvider.historicoPessoal.where((l) => !l.sincronizado).length;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Faturamento Mensal'),
        backgroundColor: const Color(0xFF00ACC1),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, 
        actions: [
          // Botão manual de Sincronização na barra superior
          IconButton(
            icon: _sincronizando 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.cloud_upload_rounded),
            tooltip: "Sincronizar com o Banco",
            onPressed: _sincronizando ? null : _sincronizarFilaPendentes,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: "Mudar Mês",
            onPressed: () async {
              final DateTime? selecionada = await showDatePicker(
                context: context,
                initialDate: _dataFaturamentoRef,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
              );
              if (selecionada != null) {
                setState(() {
                  _dataFaturamentoRef = selecionada;
                });
              }
            },
          )
        ],
      ),
      body: logProvider.carregando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00ACC1)))
          : Column(
              children: [
                // --- SEÇÃO DINÂMICA: Alerta de Viagens Pendentes de Sincronização ---
                if (logsPendentes > 0) ...[
                  Container(
                    width: double.infinity,
                    color: Colors.amber.shade100,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.cloud_off_rounded, color: Colors.amber.shade900, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Tens $logsPendentes viagem(ns) offline aguardando sincronização.',
                            style: TextStyle(
                              color: Colors.amber.shade900, 
                              fontWeight: FontWeight.bold, 
                              fontSize: 12
                            ),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            minimumSize: const Size(60, 30),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _sincronizando ? null : _sincronizarFilaPendentes,
                          child: const Text('ENVIAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],

                _buildCardPainelFaturamento(
                  faturamentoViagens,
                  corridasNoPeriodo.length,
                ),
                Expanded(
                  child: corridasNoPeriodo.isEmpty
                      ? const Center(child: Text('Nenhuma atividade neste ciclo de faturamento.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: corridasNoPeriodo.length,
                          itemBuilder: (context, index) {
                            final log = corridasNoPeriodo[index];
                            return _buildTimelineItem(log);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildCardPainelFaturamento(double total, int qtd) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white, 
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PERÍODO DE FATURAMENTO MENSAL', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyan)),
          Text(_obterIntervaloFaturamentoFormatado(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$qtd Viagens', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const Text('Total Realizado', style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('R\$ ${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.teal)),
                  const Text('Faturamento Total', style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(TransporteLog log) {
    // Calcula a diferença exata de tempo na paragem intermédia caso exista check-in e check-out
    int tempoPermanenciaMinutos = 0;
    if (log.horaCheckInIntermediario != null && log.horaCheckOutIntermediario != null) {
      tempoPermanenciaMinutos = log.horaCheckOutIntermediario!.difference(log.horaCheckInIntermediario!).inMinutes;
    }

    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  log.equipeLinha,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF263238)),
                ),
                Row(
                  children: [
                    // INDICADOR DE STATUS DA NUVEM (Sincronizado = Verde, Pendente/Offline = Cinza)
                    Icon(
                      log.sincronizado ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                      size: 18,
                      color: log.sincronizado ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        'R\$ ${log.valorCorrida.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                    ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Rota: ${log.localInicio} ➔ ${log.destino}',
              style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
            ),
            const SizedBox(height: 4),
            Text(
              'Duração Total: ${log.tempoTrajeto.inMinutes} min (Saída: ${DateFormat('HH:mm').format(log.horaSaida)} | Chegada: ${DateFormat('HH:mm').format(log.horaChegada)})',
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              'Amostras (${log.idAmostras.length}): ${log.idAmostras.join(', ')}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            
            // --- DETALHAMENTO DE TEMPO NO LOCAL INTERMÉDIO (Check-In Duplo) ---
            if (log.horaCheckInIntermediario != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50, 
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, color: Colors.orange, size: 15),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Parado em: ${log.localIntermediario ?? "Upa Santana"}',
                            style: TextStyle(fontSize: 11, color: Colors.orange.shade900, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Entrada: ${DateFormat('HH:mm:ss').format(log.horaCheckInIntermediario!)}',
                          style: const TextStyle(fontSize: 10, color: Colors.black87),
                        ),
                        Text(
                          log.horaCheckOutIntermediario != null 
                              ? 'Saída: ${DateFormat('HH:mm:ss').format(log.horaCheckOutIntermediario!)}'
                              : 'Saída: Não registada',
                          style: const TextStyle(fontSize: 10, color: Colors.black87),
                        ),
                      ],
                    ),
                    if (log.horaCheckOutIntermediario != null) ...[
                      const Divider(height: 12, color: Colors.orange),
                      Text(
                        'Tempo parado no local: $tempoPermanenciaMinutos min',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                      ),
                    ],
                  ],
                ),
              )
            ],
            if (log.observacao.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Obs: ${log.observacao}', style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey))
            ]
          ],
        ),
      ),
    );
  }
}