import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';


// IMPORTANT: Do NOT define custom classes or functions named Icon, IconButton, Positioned, PreferredSize, SliverList, or setState in this file or anywhere in the project.
// These are Flutter core widgets/methods. Shadowing them will break widget construction and runtime behavior.
// If you ever need a custom widget, use a unique name (e.g., MyIcon, CustomIconButton, MyPositioned, etc.)
// Verified: No shadowing definitions found in this file.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io' show Platform;
import 'package:intl/intl.dart';
import 'admin_screen.dart';
import 'onboarding_screen.dart';
import 'stats_period.dart';
import 'constants.dart';
    // ...existing code...

// ...existing code...

                                        child: FilterChip(
                                          label: const Text('All'),
                                          selected: _selectedFilter == null,
                                          onSelected: (_) {
                                            this.setState(() {
                                              _selectedFilter = null;
                                            });
                                          },
                                        ),
  final double? tp;
  final double? pnlPercent;
  final bool? isClosed;
  final String? hit;
  final String? source;
  final String? extraText;
  final String? timeframe;
  bool isFavorite;

  Signal({
    required this.id,
    required this.symbol,
    required this.direction,
    required this.time,
    required this.analysisType,
    this.entry,
    this.sl,
    this.tp,
    this.pnlPercent,
    this.isClosed,
    this.hit,
    this.source,
    this.extraText,
    this.timeframe,
    this.isFavorite = false,
  });

  factory Signal.fromJson(Map<String, dynamic> json) {
    return Signal(
      id: json['id'] ?? 0,
      symbol: json['symbol'] ?? '',
      direction: json['direction'] ?? '',
      time: DateTime.tryParse(json['time'] ?? '') ?? DateTime.now(),
      analysisType: json['analysis_type'] ?? '',
      entry: (json['entry'] != null) ? double.tryParse(json['entry'].toString()) : null,
      sl: (json['sl'] != null) ? double.tryParse(json['sl'].toString()) : null,
      tp: (json['tp'] != null) ? double.tryParse(json['tp'].toString()) : null,
      pnlPercent: (json['pnl_percent'] != null) ? double.tryParse(json['pnl_percent'].toString()) : null,
      isClosed: json['is_closed'],
      hit: json['hit'],
      source: json['source'],
      extraText: json['extra_text'],
      timeframe: json['timeframe'],
      isFavorite: json['is_favorite'] ?? false,
    );
  }
}

enum AnalysisType {
  forexSwing,
  forexIntraday,
  cryptoSwing,
  cryptoScalping,
}

extension AnalysisTypeExt on AnalysisType {
  String get label {
    switch (this) {
      case AnalysisType.forexSwing:
        return 'Forex Swing';
      case AnalysisType.forexIntraday:
        return 'Forex Scalping';
      case AnalysisType.cryptoSwing:
        return 'Crypto Swing';
      case AnalysisType.cryptoScalping:
        return 'Crypto Scalping';
    }
  }

  String get apiValue {
    switch (this) {
      case AnalysisType.forexSwing:
        return 'forex_swing';
      case AnalysisType.forexIntraday:
        return 'forex_intraday';
      case AnalysisType.cryptoSwing:
        return 'crypto_swing';
      case AnalysisType.cryptoScalping:
        return 'crypto_scalping';
    }
  }

  IconData get icon {
    switch (this) {
      case AnalysisType.forexSwing:
        return Icons.show_chart;
      case AnalysisType.forexIntraday:
        return Icons.bolt;
      case AnalysisType.cryptoSwing:
        return Icons.currency_bitcoin;
      case AnalysisType.cryptoScalping:
        return Icons.flash_on;
    }
  }

  Color get color {
    switch (this) {
      case AnalysisType.forexSwing:
        return Colors.blueAccent;
      case AnalysisType.forexIntraday:
        return Colors.tealAccent;
      case AnalysisType.cryptoSwing:
        return Colors.orangeAccent;
      case AnalysisType.cryptoScalping:
        return Colors.purpleAccent;
    }
  }

  static AnalysisType? fromApi(String? api) {
    final v = (api ?? '').toLowerCase().trim();
    for (final t in AnalysisType.values) {
      if (t.apiValue == v) return t;
    }
    return null;
  }

  /// Infer analysis_type from source if not explicitly provided
  static AnalysisType? fromSource(String? source) {
    final s = (source ?? '').toLowerCase().trim();
    if (s.contains('forex') && s.contains('swing')) return AnalysisType.forexSwing;
    if (s.contains('forex') && (s.contains('scalp') || s.contains('intraday'))) return AnalysisType.forexIntraday;
    if (s.contains('crypto') && s.contains('swing')) return AnalysisType.cryptoSwing;
    if (s.contains('crypto') && s.contains('scalp')) return AnalysisType.cryptoScalping;
    return null;
  }
}
                          icon: Icon(Icons.bar_chart),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const StatisticsScreen()),
                            );
                          },
                          tooltip: 'Statistics',
                        ),
                        IconButton(
                          icon: Icon(Icons.refresh),
                          onPressed: _loadSignals,
                        ),
                      ],
                      bottom: PreferredSize(
                        preferredSize: const Size.fromHeight(56),
                        child: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          height: 56,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                // "All" filter chip
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: FilterChip(
                                    label: const Text('All'),
                                    selected: _selectedFilter == null,
                                    onSelected: (_) {
                                      setState(() {
                                        _selectedFilter = null;
                                      });
                                    },
                                  ),
                                ),
                                ...AnalysisType.values.map((t) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: FilterChip(
                                      label: Text(t.label),
                                      selected: _selectedFilter == t,
                                      onSelected: (_) {
                                        setState(() {
                                          _selectedFilter = t;
                                        });
                                      },
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: _loading
                          ? const Padding(
                              padding: EdgeInsets.only(top: 80.0),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : _error != null
                              ? Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text('Error: $_error', style: TextStyle(color: Colors.redAccent)),
                                )
                              : _filteredSignals.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.all(24.0),
                                      child: Center(
                                        child: Text('No signals at the moment.', style: TextStyle(color: Colors.grey)),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                    ),

                    if (!_loading && _error == null && _filteredSignals.isNotEmpty)
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final signal = _filteredSignals[index];
                            return SignalCard(
                              signal: signal,
                              isFavorite: favoritesManager.isFavorite(signal),
                              isPremium: premiumManager.isPremium || _isAdmin,
                              onTap: () => _openDetails(signal),
                              onFavoriteToggle: () => _toggleFavorite(signal),
                            );
                          },
                          childCount: _filteredSignals.length,
                        ),
                      ),
                  ],
                ),
              ),
              // TEMP DEBUG BUTTON: Register Device (visible only in debug mode)
              if (kDebugMode)
                Positioned(
                  right: 16,
                  bottom: 16,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                      child: const Text('Register Device'),
                      onPressed: () async {
                        try {
                          final messaging = FirebaseMessaging.instance;
                          if (!kIsWeb && Platform.isIOS) {
                            await messaging.requestPermission(alert: true, badge: true, sound: true);
                          }
                          final token = await messaging.getToken();
                          if (token == null || token.isEmpty) {
                            debugPrint('[RegisterDevice] FCM token is null/empty');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('FCM token is null/empty')));
                            }
                            return;
                          }
                          final info = await PackageInfo.fromPlatform();
                          final appVersion = info.version;
                          final url = Uri.parse('http://194.163.165.198:8000/register_device');
                          final body = {
                            'token': token,
                            'platform': Platform.isIOS ? 'ios' : 'android',
                            'app_version': appVersion,
                          };
                          debugPrint('[RegisterDevice] URL: $url');
                          debugPrint('[RegisterDevice] token length: ${token.length}');
                          final resp = await http.post(
                            url,
                            headers: {'Content-Type': 'application/json'},
                            body: jsonEncode(body),
                          );
                          debugPrint('[RegisterDevice] status: ${resp.statusCode}');
                          debugPrint('[RegisterDevice] body: ${resp.body}');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Token: ${token.length} chars\nStatus: ${resp.statusCode}\nResp: ${resp.body.substring(0, resp.body.length > 120 ? 120 : resp.body.length)}'),
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          }
                        } catch (e, st) {
                          debugPrint('[RegisterDevice] ERROR: $e\n$st');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Register failed: $e')),
                            );
                          }
                        }
                      },
                    ),
                ),
            ],
          ),
        );
      }
    required this.to,
    required this.totalTrades,
    required this.wins,
    required this.losses,
    required this.breakevens,
    required this.winRate,
    required this.avgPnlPercent,
    required this.totalPnlPercent,
  });

  factory StatsResponse.fromJson(Map<String, dynamic> json) {
    final periodStr = (json['period'] ?? 'daily').toString();
    final period = StatsPeriod.values.firstWhere(
      (p) => p.apiValue == periodStr,
      orElse: () => StatsPeriod.daily,
    );
    return StatsResponse(
      analysisType: json['analysis_type']?.toString() ?? '',
      period: period,
      from: DateTime.tryParse(json['date_from'].toString()) ?? DateTime.now(),
      to: DateTime.tryParse(json['date_to'].toString()) ?? DateTime.now(),
      totalTrades: json['total_trades'] ?? 0,
      wins: json['wins'] ?? 0,
      losses: json['losses'] ?? 0,
      breakevens: json['breakevens'] ?? 0,
      winRate: _asDouble(json['win_rate']),
      avgPnlPercent: _asDouble(json['avg_pnl_percent']),
      totalPnlPercent: _asDouble(json['total_pnl_percent']),
    );
  }

double _asDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}
}

// ======================= FAVORITES MANAGER (GLOBAL) =======================

class FavoritesManager extends ChangeNotifier {
  final Set<int> _favoriteIds = {};
  final Map<int, Signal> _signalsById = {};

  bool isFavorite(Signal s) => _favoriteIds.contains(s.id);

  List<Signal> get favorites => _favoriteIds
      .map((id) => _signalsById[id])
      .whereType<Signal>()
      .toList()
    ..sort((a, b) => b.time.compareTo(a.time));

  void updateSignals(List<Signal> signals) {
    for (final s in signals) {
      if (_favoriteIds.contains(s.id)) s.isFavorite = true;
      _signalsById[s.id] = s;
    }
    notifyListeners();
  }

