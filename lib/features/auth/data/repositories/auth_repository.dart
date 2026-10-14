import 'dart:convert';
import '../../../../core/api/api_token_store.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../core/api/api_factory.dart';
import '../datasources/api_auth_service.dart';
import '../datasources/auth_service.dart';
import '../../domain/models/user_session.dart';

import '../../../audit/data/repositories/account_audit_repository.dart';
import '../../../audit/domain/models/account_audit_event.dart';
import '../../../audit/domain/models/audit_actor.dart';
import '../../../audit/domain/models/audit_category.dart';
import '../../../audit/domain/models/audit_metadata.dart';
import '../../../audit/domain/models/audit_result.dart';
import '../../../audit/domain/models/audit_target.dart';

abstract class AuthRepository {
  Future<UserSession> login(String identifier, String password);
  Future<UserSession?> restoreSession();
  Future<void> logout();
  Future<void> clearSession();
}

class AuthRepositoryImpl implements AuthRepository {
  static const String _sessionKey = 'aquaflow_user_session';

  final AuthService _authService;
  final SecureStorageService _storageService;
  final ApiTokenStore? _tokenStore;
  final AccountAuditRepository? _auditRepository;

  AuthRepositoryImpl({
    AuthService? authService,
    SecureStorageService? storageService,
    ApiTokenStore? tokenStore,
    AccountAuditRepository? auditRepository,
  })  : _storageService = storageService ?? SecureStorageServiceImpl(),
        _tokenStore = tokenStore,
        _auditRepository = auditRepository,
        _authService = authService ??
            ApiAuthService(ApiRepositoryFactory().client);

  @override
  Future<UserSession> login(String identifier, String password) async {
    final trimmedId = identifier.trim();
    if (trimmedId.isEmpty || password.isEmpty) {
      throw Exception('Username/email and password cannot be empty.');
    }
    try {
      final session = await _authService.login(trimmedId, password);
      await _persistSession(session);
      await _auditRepository?.emitAuditEvent(AccountAuditEvent(
        eventId: 'aud-${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        actor: AuditActor.user(session.userId, session.username),
        category: AuditCategory.authentication,
        action: 'auth.login.success',
        target: AuditTarget(type: 'session', id: session.userId, displayName: 'User Session'),
        result: AuditResult.success,
      ));
      return session;
    } catch (e) {
      await _auditRepository?.emitAuditEvent(AccountAuditEvent(
        eventId: 'aud-${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        actor: AuditActor.user(trimmedId, trimmedId),
        category: AuditCategory.authentication,
        action: 'auth.login.failed',
        target: AuditTarget(type: 'session', id: trimmedId),
        result: AuditResult.failed,
        metadata: AuditMetadata(failureReason: e.toString()),
      ));
      rethrow;
    }
  }

  @override
  Future<UserSession?> restoreSession() async {
    final jsonStr = await _storageService.read(key: _sessionKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      return null;
    }

    try {
      final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (jsonMap.containsKey('password')) {
        await clearSession();
        return null;
      }
      final session = UserSession.fromJson(jsonMap);

      if (session.token.isExpired) {
        try {
          final newToken =
              await _authService.refreshToken(session.token.refreshToken);
          final updatedSession = UserSession(
            userId: session.userId,
            username: session.username,
            email: session.email,
            role: session.role,
            token: newToken,
          );
          await _persistSession(updatedSession);
          return updatedSession;
        } catch (_) {
          await clearSession();
          return null;
        }
      }

      final isValid =
          await _authService.validateToken(session.token.accessToken);
      if (!isValid) {
        await clearSession();
        return null;
      }

      await _tokenStore?.writeTokens(
        accessToken: session.token.accessToken,
        refreshToken: session.token.refreshToken,
      );
      return session;
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  @override
  Future<void> logout() async {
    final jsonStr = await _storageService.read(key: _sessionKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
        final session = UserSession.fromJson(jsonMap);
        await _authService.logout(session.token.accessToken);
      } catch (_) {}
    }
    await clearSession();
  }

  @override
  Future<void> clearSession() async {
    await _storageService.delete(key: _sessionKey);
    await _tokenStore?.clearTokens();
  }

  Future<void> _persistSession(UserSession session) async {
    final payload = session.toJson();
    // Never persist passwords — session JSON is profile + tokens only.
    payload.remove('password');
    await _storageService.write(
      key: _sessionKey,
      value: jsonEncode(payload),
    );
    await _tokenStore?.writeTokens(
      accessToken: session.token.accessToken,
      refreshToken: session.token.refreshToken,
    );
  }
}
