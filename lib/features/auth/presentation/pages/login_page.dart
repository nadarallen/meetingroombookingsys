import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/validators.dart';
import '../../presentation/viewmodels/auth_view_model.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final TextEditingController _passwordController = TextEditingController();
  bool _controllersReady = false;
  bool _rememberMe = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_controllersReady) {
      final auth = context.read<AuthViewModel>();
      _rememberMe = auth.rememberMe;
      _emailController = TextEditingController(text: auth.rememberedEmail ?? '');
      _controllersReady = true;
    }
  }

  @override
  void dispose() {
    if (_controllersReady) {
      _emailController.dispose();
    }
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final busy = auth.isBusy(AuthOperation.login);

    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                    autofillHints: const [AutofillHints.username],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (value) => Validators.minLength(value, 6, fieldName: 'Password'),
                    autofillHints: const [AutofillHints.password],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: busy ? null : _resetPassword,
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Remember me'),
                    value: _rememberMe,
                    onChanged: busy
                        ? null
                        : (value) async {
                            if (value == null) return;
                            setState(() => _rememberMe = value);
                            await context.read<AuthViewModel>().setRememberMe(value);
                          },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: busy ? null : _submit,
                      child: busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sign In'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('No account?'),
                      TextButton(
                        onPressed: () => context.go('/auth/register'),
                        child: const Text('Create one'),
                      ),
                    ],
                  ),
                  if (auth.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(auth.errorMessage!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthViewModel>();
    final success = await auth.login(
      _emailController.text,
      _passwordController.text,
      remember: _rememberMe,
    );

    if (!mounted) return;
    final message = auth.errorMessage ?? auth.infoMessage;
    if (message != null && (!success || auth.infoMessage != null)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      auth.clearMessages();
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email first.')),
      );
      return;
    }

    final auth = context.read<AuthViewModel>();
    final ok = await auth.sendPasswordReset(email);

    if (!mounted) return;
    final message = auth.errorMessage ?? auth.infoMessage;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      auth.clearMessages();
    }

    if (ok) {
      _passwordController.clear();
    }
  }
}

