import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../providers/log_provider.dart';
import '../models/transporte_log.dart';
import '../services/gps_service.dart';

class RastreamentoScreen extends StatefulWidget {
  final double destLat;
  final double destLng;
  final String destinoNome;
  final String motorista;
  final String observacao;
  final String localInicioNome;
  final List<String> idAmostras; 
  final double valorCorrida;
  
  final String equipeLinha;
  final String turno;
  final String tipoVeiculo;
  final bool isExtra;
  final bool isSemColeta;

  const RastreamentoScreen({
    super.key,
    required this.destLat,
    required this.destLng,
    required this.destinoNome,
    required this.motorista,
    required this.observacao,
    required this.localInicioNome,
    required this.idAmostras,
    required this.valorCorrida,
    required this.equipeLinha,
    required this.turno,
    required this.tipoVeiculo,
    this.isExtra = false,
    this.isSemColeta = false,
  });

  @override
  State<RastreamentoScreen> createState() => _RastreamentoScreenState();
}

class _RastreamentoScreenState extends State<RastreamentoScreen> {
  final GpsService _gpsService = GpsService();
  late DateTime _horaInicio;
  
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  double _distanciaAteDestinoMetros = 9999.0;
  bool _emDeslocamento = true;
  StreamSubscription<Position>? _gpsSubscription;

  bool _precisaDeCheckInIntermediario = false;
  bool _fezCheckInIntermediario = false;
  bool _fezCheckOutIntermediario = false;
  DateTime? _horaCheckInIntermediario;
  DateTime? _horaCheckOutIntermediario;
  final String _localIntermediarioNome = "Upa Santana";
  final LatLng _coordsUpaSantana = const LatLng(-25.102619, -50.160972);

  @override
  void initState() {
    super.initState();
    _horaInicio = DateTime.now();
    
    if (widget.equipeLinha == 'Santa Paula / Santana / Laboratório') {
      _precisaDeCheckInIntermediario = true;
    }
    
    _iniciarMonitoramentoGPS();
  }

  void _iniciarMonitoramentoGPS() async {
    try {
      Position posicaoInicial = await _gpsService.determinarPosicao();
      _atualizarTelemetriaReal(posicaoInicial);
      _carregarRotaFisicaReal(posicaoInicial);

      _gpsSubscription = _gpsService.monitorarMovimento().listen(
        (Position posicaoAtual) {
          _atualizarTelemetriaReal(posicaoAtual);
        },
        onError: (erro) {
          debugPrint("Erro no sensor de GPS: $erro");
        },
      );
    } catch (e) {
      debugPrint("Erro ao inicializar telemetria de GPS: $e");
    }
  }

