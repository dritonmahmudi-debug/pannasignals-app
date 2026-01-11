import 'dart:io';
import 'dart:developer';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class DeviceRegisterService {
  static final DeviceRegisterService _instance = DeviceRegisterService._internal();
  factory DeviceRegisterService() => _instance;
  DeviceRegisterService._internal();

  static const String baseUrl = 'http://194.163.165.198:8000';
  static const String endpoint = '/register_device';

  bool _registered = false;

  Future<void> registerDeviceFCMToken() async {
    if (_registered) return;
    _registered = true;
    try {
      // Request notification permission (especially on iOS)
      final messaging = FirebaseMessaging.instance;
      if (!kIsWeb && Platform.isIOS) {
        await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      final token = await messaging.getToken();
      if (token == null) {
        log('[DeviceRegister] FCM token is null');
        return;
      }

      final info = await PackageInfo.fromPlatform();
      final appVersion = info.version;
      final platform = Platform.isIOS ? 'ios' : 'android';

      final url = Uri.parse('$baseUrl$endpoint');
      final body = {
        'token': token,
        'platform': platform,
        'app_version': appVersion,
      };
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );
      log('[DeviceRegister] Status: ${resp.statusCode}, Body: ${resp.body}');
    } catch (e, st) {
      log('[DeviceRegister] Error: $e', stackTrace: st);
    }

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        final info = await PackageInfo.fromPlatform();
        final appVersion = info.version;
        final platform = Platform.isIOS ? 'ios' : 'android';
        final url = Uri.parse('$baseUrl$endpoint');
        final body = {
          'token': newToken,
          'platform': platform,
          'app_version': appVersion,
        };
        final resp = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        );
        log('[DeviceRegister] TokenRefresh Status: ${resp.statusCode}, Body: ${resp.body}');
      } catch (e, st) {
        log('[DeviceRegister] TokenRefresh Error: $e', stackTrace: st);
      }
    });
  }
}
