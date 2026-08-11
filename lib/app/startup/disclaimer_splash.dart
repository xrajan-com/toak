import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ten_of_a_kind_poker/app/startup/auth_gate.dart';

class DisclaimerSplash extends StatefulWidget {
  static const String acceptanceKey = 'disclaimer.accepted.v2';

  const DisclaimerSplash({super.key});

  @override
  State<DisclaimerSplash> createState() => _DisclaimerSplashState();
}

class _DisclaimerSplashState extends State<DisclaimerSplash> {
  static const _paragraphs = <String>[
    'Ten of a Kind is a free, recreational poker simulation made for fun and '
        'learning. It is not a gambling or real-money gaming product.',
    'There are no cash deposits, cash-outs, prizes, or rewards with real-world '
        'value. Chips, AUP, Aura, ranks, and progress exist only inside the game.',
    'Poker involves chance. Focus on decision quality over any single result, '
        'and take a break if play stops feeling enjoyable.',
    'You must be at least 18 to use this app. Follow the laws that apply where '
        'you live and avoid illegal real-money offerings.',
  ];

  bool _checking = true;
  bool _accepted = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadAcceptance();
  }

  Future<void> _loadAcceptance() async {
    var accepted = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      accepted = prefs.getBool(DisclaimerSplash.acceptanceKey) ?? false;
    } catch (error) {
      debugPrint('Disclaimer preference load failed: $error');
    }
    if (!mounted) return;
    setState(() {
      _accepted = accepted;
      _checking = false;
    });
  }

  Future<void> _continue() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setBool(DisclaimerSplash.acceptanceKey, true);
      if (!saved) {
        debugPrint('Disclaimer preference write was rejected.');
      }
    } catch (error) {
      // Do not trap the user if local preferences are temporarily unavailable.
      debugPrint('Disclaimer preference write failed: $error');
    }
    if (!mounted) return;
    setState(() {
      _accepted = true;
      _saving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white70),
        ),
      );
    }
    if (_accepted) return const AuthGate();

    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 620;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                size.width < 380 ? 16 : 24,
                compact ? 12 : 24,
                size.width < 380 ? 16 : 24,
                compact ? 12 : 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Before You Play',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFFFF4B36),
                      fontWeight: FontWeight.w900,
                      fontSize: compact ? 24 : 30,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Recreational and educational use only',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: compact ? 12 : 22),
                  Expanded(
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(right: 10),
                        child: Semantics(
                          label: 'Game disclaimer',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final paragraph in _paragraphs)
                                Padding(
                                  padding: EdgeInsets.only(
                                    bottom: compact ? 12 : 18,
                                  ),
                                  child: Text(
                                    paragraph,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: compact ? 14 : 16,
                                      height: 1.45,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const ValueKey('disclaimer_continue'),
                    onPressed: _saving ? null : _continue,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label:
                        Text(_saving ? 'Saving…' : 'I Understand — Continue'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: const Color(0xFFC62828),
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
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
