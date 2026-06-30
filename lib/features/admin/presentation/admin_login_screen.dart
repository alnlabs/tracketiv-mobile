import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/auth_credential_fields.dart';
import '../../../shared/widgets/loading_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../../../core/admin/admin_device_id.dart';
import '../providers/admin_otp_provider.dart';
import '../providers/admin_session_provider.dart';
import 'package:tracketiv/shared/utils/api_error_formatter.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

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

      ref.invalidate(currentProfileProvider);
      final profile = await ref.read(currentProfileProvider.future);

      if (profile?.isAdmin != true) {
        await ref.read(authRepositoryProvider).signOut();
        await ref.read(adminSessionActiveProvider.notifier).deactivate();
        await ref.read(adminOtpPendingProvider.notifier).clear();
        setState(() => _error = 'This account does not have admin access.');
        return;
      }

      final deviceId = await AdminDeviceId.get();
      final security = ref.read(adminAuthSecurityRepositoryProvider);
      final trusted = await security.isDeviceTrusted(deviceId);

      if (trusted) {
        await ref.read(adminOtpPendingProvider.notifier).clear();
        await ref.read(adminSessionActiveProvider.notifier).activate();
        if (mounted) context.go('/admin');
        return;
      }

      final otpResult = await security.sendLoginOtp(deviceId);
      if (otpResult.alreadyTrusted) {
        await ref.read(adminOtpPendingProvider.notifier).clear();
        await ref.read(adminSessionActiveProvider.notifier).activate();
        if (mounted) context.go('/admin');
        return;
      }

      await ref.read(adminOtpPendingProvider.notifier).setPending(true);
      if (mounted) context.go('/admin/verify-otp');
    } catch (e) {
      setState(() => _error = e.toUserMessage());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracketiv Admin'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Management console',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in with your admin account to manage users, default app data, feedback, and configuration.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 32),
                AuthCredentialFields(
                  identifierController: _identifierController,
                  passwordController: _passwordController,
                  identifierLabel: 'Admin email or username',
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                LoadingButton(
                  onPressed: _login,
                  label: 'Sign in to management console',
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
