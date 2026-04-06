import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/permissions.dart';
import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../data/models/sale.dart';
import '../../../../data/repositories/credit_sync_facade.dart';
import '../../../../providers/permissions_provider.dart';
import '../../../../shared/utils/format_currency.dart';

import '../credit_math.dart';
import 'credit_pay_dialog.dart';

String _paymentMethodLabel(PaymentMethod m) {
  switch (m) {
    case PaymentMethod.cash:
      return 'Espèces';
    case PaymentMethod.mobile_money:
      return 'Mobile money';
    case PaymentMethod.card:
      return 'Carte';
    case PaymentMethod.transfer:
      return 'Virement';
    case PaymentMethod.other:
      return 'Autre';
  }
}

/// Panneau latéral — aligné `CreditDetailPanel` (web).
class CreditDetailSheet extends StatefulWidget {
  const CreditDetailSheet({
    super.key,
    required this.saleId,
    required this.companyId,
    required this.credit,
    required this.onClose,
    required this.onRefreshList,
  });

  final String saleId;
  final String companyId;
  final CreditSyncFacade credit;
  final VoidCallback onClose;
  final VoidCallback onRefreshList;

  @override
  State<CreditDetailSheet> createState() => _CreditDetailSheetState();
}

class _CreditDetailSheetState extends State<CreditDetailSheet> {
  Sale? _sale;
  bool _loading = true;
  String? _loadError;
  final _dueCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _metaBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _dueCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final s = await widget.credit.fetchCreditSaleDetail(widget.saleId, widget.companyId);
      if (!mounted) return;
      if (s == null) {
        setState(() {
          _sale = null;
          _loading = false;
          _loadError = 'Vente introuvable.';
        });
        return;
      }
      final due = effectiveDueAt(s);
      _dueCtrl.text = DateFormat('yyyy-MM-dd').format(due);
      _noteCtrl.text = s.creditInternalNote ?? '';
      setState(() {
        _sale = s;
        _loading = false;
      });
    } catch (e, st) {
      AppErrorHandler.log(e, st);
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = AppErrorHandler.toUserMessage(e, fallback: 'Chargement impossible.');
        });
      }
    }
  }

  Future<void> _saveMeta() async {
    final perm = context.read<PermissionsProvider>();
    if (!perm.hasPermission(Permissions.salesUpdate)) return;
    final ymd = _dueCtrl.text.trim();
    String? iso;
    if (ymd.isNotEmpty) {
      final d = DateTime.tryParse('${ymd}T12:00:00');
      iso = d?.toUtc().toIso8601String();
    }
    setState(() => _metaBusy = true);
    try {
      await widget.credit.updateSaleCreditMeta(
        saleId: widget.saleId,
        creditDueAtIso: iso,
        creditInternalNote: _noteCtrl.text,
      );
      if (!mounted) return;
      AppToast.success(context, 'Échéance / notes enregistrées.');
      widget.onRefreshList();
      await _load();
    } catch (e, st) {
      AppErrorHandler.log(e, st);
      if (mounted) AppToast.error(context, AppErrorHandler.toUserMessage(e, fallback: 'Échec.'));
    } finally {
      if (mounted) setState(() => _metaBusy = false);
    }
  }

  Future<void> _openPay() async {
    final s = _sale;
    if (s == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => CreditPayDialog(
        sale: s,
        credit: widget.credit,
        onSuccess: widget.onRefreshList,
      ),
    );
    if (ok == true && mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final perm = context.watch<PermissionsProvider>();
    final canPay = perm.hasPermission(Permissions.salesUpdate);

    final header = Material(
      elevation: 0,
      color: theme.colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
          child: Row(
            children: [
              Expanded(
                child: Text('Détail crédit', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: widget.onClose),
            ],
          ),
        ),
      ),
    );

    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          header,
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_loadError!)))
                : _sale == null
                ? const SizedBox.shrink()
                : _buildBody(context, _sale!, canPay, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, Sale sale, bool canPay, ThemeData theme) {
    final rem = remainingTotal(sale);
    final pays = [...(sale.salePayments ?? <SalePayment>[])];
    pays.sort((a, b) => (a.createdAt ?? '').compareTo(b.createdAt ?? ''));

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppTheme.spaceMd, 0, AppTheme.spaceMd, AppTheme.spaceXl),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sale.saleNumber, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(sale.customer?.name ?? '—', style: theme.textTheme.bodyMedium),
                if (sale.customer?.phone != null && sale.customer!.phone!.isNotEmpty)
                  InkWell(
                    onTap: () async {
                      final raw = sale.customer!.phone!.replaceAll(RegExp(r'\s'), '');
                      final uri = Uri.parse('tel:$raw');
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.phone, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(sale.customer!.phone!, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                if (sale.customer?.address != null && sale.customer!.address!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(sale.customer!.address!, style: theme.textTheme.bodySmall),
                  ),
                const SizedBox(height: 8),
                Text(
                  '${DateFormat('dd MMM yyyy HH:mm', 'fr_FR').format(DateTime.tryParse(sale.createdAt)?.toLocal() ?? DateTime.now())} · ${sale.store?.name ?? '—'} · ${sale.createdByLabel ?? '—'}',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spaceMd),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Montants', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _kv(theme, 'Total TTC', formatCurrency(sale.total)),
                _kv(theme, 'Encaissé', formatCurrency(paidRealized(sale)), valueColor: Colors.green.shade700),
                _kv(theme, 'Reste', formatCurrency(rem), valueBold: true),
                const SizedBox(height: 8),
                Text(
                  'Statut : ${creditStatusLabel(creditLineStatus(sale))}${daysOverdue(sale) > 0 ? ' · Retard ${daysOverdue(sale)} j' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spaceMd),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Échéance & notes internes', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _dueCtrl,
                  decoration: const InputDecoration(labelText: 'Date d\'échéance', border: OutlineInputBorder()),
                  readOnly: true,
                  onTap: () async {
                    final initial = DateTime.tryParse('${_dueCtrl.text}T12:00:00');
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initial ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      locale: const Locale('fr', 'FR'),
                    );
                    if (picked != null && mounted) {
                      _dueCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
                      setState(() {});
                    }
                  },
                ),
                const SizedBox(height: AppTheme.spaceMd),
                TextField(
                  controller: _noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes (relance, promesse…)',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: AppTheme.spaceSm),
                FilledButton.tonal(
                  onPressed: (!canPay || _metaBusy) ? null : _saveMeta,
                  child: _metaBusy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Enregistrer échéance / notes'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spaceMd),
        Text('Historique des paiements', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...pays.map(
          (p) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              dense: true,
              title: Text(
                '${DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(p.createdAt != null ? DateTime.tryParse(p.createdAt!)?.toLocal() ?? DateTime.now() : DateTime.now())} — ${_paymentMethodLabel(p.method)}',
                style: theme.textTheme.bodySmall,
              ),
              trailing: Text(formatCurrency(p.amount), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spaceMd),
        Text('Articles', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...(sale.saleItems ?? []).map(
          (it) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text(it.product?.name ?? it.productId, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
                Text('×${it.quantity} ${formatCurrency(it.total)}', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
        if (canPay && rem > creditAmountEps) ...[
          const SizedBox(height: AppTheme.spaceLg),
          FilledButton(onPressed: _openPay, child: const Text('Enregistrer un paiement')),
        ],
      ],
    );
  }

  Widget _kv(ThemeData theme, String k, String v, {Color? valueColor, bool valueBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(k, style: theme.textTheme.bodySmall)),
          Text(
            v,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: valueBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
