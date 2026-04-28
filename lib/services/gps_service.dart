import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math';

class LocalPreProgramado {
  final String nome;
  final LatLng coords;
  LocalPreProgramado(this.nome, this.coords);
}

class GpsService {
  final String _apiKey = "AIzaSyA8wdqUKJLIt4FutB0Q6O0YY-lPRg5rY_0";

  // Locais pré-programados em Ponta Grossa
  final List<LocalPreProgramado> locaisFixos = [
    LocalPreProgramado("Upa Santana", const LatLng(-25.0935, -50.1588)),
    LocalPreProgramado("Upa Santa Paula", const LatLng(-25.1322, -50.1812)),
    LocalPreProgramado("Laboratório", const LatLng(-25.0945, -50.1633)),
  ];

  /// Detecta se o usuário está a 30m de algum local conhecido
  Future<String?> detectarLocalProximo() async {
    try {
      Position pos = await determinarPosicao();
      LatLng atual = LatLng(pos.latitude, pos.longitude);
      
      for (var local in locaisFixos) {
        if (verificarProximidadeDestino(atual, local.coords, 30.0)) {
          return local.nome;
        }
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<Position> determinarPosicao() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('GPS desativado.');
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return Future.error('Permissão negada.');
    }
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  bool verificarProximidadeDestino(LatLng atual, LatLng destino, double raioMetros) {
    double dist = calcularDistanciaKm(atual, destino) * 1000;
    return dist <= raioMetros;
  }

  double calcularDistanciaKm(LatLng p1, LatLng p2) {
    var p = 0.017453292519943295;
    var a = 0.5 - cos((p2.latitude - p1.latitude) * p) / 2 + cos(p1.latitude * p) * cos(p2.latitude * p) * (1 - cos((p2.longitude - p1.longitude) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  Future<Map<String, dynamic>> buscarInformacoesRota(LatLng origem, LatLng destino) async {
    final url = "https://maps.googleapis.com/maps/api/directions/json?origin=${origem.latitude},${origem.longitude}&destination=${destino.latitude},${destino.longitude}&key=$_apiKey&mode=driving";
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final leg = data['routes'][0]['legs'][0];
        return {
          'distancia_valor': leg['distance']['value'],
          'tempo_valor': leg['duration']['value'],
          'polyline': data['routes'][0]['overview_polyline']['points'],
        };
      }
    }
    throw Exception("Erro na rota");
  }

  Future<List<LatLng>> buscarRotaReal(LatLng origem, LatLng destino) async {
    try {
      final info = await buscarInformacoesRota(origem, destino);
      return _decodificarPolyline(info['polyline']);
    } catch (e) { return [origem, destino]; }
  }

  Stream<Position> monitorarMovimento() {
    return Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5));
  }

  List<LatLng> _decodificarPolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do { b = encoded.codeUnitAt(index++) - 63; result |= (b & 0x1f) << shift; shift += 5; } while (b >= 0x20);
      lat += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      shift = 0; result = 0;
      do { b = encoded.codeUnitAt(index++) - 63; result |= (b & 0x1f) << shift; shift += 5; } while (b >= 0x20);
      lng += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }
}