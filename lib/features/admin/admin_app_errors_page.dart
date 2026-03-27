import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/utils/app_toast.dart';
import '../../data/models/admin_models.dart';
import '../../data/repositories/admin_repository.dart';
import 'shared/admin_ui.dart';

/// Super admin : visualise les erreurs applicatives remontées par Flutter.
class AdminAppErrorsPage extends StatefulWidget {
  const AdminAppErrorsPage({super.key});

  @override
  State<AdminAppErrorsPage> createState() => _AdminAppErrorsPageState();
}

class _AdminAppErrorsPageState extends State<AdminAppErrorsPage> {
  final AdminRepository _repo = AdminRepository();
  static const _resolvedUntilPrefKey = 'admin_app_errors_resolved_until';

  List<AdminAppErrorLog> _entries = [];
  List<AdminCompany> _companies = [];
  List<AdminUser> _users = [];
  String? _selectedCompanyId;
  String? _selectedUserId;
  String? _selectedLevel;
  String? _selectedSource;
  /// Filtre `web` / `flutter` (colonne `client_kind`).
  String? _selectedClientKind;
  DateTime? _fromDate;
  DateTime? _toDate;
  DateTime? _resolvedUntil;
  bool _loading = true;
  bool _prefLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadResolvedUntil();
    _loadCompanies();
    _loadUsers();
    _load();
  }

  Future<void> _loadResolvedUntil() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_resolvedUntilPrefKey);
      DateTime? parsed;
      if (raw != null && raw.trim().isNotEmpty) {
        parsed = DateTime.tryParse(raw)?.toUtc();
      }
      if (mounted) {
        setState(() {
          _resolvedUntil = parsed;
          _prefLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _prefLoading = false);
    }
  }

  Future<void> _setResolvedUntilNow() async {
    final now = DateTime.now().toUtc();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_resolvedUntilPrefKey, now.toIso8601String());
      if (mounted) {
        setState(() => _resolvedUntil = now);
        AppToast.success(context, 'Repère enregistré. Les nouvelles erreurs seront marquées.');
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.error(
        context,
        AppErrorHandler.toUserMessage(e, fallback: 'Impossible d\'enregistrer le repère.'),
      );
    }
  }

  Future<void> _clearResolvedUntil() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_resolvedUntilPrefKey);
      if (mounted) {
        setState(() => _resolvedUntil = null);
        AppToast.success(context, 'Repère réinitialisé.');
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.error(
        context,
        AppErrorHandler.toUserMessage(e, fallback: 'Impossible de réinitialiser le repère.'),
      );
    }
  }

  Future<void> _loadCompanies() async {
    try {
      final list = await _repo.listCompanies();
      if (mounted) setState(() => _companies = list);
    } catch (_) {}
  }

  Future<void> _loadUsers() async {
    try {
      final list = await _repo.listUsers();
      if (mounted) setState(() => _users = list);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.listAppErrors(
        companyId: _selectedCompanyId,
        userId: _selectedUserId,
        source: _selectedSource,
        level: _selectedLevel,
        clientKind: _selectedClientKind,
        fromDate: _fromDate == null
            ? null
            : DateFormat('yyyy-MM-dd').format(_fromDate!),
        toDate: _toDate == null ? null : DateFormat('yyyy-MM-dd').format(_toDate!),
        limit: 200,
      );
      if (mounted) {
        setState(() {
          _entries = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppErrorHandler.toUserMessage(
          e,
          fallback: 'Impossible de charger les erreurs applicatives.',
        );
      });
    }
  }

  String _userLabel(String? id) {
    if (id == null || id.isEmpty) return '—';
    for (final u in _users) {
      if (u.id == id) {
        if (u.fullName != null && u.fullName!.trim().isNotEmpty) {
          return u.fullName!;
        }
        return u.email ?? id;
      }
    }
    return id;
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = isFrom
        ? (_fromDate ?? now)
        : (_toDate ?? _fromDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
      } else {
        _toDate = picked;
      }
    });
  }

  Future<void> _copyStackTrace(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    AppToast.success(context, 'Stack trace copiée.');
  }

  String _companyName(String? id) {
    if (id == null) return '—';
    for (final c in _companies) {
      if (c.id == id) return c.name;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final padding = isWide ? 32.0 : 20.0;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss', 'fr_FR');

    return Container(
      color: AdminPalette.surfaceAlt,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AdminPageHeader(
              title: 'Erreurs App',
              description:
                  'Journal des erreurs remontées automatiquement depuis les applications clientes.',
            ),
            const SizedBox(height: 24),
            AdminCard(
              padding: const EdgeInsets.all(16),
              child: _prefLoading
                  ? const SizedBox(
                      height: 28,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _resolvedUntil == null
                              ? 'Repère de correction: non défini'
                              : 'Repère de correction: ${dateFormat.format(_resolvedUntil!.toLocal())}',
                          style: const TextStyle(
                            color: AdminPalette.title,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: _setResolvedUntilNow,
                              style: FilledButton.styleFrom(
                                backgroundColor: AdminPalette.accent,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                              label: const Text('Marquer comme corrigé jusqu\'à maintenant'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _resolvedUntil == null ? null : _clearResolvedUntil,
                              icon: const Icon(Icons.restart_alt_rounded, size: 18),
                              label: const Text('Réinitialiser le repère'),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            AdminCard(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final useRow = constraints.maxWidth > 760;
                  final companyDd = SizedBox(
                    width: useRow ? 260 : double.infinity,
                    child: DropdownButtonFormField<String?>(
                      value: _selectedCompanyId,
                      isExpanded: true,
                      decoration: adminInputDecoration(labelText: 'Entreprise'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Toutes')),
                        ..._companies.map(
                          (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                        ),
                      ],
                      onChanged: (v) => setState(() => _selectedCompanyId = v),
                    ),
                  );
                  final userDd = SizedBox(
                    width: useRow ? 260 : double.infinity,
                    child: DropdownButtonFormField<String?>(
                      value: _selectedUserId,
                      isExpanded: true,
                      decoration: adminInputDecoration(labelText: 'Utilisateur'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Tous')),
                        ..._users.map(
                          (u) => DropdownMenuItem(
                            value: u.id,
                            child: Text(
                              u.fullName?.trim().isNotEmpty == true
                                  ? u.fullName!
                                  : (u.email ?? u.id),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _selectedUserId = v),
                    ),
                  );
                  final levelDd = SizedBox(
                    width: useRow ? 180 : double.infinity,
                    child: DropdownButtonFormField<String?>(
                      value: _selectedLevel,
                      isExpanded: true,
                      decoration: adminInputDecoration(labelText: 'Niveau'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Tous')),
                        DropdownMenuItem(value: 'error', child: Text('error')),
                        DropdownMenuItem(value: 'warning', child: Text('warning')),
                        DropdownMenuItem(value: 'info', child: Text('info')),
                      ],
                      onChanged: (v) => setState(() => _selectedLevel = v),
                    ),
                  );
                  final sourceDd = SizedBox(
                    width: useRow ? 220 : double.infinity,
                    child: DropdownButtonFormField<String?>(
                      value: _selectedSource,
                      isExpanded: true,
                      decoration: adminInputDecoration(labelText: 'Source'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Toutes')),
                        DropdownMenuItem(
                          value: 'app_error_handler',
                          child: Text('app_error_handler'),
                        ),
                        DropdownMenuItem(value: 'app', child: Text('app')),
                      ],
                      onChanged: (v) => setState(() => _selectedSource = v),
                    ),
                  );
                  final clientKindDd = SizedBox(
                    width: useRow ? 220 : double.infinity,
                    child: DropdownButtonFormField<String?>(
                      value: _selectedClientKind,
                      isExpanded: true,
                      decoration: adminInputDecoration(labelText: 'App'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Toutes')),
                        DropdownMenuItem(value: 'web', child: Text('Web (navigateur)')),
                        DropdownMenuItem(value: 'flutter', child: Text('Flutter')),
                      ],
                      onChanged: (v) => setState(() => _selectedClientKind = v),
                    ),
                  );
                  final dateRange = Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDate(isFrom: true),
                          icon: const Icon(Icons.date_range_rounded),
                          label: Text(
                            _fromDate == null
                                ? 'Du'
                                : DateFormat('dd/MM/yyyy').format(_fromDate!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDate(isFrom: false),
                          icon: const Icon(Icons.date_range_rounded),
                          label: Text(
                            _toDate == null
                                ? 'Au'
                                : DateFormat('dd/MM/yyyy').format(_toDate!),
                          ),
                        ),
                      ),
                    ],
                  );
                  final actions = Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _load,
                          style: FilledButton.styleFrom(
                            backgroundColor: AdminPalette.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 20,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.filter_alt_rounded, size: 20),
                          label: const Text('Appliquer'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _loading
                            ? null
                            : () {
                                setState(() {
                                  _selectedCompanyId = null;
                                  _selectedUserId = null;
                                  _selectedLevel = null;
                                  _selectedSource = null;
                                  _selectedClientKind = null;
                                  _fromDate = null;
                                  _toDate = null;
                                });
                                _load();
                              },
                        child: const Text('Réinitialiser'),
                      ),
                    ],
                  );
                  final refreshButton = FilledButton.icon(
                    onPressed: _loading ? null : _load,
                    style: FilledButton.styleFrom(
                      backgroundColor: AdminPalette.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text('Actualiser'),
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (useRow)
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [companyDd, userDd, levelDd, sourceDd, clientKindDd],
                        )
                      else ...[
                        companyDd,
                        const SizedBox(height: 10),
                        userDd,
                        const SizedBox(height: 10),
                        levelDd,
                        const SizedBox(height: 10),
                        sourceDd,
                        const SizedBox(height: 10),
                        clientKindDd,
                      ],
                      const SizedBox(height: 10),
                      dateRange,
                      const SizedBox(height: 10),
                      actions,
                      const SizedBox(height: 10),
                      refreshButton,
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              AdminCard(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_loading)
              const AdminCard(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_entries.isEmpty)
              AdminCard(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'Aucune erreur remontée.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: AdminPalette.subtitle),
                  ),
                ),
              )
            else
              AdminCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: _entries.map((e) {
                    final createdAt = DateTime.tryParse(e.createdAt)?.toUtc();
                    final isNewSinceCutoff = _resolvedUntil != null &&
                        createdAt != null &&
                        createdAt.isAfter(_resolvedUntil!);
                    final levelColor = (e.level == 'warning')
                        ? Colors.orange
                        : Theme.of(context).colorScheme.error;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AdminPalette.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.error_outline_rounded, color: levelColor, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  e.message,
                                  style: const TextStyle(
                                    color: AdminPalette.title,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (e.clientKind != null && e.clientKind!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Chip(
                                    label: Text(
                                      e.clientKind == 'web' ? 'WEB' : 'FLUTTER',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10,
                                      ),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: e.clientKind == 'web'
                                        ? Colors.green.shade100
                                        : Colors.lightBlue.shade100,
                                  ),
                                ),
                              Chip(
                                label: Text(
                                  isNewSinceCutoff ? 'NOUVEAU' : 'ANCIEN',
                                  style: TextStyle(
                                    color: isNewSinceCutoff
                                        ? Colors.white
                                        : AdminPalette.title,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                                backgroundColor: isNewSinceCutoff
                                    ? Theme.of(context).colorScheme.error
                                    : Colors.grey.shade300,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${dateFormat.format(DateTime.parse(e.createdAt).toLocal())} • ${_companyName(e.companyId)}',
                            style: const TextStyle(color: AdminPalette.subtitle, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'source: ${e.source} • niveau: ${e.level} • app: ${e.clientKind ?? '—'} • user: ${e.userId ?? '—'} • platform: ${e.platform ?? '—'}',
                            style: const TextStyle(color: AdminPalette.subtitle, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'utilisateur: ${_userLabel(e.userId)}',
                            style: const TextStyle(color: AdminPalette.subtitle, fontSize: 12),
                          ),
                          if (e.errorType != null && e.errorType!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'type: ${e.errorType}',
                              style: const TextStyle(
                                color: AdminPalette.subtitle,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          if (e.stackTrace != null && e.stackTrace!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: () => _copyStackTrace(e.stackTrace!),
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                label: const Text('Copier stack trace'),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              e.stackTrace!,
                              style: const TextStyle(
                                color: AdminPalette.subtitle,
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

