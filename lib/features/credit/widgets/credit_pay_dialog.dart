import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../data/models/append_payment_result.dart';
import '../../../../data/models/sale.dart';
import '../../../../data/repositories/credit_sync_facade.dart';
import '../../../../shared/utils/format_currency.dart';
import '../credit_math.dart';

/// Modes affichés — alignés `CreditRecordPaymentDialog` (web).
enum _PayModeUi {
  cash,
  orangeMoney,
  moovMoney,
  wave,
  card,
  transfer,
}

extension on _PayModeUi {
  bool get isCash => this == _PayModeUi.cash;

  PaymentMethod get backendMethod => switch (this) {
        _PayModeUi.cash => PaymentMethod.cash,
        _PayModeUi.orangeMoney ||
        _PayModeUi.moovMoney ||
        _PayModeUi.wave =>
          PaymentMethod.mobile_money,
        _PayModeUi.card => PaymentMethod.card,
        _PayModeUi.transfer => PaymentMethod.transfer,
      };

  String? get mobileProviderLabel => switch (this) {
        _PayModeUi.orangeMoney => 'Orange money',
        _PayModeUi.moovMoney => 'Moov money',
        _PayModeUi.wave => 'Wave',
        _ => null,
      };
}

/// Enregistrement d'un paiement — aligné `CreditQuickPayDialog` / `CreditRecordPaymentDialog` (web).
class CreditPayDialog extends StatefulWidget {
  const CreditPayDialog({
    super.key,
    required this.sale,
    required this.credit,
    this.onSuccess,
  });

  final Sale sale;
  final CreditSyncFacade credit;
  final VoidCallback? onSuccess;

  @override
  State<CreditPayDialog> createState() => _CreditPayDialogState();
}

class CreditPaymentReceiptPayload {
  const CreditPaymentReceiptPayload({
    required this.paymentId,
    required this.issuedAt,
    required this.storeId,
    required this.storePrimaryColor,
    required this.saleNumber,
    required this.storeName,
    required this.customerName,
    required this.customerPhone,
    required this.creditTitle,
    required this.paymentMethodCode,
    required this.paymentMethodLabel,
    required this.paymentReference,
    required this.amountPaid,
    required this.amountTendered,
    required this.changeDue,
    required this.previousBalance,
    required this.newBalance,
    required this.settled,
  });

  /// Identifiant serveur `sale_payments.id` (reçu dérivé de façon déterministe).
  final String paymentId;
  final DateTime issuedAt;
  final String storeId;

  /// `stores.primary_color` tel que renvoyé par l’API (évite une liste `CompanyProvider` obsolète).
  final String? storePrimaryColor;

  final String saleNumber;
  final String storeName;
  final String customerName;
  final String? customerPhone;
  final String creditTitle;
  final String paymentMethodCode;
  final String paymentMethodLabel;
  final String? paymentReference;
  final double amountPaid;
  final double? amountTendered;
  final double? changeDue;
  final double previousBalance;
  final double newBalance;
  final bool settled;
}

class _CreditPayDialogState extends State<CreditPayDialog> {
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  _PayModeUi _mode = _PayModeUi.cash;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  double get _restInitial => remainingTotal(widget.sale);

  static double _roundMoney(double x) => (x * 100).round() / 100.0;

  static bool _isOverpayError(Object e) => RegExp(
        r'montant supérieur au reste à payer',
        caseSensitive: false,
      ).hasMatch(e.toString());

