import '../../data/models/sale.dart';

const creditAmountEps = 0.005;

/// Indique si cette ligne de paiement compte dans l’« encaissé » (crédit / partiel).
///
/// - Espèces, carte, etc. : toujours oui.
/// - `other` : non si une autre ligne non-`other` existe (ex. acompte espèces + ligne
///   « crédit » pour le reliquat). Oui uniquement pour **une seule** ligne `other` avec
///   montant **strictement inférieur** au total (acompte saisi au POS sous « À crédit »).
bool salePaymentContributesToPaidRealized(Sale sale, SalePayment p) {
  final all = sale.salePayments ?? const <SalePayment>[];
  if (p.method != PaymentMethod.other) return true;
  final nonOther = all.where((x) => x.method != PaymentMethod.other).toList();
  final others = all.where((x) => x.method == PaymentMethod.other).toList();
  if (nonOther.isNotEmpty) return false;
  if (others.length != 1 || p.id != others.first.id) return false;
  return p.amount + creditAmountEps < sale.total;
}

double paidRealized(Sale sale) {
  final pays = sale.salePayments ?? const <SalePayment>[];
  var s = 0.0;
  for (final p in pays) {
    if (!salePaymentContributesToPaidRealized(sale, p)) continue;
    s += p.amount;
  }
  return s;
}

double remainingTotal(Sale sale) {
  return (sale.total - paidRealized(sale)).clamp(0.0, double.infinity);
}

DateTime effectiveDueAt(Sale sale) {
  final raw = sale.creditDueAt;
  if (raw != null && raw.trim().isNotEmpty) {
    final d = DateTime.tryParse(raw);
    if (d != null) return DateTime(d.year, d.month, d.day);
  }
  final created = DateTime.tryParse(sale.createdAt) ?? DateTime.now();
  return DateTime(created.year, created.month, created.day).add(const Duration(days: 30));
}

int daysOverdue(Sale sale, [DateTime? now]) {
  final n = now ?? DateTime.now();
  if (remainingTotal(sale) <= creditAmountEps) return 0;
  final due = effectiveDueAt(sale);
  final dueDay = DateTime(due.year, due.month, due.day);
  final today = DateTime(n.year, n.month, n.day);
  final diff = today.difference(dueDay).inDays;
  return diff > 0 ? diff : 0;
}

enum CreditLineStatus { nonPaye, partiel, solde, enRetard, annule }

CreditLineStatus creditLineStatus(Sale sale, [DateTime? now]) {
  if (sale.status == SaleStatus.cancelled || sale.status == SaleStatus.refunded) {
    return CreditLineStatus.annule;
  }
  final rem = remainingTotal(sale);
  if (rem <= creditAmountEps) return CreditLineStatus.solde;
  final paid = paidRealized(sale);
  final overdue = daysOverdue(sale, now) > 0;
  if (overdue) return CreditLineStatus.enRetard;
  if (paid <= creditAmountEps) return CreditLineStatus.nonPaye;
  return CreditLineStatus.partiel;
}

String creditStatusLabel(CreditLineStatus s) {
  switch (s) {
    case CreditLineStatus.nonPaye:
      return 'Non payé';
    case CreditLineStatus.partiel:
      return 'Partiellement payé';
    case CreditLineStatus.solde:
      return 'Soldé';
    case CreditLineStatus.enRetard:
      return 'En retard';
    case CreditLineStatus.annule:
      return 'Annulé';
  }
}

bool isDueToday(Sale sale, [DateTime? now]) {
  if (remainingTotal(sale) <= creditAmountEps) return false;
  final n = now ?? DateTime.now();
  final d = effectiveDueAt(sale);
  return d.year == n.year && d.month == n.month && d.day == n.day;
}

