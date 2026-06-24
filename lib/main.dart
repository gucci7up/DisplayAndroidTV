import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

const _kBaseUrl = 'https://display.mbsport.lat';
const _kPrefAgencyId = 'agency_id';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await WakelockPlus.enable();
  runApp(const DisplayTvApp());
}

class DisplayTvApp extends StatelessWidget {
  const DisplayTvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MBSport Display',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      home: const _SplashGate(),
    );
  }
}

// ── Splash: decide si mostrar setup o display ─────────────────────────────────

class _SplashGate extends StatefulWidget {
  const _SplashGate();

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final agencyId = prefs.getString(_kPrefAgencyId) ?? '';
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => agencyId.isEmpty
            ? const SetupScreen()
            : DisplayScreen(agencyId: agencyId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))),
    );
  }
}

// ── Pantalla de configuración del Agency ID ───────────────────────────────────

class SetupScreen extends StatefulWidget {
  const SetupScreen();

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  String _input = '';

  void _type(String d) {
    if (_input.length < 36) setState(() => _input += d);
  }

  void _backspace() {
    if (_input.isNotEmpty) setState(() => _input = _input.substring(0, _input.length - 1));
  }

  Future<void> _save() async {
    if (_input.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefAgencyId, _input.trim());
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => DisplayScreen(agencyId: _input.trim())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1A10),
      body: Center(
        child: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(text: 'MB', style: TextStyle(color: Color(0xFFD4AF37))),
                    TextSpan(text: 'SPORT', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Text('RACING DOGS — DISPLAY TV',
                  style: TextStyle(color: Colors.white38, letterSpacing: 3, fontSize: 11)),
              const SizedBox(height: 28),
              const Text('ID DE AGENCIA',
                  style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 13)),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5)),
                ),
                child: Text(
                  _input.isEmpty ? '—' : _input,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _input.isEmpty ? Colors.white24 : Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(height: 260, child: _NumPad(onDigit: _type, onBackspace: _backspace)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _input.isEmpty ? Colors.white12 : const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _input.isEmpty ? null : _save,
                  child: const Text('CONFIRMAR',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Pantalla principal WebView ────────────────────────────────────────────────

class DisplayScreen extends StatefulWidget {
  final String agencyId;
  const DisplayScreen({super.key, required this.agencyId});

  @override
  State<DisplayScreen> createState() => _DisplayScreenState();
}

class _DisplayScreenState extends State<DisplayScreen> {
  late final WebViewController _controller;
  bool _hasError = false;
  Timer? _retryTimer;
  int _retrySeconds = 0;

  String get _url => '$_kBaseUrl?agencyId=${widget.agencyId}';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setOnConsoleMessage((_) {})
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) {
          if (mounted) setState(() => _hasError = false);
          _retryTimer?.cancel();
        },
        onWebResourceError: (error) {
          if (mounted && error.isForMainFrame == true) {
            setState(() { _hasError = true; _retrySeconds = 30; });
            _startRetry();
          }
        },
      ));

    // Configuración Android específica para mejor video
    if (_controller.platform is AndroidWebViewController) {
      final android = _controller.platform as AndroidWebViewController;
      android.setMediaPlaybackRequiresUserGesture(false);
    }

    // Cargar primero una página del mismo origen que setea localStorage
    // y luego redirige al display — así React lee los valores correctos al iniciar
    _controller.loadHtmlString('''
      <!DOCTYPE html>
      <html>
      <head>
        <script>
          try {
            localStorage.setItem('display_unlocked', 'true');
            localStorage.setItem('display_agency_id', '${widget.agencyId}');
          } catch(e) {}
          window.location.replace('$_url');
        </script>
      </head>
      <body style="background:#000"></body>
      </html>
    ''', baseUrl: _kBaseUrl);
  }

  void _startRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _retrySeconds--);
      if (_retrySeconds <= 0) { t.cancel(); _reload(); }
    });
  }

  void _reload() {
    setState(() => _hasError = false);
    _controller.loadRequest(Uri.parse(_url));
  }

  Future<void> _openSettings() async {
    _retryTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefAgencyId);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SetupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        // Mantener presionado 3s para ir a configuración
        onLongPress: _openSettings,
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_hasError)
              Container(
                color: const Color(0xFF0D1A10),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off, color: Color(0xFFD4AF37), size: 64),
                      const SizedBox(height: 16),
                      const Text('SIN CONEXIÓN',
                          style: TextStyle(color: Colors.white, fontSize: 24,
                              fontWeight: FontWeight.bold, letterSpacing: 3)),
                      const SizedBox(height: 8),
                      Text('Reintentando en $_retrySeconds segundos...',
                          style: const TextStyle(color: Colors.white54, fontSize: 16)),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        ),
                        onPressed: _reload,
                        child: const Text('REINTENTAR AHORA',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Teclado numérico ──────────────────────────────────────────────────────────

class _NumPad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  const _NumPad({required this.onDigit, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    const sp = 12.0;
    return Column(
      children: [
        Expanded(child: Row(children: [
          Expanded(child: _Key(label: '1', onTap: () => onDigit('1'))),
          const SizedBox(width: sp),
          Expanded(child: _Key(label: '2', onTap: () => onDigit('2'))),
          const SizedBox(width: sp),
          Expanded(child: _Key(label: '3', onTap: () => onDigit('3'))),
        ])),
        const SizedBox(height: sp),
        Expanded(child: Row(children: [
          Expanded(child: _Key(label: '4', onTap: () => onDigit('4'))),
          const SizedBox(width: sp),
          Expanded(child: _Key(label: '5', onTap: () => onDigit('5'))),
          const SizedBox(width: sp),
          Expanded(child: _Key(label: '6', onTap: () => onDigit('6'))),
        ])),
        const SizedBox(height: sp),
        Expanded(child: Row(children: [
          Expanded(child: _Key(label: '7', onTap: () => onDigit('7'))),
          const SizedBox(width: sp),
          Expanded(child: _Key(label: '8', onTap: () => onDigit('8'))),
          const SizedBox(width: sp),
          Expanded(child: _Key(label: '9', onTap: () => onDigit('9'))),
        ])),
        const SizedBox(height: sp),
        Expanded(child: Row(children: [
          Expanded(flex: 2, child: _Key(icon: Icons.backspace_outlined, gold: true, onTap: onBackspace)),
          const SizedBox(width: sp),
          Expanded(child: _Key(label: '0', onTap: () => onDigit('0'))),
        ])),
      ],
    );
  }
}

class _Key extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final bool gold;
  final VoidCallback onTap;
  const _Key({this.label, this.icon, this.gold = false, required this.onTap});

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final deco = widget.gold
        ? BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _pressed
                  ? [const Color(0xFFE6C75B), const Color(0xFFB8902C)]
                  : [const Color(0xFFD4AF37), const Color(0xFFA67C1F)],
            ),
            borderRadius: BorderRadius.circular(10),
          )
        : BoxDecoration(
            color: Colors.white.withOpacity(_pressed ? 0.14 : 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFD4AF37).withOpacity(_pressed ? 0.8 : 0.3),
              width: 1.5,
            ),
          );

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        decoration: deco,
        child: Center(
          child: widget.icon != null
              ? Icon(widget.icon,
                  color: widget.gold ? const Color(0xFF12241A) : Colors.white, size: 22)
              : Text(widget.label!,
                  style: TextStyle(
                    color: widget.gold ? const Color(0xFF12241A) : Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  )),
        ),
      ),
    );
  }
}
