import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Motoboy {
  final String id;
  final String username;
  final String nomeCompleto;

  Motoboy({
    required this.id,
    required this.username,
    required this.nomeCompleto,
  });
}

/// Provedor que controla a sessão ativa do motorista, equipe blindada e validações de administrador.
class AuthProvider with ChangeNotifier {
  Motoboy? _usuarioLogado;
  bool _processando = false;
  String _equipeAtiva = 'Uvaranas - Laboratório';
  String _turnoAtivo = 'Dia';

  Motoboy? get usuarioLogado => _usuarioLogado;
  bool get isAuthenticated => _usuarioLogado != null;
  bool get isProcessando => _processando;
  String get equipeAtiva => _equipeAtiva;
  String get turnoAtivo => _turnoAtivo;

  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _keyUserId = 'sessao_user_id';
  static const String _keyUsername = 'sessao_username';
  static const String _keyNomeCompleto = 'sessao_nome_completo';
  static const String _keySessaoTipo = 'sessao_tipo';
  static const String _keyEquipe = 'sessao_equipe';
  static const String _keyTurno = 'sessao_turno';

  /// Autentica o motoboy em tempo real, salvando a equipe e o turno selecionados no login.
  Future<bool> realizarLogin(String username, String password, String equipe, String turno) async {
    _processando = true;
    notifyListeners();

    try {
      final usernameSujo = username.trim().toLowerCase();

      // Busca na tabela 'motoristas' do Supabase
      final response = await _supabase
          .from('motoristas')
          .select()
          .eq('username', usernameSujo)
          .maybeSingle();

      if (response != null) {
        final String senhaBanco = response['senha'] ?? '';

        if (senhaBanco == password) {
          _usuarioLogado = Motoboy(
            id: response['id'].toString(),
            username: response['username'],
            nomeCompleto: response['nome_completo'] ?? 'Motorista',
          );

          _equipeAtiva = equipe;
          _turnoAtivo = turno;

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_keyUserId, _usuarioLogado!.id);
          await prefs.setString(_keyUsername, _usuarioLogado!.username);
          await prefs.setString(_keyNomeCompleto, _usuarioLogado!.nomeCompleto);
          await prefs.setString(_keySessaoTipo, 'motorista');
          await prefs.setString(_keyEquipe, equipe);
          await prefs.setString(_keyTurno, turno);

          _processando = false;
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint("Erro crítico durante a autenticação no Supabase: $e");
    }

    _processando = false;
    notifyListeners();
    return false;
  }

  /// Realiza login de Admin consultando a tabela 'administradores' (ou 'motoristas' com username admin) no Supabase.
  Future<bool> realizarLoginAdmin(String username, String password) async {
    _processando = true;
    notifyListeners();

    try {
      final usernameSujo = username.trim().toLowerCase();

      // Tenta consultar uma tabela de administradores ou motorista com flag/username admin no Supabase
      final response = await _supabase
          .from('motoristas')
          .select()
          .eq('username', usernameSujo)
          .maybeSingle();

      if (response != null) {
        final String senhaBanco = response['senha'] ?? '';
        final bool isAdmin = response['is_admin'] ?? (response['username'] == 'admin');

        if (senhaBanco == password && isAdmin) {
          _usuarioLogado = Motoboy(
            id: response['id'].toString(),
            username: response['username'],
            nomeCompleto: response['nome_completo'] ?? 'Administrador',
          );

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_keyUserId, 'admin');
          await prefs.setString(_keyUsername, 'admin');
          await prefs.setString(_keyNomeCompleto, _usuarioLogado!.nomeCompleto);
          await prefs.setString(_keySessaoTipo, 'admin');

          _processando = false;
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint("Erro ao autenticar admin no Supabase, aplicando fallback local para testes: $e");
      // Fallback local seguro caso a coluna 'is_admin' não esteja criada na sua estrutura do Supabase ainda
      if (username == 'admin' && password == 'admin') {
        _usuarioLogado = Motoboy(
          id: 'admin',
          username: 'admin',
          nomeCompleto: 'Administrador Souza',
        );
        await registrarSessaoAdmin();
        _processando = false;
        notifyListeners();
        return true;
      }
    }

    _processando = false;
    notifyListeners();
    return false;
  }

  bool validarSenhaAdministrador(String password) {
    return password == "admin123" || password == "admin";
  }

  Future<void> registrarSessaoAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, 'admin');
    await prefs.setString(_keyUsername, 'admin');
    await prefs.setString(_keyNomeCompleto, 'Administrador');
    await prefs.setString(_keySessaoTipo, 'admin');
  }

  /// Permite atualizar dinamicamente a equipe e turno definidos na tela intermediária
  Future<void> atualizarDadosSessaoTrabalho(String equipe, String turno) async {
    _equipeAtiva = equipe;
    _turnoAtivo = turno;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEquipe, equipe);
    await prefs.setString(_keyTurno, turno);
    notifyListeners();
  }

  Future<String?> carregarSessaoSalva() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? id = prefs.getString(_keyUserId);
      final String? username = prefs.getString(_keyUsername);
      final String? nomeCompleto = prefs.getString(_keyNomeCompleto);
      final String? tipo = prefs.getString(_keySessaoTipo);
      final String? equipe = prefs.getString(_keyEquipe);
      final String? turno = prefs.getString(_keyTurno);

      if (id != null && username != null && nomeCompleto != null) {
        _usuarioLogado = Motoboy(
          id: id,
          username: username,
          nomeCompleto: nomeCompleto,
        );
        _equipeAtiva = equipe ?? 'Uvaranas - Laboratório';
        _turnoAtivo = turno ?? 'Dia';
        notifyListeners();
        return tipo;
      }
    } catch (e) {
      debugPrint("Erro ao recuperar sessão salva: $e");
    }
    return null;
  }

  Future<void> realizarLogout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyUsername);
      await prefs.remove(_keyNomeCompleto);
      await prefs.remove(_keySessaoTipo);
      await prefs.remove(_keyEquipe);
      await prefs.remove(_keyTurno);
    } catch (e) {
      debugPrint("Erro ao limpar dados de sessão: $e");
    }

    _usuarioLogado = null;
    notifyListeners();
  }
}