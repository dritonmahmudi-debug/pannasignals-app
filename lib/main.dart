import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
// import 'package:firebase_analytics/observer.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/push_notifications_service.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:intl/intl.dart';

import 'admin_screen.dart' hide kApiBaseUrl;
import 'onboarding_screen.dart';
import 'stats_period.dart';
import 'constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase init (Android/iOS).
  await Firebase.initializeApp();

  // Crashlytics setup (safe no-op on platforms where not supported).
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Init push notifications (log status, token, handle refresh)
  await PushNotificationsService().initPush();

  runApp(const SignalApp());
}

// ======================= MODELS =======================

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
        return 'forex_scalp';
      case AnalysisType.cryptoSwing:
        return 'crypto_swing';
      case AnalysisType.cryptoScalping:
        return 'crypto_scalp';
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
    if (v.isEmpty) return null;

    // Accept aliases from older/newer bots so signals always land in the right folder.
    switch (v) {
      case 'forex_swing':
        return AnalysisType.forexSwing;

      // Some bots used forex_intraday, others use forex_scalp.
      case 'forex_intraday':
      case 'forex_scalp':
        return AnalysisType.forexIntraday;

      case 'crypto_swing':
        return AnalysisType.cryptoSwing;

      // Older value was crypto_scalping, new canonical is crypto_scalp.
      case 'crypto_scalping':
      case 'crypto_scalp':
        return AnalysisType.cryptoScalping;
      default:
        return null;
    }
  }

  static AnalysisType? fromSource(String? source) {
    final s = (source ?? '').toLowerCase().trim();
    if (s.contains('forex') && s.contains('swing')) return AnalysisType.forexSwing;
    if (s.contains('forex') && (s.contains('scalp') || s.contains('intraday'))) return AnalysisType.forexIntraday;
    if (s.contains('crypto') && s.contains('swing')) return AnalysisType.cryptoSwing;
    if (s.contains('crypto') && (s.contains('scalp') || s.contains('pullback'))) return AnalysisType.cryptoScalping;
    return null;
  }
}

class Signal {
  final int id;
  final String symbol;
  final String direction;
  final DateTime time;
  final AnalysisType? analysisType;

  final double? entry;
  final double? sl;
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
    final analysisType = AnalysisTypeExt.fromApi(json['analysis_type']?.toString()) ??
        AnalysisTypeExt.fromSource(json['source']?.toString());

    return Signal(
      id: _asInt(json['id']),
      symbol: (json['symbol'] ?? '').toString(),
      direction: (json['direction'] ?? '').toString(),
      time: DateTime.tryParse((json['time'] ?? '').toString()) ?? DateTime.now(),
      analysisType: analysisType,
      entry: _asDoubleOrNull(json['entry']),
      sl: _asDoubleOrNull(json['sl']),
      tp: _asDoubleOrNull(json['tp']),
      pnlPercent: _asDoubleOrNull(json['pnl_percent']),
      isClosed: json['is_closed'] as bool?,
      hit: json['hit']?.toString(),
      source: json['source']?.toString(),
      extraText: json['extra_text']?.toString(),
      timeframe: json['timeframe']?.toString(),
      isFavorite: (json['is_favorite'] == true),
    );
  }
}

int _asInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  return int.tryParse(v.toString()) ?? 0;
}

double? _asDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString());
}

double _asDouble(dynamic v) {
  return _asDoubleOrNull(v) ?? 0.0;
}

// ======================= FAVORITES MANAGER (GLOBAL) =======================

class FavoritesManager extends ChangeNotifier {
  final Set<int> _favoriteIds = <int>{};
  final Map<int, Signal> _signalsById = <int, Signal>{};

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

final FavoritesManager favoritesManager = FavoritesManager();

// ======================= PREMIUM MANAGER (GLOBAL) =======================

class PremiumManager extends ChangeNotifier {
  final InAppPurchase _iap = InAppPurchase.instance;
  static const String premiumProductId = 'premium_monthly';

  bool _initialized = false;
  bool _isPremium = false;
  bool _isLoading = false;

  bool get isPremium => _isPremium;
  bool get isLoading => _isLoading;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await checkPremiumFromBackend();

