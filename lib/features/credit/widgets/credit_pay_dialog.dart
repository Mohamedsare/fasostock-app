import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../data/models/sale.dart';
import '../../../../data/repositories/credit_sync_facade.dart';
import '../../../../shared/utils/format_currency.dart';
import '../credit_math.dart';

/// Enregistrement d'un paiement — aligné `CreditRecordPaymentDialog` (web).
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

class _CreditPayDialogState extends State<CreditPayDialog> {
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;
  bool _busy = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  double get _rest => remainingTotal(widget.sale);

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    if (amount <= 0 || amount > _rest + 0.01) return;
    setState(() => _busy = true);
    try {
      await widget.credit.appendSalePayment(
        saleId: widget.sale.id,
        method: _method,
        amount: amount,
        reference: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
      );
      if (!mounted) return;
      AppToast.success(context, 'Paiement enregistré.');
      widget.onSuccess?.call();
      Navigator.of(context).pop(true);
    } catch (e, st) {
      AppErrorHandler.log(e, st);
      if (mounted) {
        AppToast.error(context, AppErrorHandler.toUserMessage(e, fallback: 'Échec enregistrement.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rest = _rest;
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Enregistrer un paiement'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.sale.saleNumber} — reste ${formatCurrency(rest)}',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            TextField(
              controller: _amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Montant',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            ),
            const SizedBox(height: AppTheme.spaceMd),
            DropdownButtonFormField<PaymentMethod>(
              value: _method,
              decoration: const InputDecoration(
                labelText: 'Mode',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: PaymentMethod.cash, child: Text('Espèces')),
                DropdownMenuItem(value: PaymentMethod.mobile_money, child: Text('Mobile money')),
                DropdownMenuItem(value: PaymentMethod.card, child: Text('Carte')),
                DropdownMenuItem(value: PaymentMethod.transfer, child: Text('Virement')),
              ],
              onChanged: _busy
                  ? null
                  : (v) {
                      if (v != null) setState(() => _method = v);
                    },
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
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Annuler')),
        FilledButton(
          onPressed: _busy
              ? null
              : () {
                  final amount = double.tryParse(_amountCtrl.text.trim().replaceAll(',', '.')) ?? 0;
                  if (amount <= 0 || amount > rest + 0.01) return;
                  _submit();
                },
          child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Valider'),
        ),
      ],
    );
  }
}
