// Aichat_screen.dart

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

// =============================================
// CONSTANTS
// =============================================

const String _kBaseUrl = 'https://ai-backend-phgm.onrender.com';

const _kPrimary = Color(0xFFFFD76F);
const _kAccent = Color(0xFFFFB347);
const _kBg = Color(0xFF0B0B10);
const _kBorder = Color(0x14FFFFFF);
const _kUserText = Color(0xFF111111);
const _kBotText = Colors.white;

const _kLanguages = [
  {'code': 'en', 'locale': 'en_IN', 'label': 'English'},
  {'code': 'ta', 'locale': 'ta_IN', 'label': 'Tamil'},
  {'code': 'hi', 'locale': 'hi_IN', 'label': 'Hindi'},
  {'code': 'te', 'locale': 'te_IN', 'label': 'Telugu'},
  {'code': 'kn', 'locale': 'kn_IN', 'label': 'Kannada'},
];

// =============================================
// DATA MODEL
// =============================================

class AIChatMessage {
  final String text;
  final bool isUser;

  const AIChatMessage({required this.text, required this.isUser});
}

// =============================================
// ENTRY POINT  (use this in main.dart)
// =============================================
//
//  void main() {
//    runApp(const MaterialApp(
//      debugShowCheckedModeBanner: false,
//      home: ChatScreen(),
//    ));
//  }

// =============================================
// CHAT SCREEN
// =============================================

class Aisearchsheet extends StatefulWidget {
  const Aisearchsheet({super.key});

  @override
  State<Aisearchsheet> createState() => _AisearchsheetState();
}

class _AisearchsheetState extends State<Aisearchsheet>
    with TickerProviderStateMixin {
  // -- State --------------------------------
  final List<AIChatMessage> _messages = [
    const AIChatMessage(
      text: 'Welcome to Real Estate AI Assistant',
      isUser: false,
    ),
  ];

  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  bool _loading = false;
  bool _isListening = false;
  String _selectedLang = 'en';

  // userId — replace with real auth value if needed
  final int _userId = 1;

  // -- Speech -------------------------------
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;

  // -- Audio --------------------------------
  final AudioPlayer _audioPlayer = AudioPlayer();

  // -- Typing-dot animation -----------------
  late final AnimationController _dotCtrl;
  late final Animation<double> _dotAnim;

  // -- Particles ----------------------------
  final List<_Particle> _particles = List.generate(70, (_) => _Particle());

  @override
  void initState() {
    super.initState();

    // Typing dots animation
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _dotAnim = Tween<double>(
      begin: 0.2,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _dotCtrl, curve: Curves.easeInOut));

    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize();

    if (!mounted) return;

    setState(() {});
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _dotCtrl.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // =============================================
  // SCROLL TO BOTTOM
  // =============================================

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // =============================================
  // SEND MESSAGE
  // =============================================

  Future<void> _sendMessage([String? customText]) async {
    final text = (customText ?? _inputCtrl.text).trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(AIChatMessage(text: text, isUser: true));
      _loading = true;
    });

    _inputCtrl.clear();
    _scrollToBottom();

    try {
      final res = await http.post(
        Uri.parse('$_kBaseUrl/chat'),

        headers: {'Content-Type': 'application/json'},

        body: jsonEncode({
          'message': text,
          'userId': _userId,
          'language': _selectedLang,
        }),
      );

      print("STATUS => ${res.statusCode}");
      print("BODY => ${res.body}");

      if (res.statusCode != 200) {
        throw Exception("Backend Error => ${res.body}");
      }

      final data = jsonDecode(res.body);

      setState(() {
        _loading = false;

        _messages.add(
          AIChatMessage(
            text: data['reply']?.toString() ?? 'No response',
            isUser: false,
          ),
        );
      });
    } catch (e, stack) {
      print("ERROR => $e");
      print("STACK => $stack");

      setState(() {
        _loading = false;

        _messages.add(
          AIChatMessage(text: 'Server Error. Please try again.', isUser: false),
        );
      });

      _scrollToBottom();
    }
  }

  // =============================================
  // VOICE INPUT
  // =============================================

  Future<void> _toggleVoice() async {
    if (!_speechAvailable) {
      _showSnack('Voice recognition not available on this device.');
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    // Map selected lang code ? locale
    final locale = _kLanguages.firstWhere(
      (l) => l['code'] == _selectedLang,
      orElse: () => _kLanguages.first,
    )['locale']!;

    setState(() => _isListening = true);

    await _speech.listen(
      localeId: locale,
      onResult: (SpeechRecognitionResult result) {
        if (result.finalResult) {
          if (!mounted) return;
          setState(() => _isListening = false);
          _sendMessage(result.recognizedWords);
        }
      },
      cancelOnError: true,
      listenFor: const Duration(seconds: 30),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // =============================================
  // BUILD
  // =============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // -- Particle background --------------
          const _ParticleCanvas(),

          // -- Main UI -------------------------
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildChatArea()),
                _buildInputBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =============================================
  // HEADER
  // =============================================

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: _kBorder, width: 1)),
      ),
      child: Row(
        children: [
          // Title
          const Text(
            'Real Estate AI',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const Spacer(),

          // Language selector
          _buildLangDropdown(),
        ],
      ),
    );
  }

  Widget _buildLangDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedLang,
          dropdownColor: const Color(0xFF1F1F2E),
          style: const TextStyle(color: _kPrimary, fontSize: 14),
          icon: const Icon(Icons.arrow_drop_down, color: _kPrimary),
          items: _kLanguages.map((lang) {
            return DropdownMenuItem<String>(
              value: lang['code']!,
              child: Text(lang['label']!),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedLang = val);
          },
        ),
      ),
    );
  }

  // =============================================
  // CHAT AREA
  // =============================================

  Widget _buildChatArea() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(20),
      itemCount: _messages.length + (_loading ? 1 : 0),
      itemBuilder: (context, index) {
        if (_loading && index == _messages.length) {
          return _buildTypingIndicator();
        }
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(AIChatMessage msg) {
    final isUser = msg.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(
                  colors: [_kPrimary, _kAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isUser ? null : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser
              ? null
              : Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            color: isUser ? _kUserText : _kBotText,
            fontSize: 14.5,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  // -- Typing dots -----------------------------

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: List.generate(3, (i) {
          return _TypingDot(controller: _dotCtrl, delay: i * 0.15);
        }),
      ),
    );
  }

  // =============================================
  // INPUT BAR
  // =============================================

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        border: Border(top: BorderSide(color: _kBorder, width: 1)),
      ),
      child: Row(
        children: [
          // Text input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: TextField(
                controller: _inputCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ask about properties, PG, visits...',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.38),
                    fontSize: 14,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
                textInputAction: TextInputAction.send,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Mic button
          _IconBtn(
            onTap: _toggleVoice,
            active: _isListening,
            child: _isListening
                ? const _PulsingMic()
                : const Icon(Icons.mic_rounded, color: Colors.white, size: 20),
          ),

          const SizedBox(width: 8),

          // Send button
          GestureDetector(
            onTap: () => _sendMessage(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kPrimary, _kAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Send',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _kUserText,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================
// TYPING DOT WIDGET
// =============================================

class _TypingDot extends StatelessWidget {
  final AnimationController controller;
  final double delay;

  const _TypingDot({required this.controller, required this.delay});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        // Each dot shifts phase using delay
        final phase = (controller.value + delay) % 1.0;
        final opacity = 0.2 + 0.8 * (0.5 - (phase - 0.5).abs()) * 2;
        return Container(
          margin: const EdgeInsets.only(right: 5),
          child: Text(
            '•',
            style: TextStyle(
              fontSize: 28,
              color: _kPrimary.withOpacity(opacity.clamp(0.2, 1.0)),
            ),
          ),
        );
      },
    );
  }
}

// =============================================
// PULSING MIC (listening state)
// =============================================

class _PulsingMic extends StatefulWidget {
  const _PulsingMic();

  @override
  State<_PulsingMic> createState() => _PulsingMicState();
}

class _PulsingMicState extends State<_PulsingMic>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 0.85,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: const Icon(Icons.mic_rounded, color: _kPrimary, size: 20),
    );
  }
}

