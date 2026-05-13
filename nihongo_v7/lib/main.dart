import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {

  static const platform = MethodChannel('overlay_channel');

  String japaneseText = "";
  String englishText  = "Waiting for Japanese captions...";
  bool isRunning       = false;
  bool hasOverlay      = false;
  bool hasAccessibility = false;
  String statusMsg     = "";
  Timer? pollTimer;
  int translationCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    platform.setMethodCallHandler((call) async {
      if (call.method == "onTranslation" && call.arguments is Map) {
        final args = call.arguments as Map;
        final jp = args["japanese"]?.toString() ?? "";
        final en = args["english"]?.toString() ?? "";
        if (en.isNotEmpty && mounted) {
          setState(() {
            japaneseText = jp;
            englishText  = en;
            translationCount++;
          });
        }
      }
    });
    _checkPermissions();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      final overlay = await platform.invokeMethod<bool>('hasOverlayPermission') ?? false;
      final access  = await platform.invokeMethod<bool>('checkAccessibilityEnabled') ?? false;
      if (mounted) setState(() { hasOverlay = overlay; hasAccessibility = access; });
    } catch (_) {}
  }

  Future<void> _start() async {
    if (!hasOverlay) {
      await platform.invokeMethod('requestOverlayPermission');
      setState(() => statusMsg = '⚠️ Allow "Display over other apps" → come back → tap START again');
      return;
    }
    if (!hasAccessibility) {
      await platform.invokeMethod('openAccessibilitySettings');
      setState(() => statusMsg = '⚠️ Find "Nihongo Lens" → Enable it → come back → tap START');
      return;
    }
    await platform.invokeMethod('startOverlay');
    setState(() {
      isRunning = true;
      translationCount = 0;
      statusMsg = '';
      englishText = "Watching for Japanese captions...";
    });

    // Backup polling
    pollTimer?.cancel();
    pollTimer = Timer.periodic(const Duration(milliseconds: 800), (_) async {
      try {
        final r = await platform.invokeMethod('getLatestTranslation');
        if (r is Map && mounted) {
          final en = r["english"]?.toString() ?? "";
          final jp = r["japanese"]?.toString() ?? "";
          if (en.isNotEmpty && en != englishText) {
            setState(() { englishText = en; japaneseText = jp; translationCount++; });
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _stop() async {
    pollTimer?.cancel();
    await platform.invokeMethod('stopOverlay');
    if (mounted) setState(() {
      isRunning = false; statusMsg = "";
      englishText = "Waiting for Japanese captions..."; japaneseText = "";
    });
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Header ──────────────────────────────────────────────────────
          Row(children: [
            const Text('🎌', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Nihongo Lens',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              Text('Translates Japanese captions from ANY app',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
            ])),
            if (isRunning) Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.fiber_manual_record, color: Colors.white, size: 8),
                const SizedBox(width: 4),
                Text('$translationCount', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ),
          ]),

          const SizedBox(height: 20),

          // ── Permissions ──────────────────────────────────────────────────
          _permRow(Icons.accessibility_new, 'Accessibility Service',
              'Required to read captions from screen', hasAccessibility, () async {
            await platform.invokeMethod('openAccessibilitySettings');
          }),
          const SizedBox(height: 8),
          _permRow(Icons.picture_in_picture_alt, 'Display over apps',
              'Required to show floating overlay', hasOverlay, () async {
            await platform.invokeMethod('requestOverlayPermission');
          }),

          const SizedBox(height: 20),

          // ── Works with ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0a1628),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Works with', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _appChip('📺 YouTube'),
                _appChip('🌐 Chrome'),
                _appChip('🦊 Firefox'),
                _appChip('🎬 VLC'),
                _appChip('🎞 Netflix'),
                _appChip('🎦 Prime'),
                _appChip('📱 Live Caption'),
                _appChip('+ Any app'),
              ]),
            ]),
          ),

          const SizedBox(height: 20),

          // ── Japanese text ────────────────────────────────────────────────
          if (japaneseText.isNotEmpty) ...[
            Row(children: [
              const Text('🎌 Japanese', style: TextStyle(color: Colors.white38, fontSize: 12)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                child: const Text('DETECTED', style: TextStyle(color: Colors.white38, fontSize: 9)),
              ),
            ]),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white10, borderRadius: BorderRadius.circular(10)),
              child: Text(japaneseText,
                  style: const TextStyle(color: Colors.white70, fontSize: 18, letterSpacing: 1.2)),
            ),
            const SizedBox(height: 12),
          ],

          // ── English translation ──────────────────────────────────────────
          const Text('🇬🇧 English Translation',
              style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
            ),
            child: Text(englishText,
                style: const TextStyle(
                    color: Colors.greenAccent, fontSize: 24,
                    fontWeight: FontWeight.bold, height: 1.4)),
          ),

          if (statusMsg.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(statusMsg,
                    style: const TextStyle(color: Colors.orange, fontSize: 13))),
              ]),
            ),
          ],

          const SizedBox(height: 20),

          // ── How it works ─────────────────────────────────────────────────
          if (!isRunning) Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF111111), borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Setup (one time)', style: TextStyle(
                  color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _step('1', 'Grant both permissions above'),
              _step('2', 'Tap START'),
              _step('3', 'Open YouTube / VLC / Chrome / any app'),
              _step('4', 'Play Japanese video'),
              _step('5', 'Enable Live Captions:\n    Volume button → CC icon'),
              _step('6', 'English captions appear as floating overlay ✅'),
            ]),
          ),

          const SizedBox(height: 20),

          // ── START / STOP ─────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isRunning ? _stop : _start,
              icon: Icon(isRunning ? Icons.stop_circle_outlined : Icons.play_circle_outline, size: 26),
              label: Text(
                isRunning ? 'STOP' : 'START LIVE TRANSLATION',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: isRunning ? const Color(0xFF333333) : const Color(0xFFFF3B3B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(child: Text(
            'Overlay stays on screen while you use other apps',
            style: TextStyle(color: Colors.white24, fontSize: 11))),
        ]),
      )),
    );
  }

  Widget _appChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white12),
    ),
    child: Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
  );

  Widget _step(String n, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 20, height: 20,
        decoration: const BoxDecoration(color: Color(0xFFFF3B3B), shape: BoxShape.circle),
        child: Center(child: Text(n,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.5))),
    ]),
  );

  Widget _permRow(IconData icon, String label, String desc, bool granted, VoidCallback onTap) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: granted ? Colors.greenAccent.withOpacity(0.3) : Colors.white12),
      ),
      child: Row(children: [
        Icon(granted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: granted ? Colors.greenAccent : Colors.white30, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
          Text(desc, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ])),
        if (!granted) GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFFF3B3B), borderRadius: BorderRadius.circular(6)),
            child: const Text('Allow', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
        if (granted) const Icon(Icons.check, color: Colors.greenAccent, size: 16),
      ]),
    );
  }
}