/// Semaine du lundi (aligné web date-fns weekStartsOn: 1).
bool isDueThisWeek(Sale sale, [DateTime? now]) {
  if (remainingTotal(sale) <= creditAmountEps) return false;
  final n = now ?? DateTime.now();
  final d = effectiveDueAt(sale);
  if (isDueToday(sale, n)) return true;
  final monday = n.subtract(Duration(days: n.weekday - DateTime.monday));
  final monday0 = DateTime(monday.year, monday.month, monday.day);
  final sunday0 = monday0.add(const Duration(days: 6));
  final dd = DateTime(d.year, d.month, d.day);
  return !dd.isBefore(monday0) && !dd.isAfter(sunday0);
}

/// Aligné `dueBadgeVariant` (web credit-math) : couleur ligne échéance.
enum DueBadgeVariant { ok, soon, late }

DueBadgeVariant dueBadgeVariant(Sale sale, [DateTime? now]) {
  if (remainingTotal(sale) <= creditAmountEps) return DueBadgeVariant.ok;
  if (daysOverdue(sale, now) > 0) return DueBadgeVariant.late;
  final n = now ?? DateTime.now();
  final due = effectiveDueAt(sale);
  final dueDay = DateTime(due.year, due.month, due.day);
  final today = DateTime(n.year, n.month, n.day);
  final daysTo = dueDay.difference(today).inDays;
  if (daysTo <= 7) return DueBadgeVariant.soon;
  return DueBadgeVariant.ok;
}

class CustomerCreditAgg {
  const CustomerCreditAgg({
    required this.customerId,
    required this.customerName,
    required this.phone,
    required this.openSaleCount,
    required this.totalDue,
    required this.overdueAmount,
    this.lastPaymentAt,
    this.nextDueAt,
    required this.risk,
  });

  final String customerId;
  final String customerName;
  final String? phone;
  final int openSaleCount;
  final double totalDue;
  final double overdueAmount;
  final DateTime? lastPaymentAt;
  final DateTime? nextDueAt;
  /// attention | critique | normal
  final String risk;
}

String? _maxRealizedPaymentAt(Sale sale) {
  final pays = (sale.salePayments ?? []).where((p) => salePaymentContributesToPaidRealized(sale, p)).toList();
  if (pays.isEmpty) return null;
  String? best;
  for (final p in pays) {
    final c = p.createdAt;
    if (c == null || c.isEmpty) continue;
    if (best == null || c.compareTo(best) > 0) best = c;
  }
  return best;
}

List<CustomerCreditAgg> buildCustomerAggregates(List<Sale> sales) {
  final byCustomer = <String, List<Sale>>{};
  for (final s in sales) {
    final cid = s.customerId;
    final c = s.customer;
    if (cid == null || c == null) continue;
    byCustomer.putIfAbsent(cid, () => []).add(s);
  }
  final out = <CustomerCreditAgg>[];
  for (final e in byCustomer.entries) {
    final list = e.value;
    final open = list.where((s) => remainingTotal(s) > creditAmountEps).toList();
    if (open.isEmpty) continue;
    final c = list.first.customer!;
    var totalDue = 0.0;
    var overdueAmount = 0.0;
    DateTime? nextDue;
    String? lastPay;
    for (final s in open) {
      final r = remainingTotal(s);
      totalDue += r;
      if (daysOverdue(s) > 0) overdueAmount += r;
      final d = effectiveDueAt(s);
      if (nextDue == null || d.isBefore(nextDue)) nextDue = d;
      final mp = _maxRealizedPaymentAt(s);
      if (mp != null && (lastPay == null || mp.compareTo(lastPay) > 0)) lastPay = mp;
    }
    var risk = 'normal';
    if (overdueAmount > creditAmountEps) {
      risk = overdueAmount >= totalDue * 0.5 ? 'critique' : 'attention';
    }
    out.add(CustomerCreditAgg(
      customerId: e.key,
      customerName: c.name,
      phone: c.phone,
      openSaleCount: open.length,
      totalDue: totalDue,
      overdueAmount: overdueAmount,
      lastPaymentAt: lastPay != null ? DateTime.tryParse(lastPay) : null,
      nextDueAt: nextDue,
      risk: risk,
    ));
  }
  out.sort((a, b) => b.totalDue.compareTo(a.totalDue));
  return out;
}
