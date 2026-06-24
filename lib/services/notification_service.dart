import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Serviço responsável pelo registro e envio de notificações locais no sistema operacional (Android).
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Inicializa as configurações do canal de notificações local do dispositivo móvel
  static Future<void> inicializar() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(initializationSettings);
  }

  /// Dispara um alerta nativo sonoro com vibração na bandeja do celular
  static Future<void> dispararNotificacao(String titulo, String corpo) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'canal_souza',
      'Alertas Souza Transportes',
      channelDescription: 'Canal de alertas de faturamento e trajetos vazios',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      DateTime.now().millisecond,
      titulo,
      corpo,
      platformChannelSpecifics,
    );
  }
}