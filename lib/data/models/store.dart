/// Normalise la valeur invoice_template (API peut renvoyer null, vide ou casse différente).
String _normalizeInvoiceTemplate(dynamic v) {
  if (v == null) return 'classic';
  final s = (v as Object?).toString().trim().toLowerCase();
  return s == 'elof' ? 'elof' : 'classic';
}

/// Boutique — aligné avec Store (storesService, CompanyContext) + paramètres facture A4.
class Store {
  const Store({
    required this.id,
    required this.companyId,
    required this.name,
    this.code,
    this.address,
    this.logoUrl,
    this.phone,
    this.email,
    this.description,
    this.isActive = true,
    this.isPrimary = false,
    this.posDiscountEnabled = false,
    this.createdAt,
    this.currency,
    this.primaryColor,
    this.secondaryColor,
    this.invoicePrefix,
    this.footerText,
    this.legalInfo,
    this.signatureUrl,
    this.stampUrl,
    this.paymentTerms,
    this.taxLabel,
    this.taxNumber,
    this.city,
    this.country,
    this.commercialName,
    this.slogan,
    this.activity,
    this.mobileMoney,
    this.invoiceShortTitle,
    this.invoiceSignerTitle,
    this.invoiceSignerName,
    this.invoiceTemplate,
  });

  final String id;
  final String companyId;
  final String name;
  final String? code;
  final String? address;
  final String? logoUrl;
  final String? phone;
  final String? email;
  final String? description;
  final bool isActive;
  final bool isPrimary;
  final bool posDiscountEnabled;
  final String? createdAt;
  // Paramètres facture A4
  final String? currency;
  final String? primaryColor;
  final String? secondaryColor;
  final String? invoicePrefix;
  final String? footerText;
  final String? legalInfo;
  final String? signatureUrl;
  final String? stampUrl;
  final String? paymentTerms;
  final String? taxLabel;
  final String? taxNumber;
  final String? city;
  final String? country;
  final String? commercialName;
  final String? slogan;
  final String? activity;
  final String? mobileMoney;
  final String? invoiceShortTitle;
  final String? invoiceSignerTitle;
  final String? invoiceSignerName;
  /// Modèle facture A4 : 'classic' (défaut) ou 'elof'.
  final String? invoiceTemplate;

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      name: json['name'] as String,
      code: json['code'] as String?,
      address: json['address'] as String?,
      logoUrl: json['logo_url'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      isPrimary: json['is_primary'] as bool? ?? false,
      posDiscountEnabled: json['pos_discount_enabled'] as bool? ?? false,
      createdAt: json['created_at'] as String?,
      currency: json['currency'] as String?,
      primaryColor: json['primary_color'] as String?,
      secondaryColor: json['secondary_color'] as String?,
      invoicePrefix: json['invoice_prefix'] as String?,
      footerText: json['footer_text'] as String?,
      legalInfo: json['legal_info'] as String?,
      signatureUrl: json['signature_url'] as String?,
      stampUrl: json['stamp_url'] as String?,
      paymentTerms: json['payment_terms'] as String?,
      taxLabel: json['tax_label'] as String?,
      taxNumber: json['tax_number'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      commercialName: json['commercial_name'] as String?,
      slogan: json['slogan'] as String?,
      activity: json['activity'] as String?,
      mobileMoney: json['mobile_money'] as String?,
      invoiceShortTitle: json['invoice_short_title'] as String?,
      invoiceSignerTitle: json['invoice_signer_title'] as String?,
      invoiceSignerName: json['invoice_signer_name'] as String?,
      invoiceTemplate: _normalizeInvoiceTemplate(json['invoice_template']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'company_id': companyId,
        'name': name,
        'code': code,
        'address': address,
        'logo_url': logoUrl,
        'phone': phone,
        'email': email,
        'description': description,
        'is_active': isActive,
        'is_primary': isPrimary,
        'pos_discount_enabled': posDiscountEnabled,
        'created_at': createdAt,
        'currency': currency,
        'primary_color': primaryColor,
        'secondary_color': secondaryColor,
        'invoice_prefix': invoicePrefix,
        'footer_text': footerText,
        'legal_info': legalInfo,
        'signature_url': signatureUrl,
        'stamp_url': stampUrl,
        'payment_terms': paymentTerms,
        'tax_label': taxLabel,
        'tax_number': taxNumber,
        'city': city,
        'country': country,
        'commercial_name': commercialName,
        'slogan': slogan,
        'activity': activity,
        'mobile_money': mobileMoney,
        'invoice_short_title': invoiceShortTitle,
        'invoice_signer_title': invoiceSignerTitle,
        'invoice_signer_name': invoiceSignerName,
        'invoice_template': invoiceTemplate,
      };
}

/// Input création boutique — même champs que CreateStoreInput (web).
class CreateStoreInput {
  const CreateStoreInput({
    required this.companyId,
    required this.name,
    this.address,
    this.logoUrl,
    this.phone,
    this.email,
    this.description,
    this.isPrimary = false,
    this.posDiscountEnabled,
  });

  final String companyId;
  final String name;
  final String? address;
  final String? logoUrl;
  final String? phone;
  final String? email;
  final String? description;
  final bool isPrimary;
  final bool? posDiscountEnabled;
}
