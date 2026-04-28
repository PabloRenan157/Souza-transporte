import 'dart:convert';

class TransporteLog {
  static const double raioChegadaMetros = 30.0;

  final String id;
  final String localInicio;
  final String destino;
  final DateTime horaSaida;
  final DateTime horaChegada;
  final Duration tempoTrajeto;
  final String nomeMotorista;
  final String observacao;

  TransporteLog({
    required this.id,
    required this.localInicio,
    required this.destino,
    required this.horaSaida,
    required this.horaChegada,
    required this.tempoTrajeto,
    required this.nomeMotorista,
    this.observacao = "",
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'localInicio': localInicio,
      'destino': destino,
      'horaSaida': horaSaida.toIso8601String(),
      'horaChegada': horaChegada.toIso8601String(),
      'tempoTrajetoMinutos': tempoTrajeto.inMinutes,
      'nomeMotorista': nomeMotorista,
      'observacao': observacao,
    };
  }

  factory TransporteLog.fromMap(Map<String, dynamic> map) {
    return TransporteLog(
      id: map['id'],
      localInicio: map['localInicio'] ?? "Origem",
      destino: map['destino'] ?? "Destino",
      horaSaida: DateTime.parse(map['horaSaida']),
      horaChegada: DateTime.parse(map['horaChegada']),
      tempoTrajeto: Duration(minutes: map['tempoTrajetoMinutos'] ?? 0),
      nomeMotorista: map['nomeMotorista'] ?? 'Motorista',
      observacao: map['observacao'] ?? "",
    );
  }

  String toJson() => json.encode(toMap());
  factory TransporteLog.fromJson(String source) => TransporteLog.fromMap(json.decode(source));
}