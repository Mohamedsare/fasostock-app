import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/breakpoints.dart';
import '../../../core/config/env.dart';
import '../../../core/config/routes.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/profile.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/company_provider.dart';
import '../../../providers/permissions_provider.dart';

/// Page de connexion — même comportement que LoginPage (web).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

/// Numéro de support affiché lorsque le compte est bloqué (WhatsApp / appel).
const String _supportPhone = '+22664712044';
const String _supportPhoneE164 = '22664712044';

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _loading = false;
  bool _obscurePassword = true;

  /// Compte bloqué après 5 tentatives : on affiche l'écran avec contact WhatsApp.
  bool _isLocked = false;
  String _lockedEmail = '';

  /// Après un échec, nombre de tentatives restantes (affiché dans le message d'erreur).
  int? _remainingAttempts;
  String _loadingLabel = 'Connexion...';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkLockAndSubmit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() {
      _error = null;
      _remainingAttempts = null;
      _loading = true;
    });
    try {
      final status = await Supabase.instance.client.rpc(
        'get_login_lock_status',
        params: {'p_email': email},
      );
      final list = status as List;
      final locked = list.isNotEmpty && (list.first as Map)['locked'] == true;
      if (!mounted) return;
      if (locked) {
        setState(() {
          _isLocked = true;
          _lockedEmail = email;
          _loading = false;
        });
        return;
      }
      await _submit(email);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppErrorHandler.log(e);
      }
      await _submit(email);
    }
  }

  Future<void> _submit(String email) async {
    final auth = context.read<AuthProvider>();
    setState(() {
      _error = null;
      _remainingAttempts = null;
      _loading = true;
      _loadingLabel = 'Connexion...';
    });
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: _passwordController.text,
      );
      if (!mounted) return;
      final user = response.user;
      if (user == null) {
        setState(() {
          _error = 'Connexion échouée. Réessayez.';
          _loading = false;
        });
        return;
      }
      try {
        await Supabase.instance.client.rpc('reset_login_attempts');
      } catch (e, st) {
        AppErrorHandler.logWithContext(
          e,
          stackTrace: st,
          logSource: 'login_page',
          logContext: {'phase': 'reset_login_attempts', 'email': email},
        );
      }
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Profile? profileLoaded;
      try {
        profileLoaded = await auth.refreshProfile(fromLoginAttempt: true);
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = 'Profil introuvable ou erreur serveur.';
            _loading = false;
          });
        }
        return;
      }
      if (!mounted) return;
      if (profileLoaded != null && profileLoaded.isActive == false) {
        setState(() {
          _error = 'Compte désactivé. Contactez l\'administrateur.';
          _loading = false;
        });
        return;
      }
      if (auth.profile == null || !auth.isAuthenticated) {
        setState(() {
          _error =
              'Impossible de charger votre profil. Vérifiez la connexion et réessayez.';
          _loading = false;
        });
        return;
      }
      final dest = auth.isSuperAdmin ? AppRoutes.admin : AppRoutes.dashboard;
      if (!mounted || !context.mounted) return;
      final company = context.read<CompanyProvider>();
      final permissions = context.read<PermissionsProvider>();
      final userId = auth.user?.id;
      if (!auth.isSuperAdmin && userId != null && userId.isNotEmpty) {
        // En parallèle de la navigation : le tableau de bord relit Drift tout de suite ;
        // entreprises + permissions arrivent sans bloquer l’ouverture de l’app.
        unawaited(
          bootstrapCompanySessionAfterLogin(
            userId: userId,
            company: company,
            permissions: permissions,
          ),
        );
      }
      if (mounted) {
        setState(() => _loading = false);
      }
      Future<void>.delayed(const Duration(milliseconds: 50), () {
        if (!mounted || !context.mounted) return;
        try {
          context.go(dest);
        } catch (e, st) {
          AppErrorHandler.logWithContext(
            e,
            stackTrace: st,
            logSource: 'login_page',
            logContext: {'phase': 'post_login_navigation', 'destination': dest},
          );
        }
      });
    } on AuthException catch (e) {
      if (mounted) {
        try {
          await Supabase.instance.client.rpc(
            'record_failed_login',
            params: {'p_email': email},
          );
          final status = await Supabase.instance.client.rpc(
            'get_login_lock_status',
            params: {'p_email': email},
          );
          final list = status as List;
          final locked =
              list.isNotEmpty && (list.first as Map)['locked'] == true;
          final int failed = list.isNotEmpty
              ? ((list.first as Map)['failed_attempts'] as num?)?.toInt() ?? 0
              : 0;
          final int remaining = (5 - failed).clamp(0, 5);
          setState(() {
            _error = locked
                ? 'Compte bloqué après 5 tentatives. Contactez le support pour être débloqué.'
                : "${AppErrorHandler.toUserMessage(e)} ($remaining tentative${remaining > 1 ? 's' : ''} restante${remaining > 1 ? 's' : ''})";
            _remainingAttempts = remaining;
            if (locked) {
              _isLocked = true;
              _lockedEmail = email;
            }
            _loading = false;
          });
        } catch (e2) {
          if (mounted) {
            AppErrorHandler.log(e2);
            setState(() {
              _error = AppErrorHandler.toUserMessage(e);
              _loading = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        AppErrorHandler.log(e);
        setState(() {
          _error = AppErrorHandler.toUserMessage(e);
          _loading = false;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildBlockedContent(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = Breakpoints.isMobile(MediaQuery.sizeOf(context).width);
    const whatsAppGreen = Color(0xFF25D366);
    final padH = isMobile ? AppTheme.spaceXlM : AppTheme.spaceXl;
    final padV = isMobile ? AppTheme.spaceXxlM : AppTheme.spaceXxl;
    final padCard = isMobile ? AppTheme.spaceXlM : AppTheme.spaceXl;
    final iconSize = isMobile ? 40.0 : 56.0;
    final spaceL = isMobile ? AppTheme.spaceLgM : AppTheme.spaceLg;
    final spaceM = isMobile ? AppTheme.spaceMdM : AppTheme.spaceMd;
    final spaceS = isMobile ? AppTheme.spaceSmM : AppTheme.spaceSm;
    final radius = isMobile ? AppTheme.radiusXlM : AppTheme.radiusXl;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 420),
        child: Container(
          padding: EdgeInsets.all(padCard),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: isMobile ? 12 : 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.lock_rounded,
                size: iconSize,
                color: colorScheme.error,
              ),
              SizedBox(height: spaceL),
              Text(
                'Compte temporairement bloqué',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spaceS),
              if (_lockedEmail.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: spaceS),
                  child: Text(
                    _lockedEmail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              Text(
                'Après 5 tentatives de connexion incorrectes, votre accès a été verrouillé pour des raisons de sécurité. Le super administrateur peut débloquer votre compte.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spaceM),
              Text(
                'Contactez le support pour être débloqué :',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spaceL),
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    final uri = Uri.parse('https://wa.me/$_supportPhoneE164');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } else {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Impossible d\'ouvrir WhatsApp'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (!context.mounted) return;
                    AppErrorHandler.log(e);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppErrorHandler.toUserMessage(e))),
                    );
                  }
                },
                icon: SvgPicture.asset(
                  'assets/whatsApp.svg',
                  width: isMobile ? 20 : 24,
                  height: isMobile ? 20 : 24,
                  fit: BoxFit.contain,
                ),
                label: Text('WhatsApp : $_supportPhone'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: whatsAppGreen,
                  side: BorderSide(color: whatsAppGreen),
                  padding: EdgeInsets.symmetric(vertical: isMobile ? 10 : 14),
                ),
              ),
              SizedBox(height: spaceM),
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    final uri = Uri.parse('tel:$_supportPhone');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } else {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Impossible d\'ouvrir l\'application téléphone',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (!context.mounted) return;
                    AppErrorHandler.log(e);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppErrorHandler.toUserMessage(e))),
                    );
                  }
                },
                icon: Icon(
                  Icons.phone_rounded,
                  color: colorScheme.primary,
                  size: isMobile ? 18 : 22,
                ),
                label: Text('Appeler $_supportPhone'),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: isMobile ? 10 : 14),
                ),
              ),
              SizedBox(height: spaceL),
              TextButton(
                onPressed: () => setState(() {
                  _isLocked = false;
                  _lockedEmail = '';
                }),
                child: const Text('Retour à la connexion'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = Breakpoints.isMobile(MediaQuery.sizeOf(context).width);
    final padH = isMobile ? AppTheme.spaceXlM : AppTheme.spaceXl;
    final padV = isMobile ? AppTheme.spaceXxlM : AppTheme.spaceXxl;
    final padCard = isMobile ? AppTheme.spaceXlM : AppTheme.spaceXl;
    final spaceL = isMobile ? AppTheme.spaceLgM : AppTheme.spaceLg;
    final spaceM = isMobile ? AppTheme.spaceMdM : AppTheme.spaceMd;
    final spaceS = isMobile ? AppTheme.spaceSmM : AppTheme.spaceSm;
    final spaceX = isMobile ? AppTheme.spaceXlM : AppTheme.spaceXl;
    final radius = isMobile ? AppTheme.radiusXlM : AppTheme.radiusXl;
    final logoSize = isMobile ? 56.0 : 80.0;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: _isLocked
              ? _buildBlockedContent(context)
              : SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: padH,
                    vertical: padV,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isMobile ? double.infinity : 420,
                    ),
                    child: Container(
                      padding: EdgeInsets.all(padCard),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(radius),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: isMobile ? 12 : 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Center(
                              child: Image.asset(
                                'assets/fs.png',
                                height: logoSize,
                                width: logoSize,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                            SizedBox(height: spaceL),
                            Text(
                              'Connexion à votre espace',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: spaceX),
                            if (!Env.hasValidSupabase)
                              Padding(
                                padding: EdgeInsets.only(bottom: spaceL),
                                child: Text(
                                  'Config Supabase manquante. Relancez l\'app : un écran vous permettra de saisir l\'URL et la clé Supabase (Dashboard → Settings → API).',
                                  style: TextStyle(
                                    color: colorScheme.error,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            if (_remainingAttempts != null &&
                                _remainingAttempts! < 5)
                              Padding(
                                padding: EdgeInsets.only(bottom: spaceS),
                                child: Text(
                                  'Tentatives restantes : $_remainingAttempts',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            if (_error != null) ...[
                              Container(
                                padding: EdgeInsets.all(
                                  isMobile
                                      ? AppTheme.spaceMdM
                                      : AppTheme.spaceMd,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.errorContainer.withValues(
                                    alpha: 0.6,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    isMobile
                                        ? AppTheme.radiusMdM
                                        : AppTheme.radiusMd,
                                  ),
                                  border: Border.all(
                                    color: colorScheme.error.withValues(
                                      alpha: 0.2,
                                    ),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline_rounded,
                                      color: colorScheme.error,
                                      size: isMobile ? 18 : 22,
                                    ),
                                    SizedBox(width: spaceM),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onErrorContainer,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: spaceL),
                            ],
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                hintText: 'vous@exemple.com',
                              ),
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Email requis';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: spaceL),
                            TextFormField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: 'Mot de passe',
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                  tooltip: _obscurePassword
                                      ? 'Afficher le mot de passe'
                                      : 'Masquer le mot de passe',
                                ),
                              ),
                              obscureText: _obscurePassword,
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Mot de passe requis';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: spaceX),
                            FilledButton(
                              onPressed: _loading
                                  ? null
                                  : () {
                                      if (_formKey.currentState?.validate() ??
                                          false) {
                                        _checkLockAndSubmit();
                                      }
                                    },
                              child: _loading
                                  ? SizedBox(
                                      height: isMobile ? 20 : 24,
                                      width: isMobile ? 20 : 24,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Se connecter'),
                            ),
                            if (_loading) ...[
                              SizedBox(height: spaceS),
                              Text(
                                _loadingLabel,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            SizedBox(height: spaceL),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () =>
                                        context.push(AppRoutes.forgotPassword),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 8,
                                      ),
                                    ),
                                    child: const Text(
                                      'Mot de passe oublié ?',
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: TextButton(
                                    onPressed: () =>
                                        context.push(AppRoutes.register),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 8,
                                      ),
                                    ),
                                    child: const Text(
                                      'Créer un compte',
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Après connexion : charge entreprises + permissions **sans bloquer** la navigation.
/// Le tableau de bord et [OfflineSyncWrapper] complètent le contexte si besoin.
Future<void> bootstrapCompanySessionAfterLogin({
  required String userId,
  required CompanyProvider company,
  required PermissionsProvider permissions,
}) async {
  Future<void> safe(Future<void> Function() fn) async {
    try {
      await fn().timeout(const Duration(milliseconds: 1800));
    } catch (e, st) {
      AppErrorHandler.logWithContext(
        e,
        stackTrace: st,
        logSource: 'login_page',
        logContext: const {'phase': 'bootstrap_company_session_after_login'},
      );
    }
  }

  await safe(() async {
    if (company.companies.isEmpty || company.currentCompanyId == null) {
      await company.loadCompanies(userId);
    } else {
      await company.refreshStores();
    }
  });

  await safe(() async {
    final cid = company.currentCompanyId;
    if (cid != null && cid.isNotEmpty) {
      await permissions.load(cid);
    }
  });
}