  void toggleFavorite(Signal s) {
    if (_favoriteIds.contains(s.id)) {
      _favoriteIds.remove(s.id);
      s.isFavorite = false;
    } else {
      _favoriteIds.add(s.id);
      s.isFavorite = true;
    }
    _signalsById[s.id] = s;
    notifyListeners();
  }
}

final favoritesManager = FavoritesManager();

// ======================= PREMIUM MANAGER (GLOBAL) =======================

class PremiumManager extends ChangeNotifier {
    @override
    void dispose() {
      _purchaseSub?.cancel();
      super.dispose();
    }
  bool _isPremium = false;
  bool _isLoading = false;
  
  final InAppPurchase _iap = InAppPurchase.instance;
  static const String premiumProductId = 'premium_monthly'; // ID qÃ« do ta krijoni nÃ« Play Console
  
  bool get isPremium => _isPremium;
  bool get isLoading => _isLoading;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  Future<void> initialize() async {
    // Check premium status from backend first
    await checkPremiumFromBackend();

    // Check if billing is available
    final available = await _iap.isAvailable();
    if (!available) {
      debugPrint('âš ï¸ In-app purchases not available');
      return;
    }

    // Listen to purchase updates
    _purchaseSub = _iap.purchaseStream.listen((purchases) async {
      for (final purchase in purchases) {
        if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
          // TODO: verify server-side (ideal)
          await checkPremiumFromBackend();
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
        } else if (purchase.status == PurchaseStatus.error) {
          debugPrint('âŒ Purchase error: ${purchase.error}');
        }
      }
    }, onError: (e) {
      debugPrint('âŒ Error in purchaseStream: $e');
    });

    // Restore purchases on init
    await _restorePurchases();
  }

  Future<void> checkPremiumFromBackend() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    
    final emailRaw = user?.email; // String?
    if (emailRaw == null || emailRaw.isEmpty) {
      return;
    }
    final email = Uri.encodeComponent(emailRaw);
    final response = await http
        .get(Uri.parse('$kApiBaseUrl/premium/check/$email'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      _isPremium = data['is_premium'] ?? false;
      notifyListeners();
    }
  } catch (e) {
    debugPrint('âŒ Error checking premium status: $e');
    // mos e blloko app-in
  }
}


  Future<void> _restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('âŒ Error restoring purchases: $e');
    }
  }

  Future<bool> purchasePremium() async {
    _isLoading = true;
    notifyListeners();
    try {
      // Get product details
      final response = await _iap.queryProductDetails({premiumProductId});
      if (response.productDetails.isEmpty) {
        debugPrint('âš ï¸ Premium product not found in Play Console');
        _isLoading = false;
        notifyListeners();
        return false;
      }
      final product = response.productDetails.first;
      final purchaseParam = PurchaseParam(productDetails: product);
      // Start purchase flow (result handled by purchaseStream)
      _iap.buyNonConsumable(purchaseParam: purchaseParam);
      _isLoading = false;
      notifyListeners();
      // Do not return true immediately; premium status is set after backend verification
      return true;
    } catch (e) {
      debugPrint('âŒ Error purchasing premium: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void setPremium(bool value) {
    if (value == _isPremium) return;
    _isPremium = value;
    notifyListeners();
  }
}

final premiumManager = PremiumManager();

// ======================= APP ROOT + AUTH =======================

class SignalApp extends StatelessWidget {
  const SignalApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData.dark();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Panna Signals',
      navigatorObservers: [FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance)],
      theme: baseTheme.copyWith(
        colorScheme: baseTheme.colorScheme.copyWith(
          primary: Colors.tealAccent,
          secondary: Colors.amberAccent,
        ),
        scaffoldBackgroundColor: const Color(0xFF05070A),
        cardTheme: const CardThemeData(
          elevation: 2,
          margin: EdgeInsets.all(12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF05070A),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF05070A),
          selectedItemColor: Colors.tealAccent,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
        ),
      ),
      home: const OnboardingGate(),
      routes: {
        '/home': (context) => const AuthGate(),
        '/onboarding': (context) => const OnboardingScreen(),
      },
    );
  }
}

class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key});

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool _isLoading = true;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
    
    setState(() {
      _showOnboarding = !onboardingComplete;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_showOnboarding) {
      return const OnboardingScreen();
    }

    return const AuthGate();
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user == null) return const LoginScreen();
        if (!user.emailVerified) return EmailVerificationScreen(user: user);

        return const MainShell();
      },
    );
  }
}

// ======================= LOGIN / REGISTER =======================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text.trim();

      if (_isLogin) {
        final cred = await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: password);

        final user = cred.user;
        if (user == null) throw Exception('User not found');

        // Log login event to Analytics
        await FirebaseAnalytics.instance.logEvent(
          name: 'user_login',
          parameters: {
            'email': email,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );

        if (!user.emailVerified) {
          // DÃ«rgo verification email nga backend
          try {
            await http.post(
              Uri.parse(' kApiBaseUrl/auth/send_verification_email'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'email': email}),
            );
          } catch (e) {
            print('Error sending verification email: $e');
          }
          
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => EmailVerificationScreen(user: user),
            ),
          );
          return;
        }

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      } else {
        final cred = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);

        final user = cred.user;
        if (user == null) throw Exception('User not found');

        // Log registration event to Analytics
        await FirebaseAnalytics.instance.logEvent(
          name: 'user_signup',
          parameters: {
            'email': email,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );

        // DÃ«rgo verification email nga backend (official@pannasignals.com)
        try {
          final response = await http.post(
            Uri.parse(' kApiBaseUrl/auth/send_verification_email'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          );
          if (response.statusCode != 200) {
            print('Failed to send verification email: ${response.body}');
          }
        } catch (e) {
          print('Error sending verification email: $e');
        }

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => EmailVerificationScreen(user: user),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Authentication error';
      if (e.code == 'user-not-found') msg = 'No user found for that email.';
      if (e.code == 'wrong-password') msg = 'Wrong password provided.';
      if (e.code == 'email-already-in-use') msg = 'This email is already in use.';
      if (e.code == 'weak-password') msg = 'Password is too weak.';
      if (e.code == 'invalid-email') msg = 'Invalid email address.';
      setState(() => _error = msg);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email to reset password.'),
        ),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Please check your inbox.'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String msg = 'Error sending reset email.';
      if (e.code == 'user-not-found') msg = 'No user found for that email.';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.show_chart,
                      size: 40,
                      color: Colors.tealAccent,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Panna Signals',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Simple, clear Forex & Crypto signals.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isLogin ? 'Sign in to your account' : 'Create a new account',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Please enter your email';
                        if (!value.contains('@')) return 'Invalid email address';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

                    if (_isLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _resetPassword,
                          child: const Text('Forgot password?'),
                        ),
                      ),

                    const SizedBox(height: 8),

                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),

                    _loading
                        ? const Center(child: CircularProgressIndicator())
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _submit,
                              child: Text(_isLogin ? 'Login' : 'Register'),
                            ),
                          ),

                    const SizedBox(height: 8),

                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLogin = !_isLogin;
                          _error = null;
                        });
                      },
                      child: Text(
                        _isLogin
                            ? 'Don\'t have an account? Register'
                            : 'Already have an account? Login',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  }
}

// ======================= EMAIL VERIFICATION SCREEN =======================

class EmailVerificationScreen extends StatefulWidget {
  final User user;

  const EmailVerificationScreen({super.key, required this.user});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _sending = false;
  bool _checking = false;

  DateTime? _lastSent;
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  @override
  void initState() {
    super.initState();
    // Do not send email automatically to avoid spam
  }

  Future<void> _sendVerificationEmail() async {
    if (_cooldownSeconds > 0) return;
    setState(() => _sending = true);
    try {
      final response = await http.post(
        Uri.parse('$kApiBaseUrl/auth/send_verification_email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.user.email}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification email sent to ${widget.user.email}.')),
        );
        _lastSent = DateTime.now();
        _startCooldown();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send verification email. Please try again.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send verification email. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startCooldown() {
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _cooldownSeconds = 0);
      } else {
        if (mounted) setState(() => _cooldownSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerified() async {
    setState(() => _checking = true);
    try {
      await widget.user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser != null && refreshedUser.emailVerified) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (_) => false,
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email is not verified yet. Please check your inbox.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not check verification. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _useDifferentEmail() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.user.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify your email'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mark_email_read_outlined, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Confirm your email address',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We have sent a verification link to:',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(email, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  const Text(
                    'Please open your email and click the verification link.\nAfter that, tap the button below.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _checking ? null : _checkVerified,
                      child: _checking
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('I have verified my email'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: (_sending || _cooldownSeconds > 0) ? null : _sendVerificationEmail,
                    child: _sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_cooldownSeconds > 0
                            ? 'Resend in ${_cooldownSeconds}s'
                            : 'Resend verification email'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _useDifferentEmail,
                    child: const Text('Use a different email'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ======================= MAIN SHELL =======================

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  final _homeKey = GlobalKey<HomeScreenState>();
  final _historyKey = GlobalKey<HistoryScreenState>();
  final _favoritesKey = GlobalKey<FavoritesScreenState>();

  List<Widget> get _pages {
    final isPremium = premiumManager.isPremium;
    final user = FirebaseAuth.instance.currentUser;
    final isAdmin = user?.email?.toLowerCase() == 'driton.mahmudi@gmail.com';
    return [
      HomeScreen(key: _homeKey),
      HistoryScreen(key: _historyKey),
      if (isPremium || isAdmin) FavoritesScreen(key: _favoritesKey),
      const SettingsScreen(),
    ];
  }

  @override
  void initState() {
    super.initState();
    premiumManager.addListener(_onPremiumChanged);
    _setupFcm();
  }
  
  @override
  void dispose() {
    premiumManager.removeListener(_onPremiumChanged);
    super.dispose();
  }
  
  void _onPremiumChanged() {
    setState(() {
      // Reset to Signals tab if current tab becomes unavailable
      if (_selectedIndex >= _pages.length) {
        _selectedIndex = 0;
      }
    });
  }

  Future<void> _setupFcm() async {
    try {
      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission();

      final token = await messaging.getToken();
      debugPrint('ðŸ“² FCM TOKEN: $token');

      if (token != null) {
        final uri = Uri.parse('$kApiBaseUrl/register_device');
        final resp = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'token': token, 'platform': 'android'}),
        ).timeout(const Duration(seconds: 10));
        debugPrint('ðŸ“¡ /register_device response: ${resp.statusCode} ${resp.body}');
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        if (notification != null && mounted) {
          final snackText =
              '${notification.title ?? 'New signal'}\n${notification.body ?? ''}';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(snackText), duration: const Duration(seconds: 3)),
          );
        }
      });
    } catch (e) {
      debugPrint('âŒ Error in FCM setup: $e');
    }
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final isPremium = premiumManager.isPremium;
    final user = FirebaseAuth.instance.currentUser;
    final isAdmin = user?.email?.toLowerCase() == 'driton.mahmudi@gmail.com';
    
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Signals'),
          const BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          if (isPremium || isAdmin)
            const BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favorites'),
          const BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'More'),
        ],
      ),
    );
  }
}

