import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/widgets/app_loading.dart';
import '../../domain/entities/user_profile.dart';
import '../viewmodels/auth_view_model.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _employeeIdController;
  late final TextEditingController _departmentController;
  bool _controllersInitialized = false;
  bool _editing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeInitControllers();
  }

  void _maybeInitControllers() {
    if (_controllersInitialized) return;
    final user = context.read<AuthViewModel>().user;
    if (user == null) return;

    _nameController = TextEditingController(text: user.fullName);
    _emailController = TextEditingController(text: user.email);
    _employeeIdController = TextEditingController(text: user.employeeId);
    _departmentController = TextEditingController(text: user.department);
    _controllersInitialized = true;
  }

  @override
  void dispose() {
    if (_controllersInitialized) {
      _nameController.dispose();
      _emailController.dispose();
      _employeeIdController.dispose();
      _departmentController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();

    if (!auth.isInitialized) {
      return const Scaffold(body: AppLoading());
    }

    final user = auth.user;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No profile loaded. Please sign in.')),
      );
    }

    if (!_controllersInitialized) {
      // Ensure controllers sync with user once available
      _maybeInitControllers();
    }

    final updating = auth.isBusy(AuthOperation.updateProfile);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: _editing ? 'Cancel' : 'Edit',
            onPressed: () {
              if (updating) return;
              setState(() {
                _editing = !_editing;
                if (!_editing) {
                  _resetFields(user);
                }
              });
            },
            icon: Icon(_editing ? Icons.close : Icons.edit),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Account', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full name'),
                textCapitalization: TextCapitalization.words,
                readOnly: !_editing,
                validator: (value) => value == null || value.trim().isEmpty ? 'Full name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                readOnly: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _employeeIdController,
                decoration: const InputDecoration(labelText: 'Employee ID'),
                readOnly: !_editing,
                validator: (value) => value == null || value.trim().isEmpty ? 'Employee ID is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _departmentController,
                decoration: const InputDecoration(labelText: 'Department'),
                readOnly: !_editing,
                validator: (value) => value == null || value.trim().isEmpty ? 'Department is required' : null,
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Role'),
                child: Text(user.isAdmin ? 'Admin' : 'Member'),
              ),
              const SizedBox(height: 24),
              if (_editing)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: updating ? null : () => _save(user),
                    icon: updating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(updating ? 'Saving...' : 'Save changes'),
                  ),
                ),
              if (auth.errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(auth.errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _resetFields(UserProfile user) {
    _nameController.text = user.fullName;
    _emailController.text = user.email;
    _employeeIdController.text = user.employeeId;
    _departmentController.text = user.department;
  }

  Future<void> _save(UserProfile current) async {
    if (!_formKey.currentState!.validate()) return;

    final updated = current.copyWith(
      fullName: _nameController.text.trim(),
      employeeId: _employeeIdController.text.trim(),
      department: _departmentController.text.trim(),
    );

    final auth = context.read<AuthViewModel>();
    final success = await auth.updateProfile(updated);

    if (!mounted) return;
    final message = auth.errorMessage ?? auth.infoMessage;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      auth.clearMessages();
    }

    if (success) {
      setState(() => _editing = false);
    }
  }
}
