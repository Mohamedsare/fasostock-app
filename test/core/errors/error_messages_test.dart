import 'package:flutter_test/flutter_test.dart';

import 'package:fasostock/core/errors/error_messages.dart';

void main() {
  group('ErrorMessages.translate', () {
    test('null or empty returns generic', () {
      expect(ErrorMessages.translate(null), ErrorMessages.generic);
      expect(ErrorMessages.translate(''), ErrorMessages.generic);
    });

    test('auth messages are translated', () {
      expect(
        ErrorMessages.translate('Invalid login credentials'),
        'Identifiants incorrects.',
      );
      expect(
        ErrorMessages.translate('Email not confirmed'),
        'Adresse email non confirmée.',
      );
      expect(
        ErrorMessages.translate('Session expired'),
        'Session expirée. Reconnectez-vous.',
      );
    });

    test('api messages are translated', () {
      expect(
        ErrorMessages.translate('new row violates row-level security policy'),
        "Vous n'avez pas l'autorisation d'effectuer cette action.",
      );
      expect(
        ErrorMessages.translate('JWT expired'),
        'Session expirée. Reconnectez-vous.',
      );
      expect(
        ErrorMessages.translate('Permission denied'),
        "Accès refusé : vous n'avez pas l'autorisation.",
      );
    });

    test('unknown technical message returns generic', () {
      expect(
        ErrorMessages.translate('SomeException: foo'),
        ErrorMessages.generic,
      );
    });
  });
}
