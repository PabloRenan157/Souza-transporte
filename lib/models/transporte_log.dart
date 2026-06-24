import 'dart:convert';

/// Modelo de dados atualizado para a Parte 3 do projeto Souza Transportes.
/// Suporta múltiplas amostras, linhas de equipe, tipos de veículo, tempos de permanência e compensações financeiras.
class TransporteLog {
  final String id;
  final List<String> idAmostras; // Requisito 1: Suporta mais de uma coleta por corrida
  final String localInicio;
  final String destino;
  final DateTime horaSaida;
  final DateTime horaChegada;
  final Duration tempoTrajeto;
  final String nomeMotorista;
  final String observacao;
  final bool sincronizado;
  final double valorCorrida;
  
  // Novos Atributos para as regras da Parte 3
  final String equipeLinha;       // Requisito 5 & 8 & 9: Uvaranas ou Santa Paula/Santana
  final String turno;             // Requisito 5: Dia ou Noite
  final String tipoVeiculo;       // Requisito 8 & 9: Motoboy ou Carro
  final bool isExtra;             // Requisito 7: Se é serviço extra
  final bool isSemColeta;         // Requisito 2: Se é trajeto vazio sem coleta
  
  // Requisito 6 & 8: Tempos de check-in e permanência nos pontos
  final DateTime? horaCheckInIntermediario; 
  final DateTime? horaCheckOutIntermediario;
  final String? localIntermediario;

  TransporteLog({
    required this.id,
    this.idAmostras = const [], // Opcional com padrão para compatibilidade com motorista_home_screen
    required this.localInicio,
    required this.destino,
    required this.horaSaida,
    required this.horaChegada,
    required this.tempoTrajeto,
    required this.nomeMotorista,
    required this.observacao,
    required this.sincronizado,
    this.valorCorrida = 0.0,
    this.equipeLinha = 'Uvaranas - Laboratório',
    this.turno = 'Dia',
    this.tipoVeiculo = 'Motoboy',
    this.isExtra = false,
    this.isSemColeta = false,
    this.horaCheckInIntermediario,
    this.horaCheckOutIntermediario,
    this.localIntermediario,
  });

  /// Retorna o tempo de permanência formatado para exibição no relatório
  Duration get tempoPermanenciaIntermediaria {
    if (horaCheckInIntermediario != null && horaCheckOutIntermediario != null) {
      return horaCheckOutIntermediario!.difference(horaCheckInIntermediario!);
    }
    return Duration.zero;
  }

