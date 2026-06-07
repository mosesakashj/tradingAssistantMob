import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'trading_alerts',
    'Trading Alerts',
    description: 'Margin warnings and trade notifications',
    importance: Importance.high,
  );

  static Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings =
        InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);

    // Create the notification channel
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_androidChannel);
  }

  static Future<void> showMarginWarning({
    required double marginLevel,
    required String aiExplanation,
  }) async {
    await _plugin.show(
      1, // fixed ID for margin warnings — replaces previous
      '⚠️ Margin Warning: ${marginLevel.toStringAsFixed(1)}%',
      aiExplanation,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  static Future<void> showTradeInsight({
    required String tradeId,
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      tradeId.hashCode & 0x7FFFFFFF,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  static Future<void> cancelAll() => _plugin.cancelAll();
}
