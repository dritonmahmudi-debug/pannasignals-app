import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

/// E njëjta URL si në main.dart
const String kApiBaseUrl = 'https://pannasignals.com/api';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _loadingStatus = false;
  bool _loadingSignals = false;
  bool _loadingProfile = false;

  String? _errorStatus;
  String? _errorSignals;
  String? _errorProfile;

  List<AdminStatusItem> _statusItems = [];
  List<Map<String, dynamic>> _signals = [];
  HealthItem? _health;
  List<BotItem> _bots = [];

  final DateFormat _dt = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadStatus(),
      _loadSignals(),
      _loadProfile(),
    ]);
  }

  Future<void> _loadStatus() async {
    setState(() {
      _loadingStatus = true;
      _errorStatus = null;
    });

    try {
      final uri = Uri.parse('$kApiBaseUrl/admin/status');
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) {
        setState(() {
          _errorStatus = 'HTTP ${resp.statusCode}: ${resp.body}';
        });
        return;
      }

      final data = jsonDecode(resp.body);
      if (data is! List) {
        setState(() {
          _errorStatus = 'Përgjigja nuk është listë.';
        });
        return;
      }

      final items = data
          .whereType<Map<String, dynamic>>()
          .map(AdminStatusItem.fromJson)
          .toList();

      setState(() {
        _statusItems = items;
      });
    } catch (e) {
      setState(() {
        _errorStatus = 'Gabim: $e';
      });
    } finally {
      setState(() {
        _loadingStatus = false;
      });
    }
  }

  Future<void> _loadSignals() async {
    setState(() {
      _loadingSignals = true;
      _errorSignals = null;
    });

    try {
      final uri = Uri.parse('$kApiBaseUrl/signals?limit=100');
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) {
        setState(() {
          _errorSignals = 'HTTP ${resp.statusCode}: ${resp.body}';
        });
        return;
      }

      final data = jsonDecode(resp.body);
      if (data is! List) {
        setState(() {
          _errorSignals = 'Përgjigja nuk është listë.';
        });
        return;
      }

      final items = data.whereType<Map<String, dynamic>>().toList();

      setState(() {
        _signals = items;
      });
    } catch (e) {
      setState(() {
        _errorSignals = 'Gabim: $e';
      });
    } finally {
      setState(() {
        _loadingSignals = false;
      });
    }
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loadingProfile = true;
      _errorProfile = null;
    });

    try {
      // 1) /health
      final healthUri = Uri.parse('$kApiBaseUrl/health');
      final healthResp =
          await http.get(healthUri).timeout(const Duration(seconds: 10));

      if (healthResp.statusCode == 200) {
        final map = jsonDecode(healthResp.body);
        if (map is Map<String, dynamic>) {
          _health = HealthItem.fromJson(map);
        }
      } else {
        _errorProfile =
            'Health HTTP ${healthResp.statusCode}: ${healthResp.body}';
      }

      // 2) /api/admin/bots
      final botsUri = Uri.parse('$kApiBaseUrl/api/admin/bots');
      final botsResp =
          await http.get(botsUri).timeout(const Duration(seconds: 10));

      if (botsResp.statusCode == 200) {
        final data = jsonDecode(botsResp.body);
        if (data is List) {
          _bots = data
              .whereType<Map<String, dynamic>>()
              .map(BotItem.fromJson)
              .toList();
        }
      } else {
        // nëse health është ok, por bots jo, ruaj gabimin
        final err =
            'Bots HTTP ${botsResp.statusCode}: ${botsResp.body}';
        _errorProfile =
            (_errorProfile == null) ? err : '${_errorProfile!}\n$err';
      }
    } catch (e) {
      setState(() {
        _errorProfile = 'Gabim: $e';
      });
    } finally {
      setState(() {
        _loadingProfile = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // =========================================================
  //                         BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart), text: 'Status'),
            Tab(icon: Icon(Icons.list_alt), text: 'Signals'),
            Tab(icon: Icon(Icons.person), text: 'Profile'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStatusTab(),
          _buildSignalsTab(),
          _buildProfileTab(),
        ],
      ),
    );
  }

  // ---------------- STATUS TAB ----------------

  Widget _buildStatusTab() {
    if (_loadingStatus) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorStatus != null) {
      return _errorBox(_errorStatus!, onRetry: _loadStatus);
    }
    if (_statusItems.isEmpty) {
      return const Center(
        child: Text(
          'Nuk ka sinjale në 24 orët e fundit.\n(botët s’kanë dërguar asgjë)',
          textAlign: TextAlign.center,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStatus,
      child: ListView.builder(
        itemCount: _statusItems.length,
        itemBuilder: (context, index) {
          final s = _statusItems[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              title: Text(
                s.analysisType,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sinjale në 24h: ${s.totalSignals24h}'),
                  if (s.lastSignalTime != null)
                    Text(
                      'Sinjali i fundit: '
                      '${_dt.format(s.lastSignalTime!)} '
                      '(${s.lastSignalSymbol ?? '-'} ${s.lastSignalDirection ?? '-'})',
                    )
                  else
                    const Text('Asnjë sinjal në 24h'),
                ],
              ),
              trailing: Icon(
                s.isActive ? Icons.check_circle : Icons.help_outline,
                color: s.isActive ? Colors.green : Colors.grey,
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------- SIGNALS TAB ----------------

  Widget _buildSignalsTab() {
    if (_loadingSignals) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorSignals != null) {
      return _errorBox(_errorSignals!, onRetry: _loadSignals);
    }
    if (_signals.isEmpty) {
      return const Center(
        child: Text(
          'Nuk ka sinjale (ose s’janë krijuar ende).',
          textAlign: TextAlign.center,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSignals,
      child: ListView.builder(
        itemCount: _signals.length,
        itemBuilder: (context, index) {
          final m = _signals[index];

          final symbol = m['symbol']?.toString() ?? '-';
          final direction = m['direction']?.toString() ?? '-';
          final timeframe = m['timeframe']?.toString() ?? '-';
          final source = m['source']?.toString() ?? '-';
          final analysisType = m['analysis_type']?.toString() ?? '-';
          final status = m['status']?.toString() ?? '-';
          final timeStr = m['time']?.toString();
          DateTime? t;
          if (timeStr != null) {
            try {
              t = DateTime.parse(timeStr);
            } catch (_) {}
          }

          final entry = (m['entry'] ?? 0).toString();
          final tp = (m['tp'] ?? 0).toString();
          final sl = (m['sl'] ?? 0).toString();

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              title: Text(
                '$symbol $direction ($timeframe)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (t != null) Text('Time: ${_dt.format(t)}'),
                  Text('Source: $source'),
                  Text('Type: $analysisType'),
                  Text('Status: $status'),
                  Text('Entry: $entry | TP: $tp | SL: $sl'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------- PROFILE TAB ----------------

  Widget _buildProfileTab() {
    if (_loadingProfile) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorProfile != null) {
      return _errorBox(_errorProfile!, onRetry: _loadProfile);
    }

    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_health != null)
            Card(
              child: ListTile(
                leading: Icon(
                  _health!.dbOk ? Icons.storage : Icons.storage_rounded,
                  color: _health!.dbOk ? Colors.green : Colors.red,
                ),
                title: const Text('Backend / Database'),
                subtitle: Text(_health!.message),
                trailing: Icon(
                  _health!.firebaseOk
                      ? Icons.notifications_active
                      : Icons.notifications_off,
                  color: _health!.firebaseOk ? Colors.green : Colors.red,
                ),
              ),
            )
          else
            const Card(
              child: ListTile(
                title: Text('Nuk u lexua /health'),
                subtitle: Text('Kontrollo backend-in.'),
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'Bots status (nga /api/heartbeat)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_bots.isEmpty)
            const Text(
              'Asnjë bot nuk është raportuar ende.\n'
              'Skriptat duhet të thërrasin /api/heartbeat për t\'u shfaqur këtu.',
            )
          else
            ..._bots.map(
              (b) => Card(
                child: ListTile(
                  leading: Icon(
                    b.isOnline ? Icons.power : Icons.power_off,
                    color: b.isOnline ? Colors.green : Colors.red,
                  ),
                  title: Text(b.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Last heartbeat: ${_dt.format(b.lastHeartbeat)}'),
                      if (b.lastSignalTime != null)
                        Text(
                            'Last signal: ${_dt.format(b.lastSignalTime!)}'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------- HELPERS ----------------

  Widget _errorBox(String msg, {VoidCallback? onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            Text(
              msg,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (onRetry != null)
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Riprovo'),
              ),
          ],
        ),
      ),
    );
  }
}

// =========================================================
//                        MODELS
// =========================================================

class AdminStatusItem {
  final String analysisType;
  final bool isActive;
  final DateTime? lastSignalTime;
  final String? lastSignalSymbol;
  final String? lastSignalDirection;
  final int totalSignals24h;

  AdminStatusItem({
    required this.analysisType,
    required this.isActive,
    required this.lastSignalTime,
    required this.lastSignalSymbol,
    required this.lastSignalDirection,
    required this.totalSignals24h,
  });

  factory AdminStatusItem.fromJson(Map<String, dynamic> json) {
    DateTime? t;
    final ts = json['last_signal_time']?.toString();
    if (ts != null) {
      try {
        t = DateTime.parse(ts);
      } catch (_) {}
    }

    return AdminStatusItem(
      analysisType: json['analysis_type']?.toString() ?? 'unknown',
      isActive: json['is_active'] == true,
      lastSignalTime: t,
      lastSignalSymbol: json['last_signal_symbol']?.toString(),
      lastSignalDirection: json['last_signal_direction']?.toString(),
      totalSignals24h: (json['total_signals_last_24h'] ?? 0) as int,
    );
  }
}

class HealthItem {
  final String status;
  final String message;
  final bool dbOk;
  final bool firebaseOk;

  HealthItem({
    required this.status,
    required this.message,
    required this.dbOk,
    required this.firebaseOk,
  });

  factory HealthItem.fromJson(Map<String, dynamic> json) {
    return HealthItem(
      status: json['status']?.toString() ?? '-',
      message: json['message']?.toString() ?? '',
      dbOk: json['db_ok'] == true,
      firebaseOk: json['firebase_ok'] == true,
    );
  }
}

class BotItem {
  final String name;
  final DateTime lastHeartbeat;
  final DateTime? lastSignalTime;
  final bool isOnline;

  BotItem({
    required this.name,
    required this.lastHeartbeat,
    required this.lastSignalTime,
    required this.isOnline,
  });

  factory BotItem.fromJson(Map<String, dynamic> json) {
    DateTime hb;
    final hbStr = json['last_heartbeat']?.toString();
    hb = DateTime.tryParse(hbStr ?? '') ?? DateTime.now();

    DateTime? ls;
    final lsStr = json['last_signal_time']?.toString();
    if (lsStr != null) {
      ls = DateTime.tryParse(lsStr);
    }

    return BotItem(
      name: json['name']?.toString() ?? 'unknown',
      lastHeartbeat: hb,
      lastSignalTime: ls,
      isOnline: json['is_online'] == true,
    );
  }
}