    // Skip StoreKit/Billing on web.
    if (kIsWeb) return;

    final available = await _iap.isAvailable();
    if (!available) {
      debugPrint('⚠️ In-app purchases not available');
      return;
    }

    _purchaseSub = _iap.purchaseStream.listen((purchases) async {
      for (final purchase in purchases) {
        if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
          await checkPremiumFromBackend();
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
        } else if (purchase.status == PurchaseStatus.error) {
          debugPrint('❌ Purchase error: ${purchase.error}');
        }
      }
    }, onError: (e) {
      debugPrint('❌ Error in purchaseStream: $e');
    });

    await _restorePurchases();
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }

  Future<void> checkPremiumFromBackend() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final emailRaw = user?.email;
      if (emailRaw == null || emailRaw.isEmpty) return;

      final email = Uri.encodeComponent(emailRaw);
      final resp = await http
          .get(Uri.parse('$kApiBaseUrl/premium/check/$email'))
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final bool value = (data is Map && data['is_premium'] == true);
        if (_isPremium != value) {
          _isPremium = value;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking premium status: $e');
    }
  }

  Future<void> _restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('❌ Error restoring purchases: $e');
    }
  }

  Future<bool> purchasePremium() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _iap.queryProductDetails({premiumProductId});
      if (response.productDetails.isEmpty) {
        debugPrint('⚠️ Premium product not found in Play Console / App Store');
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final product = response.productDetails.first;
      final purchaseParam = PurchaseParam(productDetails: product);
      _iap.buyNonConsumable(purchaseParam: purchaseParam);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Error purchasing premium: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}

final PremiumManager premiumManager = PremiumManager();

// ======================= APP ROOT + AUTH =======================

class SignalApp extends StatelessWidget {
  const SignalApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData.dark();