// ======================= HOME (SIGNALS) =======================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  AnalysisType? _selectedFilter;
  bool _loading = false;
  String? _error;
  List<Signal> _filteredSignals = [];
  bool _isAdmin = false;

  final FavoritesManager favoritesManager = FavoritesManager();
  final PremiumManager premiumManager = PremiumManager();

  @override
  void initState() {
    super.initState();
    _loadSignals();
  }

  void _openDetails(Signal signal) {
    // TODO
  }

  void _toggleFavorite(Signal signal) {
    setState(() {
      favoritesManager.toggleFavorite(signal);
    });
  }

  Future<void> _loadSignals() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // TODO: fetch
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _filteredSignals = [];
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Signals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StatisticsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSignals,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _buildFilters(),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildTopState()),
          if (!_loading && _error == null && _filteredSignals.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final signal = _filteredSignals[index];
                  return SignalCard(
                    signal: signal,
                    isFavorite: favoritesManager.isFavorite(signal),
                    isPremium: premiumManager.isPremium || _isAdmin,
                    onTap: () => _openDetails(signal),
                    onFavoriteToggle: () => _toggleFavorite(signal),
                  );
                },
                childCount: _filteredSignals.length,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      height: 56,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                label: const Text('All'),
                selected: _selectedFilter == null,
                onSelected: (_) => setState(() => _selectedFilter = null),
              ),
            ),
            ...AnalysisType.values.map((t) {
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  label: Text(t.label),
                  selected: _selectedFilter == t,
                  onSelected: (_) => setState(() => _selectedFilter = t),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTopState() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 80.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text('Error: $_error', style: const TextStyle(color: Colors.redAccent)),
      );
    }
    if (_filteredSignals.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: Text('No signals at the moment.', style: TextStyle(color: Colors.grey))),
      );
    }
    return const SizedBox.shrink();
  }
}


// ======================= SIGNAL CARD =======================

