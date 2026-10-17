import 'package:aquaflow_frontend/features/auth/domain/models/auth_token.dart';
import 'package:aquaflow_frontend/features/auth/domain/models/user_role.dart';
import 'package:aquaflow_frontend/features/auth/domain/models/user_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserRole.fromString', () {
    test('parses field_admin, admin, and ROLE_ADMIN', () {
      expect(UserRole.fromString('field_admin'), UserRole.fieldAdmin);
      expect(UserRole.fromString('fieldadmin'), UserRole.fieldAdmin);
      expect(UserRole.fromString('admin'), UserRole.fieldAdmin);
      expect(UserRole.fromString('ROLE_ADMIN'), UserRole.fieldAdmin);
    });

    test('parses supervisor and ROLE_SUPERVISOR', () {
      expect(UserRole.fromString('supervisor'), UserRole.supervisor);
      expect(UserRole.fromString('ROLE_SUPERVISOR'), UserRole.supervisor);
    });

    test('parses operator and ROLE_OPERATOR', () {
      expect(UserRole.fromString('operator'), UserRole.operator);
      expect(UserRole.fromString('ROLE_OPERATOR'), UserRole.operator);
    });

    test('parses user, farmer, and ROLE_USER', () {
      expect(UserRole.fromString('user'), UserRole.user);
      expect(UserRole.fromString('farmer'), UserRole.user);
      expect(UserRole.fromString('ROLE_USER'), UserRole.user);
    });

    test('parses viewer and ROLE_VIEWER', () {
      expect(UserRole.fromString('viewer'), UserRole.viewer);
      expect(UserRole.fromString('ROLE_VIEWER'), UserRole.viewer);
    });

    test('is case-insensitive', () {
      expect(UserRole.fromString('OPERATOR'), UserRole.operator);
      expect(UserRole.fromString('Supervisor'), UserRole.supervisor);
      expect(UserRole.fromString('Farmer'), UserRole.user);
      expect(UserRole.fromString('Field_Admin'), UserRole.fieldAdmin);
      expect(UserRole.fromString('Role_Admin'), UserRole.fieldAdmin);
    });

    test('returns null for unrecognized value', () {
      expect(UserRole.fromString('superuser'), isNull);
      expect(UserRole.fromString('root'), isNull);
      expect(UserRole.fromString('unknown'), isNull);
    });

    test('returns null for empty string', () {
      expect(UserRole.fromString(''), isNull);
    });

    test('returns null for null input', () {
      expect(UserRole.fromString(null), isNull);
    });

    test('round-trips through claimValue', () {
      for (final role in UserRole.values) {
        expect(UserRole.fromString(role.claimValue), equals(role));
      }
    });
  });

  group('UserRole.satisfies — permission ordering', () {
    test('fieldAdmin satisfies all roles', () {
      expect(UserRole.fieldAdmin.satisfies(UserRole.fieldAdmin), isTrue);
      expect(UserRole.fieldAdmin.satisfies(UserRole.supervisor), isTrue);
      expect(UserRole.fieldAdmin.satisfies(UserRole.operator), isTrue);
      expect(UserRole.fieldAdmin.satisfies(UserRole.user), isTrue);
      expect(UserRole.fieldAdmin.satisfies(UserRole.viewer), isTrue);
    });

    test('supervisor satisfies supervisor, user, viewer but not fieldAdmin or operator', () {
      expect(UserRole.supervisor.satisfies(UserRole.fieldAdmin), isFalse);
      expect(UserRole.supervisor.satisfies(UserRole.operator), isFalse);
      expect(UserRole.supervisor.satisfies(UserRole.supervisor), isTrue);
      expect(UserRole.supervisor.satisfies(UserRole.user), isTrue);
      expect(UserRole.supervisor.satisfies(UserRole.viewer), isTrue);
    });

    test('operator satisfies operator, user, viewer but not fieldAdmin or supervisor', () {
      expect(UserRole.operator.satisfies(UserRole.fieldAdmin), isFalse);
      expect(UserRole.operator.satisfies(UserRole.supervisor), isFalse);
      expect(UserRole.operator.satisfies(UserRole.operator), isTrue);
      expect(UserRole.operator.satisfies(UserRole.user), isTrue);
      expect(UserRole.operator.satisfies(UserRole.viewer), isTrue);
    });

    test('user satisfies user and viewer but not operator, supervisor, or fieldAdmin', () {
      expect(UserRole.user.satisfies(UserRole.fieldAdmin), isFalse);
      expect(UserRole.user.satisfies(UserRole.supervisor), isFalse);
      expect(UserRole.user.satisfies(UserRole.operator), isFalse);
      expect(UserRole.user.satisfies(UserRole.user), isTrue);
      expect(UserRole.user.satisfies(UserRole.viewer), isTrue);
    });

    test('viewer satisfies only viewer', () {
      expect(UserRole.viewer.satisfies(UserRole.fieldAdmin), isFalse);
      expect(UserRole.viewer.satisfies(UserRole.supervisor), isFalse);
      expect(UserRole.viewer.satisfies(UserRole.operator), isFalse);
      expect(UserRole.viewer.satisfies(UserRole.user), isFalse);
      expect(UserRole.viewer.satisfies(UserRole.viewer), isTrue);
    });
  });

  group('UserSession.canPerform', () {
    AuthToken createToken(UserRole? role) => AuthToken(
          accessToken: 'tok',
          refreshToken: 'ref',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          fieldId: role != null ? 'field_001' : null,
          role: role,
        );

    UserSession createSession(UserRole? role) => UserSession(
          userId: 'usr_test',
          username: 'tester',
          email: 'tester@aquaflow.io',
          role: role?.displayLabel ?? 'unknown',
          token: createToken(role),
        );

    test('null role — cannot perform any action', () {
      final session = createSession(null);
      expect(session.canPerform(UserRole.viewer), isFalse);
      expect(session.canPerform(UserRole.user), isFalse);
      expect(session.canPerform(UserRole.operator), isFalse);
      expect(session.canPerform(UserRole.supervisor), isFalse);
      expect(session.canPerform(UserRole.fieldAdmin), isFalse);
    });

    test('viewer — only viewer-level permitted', () {
      final session = createSession(UserRole.viewer);
      expect(session.canPerform(UserRole.viewer), isTrue);
      expect(session.canPerform(UserRole.user), isFalse);
      expect(session.canPerform(UserRole.operator), isFalse);
      expect(session.canPerform(UserRole.supervisor), isFalse);
      expect(session.canPerform(UserRole.fieldAdmin), isFalse);
    });

    test('user — user and viewer permitted; operator/admin denied', () {
      final session = createSession(UserRole.user);
      expect(session.canPerform(UserRole.viewer), isTrue);
      expect(session.canPerform(UserRole.user), isTrue);
      expect(session.canPerform(UserRole.operator), isFalse);
      expect(session.canPerform(UserRole.supervisor), isFalse);
      expect(session.canPerform(UserRole.fieldAdmin), isFalse);
    });

    test('operator — viewer, user, and operator permitted; supervisor/admin denied', () {
      final session = createSession(UserRole.operator);
      expect(session.canPerform(UserRole.viewer), isTrue);
      expect(session.canPerform(UserRole.user), isTrue);
      expect(session.canPerform(UserRole.operator), isTrue);
      expect(session.canPerform(UserRole.supervisor), isFalse);
      expect(session.canPerform(UserRole.fieldAdmin), isFalse);
    });

    test('supervisor — viewer, user, and supervisor permitted; operator/admin denied', () {
      final session = createSession(UserRole.supervisor);
      expect(session.canPerform(UserRole.viewer), isTrue);
      expect(session.canPerform(UserRole.user), isTrue);
      expect(session.canPerform(UserRole.operator), isFalse);
      expect(session.canPerform(UserRole.supervisor), isTrue);
      expect(session.canPerform(UserRole.fieldAdmin), isFalse);
    });

    test('fieldAdmin — all levels permitted', () {
      final session = createSession(UserRole.fieldAdmin);
      expect(session.canPerform(UserRole.viewer), isTrue);
      expect(session.canPerform(UserRole.user), isTrue);
      expect(session.canPerform(UserRole.operator), isTrue);
      expect(session.canPerform(UserRole.supervisor), isTrue);
      expect(session.canPerform(UserRole.fieldAdmin), isTrue);
    });

    test('hasValidFieldClaims false when role is null', () {
      expect(createSession(null).hasValidFieldClaims, isFalse);
    });

    test('hasValidFieldClaims true when role and fieldId present', () {
      expect(createSession(UserRole.operator).hasValidFieldClaims, isTrue);
      expect(createSession(UserRole.supervisor).hasValidFieldClaims, isTrue);
      expect(createSession(UserRole.user).hasValidFieldClaims, isTrue);
      expect(createSession(UserRole.fieldAdmin).hasValidFieldClaims, isTrue);
    });
  });
}
