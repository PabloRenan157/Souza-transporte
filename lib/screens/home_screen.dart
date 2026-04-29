import 'package:flutter/material.dart';
import 'package:s_transporte/screens/rota_screen.dart';
import 'package:s_transporte/screens/relatorio_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Lista de motoristas cadastrados no sistema
  final List<String> motoristas = ['Renan', 'Carlos', 'Ana', 'Beatriz'];
  String motoristaSelecionado = 'Renan';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fundo com gradiente moderno para identidade visual
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF00C853), Color(0xFF00ACC1)],
              ),
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  const Text(
                    'Bem-vindo ao',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  const Text(
                    'Souza transporte',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Card de Perfil para identificação do motorista atual
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.person, color: Colors.white),
                            SizedBox(width: 10),
                            Text(
                              'Perfil do Motorista',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: motoristaSelecionado,
                              isExpanded: true,
                              items: motoristas.map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (novo) {
                                setState(() => motoristaSelecionado = novo!);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Botão para iniciar o fluxo de scanner e GPS
                  _buildMenuButton(
                    context,
                    'INICIAR NOVA ENTREGA',
                    Icons.qr_code_scanner,
                    Colors.white,
                    const Color(0xFF00C853),
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => RotaScreen(motorista: motoristaSelecionado),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  
                  // Botão para acessar os logs salvos no dispositivo
                  _buildMenuButton(
                    context,
                    'Relatórios',
                    Icons.history,
                    Colors.white.withOpacity(0.2),
                    Colors.white,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (c) => const RelatorioScreen()),
                    ),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget auxiliar para manter o padrão visual dos botões principais
  Widget _buildMenuButton(BuildContext context, String title, IconData icon, Color bgColor, Color textColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor),
            const SizedBox(width: 15),
            Text(
              title,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
