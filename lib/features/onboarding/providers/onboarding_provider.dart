import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _onboardingCompletedKey = 'onboarding_completed_v1';

Future<bool> readOnboardingCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_onboardingCompletedKey) ?? false;
}

class OnboardingNotifier extends StateNotifier<AsyncValue<bool>> {
  OnboardingNotifier([bool? initialCompleted])
      : super(
          initialCompleted != null
              ? AsyncData(initialCompleted)
              : const AsyncValue.loading(),
        ) {
    if (initialCompleted == null) {
      _load();
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AsyncData(prefs.getBool(_onboardingCompletedKey) ?? false);
  }

  Future<void> complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, true);
    state = const AsyncData(true);
  }
}

final onboardingCompletedProvider =
    StateNotifierProvider<OnboardingNotifier, AsyncValue<bool>>((ref) {
  return OnboardingNotifier();
});

bool isOnboardingPublicRoute(String path) {
  return path == '/onboarding' ||
      path == '/about' ||
      path == '/disclaimer' ||
      path == '/privacy-policy';
}
