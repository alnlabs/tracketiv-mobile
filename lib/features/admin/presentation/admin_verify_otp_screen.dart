import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/admin/admin_device_id.dart';
import '../../../shared/utils/api_error_formatter.dart';
import '../../../shared/widgets/loading_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/admin_auth_provider.dart';
import '../providers/admin_otp_provider.dart';
import '../providers/admin_session_provider.dart';

class AdminVerifyOtpScreen extends ConsumerStatefulWidget {
  const AdminVerifyOtpScreen({super.key});

  @override
  ConsumerState<AdminVerifyOtpScreen> createState() => _AdminVerifyOtpScreenState();
}

class _AdminVerifyOtpScreenState extends ConsumerState<AdminVerifyOtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  String? _error;
  String? _emailHint;
  int? _expiresInMinutes;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    await ref.read(authRepositoryProvider).signOut();
    await ref.read(adminSessionActiveProvider.notifier).deactivate();
    await ref.read(adminOtpPendingProvider.notifier).clear();
    if (mounted) context.go('/admin/login');
  }

  Future<void> _resend() async {
    setState(() {
      _isResending = true;
      _error = null;
    });

    try {
      final deviceId = await AdminDeviceId.get();
      final result = await ref.read(adminAuthSecurityRepositoryProvider).sendLoginOtp(deviceId);
      if (!mounted) return;
      setState(() {
        _emailHint = result.emailHint ?? _emailHint;
        _expiresInMinutes = result.expiresInMinutes;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification code sent')),
      );
    } catch (e) {
      setState(() => _error = e.toUserMessage());
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final deviceId = await AdminDeviceId.get();
      await ref.read(adminAuthSecurityRepositoryProvider).verifyLoginOtp(
            deviceId: deviceId,
            code: _codeController.text.trim(),
          );
      await ref.read(adminOtpPendingProvider.notifier).clear();
      await ref.read(adminSessionActiveProvider.notifier).activate();
      if (mounted) context.go('/admin');
    } catch (e) {
      setState(() => _error = e.toUserMessage());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emailHint = _emailHint ??
        maskEmail(ref.watch(adminCurrentUserProvider)?.email);
    final expiryText = _expiresInMinutes == null
        ? 'The code expires in 10 minutes.'
        : 'The code expires in $_expiresInMinutes minutes.';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify sign-in'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isLoading ? null : _cancel,
        ),
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
                  'Check your email',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We sent a 6-digit code to $emailHint because this device has not been used for admin access before.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  expiryText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Verification code',
                    hintText: '123456',
                    counterText: '',
                  ),
                  validator: (value) {
                    final code = value?.trim() ?? '';
                    if (code.length != 6) return 'Enter the 6-digit code';
                    return null;
                  },
                  onFieldSubmitted: (_) => _verify(),
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
                  onPressed: _verify,
                  label: 'Verify and continue',
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isResending || _isLoading ? null : _resend,
                  child: Text(_isResending ? 'Sending…' : 'Resend code'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
