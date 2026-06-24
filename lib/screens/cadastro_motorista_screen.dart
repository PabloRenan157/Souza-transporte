import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';

/// Ecrã de Registo de novos motoristas para a Souza Transportes.
class CadastroMotoristaScreen extends StatefulWidget {
  const CadastroMotoristaScreen({super.key});

  @override
  State<CadastroMotoristaScreen> createState() => _CadastroMotoristaScreenState();
}

class _CadastroMotoristaScreenState extends State<CadastroMotoristaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _senhaController = TextEditingController();
  final _nomeController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _senhaController.dispose();
    _nomeController.dispose();
    super.dispose();
  }

  void _submeterFormulario() async {
    if (_formKey.currentState!.validate()) {
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);

      final sucesso = await adminProvider.registarNovoMotorista(
        username: _usernameController.text,
        senha: _senhaController.text,
        nomeCompleto: _nomeController.text,
      );

      if (mounted) {
        if (sucesso) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Motorista registrado com sucesso no Supabase!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); 
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro: Utilizador/Username já cadastrado no sistema!'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Registrar Motorista'),
        backgroundColor: const Color(0xFF263238),
        foregroundColor: Colors.white,
      ),
      body: adminProvider.carregando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF263238)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 80,
                      color: Color(0xFF263238),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Novo Cadastro de Condutor',
                      textAlign: TextAlign.center, // CORRIGIDO: de Center para TextAlign.center
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    ),
                    const Text(
                      'Insira os dados credenciais do motoboy para liberar o acesso ao aplicativo local.',
                      textAlign: TextAlign.center, // CORRIGIDO
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _nomeController,
                      decoration: InputDecoration(
                        labelText: 'Nome Completo',
                        prefixIcon: const Icon(Icons.badge_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (valor) {
                        if (valor == null || valor.trim().isEmpty) {
                          return 'Insira o nome completo do condutor';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Utilizador (Username)',
                        helperText: 'Apenas letras minúsculas (ex: renan.souza)',
                        prefixIcon: const Icon(Icons.alternate_email_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (valor) {
                        if (valor == null || valor.trim().isEmpty) {
                          return 'Insira um utilizador de login';
                        }
                        if (valor.contains(' ')) {
                          return 'Utilizador não pode conter espaços';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _senhaController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Senha de Entrada',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (valor) {
                        if (valor == null || valor.trim().isEmpty) {
                          return 'Defina uma senha de entrada';
                        }
                        if (valor.length < 3) {
                          return 'A senha precisa ter pelo menos 3 dígitos';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: _submeterFormulario,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF263238),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Confirmar Registro',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}