    return MaterialApp(
          debugShowCheckedModeBanner: true,
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

    if (!mounted) return;
    setState(() {
      _showOnboarding = !onboardingComplete;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _showOnboarding ? const OnboardingScreen() : const AuthGate();
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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
        final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
        final user = cred.user;
        if (user == null) throw Exception('User not found');

        await FirebaseAnalytics.instance.logEvent(
          name: 'user_login',
          parameters: {'timestamp': DateTime.now().toIso8601String()},
        );

        if (!user.emailVerified) {
          await user.sendEmailVerification();
        }
      } else {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
        final user = cred.user;
        if (user == null) throw Exception('User not found');

        await user.sendEmailVerification();

        await FirebaseAnalytics.instance.logEvent(
          name: 'user_register',
          parameters: {'timestamp': DateTime.now().toIso8601String()},
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      setState(() => _error = e.toString());
    }
    finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panna Signals')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Email required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                    ),
                    const SizedBox(height: 16),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(_isLogin ? 'Login' : 'Create account'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() {
                                _isLogin = !_isLogin;
                                _error = null;
                              }),
                      child: Text(_isLogin ? 'No account? Register' : 'Have an account? Login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EmailVerificationScreen extends StatefulWidget {
  final User user;
  const EmailVerificationScreen({super.key, required this.user});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _sending = false;
  String? _msg;

  Future<void> _resend() async {
    setState(() {
      _sending = true;
      _msg = null;
    });
    try {
      await widget.user.sendEmailVerification();
      setState(() => _msg = 'Verification email sent. Please check your inbox.');
    } catch (e) {
      setState(() => _msg = 'Failed: $e');
    }
    finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _refresh() async {
    await widget.user.reload();
    final refreshed = FirebaseAuth.instance.currentUser;
    if (refreshed != null && refreshed.emailVerified && mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify email')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mark_email_read_outlined, size: 48),
            const SizedBox(height: 12),
            Text('We sent a verification email to:\n${widget.user.email ?? ''}', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            if (_msg != null) Text(_msg!, style: const TextStyle(color: Colors.tealAccent)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sending ? null : _resend,
                child: _sending ? const Text('Sending...') : const Text('Resend email'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _refresh,
                child: const Text('I verified, continue'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
              child: const Text('Log out'),
            ),
          ],
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
  int _index = 0;

  @override
  void initState() {
    super.initState();
    unawaited(premiumManager.initialize());
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomeScreen(),
      const FavoritesScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Signals'),
          BottomNavigationBarItem(icon: Icon(Icons.star), label: 'Favorites'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
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
  List<Signal> _signals = const [];

  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _isAdmin = _isAdminEmail(FirebaseAuth.instance.currentUser?.email);
    _loadSignals();
  }

  bool _isAdminEmail(String? email) {
    if (email == null) return false;
    const admins = <String>{
      // TODO: add your admin emails here (lowercase).
      'admin@example.com',
    };
    return admins.contains(email.toLowerCase());
  }

  Future<void> _loadSignals() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final params = <String, String>{'limit': '200'};

      final f = _selectedFilter;

      if (f != null) params['analysis_type'] = f.apiValue;

      final uri = Uri.parse('$kApiBaseUrl/signals').replace(queryParameters: params);
      final resp = await http.get(uri).timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
      }

      final decoded = jsonDecode(resp.body);
      final List<dynamic> arr;
      if (decoded is List) {
        arr = decoded;
      } else if (decoded is Map && decoded['signals'] is List) {
        arr = decoded['signals'] as List;
      } else {
        throw Exception('Unexpected response shape');
      }

      final signals = arr.whereType<Map>().map((e) => Signal.fromJson(e.cast<String, dynamic>())).toList();
      favoritesManager.updateSignals(signals);

      if (!mounted) return;
      setState(() {
        _signals = signals;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openStatistics() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StatisticsScreen()));
  }

  void _toggleFavorite(Signal signal) {
    setState(() => favoritesManager.toggleFavorite(signal));
  }

  void _openDetails(Signal signal) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => SignalDetailsScreen(signal: signal)));
  }

  List<Signal> get _filtered {
    if (_selectedFilter == null) {
      // All tab: show all signals
      return _signals;
    }
    // Show only signals matching the selected canonical analysis type
    return _signals.where((s) {
      final at = s.analysisType;
      final match = at == _selectedFilter;
      assert(() {
        debugPrint('[DEBUG] Signal id=${s.id} symbol=${s.symbol} analysisType=${at?.apiValue} tab=${_selectedFilter?.apiValue} match=$match');
        return true;
      }());
      return match;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Signals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Statistics',
            onPressed: _openStatistics,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSignals,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: _selectedFilter == null,
                    onSelected: (_) {
                      setState(() => _selectedFilter = null);
                      _loadSignals();
                    },
                  ),
                ),
                for (final t in AnalysisType.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(t.label),
                      selected: _selectedFilter == t,
                      onSelected: (_) {
                        setState(() => _selectedFilter = t);
                        _loadSignals();
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadSignals,
            child: _loading
                ? ListView(children: [SizedBox(height: 140), Center(child: CircularProgressIndicator())])
                : _error != null
                    ? ListView(
                        padding: const EdgeInsets.all(16),
                        children: [Text('Error: $_error', style: const TextStyle(color: Colors.redAccent))],
                      )
                    : filtered.isEmpty
                        ? ListView(
                            padding: EdgeInsets.all(24),
                            children: [
                              SizedBox(height: 80),
                              Center(child: Text('No signals at the moment.', style: TextStyle(color: Colors.grey))),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final signal = filtered[index];
                              return SignalCard(
                                signal: signal,
                                isFavorite: favoritesManager.isFavorite(signal),
                                isPremium: premiumManager.isPremium || _isAdmin,
                                onTap: () => _openDetails(signal),
                                onFavoriteToggle: () => _toggleFavorite(signal),
                              );
                            },
                          ),
          ),
          if (kDebugMode)
            Positioned(
              right: 16,
              bottom: 16,
              child: _RegisterDeviceButton(isAdmin: _isAdmin),
            ),
        ],
      ),
    );
  }
}

class _RegisterDeviceButton extends StatefulWidget {
  final bool isAdmin;
  const _RegisterDeviceButton({required this.isAdmin});

  @override
  State<_RegisterDeviceButton> createState() => _RegisterDeviceButtonState();
}

class _RegisterDeviceButtonState extends State<_RegisterDeviceButton> {
  bool _sending = false;

  String _platformName() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return defaultTargetPlatform.name;
    }
  }

  Future<void> _register() async {
    if (_sending) return;
    setState(() => _sending = true);

    try {
      final messaging = FirebaseMessaging.instance;

      // iOS permission request is safe on other platforms too.
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) throw Exception('FCM token is null/empty');

      final info = await PackageInfo.fromPlatform();
      final appVersion = info.version;

      final url = Uri.parse('$kApiBaseUrl/register_device');
      final body = {'token': token, 'platform': _platformName(), 'app_version': appVersion};

      final resp = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Register_device: ${resp.statusCode}  (${resp.body.length} chars)')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Register failed: $e')));
    }
    finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
      onPressed: _sending ? null : _register,
      child: Text(_sending ? 'Registering...' : 'Register Device'),
    );
  }
}

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

  bool get _isLocked {
    final src = (signal.source ?? '').toLowerCase();
    final extra = (signal.extraText ?? '').toLowerCase();
    final looksVip = src.contains('vip') || extra.contains('vip');
    return looksVip && !isPremium;
  }

  @override
  Widget build(BuildContext context) {
    final at = signal.analysisType;
    final titleColor = at?.color ?? Colors.grey;
    final icon = at?.icon ?? Icons.insights;

    final df = DateFormat('yyyy-MM-dd HH:mm');
    final timeText = df.format(signal.time);

    final subtitle = <String>[
      if (signal.entry != null) 'Entry: ${signal.entry}',
      if (signal.sl != null) 'SL: ${signal.sl}',
      if (signal.tp != null) 'TP: ${signal.tp}',
      if (signal.timeframe != null && signal.timeframe!.isNotEmpty) 'TF: ${signal.timeframe}',
    ].join('   ');

    return Stack(
      children: [
        Card(
          child: ListTile(
            onTap: _isLocked ? null : onTap,
            leading: Icon(icon, color: titleColor),
            title: Text('${signal.symbol} • ${signal.direction}', style: TextStyle(color: titleColor)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(timeText, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                if (subtitle.isNotEmpty) const SizedBox(height: 4),
                if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(fontSize: 12)),
              ],
            ),
            trailing: IconButton(
              icon: Icon(isFavorite ? Icons.star : Icons.star_border),
              onPressed: onFavoriteToggle,
            ),
          ),
        ),
        if (_isLocked)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.black.withOpacity(0.60),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, color: Colors.amberAccent, size: 32),
                    SizedBox(height: 8),
                    Text('Upgrade to Premium', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class SignalDetailsScreen extends StatelessWidget {
  final Signal signal;
  const SignalDetailsScreen({super.key, required this.signal});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd HH:mm:ss');
    return Scaffold(
      appBar: AppBar(title: Text('${signal.symbol}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Direction: ${signal.direction}'),
          const SizedBox(height: 8),
          Text('Time: ${df.format(signal.time)}'),
          const SizedBox(height: 8),
          Text('Analysis: ${signal.analysisType?.label ?? 'Unknown'}'),
          const SizedBox(height: 16),
          _kv('Entry', signal.entry),
          _kv('SL', signal.sl),
          _kv('TP', signal.tp),
          _kv('PnL %', signal.pnlPercent),
          const SizedBox(height: 12),
          if (signal.extraText != null && signal.extraText!.isNotEmpty) Text(signal.extraText!),
        ],
      ),
    );
  }

  Widget _kv(String k, dynamic v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text('$k: ${v ?? '-'}'),
    );
  }
}

