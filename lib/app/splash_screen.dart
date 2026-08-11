import 'dart:async';

import 'package:flutter/material.dart';

class AppSplashGate extends StatefulWidget {
  const AppSplashGate({
    required this.child,
    this.duration = const Duration(milliseconds: 1800),
    super.key,
  });

  final Widget child;
  final Duration duration;

  @override
  State<AppSplashGate> createState() => _AppSplashGateState();
}

class _AppSplashGateState extends State<AppSplashGate> {
  Timer? _timer;
  var _showSplash = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, () {
      if (!mounted) {
        return;
      }
      setState(() => _showSplash = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _showSplash
          ? const SuaCodeSplashScreen()
          : KeyedSubtree(
              key: const ValueKey('app_content'),
              child: widget.child,
            ),
    );
  }
}

class SuaCodeSplashScreen extends StatelessWidget {
  const SuaCodeSplashScreen({super.key});

  static const String logoAsset = 'assets/images/suacode-ide-logo.png';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FBF6),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 132,
                  height: 132,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E3A5F).withValues(alpha: 0.16),
                        blurRadius: 30,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Image.asset(logoAsset, fit: BoxFit.contain),
                ),
                const SizedBox(height: 24),
                Text(
                  'SuaCode IDE',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: const Color(0xFF1E3345),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
