import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../core/toast.dart';
import 'app_providers.dart';

/// Session state. `user` is null until `/users/me` has been fetched.
class AuthState {
  const AuthState({
    required this.isLoggedIn,
    this.user,
    this.isLoadingUser = false,
  });

  final bool isLoggedIn;
  final UserPublic? user;
  final bool isLoadingUser;

  AuthState copyWith({
    bool? isLoggedIn,
    UserPublic? user,
    bool clearUser = false,
    bool? isLoadingUser,
  }) => AuthState(
    isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    user: clearUser ? null : (user ?? this.user),
    isLoadingUser: isLoadingUser ?? this.isLoadingUser,
  );
}

/// Session controller: login, sign up, logout and the current user.
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final storage = ref.watch(storageProvider);
    final loggedIn = storage.isLoggedIn;
    if (loggedIn) {
      // Kick off the current-user fetch without blocking the first frame.
      Future.microtask(refreshUser);
    }
    return AuthState(isLoggedIn: loggedIn, isLoadingUser: loggedIn);
  }

  Future<void> refreshUser() async {
    if (!state.isLoggedIn) return;
    state = state.copyWith(isLoadingUser: true);
    try {
      final user = await ref.read(usersServiceProvider).readUserMe();
      if (!state.isLoggedIn) return; // logged out while fetching
      state = state.copyWith(user: user, isLoadingUser: false);
    } catch (_) {
      // 401 are handled by the Dio interceptor (logout). Anything else
      // just leaves `user` empty; pages render with what they have.
      state = state.copyWith(isLoadingUser: false);
    }
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    final token = await ref
        .read(loginServiceProvider)
        .loginAccessToken(username: username, password: password);
    await ref.read(storageProvider).setTokens(token);
    state = const AuthState(isLoggedIn: true, isLoadingUser: true);
    await refreshUser();
  }

  Future<void> signUp(UserRegister data) async {
    await ref.read(usersServiceProvider).registerUser(data);
  }

  Future<void> logout() async {
    try {
      await ref.read(loginServiceProvider).logout();
    } catch (_) {
      Toast.error(
        'Signed out on this device. Server logout could not be confirmed.',
      );
    } finally {
      await expireSession();
    }
  }

  Future<void> expireSession() async {
    await ref.read(storageProvider).clearAccessToken();
    state = const AuthState(isLoggedIn: false);
  }

  /// Replace the cached user after a profile update.
  void setUser(UserPublic user) {
    state = state.copyWith(user: user);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

final currentUserProvider = Provider<UserPublic?>(
  (ref) => ref.watch(authProvider).user,
);
