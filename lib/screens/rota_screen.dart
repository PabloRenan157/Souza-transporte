import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/gps_service.dart';
import '../services/scanner_service.dart';
import 'rastreamento_screen.dart';

enum StatusCorrida { aguardandoScan, escaneando, escaneado }

class RotaScreen extends StatefulWidget {
  final String motorista;
  const RotaScreen({super.key, required this.motorista});

  @override
  State<RotaScreen> createState() => _RotaScreenState();
}

class _RotaScreenState extends State<RotaScreen> {
  StatusCorrida status = StatusCorrida.aguardandoScan;
  final GpsService _gpsService = GpsService();
  final _formKey = GlobalKey<FormState>(); 
  
  // Dados da Viagem
  String idAmostra = '';
  String localOrigem = 'Upa Santana';
  String localDestino = 'Laboratório';
  String observacao = '';
  
  double destLat = 0.0;
  double destLng = 0.0;
  String distanciaStr = 'Calculando...';
  String tempoStr = '---';

  @override
  void initState() {
    super.initState();
    _autoDetectarOrigem();
  }

  Future<void> _autoDetectarOrigem() async {
    String? local = await _gpsService.detectarLocalProximo();
    if (local != null) setState(() => localOrigem = local);
  }

  // NOVA LÓGICA DE PROCESSAMENTO DE JSON
  void _processarScan(String code) async {
    try {
      // Tenta decodificar o JSON do QR Code
      final Map<String, dynamic> data = jsonDecode(code);
      
      setState(() {
        idAmostra = data['id']?.toString() ?? 'S/ID';
        localDestino = data['destino']?.toString() ?? 'Laboratório';
        destLat = double.parse(data['lat'].toString());
        destLng = double.parse(data['lng'].toString());
        observacao = data['obs']?.toString() ?? '';
      });

    } catch (e) {
      // Se não for um JSON, trata o código como o ID da Amostra (Texto Simples)
      idAmostra = code;
      localDestino = "Laboratório"; // Destino padrão
      final localD = _gpsService.locaisFixos.firstWhere((l) => l.nome == "Laboratório");
      destLat = localD.coords.latitude;
      destLng = localD.coords.longitude;
    }

    _buscarInformacoesRota();
  }

  void _buscarInformacoesRota() async {
    Position pos = await _gpsService.determinarPosicao();
    try {
      final info = await _gpsService.buscarInformacoesRota(
        LatLng(pos.latitude, pos.longitude), 
        LatLng(destLat, destLng)
      );
      setState(() {
        distanciaStr = "${(info['distancia_valor'] / 1000).toStringAsFixed(1)} km";
        tempoStr = "${(info['tempo_valor'] / 60).round()} min";
        status = StatusCorrida.escaneado;
      });
    } catch (e) {
      setState(() {
        distanciaStr = "Calculada via GPS";
        status = StatusCorrida.escaneado;
      });
    }
  }

  void _confirmarDadosManuais() {
    if (!_formKey.currentState!.validate()) return;
    
    final localD = _gpsService.locaisFixos.firstWhere((l) => l.nome == localDestino);
    destLat = localD.coords.latitude;
    destLng = localD.coords.longitude;
    
    _buscarInformacoesRota();
  }

  void _mostrarFormularioManual() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Entrada Manual', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00ACC1))),
                const Divider(),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'ID da Amostra', prefixIcon: Icon(Icons.tag)),
                  validator: (value) => (value == null || value.isEmpty) ? 'ID obrigatório' : null,
                  onChanged: (v) => idAmostra = v,
                ),
                const SizedBox(height: 10),
                _buildDropdown('Origem', localOrigem, (v) => setModalState(() => localOrigem = v!)),
                _buildDropdown('Destino', localDestino, (v) => setModalState(() => localDestino = v!)),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Observações', prefixIcon: Icon(Icons.comment)),
                  onChanged: (v) => observacao = v,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: const Color(0xFF00C853)),
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      Navigator.pop(context);
                      _confirmarDadosManuais();
                    }
                  },
                  child: const Text('CONFIRMAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: ["Upa Santana", "Upa Santa Paula", "Laboratório"].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: const Text('Souza transporte - Rota'), backgroundColor: const Color(0xFF00ACC1)),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (status == StatusCorrida.aguardandoScan) ...[
              const SizedBox(height: 20),
              _buildLocationBadge(),
              _actionCard("ESCANEAR PRODUTO", Icons.qr_code_scanner, () => setState(() => status = StatusCorrida.escaneando)),
              _actionCard("DIGITAR MANUALMENTE", Icons.edit_note, _mostrarFormularioManual),
            ],
            
            if (status == StatusCorrida.escaneando) ...[
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text("Posicione o QR Code no centro", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 300,
                      child: ScannerDevice(onCodeScanned: _processarScan),
                    ),
                    const SizedBox(height: 20),
                    TextButton.icon(
                      onPressed: () => setState(() => status = StatusCorrida.aguardandoScan),
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      label: const Text("CANCELAR LEITURA", style: TextStyle(color: Colors.red)),
                    )
                  ],
                ),
              ),
            ],

            if (status == StatusCorrida.escaneado) _buildResumoConfirmacao(),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationBadge() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
    child: Row(children: [const Icon(Icons.my_location, color: Colors.blue, size: 18), const SizedBox(width: 10), Text("GPS detectou: $localOrigem", style: const TextStyle(fontSize: 13, color: Colors.blue))]),
  );

  Widget _actionCard(String title, IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)]),
      child: Row(children: [Icon(icon, color: Colors.cyan), const SizedBox(width: 20), Text(title, style: const TextStyle(fontWeight: FontWeight.bold))]),
    ),
  );

  Widget _buildResumoConfirmacao() => Container(
    margin: const EdgeInsets.all(20), padding: const EdgeInsets.all(25),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15)]),
    child: Column(
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 60),
        const SizedBox(height: 10),
        Text("Amostra: $idAmostra", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const Divider(height: 30),
        _resRow("Saindo de:", localOrigem),
        _resRow("Indo para:", localDestino),
        _resRow("Distância:", distanciaStr),
        _resRow("Estimativa:", tempoStr),
        if (observacao.isNotEmpty) _resRow("Obs:", observacao),
        const SizedBox(height: 30),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00ACC1),
            minimumSize: const Size(double.infinity, 60),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
          ),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => RastreamentoScreen(
            destLat: destLat, 
            destLng: destLng, 
            destinoNome: localDestino, 
            motorista: widget.motorista, 
            observacao: observacao, 
            localInicioNome: localOrigem,
          ))),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.navigation, color: Colors.white),
              SizedBox(width: 10),
              Text("INICIAR CORRIDA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ),
        TextButton(onPressed: () => setState(() => status = StatusCorrida.aguardandoScan), child: const Text("Voltar"))
      ],
    ),
  );

  Widget _resRow(String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.grey)), Text(v, style: const TextStyle(fontWeight: FontWeight.bold))]));
}