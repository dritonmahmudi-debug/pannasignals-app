import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';

const String BACKEND_BASE_URL = 'https://pannasignals.com/api'; // Backend API URL

class PushNotificationsService {
  static final PushNotificationsService _instance = PushNotificationsService._internal();
  factory PushNotificationsService() => _instance;
  PushNotificationsService._internal();

  Future<void> initPush() async {
    try {
      await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      if (Platform.isIOS) {
        await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
          alert: true, badge: true, sound: true,
        );
      }
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[PUSH] onMessage: title="${message.notification?.title}" body="${message.notification?.body}" data=${message.data}');
      });
      await _registerAndListenToken();
    } catch (e) {
      debugPrint('[PUSH] initPush error: $e');
    }
  }

  Future<void> _registerAndListenToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        debugPrint('FCM TOKEN: $token');
        await _registerDevice(token);
      }
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        debugPrint('FCM TOKEN: $newToken');
        await _registerDevice(newToken);
      });
    } catch (e) {
      debugPrint('[PUSH] Token registration error: $e');
    }
  }

  Future<void> _registerDevice(String token) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final appVersion = info.version;
      final url = '$BACKEND_BASE_URL/register_device';
      final body = jsonEncode({
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'app_version': appVersion,
      });
      final resp = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      if (resp.statusCode == 200) {
        debugPrint('[PUSH] Device registered');
      } else {
        debugPrint('[PUSH] Register failed: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('[PUSH] Register error: $e');
    }
  }
}