class SignalCard extends StatelessWidget {
  final Signal signal;
  final bool isFavorite;
  final bool isPremium;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  const SignalCard({
    super.key,
    required this.signal,
    required this.isFavorite,
    required this.isPremium,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  Color _directionColor() {
    if (signal.direction == 'BUY') return Colors.greenAccent;
    if (signal.direction == 'SELL') return Colors.redAccent;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final timeText = DateFormat('yyyy-MM-dd HH:mm').format(signal.time);
    final directionColor = _directionColor();
    final t = AnalysisTypeExt.fromApi(signal.analysisType);

    final analysisIcon = t?.icon ?? Icons.insights;
    final analysisLabel = t?.label ?? 'Unknown';
    final analysisColor = t?.color ?? Colors.blueGrey;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: directionColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          signal.symbol,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: directionColor.withAlpha((0.15 * 255).round()),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            signal.direction,
                            style: TextStyle(color: directionColor, fontWeight: FontWeight.w600, fontSize: 11),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.pinkAccent : Colors.grey,
                            size: 20,
                          ),
                          onPressed: onFavoriteToggle,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Stack(
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Entry: ${signal.entry != null ? signal.entry!.toStringAsFixed(4) : '-'}',
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'SL: ${signal.sl != null ? signal.sl!.toStringAsFixed(4) : '-'}',
                                style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'TP: ${signal.tp != null ? signal.tp!.toStringAsFixed(4) : '-'}',
                                style: const TextStyle(fontSize: 12, color: Colors.greenAccent),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (!isPremium)
                          Positioned.fill(
                            child: ClipRect(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                                child: Container(
                                  color: Colors.black.withAlpha((0.1 * 255).round()),
                                  alignment: Alignment.center,
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.lock, size: 14, color: Colors.amberAccent),
                                      SizedBox(width: 4),
                                      Text(
                                        'Premium',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.amberAccent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(analysisIcon, size: 16, color: analysisColor),
                        const SizedBox(width: 4),
                        Text(analysisLabel, style: TextStyle(fontSize: 12, color: analysisColor)),
                        const SizedBox(width: 8),
                        Text(signal.timeframe ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const Spacer(),
                        Text(timeText, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================= LOCKED SIGNAL CARD =======================

class LockedSignalCard extends StatelessWidget {
  final Signal signal;
  final VoidCallback onTap;

  const LockedSignalCard({
    super.key,
    required this.signal,
    required this.onTap,
  });

  Color _directionColor() {
    if (signal.direction == 'BUY') return Colors.greenAccent;
    if (signal.direction == 'SELL') return Colors.redAccent;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final timeText = DateFormat('yyyy-MM-dd HH:mm').format(signal.time);
    final directionColor = _directionColor();
    final t = AnalysisTypeExt.fromApi(signal.analysisType);

    final analysisIcon = t?.icon ?? Icons.insights;
    final analysisLabel = t?.label ?? 'Unknown';
    final analysisColor = t?.color ?? Colors.blueGrey;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // Blurred content
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 60,
                        decoration: BoxDecoration(
                          color: directionColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  signal.symbol,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: directionColor.withAlpha((0.15 * 255).round()),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    signal.direction,
                                    style: TextStyle(color: directionColor, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text('Entry: ${signal.entry.toStringAsFixed(4)}', style: const TextStyle(fontSize: 13)),
                                const SizedBox(width: 8),
                                Text(
                                  'SL: ${signal.sl.toStringAsFixed(4)}',
                                  style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'TP: ${signal.tp.toStringAsFixed(4)}',
                                  style: const TextStyle(fontSize: 12, color: Colors.greenAccent),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(analysisIcon, size: 16, color: analysisColor),
                                const SizedBox(width: 4),
                                Text(analysisLabel, style: TextStyle(fontSize: 12, color: analysisColor)),
                                const SizedBox(width: 8),
                                Text(signal.timeframe, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                const Spacer(),
                                Text(timeText, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Lock overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.black.withAlpha((0.6 * 255).round()),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock, color: Colors.amberAccent, size: 32),
                      SizedBox(height: 8),
                      Text(
                        'Upgrade to Premium',
                        style: TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================= DETAILS SHEET =======================

class SignalDetailsSheet extends StatelessWidget {
  final Signal signal;
  final VoidCallback onToggleFavorite;

  const SignalDetailsSheet({
    super.key,
    required this.signal,
    required this.onToggleFavorite,
  });

  Color _directionColor() {
    if (signal.direction == 'BUY') return Colors.greenAccent;
    if (signal.direction == 'SELL') return Colors.redAccent;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final timeText = DateFormat('yyyy-MM-dd HH:mm').format(signal.time);

    String resultText = '';
    Color? resultColor;
    if (signal.isClosed) {
      final hit = (signal.hit ?? '').toLowerCase();
      if (hit == 'tp') {
        resultText = 'TP';
        resultColor = Colors.greenAccent;
      } else if (hit == 'sl') {
        resultText = 'SL';
        resultColor = Colors.redAccent;
      } else if (hit.contains('be')) {
        resultText = 'Breakeven';
        resultColor = Colors.grey;
      }
    }

    String? pnlText;
    if (signal.pnlPercent != null) {
      final p = signal.pnlPercent!;
      pnlText = '${p >= 0 ? '+' : ''}${p.toStringAsFixed(2)}% PnL';
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          Row(
            children: [
              Text(signal.symbol, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _directionColor().withAlpha((0.15 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  signal.direction,
                  style: TextStyle(color: _directionColor(), fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  signal.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: signal.isFavorite ? Colors.pinkAccent : Colors.grey,
                ),
                onPressed: onToggleFavorite,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (signal.isClosed && resultText.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: resultColor?.withAlpha((0.15 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      resultText == 'TP'
                          ? Icons.check_circle
                          : resultText == 'SL'
                              ? Icons.cancel
                              : Icons.drag_handle,
                      size: 14,
                      color: resultColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      resultText,
                      style: TextStyle(fontSize: 12, color: resultColor, fontWeight: FontWeight.w600),
                    ),
                    if (pnlText != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        pnlText,
                        style: TextStyle(
                          fontSize: 11,
                          color: (signal.pnlPercent ?? 0) >= 0 ? Colors.greenAccent : Colors.redAccent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _infoTile(title: 'Entry', value: signal.entry.toStringAsFixed(5))),
              const SizedBox(width: 12),
              Expanded(child: _infoTile(title: 'TP', value: signal.tp.toStringAsFixed(5), color: Colors.greenAccent)),
              const SizedBox(width: 12),
              Expanded(child: _infoTile(title: 'SL', value: signal.sl.toStringAsFixed(5), color: Colors.redAccent)),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Time: $timeText', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Source: ${signal.source ?? 'Unknown'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          const SizedBox(height: 16),
          if (signal.extraText != null && signal.extraText!.trim().isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(signal.extraText!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final text = _formatSignalForCopy(signal);
                    Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Signal copied to clipboard!')),
                      );
                    }
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy signal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onToggleFavorite,
                  icon: Icon(signal.isFavorite ? Icons.favorite : Icons.favorite_border, size: 18),
                  label: Text(signal.isFavorite ? 'Remove favorite' : 'Add to favorites'),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _infoTile({required String title, required String value, Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF181C24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color ?? Colors.white),
          ),
        ],
      ),
    );
  }

}

String _formatSignalForCopy(Signal signal) {
  // Format the signal for copying (customize as needed)
  return [
    'Symbol: ${signal.symbol}',
    'Direction: ${signal.direction}',
    'Entry: ${signal.entry}',
    'TP: ${signal.tp}',
    'SL: ${signal.sl}',
    if (signal.extraText != null && signal.extraText!.trim().isNotEmpty) 'Info: ${signal.extraText}',
    if (signal.time != null) 'Time: ${signal.time}',
  ].join('\n');
}
}

// ======================= PROMO CARD =======================

class PromoCard extends StatelessWidget {
  const PromoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF101820),
      child: SizedBox(
        height: 80,
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.workspace_premium, color: Colors.amberAccent),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Upgrade to Premium', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('Remove ads and get access to VIP signals.',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            TextButton(onPressed: () {}, child: const Text('View')),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

// ======================= HISTORY SCREEN =======================

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  HistoryScreenState createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  bool _loading = false;
  String? _error;
  List<Signal> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  /// Loads closed signals from backend and updates _history
  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http.get(Uri.parse('$kApiBaseUrl/signals/history')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final List<Signal> signals = data.map((e) => Signal.fromJson(e)).toList();
        setState(() {
          _history = signals;
          _loading = false;
        });
        favoritesManager.updateSignals(signals);
      } else {
        setState(() {
          _error = 'Failed to load history (${response.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading history: $e';
        _loading = false;
      });
    }
  }


  void _openDetails(Signal signal) {
    final user = FirebaseAuth.instance.currentUser;
    final isAdmin = user?.email?.toLowerCase() == 'driton.mahmudi@gmail.com';
    if (!premiumManager.isPremium && !isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upgrade to Premium to view details.')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF10131A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SignalDetailsSheet(
          signal: signal,
          onToggleFavorite: () {
            setState(() => favoritesManager.toggleFavorite(signal));
            Navigator.of(ctx).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _history;

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('History'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadHistory),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _loadHistory,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text('Error: $_error', style: const TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    )
                  : items.isEmpty
                      ? ListView(
                          children: const [
                            Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Center(
                                child: Text(
                                  'No closed signals yet.\nOnce TP/SL/BE are updated in the backend,\nthey will appear here.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final s = items[index];
                            return HistoryCard(
                              signal: s,
                              isFavorite: favoritesManager.isFavorite(s),
                              onTap: () => _openDetails(s),
                              onFavoriteToggle: () => this.setState(() => favoritesManager.toggleFavorite(s)),
                            );
                          },
                        ),
        ),
      ),
    );
  }
}

// ======================= HISTORY CARD =======================

class HistoryCard extends StatelessWidget {
  final Signal signal;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  const HistoryCard({
    super.key,
    required this.signal,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  Color _directionColor() {
    if (signal.direction == 'BUY') return Colors.greenAccent;
    if (signal.direction == 'SELL') return Colors.redAccent;
    return Colors.grey;
  }

  String get _resultLabel {
    final h = (signal.hit ?? '').toLowerCase();
    if (h == 'tp') return 'TP';
    if (h == 'sl') return 'SL';
    if (h.contains('be')) return 'BE';
    return '';
  }

  Color? get _resultColor {
    final h = (signal.hit ?? '').toLowerCase();
    if (h == 'tp') return Colors.greenAccent;
    if (h == 'sl') return Colors.redAccent;
    if (h.contains('be')) return Colors.grey;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final timeText = DateFormat('yyyy-MM-dd HH:mm').format(signal.time);
    final directionColor = _directionColor();
    final resultLabel = _resultLabel;
    final resultColor = _resultColor;

    String? pnlText;
    if (signal.pnlPercent != null) {
      final p = signal.pnlPercent!;
      pnlText = '${p >= 0 ? '+' : ''}${p.toStringAsFixed(2)}%';
    }

    // Avoid shadowing the 'm' prefix by renaming any local variable named 'm' to 'mm' if present in this scope.
    return Card(
      @override
      Widget build(BuildContext context) {
        final timeText = DateFormat('yyyy-MM-dd HH:mm').format(signal.time);
        final directionColor = _directionColor();
        final resultLabel = _resultLabel;
        final resultColor = _resultColor;

        String? pnlText;
        if (signal.pnlPercent != null) {
          final p = signal.pnlPercent!;
          pnlText = '${p >= 0 ? '+' : ''}${p.toStringAsFixed(2)}%';
        }

        return Card(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 60,
                    decoration: BoxDecoration(
                      color: directionColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(signal.symbol,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: directionColor.withAlpha((0.15 * 255).round()),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                signal.direction,
                                style: TextStyle(color: directionColor, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const Spacer(),
                            if (resultLabel.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: resultColor?.withAlpha((0.15 * 255).round()),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      resultLabel == 'TP'
                                          ? Icons.check_circle
                                          : resultLabel == 'SL'
                                              ? Icons.cancel
                                              : Icons.drag_handle,
                                      size: 14,
                                      color: resultColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      resultLabel,
                                      style: TextStyle(fontSize: 12, color: resultColor, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            IconButton(
                              icon: Icon(
                                isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: isFavorite ? Colors.pinkAccent : Colors.grey,
                                size: 20,
                              ),
                              onPressed: onFavoriteToggle,
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Entry: ${signal.entry.toStringAsFixed(4)}',
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'SL: ${signal.sl.toStringAsFixed(4)}',
                                style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'TP: ${signal.tp.toStringAsFixed(4)}',
                                style: const TextStyle(fontSize: 12, color: Colors.greenAccent),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (pnlText != null)
                              Text(
                                pnlText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: (signal.pnlPercent ?? 0) >= 0 ? Colors.greenAccent : Colors.redAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            const Spacer(),
                            Text(timeText, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.toLowerCase();
    return email == 'driton.mahmudi@gmail.com';
  }

  @override
  void initState() {
    super.initState();
    favoritesManager.addListener(_onFavChanged);
  }

  @override
  void dispose() {
    favoritesManager.removeListener(_onFavChanged);
    super.dispose();
  }

  void _onFavChanged() => setState(() {});

  void _openDetails(Signal signal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF10131A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SignalDetailsSheet(
          signal: signal,
          onToggleFavorite: () {
            favoritesManager.toggleFavorite(signal);
            Navigator.of(ctx).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show premium prompt for free users (admins have full access)
    if (!premiumManager.isPremium && !_isAdmin) {
      return SafeArea(
        child: Scaffold(
          appBar: AppBar(title: const Text('Favorites')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.workspace_premium, color: Colors.amberAccent, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Upgrade to Premium',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Save your favorite signals and access them anytime.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Premium subscription coming soon!')),
                      );
                    },
                    child: const Text('Upgrade Now'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    final favs = favoritesManager.favorites;

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Favorites')),
        body: favs.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'You don\'t have any favorite signals yet.\n\nFrom the Signals list or History,\ntap the heart icon to save a signal here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            : ListView.builder(
                itemCount: favs.length,
                itemBuilder: (context, index) {
                  final signal = favs[index];
                  return SignalCard(
                    signal: signal,
                    isFavorite: favoritesManager.isFavorite(signal),
                    isPremium: premiumManager.isPremium || _isAdmin,
                    onTap: () => _openDetails(signal),
                    onFavoriteToggle: () => favoritesManager.toggleFavorite(signal),
                  );
                },
              ),
      ),
    );
  }
}

// ======================= SETTINGS =======================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushEnabled = true;

  static const Set<String> _adminEmails = {
    'driton.mahmudi@gmail.com',
  };

  bool get _isAdmin {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.toLowerCase();
    if (email == null) return false;
    return _adminEmails.contains(email);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _logout() async {
    // Log logout event to Analytics
    await FirebaseAnalytics.instance.logEvent(
      name: 'user_logout',
      parameters: {
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (_) => false,
    );
  }

  void _showTestCrashDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Test Crashlytics'),
        content: const Text(
          'This will trigger a test crash to verify Crashlytics is working.\n\n'
          'Check Firebase Crashlytics console after the app restarts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _triggerTestCrash();
            },
            child: const Text('Trigger crash', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _triggerTestCrash() {
       // Record the test crash intent to Crashlytics before crashing
    FirebaseCrashlytics.instance.log('ðŸ§ª User triggered test crash via admin button');
    
    // Throw an exception that Crashlytics will capture
    throw Exception('ðŸ§ª Test crash triggered by admin button');
  }

  Future<void> _handlePremiumUpgrade() async {
    final success = await premiumManager.purchasePremium();
    
    if (!mounted) return;
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('âœ… Premium activated! Enjoy full access.'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Log premium purchase event to Analytics
      FirebaseAnalytics.instance.logEvent(
        name: 'premium_purchased',
        parameters: {
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('âš ï¸ Purchase cancelled or failed. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(user.email ?? 'Unknown user'),
                subtitle: const Text('Logged in'),
              ),
            ),

          SwitchListTile(
            value: _pushEnabled,
            onChanged: (v) async {
              this.setState(() => _pushEnabled = v);
              await FirebaseMessaging.instance.setAutoInitEnabled(v);
            },
            title: const Text('Push notifications'),
            subtitle: const Text('Receive trade signal notifications'),
          ),

          const SizedBox(height: 16),

          // âœ… PREMIUM SUBSCRIPTION (hidden for admins)
          if (!_isAdmin)
            ListenableBuilder(
              listenable: premiumManager,
              builder: (context, _) {
                if (premiumManager.isPremium) {
                  return Card(
                    color: Colors.amber.withAlpha(25),
                    child: ListTile(
                      leading: const Icon(Icons.star, color: Colors.amberAccent),
                      title: const Text('Premium Active', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('You have full access to all features'),
                    ),
                  );
                }
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.workspace_premium, color: Colors.amberAccent),
                    title: const Text('Upgrade to Premium'),
                    subtitle: const Text('Unlock VIP signals & advanced analytics'),
                    trailing: premiumManager.isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.chevron_right),
                    onTap: premiumManager.isLoading ? null : _handlePremiumUpgrade,
                  ),
                );
              },
            ),

          const SizedBox(height: 16),

          // âœ… ADMIN TOOLS (only admin - shown instead of Premium)
          if (_isAdmin) ...[
            Card(
              color: Colors.cyan.withAlpha(25),
              child: const ListTile(
                leading: Icon(Icons.admin_panel_settings, color: Colors.cyan),
                title: Text('Admin Access', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Full access to all features & admin panel'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Admin tools',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings),
                    title: const Text('Admin panel'),
                    subtitle: const Text('View raw signals, stats & controls'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AdminScreen()),
                      );
                    },
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: const Icon(Icons.bug_report_outlined, color: Colors.redAccent),
                    title: const Text('Test crash (Crashlytics)', style: TextStyle(color: Colors.redAccent)),
                    subtitle: const Text('âš ï¸ This will trigger a test crash'),
                    onTap: () {
                      _showTestCrashDialog();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // âœ… ABOUT / PRIVACY / SHARE / LOGOUT
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    );
                  },
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy policy'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                    );
                  },
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: const Text('Share app'),
                  onTap: () async {
                    try {
                      await Share.share('Panna Signals: $kStoreUrl');
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Sharing is not available on this device.')),
                        );
                      }
                    }
                  },
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Log out'),
                  onTap: _logout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ======================= STATISTICS SCREEN =======================

class SignalStatsResponse {
  final int totalSignals;
  final double winRate;
  final double avgRR;
  final double avgDuration;
  final Signal? bestSignal;
  final Signal? worstSignal;
  final AnalysisType? analysisType;
  final String period;
  final DateTime? start;
  final DateTime? end;

  SignalStatsResponse({
    required this.totalSignals,
    required this.winRate,
    required this.avgRR,
    required this.avgDuration,
    required this.bestSignal,
    required this.worstSignal,
    required this.analysisType,
    required this.period,
    required this.start,
    required this.end,
  });

  factory SignalStatsResponse.fromJson(Map<String, dynamic> json) {
    return SignalStatsResponse(
      totalSignals: (json['total_signals'] ?? 0) as int,
      winRate: _asDouble(json['win_rate']),
      avgRR: _asDouble(json['avg_rr']),
      avgDuration: _asDouble(json['avg_duration']),
      bestSignal: json['best_signal'] != null ? Signal.fromJson(json['best_signal']) : null,
      worstSignal: json['worst_signal'] != null ? Signal.fromJson(json['worst_signal']) : null,
      analysisType: AnalysisTypeExt.fromApi(json['analysis_type']?.toString()),
      period: (json['period'] ?? '').toString(),
      start: json['start'] != null ? DateTime.tryParse(json['start'].toString()) : null,
      end: json['end'] != null ? DateTime.tryParse(json['end'].toString()) : null,
    );
  }
}

double _asDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _loading = false;
  String? _error;
  SignalStatsResponse? _stats;

  AnalysisType _selectedType = AnalysisType.values.first;
  StatsPeriod _selectedPeriod = StatsPeriod.values.first;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  String _periodValue(StatsPeriod p) => p.toString().split('.').last;

  Future<void> _fetchStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse(
        '\/stats?analysis_type=\&period=\',
      );

      final resp = await http.get(uri).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) {
        throw Exception('HTTP \: \');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final stats = SignalStatsResponse.fromJson(data);

      if (!mounted) return;
      setState(() => _stats = stats);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _stats = null;
      });
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Widget _tile(String title, String value) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(title.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchStats,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<AnalysisType>(
                      value: _selectedType,
                      decoration: const InputDecoration(labelText: 'Strategy'),
                      items: AnalysisType.values
                          .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _selectedType = v);
                        _fetchStats();
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<StatsPeriod>(
                      value: _selectedPeriod,
                      decoration: const InputDecoration(labelText: 'Period'),
                      items: StatsPeriod.values
                          .map((p) => DropdownMenuItem(value: p, child: Text(_periodValue(p))))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _selectedPeriod = v);
                        _fetchStats();
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 50),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('Error: \', style: const TextStyle(color: Colors.redAccent)),
              )
            else if (stats == null)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('No stats yet. Pull to refresh.'),
              )
            else ...[
              Row(
                children: [
                  _tile('Total', stats.totalSignals.toString()),
                  _tile('Win rate', '\%'),
                ],
              ),
              Row(
                children: [
                  _tile('Avg RR', stats.avgRR.toStringAsFixed(2)),
                  _tile('Avg dur', '\m'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ======================= FAVORITES MANAGER (GLOBAL) =======================

class FavoritesManager extends ChangeNotifier {
  final Set<int> _favoriteIds = {};
  final Map<int, Signal> _signalsById = {};

  bool isFavorite(Signal s) => _favoriteIds.contains(s.id);

  List<Signal> get favorites => _favoriteIds
      .map((id) => _signalsById[id])
      .whereType<Signal>()
      .toList()
    ..sort((a, b) => b.time.compareTo(a.time));

  void updateSignals(List<Signal> signals) {
    for (final s in signals) {
      if (_favoriteIds.contains(s.id)) s.isFavorite = true;
      _signalsById[s.id] = s;
    }
    notifyListeners();
  }

  void toggleFavorite(Signal s) {
    if (_favoriteIds.contains(s.id)) {
      _favoriteIds.remove(s.id);
      s.isFavorite = false;
    } else {
      _favoriteIds.add(s.id);
      s.isFavorite = true;
    }
    _signalsById[s.id] = s;
    notifyListeners();
  }
}

final favoritesManager = FavoritesManager();

// ======================= PREMIUM MANAGER (GLOBAL) =======================

class PremiumManager extends ChangeNotifier {
    @override
    void dispose() {
      _purchaseSub?.cancel();
      super.dispose();
    }
  bool _isPremium = false;
  bool _isLoading = false;
  
  final InAppPurchase _iap = InAppPurchase.instance;
  static const String premiumProductId = 'premium_monthly'; // ID qÃ« do ta krijoni nÃ« Play Console
  
  bool get isPremium => _isPremium;
  bool get isLoading => _isLoading;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  Future<void> initialize() async {
    // Check premium status from backend first
    await checkPremiumFromBackend();

    // Check if billing is available
    final available = await _iap.isAvailable();
    if (!available) {
      debugPrint('âš ï¸ In-app purchases not available');
      return;
    }

    // Listen to purchase updates
    _purchaseSub = _iap.purchaseStream.listen((purchases) async {
      for (final purchase in purchases) {
        if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
          // TODO: verify server-side (ideal)
          await checkPremiumFromBackend();
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
        } else if (purchase.status == PurchaseStatus.error) {
          debugPrint('âŒ Purchase error: ${purchase.error}');
        }
      }
    }, onError: (e) {
      debugPrint('âŒ Error in purchaseStream: $e');
    });

    // Restore purchases on init
    await _restorePurchases();
  }

  Future<void> checkPremiumFromBackend() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    
    final emailRaw = user?.email; // String?
    if (emailRaw == null || emailRaw.isEmpty) {
      return;
    }
    final email = Uri.encodeComponent(emailRaw);
    final response = await http
        .get(Uri.parse('$kApiBaseUrl/premium/check/$email'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      _isPremium = data['is_premium'] ?? false;
      notifyListeners();
    }
  } catch (e) {
    debugPrint('âŒ Error checking premium status: $e');
    // mos e blloko app-in
  }
}


  Future<void> _restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('âŒ Error restoring purchases: $e');
    }
  }

  Future<bool> purchasePremium() async {
    _isLoading = true;
    notifyListeners();
    try {
      // Get product details
      final response = await _iap.queryProductDetails({premiumProductId});
      if (response.productDetails.isEmpty) {
        debugPrint('âš ï¸ Premium product not found in Play Console');
        _isLoading = false;
        notifyListeners();
        return false;
      }
      final product = response.productDetails.first;
      final purchaseParam = PurchaseParam(productDetails: product);
      // Start purchase flow (result handled by purchaseStream)
      _iap.buyNonConsumable(purchaseParam: purchaseParam);
      _isLoading = false;
      notifyListeners();
      // Do not return true immediately; premium status is set after backend verification
      return true;
    } catch (e) {
      debugPrint('âŒ Error purchasing premium: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void setPremium(bool value) {
    if (value == _isPremium) return;
    _isPremium = value;
    notifyListeners();
  }
}

final premiumManager = PremiumManager();

// ======================= APP ROOT + AUTH =======================

class SignalApp extends StatelessWidget {
  const SignalApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData.dark();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Panna Signals',
      navigatorObservers: [FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance)],
      theme: baseTheme.copyWith(
        colorScheme: baseTheme.colorScheme.copyWith(
          primary: Colors.tealAccent,
          secondary: Colors.amberAccent,
        ),
        scaffoldBackgroundColor: const Color(0xFF05070A),
        cardTheme: const CardThemeData(
          elevation: 2,
          margin: EdgeInsets.all(12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF05070A),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF05070A),
          selectedItemColor: Colors.tealAccent,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
        ),
      ),
      home: const OnboardingGate(),
      routes: {
        '/home': (context) => const AuthGate(),
        '/onboarding': (context) => const OnboardingScreen(),
      },
    );
  }
}

class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key});

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool _isLoading = true;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
    
    setState(() {
      _showOnboarding = !onboardingComplete;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_showOnboarding) {
      return const OnboardingScreen();
    }

    return const AuthGate();
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user == null) return const LoginScreen();
        if (!user.emailVerified) return EmailVerificationScreen(user: user);

        return const MainShell();
      },
    );
  }
}

// ======================= LOGIN / REGISTER =======================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text.trim();

      if (_isLogin) {
        final cred = await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: password);

        final user = cred.user;
        if (user == null) throw Exception('User not found');

        // Log login event to Analytics
        await FirebaseAnalytics.instance.logEvent(
          name: 'user_login',
          parameters: {
            'email': email,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );

        if (!user.emailVerified) {
          // DÃ«rgo verification email nga backend
          try {
            await http.post(
              Uri.parse(' kApiBaseUrl/auth/send_verification_email'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'email': email}),
            );
          } catch (e) {
            print('Error sending verification email: $e');
          }
          
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => EmailVerificationScreen(user: user),
            ),
          );
          return;
        }

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      } else {
        final cred = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);

        final user = cred.user;
        if (user == null) throw Exception('User not found');

        // Log registration event to Analytics
        await FirebaseAnalytics.instance.logEvent(
          name: 'user_signup',
          parameters: {
            'email': email,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );

        // DÃ«rgo verification email nga backend (official@pannasignals.com)
        try {
          final response = await http.post(
            Uri.parse(' kApiBaseUrl/auth/send_verification_email'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          );
          if (response.statusCode != 200) {
            print('Failed to send verification email: ${response.body}');
          }
        } catch (e) {
          print('Error sending verification email: $e');
        }

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => EmailVerificationScreen(user: user),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Authentication error';
      if (e.code == 'user-not-found') msg = 'No user found for that email.';
      if (e.code == 'wrong-password') msg = 'Wrong password provided.';
      if (e.code == 'email-already-in-use') msg = 'This email is already in use.';
      if (e.code == 'weak-password') msg = 'Password is too weak.';
      if (e.code == 'invalid-email') msg = 'Invalid email address.';
      setState(() => _error = msg);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email to reset password.'),
        ),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Please check your inbox.'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String msg = 'Error sending reset email.';
      if (e.code == 'user-not-found') msg = 'No user found for that email.';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.show_chart,
                      size: 40,
                      color: Colors.tealAccent,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Panna Signals',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Simple, clear Forex & Crypto signals.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isLogin ? 'Sign in to your account' : 'Create a new account',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Please enter your email';
                        if (!value.contains('@')) return 'Invalid email address';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

                    if (_isLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _resetPassword,
                          child: const Text('Forgot password?'),
                        ),
                      ),

                    const SizedBox(height: 8),

                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),

                    _loading
                        ? const Center(child: CircularProgressIndicator())
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _submit,
                              child: Text(_isLogin ? 'Login' : 'Register'),
                            ),
                          ),

                    const SizedBox(height: 8),

                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLogin = !_isLogin;
                          _error = null;
                        });
                      },
                      child: Text(
                        _isLogin
                            ? 'Don\'t have an account? Register'
                            : 'Already have an account? Login',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  }
}

// ======================= EMAIL VERIFICATION SCREEN =======================

class EmailVerificationScreen extends StatefulWidget {
  final User user;

  const EmailVerificationScreen({super.key, required this.user});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _sending = false;
  bool _checking = false;

  DateTime? _lastSent;
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  @override
  void initState() {
    super.initState();
    // Do not send email automatically to avoid spam
  }

  Future<void> _sendVerificationEmail() async {
    if (_cooldownSeconds > 0) return;
    setState(() => _sending = true);
    try {
      final response = await http.post(
        Uri.parse('$kApiBaseUrl/auth/send_verification_email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.user.email}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification email sent to ${widget.user.email}.')),
        );
        _lastSent = DateTime.now();
        _startCooldown();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send verification email. Please try again.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send verification email. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startCooldown() {
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _cooldownSeconds = 0);
      } else {
        if (mounted) setState(() => _cooldownSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerified() async {
    setState(() => _checking = true);
    try {
      await widget.user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser != null && refreshedUser.emailVerified) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (_) => false,
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email is not verified yet. Please check your inbox.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not check verification. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _useDifferentEmail() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.user.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify your email'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mark_email_read_outlined, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Confirm your email address',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We have sent a verification link to:',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(email, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  const Text(
                    'Please open your email and click the verification link.\nAfter that, tap the button below.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _checking ? null : _checkVerified,
                      child: _checking
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('I have verified my email'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: (_sending || _cooldownSeconds > 0) ? null : _sendVerificationEmail,
                    child: _sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_cooldownSeconds > 0
                            ? 'Resend in ${_cooldownSeconds}s'
                            : 'Resend verification email'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _useDifferentEmail,
                    child: const Text('Use a different email'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ======================= MAIN SHELL =======================

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  final _homeKey = GlobalKey<HomeScreenState>();
  final _historyKey = GlobalKey<HistoryScreenState>();
  final _favoritesKey = GlobalKey<FavoritesScreenState>();

  List<Widget> get _pages {
    final isPremium = premiumManager.isPremium;
    final user = FirebaseAuth.instance.currentUser;
    final isAdmin = user?.email?.toLowerCase() == 'driton.mahmudi@gmail.com';
    return [
      HomeScreen(key: _homeKey),
      HistoryScreen(key: _historyKey),
      if (isPremium || isAdmin) FavoritesScreen(key: _favoritesKey),
      const SettingsScreen(),
    ];
  }

  @override
  void initState() {
    super.initState();
    premiumManager.addListener(_onPremiumChanged);
    _setupFcm();
  }
  
  @override
  void dispose() {
    premiumManager.removeListener(_onPremiumChanged);
    super.dispose();
  }
  
  void _onPremiumChanged() {
    setState(() {
      // Reset to Signals tab if current tab becomes unavailable
      if (_selectedIndex >= _pages.length) {
        _selectedIndex = 0;
      }
    });
  }

  Future<void> _setupFcm() async {
    try {
      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission();

      final token = await messaging.getToken();
      debugPrint('ðŸ“² FCM TOKEN: $token');

      if (token != null) {
        final uri = Uri.parse('$kApiBaseUrl/register_device');
        final resp = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'token': token, 'platform': 'android'}),
        ).timeout(const Duration(seconds: 10));
        debugPrint('ðŸ“¡ /register_device response: ${resp.statusCode} ${resp.body}');
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        if (notification != null && mounted) {
          final snackText =
              '${notification.title ?? 'New signal'}\n${notification.body ?? ''}';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(snackText), duration: const Duration(seconds: 3)),
          );
        }
      });
    } catch (e) {
      debugPrint('âŒ Error in FCM setup: $e');
    }
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final isPremium = premiumManager.isPremium;
    final user = FirebaseAuth.instance.currentUser;
    final isAdmin = user?.email?.toLowerCase() == 'driton.mahmudi@gmail.com';
    
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Signals'),
          const BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          if (isPremium || isAdmin)
            const BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favorites'),
          const BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'More'),
        ],
      ),
    );
  }
}

// ======================= HOME (SIGNALS) =======================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  AnalysisType? _selectedFilter;
  bool _loading = false;
  String? _error;
  List<Signal> _filteredSignals = [];
  bool _isAdmin = false;

  final FavoritesManager favoritesManager = FavoritesManager();
  final PremiumManager premiumManager = PremiumManager();

  @override
  void initState() {
    super.initState();
    _loadSignals();
  }

  void _openDetails(Signal signal) {
    // TODO
  }

  void _toggleFavorite(Signal signal) {
    setState(() {
      favoritesManager.toggleFavorite(signal);
    });
  }

  Future<void> _loadSignals() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // TODO: fetch
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _filteredSignals = [];
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Signals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StatisticsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSignals,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _buildFilters(),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildTopState()),
          if (!_loading && _error == null && _filteredSignals.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final signal = _filteredSignals[index];
                  return SignalCard(
                    signal: signal,
                    isFavorite: favoritesManager.isFavorite(signal),
                    isPremium: premiumManager.isPremium || _isAdmin,
                    onTap: () => _openDetails(signal),
                    onFavoriteToggle: () => _toggleFavorite(signal),
                  );
                },
                childCount: _filteredSignals.length,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      height: 56,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                label: const Text('All'),
                selected: _selectedFilter == null,
                onSelected: (_) => setState(() => _selectedFilter = null),
              ),
            ),
            ...AnalysisType.values.map((t) {
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  label: Text(t.label),
                  selected: _selectedFilter == t,
                  onSelected: (_) => setState(() => _selectedFilter = t),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTopState() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 80.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text('Error: $_error', style: const TextStyle(color: Colors.redAccent)),
      );
    }
    if (_filteredSignals.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: Text('No signals at the moment.', style: TextStyle(color: Colors.grey))),
      );
    }
    return const SizedBox.shrink();
  }
}


// ======================= SIGNAL CARD =======================

class SignalCard extends StatelessWidget {
  final Signal signal;
  final bool isFavorite;
  final bool isPremium;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  const SignalCard({
    super.key,
    required this.signal,
    required this.isFavorite,
    required this.isPremium,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  Color _directionColor() {
    if (signal.direction == 'BUY') return Colors.greenAccent;
    if (signal.direction == 'SELL') return Colors.redAccent;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final timeText = DateFormat('yyyy-MM-dd HH:mm').format(signal.time);
    final directionColor = _directionColor();
    final t = AnalysisTypeExt.fromApi(signal.analysisType);

    final analysisIcon = t?.icon ?? Icons.insights;
    final analysisLabel = t?.label ?? 'Unknown';
    final analysisColor = t?.color ?? Colors.blueGrey;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: directionColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          signal.symbol,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: directionColor.withAlpha((0.15 * 255).round()),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            signal.direction,
                            style: TextStyle(color: directionColor, fontWeight: FontWeight.w600, fontSize: 11),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.pinkAccent : Colors.grey,
                            size: 20,
                          ),
                          onPressed: onFavoriteToggle,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Stack(
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Entry: ${signal.entry != null ? signal.entry!.toStringAsFixed(4) : '-'}',
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'SL: ${signal.sl != null ? signal.sl!.toStringAsFixed(4) : '-'}',
                                style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'TP: ${signal.tp != null ? signal.tp!.toStringAsFixed(4) : '-'}',
                                style: const TextStyle(fontSize: 12, color: Colors.greenAccent),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (!isPremium)
                          Positioned.fill(
                            child: ClipRect(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                                child: Container(
                                  color: Colors.black.withAlpha((0.1 * 255).round()),
                                  alignment: Alignment.center,
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.lock, size: 14, color: Colors.amberAccent),
                                      SizedBox(width: 4),
                                      Text(
                                        'Premium',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.amberAccent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(analysisIcon, size: 16, color: analysisColor),
                        const SizedBox(width: 4),
                        Text(analysisLabel, style: TextStyle(fontSize: 12, color: analysisColor)),
                        const SizedBox(width: 8),
                        Text(signal.timeframe ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const Spacer(),
                        Text(timeText, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================= LOCKED SIGNAL CARD =======================

class LockedSignalCard extends StatelessWidget {
  final Signal signal;
  final VoidCallback onTap;

  const LockedSignalCard({
    super.key,
    required this.signal,
    required this.onTap,
  });

  Color _directionColor() {
    if (signal.direction == 'BUY') return Colors.greenAccent;
    if (signal.direction == 'SELL') return Colors.redAccent;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final timeText = DateFormat('yyyy-MM-dd HH:mm').format(signal.time);
    final directionColor = _directionColor();
    final t = AnalysisTypeExt.fromApi(signal.analysisType);

    final analysisIcon = t?.icon ?? Icons.insights;
    final analysisLabel = t?.label ?? 'Unknown';
    final analysisColor = t?.color ?? Colors.blueGrey;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // Blurred content
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 60,
                        decoration: BoxDecoration(
                          color: directionColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  signal.symbol,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: directionColor.withAlpha((0.15 * 255).round()),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    signal.direction,
                                    style: TextStyle(color: directionColor, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text('Entry: ${signal.entry.toStringAsFixed(4)}', style: const TextStyle(fontSize: 13)),
                                const SizedBox(width: 8),
                                Text(
                                  'SL: ${signal.sl.toStringAsFixed(4)}',
                                  style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'TP: ${signal.tp.toStringAsFixed(4)}',
                                  style: const TextStyle(fontSize: 12, color: Colors.greenAccent),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(analysisIcon, size: 16, color: analysisColor),
                                const SizedBox(width: 4),
                                Text(analysisLabel, style: TextStyle(fontSize: 12, color: analysisColor)),
                                const SizedBox(width: 8),
                                Text(signal.timeframe, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                const Spacer(),
                                Text(timeText, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Lock overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.black.withAlpha((0.6 * 255).round()),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock, color: Colors.amberAccent, size: 32),
                      SizedBox(height: 8),
                      Text(
                        'Upgrade to Premium',
                        style: TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================= DETAILS SHEET =======================

class SignalDetailsSheet extends StatelessWidget {
  final Signal signal;
  final VoidCallback onToggleFavorite;

  const SignalDetailsSheet({
    super.key,
    required this.signal,
    required this.onToggleFavorite,
  });

  Color _directionColor() {
    if (signal.direction == 'BUY') return Colors.greenAccent;
    if (signal.direction == 'SELL') return Colors.redAccent;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final timeText = DateFormat('yyyy-MM-dd HH:mm').format(signal.time);

    String resultText = '';
    Color? resultColor;
    if (signal.isClosed) {
      final hit = (signal.hit ?? '').toLowerCase();
      if (hit == 'tp') {
        resultText = 'TP';
        resultColor = Colors.greenAccent;
      } else if (hit == 'sl') {
        resultText = 'SL';
        resultColor = Colors.redAccent;
      } else if (hit.contains('be')) {
        resultText = 'Breakeven';
        resultColor = Colors.grey;
      }
    }

    String? pnlText;
    if (signal.pnlPercent != null) {
      final p = signal.pnlPercent!;
      pnlText = '${p >= 0 ? '+' : ''}${p.toStringAsFixed(2)}% PnL';
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          Row(
            children: [
              Text(signal.symbol, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _directionColor().withAlpha((0.15 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  signal.direction,
                  style: TextStyle(color: _directionColor(), fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  signal.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: signal.isFavorite ? Colors.pinkAccent : Colors.grey,
                ),
                onPressed: onToggleFavorite,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (signal.isClosed && resultText.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: resultColor?.withAlpha((0.15 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      resultText == 'TP'
                          ? Icons.check_circle
                          : resultText == 'SL'
                              ? Icons.cancel
                              : Icons.drag_handle,
                      size: 14,
                      color: resultColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      resultText,
                      style: TextStyle(fontSize: 12, color: resultColor, fontWeight: FontWeight.w600),
                    ),
                    if (pnlText != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        pnlText,
                        style: TextStyle(
                          fontSize: 11,
                          color: (signal.pnlPercent ?? 0) >= 0 ? Colors.greenAccent : Colors.redAccent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _infoTile(title: 'Entry', value: signal.entry.toStringAsFixed(5))),
              const SizedBox(width: 12),
              Expanded(child: _infoTile(title: 'TP', value: signal.tp.toStringAsFixed(5), color: Colors.greenAccent)),
              const SizedBox(width: 12),
              Expanded(child: _infoTile(title: 'SL', value: signal.sl.toStringAsFixed(5), color: Colors.redAccent)),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Time: $timeText', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Source: ${signal.source ?? 'Unknown'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          const SizedBox(height: 16),
          if (signal.extraText != null && signal.extraText!.trim().isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(signal.extraText!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final text = _formatSignalForCopy(signal);
                    Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Signal copied to clipboard!')),
                      );
                    }
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy signal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onToggleFavorite,
                  icon: Icon(signal.isFavorite ? Icons.favorite : Icons.favorite_border, size: 18),
                  label: Text(signal.isFavorite ? 'Remove favorite' : 'Add to favorites'),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _infoTile({required String title, required String value, Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF181C24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color ?? Colors.white),
          ),
        ],
      ),
    );
  }

}

String _formatSignalForCopy(Signal signal) {
  // Format the signal for copying (customize as needed)
  return [
    'Symbol: ${signal.symbol}',
    'Direction: ${signal.direction}',
    'Entry: ${signal.entry}',
    'TP: ${signal.tp}',
    'SL: ${signal.sl}',
    if (signal.extraText != null && signal.extraText!.trim().isNotEmpty) 'Info: ${signal.extraText}',
    if (signal.time != null) 'Time: ${signal.time}',
  ].join('\n');
}
}

// ======================= PROMO CARD =======================

class PromoCard extends StatelessWidget {
  const PromoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF101820),
      child: SizedBox(
        height: 80,
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.workspace_premium, color: Colors.amberAccent),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Upgrade to Premium', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('Remove ads and get access to VIP signals.',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            TextButton(onPressed: () {}, child: const Text('View')),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

// ======================= HISTORY SCREEN =======================

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  HistoryScreenState createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  bool _loading = false;
  String? _error;
  List<Signal> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  /// Loads closed signals from backend and updates _history
  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http.get(Uri.parse('$kApiBaseUrl/signals/history')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final List<Signal> signals = data.map((e) => Signal.fromJson(e)).toList();
        setState(() {
          _history = signals;
          _loading = false;
        });
        favoritesManager.updateSignals(signals);
      } else {
        setState(() {
          _error = 'Failed to load history (${response.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading history: $e';
        _loading = false;
      });
    }
  }


  void _openDetails(Signal signal) {
    final user = FirebaseAuth.instance.currentUser;
    final isAdmin = user?.email?.toLowerCase() == 'driton.mahmudi@gmail.com';
    if (!premiumManager.isPremium && !isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upgrade to Premium to view details.')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF10131A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SignalDetailsSheet(
          signal: signal,
          onToggleFavorite: () {
            setState(() => favoritesManager.toggleFavorite(signal));
            Navigator.of(ctx).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _history;

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('History'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadHistory),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _loadHistory,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text('Error: $_error', style: const TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    )
                  : items.isEmpty
                      ? ListView(
                          children: const [
                            Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Center(
                                child: Text(
                                  'No closed signals yet.\nOnce TP/SL/BE are updated in the backend,\nthey will appear here.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final s = items[index];
                            return HistoryCard(
                              signal: s,
                              isFavorite: favoritesManager.isFavorite(s),
                              onTap: () => _openDetails(s),
                              onFavoriteToggle: () => this.setState(() => favoritesManager.toggleFavorite(s)),
                            );
                          },
                        ),
        ),
      ),
    );
  }
}

// ======================= HISTORY CARD =======================

class HistoryCard extends StatelessWidget {
  final Signal signal;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  const HistoryCard({
    super.key,
    required this.signal,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  Color _directionColor() {
    if (signal.direction == 'BUY') return Colors.greenAccent;
    if (signal.direction == 'SELL') return Colors.redAccent;
    return Colors.grey;
  }

  String get _resultLabel {
    final h = (signal.hit ?? '').toLowerCase();
    if (h == 'tp') return 'TP';
    if (h == 'sl') return 'SL';
    if (h.contains('be')) return 'BE';
    return '';
  }

  Color? get _resultColor {
    final h = (signal.hit ?? '').toLowerCase();
    if (h == 'tp') return Colors.greenAccent;
    if (h == 'sl') return Colors.redAccent;
    if (h.contains('be')) return Colors.grey;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final timeText = DateFormat('yyyy-MM-dd HH:mm').format(signal.time);
    final directionColor = _directionColor();
    final resultLabel = _resultLabel;
    final resultColor = _resultColor;

    String? pnlText;
    if (signal.pnlPercent != null) {
      final p = signal.pnlPercent!;
      pnlText = '${p >= 0 ? '+' : ''}${p.toStringAsFixed(2)}%';
    }

    // Avoid shadowing the 'm' prefix by renaming any local variable named 'm' to 'mm' if present in this scope.
    return Card(
      @override
      Widget build(BuildContext context) {
        final timeText = DateFormat('yyyy-MM-dd HH:mm').format(signal.time);
        final directionColor = _directionColor();
        final resultLabel = _resultLabel;
        final resultColor = _resultColor;

        String? pnlText;
        if (signal.pnlPercent != null) {
          final p = signal.pnlPercent!;
          pnlText = '${p >= 0 ? '+' : ''}${p.toStringAsFixed(2)}%';
        }

        return Card(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 60,
                    decoration: BoxDecoration(
                      color: directionColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(signal.symbol,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: directionColor.withAlpha((0.15 * 255).round()),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                signal.direction,
                                style: TextStyle(color: directionColor, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const Spacer(),
                            if (resultLabel.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: resultColor?.withAlpha((0.15 * 255).round()),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      resultLabel == 'TP'
                                          ? Icons.check_circle
                                          : resultLabel == 'SL'
                                              ? Icons.cancel
                                              : Icons.drag_handle,
                                      size: 14,
                                      color: resultColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      resultLabel,
                                      style: TextStyle(fontSize: 12, color: resultColor, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            IconButton(
                              icon: Icon(
                                isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: isFavorite ? Colors.pinkAccent : Colors.grey,
                                size: 20,
                              ),
                              onPressed: onFavoriteToggle,
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Entry: ${signal.entry.toStringAsFixed(4)}',
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'SL: ${signal.sl.toStringAsFixed(4)}',
                                style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'TP: ${signal.tp.toStringAsFixed(4)}',
                                style: const TextStyle(fontSize: 12, color: Colors.greenAccent),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (pnlText != null)
                              Text(
                                pnlText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: (signal.pnlPercent ?? 0) >= 0 ? Colors.greenAccent : Colors.redAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            const Spacer(),
                            Text(timeText, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.toLowerCase();
    return email == 'driton.mahmudi@gmail.com';
  }

  @override
  void initState() {
    super.initState();
    favoritesManager.addListener(_onFavChanged);
  }

  @override
  void dispose() {
    favoritesManager.removeListener(_onFavChanged);
    super.dispose();
  }

  void _onFavChanged() => setState(() {});

  void _openDetails(Signal signal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF10131A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SignalDetailsSheet(
          signal: signal,
          onToggleFavorite: () {
            favoritesManager.toggleFavorite(signal);
            Navigator.of(ctx).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show premium prompt for free users (admins have full access)
    if (!premiumManager.isPremium && !_isAdmin) {
      return SafeArea(
        child: Scaffold(
          appBar: AppBar(title: const Text('Favorites')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.workspace_premium, color: Colors.amberAccent, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Upgrade to Premium',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Save your favorite signals and access them anytime.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Premium subscription coming soon!')),
                      );
                    },
                    child: const Text('Upgrade Now'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    final favs = favoritesManager.favorites;

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Favorites')),
        body: favs.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'You don\'t have any favorite signals yet.\n\nFrom the Signals list or History,\ntap the heart icon to save a signal here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            : ListView.builder(
                itemCount: favs.length,
                itemBuilder: (context, index) {
                  final signal = favs[index];
                  return SignalCard(
                    signal: signal,
                    isFavorite: favoritesManager.isFavorite(signal),
                    isPremium: premiumManager.isPremium || _isAdmin,
                    onTap: () => _openDetails(signal),
                    onFavoriteToggle: () => favoritesManager.toggleFavorite(signal),
                  );
                },
              ),
      ),
    );
  }
}

// ======================= SETTINGS =======================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushEnabled = true;

  static const Set<String> _adminEmails = {
    'driton.mahmudi@gmail.com',
  };

  bool get _isAdmin {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.toLowerCase();
    if (email == null) return false;
    return _adminEmails.contains(email);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _logout() async {
    // Log logout event to Analytics
    await FirebaseAnalytics.instance.logEvent(
      name: 'user_logout',
      parameters: {
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (_) => false,
    );
  }

  void _showTestCrashDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Test Crashlytics'),
        content: const Text(
          'This will trigger a test crash to verify Crashlytics is working.\n\n'
          'Check Firebase Crashlytics console after the app restarts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _triggerTestCrash();
            },
            child: const Text('Trigger crash', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _triggerTestCrash() {
       // Record the test crash intent to Crashlytics before crashing
    FirebaseCrashlytics.instance.log('ðŸ§ª User triggered test crash via admin button');
    
    // Throw an exception that Crashlytics will capture
    throw Exception('ðŸ§ª Test crash triggered by admin button');
  }

  Future<void> _handlePremiumUpgrade() async {
    final success = await premiumManager.purchasePremium();
    
    if (!mounted) return;
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('âœ… Premium activated! Enjoy full access.'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Log premium purchase event to Analytics
      FirebaseAnalytics.instance.logEvent(
        name: 'premium_purchased',
        parameters: {
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('âš ï¸ Purchase cancelled or failed. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(user.email ?? 'Unknown user'),
                subtitle: const Text('Logged in'),
              ),
            ),

          SwitchListTile(
            value: _pushEnabled,
            onChanged: (v) async {
              this.setState(() => _pushEnabled = v);
              await FirebaseMessaging.instance.setAutoInitEnabled(v);
            },
            title: const Text('Push notifications'),
            subtitle: const Text('Receive trade signal notifications'),
          ),

          const SizedBox(height: 16),

          // âœ… PREMIUM SUBSCRIPTION (hidden for admins)
          if (!_isAdmin)
            ListenableBuilder(
              listenable: premiumManager,
              builder: (context, _) {
                if (premiumManager.isPremium) {
                  return Card(
                    color: Colors.amber.withAlpha(25),
                    child: ListTile(
                      leading: const Icon(Icons.star, color: Colors.amberAccent),
                      title: const Text('Premium Active', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('You have full access to all features'),
                    ),
                  );
                }
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.workspace_premium, color: Colors.amberAccent),
                    title: const Text('Upgrade to Premium'),
                    subtitle: const Text('Unlock VIP signals & advanced analytics'),
                    trailing: premiumManager.isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.chevron_right),
                    onTap: premiumManager.isLoading ? null : _handlePremiumUpgrade,
                  ),
                );
              },
            ),

          const SizedBox(height: 16),

          // âœ… ADMIN TOOLS (only admin - shown instead of Premium)
          if (_isAdmin) ...[
            Card(
              color: Colors.cyan.withAlpha(25),
              child: const ListTile(
                leading: Icon(Icons.admin_panel_settings, color: Colors.cyan),
                title: Text('Admin Access', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Full access to all features & admin panel'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Admin tools',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings),
                    title: const Text('Admin panel'),
                    subtitle: const Text('View raw signals, stats & controls'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AdminScreen()),
                      );
                    },
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: const Icon(Icons.bug_report_outlined, color: Colors.redAccent),
                    title: const Text('Test crash (Crashlytics)', style: TextStyle(color: Colors.redAccent)),
                    subtitle: const Text('âš ï¸ This will trigger a test crash'),
                    onTap: () {
                      _showTestCrashDialog();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // âœ… ABOUT / PRIVACY / SHARE / LOGOUT
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    );
                  },
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy policy'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                    );
                  },
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: const Text('Share app'),
                  onTap: () async {
                    try {
                      await Share.share('Panna Signals: $kStoreUrl');
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Sharing is not available on this device.')),
                        );
                      }
                    }
                  },
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Log out'),
                  onTap: _logout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ======================= STATISTICS SCREEN =======================

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class StatsResponse {
  final StatsPeriod period;
  final DateTime from;
  final DateTime to;
  final AnalysisType? analysisType;

  final int totalTrades;
  final int wins;
  final int losses;
  final int breakevens;
  final double winRate;
  final double avgPnlPercent;
  final double totalPnlPercent;

  const StatsResponse({
    required this.period,
    required this.from,
    required this.to,
    required this.analysisType,
    required this.totalTrades,
    required this.wins,
    required this.losses,
    required this.breakevens,
    required this.winRate,
    required this.avgPnlPercent,
    required this.totalPnlPercent,
  });

  static double _asDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  factory StatsResponse.fromJson(Map<String, dynamic> json) {
    final periodStr = (json['period'] ?? 'daily').toString();
    final period = StatsPeriod.values.firstWhere(
      (p) => p.apiValue == periodStr,
      orElse: () => StatsPeriod.daily,
    );

    return StatsResponse(
      period: period,
      from: DateTime.tryParse(json['date_from']?.toString() ?? '') ?? DateTime.now(),
      to: DateTime.tryParse(json['date_to']?.toString() ?? '') ?? DateTime.now(),
      analysisType: AnalysisTypeExt.fromApi(json['analysis_type']?.toString()),
      totalTrades: (json['total_trades'] ?? 0) is int ? (json['total_trades'] ?? 0) : int.tryParse((json['total_trades'] ?? '0').toString()) ?? 0,
      wins: (json['wins'] ?? 0) is int ? (json['wins'] ?? 0) : int.tryParse((json['wins'] ?? '0').toString()) ?? 0,
      losses: (json['losses'] ?? 0) is int ? (json['losses'] ?? 0) : int.tryParse((json['losses'] ?? '0').toString()) ?? 0,
      breakevens: (json['breakevens'] ?? 0) is int ? (json['breakevens'] ?? 0) : int.tryParse((json['breakevens'] ?? '0').toString()) ?? 0,
      winRate: _asDouble(json['win_rate']),
      avgPnlPercent: _asDouble(json['avg_pnl_percent']),
      totalPnlPercent: _asDouble(json['total_pnl_percent']),
    );
  }
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _loading = false;
  String? _error;
  StatsResponse? _stats;

  AnalysisType _selectedType = AnalysisType.forexSwing;
  StatsPeriod _selectedPeriod = StatsPeriod.daily;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('/stats').replace(queryParameters: {
        'analysis_type': _selectedType.apiValue,
        'period': _selectedPeriod.apiValue,
      });

      final resp = await http.get(uri).timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) {
        throw Exception('HTTP : ');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final stats = StatsResponse.fromJson(data);

      if (!mounted) return;
      setState(() => _stats = stats);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _stats = null;
      });
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Statistics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 360;

                final typeDrop = DropdownButtonFormField<AnalysisType>(
                  isExpanded: true,
                  value: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Strategy',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: AnalysisType.values
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.label, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() => _selectedType = val);
                    _fetchStats();
                  },
                );

                final periodDrop = DropdownButtonFormField<StatsPeriod>(
                  isExpanded: true,
                  value: _selectedPeriod,
                  decoration: const InputDecoration(
                    labelText: 'Period',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: StatsPeriod.values
                      .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                      .toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() => _selectedPeriod = val);
                    _fetchStats();
                  },
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      typeDrop,
                      const SizedBox(height: 8),
                      periodDrop,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: typeDrop),
                    const SizedBox(width: 8),
                    Expanded(child: periodDrop),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 80.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text('Error: ', style: const TextStyle(color: Colors.redAccent)),
      );
    }

    final stats = _stats;
    if (stats == null || stats.totalTrades == 0) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            'No closed trades for this strategy and period.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final df = DateFormat('yyyy-MM-dd');

    return Column(
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.calendar_today, size: 18),
            title: Text(' •  → '),
            subtitle: Text('Trades:  | Wins:  | Losses:  | BE: '),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _statRow('Win rate', '%'),
                const SizedBox(height: 8),
                _statRow('Avg PnL', '%'),
                const SizedBox(height: 8),
                _statRow('Total PnL', '%'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statRow(String title, String value) {
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(color: Colors.grey))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: RefreshIndicator(
        onRefresh: _fetchStats,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            _buildStatsBody(),
          ],
        ),
      ),
    );
  }
}



