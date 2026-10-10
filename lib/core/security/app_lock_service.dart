import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class AppLockState {
  final bool isLockEnabled;
  final bool isUnlocked;
  final bool isDeviceSecurityAvailable;
  final String? lastError;

  const AppLockState({
    required this.isLockEnabled,
    required this.isUnlocked,
    required this.isDeviceSecurityAvailable,
    this.lastError,
  });

  AppLockState copyWith({
    bool? isLockEnabled,
    bool? isUnlocked,
    bool? isDeviceSecurityAvailable,
    String? lastError,
  }) {
    return AppLockState(
      isLockEnabled: isLockEnabled ?? this.isLockEnabled,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      isDeviceSecurityAvailable: isDeviceSecurityAvailable ?? this.isDeviceSecurityAvailable,
      lastError: lastError,
    );
  }
}

class AppLockService extends StateNotifier<AppLockState> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _keyLockEnabled = 'pl_device_lock_enabled';
  DateTime? _pausedAt;

  AppLockService()
      : super(const AppLockState(
          isLockEnabled: false,
          isUnlocked: true,
          isDeviceSecurityAvailable: true,
        )) {
    _loadState();
  }

  Future<void> _loadState() async {
    final lockEnabledStr = await _storage.read(key: _keyLockEnabled);
    final lockEnabled = lockEnabledStr == 'true';
    final hasSecurity = await isDeviceSecurityAvailable();

    state = AppLockState(
      isLockEnabled: lockEnabled,
      isUnlocked: !lockEnabled, // If lock is disabled, start unlocked
      isDeviceSecurityAvailable: hasSecurity,
    );
  }

  Future<bool> isDeviceSecurityAvailable() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return isSupported || canCheck;
    } catch (_) {
      return false;
    }
  }

  /// Authenticate using device biometrics or device PIN/password/pattern fallback
  Future<bool> authenticate() async {
    try {
      final isSecured = await isDeviceSecurityAvailable();
      if (!isSecured) {
        state = state.copyWith(
          lastError: 'No screen lock or biometrics configured on this phone. Please set up a screen lock in Android Settings.',
        );
        return false;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate with fingerprint, face, or device PIN to open BismillahStore',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allows Android system device PIN/pattern/password fallback
        ),
      );

      if (authenticated) {
        state = state.copyWith(isUnlocked: true, lastError: null);
      } else {
        state = state.copyWith(lastError: 'Authentication was cancelled.');
      }
      return authenticated;
    } on PlatformException catch (e) {
      String msg = 'Authentication error: ${e.message ?? e.code}';
      if (e.code == 'NotAvailable' || e.code == 'PasscodeNotSet') {
        msg = 'Please set up a screen lock (PIN, Pattern, or Fingerprint) in Android Settings.';
      }
      state = state.copyWith(lastError: msg);
      return false;
    } catch (e) {
      state = state.copyWith(lastError: 'Authentication error: $e');
      return false;
    }
  }

  Future<bool> enableDeviceLock() async {
    final success = await authenticate();
    if (success) {
      await _storage.write(key: _keyLockEnabled, value: 'true');
      state = state.copyWith(isLockEnabled: true, isUnlocked: true, lastError: null);
      return true;
    }
    return false;
  }

  Future<void> disableDeviceLock() async {
    await _storage.delete(key: _keyLockEnabled);
    state = state.copyWith(isLockEnabled: false, isUnlocked: true, lastError: null);
  }

  void onAppPaused() {
    if (state.isLockEnabled) {
      _pausedAt = DateTime.now();
    }
  }

  void onAppResumed() {
    if (state.isLockEnabled && _pausedAt != null) {
      final elapsed = DateTime.now().difference(_pausedAt!);
      // Lock if app was in background for 30+ seconds
      if (elapsed.inSeconds >= 30) {
        state = state.copyWith(isUnlocked: false);
      }
      _pausedAt = null;
    }
  }

  void lockNow() {
    if (state.isLockEnabled) {
      state = state.copyWith(isUnlocked: false);
    }
  }
}

final appLockServiceProvider =
    StateNotifierProvider<AppLockService, AppLockState>((ref) {
  return AppLockService();
});