  TransporteLog copyWith({
    String? id,
    List<String>? idAmostras,
    String? localInicio,
    String? destino,
    DateTime? horaSaida,
    DateTime? horaChegada,
    Duration? tempoTrajeto,
    String? nomeMotorista,
    String? observacao,
    bool? sincronizado,
    double? valorCorrida,
    String? equipeLinha,
    String? turno,
    String? tipoVeiculo,
    bool? isExtra,
    bool? isSemColeta,
    DateTime? horaCheckInIntermediario,
    DateTime? horaCheckOutIntermediario,
    String? localIntermediario,
  }) {
    return TransporteLog(
      id: id ?? this.id,
      idAmostras: idAmostras ?? this.idAmostras,
      localInicio: localInicio ?? this.localInicio,
      destino: destino ?? this.destino,
      horaSaida: horaSaida ?? this.horaSaida,
      horaChegada: horaChegada ?? this.horaChegada,
      tempoTrajeto: tempoTrajeto ?? this.tempoTrajeto,
      nomeMotorista: nomeMotorista ?? this.nomeMotorista,
      observacao: observacao ?? this.observacao,
      sincronizado: sincronizado ?? this.sincronizado,
      valorCorrida: valorCorrida ?? this.valorCorrida,
      equipeLinha: equipeLinha ?? this.equipeLinha,
      turno: turno ?? this.turno,
      tipoVeiculo: tipoVeiculo ?? this.tipoVeiculo,
      isExtra: isExtra ?? this.isExtra,
      isSemColeta: isSemColeta ?? this.isSemColeta,
      horaCheckInIntermediario: horaCheckInIntermediario ?? this.horaCheckInIntermediario,
      horaCheckOutIntermediario: horaCheckOutIntermediario ?? this.horaCheckOutIntermediario,
      localIntermediario: localIntermediario ?? this.localIntermediario,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'idAmostras': idAmostras,
      'localInicio': localInicio,
      'destino': destino,
      'horaSaida': horaSaida.toIso8601String(),
      'horaChegada': horaChegada.toIso8601String(),
      'tempoTrajetoMinutos': tempoTrajeto.inMinutes,
      'nomeMotorista': nomeMotorista,
      'observacao': observacao,
      'sincronizado': sincronizado,
      'valorCorrida': valorCorrida,
      'equipeLinha': equipeLinha,
      'turno': turno,
      'tipoVeiculo': tipoVeiculo,
      'isExtra': isExtra,
      'isSemColeta': isSemColeta,
      'horaCheckInIntermediario': horaCheckInIntermediario?.toIso8601String(),
      'horaCheckOutIntermediario': horaCheckOutIntermediario?.toIso8601String(),
      'localIntermediario': localIntermediario,
    };
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'id_amostras': idAmostras.join(','), 
      'local_inicio': localInicio,
      'destino': destino,
      'hora_saida': horaSaida.toIso8601String(),
      'hora_chegada': horaChegada.toIso8601String(),
      'tempo_trajeto_minutos': tempoTrajeto.inMinutes,
      'nome_motorista': nomeMotorista,
      'observacao': observacao,
      'valor_corrida': valorCorrida,
      'equipe_linha': equipeLinha,
      'turno': turno,
      'tipo_veiculo': tipoVeiculo,
      'is_extra': isExtra,
      'is_sem_coleta': isSemColeta,
      'hora_checkin_intermediario': horaCheckInIntermediario?.toIso8601String(),
      'hora_checkout_intermediario': horaCheckOutIntermediario?.toIso8601String(),
      'local_intermediario': localIntermediario,
    };
  }

  factory TransporteLog.fromMap(Map<String, dynamic> map) {
    List<String> amostrasList = [];
    if (map['idAmostras'] != null) {
      amostrasList = List<String>.from(map['idAmostras']);
    } else if (map['id_amostras'] != null) {
      amostrasList = map['id_amostras'].toString().split(',').where((s) => s.isNotEmpty).toList();
    } else {
      amostrasList = [map['id']?.toString() ?? ''];
    }

    return TransporteLog(
      id: map['id']?.toString() ?? '',
      idAmostras: amostrasList,
      localInicio: map['localInicio']?.toString() ?? map['local_inicio']?.toString() ?? '',
      destino: map['destino']?.toString() ?? '',
      horaSaida: map['horaSaida'] != null ? DateTime.parse(map['horaSaida']) : (map['hora_saida'] != null ? DateTime.parse(map['hora_saida']) : DateTime.now()),
      horaChegada: map['horaChegada'] != null ? DateTime.parse(map['horaChegada']) : (map['hora_chegada'] != null ? DateTime.parse(map['hora_chegada']) : DateTime.now()),
      tempoTrajeto: Duration(minutes: map['tempoTrajetoMinutos'] ?? map['tempo_trajeto_minutos'] ?? 0),
      nomeMotorista: map['nomeMotorista']?.toString() ?? map['nome_motorista']?.toString() ?? '',
      observacao: map['observacao']?.toString() ?? '',
      sincronizado: map['sincronizado'] ?? true,
      valorCorrida: double.tryParse(map['valorCorrida']?.toString() ?? map['valor_corrida']?.toString() ?? '0.0') ?? 0.0,
      equipeLinha: map['equipeLinha']?.toString() ?? map['equipe_linha']?.toString() ?? 'Uvaranas - Laboratório',
      turno: map['turno']?.toString() ?? map['turno']?.toString() ?? 'Dia',
      tipoVeiculo: map['tipoVeiculo']?.toString() ?? map['tipo_veiculo']?.toString() ?? 'Motoboy',
      isExtra: map['isExtra'] ?? map['is_extra'] ?? false,
      isSemColeta: map['isSemColeta'] ?? map['is_sem_coleta'] ?? false,
      horaCheckInIntermediario: map['horaCheckInIntermediario'] != null ? DateTime.parse(map['horaCheckInIntermediario']) : (map['hora_checkin_intermediario'] != null ? DateTime.parse(map['hora_checkin_intermediario']) : null),
      horaCheckOutIntermediario: map['horaCheckOutIntermediario'] != null ? DateTime.parse(map['horaCheckOutIntermediario']) : (map['hora_checkout_intermediario'] != null ? DateTime.parse(map['hora_checkout_intermediario']) : null),
      localIntermediario: map['localIntermediario']?.toString() ?? map['local_intermediario']?.toString(),
    );
  }

  String toJson() => json.encode(toMap());

  factory TransporteLog.fromJson(String source) => TransporteLog.fromMap(json.decode(source));
}