import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../legal/presentation/legal_screens.dart';
import '../../../shared/widgets/auth_credential_fields.dart';
import '../../../shared/widgets/loading_button.dart';
import '../../admin/providers/admin_provider.dart';
import '../../admin/providers/admin_session_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/session_sync_provider.dart';
import 'package:tracketiv/shared/utils/api_error_formatter.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _enforceNonAdminSession());
  }

  Future<void> _enforceNonAdminSession() async {
    if (ref.read(currentUserProvider) == null) return;
    final adminMode = ref.read(adminSessionActiveProvider).valueOrNull ?? false;
    if (adminMode) return;
    final isAdmin = await ref.read(mainSessionIsAdminProvider.future);
    if (!mounted || !isAdmin) return;
    await ref.read(authRepositoryProvider).signOut();
    setState(() {
      _error = 'Admin accounts must use Admin management login.';
    });
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref.read(authRepositoryProvider).signIn(
            emailOrUsername: _identifierController.text.trim(),
            password: _passwordController.text,
          );
      invalidateUserSessionData(ref);
      final isAdmin = await ref.read(mainSessionIsAdminProvider.future);
      if (isAdmin) {
        await ref.read(authRepositoryProvider).signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Admin accounts must use Admin management login.'),
            ),
          );
          context.go('/admin/login');
        }
        return;
      }
      await ref.read(adminSessionActiveProvider.notifier).deactivate();
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() => _error = e.toUserMessage());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                Text(
                  AppConstants.appName,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Track habits. Achieve goals. Together.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                AuthCredentialFields(
                  identifierController: _identifierController,
                  passwordController: _passwordController,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/forgot-password'),
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 16),
                LoadingButton(
                  onPressed: _login,
                  label: 'Log in',
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account?"),
                    TextButton(
                      onPressed: () => context.push('/register'),
                      child: const Text('Sign up'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go('/admin/login'),
                  child: const Text('Admin management login'),
                ),
                const SizedBox(height: 8),
                const AuthLegalLinks(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
