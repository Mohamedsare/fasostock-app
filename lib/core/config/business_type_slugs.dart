/// Slugs alignés sur `appweb/lib/config/business-types.ts` (inscription).
const Set<String> kValidBusinessTypeSlugs = {
  'supermarche-alimentation',
  'boutique-vetements',
  'telephones-accessoires',
  'pharmacie',
  'pieces-moto',
  'pieces-auto',
  'quincaillerie',
  'materiaux-construction',
  'restaurant-fast-food',
  'grossiste-distribution',
  'autre-commerce',
};

bool isValidBusinessTypeSlug(String? slug) {
  if (slug == null) return false;
  final t = slug.trim();
  if (t.isEmpty) return false;
  return kValidBusinessTypeSlugs.contains(t);
}