// =============================================
// ICON BUTTON WRAPPER
// =============================================

class _IconBtn extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  final bool active;

  const _IconBtn({
    required this.onTap,
    required this.child,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: active
              ? _kPrimary.withOpacity(0.15)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active
                ? _kPrimary.withOpacity(0.4)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: child,
      ),
    );
  }
}

// =============================================
// PARTICLE SYSTEM  (mirrors ParticleCanvas)
// =============================================

class _Particle {
  late double x, y, size, speedX, speedY;
  final Random _rng = Random();

  _Particle() {
    _reset(800, 1200);
  }

  void _reset(double w, double h) {
    x = _rng.nextDouble() * w;
    y = _rng.nextDouble() * h;
    size = _rng.nextDouble() * 2 + 1;
    speedX = (_rng.nextDouble() - 0.5) * 0.5;
    speedY = (_rng.nextDouble() - 0.5) * 0.5;
  }

  void update(double w, double h) {
    x += speedX;
    y += speedY;
    if (x > w) x = 0;
    if (x < 0) x = w;
    if (y > h) y = 0;
    if (y < 0) y = h;
  }
}

class _ParticleCanvas extends StatefulWidget {
  const _ParticleCanvas();

  @override
  State<_ParticleCanvas> createState() => _ParticleCanvasState();
}

class _ParticleCanvasState extends State<_ParticleCanvas>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<_Particle> _particles = List.generate(70, (_) => _Particle());

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) {
        final size = MediaQuery.of(ctx).size;
        for (final p in _particles) {
          p.update(size.width, size.height);
        }
        return CustomPaint(painter: _ParticlePainter(_particles), size: size);
      },
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  _ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x80FFD778); // rgba(255,215,120,0.5)

    for (final p in particles) {
      canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => true;
}
