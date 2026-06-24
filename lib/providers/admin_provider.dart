import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transporte_log.dart';

/// Provedor correspondente ao arquivo 'lib/providers/admin_provider.dart' no seu VS Code.
/// Gerencia reativamente tarifas personalizáveis e dados agregados de faturamento.
class AdminProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _motoristas = [];
  List<TransporteLog> _todasAsCorridas = [];
  bool _carregando = false;

  double _valor1 = 15.00; // Tarifa Padrão Trajeto Simples
  double _valor2 = 25.00; // Tarifa Padrão Trajeto Upa-Upa

  List<Map<String, dynamic>> get motoristas => _motoristas;
  List<TransporteLog> get todasAsCorridas => _todasAsCorridas;
  bool get carregando => _carregando;
  double get valor1 => _valor1;
  double get valor2 => _valor2;

  /// Carrega motoristas, corridas e as configurações dinâmicas de tarifas salvos no Supabase
  Future<void> carregarDadosGlobais() async {
    _carregando = true;
    notifyListeners();

    try {
      // 1. Carrega tarifas do banco configuracoes
      final responseConfig = await _supabase.from('configuracoes').select();
      if (responseConfig != null && responseConfig is List) {
        for (var row in responseConfig) {
          if (row['chave'] == 'valor_1') {
            _valor1 = double.tryParse(row['valor'].toString()) ?? 15.00;
          } else if (row['chave'] == 'valor_2') {
            _valor2 = double.tryParse(row['valor'].toString()) ?? 25.00;
          }
        }
      }

      // 2. Busca motoristas ativos
      final responseMotoristas = await _supabase
          .from('motoristas')
          .select('id, username, nome_completo, created_at')
          .order('nome_completo', ascending: true);

      if (responseMotoristas != null) {
        _motoristas = List<Map<String, dynamic>>.from(responseMotoristas);
      }

      // 3. Busca todo o histórico de corridas
      final responseCorridas = await _supabase
          .from('corridas')
          .select()
          .order('hora_saida', ascending: false);

      if (responseCorridas != null) {
        final List<dynamic> listaCorridas = responseCorridas;
        _todasAsCorridas = listaCorridas
            .map((mapa) => TransporteLog.fromMap(mapa))
            .toList();
      }
    } catch (e) {
      debugPrint("Erro ao carregar dados administrativos: $e");
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  /// Salva novos valores globais de tarifas no Supabase
  Future<void> atualizarTarifas(double novoV1, double novoV2) async {
    _carregando = true;
    notifyListeners();

    try {
      await _supabase.from('configuracoes').upsert({'chave': 'valor_1', 'valor': novoV1});
      await _supabase.from('configuracoes').upsert({'chave': 'valor_2', 'valor': novoV2});
      
      _valor1 = novoV1;
      _valor2 = novoV2;
      
      await carregarDadosGlobais();
    } catch (e) {
      debugPrint("Erro ao atualizar tarifas: $e");
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  /// Cadastra novos motoristas no banco
  Future<bool> registarNovoMotorista({
    required String username,
    required String senha,
    required String nomeCompleto,
  }) async {
    _carregando = true;
    notifyListeners();

    try {
      final usernameLimpo = username.trim().toLowerCase();

      final existe = await _supabase
          .from('motoristas')
          .select('id')
          .eq('username', usernameLimpo)
          .maybeSingle();

      if (existe != null) {
        _carregando = false;
        notifyListeners();
        return false;
      }

      await _supabase.from('motoristas').insert({
        'username': usernameLimpo,
        'senha': senha.trim(),
        'nome_completo': nomeCompleto.trim(),
      });

      await carregarDadosGlobais();
      return true;
    } catch (e) {
      debugPrint("Erro ao registrar novo motorista: $e");
      _carregando = false;
      notifyListeners();
      return false;
    }
  }

  List<TransporteLog> filtrarCorridas({
    required String filtroTempo,
    String? filtroMotorista,
    DateTime? dataReferencia,
  }) {
    final DateTime ref = dataReferencia ?? DateTime.now();
    
    return _todasAsCorridas.where((corrida) {
      if (filtroMotorista != null && filtroMotorista != 'Todos') {
        if (corrida.nomeMotorista.toLowerCase() != filtroMotorista.toLowerCase()) {
          return false;
        }
      }

      final dataCorrida = corrida.horaChegada;
      if (filtroTempo == 'dia') {
        return dataCorrida.year == ref.year &&
            dataCorrida.month == ref.month &&
            dataCorrida.day == ref.day;
      } else if (filtroTempo == 'semana') {
        final diferencaDias = ref.difference(dataCorrida).inDays;
        return diferencaDias >= 0 && diferencaDias <= 7;
      } else if (filtroTempo == 'mes') {
        return dataCorrida.year == ref.year && dataCorrida.month == ref.month;
      }

      return true;
    }).toList();
  }
}