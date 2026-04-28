import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/gps_service.dart';
import '../services/log_service.dart';
import '../models/transporte_log.dart';
import 'relatorio_screen.dart';

class RastreamentoScreen extends StatefulWidget {
  final double destLat;
  final double destLng;
  final String destinoNome;
  final String localInicioNome;
  final String motorista;
  final String observacao;

  const RastreamentoScreen({
    super.key, 
    required this.destLat, 
    required this.destLng, 
    required this.destinoNome,
    required this.localInicioNome,
    required this.motorista,
    required this.observacao,
  });

  @override
  State<RastreamentoScreen> createState() => _RastreamentoScreenState();
}

class _RastreamentoScreenState extends State<RastreamentoScreen> {
  GoogleMapController? _mapController;
  final GpsService _gpsService = GpsService();
  LatLng _posicaoAtual = const LatLng(-25.0945, -50.1633);
  List<LatLng> _pontosRota = [];
  bool _carregando = true;
  double _heading = 0.0;
  late DateTime _horaSaida;

  @override
  void initState() {
    super.initState();
    _horaSaida = DateTime.now();
    _iniciarNavegacao();
  }

  Future<void> _iniciarNavegacao() async {
    try {
      Position p = await _gpsService.determinarPosicao();
      LatLng destino = LatLng(widget.destLat, widget.destLng);
      List<LatLng> rota = await _gpsService.buscarRotaReal(LatLng(p.latitude, p.longitude), destino);
      setState(() {
        _posicaoAtual = LatLng(p.latitude, p.longitude);
        _pontosRota = rota;
        _heading = p.heading;
        _carregando = false;
      });
      _gpsService.monitorarMovimento().listen((p) {
        if (mounted) {
          setState(() { _posicaoAtual = LatLng(p.latitude, p.longitude); _heading = p.heading; });
          _mapController?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: _posicaoAtual, zoom: 18, tilt: 45, bearing: _heading)));
        }
      });
    } catch (e) { debugPrint("Erro: $e"); }
  }

  void _finalizarCorrida() async {
    LatLng destino = LatLng(widget.destLat, widget.destLng);
    bool chegou = _gpsService.verificarProximidadeDestino(_posicaoAtual, destino, TransporteLog.raioChegadaMetros);

    if (!chegou) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Longe do destino (${TransporteLog.raioChegadaMetros.toInt()}m necessários).'), backgroundColor: Colors.orange));
      return;
    }

    DateTime horaChegada = DateTime.now();
    final log = TransporteLog(
      id: "AMS-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}",
      localInicio: widget.localInicioNome,
      destino: widget.destinoNome,
      horaSaida: _horaSaida,
      horaChegada: horaChegada,
      tempoTrajeto: horaChegada.difference(_horaSaida),
      nomeMotorista: widget.motorista,
      observacao: widget.observacao,
    );

    await LogService.salvarLog(log);
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const RelatorioScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Entrega para ${widget.destinoNome}'), backgroundColor: const Color(0xFF00ACC1)),
      body: Stack(
        children: [
          _carregando ? const Center(child: CircularProgressIndicator()) : GoogleMap(
            initialCameraPosition: CameraPosition(target: _posicaoAtual, zoom: 18, tilt: 45),
            onMapCreated: (c) => _mapController = c,
            myLocationEnabled: true,
            polylines: { Polyline(polylineId: const PolylineId('r'), color: Colors.blueAccent, width: 8, points: _pontosRota) },
            markers: { Marker(markerId: const MarkerId('d'), position: LatLng(widget.destLat, widget.destLng)) },
          ),
          Positioned(bottom: 30, left: 60, right: 60, child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if(widget.observacao.isNotEmpty) Container(padding: const EdgeInsets.all(8), color: Colors.white, child: Text("Obs: ${widget.observacao}")),
              const SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.all(15), minimumSize: const Size(double.infinity, 50)),
                onPressed: _finalizarCorrida,
                child: const Text('FINALIZAR ENTREGA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          )),
        ],
      ),
    );
  }
}