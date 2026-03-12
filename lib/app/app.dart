import 'package:flutter/material.dart';
import 'package:p5de/app/di/app_dependencies.dart';

class P5deApp extends StatelessWidget {
  const P5deApp({required this.dependencies, super.key});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'p5de',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const _BootstrapStatusScreen(),
    );
  }
}

class _BootstrapStatusScreen extends StatelessWidget {
  const _BootstrapStatusScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(child: Text('Milestone 0 foundation ready')),
      ),
    );
  }
}