  double get _tendered {
    final v = double.tryParse(_amountCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    return v < 0 ? 0 : v;
  }

  Future<void> _submit() async {
    final tenderedRaw = _roundMoney(_tendered);
    if (tenderedRaw <= creditAmountEps) {
      AppToast.error(context, 'Indiquez un montant valide.');
      return;
    }

    setState(() => _busy = true);
    try {
      final fresh = await widget.credit.fetchCreditSaleDetail(
        widget.sale.id,
        widget.sale.companyId,
      );
      if (fresh == null) {
        if (mounted) {
          AppToast.error(context, 'Impossible de charger la vente. Réessayez.');
        }
        return;
      }
      final rest = remainingTotal(fresh);
      if (rest <= creditRpcEpsilon) {
        if (mounted) {
          AppToast.info(
            context,
            'Cette créance est déjà soldée. La liste a été actualisée.',
          );
          widget.onSuccess?.call();
          Navigator.of(context).pop(true);
        }
        return;
      }

      final tendered = tenderedRaw;
      final isCash = _mode.isCash;
      final applied = isCash
          ? _roundMoney(tendered > rest ? rest : tendered)
          : _roundMoney(tendered);

      if (!isCash && tendered > rest + creditAmountEps) {
        if (mounted) {
          AppToast.error(
            context,
            'Le montant ne peut pas dépasser le reste à payer (${formatCurrency(rest)}) '
            'pour ce mode de paiement.',
          );
        }
        return;
      }

      if (applied <= creditRpcEpsilon) {
        if (mounted) {
          AppToast.error(
            context,
            rest <= creditRpcEpsilon
                ? 'Cette créance est déjà soldée.'
                : 'Montant reçu insuffisant ou invalide.',
          );
        }
        return;
      }

      final note = _refCtrl.text.trim();
      final mobileLbl = _mode.mobileProviderLabel;
      final reference = mobileLbl != null
          ? [mobileLbl, note].where((s) => s.isNotEmpty).join(' — ')
          : (note.isEmpty ? null : note);

      final AppendPaymentResult payMeta;
      try {
        payMeta = await widget.credit.appendSalePayment(
          saleId: widget.sale.id,
          method: _mode.backendMethod,
          amount: applied,
          reference: reference,
        );
      } catch (e, st) {
        if (!_isOverpayError(e)) rethrow;
        AppErrorHandler.log(e, st);

        final freshAfter = await widget.credit.fetchCreditSaleDetail(
          widget.sale.id,
          widget.sale.companyId,
        );
        final restAfter =
            freshAfter == null ? null : remainingTotal(freshAfter);
        if (restAfter != null && restAfter <= creditRpcEpsilon) {
          if (mounted) {
            AppToast.info(
              context,
              'Cette créance est déjà soldée. La liste a été actualisée.',
            );
            widget.onSuccess?.call();
            Navigator.of(context).pop(true);
          }
          return;
        }
        if (mounted) {
          AppToast.error(
            context,
            'Le solde a changé. La liste a été actualisée, réessayez avec le nouveau reste.',
          );
          widget.onSuccess?.call();
        }
        return;
      }

      if (!mounted) return;
      final changeDue = isCash
          ? _roundMoney((tendered - applied).clamp(0.0, double.infinity))
          : 0.0;
      final payload = CreditPaymentReceiptPayload(
        paymentId: payMeta.paymentId,
        issuedAt: payMeta.createdAt,
        storeId: fresh.storeId,
        storePrimaryColor: fresh.store?.primaryColor,
        saleNumber: fresh.saleNumber,
        storeName: fresh.store?.name ?? 'Boutique',
        customerName: fresh.customer?.name ?? 'Client',
        customerPhone: fresh.customer?.phone,
        creditTitle: 'Vente ${fresh.saleNumber}',
        paymentMethodCode: _mode.backendMethod.name,
        paymentMethodLabel: switch (_mode.backendMethod) {
          PaymentMethod.cash => 'Espèces',
          PaymentMethod.mobile_money => 'Mobile money',
          PaymentMethod.card => 'Carte',
          PaymentMethod.transfer => 'Virement',
          PaymentMethod.other => 'Autre',
        },
        paymentReference: reference,
        amountPaid: applied,
        amountTendered: isCash ? tendered : null,
        changeDue: isCash && changeDue > creditAmountEps ? changeDue : null,
        previousBalance: rest,
        newBalance: (rest - applied).clamp(0.0, double.infinity),
        settled: (rest - applied).clamp(0.0, double.infinity) <= creditAmountEps,
      );
      if (isCash && changeDue > creditAmountEps) {
        AppToast.success(
          context,
          'Paiement enregistré. Monnaie à rendre : ${formatCurrency(changeDue)}.',
        );
      } else {
        AppToast.success(context, 'Paiement enregistré.');
      }
      widget.onSuccess?.call();
      Navigator.of(context).pop(payload);
    } catch (e, st) {
      AppErrorHandler.log(e, st);
      if (mounted) {
        AppToast.error(
          context,
          AppErrorHandler.toUserMessage(e, fallback: 'Échec enregistrement.'),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rest = _restInitial;
    final theme = Theme.of(context);
    final isCash = _mode.isCash;
    final tendered = _tendered;
    final appliedPreview = isCash
        ? (tendered > rest ? rest : tendered)
        : tendered;
    final changePreview = isCash
        ? (tendered - appliedPreview).clamp(0.0, double.infinity)
        : 0.0;
    final nonCashOver =
        !isCash && tendered > rest + creditAmountEps && tendered > creditAmountEps;

    return AlertDialog(
      title: const Text('Enregistrer un paiement'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.sale.saleNumber} — reste ${formatCurrency(rest)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            DropdownButtonFormField<_PayModeUi>(
              key: ValueKey<_PayModeUi>(_mode),
              initialValue: _mode,
              decoration: const InputDecoration(
                labelText: 'Mode',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: _PayModeUi.cash,
                  child: Text('Espèces'),
                ),
                DropdownMenuItem(
                  value: _PayModeUi.orangeMoney,
                  child: Text('Orange money'),
                ),
                DropdownMenuItem(
                  value: _PayModeUi.moovMoney,
                  child: Text('Moov money'),
                ),
                DropdownMenuItem(
                  value: _PayModeUi.wave,
                  child: Text('Wave'),
                ),
                DropdownMenuItem(
                  value: _PayModeUi.card,
                  child: Text('Carte'),
                ),
                DropdownMenuItem(
                  value: _PayModeUi.transfer,
                  child: Text('Virement'),
                ),
              ],
              onChanged: _busy
                  ? null
                  : (v) {
                      if (v != null) setState(() => _mode = v);
                    },
            ),
            const SizedBox(height: AppTheme.spaceMd),
            TextField(
              controller: _amountCtrl,
              decoration: InputDecoration(
                labelText: isCash ? 'Montant reçu (espèces)' : 'Montant encaissé',
                hintText: rest > 0 ? formatCurrency(rest) : '0',
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
            ),
            if (isCash && tendered > creditAmountEps) ...[
              const SizedBox(height: 8),
              Text(
                'Imputé au solde : ${formatCurrency(appliedPreview)}'
                '${changePreview > creditAmountEps ? ' · Monnaie à rendre : ${formatCurrency(changePreview)}' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (nonCashOver)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Le montant ne peut pas dépasser le reste à payer (${formatCurrency(rest)}) '
                  'pour ce mode de paiement.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: AppTheme.spaceMd),
            TextField(
              controller: _refCtrl,
              decoration: const InputDecoration(
                labelText: 'Note / référence',
                hintText: 'Reçu, n° transaction…',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : () {
                  _submit();
                },
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Valider'),
        ),
      ],
    );
  }
}
