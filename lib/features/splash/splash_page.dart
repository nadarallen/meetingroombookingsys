import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/presentation/viewmodels/auth_view_model.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _initTriggered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initTriggered) {
      _initTriggered = true;
      context.read<AuthViewModel>().init();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FlutterLogo(size: 96),
            const SizedBox(height: 24),
            const Text('Meeting Room Booking'),
            const SizedBox(height: 12),
            if (!auth.isInitialized) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              const Text('Checking authentication...'),
            ] else ...[
              const Text('Loading completed'),
            ],
          ],
        ),
      ),
    );
  }
}

