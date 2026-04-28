import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import '../models/transporte_log.dart';

class LogService {
  static const String _storageKey = 'medexpress_logs';

  /// Salva um novo log no armazenamento local
  static Future<void> salvarLog(TransporteLog log) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> historicoJson = prefs.getStringList(_storageKey) ?? [];
    historicoJson.add(log.toJson());
    await prefs.setStringList(_storageKey, historicoJson);
  }

  /// Obtém todo o histórico ordenado por data de saída
  static Future<List<TransporteLog>> obterHistorico() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? historicoJson = prefs.getStringList(_storageKey);
    if (historicoJson == null) return [];
    
    var logs = historicoJson.map((item) => TransporteLog.fromJson(item)).toList();
    // Ordenação cronológica para cálculo de tempo ocioso na Timeline
    logs.sort((a, b) => a.horaSaida.compareTo(b.horaSaida));
    return logs;
  }

  /// Filtra os logs por uma data específica para exibição na tela
  static Future<List<TransporteLog>> obterLogsPorData(DateTime data) async {
    final todos = await obterHistorico();
    return todos.where((l) => 
      l.horaChegada.year == data.year && 
      l.horaChegada.month == data.month && 
      l.horaChegada.day == data.day
    ).toList();
  }

  /// Remove todos os logs (requer senha na UI)
  static Future<void> limparHistorico() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  /// Gera arquivo Excel (.xlsx) com suporte à versão 4.0.6 do pacote Excel
  static Future<String> gerarExcel(List<TransporteLog> logs, String path) async {
    var excel = Excel.createExcel();
    String sheetName = "Logistica_MedExpress";
    excel.rename(excel.getDefaultSheet()!, sheetName);
    Sheet sheetObject = excel[sheetName];

    CellStyle headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#00ACC1'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
    );

    // Cabeçalhos
    List<String> headers = ["ID", "Motorista", "Origem", "Destino", "Saída", "Chegada", "Duração (min)", "Obs"];
    for (var i = 0; i < headers.length; i++) {
      var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // Linhas de dados
    for (var i = 0; i < logs.length; i++) {
      var log = logs[i];
      var rowIndex = i + 1;
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = TextCellValue(log.id);
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue(log.nomeMotorista);
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = TextCellValue(log.localInicio);
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = TextCellValue(log.destino);
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = TextCellValue(DateFormat('HH:mm').format(log.horaSaida));
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = TextCellValue(DateFormat('HH:mm').format(log.horaChegada));
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = IntCellValue(log.tempoTrajeto.inMinutes);
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).value = TextCellValue(log.observacao);
    }

    final fileBytes = excel.save();
    final file = File(path);
    await file.writeAsBytes(fileBytes!);
    return file.path;
  }

  /// Gera arquivo CSV
  static Future<String> gerarCSV(List<TransporteLog> logs, String path) async {
    List<List<dynamic>> rows = [];
    rows.add(["ID Amostra", "Motorista", "Origem", "Destino", "Saída", "Chegada", "Duração", "Observação"]);
    for (var log in logs) {
      rows.add([log.id, log.nomeMotorista, log.localInicio, log.destino, DateFormat('HH:mm').format(log.horaSaida), DateFormat('HH:mm').format(log.horaChegada), log.tempoTrajeto.inMinutes, log.observacao]);
    }
    String csvData = const ListToCsvConverter().convert(rows);
    await File(path).writeAsString(csvData);
    return path;
  }

  /// Gera Relatório em Texto formatado (TXT) - MÉTODO RESTAURADO PARA CORRIGIR O ERRO
  static Future<String> gerarRelatorioTexto(List<TransporteLog> logs, String periodo) async {
    if (logs.isEmpty) return "Nenhum registro encontrado para este período (${periodo.toUpperCase()}).";

    String conteudo = "=== RELATÓRIO Souza transporte (${periodo.toUpperCase()}) ===\n";
    conteudo += "Gerado em: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}\n";
    conteudo += "==========================================\n\n";

    for (var log in logs) {
      conteudo += "ID: ${log.id} | MOTORISTA: ${log.nomeMotorista}\n";
      conteudo += "ROTA: ${log.localInicio} -> ${log.destino}\n";
      conteudo += "SAÍDA: ${DateFormat('HH:mm').format(log.horaSaida)} | CHEGADA: ${DateFormat('HH:mm').format(log.horaChegada)}\n";
      conteudo += "DURAÇÃO: ${log.tempoTrajeto.inMinutes} min | OBS: ${log.observacao}\n";
      conteudo += "------------------------------------------\n";
    }

    return conteudo;
  }
}