  void _carregarRotaFisicaReal(Position pos) async {
    try {
      List<LatLng> pontos = await _gpsService.buscarRotaReal(
        LatLng(pos.latitude, pos.longitude),
        LatLng(widget.destLat, widget.destLng),
      );
      if (mounted) {
        setState(() {
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('rota_google'),
              points: pontos,
              color: const Color(0xFF00ACC1),
              width: 5,
            ),
          );
        });
      }
    } catch (e) {
      debugPrint("Erro ao obter polylines reais da API: $e");
    }
  }

  void _atualizarTelemetriaReal(Position pos) {
    if (!mounted) return;

    final LatLng localAtual = LatLng(pos.latitude, pos.longitude);
    final LatLng localDestino = LatLng(widget.destLat, widget.destLng);

    final double distKm = _gpsService.calcularDistanciaKm(localAtual, localDestino);

    if (_precisaDeCheckInIntermediario && !_fezCheckOutIntermediario) {
      double distAteSantana = _gpsService.calcularDistanciaKm(localAtual, _coordsUpaSantana) * 1000;
      
      if (distAteSantana <= 50.0 && !_fezCheckInIntermediario) {
        _dispararCheckInDuploAutomovel();
      }
    }

    setState(() {
      _distanciaAteDestinoMetros = distKm * 1000;
      _emDeslocamento = _distanciaAteDestinoMetros > 50.0;

      _markers = {
        Marker(
          markerId: const MarkerId('motorista_marker'),
          position: localAtual,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
          infoWindow: const InfoWindow(title: 'Sua Posição'),
        ),
        Marker(
          markerId: const MarkerId('destino_marker'),
          position: localDestino,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: widget.destinoNome),
        ),
        if (_precisaDeCheckInIntermediario)
          Marker(
            markerId: const MarkerId('intermediario_marker'),
            position: _coordsUpaSantana,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            infoWindow: InfoWindow(title: _localIntermediarioNome),
          ),
      };
    });

    _mapController?.animateCamera(CameraUpdate.newLatLng(localAtual));
  }

  void _dispararCheckInDuploAutomovel() {
    setState(() {
      _fezCheckInIntermediario = true;
      _horaCheckInIntermediario = DateTime.now();
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.orange),
              SizedBox(width: 8),
              Text('Check-In Confirmado'),
            ],
          ),
          content: Text(
            'Você chegou na $_localIntermediarioNome.\nSeu tempo de permanência começará a ser contabilizado agora.\n\nClique no botão abaixo ao sair do local.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _fezCheckOutIntermediario = true;
                  _horaCheckOutIntermediario = DateTime.now();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Check-Out intermediário confirmado!'), backgroundColor: Colors.orange),
                );
              },
              child: const Text('REALIZAR CHECK-OUT E PARTIR', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _tentarFinalizarCorrida() async {
    if (_precisaDeCheckInIntermediario && !_fezCheckOutIntermediario) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Check-In Pendente'),
          content: Text('Você deve parar na $_localIntermediarioNome e realizar o check-in duplo antes de finalizar a corrida.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _dispararCheckInDuploAutomovel();
              },
              child: const Text('Simular Parada'),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ok')),
          ],
        ),
      );
      return;
    }

    if (_distanciaAteDestinoMetros > 50.0) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text('Bloqueio por GPS'),
              ],
            ),
            content: Text(
              'Atenção! Você está a ${_distanciaAteDestinoMetros.toStringAsFixed(0)}m do destino (${widget.destinoNome}).\n\nChegue a menos de 50 metros do local para poder finalizar.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _distanciaAteDestinoMetros = 15.0;
                    _emDeslocamento = false;
                  });
                  Navigator.pop(context);
                },
                child: const Text('Forçar Chegada (Testes)'),
              ),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          );
        },
      );
      return;
    }

    final horaFim = DateTime.now();
    final duracao = horaFim.difference(_horaInicio);
    final String uuidViagem = 'AMS-${const Uuid().v4().substring(0, 5).toUpperCase()}';

    final log = TransporteLog(
      id: uuidViagem,
      idAmostras: widget.idAmostras,
      localInicio: widget.localInicioNome,
      destino: widget.destinoNome,
      horaSaida: _horaInicio,
      horaChegada: horaFim,
      tempoTrajeto: duracao,
      nomeMotorista: widget.motorista,
      observacao: widget.observacao,
      sincronizado: false,
      valorCorrida: widget.valorCorrida,
      equipeLinha: widget.equipeLinha,
      turno: widget.turno,
      tipoVeiculo: widget.tipoVeiculo,
      isExtra: widget.isExtra,
      isSemColeta: widget.isSemColeta,
      horaCheckInIntermediario: _horaCheckInIntermediario,
      horaCheckOutIntermediario: _horaCheckOutIntermediario,
      localIntermediario: _precisaDeCheckInIntermediario ? _localIntermediarioNome : null,
    );

    await Provider.of<LogProvider>(context, listen: false).registarNovaCorrida(log);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Viagem concluída e sincronizada com sucesso!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool liberadoParaFinalizar = _distanciaAteDestinoMetros <= 50.0;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Viagem em Curso'),
        backgroundColor: const Color(0xFF263238),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: LatLng(widget.destLat, widget.destLng), zoom: 14.5),
              myLocationEnabled: true,
              zoomControlsEnabled: true,
              markers: _markers,
              polylines: _polylines,
              onMapCreated: (c) => _mapController = c,
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDetailRow('Origem:', widget.localInicioNome, Icons.radio_button_checked, Colors.cyan),
                  const SizedBox(height: 6),
                  if (_precisaDeCheckInIntermediario) ...[
                    _buildDetailRow(
                      'Ponto Check-In:', 
                      '$_localIntermediarioNome (${_fezCheckInIntermediario ? (_fezCheckOutIntermediario ? 'Concluído' : 'Aguardando Saída') : 'Pendente'})', 
                      Icons.flag_rounded, 
                      Colors.orange
                    ),
                    const SizedBox(height: 6),
                  ],
                  _buildDetailRow('Destino Final:', widget.destinoNome, Icons.location_on, Colors.redAccent),
                  const SizedBox(height: 12),
                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Distância restante:', style: TextStyle(color: Colors.grey, fontSize: 10)),
                            Text('${_distanciaAteDestinoMetros.toStringAsFixed(0)} metros', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: liberadoParaFinalizar ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: Text(
                            liberadoParaFinalizar ? 'Liberado' : 'Afastado',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: liberadoParaFinalizar ? Colors.green : Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _tentarFinalizarCorrida,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: liberadoParaFinalizar ? Colors.green : Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(liberadoParaFinalizar ? 'FINALIZAR CORRIDA' : 'BLOQUEADO POR DISTÂNCIA', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, Color cor) {
    return Row(
      children: [
        Icon(icon, color: cor, size: 16),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9)),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}