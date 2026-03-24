/// Traduction des messages d'erreur (auth Supabase, API) en français —
/// équivalent de src/lib/errorMessages.ts.
class ErrorMessages {
  ErrorMessages._();

  static const _authMessages = <String, String>{
    'Invalid login credentials': 'Identifiants incorrects.',
    'invalid_login_credentials': 'Identifiants incorrects.',
    'invalid_credentials': 'Identifiants incorrects.',
    'Invalid credentials': 'Identifiants incorrects.',
    'Email not confirmed': 'Adresse email non confirmée.',
    'User already registered': 'Un compte existe déjà avec cet email.',
    'Signup disabled': 'Inscription désactivée.',
    'Sign up disabled': 'Inscription désactivée.',
    'Password should be at least 6 characters': 'Le mot de passe doit contenir au moins 6 caractères.',
    'New password should be different from the old password':
        "Le nouveau mot de passe doit être différent de l'ancien.",
    'Token has expired or is invalid': 'Le lien a expiré ou est invalide. Demandez un nouveau lien.',
    'Password recovery requires a valid email': 'Veuillez entrer une adresse email valide.',
    'User not found': 'Utilisateur introuvable.',
    'User already exists': 'Un compte existe déjà avec cet email.',
    'A user with this email already exists': 'Un compte existe déjà avec cet email.',
    'Email rate limit exceeded': 'Trop de tentatives. Réessayez plus tard.',
    'Forbidden': 'Accès refusé.',
    'Invalid request': 'Requête invalide.',
    'Session expired': 'Session expirée. Reconnectez-vous.',
    'Unable to validate email address: invalid format': 'Adresse email invalide.',
    'Signup requires a valid password': 'Le mot de passe doit contenir au moins 6 caractères.',
  };

  static const _apiMessages = <String, String>{
    'new row violates row-level security policy': "Vous n'avez pas les droits pour effectuer cette action.",
    'duplicate key value violates unique constraint': 'Cette valeur existe déjà.',
    'foreign key violation': 'Référence invalide.',
    'JWT expired': 'Session expirée. Reconnectez-vous.',
    'Invalid JWT': 'Session expirée. Reconnectez-vous.',
    'Permission denied': 'Accès refusé.',
    'Le rôle super admin ne peut pas être attribué': 'Ce type d\'utilisateur ne peut pas être créé ici.',
    'Rôle invalide ou inconnu': 'Type d\'utilisateur inconnu. Réessayez.',
    'Session absente': 'Session expirée. Déconnectez-vous puis reconnectez-vous.',
    // Gestion des droits (RPC owner)
    'Seul le propriétaire peut consulter les droits': "Seul le propriétaire peut consulter les droits d'un utilisateur.",
    'Seul le propriétaire peut modifier les droits': "Seul le propriétaire peut modifier les droits d'un utilisateur.",
    'Vous ne pouvez pas modifier vos propres droits': "Vous ne pouvez pas modifier vos propres droits ici.",
    "Permission inconnue": "Droit inconnu. Veuillez réessayer.",
    "n'est pas membre de cette entreprise": "Cet utilisateur n'est pas membre de cette entreprise.",
    'Membre introuvable': 'Membre introuvable.',
  };

  /// Message générique — aucun détail technique ne doit être affiché à l'utilisateur.
  static const String generic = "Une erreur s'est produite.";

  /// Retourne un message utilisateur sûr. Ne retourne jamais de message technique (API, code, stack).
  static String translate(String? message, {String? code}) {
    if (message == null || message.isEmpty) return generic;
    final normalized = message.trim();
    if (code != null && _authMessages.containsKey(code)) return _authMessages[code]!;
    if (_authMessages.containsKey(normalized)) return _authMessages[normalized]!;
    final lower = normalized.toLowerCase();
    for (final e in _authMessages.entries) {
      if (lower.contains(e.key.toLowerCase())) return e.value;
    }
    for (final e in _apiMessages.entries) {
      if (lower.contains(e.key.toLowerCase())) return e.value;
    }
    // Messages courts et déjà en français (sans code technique) : on les garde
    final looksFrench = RegExp(r'[\u00C0-\u024F]', caseSensitive: false).hasMatch(normalized);
    final looksTechnical = normalized.contains('Exception') || normalized.contains('Error') ||
        RegExp(r'^[A-Za-z_]+\.(dart|ts|js)').hasMatch(normalized) || normalized.length > 120;
    if (looksFrench && !looksTechnical && normalized.length <= 100) return normalized;
    return generic;
  }
}
