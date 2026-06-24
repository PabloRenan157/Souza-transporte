import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transporte_log.dart';
import '../services/log_service.dart';

/// Provider que gerencia as operações de faturamento, faturamento mensal customizado e compensação de turnos.
class LogProvider with ChangeNotifier {
  List<TransporteLog> _historicoPessoal = [];
  bool _carregando = false;
  String _usernameAtivo = '';
  String _nomeCompletoAtivo = '';

  List<TransporteLog> get historicoPessoal => _historicoPessoal;
  bool get carregando => _carregando;
  String get usernameAtivo => _usernameAtivo;

  void definirUsuarioAtivo(String username, String nomeCompleto) {
    _usernameAtivo = username;
    _nomeCompletoAtivo = nomeCompleto;
  }

  Future<void> carregarHistoricoLocal() async {
    if (_usernameAtivo.isEmpty) return;
    
    _carregando = true;
    notifyListeners();

    try {
      await LogService.limparLogsAntigos(_usernameAtivo);
      _historicoPessoal = await LogService.obterHistorico(_usernameAtivo);
    } catch (e) {
      debugPrint("Erro ao carregar histórico local: $e");
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  /// Requisito 4: Filtra os logs para o ciclo de faturamento dinâmico (dia 20 do mês passado ao dia 19 deste mês)
  List<TransporteLog> obterLogsNoPeriodoFaturamento(DateTime dataRef) {
    DateTime inicio;
    DateTime fim;

    if (dataRef.day >= 20) {
      inicio = DateTime(dataRef.year, dataRef.month, 20, 0, 0, 0);
      fim = DateTime(dataRef.year, dataRef.month + 1, 19, 23, 59, 59);
    } else {
      inicio = DateTime(dataRef.year, dataRef.month - 1, 20, 0, 0, 0);
      fim = DateTime(dataRef.year, dataRef.month, 19, 23, 59, 59);
    }

    return _historicoPessoal.where((log) {
      return log.horaChegada.isAfter(inicio) && log.horaChegada.isBefore(fim);
    }).toList();
  }

  /// Requisito 5: Calcula a compensação garantida de mínimo de 10 corridas na Linha Uvaranas
  double calcularCompensacaoUvaranas(DateTime dataRef, String turno) {
    final corridasDoDia = _historicoPessoal.where((log) {
      bool mesmoDia = log.horaChegada.year == dataRef.year &&
          log.horaChegada.month == dataRef.month &&
          log.horaChegada.day == dataRef.day;
      bool mesmaLinha = log.equipeLinha == 'Uvaranas - Laboratório';
      bool mesmoTurno = log.turno == turno;
      return mesmoDia && mesmaLinha && mesmoTurno && !log.isExtra;
    }).toList();

    int totalConcluidas = corridasDoDia.length;
    if (totalConcluidas > 0 && totalConcluidas < 10) {
      int faltantes = 10 - totalConcluidas;
      return faltantes * 14.00; // Multiplica pela tarifa base da linha de Uvaranas (R$ 14,00)
    }
    return 0.0;
  }

  Future<void> registarNovaCorrida(TransporteLog log) async {
    if (_usernameAtivo.isEmpty) return;

    await LogService.salvarLog(log, _usernameAtivo);
    await carregarHistoricoLocal();

    // Sincroniza com a nuvem do Supabase
    await _enviarParaNuvem(log);
  }

  Future<bool> _enviarParaNuvem(TransporteLog log) async {
    try {
      await Supabase.instance.client.from('corridas').insert(log.toSupabaseMap());
      await LogService.atualizarStatusSincronizacao(log.id, true, _usernameAtivo);
      await carregarHistoricoLocal();
      return true;
    } catch (e) {
      debugPrint("Falha ao sincronizar com a nuvem. Mantida offline: $e");
      return false;
    }
  }

  Future<void> tentarSincronizarFilaPendentes() async {
    if (_usernameAtivo.isEmpty) return;

    final logsNaoSincronizados = _historicoPessoal.where((l) => !l.sincronizado).toList();
    if (logsNaoSincronizados.isEmpty) return;

    for (var log in logsNaoSincronizados) {
      await _enviarParaNuvem(log);
    }
  }
}