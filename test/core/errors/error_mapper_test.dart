import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:fasostock/core/errors/app_error_handler.dart';

void main() {
  group('ErrorMapper.toMessage', () {
    test('null returns fallback or unexpected', () {
      expect(ErrorMapper.toMessage(null), contains('erreur'));
      expect(ErrorMapper.toMessage(null, fallback: 'Custom'), 'Custom');
    });

    test('UserFriendlyError returns its message', () {
      const err = UserFriendlyError('Message utilisateur');
      expect(ErrorMapper.toMessage(err), 'Message utilisateur');
    });

    test('network-like errors return network message', () {
      expect(
        ErrorMapper.toMessage(Exception('SocketException: failed')),
        contains('Connexion internet'),
      );
      expect(
        ErrorMapper.toMessage(Exception('Connection refused')),
        contains('Connexion internet'),
      );
      expect(
        ErrorMapper.toMessage(Exception('Failed host lookup')),
        contains('Connexion internet'),
      );
      expect(
        ErrorMapper.toMessage(TimeoutException('Connection timed out')),
        contains('Connexion internet'),
      );
      expect(
        ErrorMapper.toMessage(Exception('request timed out')),
        contains('Connexion internet'),
      );
    });

    test('permission/RLS errors return permission message', () {
      expect(
        ErrorMapper.toMessage(Exception('new row violates row-level security policy')),
        contains('autorisation'),
      );
      expect(
        ErrorMapper.toMessage(Exception('Permission denied')),
        contains('autorisation'),
      );
    });

    test('session/JWT errors return session message', () {
      expect(
        ErrorMapper.toMessage(Exception('invalid jwt')),
        contains('Session expirée'),
      );
      expect(
        ErrorMapper.toMessage(Exception('401 Unauthorized')),
        contains('Session expirée'),
      );
    });

    test('unknown error returns generic message', () {
      expect(
        ErrorMapper.toMessage(Exception('SomeTechnicalError')),
        contains('erreur'),
      );
      expect(
        ErrorMapper.toMessage(Exception('SomeTechnicalError')),
        isNot(contains('SomeTechnicalError')),
      );
    });

    test('fallback is used for unknown error', () {
      expect(
        ErrorMapper.toMessage(Exception('X'), fallback: 'Erreur custom'),
        'Erreur custom',
      );
    });
  });

  group('ErrorMapper.isNetworkError', () {
    test('null returns false', () {
      expect(ErrorMapper.isNetworkError(null), false);
    });

    test('SocketException-like returns true', () {
      expect(ErrorMapper.isNetworkError(Exception('SocketException: ...')), true);
      expect(ErrorMapper.isNetworkError(TimeoutException('x')), true);
    });

    test('non-network returns false', () {
      expect(ErrorMapper.isNetworkError(Exception('Permission denied')), false);
      expect(ErrorMapper.isNetworkError(const UserFriendlyError('x')), false);
    });
  });
}
