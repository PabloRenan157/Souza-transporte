import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart'; 
import '../models/transporte_log.dart';

/// Serviço responsável pelo armazenamento local persistente, exportação e manutenção preventiva de dados.
class LogService {
  static const String _storageKeyBase = 'souza_transportes_logs';

  static String _getStorageKey(String username) => '${_storageKeyBase}_$username';

  /// Salva um novo log no armazenamento local de um motorista específico
  static Future<void> salvarLog(TransporteLog log, String username) async {
    final prefs = await SharedPreferences.getInstance();
    final String key = _getStorageKey(username);
    List<String> historicoJson = prefs.getStringList(key) ?? [];
    
    historicoJson.removeWhere((item) {
      final tempLog = TransporteLog.fromJson(item);
      return tempLog.id == log.id;
    });

    historicoJson.add(log.toJson());
    await prefs.setStringList(key, historicoJson);
  }

  /// Obtém o histórico exclusivo de um motorista
  static Future<List<TransporteLog>> obterHistorico(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final String key = _getStorageKey(username);
    List<String>? historicoJson = prefs.getStringList(key);
    if (historicoJson == null) return [];
    
    var logs = historicoJson.map((item) => TransporteLog.fromJson(item)).toList();
    logs.sort((a, b) => a.horaSaida.compareTo(b.horaSaida));
    return logs;
  }

  /// Rotina automática que apaga do dispositivo registos com mais de 90 dias.
  /// Mantém o armazenamento leve e está de acordo com as regras de governança e LGPD.
  static Future<void> limparLogsAntigos(String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String key = _getStorageKey(username);
      List<String> historicoJson = prefs.getStringList(key) ?? [];
      
      // Define a data limite (90 dias atrás a partir de hoje)
      final DateTime limite90Dias = DateTime.now().subtract(const Duration(days: 90));
      List<String> logsMantidos = [];

      for (var item in historicoJson) {
        final log = TransporteLog.fromJson(item);
        
        // REGRA DE SEGURANÇA: Só apaga se tiver mais de 90 dias E se já tiver sido enviado para a Nuvem (sincronizado)
        if (log.horaChegada.isAfter(limite90Dias) || !log.sincronizado) {
          logsMantidos.add(item);
        }
      }

      // Se houver registros antigos apagados, atualiza o armazenamento local
      if (logsMantidos.length < historicoJson.length) {
        await prefs.setStringList(key, logsMantidos);
      }
    } catch (e) {
      // Falha silenciosa para não quebrar a usabilidade do utilizador
    }
  }

  /// Filtra os logs por uma data e por utilizador específico
  static Future<List<TransporteLog>> obterLogsPorData(DateTime data, String username) async {
    final todos = await obterHistorico(username);
    return todos.where((l) => 
      l.horaChegada.year == data.year && 
      l.horaChegada.month == data.month && 
      l.horaChegada.day == data.day
    ).toList();
  }

  /// Atualiza dinamicamente o status de sincronização local de uma corrida
  static Future<void> atualizarStatusSincronizacao(String id, bool sincronizado, String username) async {
    final logs = await obterHistorico(username);
    final index = logs.indexWhere((l) => l.id == id);
    if (index != -1) {
      logs[index] = logs[index].copyWith(sincronizado: sincronizado);
      
      final prefs = await SharedPreferences.getInstance();
      final String key = _getStorageKey(username);
      List<String> historicoJson = logs.map((l) => l.toJson()).toList();
      await prefs.setStringList(key, historicoJson);
    }
  }

  /// Limpa o histórico de registros locais de um motorista específico
  static Future<void> limparHistorico(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final String key = _getStorageKey(username);
    await prefs.remove(key);
  }

  /// Gera arquivo Excel (.xlsx) com estilizações e dados financeiros
  static Future<String> gerarExcel(List<TransporteLog> logs, String path) async {
    var excel = Excel.createExcel();
    String sheetName = "Logistica_Souza_Transportes";
    excel.rename(excel.getDefaultSheet()!, sheetName);
    Sheet sheetObject = excel[sheetName];

    CellStyle headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#00ACC1'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
    );

    List<String> headers = ["ID Amostra", "Motorista", "Origem", "Destino", "Saída", "Chegada", "Duração (min)", "Valor (R\$)", "Obs"];
    for (var i = 0; i < headers.length; i++) {
      var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    for (var i = 0; i < logs.length; i++) {
      var log = logs[i];
      var rowIndex = i + 1;
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = TextCellValue(log.id);
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue(log.nomeMotorista);
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = TextCellValue(log.localInicio);
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = TextCellValue(log.destino);
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = TextCellValue(DateFormat('dd/MM HH:mm').format(log.horaSaida));
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = TextCellValue(DateFormat('dd/MM HH:mm').format(log.horaChegada));
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = IntCellValue(log.tempoTrajeto.inMinutes);
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).value = DoubleCellValue(log.valorCorrida);
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).value = TextCellValue(log.observacao);
    }

    final fileBytes = excel.save();
    final file = File(path);
    await file.writeAsBytes(fileBytes!);
    return file.path;
  }

  /// Gera arquivo CSV
  static Future<String> gerarCSV(List<TransporteLog> logs, String path) async {
    List<List<dynamic>> rows = [];
    rows.add(["ID Amostra", "Motorista", "Origem", "Destino", "Saída", "Chegada", "Duração Min", "Valor Corrida", "Observação"]);
    for (var log in logs) {
      rows.add([
        log.id, 
        log.nomeMotorista, 
        log.localInicio, 
        log.destino, 
        DateFormat('dd/MM HH:mm').format(log.horaSaida), 
        DateFormat('dd/MM HH:mm').format(log.horaChegada), 
        log.tempoTrajeto.inMinutes, 
        log.valorCorrida, 
        log.observacao
      ]);
    }
    String csvData = const ListToCsvConverter().convert(rows);
    await File(path).writeAsString(csvData);
    return path;
  }

  /// Método reativo para disparar a partilha nativa do arquivo via WhatsApp, Telegram, etc.
  static Future<void> partilharArquivo(String caminho, String textoMensagem) async {
    final file = XFile(caminho);
    await Share.shareXFiles([file], text: textoMensagem);
  }
}