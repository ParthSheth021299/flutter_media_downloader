import 'package:flutter/services.dart';

class CustomNotifications {
  static const MethodChannel _channel =
  MethodChannel('custom_notifications');

  static Future<void> showCustomNotification(String title, String message) async {

    try {
      await _channel.invokeMethod('showCustomNotification', {
        'title': title,
        'message': message,
      });
    } catch (e) {
      print('Error showing custom notification: $e');
    }
  }
}
