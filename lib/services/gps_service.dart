import 'package:flutter/foundation.dart'; // Adicionado para definir e corrigir o erro do método debugPrint
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math';
import '../config/env.dart'; // Importação segura do ficheiro de chaves de ambiente

class LocalPreProgramado {
  final String nome;
  final LatLng coords;
  LocalPreProgramado(this.nome, this.coords);
}

/// Serviço responsável pelo gerenciamento de localização GPS e integração real com a API do Google Maps.
class GpsService {
  // Consome a API Key do Google Maps de forma segura a partir do ficheiro de ambiente ignorado pelo Git
  final String _apiKey = Env.googleMapsApiKey;

  // Locais pré-programados do ecossistema da Souza Transportes em Ponta Grossa
  final List<LocalPreProgramado> locaisFixos = [
    LocalPreProgramado("Upa Santana", const LatLng(-25.102619, -50.160972)),
    LocalPreProgramado("Upa Santa Paula", const LatLng(-25.102150, -50.201690)),
    LocalPreProgramado("Laboratório", const LatLng(-25.051755, -50.132077)),
  ];

  /// Detecta se o utilizador está a menos de 100 metros de algum local conhecido para autodetectar a partida
  Future<String?> detectarLocalProximo() async {
    try {
      Position pos = await determinarPosicao();
      LatLng atual = LatLng(pos.latitude, pos.longitude);
      
      for (var local in locaisFixos) {
        double dist = calcularDistanciaKm(atual, local.coords) * 1000; // Converte para metros
        if (dist <= 100.0) {
          return local.nome;
        }
      }
    } catch (e) {
      debugPrint("Erro ao detectar local mais próximo por GPS: $e");
    }
    return null;
  }

  /// Solicita permissão e retorna a coordenada física atual com precisão elevada
  Future<Position> determinarPosicao() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Os serviços de localização estão desativados.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('As permissões de localização foram negadas.');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw Exception('As permissões de localização estão permanentemente negadas.');
    } 

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Calcula a distância Haversine trigonométrica em quilómetros entre duas coordenadas LatLng
  double calcularDistanciaKm(LatLng p1, LatLng p2) {
    var lat1 = p1.latitude * pi / 180;
    var lon1 = p1.longitude * pi / 180;
    var lat2 = p2.latitude * pi / 180;
    var lon2 = p2.longitude * pi / 180;

    var dlat = lat2 - lat1;
    var dlon = lon2 - lon1;

    var a = sin(dlat / 2) * sin(dlat / 2) +
            cos(lat1) * cos(lat2) *
            sin(dlon / 2) * sin(dlon / 2);
    var c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return 6371 * c; // Retorna a distância física em Km
  }

  /// Consulta a API real do Google Directions para buscar metadados de tráfego, distância e polyline
  Future<Map<String, dynamic>> buscarInformacoesRota(LatLng origem, LatLng destino) async {
    final String url = 
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origem.latitude},${origem.longitude}&destination=${destino.latitude},${destino.longitude}&key=$_apiKey';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final leg = data['routes'][0]['legs'][0];
        return {
          'distancia_valor': leg['distance']['value'], // Em metros
          'tempo_valor': leg['duration']['value'],     // Em segundos
          'polyline': data['routes'][0]['overview_polyline']['points'],
        };
      }
    }
    throw Exception("Erro na rota via Google API: ${response.statusCode}");
  }

  /// Busca e decodifica os pontos geográficos para desenhar as polylines reais no mapa
  Future<List<LatLng>> buscarRotaReal(LatLng origem, LatLng destino) async {
    try {
      final info = await buscarInformacoesRota(origem, destino);
      return _decodificarPolyline(info['polyline']);
    } catch (e) { 
      debugPrint("Usando fallback de reta simples devido a erro de API: $e");
      return [origem, destino]; 
    }
  }

  /// Escuta alterações de posicionamento do motoboy a cada 5 metros de deslocamento
  Stream<Position> monitorarMovimento() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high, 
        distanceFilter: 5,
      ),
    );
  }

  /// Algoritmo de decodificação de polylines compactadas do Google Maps Directions
  List<LatLng> _decodificarPolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do { 
        b = encoded.codeUnitAt(index++) - 63; 
        result |= (b & 0x1f) << shift; 
        shift += 5; 
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do { 
        b = encoded.codeUnitAt(index++) - 63; 
        result |= (b & 0x1f) << shift; 
        shift += 5; 
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      LatLng p = LatLng((lat / 1E5).toDouble(), (lng / 1E5).toDouble());
      poly.add(p);
    }
    return poly;
  }
}