// ======================= FAVORITES =======================

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: favoritesManager,
      builder: (context, _) {
        final favs = favoritesManager.favorites;

        return Scaffold(
          appBar: AppBar(title: const Text('Favorites')),
          body: favs.isEmpty
              ? const Center(child: Text('No favorites yet.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: favs.length,
                  itemBuilder: (context, i) {
                    final s = favs[i];
                    return SignalCard(
                      signal: s,
                      isFavorite: true,
                      isPremium: premiumManager.isPremium,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SignalDetailsScreen(signal: s))),
                      onFavoriteToggle: () => favoritesManager.toggleFavorite(s),
                    );
                  },
                ),
        );
      },
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
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _isAdmin = _isAdminEmail(FirebaseAuth.instance.currentUser?.email);
    _loadPrefs();
  }

  bool _isAdminEmail(String? email) {
    if (email == null) return false;
    const admins = <String>{
      // TODO: add your admin emails here (lowercase).
      'admin@example.com',
    };
    return admins.contains(email.toLowerCase());
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('push_enabled') ?? true;
    if (!mounted) return;
    setState(() => _pushEnabled = enabled);
  }

  Future<void> _setPush(bool v) async {
    setState(() => _pushEnabled = v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_enabled', v);

    try {
      await FirebaseMessaging.instance.setAutoInitEnabled(v);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _handlePremiumUpgrade() async {
    final ok = await premiumManager.purchasePremium();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Purchase started. If successful, premium will activate shortly.' : 'Purchase failed.'),
      ),
    );
  }

  Future<void> _showTestCrashDialog() async {
    final doCrash = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Crash test'),
        content: const Text('This will crash the app to test Crashlytics. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Crash')),
        ],
      ),
    );

    if (doCrash == true) {
      FirebaseCrashlytics.instance.crash();
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
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
            onChanged: _setPush,
            title: const Text('Push notifications'),
            subtitle: const Text('Receive trade signal notifications'),
          ),

          const SizedBox(height: 16),

          if (!_isAdmin)
            AnimatedBuilder(
              animation: premiumManager,
              builder: (context, _) {
                if (premiumManager.isPremium) {
                  return Card(
                    color: Colors.amber.withOpacity(0.10),
                    child: const ListTile(
                      leading: Icon(Icons.star, color: Colors.amberAccent),
                      title: Text('Premium Active', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('You have full access to all features'),
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

          if (_isAdmin) ...[
            Card(
              color: Colors.cyan.withOpacity(0.10),
              child: const ListTile(
                leading: Icon(Icons.admin_panel_settings, color: Colors.cyan),
                title: Text('Admin Access', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Full access to all features & admin panel'),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Admin tools', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings),
                    title: const Text('Admin panel'),
                    subtitle: const Text('View raw signals, stats & controls'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminScreen())),
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: const Icon(Icons.bug_report_outlined, color: Colors.redAccent),
                    title: const Text('Test crash (Crashlytics)', style: TextStyle(color: Colors.redAccent)),
                    subtitle: const Text('This will trigger a test crash'),
                    onTap: _showTestCrashDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About'),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutScreen())),
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy policy'),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: const Text('Share app'),
                  onTap: () async {
                    try {
                      await Share.share('Panna Signals: $kStoreUrl');
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sharing not available.')));
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

// ======================= ABOUT + PRIVACY (NO url_launcher) =======================

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snap) {
          final version = snap.data?.version ?? '-';
          final build = snap.data?.buildNumber ?? '-';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Panna Signals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Version: $version ($build)'),
              const SizedBox(height: 16),
              const Text(
                'Signals are informational only and not financial advice. Trading involves risk.',
                style: TextStyle(height: 1.5),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('Store link'),
                  subtitle: Text(kStoreUrl),
                  trailing: const Icon(Icons.copy),
                  onTap: () => _copy(context, kStoreUrl),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy policy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('Privacy Policy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          Text(
            'This app uses Firebase Authentication, Analytics, Messaging and Crashlytics to provide core functionality and improve stability.\n\n'
            'We do not sell your personal data. Data may be processed by third-party services (Firebase/Google) necessary for app features.\n\n'
            'If you have questions, contact us via the email shown in the app settings.',
            style: TextStyle(height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ======================= STATISTICS =======================

class TradeStatsResponse {
  final AnalysisType analysisType;
  final StatsPeriod period;
  final DateTime? from;
  final DateTime? to;

  final int totalTrades;
  final int wins;
  final int losses;
  final int breakevens;

  final double winRate;
  final double avgPnlPercent;
  final double totalPnlPercent;

  TradeStatsResponse({
    required this.analysisType,
    required this.period,
    required this.from,
    required this.to,
    required this.totalTrades,
    required this.wins,
    required this.losses,
    required this.breakevens,
    required this.winRate,
    required this.avgPnlPercent,
    required this.totalPnlPercent,
  });

  factory TradeStatsResponse.fromJson(Map<String, dynamic> json, {required AnalysisType analysisType, required StatsPeriod period}) {
    return TradeStatsResponse(
      analysisType: analysisType,
      period: period,
      from: DateTime.tryParse((json['date_from'] ?? json['from'] ?? '').toString()),
      to: DateTime.tryParse((json['date_to'] ?? json['to'] ?? '').toString()),
      totalTrades: _asInt(json['total_trades'] ?? json['total'] ?? 0),
      wins: _asInt(json['wins'] ?? 0),
      losses: _asInt(json['losses'] ?? 0),
      breakevens: _asInt(json['breakevens'] ?? 0),
      winRate: _asDouble(json['win_rate']),
      avgPnlPercent: _asDouble(json['avg_pnl_percent']),
      totalPnlPercent: _asDouble(json['total_pnl_percent']),
    );
  }
}

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _loading = false;
  String? _error;

  AnalysisType _selectedType = AnalysisType.forexSwing;
  StatsPeriod _selectedPeriod = StatsPeriod.values.first;

  TradeStatsResponse? _stats;

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
      final uri = Uri.parse(
        '$kApiBaseUrl/stats?analysis_type=${_selectedType.apiValue}&period=${_selectedPeriod.name}',
      );

      final resp = await http.get(uri).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
      }

      final data = jsonDecode(resp.body);
      if (data is! Map) throw Exception('Unexpected response');

      final stats = TradeStatsResponse.fromJson(
        data.cast<String, dynamic>(),
        analysisType: _selectedType,
        period: _selectedPeriod,
      );

      if (!mounted) return;
      setState(() => _stats = stats);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _stats = null;
      });
    }
    finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _statRow(String title, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(color: Colors.grey))),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }

  String _periodLabel(StatsPeriod p) => p.name.replaceAll('_', ' ').toUpperCase();

  @override
  Widget build(BuildContext context) {
    final stats = _stats;

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: RefreshIndicator(
        onRefresh: _fetchStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<AnalysisType>(
                      value: _selectedType,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Strategy', border: OutlineInputBorder(), isDense: true),
                      items: AnalysisType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() => _selectedType = val);
                        _fetchStats();
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<StatsPeriod>(
                      value: _selectedPeriod,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Period', border: OutlineInputBorder(), isDense: true),
                      items: StatsPeriod.values
                          .map((p) => DropdownMenuItem(value: p, child: Text(_periodLabel(p))))
                          .toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() => _selectedPeriod = val);
                        _fetchStats();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            if (_loading) ...[
              const SizedBox(height: 80),
              const Center(child: CircularProgressIndicator()),
            ] else if (_error != null) ...[
              Text('Error: $_error', style: const TextStyle(color: Colors.redAccent)),
            ] else if (stats == null || stats.totalTrades == 0) ...[
              const SizedBox(height: 40),
              const Center(
                child: Text(
                  'No closed trades for this strategy and period.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ] else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _statRow('Total trades', '${stats.totalTrades}'),
                      _statRow('Wins', '${stats.wins}', valueColor: Colors.greenAccent),
                      _statRow('Losses', '${stats.losses}', valueColor: Colors.redAccent),
                      _statRow('Breakevens', '${stats.breakevens}', valueColor: Colors.amberAccent),
                      const Divider(),
                      _statRow('Win rate', '${stats.winRate.toStringAsFixed(2)}%'),
                      _statRow('Avg PnL', '${stats.avgPnlPercent.toStringAsFixed(2)}%'),
                      _statRow('Total PnL', '${stats.totalPnlPercent.toStringAsFixed(2)}%'),
                      if (stats.from != null || stats.to != null) ...[
                        const Divider(),
                        Text(
                          '${stats.from?.toIso8601String() ?? '-'}  →  ${stats.to?.toIso8601String() ?? '-'}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}