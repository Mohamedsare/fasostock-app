import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import '../../../core/breakpoints.dart';
import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../data/models/store.dart';
import '../../../data/repositories/stores_repository.dart';
import '../../pos/services/invoice_a4_pdf_service.dart';

/// Dialog d'édition de boutique — champs préremplis + logo (aligné EditStoreDialog web).
class EditStoreDialog extends StatefulWidget {
  const EditStoreDialog({
    super.key,
    required this.store,
    required this.onSuccess,
    required this.onCancel,
  });

  final Store store;
  /// Appelé avec la boutique modifiée (pour mise à jour immédiate du cache Drift).
  final void Function(Store? store)? onSuccess;
  final VoidCallback onCancel;

  @override
  State<EditStoreDialog> createState() => _EditStoreDialogState();
}

class _EditStoreDialogState extends State<EditStoreDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _descriptionController;
  // Paramètres facture A4
  late final TextEditingController _invoiceShortTitleController;
  late final TextEditingController _commercialNameController;
  late final TextEditingController _sloganController;
  late final TextEditingController _activityController;
  late final TextEditingController _mobileMoneyController;
  late final TextEditingController _invoicePrefixController;
  late final TextEditingController _currencyController;
  late final TextEditingController _primaryColorController;
  late final TextEditingController _secondaryColorController;
  late final TextEditingController _cityController;
  late final TextEditingController _countryController;
  late final TextEditingController _legalInfoController;
  late final TextEditingController _taxLabelController;
  late final TextEditingController _taxNumberController;
  late final TextEditingController _footerTextController;
  late final TextEditingController _paymentTermsController;
  late final TextEditingController _signatureUrlController;
  late final TextEditingController _stampUrlController;
  late final TextEditingController _invoiceSignerTitleController;
  late final TextEditingController _invoiceSignerNameController;

  late bool _isPrimary;
  late bool _posDiscountEnabled;
  late String _invoiceTemplate;
  bool _loading = false;
  String? _error;
  List<int>? _logoBytes;
  String _logoFileName = '';
  String _logoContentType = 'image/jpeg';

  @override
  void initState() {
    super.initState();
    final s = widget.store;
    _nameController = TextEditingController(text: s.name);
    _addressController = TextEditingController(text: s.address ?? '');
    _phoneController = TextEditingController(text: s.phone ?? '');
    _emailController = TextEditingController(text: s.email ?? '');
    _descriptionController = TextEditingController(text: s.description ?? '');
    _invoiceShortTitleController = TextEditingController(text: s.invoiceShortTitle ?? '');
    _commercialNameController = TextEditingController(text: s.commercialName ?? '');
    _sloganController = TextEditingController(text: s.slogan ?? '');
    _activityController = TextEditingController(text: s.activity ?? '');
    _mobileMoneyController = TextEditingController(text: s.mobileMoney ?? '');
    _invoicePrefixController = TextEditingController(text: s.invoicePrefix ?? 'FAC');
    _currencyController = TextEditingController(text: s.currency ?? 'XOF');
    _primaryColorController = TextEditingController(text: s.primaryColor ?? '');
    _secondaryColorController = TextEditingController(text: s.secondaryColor ?? '');
    _cityController = TextEditingController(text: s.city ?? '');
    _countryController = TextEditingController(text: s.country ?? '');
    _legalInfoController = TextEditingController(text: s.legalInfo ?? '');
    _taxLabelController = TextEditingController(text: s.taxLabel ?? '');
    _taxNumberController = TextEditingController(text: s.taxNumber ?? '');
    _footerTextController = TextEditingController(text: s.footerText ?? '');
    _paymentTermsController = TextEditingController(text: s.paymentTerms ?? '');
    _signatureUrlController = TextEditingController(text: s.signatureUrl ?? '');
    _stampUrlController = TextEditingController(text: s.stampUrl ?? '');
    _invoiceSignerTitleController = TextEditingController(text: s.invoiceSignerTitle ?? '');
    _invoiceSignerNameController = TextEditingController(text: s.invoiceSignerName ?? '');
    _isPrimary = s.isPrimary;
    _posDiscountEnabled = s.posDiscountEnabled;
    // Normaliser pour que la valeur soit toujours 'classic' ou 'elof' (évite dropdown cassé si API renvoie autre chose).
    final t = (s.invoiceTemplate ?? 'classic').toString().trim().toLowerCase();
    _invoiceTemplate = t == 'elof' ? 'elof' : 'classic';
    // Recharger la boutique depuis l'API à l'ouverture pour afficher la valeur réellement enregistrée (invoice_template peut venir d'un cache périmé).
    WidgetsBinding.instance.addPostFrameCallback((_) => _refetchStoreTemplate());
  }

  Future<void> _refetchStoreTemplate() async {
    try {
      final repo = StoresRepository();
      final fresh = await repo.getStore(widget.store.id);
      if (!mounted || fresh == null) return;
      final t = (fresh.invoiceTemplate ?? 'classic').toString().trim().toLowerCase();
      final value = t == 'elof' ? 'elof' : 'classic';
      if (value != _invoiceTemplate) {
        setState(() => _invoiceTemplate = value);
      }
    } catch (e, st) {
      AppErrorHandler.log(e, st);
      // Garder la valeur déjà initialisée depuis widget.store
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _descriptionController.dispose();
    _invoiceShortTitleController.dispose();
    _commercialNameController.dispose();
    _sloganController.dispose();
    _activityController.dispose();
    _mobileMoneyController.dispose();
    _invoicePrefixController.dispose();
    _currencyController.dispose();
    _primaryColorController.dispose();
    _secondaryColorController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _legalInfoController.dispose();
    _taxLabelController.dispose();
    _taxNumberController.dispose();
    _footerTextController.dispose();
    _paymentTermsController.dispose();
    _signatureUrlController.dispose();
    _stampUrlController.dispose();
    _invoiceSignerTitleController.dispose();
    _invoiceSignerNameController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      if (file.bytes == null) return;
      if (!mounted) return;
      setState(() {
        _logoBytes = file.bytes;
        _logoFileName = file.name;
        _logoContentType = file.extension != null ? 'image/${file.extension}' : 'image/jpeg';
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = AppErrorHandler.toUserMessage(e, fallback: 'Impossible de sélectionner l\'image.'));
      }
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Nom requis (2 caractères minimum)');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = StoresRepository();
      String? logoUrl = widget.store.logoUrl;
      if (_logoBytes != null && _logoBytes!.isNotEmpty) {
        try {
          logoUrl = await repo.uploadStoreLogo(
            widget.store.id,
            _logoBytes!,
            _logoFileName.isEmpty ? 'logo.jpg' : _logoFileName,
            _logoContentType,
          );
        } catch (e) {
          if (mounted) {
            setState(() {
              _loading = false;
              _error = AppErrorHandler.toUserMessage(e, fallback: 'Impossible d\'envoyer le logo. Réessayez ou enregistrez sans changer le logo.');
            });
          }
          return;
        }
      }
      final patch = <String, dynamic>{
        'name': name,
        'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        'is_primary': _isPrimary,
        'pos_discount_enabled': _posDiscountEnabled,
        'invoice_short_title': _invoiceShortTitleController.text.trim().isEmpty ? null : _invoiceShortTitleController.text.trim(),
        'commercial_name': _commercialNameController.text.trim().isEmpty ? null : _commercialNameController.text.trim(),
        'slogan': _sloganController.text.trim().isEmpty ? null : _sloganController.text.trim(),
        'activity': _activityController.text.trim().isEmpty ? null : _activityController.text.trim(),
        'mobile_money': _mobileMoneyController.text.trim().isEmpty ? null : _mobileMoneyController.text.trim(),
        'invoice_prefix': _invoicePrefixController.text.trim().isEmpty ? null : _invoicePrefixController.text.trim(),
        'currency': _currencyController.text.trim().isEmpty ? null : _currencyController.text.trim(),
        'primary_color': _primaryColorController.text.trim().isEmpty ? null : _primaryColorController.text.trim(),
        'secondary_color': _secondaryColorController.text.trim().isEmpty ? null : _secondaryColorController.text.trim(),
        'city': _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
        'country': _countryController.text.trim().isEmpty ? null : _countryController.text.trim(),
        'legal_info': _legalInfoController.text.trim().isEmpty ? null : _legalInfoController.text.trim(),
        'tax_label': _taxLabelController.text.trim().isEmpty ? null : _taxLabelController.text.trim(),
        'tax_number': _taxNumberController.text.trim().isEmpty ? null : _taxNumberController.text.trim(),
        'footer_text': _footerTextController.text.trim().isEmpty ? null : _footerTextController.text.trim(),
        'payment_terms': _paymentTermsController.text.trim().isEmpty ? null : _paymentTermsController.text.trim(),
        'signature_url': _signatureUrlController.text.trim().isEmpty ? null : _signatureUrlController.text.trim(),
        'stamp_url': _stampUrlController.text.trim().isEmpty ? null : _stampUrlController.text.trim(),
        'invoice_signer_title': _invoiceSignerTitleController.text.trim().isEmpty ? null : _invoiceSignerTitleController.text.trim(),
        'invoice_signer_name': _invoiceSignerNameController.text.trim().isEmpty ? null : _invoiceSignerNameController.text.trim(),
        'invoice_template': _invoiceTemplate == 'elof' ? 'elof' : 'classic',
      };
      if (logoUrl != null) patch['logo_url'] = logoUrl;
      final updated = await repo.updateStore(widget.store.id, patch);
      if (mounted) {
        setState(() => _loading = false);
        widget.onSuccess?.call(updated);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppErrorHandler.toUserMessage(e);
          _loading = false;
        });
      }
    }
  }

  /// Construit une boutique à partir des champs du formulaire (pour aperçu facture A4).
  Store _buildStoreFromForm() {
    final s = widget.store;
    String? trim(String? v) => v == null || v.trim().isEmpty ? null : v.trim();
    return Store(
      id: s.id,
      companyId: s.companyId,
      name: trim(_nameController.text) ?? s.name,
      code: s.code,
      address: trim(_addressController.text),
      logoUrl: s.logoUrl,
      phone: trim(_phoneController.text),
      email: trim(_emailController.text),
      description: trim(_descriptionController.text),
      isActive: s.isActive,
      isPrimary: _isPrimary,
      posDiscountEnabled: _posDiscountEnabled,
      createdAt: s.createdAt,
      currency: trim(_currencyController.text),
      primaryColor: trim(_primaryColorController.text),
      secondaryColor: trim(_secondaryColorController.text),
      invoicePrefix: trim(_invoicePrefixController.text),
      footerText: trim(_footerTextController.text),
      legalInfo: trim(_legalInfoController.text),
      signatureUrl: trim(_signatureUrlController.text),
      stampUrl: trim(_stampUrlController.text),
      paymentTerms: trim(_paymentTermsController.text),
      taxLabel: trim(_taxLabelController.text),
      taxNumber: trim(_taxNumberController.text),
      city: trim(_cityController.text),
      country: trim(_countryController.text),
      commercialName: trim(_commercialNameController.text),
      slogan: trim(_sloganController.text),
      activity: trim(_activityController.text),
      mobileMoney: trim(_mobileMoneyController.text),
      invoiceShortTitle: trim(_invoiceShortTitleController.text),
      invoiceSignerTitle: trim(_invoiceSignerTitleController.text),
      invoiceSignerName: trim(_invoiceSignerNameController.text),
      invoiceTemplate: _invoiceTemplate == 'elof' ? 'elof' : 'classic',
    );
  }

  Future<void> _previewInvoiceA4() async {
    setState(() => _error = null);

    try {
      final storeForPreview = _buildStoreFromForm();
      final logoBytesForPreview = await _resolveLogoBytesForPreview(storeForPreview);
      if (!mounted) return;
      final prefix = _invoicePrefixController.text.trim().isEmpty ? 'FAC' : _invoicePrefixController.text.trim();
      final data = InvoiceA4Data(
        store: storeForPreview,
        saleNumber: '$prefix-${DateTime.now().year}-001',
        date: DateTime.now(),
        items: const [
          InvoiceLineData(description: 'Produit exemple', quantity: 2, unit: 'pce', unitPrice: 5000, total: 10000),
          InvoiceLineData(description: 'Autre article (aperçu)', quantity: 1, unit: 'pce', unitPrice: 2500, total: 2500),
        ],
        subtotal: 12500,
        discount: 0,
        tax: 0,
        total: 12500,
        customerName: 'Client test',
        customerPhone: '70 00 00 00',
        amountInWords: 'Douze mille cinq cents francs',
        logoBytes: logoBytesForPreview,
      );

      // Preview intégrée (PdfPreview) => l'utilisateur voit le PDF directement dans l'app.
      showDialog<void>(
        context: context,
        useSafeArea: true,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 900,
              maxHeight: MediaQuery.of(ctx).size.height * 0.92,
            ),
            child: Scaffold(
              backgroundColor: Theme.of(ctx).colorScheme.surface,
              appBar: AppBar(
                title: const Text('Aperçu facture A4'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                    tooltip: 'Fermer',
                  ),
                ],
              ),
              body: PdfPreview(
                build: (_) async {
                  try {
                    final doc = await InvoiceA4PdfService.buildDocument(data);
                    return doc.save();
                  } catch (e) {
                    if (ctx.mounted) AppErrorHandler.show(ctx, e, fallback: 'Impossible d\'afficher l\'aperçu de la facture.');
                    return Uint8List(0);
                  }
                },
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppErrorHandler.toUserMessage(
            e,
            fallback: 'Impossible d\'ouvrir l\'aperçu de la facture.',
          );
        });
      }
    }
  }

  Future<Uint8List?> _resolveLogoBytesForPreview(Store store) async {
    // 1) Si l'utilisateur vient de choisir une nouvelle image, on l'utilise directement.
    if (_logoBytes != null && _logoBytes!.isNotEmpty) {
      return Uint8List.fromList(_logoBytes!);
    }

    // 2) Sinon, on tente le cache local (important pour l'offline).
    final cached = await InvoiceA4PdfService.loadCachedLogoBytes(store.id);
    if (cached != null && cached.isNotEmpty) return cached;

    // 3) Si on est en ligne, on télécharge depuis l'URL (et on met en cache).
    final url = store.logoUrl;
    if (url == null || url.isEmpty) return null;
    if (!ConnectivityService.instance.isOnline) return null;

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) return null;
      final bytes = Uint8List.fromList(res.bodyBytes);
      if (bytes.isEmpty) return null;
      await InvoiceA4PdfService.cacheLogoBytes(store.id, bytes);
      return bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final screenSize = MediaQuery.sizeOf(context);
    final isNarrow = screenSize.width < Breakpoints.tablet;
    final padding = isNarrow ? 16.0 : 24.0;
    final maxW = isNarrow ? screenSize.width - 32 : 520.0;
    final maxH = isNarrow ? screenSize.height * 0.88 : 780.0;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: isNarrow ? 16 : 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Modifier la boutique', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Nom *', border: OutlineInputBorder()),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 8),
                      InputDecorator(
                        decoration: const InputDecoration(labelText: 'Code', border: OutlineInputBorder()),
                        child: Text(store.code ?? '—', style: Theme.of(context).textTheme.bodyLarge),
                      ),
                      const SizedBox(height: 4),
                      Text('Généré automatiquement par le système.', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(labelText: 'Téléphone', border: OutlineInputBorder()),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(v.trim())) return 'Email invalide';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Adresse',
                          hintText: 'Rue, quartier, ville, pays',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), alignLabelWithHint: true),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _isPrimary,
                        onChanged: (v) => setState(() => _isPrimary = v ?? false),
                        title: const Text('Boutique principale'),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      CheckboxListTile(
                        value: _posDiscountEnabled,
                        onChanged: (v) => setState(() => _posDiscountEnabled = v ?? false),
                        title: const Text('Activer la remise en caisse (POS)'),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      const SizedBox(height: 16),
                      Divider(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
                      const SizedBox(height: 8),
                      Text('Paramètres facture A4', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
                      const SizedBox(height: 4),
                      Text('Logo et identité affichés sur la facture A4.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _invoiceTemplate == 'elof' ? 'elof' : 'classic',
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Modèle de facture A4',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'classic', child: Text('Classique (en-tête actuel)', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'elof', child: Text('ELOF (E L O F, ordre fixe, Orange money en orange)', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) => setState(() => _invoiceTemplate = v ?? 'classic'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _previewInvoiceA4,
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                        label: const Text('Aperçu facture A4'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _invoiceShortTitleController,
                        decoration: const InputDecoration(
                          labelText: 'Titre court / Acronyme',
                          border: OutlineInputBorder(),
                          hintText: 'ex. ELOF (affiché E L O F en modèle ELOF)',
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 12),
                      _buildLogoSection(context),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _commercialNameController,
                        decoration: const InputDecoration(labelText: 'Nom commercial', border: OutlineInputBorder(), hintText: 'Raison sociale affichée'),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _sloganController,
                        decoration: const InputDecoration(labelText: 'Slogan', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _activityController,
                        decoration: const InputDecoration(labelText: 'Activité', border: OutlineInputBorder(), hintText: 'Ex. Commerce général en gros et détail'),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _mobileMoneyController,
                        decoration: const InputDecoration(labelText: 'Mobile money (optionnel)', border: OutlineInputBorder(), hintText: 'Ex. Orange Money 70 00 00 00'),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 8),
                      _buildResponsiveRow(
                        context,
                        child1: TextFormField(
                          controller: _invoicePrefixController,
                          decoration: const InputDecoration(labelText: 'Préfixe facture', border: OutlineInputBorder(), hintText: 'FAC'),
                        ),
                        child2: TextFormField(
                          controller: _currencyController,
                          decoration: const InputDecoration(labelText: 'Devise', border: OutlineInputBorder(), hintText: 'XOF'),
                        ),
                        flex1: 2,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _primaryColorController,
                              decoration: const InputDecoration(labelText: 'Couleur principale (hex)', border: OutlineInputBorder(), hintText: '#1976D2'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _secondaryColorController,
                              decoration: const InputDecoration(labelText: 'Couleur secondaire', border: OutlineInputBorder(), hintText: '#0D47A1'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildResponsiveRow(
                        context,
                        child1: TextFormField(
                          controller: _cityController,
                          decoration: const InputDecoration(labelText: 'Ville', border: OutlineInputBorder()),
                        ),
                        child2: TextFormField(
                          controller: _countryController,
                          decoration: const InputDecoration(labelText: 'Pays', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _legalInfoController,
                        decoration: const InputDecoration(labelText: 'Mentions légales (RCCM, IFU, NIF…)', border: OutlineInputBorder(), alignLabelWithHint: true),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                      _buildResponsiveRow(
                        context,
                        child1: TextFormField(
                          controller: _taxLabelController,
                          decoration: const InputDecoration(labelText: 'Libellé taxe', border: OutlineInputBorder(), hintText: 'N° TVA'),
                        ),
                        child2: TextFormField(
                          controller: _taxNumberController,
                          decoration: const InputDecoration(labelText: 'N° fiscal', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _footerTextController,
                        decoration: const InputDecoration(labelText: 'Texte pied de page', border: OutlineInputBorder(), alignLabelWithHint: true),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _paymentTermsController,
                        decoration: const InputDecoration(labelText: 'Conditions de paiement', border: OutlineInputBorder(), hintText: 'Comptant, 30 jours…'),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _signatureUrlController,
                        decoration: const InputDecoration(labelText: 'URL signature (image)', border: OutlineInputBorder()),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _stampUrlController,
                        decoration: const InputDecoration(labelText: 'URL cachet (image)', border: OutlineInputBorder()),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 12),
                      Text('Signataire (dernière page)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Titre et nom affichés en bas de la facture ; signature et cachet à la main.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _invoiceSignerTitleController,
                        decoration: const InputDecoration(
                          labelText: 'Titre du signataire',
                          border: OutlineInputBorder(),
                          hintText: 'ex. Directeur General',
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _invoiceSignerNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nom du signataire',
                          border: OutlineInputBorder(),
                          hintText: 'ex. M. MAHAMADI ELOF',
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _loading ? null : widget.onCancel,
                    style: TextButton.styleFrom(minimumSize: const Size(Breakpoints.minTouchTarget, Breakpoints.minTouchTarget)),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(minimumSize: const Size(0, Breakpoints.minTouchTarget)),
                    child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Enregistrer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveRow(BuildContext context, {required Widget child1, required Widget child2, int flex1 = 1}) {
    final isNarrow = MediaQuery.sizeOf(context).width < Breakpoints.tablet;
    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          child1,
          const SizedBox(height: 12),
          child2,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: flex1, child: child1),
        const SizedBox(width: 12),
        Expanded(child: child2),
      ],
    );
  }

  Widget _buildLogoSection(BuildContext context) {
    final hasNewImage = _logoBytes != null && _logoBytes!.isNotEmpty;
    final currentUrl = widget.store.logoUrl;
    return Row(
      children: [
        GestureDetector(
          onTap: _pickLogo,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
            ),
            child: hasNewImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(Uint8List.fromList(_logoBytes!), fit: BoxFit.cover, width: 80, height: 80),
                  )
                : (currentUrl != null && currentUrl.isNotEmpty)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(currentUrl, fit: BoxFit.cover, width: 80, height: 80),
                      )
                    : Icon(Icons.add_photo_alternate, size: 36, color: Theme.of(context).colorScheme.outline),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Logo entreprise', style: Theme.of(context).textTheme.titleSmall),
              Text('Affiché sur la facture A4. Cliquez pour ajouter ou modifier.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}
