import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

// Formatea un string limpio de hex en UUID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
String _formatUuid(String raw) {
  // Solo letras hex y números
  final clean = raw.replaceAll(RegExp(r'[^a-fA-F0-9]'), '').toLowerCase();
  if (clean.isEmpty) return '';
  final buf = StringBuffer();
  for (int i = 0; i < clean.length && i < 32; i++) {
    if (i == 8 || i == 12 || i == 16 || i == 20) buf.write('-');
    buf.write(clean[i]);
  }
  return buf.toString();
}

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
  final _controller = TextEditingController();
  String _formatted = '';
  bool _valid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    final formatted = _formatUuid(raw);
    // Evitar loop infinito al re-setear el texto
    if (_controller.text != formatted) {
      _controller.value = _controller.value.copyWith(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    setState(() {
      _formatted = formatted;
      // UUID completo: 36 chars (32 hex + 4 dashes)
      _valid = formatted.length == 36;
    });
  }

  Future<void> _save() async {
    if (!_valid) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefAgencyId, _formatted);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => DisplayScreen(agencyId: _formatted)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1A10),
      resizeToAvoidBottomInset: true,
      body: LayoutBuilder(builder: (context, constraints) {
        // Escala basada en el ancho de pantalla
        // 6" (~360px) → factor 1.0  |  65" (~3840px) → factor ~3.5 (cap en 2.5)
        final w = constraints.maxWidth;
        final scale = (w / 600).clamp(0.6, 2.5);

        final cardWidth = (w * 0.85).clamp(300.0, 700.0);
        final logoSize = 36.0 * scale;
        final labelSize = 13.0 * scale;
        final fieldFontSize = 20.0 * scale;
        final hintFontSize = 14.0 * scale;
        final btnHeight = 56.0 * scale;
        final btnFontSize = 18.0 * scale;
        final gap = 16.0 * scale;

        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: w * 0.07, vertical: gap),
            child: SizedBox(
              width: cardWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: logoSize, fontWeight: FontWeight.bold),
                      children: const [
                        TextSpan(text: 'MB', style: TextStyle(color: Color(0xFFD4AF37))),
                        TextSpan(text: 'SPORT', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  SizedBox(height: gap * 0.4),
                  Text('RACING DOGS — DISPLAY TV',
                      style: TextStyle(color: Colors.white38, letterSpacing: 3, fontSize: 11 * scale)),
                  SizedBox(height: gap * 2),
                  Text('ID DE AGENCIA',
                      style: TextStyle(color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: labelSize)),
                  SizedBox(height: gap * 0.75),
                  TextField(
                    controller: _controller,
                    onChanged: _onChanged,
                    onSubmitted: (_) => _save(),
                    autofocus: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.visiblePassword,
                    textCapitalization: TextCapitalization.none,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: fieldFontSize,
                      letterSpacing: 2,
                    ),
                    decoration: InputDecoration(
                      hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.2),
                        fontFamily: 'monospace',
                        fontSize: hintFontSize,
                      ),
                      filled: true,
                      fillColor: Colors.black,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 18 * scale),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.4)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.4)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                      ),
                      suffixText: _formatted.isEmpty ? '' : '${_formatted.replaceAll('-', '').length}/32',
                      suffixStyle: TextStyle(
                        color: _valid ? const Color(0xFF4CAF50) : Colors.white38,
                        fontSize: 12 * scale,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  SizedBox(height: gap),
                  SizedBox(
                    width: double.infinity,
                    height: btnHeight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _valid ? const Color(0xFFD4AF37) : Colors.white12,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _valid ? _save : null,
                      child: Text('CONFIRMAR',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: btnFontSize, letterSpacing: 2)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
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
                child: LayoutBuilder(builder: (ctx, constraints) {
                  final scale = (constraints.maxWidth / 600).clamp(0.6, 2.5);
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off, color: const Color(0xFFD4AF37), size: 64 * scale),
                        SizedBox(height: 16 * scale),
                        Text('SIN CONEXIÓN',
                            style: TextStyle(color: Colors.white, fontSize: 24 * scale,
                                fontWeight: FontWeight.bold, letterSpacing: 3)),
                        SizedBox(height: 8 * scale),
                        Text('Reintentando en $_retrySeconds segundos...',
                            style: TextStyle(color: Colors.white54, fontSize: 16 * scale)),
                        SizedBox(height: 24 * scale),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4AF37),
                            foregroundColor: Colors.black,
                            padding: EdgeInsets.symmetric(horizontal: 32 * scale, vertical: 14 * scale),
                          ),
                          onPressed: _reload,
                          child: Text('REINTENTAR AHORA',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15 * scale)),
                        ),
                      ],
                    ),
                  );
                }),
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
          Expanded(child: _Key(label: '1', autofocus: true, onTap: () => onDigit('1'))),
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

// _Key: soporta touch Y control remoto (D-pad + OK)
// InkWell maneja foco nativo → las flechas del control navegan, OK activa
class _Key extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final bool gold;
  final bool autofocus;
  final VoidCallback onTap;
  const _Key({
    this.label,
    this.icon,
    this.gold = false,
    this.autofocus = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: autofocus,
      child: Builder(builder: (ctx) {
        final focused = Focus.of(ctx).hasFocus;
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            decoration: _decoration(focused),
            child: Center(
              child: icon != null
                  ? Icon(icon,
                      color: gold ? const Color(0xFF12241A) : Colors.white,
                      size: 22)
                  : Text(label!,
                      style: TextStyle(
                        color: gold ? const Color(0xFF12241A) : Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      )),
            ),
          ),
        );
      }),
    );
  }

  BoxDecoration _decoration(bool focused) {
    if (gold) {
      return BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFD4AF37), Color(0xFFA67C1F)],
        ),
        borderRadius: BorderRadius.circular(10),
        // Borde blanco brillante cuando está enfocado con el control
        border: focused ? Border.all(color: Colors.white, width: 3) : null,
        boxShadow: focused
            ? [const BoxShadow(color: Color(0xFFD4AF37), blurRadius: 12, spreadRadius: 2)]
            : null,
      );
    }
    return BoxDecoration(
      color: focused
          ? const Color(0xFFD4AF37).withOpacity(0.25)
          : Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: focused ? const Color(0xFFD4AF37) : const Color(0xFFD4AF37).withOpacity(0.3),
        width: focused ? 2.5 : 1.5,
      ),
      boxShadow: focused
          ? [const BoxShadow(color: Color(0xFFD4AF37), blurRadius: 8, spreadRadius: 1)]
          : null,
    );
  }
}
