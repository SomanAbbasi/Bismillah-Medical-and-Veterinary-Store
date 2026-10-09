import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class AppLockState {
  final bool isLockEnabled;
  final bool isBiometricEnabled;
  final bool hasPin;
  final bool isUnlocked;

  const AppLockState({
    required this.isLockEnabled,
    required this.isBiometricEnabled,
    required this.hasPin,
    required this.isUnlocked,
  });

  AppLockState copyWith({
    bool? isLockEnabled,
    bool? isBiometricEnabled,
    bool? hasPin,
    bool? isUnlocked,
  }) {
    return AppLockState(
      isLockEnabled: isLockEnabled ?? this.isLockEnabled,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      hasPin: hasPin ?? this.hasPin,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }
}

class AppLockService extends StateNotifier<AppLockState> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _keyLockEnabled = 'pl_app_lock_enabled';
  static const _keyBiometricEnabled = 'pl_biometric_enabled';
  static const _keyPin = 'pl_app_pin';

  AppLockService()
      : super(const AppLockState(
          isLockEnabled: false,
          isBiometricEnabled: false,
          hasPin: false,
          isUnlocked: true,
        )) {
    _loadState();
  }

  Future<void> _loadState() async {
    final lockEnabledStr = await _storage.read(key: _keyLockEnabled);
    final bioEnabledStr = await _storage.read(key: _keyBiometricEnabled);
    final pinStr = await _storage.read(key: _keyPin);

    final lockEnabled = lockEnabledStr == 'true';
    final bioEnabled = bioEnabledStr == 'true';
    final hasPin = pinStr != null && pinStr.isNotEmpty;

    state = AppLockState(
      isLockEnabled: lockEnabled,
      isBiometricEnabled: bioEnabled,
      hasPin: hasPin,
      isUnlocked: !lockEnabled, // If lock is disabled, start unlocked
    );
  }

  Future<bool> isBiometricsAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> verifyPin(String enteredPin) async {
    final storedPin = await _storage.read(key: _keyPin);
    if (storedPin == enteredPin) {
      state = state.copyWith(isUnlocked: true);
      return true;
    }
    return false;
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to unlock PharmaLedger',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      if (authenticated) {
        state = state.copyWith(isUnlocked: true);
      }
      return authenticated;
    } on PlatformException {
      return false;
    }
  }

  Future<void> setPin(String pin) async {
    await _storage.write(key: _keyPin, value: pin);
    await _storage.write(key: _keyLockEnabled, value: 'true');
    state = state.copyWith(
      isLockEnabled: true,
      hasPin: true,
      isUnlocked: true,
    );
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    await _storage.write(key: _keyBiometricEnabled, value: enabled.toString());
    state = state.copyWith(isBiometricEnabled: enabled);
  }

  Future<void> disableAppLock() async {
    await _storage.delete(key: _keyPin);
    await _storage.write(key: _keyLockEnabled, value: 'false');
    await _storage.write(key: _keyBiometricEnabled, value: 'false');
    state = const AppLockState(
      isLockEnabled: false,
      isBiometricEnabled: false,
      hasPin: false,
      isUnlocked: true,
    );
  }

  void lockApp() {
    if (state.isLockEnabled) {
      state = state.copyWith(isUnlocked: false);
    }
  }

  void unlock() {
    state = state.copyWith(isUnlocked: true);
  }
}

final appLockServiceProvider =
    StateNotifierProvider<AppLockService, AppLockState>((ref) {
  return AppLockService();
});
