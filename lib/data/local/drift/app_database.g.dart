// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LocalProductsTable extends LocalProducts
    with TableInfo<$LocalProductsTable, LocalProduct> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _skuMeta = const VerificationMeta('sku');
  @override
  late final GeneratedColumn<String> sku = GeneratedColumn<String>(
    'sku',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _barcodeMeta = const VerificationMeta(
    'barcode',
  );
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
    'barcode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pce'),
  );
  static const VerificationMeta _purchasePriceMeta = const VerificationMeta(
    'purchasePrice',
  );
  @override
  late final GeneratedColumn<double> purchasePrice = GeneratedColumn<double>(
    'purchase_price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _salePriceMeta = const VerificationMeta(
    'salePrice',
  );
  @override
  late final GeneratedColumn<double> salePrice = GeneratedColumn<double>(
    'sale_price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _minPriceMeta = const VerificationMeta(
    'minPrice',
  );
  @override
  late final GeneratedColumn<double> minPrice = GeneratedColumn<double>(
    'min_price',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stockMinMeta = const VerificationMeta(
    'stockMin',
  );
  @override
  late final GeneratedColumn<int> stockMin = GeneratedColumn<int>(
    'stock_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _brandIdMeta = const VerificationMeta(
    'brandId',
  );
  @override
  late final GeneratedColumn<String> brandId = GeneratedColumn<String>(
    'brand_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _productScopeMeta = const VerificationMeta(
    'productScope',
  );
  @override
  late final GeneratedColumn<String> productScope = GeneratedColumn<String>(
    'product_scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('both'),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    companyId,
    name,
    sku,
    barcode,
    unit,
    purchasePrice,
    salePrice,
    minPrice,
    stockMin,
    description,
    isActive,
    categoryId,
    brandId,
    imageUrl,
    productScope,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_products';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalProduct> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sku')) {
      context.handle(
        _skuMeta,
        sku.isAcceptableOrUnknown(data['sku']!, _skuMeta),
      );
    }
    if (data.containsKey('barcode')) {
      context.handle(
        _barcodeMeta,
        barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta),
      );
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('purchase_price')) {
      context.handle(
        _purchasePriceMeta,
        purchasePrice.isAcceptableOrUnknown(
          data['purchase_price']!,
          _purchasePriceMeta,
        ),
      );
    }
    if (data.containsKey('sale_price')) {
      context.handle(
        _salePriceMeta,
        salePrice.isAcceptableOrUnknown(data['sale_price']!, _salePriceMeta),
      );
    }
    if (data.containsKey('min_price')) {
      context.handle(
        _minPriceMeta,
        minPrice.isAcceptableOrUnknown(data['min_price']!, _minPriceMeta),
      );
    }
    if (data.containsKey('stock_min')) {
      context.handle(
        _stockMinMeta,
        stockMin.isAcceptableOrUnknown(data['stock_min']!, _stockMinMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('brand_id')) {
      context.handle(
        _brandIdMeta,
        brandId.isAcceptableOrUnknown(data['brand_id']!, _brandIdMeta),
      );
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('product_scope')) {
      context.handle(
        _productScopeMeta,
        productScope.isAcceptableOrUnknown(
          data['product_scope']!,
          _productScopeMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalProduct map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalProduct(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sku: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sku'],
      ),
      barcode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barcode'],
      ),
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      purchasePrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}purchase_price'],
      )!,
      salePrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sale_price'],
      )!,
      minPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}min_price'],
      ),
      stockMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stock_min'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      brandId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}brand_id'],
      ),
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      productScope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_scope'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalProductsTable createAlias(String alias) {
    return $LocalProductsTable(attachedDatabase, alias);
  }
}

class LocalProduct extends DataClass implements Insertable<LocalProduct> {
  final String id;
  final String companyId;
  final String name;
  final String? sku;
  final String? barcode;
  final String unit;
  final double purchasePrice;
  final double salePrice;
  final double? minPrice;
  final int stockMin;
  final String? description;
  final bool isActive;
  final String? categoryId;
  final String? brandId;
  final String? imageUrl;

  /// `both` | `warehouse_only` | `boutique_only` — aligné colonne Supabase `product_scope`.
  final String productScope;
  final String updatedAt;
  const LocalProduct({
    required this.id,
    required this.companyId,
    required this.name,
    this.sku,
    this.barcode,
    required this.unit,
    required this.purchasePrice,
    required this.salePrice,
    this.minPrice,
    required this.stockMin,
    this.description,
    required this.isActive,
    this.categoryId,
    this.brandId,
    this.imageUrl,
    required this.productScope,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_id'] = Variable<String>(companyId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || sku != null) {
      map['sku'] = Variable<String>(sku);
    }
    if (!nullToAbsent || barcode != null) {
      map['barcode'] = Variable<String>(barcode);
    }
    map['unit'] = Variable<String>(unit);
    map['purchase_price'] = Variable<double>(purchasePrice);
    map['sale_price'] = Variable<double>(salePrice);
    if (!nullToAbsent || minPrice != null) {
      map['min_price'] = Variable<double>(minPrice);
    }
    map['stock_min'] = Variable<int>(stockMin);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['is_active'] = Variable<bool>(isActive);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || brandId != null) {
      map['brand_id'] = Variable<String>(brandId);
    }
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    map['product_scope'] = Variable<String>(productScope);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  LocalProductsCompanion toCompanion(bool nullToAbsent) {
    return LocalProductsCompanion(
      id: Value(id),
      companyId: Value(companyId),
      name: Value(name),
      sku: sku == null && nullToAbsent ? const Value.absent() : Value(sku),
      barcode: barcode == null && nullToAbsent
          ? const Value.absent()
          : Value(barcode),
      unit: Value(unit),
      purchasePrice: Value(purchasePrice),
      salePrice: Value(salePrice),
      minPrice: minPrice == null && nullToAbsent
          ? const Value.absent()
          : Value(minPrice),
      stockMin: Value(stockMin),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      isActive: Value(isActive),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      brandId: brandId == null && nullToAbsent
          ? const Value.absent()
          : Value(brandId),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      productScope: Value(productScope),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalProduct.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalProduct(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String>(json['companyId']),
      name: serializer.fromJson<String>(json['name']),
      sku: serializer.fromJson<String?>(json['sku']),
      barcode: serializer.fromJson<String?>(json['barcode']),
      unit: serializer.fromJson<String>(json['unit']),
      purchasePrice: serializer.fromJson<double>(json['purchasePrice']),
      salePrice: serializer.fromJson<double>(json['salePrice']),
      minPrice: serializer.fromJson<double?>(json['minPrice']),
      stockMin: serializer.fromJson<int>(json['stockMin']),
      description: serializer.fromJson<String?>(json['description']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      brandId: serializer.fromJson<String?>(json['brandId']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      productScope: serializer.fromJson<String>(json['productScope']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String>(companyId),
      'name': serializer.toJson<String>(name),
      'sku': serializer.toJson<String?>(sku),
      'barcode': serializer.toJson<String?>(barcode),
      'unit': serializer.toJson<String>(unit),
      'purchasePrice': serializer.toJson<double>(purchasePrice),
      'salePrice': serializer.toJson<double>(salePrice),
      'minPrice': serializer.toJson<double?>(minPrice),
      'stockMin': serializer.toJson<int>(stockMin),
      'description': serializer.toJson<String?>(description),
      'isActive': serializer.toJson<bool>(isActive),
      'categoryId': serializer.toJson<String?>(categoryId),
      'brandId': serializer.toJson<String?>(brandId),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'productScope': serializer.toJson<String>(productScope),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  LocalProduct copyWith({
    String? id,
    String? companyId,
    String? name,
    Value<String?> sku = const Value.absent(),
    Value<String?> barcode = const Value.absent(),
    String? unit,
    double? purchasePrice,
    double? salePrice,
    Value<double?> minPrice = const Value.absent(),
    int? stockMin,
    Value<String?> description = const Value.absent(),
    bool? isActive,
    Value<String?> categoryId = const Value.absent(),
    Value<String?> brandId = const Value.absent(),
    Value<String?> imageUrl = const Value.absent(),
    String? productScope,
    String? updatedAt,
  }) => LocalProduct(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    name: name ?? this.name,
    sku: sku.present ? sku.value : this.sku,
    barcode: barcode.present ? barcode.value : this.barcode,
    unit: unit ?? this.unit,
    purchasePrice: purchasePrice ?? this.purchasePrice,
    salePrice: salePrice ?? this.salePrice,
    minPrice: minPrice.present ? minPrice.value : this.minPrice,
    stockMin: stockMin ?? this.stockMin,
    description: description.present ? description.value : this.description,
    isActive: isActive ?? this.isActive,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    brandId: brandId.present ? brandId.value : this.brandId,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    productScope: productScope ?? this.productScope,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalProduct copyWithCompanion(LocalProductsCompanion data) {
    return LocalProduct(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      name: data.name.present ? data.name.value : this.name,
      sku: data.sku.present ? data.sku.value : this.sku,
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      unit: data.unit.present ? data.unit.value : this.unit,
      purchasePrice: data.purchasePrice.present
          ? data.purchasePrice.value
          : this.purchasePrice,
      salePrice: data.salePrice.present ? data.salePrice.value : this.salePrice,
      minPrice: data.minPrice.present ? data.minPrice.value : this.minPrice,
      stockMin: data.stockMin.present ? data.stockMin.value : this.stockMin,
      description: data.description.present
          ? data.description.value
          : this.description,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      brandId: data.brandId.present ? data.brandId.value : this.brandId,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      productScope: data.productScope.present
          ? data.productScope.value
          : this.productScope,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalProduct(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('name: $name, ')
          ..write('sku: $sku, ')
          ..write('barcode: $barcode, ')
          ..write('unit: $unit, ')
          ..write('purchasePrice: $purchasePrice, ')
          ..write('salePrice: $salePrice, ')
          ..write('minPrice: $minPrice, ')
          ..write('stockMin: $stockMin, ')
          ..write('description: $description, ')
          ..write('isActive: $isActive, ')
          ..write('categoryId: $categoryId, ')
          ..write('brandId: $brandId, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('productScope: $productScope, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    companyId,
    name,
    sku,
    barcode,
    unit,
    purchasePrice,
    salePrice,
    minPrice,
    stockMin,
    description,
    isActive,
    categoryId,
    brandId,
    imageUrl,
    productScope,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalProduct &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.name == this.name &&
          other.sku == this.sku &&
          other.barcode == this.barcode &&
          other.unit == this.unit &&
          other.purchasePrice == this.purchasePrice &&
          other.salePrice == this.salePrice &&
          other.minPrice == this.minPrice &&
          other.stockMin == this.stockMin &&
          other.description == this.description &&
          other.isActive == this.isActive &&
          other.categoryId == this.categoryId &&
          other.brandId == this.brandId &&
          other.imageUrl == this.imageUrl &&
          other.productScope == this.productScope &&
          other.updatedAt == this.updatedAt);
}

class LocalProductsCompanion extends UpdateCompanion<LocalProduct> {
  final Value<String> id;
  final Value<String> companyId;
  final Value<String> name;
  final Value<String?> sku;
  final Value<String?> barcode;
  final Value<String> unit;
  final Value<double> purchasePrice;
  final Value<double> salePrice;
  final Value<double?> minPrice;
  final Value<int> stockMin;
  final Value<String?> description;
  final Value<bool> isActive;
  final Value<String?> categoryId;
  final Value<String?> brandId;
  final Value<String?> imageUrl;
  final Value<String> productScope;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const LocalProductsCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.name = const Value.absent(),
    this.sku = const Value.absent(),
    this.barcode = const Value.absent(),
    this.unit = const Value.absent(),
    this.purchasePrice = const Value.absent(),
    this.salePrice = const Value.absent(),
    this.minPrice = const Value.absent(),
    this.stockMin = const Value.absent(),
    this.description = const Value.absent(),
    this.isActive = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.brandId = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.productScope = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalProductsCompanion.insert({
    required String id,
    required String companyId,
    required String name,
    this.sku = const Value.absent(),
    this.barcode = const Value.absent(),
    this.unit = const Value.absent(),
    this.purchasePrice = const Value.absent(),
    this.salePrice = const Value.absent(),
    this.minPrice = const Value.absent(),
    this.stockMin = const Value.absent(),
    this.description = const Value.absent(),
    this.isActive = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.brandId = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.productScope = const Value.absent(),
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       companyId = Value(companyId),
       name = Value(name),
       updatedAt = Value(updatedAt);
  static Insertable<LocalProduct> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? name,
    Expression<String>? sku,
    Expression<String>? barcode,
    Expression<String>? unit,
    Expression<double>? purchasePrice,
    Expression<double>? salePrice,
    Expression<double>? minPrice,
    Expression<int>? stockMin,
    Expression<String>? description,
    Expression<bool>? isActive,
    Expression<String>? categoryId,
    Expression<String>? brandId,
    Expression<String>? imageUrl,
    Expression<String>? productScope,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (name != null) 'name': name,
      if (sku != null) 'sku': sku,
      if (barcode != null) 'barcode': barcode,
      if (unit != null) 'unit': unit,
      if (purchasePrice != null) 'purchase_price': purchasePrice,
      if (salePrice != null) 'sale_price': salePrice,
      if (minPrice != null) 'min_price': minPrice,
      if (stockMin != null) 'stock_min': stockMin,
      if (description != null) 'description': description,
      if (isActive != null) 'is_active': isActive,
      if (categoryId != null) 'category_id': categoryId,
      if (brandId != null) 'brand_id': brandId,
      if (imageUrl != null) 'image_url': imageUrl,
      if (productScope != null) 'product_scope': productScope,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalProductsCompanion copyWith({
    Value<String>? id,
    Value<String>? companyId,
    Value<String>? name,
    Value<String?>? sku,
    Value<String?>? barcode,
    Value<String>? unit,
    Value<double>? purchasePrice,
    Value<double>? salePrice,
    Value<double?>? minPrice,
    Value<int>? stockMin,
    Value<String?>? description,
    Value<bool>? isActive,
    Value<String?>? categoryId,
    Value<String?>? brandId,
    Value<String?>? imageUrl,
    Value<String>? productScope,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalProductsCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      unit: unit ?? this.unit,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      salePrice: salePrice ?? this.salePrice,
      minPrice: minPrice ?? this.minPrice,
      stockMin: stockMin ?? this.stockMin,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      categoryId: categoryId ?? this.categoryId,
      brandId: brandId ?? this.brandId,
      imageUrl: imageUrl ?? this.imageUrl,
      productScope: productScope ?? this.productScope,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sku.present) {
      map['sku'] = Variable<String>(sku.value);
    }
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (purchasePrice.present) {
      map['purchase_price'] = Variable<double>(purchasePrice.value);
    }
    if (salePrice.present) {
      map['sale_price'] = Variable<double>(salePrice.value);
    }
    if (minPrice.present) {
      map['min_price'] = Variable<double>(minPrice.value);
    }
    if (stockMin.present) {
      map['stock_min'] = Variable<int>(stockMin.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (brandId.present) {
      map['brand_id'] = Variable<String>(brandId.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (productScope.present) {
      map['product_scope'] = Variable<String>(productScope.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalProductsCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('name: $name, ')
          ..write('sku: $sku, ')
          ..write('barcode: $barcode, ')
          ..write('unit: $unit, ')
          ..write('purchasePrice: $purchasePrice, ')
          ..write('salePrice: $salePrice, ')
          ..write('minPrice: $minPrice, ')
          ..write('stockMin: $stockMin, ')
          ..write('description: $description, ')
          ..write('isActive: $isActive, ')
          ..write('categoryId: $categoryId, ')
          ..write('brandId: $brandId, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('productScope: $productScope, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoreInventoryTable extends StoreInventory
    with TableInfo<$StoreInventoryTable, StoreInventoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoreInventoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _storeIdMeta = const VerificationMeta(
    'storeId',
  );
  @override
  late final GeneratedColumn<String> storeId = GeneratedColumn<String>(
    'store_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _reservedQuantityMeta = const VerificationMeta(
    'reservedQuantity',
  );
  @override
  late final GeneratedColumn<int> reservedQuantity = GeneratedColumn<int>(
    'reserved_quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    storeId,
    productId,
    quantity,
    reservedQuantity,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'store_inventory';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoreInventoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('store_id')) {
      context.handle(
        _storeIdMeta,
        storeId.isAcceptableOrUnknown(data['store_id']!, _storeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storeIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('reserved_quantity')) {
      context.handle(
        _reservedQuantityMeta,
        reservedQuantity.isAcceptableOrUnknown(
          data['reserved_quantity']!,
          _reservedQuantityMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {storeId, productId};
  @override
  StoreInventoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoreInventoryData(
      storeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
      reservedQuantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reserved_quantity'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $StoreInventoryTable createAlias(String alias) {
    return $StoreInventoryTable(attachedDatabase, alias);
  }
}

class StoreInventoryData extends DataClass
    implements Insertable<StoreInventoryData> {
  final String storeId;
  final String productId;
  final int quantity;
  final int reservedQuantity;
  final String updatedAt;
  const StoreInventoryData({
    required this.storeId,
    required this.productId,
    required this.quantity,
    required this.reservedQuantity,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['store_id'] = Variable<String>(storeId);
    map['product_id'] = Variable<String>(productId);
    map['quantity'] = Variable<int>(quantity);
    map['reserved_quantity'] = Variable<int>(reservedQuantity);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  StoreInventoryCompanion toCompanion(bool nullToAbsent) {
    return StoreInventoryCompanion(
      storeId: Value(storeId),
      productId: Value(productId),
      quantity: Value(quantity),
      reservedQuantity: Value(reservedQuantity),
      updatedAt: Value(updatedAt),
    );
  }

  factory StoreInventoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoreInventoryData(
      storeId: serializer.fromJson<String>(json['storeId']),
      productId: serializer.fromJson<String>(json['productId']),
      quantity: serializer.fromJson<int>(json['quantity']),
      reservedQuantity: serializer.fromJson<int>(json['reservedQuantity']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'storeId': serializer.toJson<String>(storeId),
      'productId': serializer.toJson<String>(productId),
      'quantity': serializer.toJson<int>(quantity),
      'reservedQuantity': serializer.toJson<int>(reservedQuantity),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  StoreInventoryData copyWith({
    String? storeId,
    String? productId,
    int? quantity,
    int? reservedQuantity,
    String? updatedAt,
  }) => StoreInventoryData(
    storeId: storeId ?? this.storeId,
    productId: productId ?? this.productId,
    quantity: quantity ?? this.quantity,
    reservedQuantity: reservedQuantity ?? this.reservedQuantity,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StoreInventoryData copyWithCompanion(StoreInventoryCompanion data) {
    return StoreInventoryData(
      storeId: data.storeId.present ? data.storeId.value : this.storeId,
      productId: data.productId.present ? data.productId.value : this.productId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      reservedQuantity: data.reservedQuantity.present
          ? data.reservedQuantity.value
          : this.reservedQuantity,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoreInventoryData(')
          ..write('storeId: $storeId, ')
          ..write('productId: $productId, ')
          ..write('quantity: $quantity, ')
          ..write('reservedQuantity: $reservedQuantity, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(storeId, productId, quantity, reservedQuantity, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoreInventoryData &&
          other.storeId == this.storeId &&
          other.productId == this.productId &&
          other.quantity == this.quantity &&
          other.reservedQuantity == this.reservedQuantity &&
          other.updatedAt == this.updatedAt);
}

class StoreInventoryCompanion extends UpdateCompanion<StoreInventoryData> {
  final Value<String> storeId;
  final Value<String> productId;
  final Value<int> quantity;
  final Value<int> reservedQuantity;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const StoreInventoryCompanion({
    this.storeId = const Value.absent(),
    this.productId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.reservedQuantity = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoreInventoryCompanion.insert({
    required String storeId,
    required String productId,
    this.quantity = const Value.absent(),
    this.reservedQuantity = const Value.absent(),
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : storeId = Value(storeId),
       productId = Value(productId),
       updatedAt = Value(updatedAt);
  static Insertable<StoreInventoryData> custom({
    Expression<String>? storeId,
    Expression<String>? productId,
    Expression<int>? quantity,
    Expression<int>? reservedQuantity,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (storeId != null) 'store_id': storeId,
      if (productId != null) 'product_id': productId,
      if (quantity != null) 'quantity': quantity,
      if (reservedQuantity != null) 'reserved_quantity': reservedQuantity,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoreInventoryCompanion copyWith({
    Value<String>? storeId,
    Value<String>? productId,
    Value<int>? quantity,
    Value<int>? reservedQuantity,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return StoreInventoryCompanion(
      storeId: storeId ?? this.storeId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      reservedQuantity: reservedQuantity ?? this.reservedQuantity,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (storeId.present) {
      map['store_id'] = Variable<String>(storeId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (reservedQuantity.present) {
      map['reserved_quantity'] = Variable<int>(reservedQuantity.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoreInventoryCompanion(')
          ..write('storeId: $storeId, ')
          ..write('productId: $productId, ')
          ..write('quantity: $quantity, ')
          ..write('reservedQuantity: $reservedQuantity, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSalesTable extends LocalSales
    with TableInfo<$LocalSalesTable, LocalSale> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSalesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storeIdMeta = const VerificationMeta(
    'storeId',
  );
  @override
  late final GeneratedColumn<String> storeId = GeneratedColumn<String>(
    'store_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta(
    'customerId',
  );
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
    'customer_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _saleNumberMeta = const VerificationMeta(
    'saleNumber',
  );
  @override
  late final GeneratedColumn<String> saleNumber = GeneratedColumn<String>(
    'sale_number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subtotalMeta = const VerificationMeta(
    'subtotal',
  );
  @override
  late final GeneratedColumn<double> subtotal = GeneratedColumn<double>(
    'subtotal',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _discountMeta = const VerificationMeta(
    'discount',
  );
  @override
  late final GeneratedColumn<double> discount = GeneratedColumn<double>(
    'discount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _taxMeta = const VerificationMeta('tax');
  @override
  late final GeneratedColumn<double> tax = GeneratedColumn<double>(
    'tax',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<double> total = GeneratedColumn<double>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _saleModeMeta = const VerificationMeta(
    'saleMode',
  );
  @override
  late final GeneratedColumn<String> saleMode = GeneratedColumn<String>(
    'sale_mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _documentTypeMeta = const VerificationMeta(
    'documentType',
  );
  @override
  late final GeneratedColumn<String> documentType = GeneratedColumn<String>(
    'document_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    companyId,
    storeId,
    customerId,
    saleNumber,
    status,
    subtotal,
    discount,
    tax,
    total,
    createdBy,
    createdAt,
    updatedAt,
    synced,
    saleMode,
    documentType,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_sales';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalSale> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('store_id')) {
      context.handle(
        _storeIdMeta,
        storeId.isAcceptableOrUnknown(data['store_id']!, _storeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storeIdMeta);
    }
    if (data.containsKey('customer_id')) {
      context.handle(
        _customerIdMeta,
        customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta),
      );
    }
    if (data.containsKey('sale_number')) {
      context.handle(
        _saleNumberMeta,
        saleNumber.isAcceptableOrUnknown(data['sale_number']!, _saleNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_saleNumberMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('subtotal')) {
      context.handle(
        _subtotalMeta,
        subtotal.isAcceptableOrUnknown(data['subtotal']!, _subtotalMeta),
      );
    }
    if (data.containsKey('discount')) {
      context.handle(
        _discountMeta,
        discount.isAcceptableOrUnknown(data['discount']!, _discountMeta),
      );
    }
    if (data.containsKey('tax')) {
      context.handle(
        _taxMeta,
        tax.isAcceptableOrUnknown(data['tax']!, _taxMeta),
      );
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    if (data.containsKey('sale_mode')) {
      context.handle(
        _saleModeMeta,
        saleMode.isAcceptableOrUnknown(data['sale_mode']!, _saleModeMeta),
      );
    }
    if (data.containsKey('document_type')) {
      context.handle(
        _documentTypeMeta,
        documentType.isAcceptableOrUnknown(
          data['document_type']!,
          _documentTypeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalSale map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSale(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      storeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_id'],
      )!,
      customerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_id'],
      ),
      saleNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sale_number'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      subtotal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}subtotal'],
      )!,
      discount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}discount'],
      )!,
      tax: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}tax'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
      saleMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sale_mode'],
      ),
      documentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_type'],
      ),
    );
  }

  @override
  $LocalSalesTable createAlias(String alias) {
    return $LocalSalesTable(attachedDatabase, alias);
  }
}

class LocalSale extends DataClass implements Insertable<LocalSale> {
  final String id;
  final String companyId;
  final String storeId;
  final String? customerId;
  final String saleNumber;
  final String status;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final String createdBy;
  final String createdAt;
  final String updatedAt;
  final bool synced;

  /// quick_pos | invoice_pos — pour distinguer A4 vs Thermique dans la liste.
  final String? saleMode;

  /// thermal_receipt | a4_invoice — source de vérité pour l'affichage type document.
  final String? documentType;
  const LocalSale({
    required this.id,
    required this.companyId,
    required this.storeId,
    this.customerId,
    required this.saleNumber,
    required this.status,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.synced,
    this.saleMode,
    this.documentType,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_id'] = Variable<String>(companyId);
    map['store_id'] = Variable<String>(storeId);
    if (!nullToAbsent || customerId != null) {
      map['customer_id'] = Variable<String>(customerId);
    }
    map['sale_number'] = Variable<String>(saleNumber);
    map['status'] = Variable<String>(status);
    map['subtotal'] = Variable<double>(subtotal);
    map['discount'] = Variable<double>(discount);
    map['tax'] = Variable<double>(tax);
    map['total'] = Variable<double>(total);
    map['created_by'] = Variable<String>(createdBy);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    map['synced'] = Variable<bool>(synced);
    if (!nullToAbsent || saleMode != null) {
      map['sale_mode'] = Variable<String>(saleMode);
    }
    if (!nullToAbsent || documentType != null) {
      map['document_type'] = Variable<String>(documentType);
    }
    return map;
  }

  LocalSalesCompanion toCompanion(bool nullToAbsent) {
    return LocalSalesCompanion(
      id: Value(id),
      companyId: Value(companyId),
      storeId: Value(storeId),
      customerId: customerId == null && nullToAbsent
          ? const Value.absent()
          : Value(customerId),
      saleNumber: Value(saleNumber),
      status: Value(status),
      subtotal: Value(subtotal),
      discount: Value(discount),
      tax: Value(tax),
      total: Value(total),
      createdBy: Value(createdBy),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      synced: Value(synced),
      saleMode: saleMode == null && nullToAbsent
          ? const Value.absent()
          : Value(saleMode),
      documentType: documentType == null && nullToAbsent
          ? const Value.absent()
          : Value(documentType),
    );
  }

  factory LocalSale.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSale(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String>(json['companyId']),
      storeId: serializer.fromJson<String>(json['storeId']),
      customerId: serializer.fromJson<String?>(json['customerId']),
      saleNumber: serializer.fromJson<String>(json['saleNumber']),
      status: serializer.fromJson<String>(json['status']),
      subtotal: serializer.fromJson<double>(json['subtotal']),
      discount: serializer.fromJson<double>(json['discount']),
      tax: serializer.fromJson<double>(json['tax']),
      total: serializer.fromJson<double>(json['total']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      synced: serializer.fromJson<bool>(json['synced']),
      saleMode: serializer.fromJson<String?>(json['saleMode']),
      documentType: serializer.fromJson<String?>(json['documentType']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String>(companyId),
      'storeId': serializer.toJson<String>(storeId),
      'customerId': serializer.toJson<String?>(customerId),
      'saleNumber': serializer.toJson<String>(saleNumber),
      'status': serializer.toJson<String>(status),
      'subtotal': serializer.toJson<double>(subtotal),
      'discount': serializer.toJson<double>(discount),
      'tax': serializer.toJson<double>(tax),
      'total': serializer.toJson<double>(total),
      'createdBy': serializer.toJson<String>(createdBy),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'synced': serializer.toJson<bool>(synced),
      'saleMode': serializer.toJson<String?>(saleMode),
      'documentType': serializer.toJson<String?>(documentType),
    };
  }

  LocalSale copyWith({
    String? id,
    String? companyId,
    String? storeId,
    Value<String?> customerId = const Value.absent(),
    String? saleNumber,
    String? status,
    double? subtotal,
    double? discount,
    double? tax,
    double? total,
    String? createdBy,
    String? createdAt,
    String? updatedAt,
    bool? synced,
    Value<String?> saleMode = const Value.absent(),
    Value<String?> documentType = const Value.absent(),
  }) => LocalSale(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    storeId: storeId ?? this.storeId,
    customerId: customerId.present ? customerId.value : this.customerId,
    saleNumber: saleNumber ?? this.saleNumber,
    status: status ?? this.status,
    subtotal: subtotal ?? this.subtotal,
    discount: discount ?? this.discount,
    tax: tax ?? this.tax,
    total: total ?? this.total,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    synced: synced ?? this.synced,
    saleMode: saleMode.present ? saleMode.value : this.saleMode,
    documentType: documentType.present ? documentType.value : this.documentType,
  );
  LocalSale copyWithCompanion(LocalSalesCompanion data) {
    return LocalSale(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      storeId: data.storeId.present ? data.storeId.value : this.storeId,
      customerId: data.customerId.present
          ? data.customerId.value
          : this.customerId,
      saleNumber: data.saleNumber.present
          ? data.saleNumber.value
          : this.saleNumber,
      status: data.status.present ? data.status.value : this.status,
      subtotal: data.subtotal.present ? data.subtotal.value : this.subtotal,
      discount: data.discount.present ? data.discount.value : this.discount,
      tax: data.tax.present ? data.tax.value : this.tax,
      total: data.total.present ? data.total.value : this.total,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      synced: data.synced.present ? data.synced.value : this.synced,
      saleMode: data.saleMode.present ? data.saleMode.value : this.saleMode,
      documentType: data.documentType.present
          ? data.documentType.value
          : this.documentType,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSale(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('storeId: $storeId, ')
          ..write('customerId: $customerId, ')
          ..write('saleNumber: $saleNumber, ')
          ..write('status: $status, ')
          ..write('subtotal: $subtotal, ')
          ..write('discount: $discount, ')
          ..write('tax: $tax, ')
          ..write('total: $total, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('synced: $synced, ')
          ..write('saleMode: $saleMode, ')
          ..write('documentType: $documentType')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    companyId,
    storeId,
    customerId,
    saleNumber,
    status,
    subtotal,
    discount,
    tax,
    total,
    createdBy,
    createdAt,
    updatedAt,
    synced,
    saleMode,
    documentType,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSale &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.storeId == this.storeId &&
          other.customerId == this.customerId &&
          other.saleNumber == this.saleNumber &&
          other.status == this.status &&
          other.subtotal == this.subtotal &&
          other.discount == this.discount &&
          other.tax == this.tax &&
          other.total == this.total &&
          other.createdBy == this.createdBy &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.synced == this.synced &&
          other.saleMode == this.saleMode &&
          other.documentType == this.documentType);
}

class LocalSalesCompanion extends UpdateCompanion<LocalSale> {
  final Value<String> id;
  final Value<String> companyId;
  final Value<String> storeId;
  final Value<String?> customerId;
  final Value<String> saleNumber;
  final Value<String> status;
  final Value<double> subtotal;
  final Value<double> discount;
  final Value<double> tax;
  final Value<double> total;
  final Value<String> createdBy;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<bool> synced;
  final Value<String?> saleMode;
  final Value<String?> documentType;
  final Value<int> rowid;
  const LocalSalesCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.storeId = const Value.absent(),
    this.customerId = const Value.absent(),
    this.saleNumber = const Value.absent(),
    this.status = const Value.absent(),
    this.subtotal = const Value.absent(),
    this.discount = const Value.absent(),
    this.tax = const Value.absent(),
    this.total = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.synced = const Value.absent(),
    this.saleMode = const Value.absent(),
    this.documentType = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSalesCompanion.insert({
    required String id,
    required String companyId,
    required String storeId,
    this.customerId = const Value.absent(),
    required String saleNumber,
    required String status,
    this.subtotal = const Value.absent(),
    this.discount = const Value.absent(),
    this.tax = const Value.absent(),
    required double total,
    required String createdBy,
    required String createdAt,
    required String updatedAt,
    this.synced = const Value.absent(),
    this.saleMode = const Value.absent(),
    this.documentType = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       companyId = Value(companyId),
       storeId = Value(storeId),
       saleNumber = Value(saleNumber),
       status = Value(status),
       total = Value(total),
       createdBy = Value(createdBy),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LocalSale> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? storeId,
    Expression<String>? customerId,
    Expression<String>? saleNumber,
    Expression<String>? status,
    Expression<double>? subtotal,
    Expression<double>? discount,
    Expression<double>? tax,
    Expression<double>? total,
    Expression<String>? createdBy,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<bool>? synced,
    Expression<String>? saleMode,
    Expression<String>? documentType,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (storeId != null) 'store_id': storeId,
      if (customerId != null) 'customer_id': customerId,
      if (saleNumber != null) 'sale_number': saleNumber,
      if (status != null) 'status': status,
      if (subtotal != null) 'subtotal': subtotal,
      if (discount != null) 'discount': discount,
      if (tax != null) 'tax': tax,
      if (total != null) 'total': total,
      if (createdBy != null) 'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (synced != null) 'synced': synced,
      if (saleMode != null) 'sale_mode': saleMode,
      if (documentType != null) 'document_type': documentType,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSalesCompanion copyWith({
    Value<String>? id,
    Value<String>? companyId,
    Value<String>? storeId,
    Value<String?>? customerId,
    Value<String>? saleNumber,
    Value<String>? status,
    Value<double>? subtotal,
    Value<double>? discount,
    Value<double>? tax,
    Value<double>? total,
    Value<String>? createdBy,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<bool>? synced,
    Value<String?>? saleMode,
    Value<String?>? documentType,
    Value<int>? rowid,
  }) {
    return LocalSalesCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      storeId: storeId ?? this.storeId,
      customerId: customerId ?? this.customerId,
      saleNumber: saleNumber ?? this.saleNumber,
      status: status ?? this.status,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
      saleMode: saleMode ?? this.saleMode,
      documentType: documentType ?? this.documentType,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (storeId.present) {
      map['store_id'] = Variable<String>(storeId.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (saleNumber.present) {
      map['sale_number'] = Variable<String>(saleNumber.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (subtotal.present) {
      map['subtotal'] = Variable<double>(subtotal.value);
    }
    if (discount.present) {
      map['discount'] = Variable<double>(discount.value);
    }
    if (tax.present) {
      map['tax'] = Variable<double>(tax.value);
    }
    if (total.present) {
      map['total'] = Variable<double>(total.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (saleMode.present) {
      map['sale_mode'] = Variable<String>(saleMode.value);
    }
    if (documentType.present) {
      map['document_type'] = Variable<String>(documentType.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSalesCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('storeId: $storeId, ')
          ..write('customerId: $customerId, ')
          ..write('saleNumber: $saleNumber, ')
          ..write('status: $status, ')
          ..write('subtotal: $subtotal, ')
          ..write('discount: $discount, ')
          ..write('tax: $tax, ')
          ..write('total: $total, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('synced: $synced, ')
          ..write('saleMode: $saleMode, ')
          ..write('documentType: $documentType, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSaleItemsTable extends LocalSaleItems
    with TableInfo<$LocalSaleItemsTable, LocalSaleItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSaleItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _saleIdMeta = const VerificationMeta('saleId');
  @override
  late final GeneratedColumn<String> saleId = GeneratedColumn<String>(
    'sale_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_sales (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitPriceMeta = const VerificationMeta(
    'unitPrice',
  );
  @override
  late final GeneratedColumn<double> unitPrice = GeneratedColumn<double>(
    'unit_price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<double> total = GeneratedColumn<double>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    saleId,
    productId,
    quantity,
    unitPrice,
    total,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_sale_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalSaleItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('sale_id')) {
      context.handle(
        _saleIdMeta,
        saleId.isAcceptableOrUnknown(data['sale_id']!, _saleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_saleIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('unit_price')) {
      context.handle(
        _unitPriceMeta,
        unitPrice.isAcceptableOrUnknown(data['unit_price']!, _unitPriceMeta),
      );
    } else if (isInserting) {
      context.missing(_unitPriceMeta);
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalSaleItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSaleItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      saleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sale_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
      unitPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}unit_price'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LocalSaleItemsTable createAlias(String alias) {
    return $LocalSaleItemsTable(attachedDatabase, alias);
  }
}

class LocalSaleItem extends DataClass implements Insertable<LocalSaleItem> {
  final String id;
  final String saleId;
  final String productId;
  final int quantity;
  final double unitPrice;
  final double total;
  final String createdAt;
  const LocalSaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['sale_id'] = Variable<String>(saleId);
    map['product_id'] = Variable<String>(productId);
    map['quantity'] = Variable<int>(quantity);
    map['unit_price'] = Variable<double>(unitPrice);
    map['total'] = Variable<double>(total);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  LocalSaleItemsCompanion toCompanion(bool nullToAbsent) {
    return LocalSaleItemsCompanion(
      id: Value(id),
      saleId: Value(saleId),
      productId: Value(productId),
      quantity: Value(quantity),
      unitPrice: Value(unitPrice),
      total: Value(total),
      createdAt: Value(createdAt),
    );
  }

  factory LocalSaleItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSaleItem(
      id: serializer.fromJson<String>(json['id']),
      saleId: serializer.fromJson<String>(json['saleId']),
      productId: serializer.fromJson<String>(json['productId']),
      quantity: serializer.fromJson<int>(json['quantity']),
      unitPrice: serializer.fromJson<double>(json['unitPrice']),
      total: serializer.fromJson<double>(json['total']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'saleId': serializer.toJson<String>(saleId),
      'productId': serializer.toJson<String>(productId),
      'quantity': serializer.toJson<int>(quantity),
      'unitPrice': serializer.toJson<double>(unitPrice),
      'total': serializer.toJson<double>(total),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  LocalSaleItem copyWith({
    String? id,
    String? saleId,
    String? productId,
    int? quantity,
    double? unitPrice,
    double? total,
    String? createdAt,
  }) => LocalSaleItem(
    id: id ?? this.id,
    saleId: saleId ?? this.saleId,
    productId: productId ?? this.productId,
    quantity: quantity ?? this.quantity,
    unitPrice: unitPrice ?? this.unitPrice,
    total: total ?? this.total,
    createdAt: createdAt ?? this.createdAt,
  );
  LocalSaleItem copyWithCompanion(LocalSaleItemsCompanion data) {
    return LocalSaleItem(
      id: data.id.present ? data.id.value : this.id,
      saleId: data.saleId.present ? data.saleId.value : this.saleId,
      productId: data.productId.present ? data.productId.value : this.productId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unitPrice: data.unitPrice.present ? data.unitPrice.value : this.unitPrice,
      total: data.total.present ? data.total.value : this.total,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSaleItem(')
          ..write('id: $id, ')
          ..write('saleId: $saleId, ')
          ..write('productId: $productId, ')
          ..write('quantity: $quantity, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('total: $total, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, saleId, productId, quantity, unitPrice, total, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSaleItem &&
          other.id == this.id &&
          other.saleId == this.saleId &&
          other.productId == this.productId &&
          other.quantity == this.quantity &&
          other.unitPrice == this.unitPrice &&
          other.total == this.total &&
          other.createdAt == this.createdAt);
}

class LocalSaleItemsCompanion extends UpdateCompanion<LocalSaleItem> {
  final Value<String> id;
  final Value<String> saleId;
  final Value<String> productId;
  final Value<int> quantity;
  final Value<double> unitPrice;
  final Value<double> total;
  final Value<String> createdAt;
  final Value<int> rowid;
  const LocalSaleItemsCompanion({
    this.id = const Value.absent(),
    this.saleId = const Value.absent(),
    this.productId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unitPrice = const Value.absent(),
    this.total = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSaleItemsCompanion.insert({
    required String id,
    required String saleId,
    required String productId,
    required int quantity,
    required double unitPrice,
    required double total,
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       saleId = Value(saleId),
       productId = Value(productId),
       quantity = Value(quantity),
       unitPrice = Value(unitPrice),
       total = Value(total),
       createdAt = Value(createdAt);
  static Insertable<LocalSaleItem> custom({
    Expression<String>? id,
    Expression<String>? saleId,
    Expression<String>? productId,
    Expression<int>? quantity,
    Expression<double>? unitPrice,
    Expression<double>? total,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (saleId != null) 'sale_id': saleId,
      if (productId != null) 'product_id': productId,
      if (quantity != null) 'quantity': quantity,
      if (unitPrice != null) 'unit_price': unitPrice,
      if (total != null) 'total': total,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSaleItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? saleId,
    Value<String>? productId,
    Value<int>? quantity,
    Value<double>? unitPrice,
    Value<double>? total,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return LocalSaleItemsCompanion(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      total: total ?? this.total,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (saleId.present) {
      map['sale_id'] = Variable<String>(saleId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (unitPrice.present) {
      map['unit_price'] = Variable<double>(unitPrice.value);
    }
    if (total.present) {
      map['total'] = Variable<double>(total.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSaleItemsCompanion(')
          ..write('id: $id, ')
          ..write('saleId: $saleId, ')
          ..write('productId: $productId, ')
          ..write('quantity: $quantity, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('total: $total, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalCustomersTable extends LocalCustomers
    with TableInfo<$LocalCustomersTable, LocalCustomer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalCustomersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('individual'),
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    companyId,
    name,
    type,
    phone,
    email,
    address,
    notes,
    createdAt,
    updatedAt,
    synced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_customers';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalCustomer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalCustomer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalCustomer(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
    );
  }

  @override
  $LocalCustomersTable createAlias(String alias) {
    return $LocalCustomersTable(attachedDatabase, alias);
  }
}

class LocalCustomer extends DataClass implements Insertable<LocalCustomer> {
  final String id;
  final String companyId;
  final String name;
  final String type;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final bool synced;
  const LocalCustomer({
    required this.id,
    required this.companyId,
    required this.name,
    required this.type,
    this.phone,
    this.email,
    this.address,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.synced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_id'] = Variable<String>(companyId);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  LocalCustomersCompanion toCompanion(bool nullToAbsent) {
    return LocalCustomersCompanion(
      id: Value(id),
      companyId: Value(companyId),
      name: Value(name),
      type: Value(type),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      synced: Value(synced),
    );
  }

  factory LocalCustomer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalCustomer(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String>(json['companyId']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      phone: serializer.fromJson<String?>(json['phone']),
      email: serializer.fromJson<String?>(json['email']),
      address: serializer.fromJson<String?>(json['address']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String>(companyId),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'phone': serializer.toJson<String?>(phone),
      'email': serializer.toJson<String?>(email),
      'address': serializer.toJson<String?>(address),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  LocalCustomer copyWith({
    String? id,
    String? companyId,
    String? name,
    String? type,
    Value<String?> phone = const Value.absent(),
    Value<String?> email = const Value.absent(),
    Value<String?> address = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    String? createdAt,
    String? updatedAt,
    bool? synced,
  }) => LocalCustomer(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    name: name ?? this.name,
    type: type ?? this.type,
    phone: phone.present ? phone.value : this.phone,
    email: email.present ? email.value : this.email,
    address: address.present ? address.value : this.address,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    synced: synced ?? this.synced,
  );
  LocalCustomer copyWithCompanion(LocalCustomersCompanion data) {
    return LocalCustomer(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      phone: data.phone.present ? data.phone.value : this.phone,
      email: data.email.present ? data.email.value : this.email,
      address: data.address.present ? data.address.value : this.address,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalCustomer(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('address: $address, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    companyId,
    name,
    type,
    phone,
    email,
    address,
    notes,
    createdAt,
    updatedAt,
    synced,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalCustomer &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.name == this.name &&
          other.type == this.type &&
          other.phone == this.phone &&
          other.email == this.email &&
          other.address == this.address &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.synced == this.synced);
}

class LocalCustomersCompanion extends UpdateCompanion<LocalCustomer> {
  final Value<String> id;
  final Value<String> companyId;
  final Value<String> name;
  final Value<String> type;
  final Value<String?> phone;
  final Value<String?> email;
  final Value<String?> address;
  final Value<String?> notes;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<bool> synced;
  final Value<int> rowid;
  const LocalCustomersCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.address = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalCustomersCompanion.insert({
    required String id,
    required String companyId,
    required String name,
    this.type = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.address = const Value.absent(),
    this.notes = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       companyId = Value(companyId),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LocalCustomer> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? phone,
    Expression<String>? email,
    Expression<String>? address,
    Expression<String>? notes,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<bool>? synced,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (address != null) 'address': address,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (synced != null) 'synced': synced,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalCustomersCompanion copyWith({
    Value<String>? id,
    Value<String>? companyId,
    Value<String>? name,
    Value<String>? type,
    Value<String?>? phone,
    Value<String?>? email,
    Value<String?>? address,
    Value<String?>? notes,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<bool>? synced,
    Value<int>? rowid,
  }) {
    return LocalCustomersCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      type: type ?? this.type,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalCustomersCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('address: $address, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('synced: $synced, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSuppliersTable extends LocalSuppliers
    with TableInfo<$LocalSuppliersTable, LocalSupplier> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSuppliersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contactMeta = const VerificationMeta(
    'contact',
  );
  @override
  late final GeneratedColumn<String> contact = GeneratedColumn<String>(
    'contact',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    companyId,
    name,
    contact,
    phone,
    email,
    address,
    notes,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_suppliers';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalSupplier> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('contact')) {
      context.handle(
        _contactMeta,
        contact.isAcceptableOrUnknown(data['contact']!, _contactMeta),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalSupplier map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSupplier(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      contact: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact'],
      ),
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalSuppliersTable createAlias(String alias) {
    return $LocalSuppliersTable(attachedDatabase, alias);
  }
}

class LocalSupplier extends DataClass implements Insertable<LocalSupplier> {
  final String id;
  final String companyId;
  final String name;
  final String? contact;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final String updatedAt;
  const LocalSupplier({
    required this.id,
    required this.companyId,
    required this.name,
    this.contact,
    this.phone,
    this.email,
    this.address,
    this.notes,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_id'] = Variable<String>(companyId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || contact != null) {
      map['contact'] = Variable<String>(contact);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  LocalSuppliersCompanion toCompanion(bool nullToAbsent) {
    return LocalSuppliersCompanion(
      id: Value(id),
      companyId: Value(companyId),
      name: Value(name),
      contact: contact == null && nullToAbsent
          ? const Value.absent()
          : Value(contact),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalSupplier.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSupplier(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String>(json['companyId']),
      name: serializer.fromJson<String>(json['name']),
      contact: serializer.fromJson<String?>(json['contact']),
      phone: serializer.fromJson<String?>(json['phone']),
      email: serializer.fromJson<String?>(json['email']),
      address: serializer.fromJson<String?>(json['address']),
      notes: serializer.fromJson<String?>(json['notes']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String>(companyId),
      'name': serializer.toJson<String>(name),
      'contact': serializer.toJson<String?>(contact),
      'phone': serializer.toJson<String?>(phone),
      'email': serializer.toJson<String?>(email),
      'address': serializer.toJson<String?>(address),
      'notes': serializer.toJson<String?>(notes),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  LocalSupplier copyWith({
    String? id,
    String? companyId,
    String? name,
    Value<String?> contact = const Value.absent(),
    Value<String?> phone = const Value.absent(),
    Value<String?> email = const Value.absent(),
    Value<String?> address = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    String? updatedAt,
  }) => LocalSupplier(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    name: name ?? this.name,
    contact: contact.present ? contact.value : this.contact,
    phone: phone.present ? phone.value : this.phone,
    email: email.present ? email.value : this.email,
    address: address.present ? address.value : this.address,
    notes: notes.present ? notes.value : this.notes,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalSupplier copyWithCompanion(LocalSuppliersCompanion data) {
    return LocalSupplier(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      name: data.name.present ? data.name.value : this.name,
      contact: data.contact.present ? data.contact.value : this.contact,
      phone: data.phone.present ? data.phone.value : this.phone,
      email: data.email.present ? data.email.value : this.email,
      address: data.address.present ? data.address.value : this.address,
      notes: data.notes.present ? data.notes.value : this.notes,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSupplier(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('name: $name, ')
          ..write('contact: $contact, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('address: $address, ')
          ..write('notes: $notes, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    companyId,
    name,
    contact,
    phone,
    email,
    address,
    notes,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSupplier &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.name == this.name &&
          other.contact == this.contact &&
          other.phone == this.phone &&
          other.email == this.email &&
          other.address == this.address &&
          other.notes == this.notes &&
          other.updatedAt == this.updatedAt);
}

class LocalSuppliersCompanion extends UpdateCompanion<LocalSupplier> {
  final Value<String> id;
  final Value<String> companyId;
  final Value<String> name;
  final Value<String?> contact;
  final Value<String?> phone;
  final Value<String?> email;
  final Value<String?> address;
  final Value<String?> notes;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const LocalSuppliersCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.name = const Value.absent(),
    this.contact = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.address = const Value.absent(),
    this.notes = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSuppliersCompanion.insert({
    required String id,
    required String companyId,
    required String name,
    this.contact = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.address = const Value.absent(),
    this.notes = const Value.absent(),
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       companyId = Value(companyId),
       name = Value(name),
       updatedAt = Value(updatedAt);
  static Insertable<LocalSupplier> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? name,
    Expression<String>? contact,
    Expression<String>? phone,
    Expression<String>? email,
    Expression<String>? address,
    Expression<String>? notes,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (name != null) 'name': name,
      if (contact != null) 'contact': contact,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (address != null) 'address': address,
      if (notes != null) 'notes': notes,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSuppliersCompanion copyWith({
    Value<String>? id,
    Value<String>? companyId,
    Value<String>? name,
    Value<String?>? contact,
    Value<String?>? phone,
    Value<String?>? email,
    Value<String?>? address,
    Value<String?>? notes,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalSuppliersCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      contact: contact ?? this.contact,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (contact.present) {
      map['contact'] = Variable<String>(contact.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSuppliersCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('name: $name, ')
          ..write('contact: $contact, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('address: $address, ')
          ..write('notes: $notes, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalStoresTable extends LocalStores
    with TableInfo<$LocalStoresTable, LocalStore> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalStoresTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _logoUrlMeta = const VerificationMeta(
    'logoUrl',
  );
  @override
  late final GeneratedColumn<String> logoUrl = GeneratedColumn<String>(
    'logo_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isPrimaryMeta = const VerificationMeta(
    'isPrimary',
  );
  @override
  late final GeneratedColumn<bool> isPrimary = GeneratedColumn<bool>(
    'is_primary',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_primary" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _posDiscountEnabledMeta =
      const VerificationMeta('posDiscountEnabled');
  @override
  late final GeneratedColumn<bool> posDiscountEnabled = GeneratedColumn<bool>(
    'pos_discount_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pos_discount_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _primaryColorMeta = const VerificationMeta(
    'primaryColor',
  );
  @override
  late final GeneratedColumn<String> primaryColor = GeneratedColumn<String>(
    'primary_color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _secondaryColorMeta = const VerificationMeta(
    'secondaryColor',
  );
  @override
  late final GeneratedColumn<String> secondaryColor = GeneratedColumn<String>(
    'secondary_color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _invoicePrefixMeta = const VerificationMeta(
    'invoicePrefix',
  );
  @override
  late final GeneratedColumn<String> invoicePrefix = GeneratedColumn<String>(
    'invoice_prefix',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _footerTextMeta = const VerificationMeta(
    'footerText',
  );
  @override
  late final GeneratedColumn<String> footerText = GeneratedColumn<String>(
    'footer_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _legalInfoMeta = const VerificationMeta(
    'legalInfo',
  );
  @override
  late final GeneratedColumn<String> legalInfo = GeneratedColumn<String>(
    'legal_info',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _signatureUrlMeta = const VerificationMeta(
    'signatureUrl',
  );
  @override
  late final GeneratedColumn<String> signatureUrl = GeneratedColumn<String>(
    'signature_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stampUrlMeta = const VerificationMeta(
    'stampUrl',
  );
  @override
  late final GeneratedColumn<String> stampUrl = GeneratedColumn<String>(
    'stamp_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paymentTermsMeta = const VerificationMeta(
    'paymentTerms',
  );
  @override
  late final GeneratedColumn<String> paymentTerms = GeneratedColumn<String>(
    'payment_terms',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taxLabelMeta = const VerificationMeta(
    'taxLabel',
  );
  @override
  late final GeneratedColumn<String> taxLabel = GeneratedColumn<String>(
    'tax_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taxNumberMeta = const VerificationMeta(
    'taxNumber',
  );
  @override
  late final GeneratedColumn<String> taxNumber = GeneratedColumn<String>(
    'tax_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  @override
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
    'city',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _countryMeta = const VerificationMeta(
    'country',
  );
  @override
  late final GeneratedColumn<String> country = GeneratedColumn<String>(
    'country',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _commercialNameMeta = const VerificationMeta(
    'commercialName',
  );
  @override
  late final GeneratedColumn<String> commercialName = GeneratedColumn<String>(
    'commercial_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sloganMeta = const VerificationMeta('slogan');
  @override
  late final GeneratedColumn<String> slogan = GeneratedColumn<String>(
    'slogan',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activityMeta = const VerificationMeta(
    'activity',
  );
  @override
  late final GeneratedColumn<String> activity = GeneratedColumn<String>(
    'activity',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mobileMoneyMeta = const VerificationMeta(
    'mobileMoney',
  );
  @override
  late final GeneratedColumn<String> mobileMoney = GeneratedColumn<String>(
    'mobile_money',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _invoiceShortTitleMeta = const VerificationMeta(
    'invoiceShortTitle',
  );
  @override
  late final GeneratedColumn<String> invoiceShortTitle =
      GeneratedColumn<String>(
        'invoice_short_title',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _invoiceSignerTitleMeta =
      const VerificationMeta('invoiceSignerTitle');
  @override
  late final GeneratedColumn<String> invoiceSignerTitle =
      GeneratedColumn<String>(
        'invoice_signer_title',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _invoiceSignerNameMeta = const VerificationMeta(
    'invoiceSignerName',
  );
  @override
  late final GeneratedColumn<String> invoiceSignerName =
      GeneratedColumn<String>(
        'invoice_signer_name',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _invoiceTemplateMeta = const VerificationMeta(
    'invoiceTemplate',
  );
  @override
  late final GeneratedColumn<String> invoiceTemplate = GeneratedColumn<String>(
    'invoice_template',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    companyId,
    name,
    code,
    address,
    logoUrl,
    phone,
    email,
    description,
    isActive,
    isPrimary,
    posDiscountEnabled,
    updatedAt,
    currency,
    primaryColor,
    secondaryColor,
    invoicePrefix,
    footerText,
    legalInfo,
    signatureUrl,
    stampUrl,
    paymentTerms,
    taxLabel,
    taxNumber,
    city,
    country,
    commercialName,
    slogan,
    activity,
    mobileMoney,
    invoiceShortTitle,
    invoiceSignerTitle,
    invoiceSignerName,
    invoiceTemplate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_stores';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalStore> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('logo_url')) {
      context.handle(
        _logoUrlMeta,
        logoUrl.isAcceptableOrUnknown(data['logo_url']!, _logoUrlMeta),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('is_primary')) {
      context.handle(
        _isPrimaryMeta,
        isPrimary.isAcceptableOrUnknown(data['is_primary']!, _isPrimaryMeta),
      );
    }
    if (data.containsKey('pos_discount_enabled')) {
      context.handle(
        _posDiscountEnabledMeta,
        posDiscountEnabled.isAcceptableOrUnknown(
          data['pos_discount_enabled']!,
          _posDiscountEnabledMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('primary_color')) {
      context.handle(
        _primaryColorMeta,
        primaryColor.isAcceptableOrUnknown(
          data['primary_color']!,
          _primaryColorMeta,
        ),
      );
    }
    if (data.containsKey('secondary_color')) {
      context.handle(
        _secondaryColorMeta,
        secondaryColor.isAcceptableOrUnknown(
          data['secondary_color']!,
          _secondaryColorMeta,
        ),
      );
    }
    if (data.containsKey('invoice_prefix')) {
      context.handle(
        _invoicePrefixMeta,
        invoicePrefix.isAcceptableOrUnknown(
          data['invoice_prefix']!,
          _invoicePrefixMeta,
        ),
      );
    }
    if (data.containsKey('footer_text')) {
      context.handle(
        _footerTextMeta,
        footerText.isAcceptableOrUnknown(data['footer_text']!, _footerTextMeta),
      );
    }
    if (data.containsKey('legal_info')) {
      context.handle(
        _legalInfoMeta,
        legalInfo.isAcceptableOrUnknown(data['legal_info']!, _legalInfoMeta),
      );
    }
    if (data.containsKey('signature_url')) {
      context.handle(
        _signatureUrlMeta,
        signatureUrl.isAcceptableOrUnknown(
          data['signature_url']!,
          _signatureUrlMeta,
        ),
      );
    }
    if (data.containsKey('stamp_url')) {
      context.handle(
        _stampUrlMeta,
        stampUrl.isAcceptableOrUnknown(data['stamp_url']!, _stampUrlMeta),
      );
    }
    if (data.containsKey('payment_terms')) {
      context.handle(
        _paymentTermsMeta,
        paymentTerms.isAcceptableOrUnknown(
          data['payment_terms']!,
          _paymentTermsMeta,
        ),
      );
    }
    if (data.containsKey('tax_label')) {
      context.handle(
        _taxLabelMeta,
        taxLabel.isAcceptableOrUnknown(data['tax_label']!, _taxLabelMeta),
      );
    }
    if (data.containsKey('tax_number')) {
      context.handle(
        _taxNumberMeta,
        taxNumber.isAcceptableOrUnknown(data['tax_number']!, _taxNumberMeta),
      );
    }
    if (data.containsKey('city')) {
      context.handle(
        _cityMeta,
        city.isAcceptableOrUnknown(data['city']!, _cityMeta),
      );
    }
    if (data.containsKey('country')) {
      context.handle(
        _countryMeta,
        country.isAcceptableOrUnknown(data['country']!, _countryMeta),
      );
    }
    if (data.containsKey('commercial_name')) {
      context.handle(
        _commercialNameMeta,
        commercialName.isAcceptableOrUnknown(
          data['commercial_name']!,
          _commercialNameMeta,
        ),
      );
    }
    if (data.containsKey('slogan')) {
      context.handle(
        _sloganMeta,
        slogan.isAcceptableOrUnknown(data['slogan']!, _sloganMeta),
      );
    }
    if (data.containsKey('activity')) {
      context.handle(
        _activityMeta,
        activity.isAcceptableOrUnknown(data['activity']!, _activityMeta),
      );
    }
    if (data.containsKey('mobile_money')) {
      context.handle(
        _mobileMoneyMeta,
        mobileMoney.isAcceptableOrUnknown(
          data['mobile_money']!,
          _mobileMoneyMeta,
        ),
      );
    }
    if (data.containsKey('invoice_short_title')) {
      context.handle(
        _invoiceShortTitleMeta,
        invoiceShortTitle.isAcceptableOrUnknown(
          data['invoice_short_title']!,
          _invoiceShortTitleMeta,
        ),
      );
    }
    if (data.containsKey('invoice_signer_title')) {
      context.handle(
        _invoiceSignerTitleMeta,
        invoiceSignerTitle.isAcceptableOrUnknown(
          data['invoice_signer_title']!,
          _invoiceSignerTitleMeta,
        ),
      );
    }
    if (data.containsKey('invoice_signer_name')) {
      context.handle(
        _invoiceSignerNameMeta,
        invoiceSignerName.isAcceptableOrUnknown(
          data['invoice_signer_name']!,
          _invoiceSignerNameMeta,
        ),
      );
    }
    if (data.containsKey('invoice_template')) {
      context.handle(
        _invoiceTemplateMeta,
        invoiceTemplate.isAcceptableOrUnknown(
          data['invoice_template']!,
          _invoiceTemplateMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalStore map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalStore(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      ),
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      ),
      logoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}logo_url'],
      ),
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      isPrimary: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_primary'],
      )!,
      posDiscountEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pos_discount_enabled'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      ),
      primaryColor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}primary_color'],
      ),
      secondaryColor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}secondary_color'],
      ),
      invoicePrefix: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}invoice_prefix'],
      ),
      footerText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}footer_text'],
      ),
      legalInfo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}legal_info'],
      ),
      signatureUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}signature_url'],
      ),
      stampUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stamp_url'],
      ),
      paymentTerms: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_terms'],
      ),
      taxLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tax_label'],
      ),
      taxNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tax_number'],
      ),
      city: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}city'],
      ),
      country: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}country'],
      ),
      commercialName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}commercial_name'],
      ),
      slogan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slogan'],
      ),
      activity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity'],
      ),
      mobileMoney: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mobile_money'],
      ),
      invoiceShortTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}invoice_short_title'],
      ),
      invoiceSignerTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}invoice_signer_title'],
      ),
      invoiceSignerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}invoice_signer_name'],
      ),
      invoiceTemplate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}invoice_template'],
      ),
    );
  }

  @override
  $LocalStoresTable createAlias(String alias) {
    return $LocalStoresTable(attachedDatabase, alias);
  }
}

class LocalStore extends DataClass implements Insertable<LocalStore> {
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
  final String updatedAt;
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
  final String? invoiceTemplate;
  const LocalStore({
    required this.id,
    required this.companyId,
    required this.name,
    this.code,
    this.address,
    this.logoUrl,
    this.phone,
    this.email,
    this.description,
    required this.isActive,
    required this.isPrimary,
    required this.posDiscountEnabled,
    required this.updatedAt,
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
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_id'] = Variable<String>(companyId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || code != null) {
      map['code'] = Variable<String>(code);
    }
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || logoUrl != null) {
      map['logo_url'] = Variable<String>(logoUrl);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['is_primary'] = Variable<bool>(isPrimary);
    map['pos_discount_enabled'] = Variable<bool>(posDiscountEnabled);
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || currency != null) {
      map['currency'] = Variable<String>(currency);
    }
    if (!nullToAbsent || primaryColor != null) {
      map['primary_color'] = Variable<String>(primaryColor);
    }
    if (!nullToAbsent || secondaryColor != null) {
      map['secondary_color'] = Variable<String>(secondaryColor);
    }
    if (!nullToAbsent || invoicePrefix != null) {
      map['invoice_prefix'] = Variable<String>(invoicePrefix);
    }
    if (!nullToAbsent || footerText != null) {
      map['footer_text'] = Variable<String>(footerText);
    }
    if (!nullToAbsent || legalInfo != null) {
      map['legal_info'] = Variable<String>(legalInfo);
    }
    if (!nullToAbsent || signatureUrl != null) {
      map['signature_url'] = Variable<String>(signatureUrl);
    }
    if (!nullToAbsent || stampUrl != null) {
      map['stamp_url'] = Variable<String>(stampUrl);
    }
    if (!nullToAbsent || paymentTerms != null) {
      map['payment_terms'] = Variable<String>(paymentTerms);
    }
    if (!nullToAbsent || taxLabel != null) {
      map['tax_label'] = Variable<String>(taxLabel);
    }
    if (!nullToAbsent || taxNumber != null) {
      map['tax_number'] = Variable<String>(taxNumber);
    }
    if (!nullToAbsent || city != null) {
      map['city'] = Variable<String>(city);
    }
    if (!nullToAbsent || country != null) {
      map['country'] = Variable<String>(country);
    }
    if (!nullToAbsent || commercialName != null) {
      map['commercial_name'] = Variable<String>(commercialName);
    }
    if (!nullToAbsent || slogan != null) {
      map['slogan'] = Variable<String>(slogan);
    }
    if (!nullToAbsent || activity != null) {
      map['activity'] = Variable<String>(activity);
    }
    if (!nullToAbsent || mobileMoney != null) {
      map['mobile_money'] = Variable<String>(mobileMoney);
    }
    if (!nullToAbsent || invoiceShortTitle != null) {
      map['invoice_short_title'] = Variable<String>(invoiceShortTitle);
    }
    if (!nullToAbsent || invoiceSignerTitle != null) {
      map['invoice_signer_title'] = Variable<String>(invoiceSignerTitle);
    }
    if (!nullToAbsent || invoiceSignerName != null) {
      map['invoice_signer_name'] = Variable<String>(invoiceSignerName);
    }
    if (!nullToAbsent || invoiceTemplate != null) {
      map['invoice_template'] = Variable<String>(invoiceTemplate);
    }
    return map;
  }

  LocalStoresCompanion toCompanion(bool nullToAbsent) {
    return LocalStoresCompanion(
      id: Value(id),
      companyId: Value(companyId),
      name: Value(name),
      code: code == null && nullToAbsent ? const Value.absent() : Value(code),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      logoUrl: logoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(logoUrl),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      isActive: Value(isActive),
      isPrimary: Value(isPrimary),
      posDiscountEnabled: Value(posDiscountEnabled),
      updatedAt: Value(updatedAt),
      currency: currency == null && nullToAbsent
          ? const Value.absent()
          : Value(currency),
      primaryColor: primaryColor == null && nullToAbsent
          ? const Value.absent()
          : Value(primaryColor),
      secondaryColor: secondaryColor == null && nullToAbsent
          ? const Value.absent()
          : Value(secondaryColor),
      invoicePrefix: invoicePrefix == null && nullToAbsent
          ? const Value.absent()
          : Value(invoicePrefix),
      footerText: footerText == null && nullToAbsent
          ? const Value.absent()
          : Value(footerText),
      legalInfo: legalInfo == null && nullToAbsent
          ? const Value.absent()
          : Value(legalInfo),
      signatureUrl: signatureUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(signatureUrl),
      stampUrl: stampUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(stampUrl),
      paymentTerms: paymentTerms == null && nullToAbsent
          ? const Value.absent()
          : Value(paymentTerms),
      taxLabel: taxLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(taxLabel),
      taxNumber: taxNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(taxNumber),
      city: city == null && nullToAbsent ? const Value.absent() : Value(city),
      country: country == null && nullToAbsent
          ? const Value.absent()
          : Value(country),
      commercialName: commercialName == null && nullToAbsent
          ? const Value.absent()
          : Value(commercialName),
      slogan: slogan == null && nullToAbsent
          ? const Value.absent()
          : Value(slogan),
      activity: activity == null && nullToAbsent
          ? const Value.absent()
          : Value(activity),
      mobileMoney: mobileMoney == null && nullToAbsent
          ? const Value.absent()
          : Value(mobileMoney),
      invoiceShortTitle: invoiceShortTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(invoiceShortTitle),
      invoiceSignerTitle: invoiceSignerTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(invoiceSignerTitle),
      invoiceSignerName: invoiceSignerName == null && nullToAbsent
          ? const Value.absent()
          : Value(invoiceSignerName),
      invoiceTemplate: invoiceTemplate == null && nullToAbsent
          ? const Value.absent()
          : Value(invoiceTemplate),
    );
  }

  factory LocalStore.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalStore(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String>(json['companyId']),
      name: serializer.fromJson<String>(json['name']),
      code: serializer.fromJson<String?>(json['code']),
      address: serializer.fromJson<String?>(json['address']),
      logoUrl: serializer.fromJson<String?>(json['logoUrl']),
      phone: serializer.fromJson<String?>(json['phone']),
      email: serializer.fromJson<String?>(json['email']),
      description: serializer.fromJson<String?>(json['description']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      isPrimary: serializer.fromJson<bool>(json['isPrimary']),
      posDiscountEnabled: serializer.fromJson<bool>(json['posDiscountEnabled']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      currency: serializer.fromJson<String?>(json['currency']),
      primaryColor: serializer.fromJson<String?>(json['primaryColor']),
      secondaryColor: serializer.fromJson<String?>(json['secondaryColor']),
      invoicePrefix: serializer.fromJson<String?>(json['invoicePrefix']),
      footerText: serializer.fromJson<String?>(json['footerText']),
      legalInfo: serializer.fromJson<String?>(json['legalInfo']),
      signatureUrl: serializer.fromJson<String?>(json['signatureUrl']),
      stampUrl: serializer.fromJson<String?>(json['stampUrl']),
      paymentTerms: serializer.fromJson<String?>(json['paymentTerms']),
      taxLabel: serializer.fromJson<String?>(json['taxLabel']),
      taxNumber: serializer.fromJson<String?>(json['taxNumber']),
      city: serializer.fromJson<String?>(json['city']),
      country: serializer.fromJson<String?>(json['country']),
      commercialName: serializer.fromJson<String?>(json['commercialName']),
      slogan: serializer.fromJson<String?>(json['slogan']),
      activity: serializer.fromJson<String?>(json['activity']),
      mobileMoney: serializer.fromJson<String?>(json['mobileMoney']),
      invoiceShortTitle: serializer.fromJson<String?>(
        json['invoiceShortTitle'],
      ),
      invoiceSignerTitle: serializer.fromJson<String?>(
        json['invoiceSignerTitle'],
      ),
      invoiceSignerName: serializer.fromJson<String?>(
        json['invoiceSignerName'],
      ),
      invoiceTemplate: serializer.fromJson<String?>(json['invoiceTemplate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String>(companyId),
      'name': serializer.toJson<String>(name),
      'code': serializer.toJson<String?>(code),
      'address': serializer.toJson<String?>(address),
      'logoUrl': serializer.toJson<String?>(logoUrl),
      'phone': serializer.toJson<String?>(phone),
      'email': serializer.toJson<String?>(email),
      'description': serializer.toJson<String?>(description),
      'isActive': serializer.toJson<bool>(isActive),
      'isPrimary': serializer.toJson<bool>(isPrimary),
      'posDiscountEnabled': serializer.toJson<bool>(posDiscountEnabled),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'currency': serializer.toJson<String?>(currency),
      'primaryColor': serializer.toJson<String?>(primaryColor),
      'secondaryColor': serializer.toJson<String?>(secondaryColor),
      'invoicePrefix': serializer.toJson<String?>(invoicePrefix),
      'footerText': serializer.toJson<String?>(footerText),
      'legalInfo': serializer.toJson<String?>(legalInfo),
      'signatureUrl': serializer.toJson<String?>(signatureUrl),
      'stampUrl': serializer.toJson<String?>(stampUrl),
      'paymentTerms': serializer.toJson<String?>(paymentTerms),
      'taxLabel': serializer.toJson<String?>(taxLabel),
      'taxNumber': serializer.toJson<String?>(taxNumber),
      'city': serializer.toJson<String?>(city),
      'country': serializer.toJson<String?>(country),
      'commercialName': serializer.toJson<String?>(commercialName),
      'slogan': serializer.toJson<String?>(slogan),
      'activity': serializer.toJson<String?>(activity),
      'mobileMoney': serializer.toJson<String?>(mobileMoney),
      'invoiceShortTitle': serializer.toJson<String?>(invoiceShortTitle),
      'invoiceSignerTitle': serializer.toJson<String?>(invoiceSignerTitle),
      'invoiceSignerName': serializer.toJson<String?>(invoiceSignerName),
      'invoiceTemplate': serializer.toJson<String?>(invoiceTemplate),
    };
  }

  LocalStore copyWith({
    String? id,
    String? companyId,
    String? name,
    Value<String?> code = const Value.absent(),
    Value<String?> address = const Value.absent(),
    Value<String?> logoUrl = const Value.absent(),
    Value<String?> phone = const Value.absent(),
    Value<String?> email = const Value.absent(),
    Value<String?> description = const Value.absent(),
    bool? isActive,
    bool? isPrimary,
    bool? posDiscountEnabled,
    String? updatedAt,
    Value<String?> currency = const Value.absent(),
    Value<String?> primaryColor = const Value.absent(),
    Value<String?> secondaryColor = const Value.absent(),
    Value<String?> invoicePrefix = const Value.absent(),
    Value<String?> footerText = const Value.absent(),
    Value<String?> legalInfo = const Value.absent(),
    Value<String?> signatureUrl = const Value.absent(),
    Value<String?> stampUrl = const Value.absent(),
    Value<String?> paymentTerms = const Value.absent(),
    Value<String?> taxLabel = const Value.absent(),
    Value<String?> taxNumber = const Value.absent(),
    Value<String?> city = const Value.absent(),
    Value<String?> country = const Value.absent(),
    Value<String?> commercialName = const Value.absent(),
    Value<String?> slogan = const Value.absent(),
    Value<String?> activity = const Value.absent(),
    Value<String?> mobileMoney = const Value.absent(),
    Value<String?> invoiceShortTitle = const Value.absent(),
    Value<String?> invoiceSignerTitle = const Value.absent(),
    Value<String?> invoiceSignerName = const Value.absent(),
    Value<String?> invoiceTemplate = const Value.absent(),
  }) => LocalStore(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    name: name ?? this.name,
    code: code.present ? code.value : this.code,
    address: address.present ? address.value : this.address,
    logoUrl: logoUrl.present ? logoUrl.value : this.logoUrl,
    phone: phone.present ? phone.value : this.phone,
    email: email.present ? email.value : this.email,
    description: description.present ? description.value : this.description,
    isActive: isActive ?? this.isActive,
    isPrimary: isPrimary ?? this.isPrimary,
    posDiscountEnabled: posDiscountEnabled ?? this.posDiscountEnabled,
    updatedAt: updatedAt ?? this.updatedAt,
    currency: currency.present ? currency.value : this.currency,
    primaryColor: primaryColor.present ? primaryColor.value : this.primaryColor,
    secondaryColor: secondaryColor.present
        ? secondaryColor.value
        : this.secondaryColor,
    invoicePrefix: invoicePrefix.present
        ? invoicePrefix.value
        : this.invoicePrefix,
    footerText: footerText.present ? footerText.value : this.footerText,
    legalInfo: legalInfo.present ? legalInfo.value : this.legalInfo,
    signatureUrl: signatureUrl.present ? signatureUrl.value : this.signatureUrl,
    stampUrl: stampUrl.present ? stampUrl.value : this.stampUrl,
    paymentTerms: paymentTerms.present ? paymentTerms.value : this.paymentTerms,
    taxLabel: taxLabel.present ? taxLabel.value : this.taxLabel,
    taxNumber: taxNumber.present ? taxNumber.value : this.taxNumber,
    city: city.present ? city.value : this.city,
    country: country.present ? country.value : this.country,
    commercialName: commercialName.present
        ? commercialName.value
        : this.commercialName,
    slogan: slogan.present ? slogan.value : this.slogan,
    activity: activity.present ? activity.value : this.activity,
    mobileMoney: mobileMoney.present ? mobileMoney.value : this.mobileMoney,
    invoiceShortTitle: invoiceShortTitle.present
        ? invoiceShortTitle.value
        : this.invoiceShortTitle,
    invoiceSignerTitle: invoiceSignerTitle.present
        ? invoiceSignerTitle.value
        : this.invoiceSignerTitle,
    invoiceSignerName: invoiceSignerName.present
        ? invoiceSignerName.value
        : this.invoiceSignerName,
    invoiceTemplate: invoiceTemplate.present
        ? invoiceTemplate.value
        : this.invoiceTemplate,
  );
  LocalStore copyWithCompanion(LocalStoresCompanion data) {
    return LocalStore(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      name: data.name.present ? data.name.value : this.name,
      code: data.code.present ? data.code.value : this.code,
      address: data.address.present ? data.address.value : this.address,
      logoUrl: data.logoUrl.present ? data.logoUrl.value : this.logoUrl,
      phone: data.phone.present ? data.phone.value : this.phone,
      email: data.email.present ? data.email.value : this.email,
      description: data.description.present
          ? data.description.value
          : this.description,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      isPrimary: data.isPrimary.present ? data.isPrimary.value : this.isPrimary,
      posDiscountEnabled: data.posDiscountEnabled.present
          ? data.posDiscountEnabled.value
          : this.posDiscountEnabled,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      currency: data.currency.present ? data.currency.value : this.currency,
      primaryColor: data.primaryColor.present
          ? data.primaryColor.value
          : this.primaryColor,
      secondaryColor: data.secondaryColor.present
          ? data.secondaryColor.value
          : this.secondaryColor,
      invoicePrefix: data.invoicePrefix.present
          ? data.invoicePrefix.value
          : this.invoicePrefix,
      footerText: data.footerText.present
          ? data.footerText.value
          : this.footerText,
      legalInfo: data.legalInfo.present ? data.legalInfo.value : this.legalInfo,
      signatureUrl: data.signatureUrl.present
          ? data.signatureUrl.value
          : this.signatureUrl,
      stampUrl: data.stampUrl.present ? data.stampUrl.value : this.stampUrl,
      paymentTerms: data.paymentTerms.present
          ? data.paymentTerms.value
          : this.paymentTerms,
      taxLabel: data.taxLabel.present ? data.taxLabel.value : this.taxLabel,
      taxNumber: data.taxNumber.present ? data.taxNumber.value : this.taxNumber,
      city: data.city.present ? data.city.value : this.city,
      country: data.country.present ? data.country.value : this.country,
      commercialName: data.commercialName.present
          ? data.commercialName.value
          : this.commercialName,
      slogan: data.slogan.present ? data.slogan.value : this.slogan,
      activity: data.activity.present ? data.activity.value : this.activity,
      mobileMoney: data.mobileMoney.present
          ? data.mobileMoney.value
          : this.mobileMoney,
      invoiceShortTitle: data.invoiceShortTitle.present
          ? data.invoiceShortTitle.value
          : this.invoiceShortTitle,
      invoiceSignerTitle: data.invoiceSignerTitle.present
          ? data.invoiceSignerTitle.value
          : this.invoiceSignerTitle,
      invoiceSignerName: data.invoiceSignerName.present
          ? data.invoiceSignerName.value
          : this.invoiceSignerName,
      invoiceTemplate: data.invoiceTemplate.present
          ? data.invoiceTemplate.value
          : this.invoiceTemplate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalStore(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('name: $name, ')
          ..write('code: $code, ')
          ..write('address: $address, ')
          ..write('logoUrl: $logoUrl, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('description: $description, ')
          ..write('isActive: $isActive, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('posDiscountEnabled: $posDiscountEnabled, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('currency: $currency, ')
          ..write('primaryColor: $primaryColor, ')
          ..write('secondaryColor: $secondaryColor, ')
          ..write('invoicePrefix: $invoicePrefix, ')
          ..write('footerText: $footerText, ')
          ..write('legalInfo: $legalInfo, ')
          ..write('signatureUrl: $signatureUrl, ')
          ..write('stampUrl: $stampUrl, ')
          ..write('paymentTerms: $paymentTerms, ')
          ..write('taxLabel: $taxLabel, ')
          ..write('taxNumber: $taxNumber, ')
          ..write('city: $city, ')
          ..write('country: $country, ')
          ..write('commercialName: $commercialName, ')
          ..write('slogan: $slogan, ')
          ..write('activity: $activity, ')
          ..write('mobileMoney: $mobileMoney, ')
          ..write('invoiceShortTitle: $invoiceShortTitle, ')
          ..write('invoiceSignerTitle: $invoiceSignerTitle, ')
          ..write('invoiceSignerName: $invoiceSignerName, ')
          ..write('invoiceTemplate: $invoiceTemplate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    companyId,
    name,
    code,
    address,
    logoUrl,
    phone,
    email,
    description,
    isActive,
    isPrimary,
    posDiscountEnabled,
    updatedAt,
    currency,
    primaryColor,
    secondaryColor,
    invoicePrefix,
    footerText,
    legalInfo,
    signatureUrl,
    stampUrl,
    paymentTerms,
    taxLabel,
    taxNumber,
    city,
    country,
    commercialName,
    slogan,
    activity,
    mobileMoney,
    invoiceShortTitle,
    invoiceSignerTitle,
    invoiceSignerName,
    invoiceTemplate,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalStore &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.name == this.name &&
          other.code == this.code &&
          other.address == this.address &&
          other.logoUrl == this.logoUrl &&
          other.phone == this.phone &&
          other.email == this.email &&
          other.description == this.description &&
          other.isActive == this.isActive &&
          other.isPrimary == this.isPrimary &&
          other.posDiscountEnabled == this.posDiscountEnabled &&
          other.updatedAt == this.updatedAt &&
          other.currency == this.currency &&
          other.primaryColor == this.primaryColor &&
          other.secondaryColor == this.secondaryColor &&
          other.invoicePrefix == this.invoicePrefix &&
          other.footerText == this.footerText &&
          other.legalInfo == this.legalInfo &&
          other.signatureUrl == this.signatureUrl &&
          other.stampUrl == this.stampUrl &&
          other.paymentTerms == this.paymentTerms &&
          other.taxLabel == this.taxLabel &&
          other.taxNumber == this.taxNumber &&
          other.city == this.city &&
          other.country == this.country &&
          other.commercialName == this.commercialName &&
          other.slogan == this.slogan &&
          other.activity == this.activity &&
          other.mobileMoney == this.mobileMoney &&
          other.invoiceShortTitle == this.invoiceShortTitle &&
          other.invoiceSignerTitle == this.invoiceSignerTitle &&
          other.invoiceSignerName == this.invoiceSignerName &&
          other.invoiceTemplate == this.invoiceTemplate);
}

class LocalStoresCompanion extends UpdateCompanion<LocalStore> {
  final Value<String> id;
  final Value<String> companyId;
  final Value<String> name;
  final Value<String?> code;
  final Value<String?> address;
  final Value<String?> logoUrl;
  final Value<String?> phone;
  final Value<String?> email;
  final Value<String?> description;
  final Value<bool> isActive;
  final Value<bool> isPrimary;
  final Value<bool> posDiscountEnabled;
  final Value<String> updatedAt;
  final Value<String?> currency;
  final Value<String?> primaryColor;
  final Value<String?> secondaryColor;
  final Value<String?> invoicePrefix;
  final Value<String?> footerText;
  final Value<String?> legalInfo;
  final Value<String?> signatureUrl;
  final Value<String?> stampUrl;
  final Value<String?> paymentTerms;
  final Value<String?> taxLabel;
  final Value<String?> taxNumber;
  final Value<String?> city;
  final Value<String?> country;
  final Value<String?> commercialName;
  final Value<String?> slogan;
  final Value<String?> activity;
  final Value<String?> mobileMoney;
  final Value<String?> invoiceShortTitle;
  final Value<String?> invoiceSignerTitle;
  final Value<String?> invoiceSignerName;
  final Value<String?> invoiceTemplate;
  final Value<int> rowid;
  const LocalStoresCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.name = const Value.absent(),
    this.code = const Value.absent(),
    this.address = const Value.absent(),
    this.logoUrl = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.description = const Value.absent(),
    this.isActive = const Value.absent(),
    this.isPrimary = const Value.absent(),
    this.posDiscountEnabled = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.currency = const Value.absent(),
    this.primaryColor = const Value.absent(),
    this.secondaryColor = const Value.absent(),
    this.invoicePrefix = const Value.absent(),
    this.footerText = const Value.absent(),
    this.legalInfo = const Value.absent(),
    this.signatureUrl = const Value.absent(),
    this.stampUrl = const Value.absent(),
    this.paymentTerms = const Value.absent(),
    this.taxLabel = const Value.absent(),
    this.taxNumber = const Value.absent(),
    this.city = const Value.absent(),
    this.country = const Value.absent(),
    this.commercialName = const Value.absent(),
    this.slogan = const Value.absent(),
    this.activity = const Value.absent(),
    this.mobileMoney = const Value.absent(),
    this.invoiceShortTitle = const Value.absent(),
    this.invoiceSignerTitle = const Value.absent(),
    this.invoiceSignerName = const Value.absent(),
    this.invoiceTemplate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalStoresCompanion.insert({
    required String id,
    required String companyId,
    required String name,
    this.code = const Value.absent(),
    this.address = const Value.absent(),
    this.logoUrl = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.description = const Value.absent(),
    this.isActive = const Value.absent(),
    this.isPrimary = const Value.absent(),
    this.posDiscountEnabled = const Value.absent(),
    required String updatedAt,
    this.currency = const Value.absent(),
    this.primaryColor = const Value.absent(),
    this.secondaryColor = const Value.absent(),
    this.invoicePrefix = const Value.absent(),
    this.footerText = const Value.absent(),
    this.legalInfo = const Value.absent(),
    this.signatureUrl = const Value.absent(),
    this.stampUrl = const Value.absent(),
    this.paymentTerms = const Value.absent(),
    this.taxLabel = const Value.absent(),
    this.taxNumber = const Value.absent(),
    this.city = const Value.absent(),
    this.country = const Value.absent(),
    this.commercialName = const Value.absent(),
    this.slogan = const Value.absent(),
    this.activity = const Value.absent(),
    this.mobileMoney = const Value.absent(),
    this.invoiceShortTitle = const Value.absent(),
    this.invoiceSignerTitle = const Value.absent(),
    this.invoiceSignerName = const Value.absent(),
    this.invoiceTemplate = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       companyId = Value(companyId),
       name = Value(name),
       updatedAt = Value(updatedAt);
  static Insertable<LocalStore> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? name,
    Expression<String>? code,
    Expression<String>? address,
    Expression<String>? logoUrl,
    Expression<String>? phone,
    Expression<String>? email,
    Expression<String>? description,
    Expression<bool>? isActive,
    Expression<bool>? isPrimary,
    Expression<bool>? posDiscountEnabled,
    Expression<String>? updatedAt,
    Expression<String>? currency,
    Expression<String>? primaryColor,
    Expression<String>? secondaryColor,
    Expression<String>? invoicePrefix,
    Expression<String>? footerText,
    Expression<String>? legalInfo,
    Expression<String>? signatureUrl,
    Expression<String>? stampUrl,
    Expression<String>? paymentTerms,
    Expression<String>? taxLabel,
    Expression<String>? taxNumber,
    Expression<String>? city,
    Expression<String>? country,
    Expression<String>? commercialName,
    Expression<String>? slogan,
    Expression<String>? activity,
    Expression<String>? mobileMoney,
    Expression<String>? invoiceShortTitle,
    Expression<String>? invoiceSignerTitle,
    Expression<String>? invoiceSignerName,
    Expression<String>? invoiceTemplate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (name != null) 'name': name,
      if (code != null) 'code': code,
      if (address != null) 'address': address,
      if (logoUrl != null) 'logo_url': logoUrl,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (description != null) 'description': description,
      if (isActive != null) 'is_active': isActive,
      if (isPrimary != null) 'is_primary': isPrimary,
      if (posDiscountEnabled != null)
        'pos_discount_enabled': posDiscountEnabled,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (currency != null) 'currency': currency,
      if (primaryColor != null) 'primary_color': primaryColor,
      if (secondaryColor != null) 'secondary_color': secondaryColor,
      if (invoicePrefix != null) 'invoice_prefix': invoicePrefix,
      if (footerText != null) 'footer_text': footerText,
      if (legalInfo != null) 'legal_info': legalInfo,
      if (signatureUrl != null) 'signature_url': signatureUrl,
      if (stampUrl != null) 'stamp_url': stampUrl,
      if (paymentTerms != null) 'payment_terms': paymentTerms,
      if (taxLabel != null) 'tax_label': taxLabel,
      if (taxNumber != null) 'tax_number': taxNumber,
      if (city != null) 'city': city,
      if (country != null) 'country': country,
      if (commercialName != null) 'commercial_name': commercialName,
      if (slogan != null) 'slogan': slogan,
      if (activity != null) 'activity': activity,
      if (mobileMoney != null) 'mobile_money': mobileMoney,
      if (invoiceShortTitle != null) 'invoice_short_title': invoiceShortTitle,
      if (invoiceSignerTitle != null)
        'invoice_signer_title': invoiceSignerTitle,
      if (invoiceSignerName != null) 'invoice_signer_name': invoiceSignerName,
      if (invoiceTemplate != null) 'invoice_template': invoiceTemplate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalStoresCompanion copyWith({
    Value<String>? id,
    Value<String>? companyId,
    Value<String>? name,
    Value<String?>? code,
    Value<String?>? address,
    Value<String?>? logoUrl,
    Value<String?>? phone,
    Value<String?>? email,
    Value<String?>? description,
    Value<bool>? isActive,
    Value<bool>? isPrimary,
    Value<bool>? posDiscountEnabled,
    Value<String>? updatedAt,
    Value<String?>? currency,
    Value<String?>? primaryColor,
    Value<String?>? secondaryColor,
    Value<String?>? invoicePrefix,
    Value<String?>? footerText,
    Value<String?>? legalInfo,
    Value<String?>? signatureUrl,
    Value<String?>? stampUrl,
    Value<String?>? paymentTerms,
    Value<String?>? taxLabel,
    Value<String?>? taxNumber,
    Value<String?>? city,
    Value<String?>? country,
    Value<String?>? commercialName,
    Value<String?>? slogan,
    Value<String?>? activity,
    Value<String?>? mobileMoney,
    Value<String?>? invoiceShortTitle,
    Value<String?>? invoiceSignerTitle,
    Value<String?>? invoiceSignerName,
    Value<String?>? invoiceTemplate,
    Value<int>? rowid,
  }) {
    return LocalStoresCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      code: code ?? this.code,
      address: address ?? this.address,
      logoUrl: logoUrl ?? this.logoUrl,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      isPrimary: isPrimary ?? this.isPrimary,
      posDiscountEnabled: posDiscountEnabled ?? this.posDiscountEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
      currency: currency ?? this.currency,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      footerText: footerText ?? this.footerText,
      legalInfo: legalInfo ?? this.legalInfo,
      signatureUrl: signatureUrl ?? this.signatureUrl,
      stampUrl: stampUrl ?? this.stampUrl,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      taxLabel: taxLabel ?? this.taxLabel,
      taxNumber: taxNumber ?? this.taxNumber,
      city: city ?? this.city,
      country: country ?? this.country,
      commercialName: commercialName ?? this.commercialName,
      slogan: slogan ?? this.slogan,
      activity: activity ?? this.activity,
      mobileMoney: mobileMoney ?? this.mobileMoney,
      invoiceShortTitle: invoiceShortTitle ?? this.invoiceShortTitle,
      invoiceSignerTitle: invoiceSignerTitle ?? this.invoiceSignerTitle,
      invoiceSignerName: invoiceSignerName ?? this.invoiceSignerName,
      invoiceTemplate: invoiceTemplate ?? this.invoiceTemplate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (logoUrl.present) {
      map['logo_url'] = Variable<String>(logoUrl.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (isPrimary.present) {
      map['is_primary'] = Variable<bool>(isPrimary.value);
    }
    if (posDiscountEnabled.present) {
      map['pos_discount_enabled'] = Variable<bool>(posDiscountEnabled.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (primaryColor.present) {
      map['primary_color'] = Variable<String>(primaryColor.value);
    }
    if (secondaryColor.present) {
      map['secondary_color'] = Variable<String>(secondaryColor.value);
    }
    if (invoicePrefix.present) {
      map['invoice_prefix'] = Variable<String>(invoicePrefix.value);
    }
    if (footerText.present) {
      map['footer_text'] = Variable<String>(footerText.value);
    }
    if (legalInfo.present) {
      map['legal_info'] = Variable<String>(legalInfo.value);
    }
    if (signatureUrl.present) {
      map['signature_url'] = Variable<String>(signatureUrl.value);
    }
    if (stampUrl.present) {
      map['stamp_url'] = Variable<String>(stampUrl.value);
    }
    if (paymentTerms.present) {
      map['payment_terms'] = Variable<String>(paymentTerms.value);
    }
    if (taxLabel.present) {
      map['tax_label'] = Variable<String>(taxLabel.value);
    }
    if (taxNumber.present) {
      map['tax_number'] = Variable<String>(taxNumber.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (country.present) {
      map['country'] = Variable<String>(country.value);
    }
    if (commercialName.present) {
      map['commercial_name'] = Variable<String>(commercialName.value);
    }
    if (slogan.present) {
      map['slogan'] = Variable<String>(slogan.value);
    }
    if (activity.present) {
      map['activity'] = Variable<String>(activity.value);
    }
    if (mobileMoney.present) {
      map['mobile_money'] = Variable<String>(mobileMoney.value);
    }
    if (invoiceShortTitle.present) {
      map['invoice_short_title'] = Variable<String>(invoiceShortTitle.value);
    }
    if (invoiceSignerTitle.present) {
      map['invoice_signer_title'] = Variable<String>(invoiceSignerTitle.value);
    }
    if (invoiceSignerName.present) {
      map['invoice_signer_name'] = Variable<String>(invoiceSignerName.value);
    }
    if (invoiceTemplate.present) {
      map['invoice_template'] = Variable<String>(invoiceTemplate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalStoresCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('name: $name, ')
          ..write('code: $code, ')
          ..write('address: $address, ')
          ..write('logoUrl: $logoUrl, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('description: $description, ')
          ..write('isActive: $isActive, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('posDiscountEnabled: $posDiscountEnabled, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('currency: $currency, ')
          ..write('primaryColor: $primaryColor, ')
          ..write('secondaryColor: $secondaryColor, ')
          ..write('invoicePrefix: $invoicePrefix, ')
          ..write('footerText: $footerText, ')
          ..write('legalInfo: $legalInfo, ')
          ..write('signatureUrl: $signatureUrl, ')
          ..write('stampUrl: $stampUrl, ')
          ..write('paymentTerms: $paymentTerms, ')
          ..write('taxLabel: $taxLabel, ')
          ..write('taxNumber: $taxNumber, ')
          ..write('city: $city, ')
          ..write('country: $country, ')
          ..write('commercialName: $commercialName, ')
          ..write('slogan: $slogan, ')
          ..write('activity: $activity, ')
          ..write('mobileMoney: $mobileMoney, ')
          ..write('invoiceShortTitle: $invoiceShortTitle, ')
          ..write('invoiceSignerTitle: $invoiceSignerTitle, ')
          ..write('invoiceSignerName: $invoiceSignerName, ')
          ..write('invoiceTemplate: $invoiceTemplate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalCategoriesTable extends LocalCategories
    with TableInfo<$LocalCategoriesTable, LocalCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, companyId, name, parentId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalCategory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalCategory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
    );
  }

  @override
  $LocalCategoriesTable createAlias(String alias) {
    return $LocalCategoriesTable(attachedDatabase, alias);
  }
}

class LocalCategory extends DataClass implements Insertable<LocalCategory> {
  final String id;
  final String companyId;
  final String name;
  final String? parentId;
  const LocalCategory({
    required this.id,
    required this.companyId,
    required this.name,
    this.parentId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_id'] = Variable<String>(companyId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    return map;
  }

  LocalCategoriesCompanion toCompanion(bool nullToAbsent) {
    return LocalCategoriesCompanion(
      id: Value(id),
      companyId: Value(companyId),
      name: Value(name),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
    );
  }

  factory LocalCategory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalCategory(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String>(json['companyId']),
      name: serializer.fromJson<String>(json['name']),
      parentId: serializer.fromJson<String?>(json['parentId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String>(companyId),
      'name': serializer.toJson<String>(name),
      'parentId': serializer.toJson<String?>(parentId),
    };
  }

  LocalCategory copyWith({
    String? id,
    String? companyId,
    String? name,
    Value<String?> parentId = const Value.absent(),
  }) => LocalCategory(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    name: name ?? this.name,
    parentId: parentId.present ? parentId.value : this.parentId,
  );
  LocalCategory copyWithCompanion(LocalCategoriesCompanion data) {
    return LocalCategory(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      name: data.name.present ? data.name.value : this.name,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalCategory(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('name: $name, ')
          ..write('parentId: $parentId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, companyId, name, parentId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalCategory &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.name == this.name &&
          other.parentId == this.parentId);
}

class LocalCategoriesCompanion extends UpdateCompanion<LocalCategory> {
  final Value<String> id;
  final Value<String> companyId;
  final Value<String> name;
  final Value<String?> parentId;
  final Value<int> rowid;
  const LocalCategoriesCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.name = const Value.absent(),
    this.parentId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalCategoriesCompanion.insert({
    required String id,
    required String companyId,
    required String name,
    this.parentId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       companyId = Value(companyId),
       name = Value(name);
  static Insertable<LocalCategory> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? name,
    Expression<String>? parentId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (name != null) 'name': name,
      if (parentId != null) 'parent_id': parentId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalCategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? companyId,
    Value<String>? name,
    Value<String?>? parentId,
    Value<int>? rowid,
  }) {
    return LocalCategoriesCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalCategoriesCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('name: $name, ')
          ..write('parentId: $parentId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalBrandsTable extends LocalBrands
    with TableInfo<$LocalBrandsTable, LocalBrand> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalBrandsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, companyId, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_brands';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalBrand> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalBrand map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalBrand(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $LocalBrandsTable createAlias(String alias) {
    return $LocalBrandsTable(attachedDatabase, alias);
  }
}

class LocalBrand extends DataClass implements Insertable<LocalBrand> {
  final String id;
  final String companyId;
  final String name;
  const LocalBrand({
    required this.id,
    required this.companyId,
    required this.name,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_id'] = Variable<String>(companyId);
    map['name'] = Variable<String>(name);
    return map;
  }

  LocalBrandsCompanion toCompanion(bool nullToAbsent) {
    return LocalBrandsCompanion(
      id: Value(id),
      companyId: Value(companyId),
      name: Value(name),
    );
  }

  factory LocalBrand.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalBrand(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String>(json['companyId']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String>(companyId),
      'name': serializer.toJson<String>(name),
    };
  }

  LocalBrand copyWith({String? id, String? companyId, String? name}) =>
      LocalBrand(
        id: id ?? this.id,
        companyId: companyId ?? this.companyId,
        name: name ?? this.name,
      );
  LocalBrand copyWithCompanion(LocalBrandsCompanion data) {
    return LocalBrand(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalBrand(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, companyId, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalBrand &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.name == this.name);
}

class LocalBrandsCompanion extends UpdateCompanion<LocalBrand> {
  final Value<String> id;
  final Value<String> companyId;
  final Value<String> name;
  final Value<int> rowid;
  const LocalBrandsCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalBrandsCompanion.insert({
    required String id,
    required String companyId,
    required String name,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       companyId = Value(companyId),
       name = Value(name);
  static Insertable<LocalBrand> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalBrandsCompanion copyWith({
    Value<String>? id,
    Value<String>? companyId,
    Value<String>? name,
    Value<int>? rowid,
  }) {
    return LocalBrandsCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalBrandsCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalPurchasesTable extends LocalPurchases
    with TableInfo<$LocalPurchasesTable, LocalPurchase> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalPurchasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storeIdMeta = const VerificationMeta(
    'storeId',
  );
  @override
  late final GeneratedColumn<String> storeId = GeneratedColumn<String>(
    'store_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _supplierIdMeta = const VerificationMeta(
    'supplierId',
  );
  @override
  late final GeneratedColumn<String> supplierId = GeneratedColumn<String>(
    'supplier_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _referenceMeta = const VerificationMeta(
    'reference',
  );
  @override
  late final GeneratedColumn<String> reference = GeneratedColumn<String>(
    'reference',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<double> total = GeneratedColumn<double>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    companyId,
    storeId,
    supplierId,
    reference,
    status,
    total,
    createdBy,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_purchases';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalPurchase> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('store_id')) {
      context.handle(
        _storeIdMeta,
        storeId.isAcceptableOrUnknown(data['store_id']!, _storeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storeIdMeta);
    }
    if (data.containsKey('supplier_id')) {
      context.handle(
        _supplierIdMeta,
        supplierId.isAcceptableOrUnknown(data['supplier_id']!, _supplierIdMeta),
      );
    } else if (isInserting) {
      context.missing(_supplierIdMeta);
    }
    if (data.containsKey('reference')) {
      context.handle(
        _referenceMeta,
        reference.isAcceptableOrUnknown(data['reference']!, _referenceMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalPurchase map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalPurchase(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      storeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_id'],
      )!,
      supplierId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supplier_id'],
      )!,
      reference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalPurchasesTable createAlias(String alias) {
    return $LocalPurchasesTable(attachedDatabase, alias);
  }
}

class LocalPurchase extends DataClass implements Insertable<LocalPurchase> {
  final String id;
  final String companyId;
  final String storeId;
  final String supplierId;
  final String? reference;
  final String status;
  final double total;
  final String createdBy;
  final String createdAt;
  final String updatedAt;
  const LocalPurchase({
    required this.id,
    required this.companyId,
    required this.storeId,
    required this.supplierId,
    this.reference,
    required this.status,
    required this.total,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_id'] = Variable<String>(companyId);
    map['store_id'] = Variable<String>(storeId);
    map['supplier_id'] = Variable<String>(supplierId);
    if (!nullToAbsent || reference != null) {
      map['reference'] = Variable<String>(reference);
    }
    map['status'] = Variable<String>(status);
    map['total'] = Variable<double>(total);
    map['created_by'] = Variable<String>(createdBy);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  LocalPurchasesCompanion toCompanion(bool nullToAbsent) {
    return LocalPurchasesCompanion(
      id: Value(id),
      companyId: Value(companyId),
      storeId: Value(storeId),
      supplierId: Value(supplierId),
      reference: reference == null && nullToAbsent
          ? const Value.absent()
          : Value(reference),
      status: Value(status),
      total: Value(total),
      createdBy: Value(createdBy),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalPurchase.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalPurchase(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String>(json['companyId']),
      storeId: serializer.fromJson<String>(json['storeId']),
      supplierId: serializer.fromJson<String>(json['supplierId']),
      reference: serializer.fromJson<String?>(json['reference']),
      status: serializer.fromJson<String>(json['status']),
      total: serializer.fromJson<double>(json['total']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String>(companyId),
      'storeId': serializer.toJson<String>(storeId),
      'supplierId': serializer.toJson<String>(supplierId),
      'reference': serializer.toJson<String?>(reference),
      'status': serializer.toJson<String>(status),
      'total': serializer.toJson<double>(total),
      'createdBy': serializer.toJson<String>(createdBy),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  LocalPurchase copyWith({
    String? id,
    String? companyId,
    String? storeId,
    String? supplierId,
    Value<String?> reference = const Value.absent(),
    String? status,
    double? total,
    String? createdBy,
    String? createdAt,
    String? updatedAt,
  }) => LocalPurchase(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    storeId: storeId ?? this.storeId,
    supplierId: supplierId ?? this.supplierId,
    reference: reference.present ? reference.value : this.reference,
    status: status ?? this.status,
    total: total ?? this.total,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalPurchase copyWithCompanion(LocalPurchasesCompanion data) {
    return LocalPurchase(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      storeId: data.storeId.present ? data.storeId.value : this.storeId,
      supplierId: data.supplierId.present
          ? data.supplierId.value
          : this.supplierId,
      reference: data.reference.present ? data.reference.value : this.reference,
      status: data.status.present ? data.status.value : this.status,
      total: data.total.present ? data.total.value : this.total,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalPurchase(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('storeId: $storeId, ')
          ..write('supplierId: $supplierId, ')
          ..write('reference: $reference, ')
          ..write('status: $status, ')
          ..write('total: $total, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    companyId,
    storeId,
    supplierId,
    reference,
    status,
    total,
    createdBy,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalPurchase &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.storeId == this.storeId &&
          other.supplierId == this.supplierId &&
          other.reference == this.reference &&
          other.status == this.status &&
          other.total == this.total &&
          other.createdBy == this.createdBy &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LocalPurchasesCompanion extends UpdateCompanion<LocalPurchase> {
  final Value<String> id;
  final Value<String> companyId;
  final Value<String> storeId;
  final Value<String> supplierId;
  final Value<String?> reference;
  final Value<String> status;
  final Value<double> total;
  final Value<String> createdBy;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const LocalPurchasesCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.storeId = const Value.absent(),
    this.supplierId = const Value.absent(),
    this.reference = const Value.absent(),
    this.status = const Value.absent(),
    this.total = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalPurchasesCompanion.insert({
    required String id,
    required String companyId,
    required String storeId,
    required String supplierId,
    this.reference = const Value.absent(),
    required String status,
    required double total,
    required String createdBy,
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       companyId = Value(companyId),
       storeId = Value(storeId),
       supplierId = Value(supplierId),
       status = Value(status),
       total = Value(total),
       createdBy = Value(createdBy),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LocalPurchase> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? storeId,
    Expression<String>? supplierId,
    Expression<String>? reference,
    Expression<String>? status,
    Expression<double>? total,
    Expression<String>? createdBy,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (storeId != null) 'store_id': storeId,
      if (supplierId != null) 'supplier_id': supplierId,
      if (reference != null) 'reference': reference,
      if (status != null) 'status': status,
      if (total != null) 'total': total,
      if (createdBy != null) 'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalPurchasesCompanion copyWith({
    Value<String>? id,
    Value<String>? companyId,
    Value<String>? storeId,
    Value<String>? supplierId,
    Value<String?>? reference,
    Value<String>? status,
    Value<double>? total,
    Value<String>? createdBy,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalPurchasesCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      storeId: storeId ?? this.storeId,
      supplierId: supplierId ?? this.supplierId,
      reference: reference ?? this.reference,
      status: status ?? this.status,
      total: total ?? this.total,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (storeId.present) {
      map['store_id'] = Variable<String>(storeId.value);
    }
    if (supplierId.present) {
      map['supplier_id'] = Variable<String>(supplierId.value);
    }
    if (reference.present) {
      map['reference'] = Variable<String>(reference.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (total.present) {
      map['total'] = Variable<double>(total.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalPurchasesCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('storeId: $storeId, ')
          ..write('supplierId: $supplierId, ')
          ..write('reference: $reference, ')
          ..write('status: $status, ')
          ..write('total: $total, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalPurchaseItemsTable extends LocalPurchaseItems
    with TableInfo<$LocalPurchaseItemsTable, LocalPurchaseItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalPurchaseItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _purchaseIdMeta = const VerificationMeta(
    'purchaseId',
  );
  @override
  late final GeneratedColumn<String> purchaseId = GeneratedColumn<String>(
    'purchase_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_purchases (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitPriceMeta = const VerificationMeta(
    'unitPrice',
  );
  @override
  late final GeneratedColumn<double> unitPrice = GeneratedColumn<double>(
    'unit_price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<double> total = GeneratedColumn<double>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    purchaseId,
    productId,
    quantity,
    unitPrice,
    total,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_purchase_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalPurchaseItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('purchase_id')) {
      context.handle(
        _purchaseIdMeta,
        purchaseId.isAcceptableOrUnknown(data['purchase_id']!, _purchaseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_purchaseIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('unit_price')) {
      context.handle(
        _unitPriceMeta,
        unitPrice.isAcceptableOrUnknown(data['unit_price']!, _unitPriceMeta),
      );
    } else if (isInserting) {
      context.missing(_unitPriceMeta);
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalPurchaseItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalPurchaseItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      purchaseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}purchase_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
      unitPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}unit_price'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total'],
      )!,
    );
  }

  @override
  $LocalPurchaseItemsTable createAlias(String alias) {
    return $LocalPurchaseItemsTable(attachedDatabase, alias);
  }
}

class LocalPurchaseItem extends DataClass
    implements Insertable<LocalPurchaseItem> {
  final String id;
  final String purchaseId;
  final String productId;
  final int quantity;
  final double unitPrice;
  final double total;
  const LocalPurchaseItem({
    required this.id,
    required this.purchaseId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['purchase_id'] = Variable<String>(purchaseId);
    map['product_id'] = Variable<String>(productId);
    map['quantity'] = Variable<int>(quantity);
    map['unit_price'] = Variable<double>(unitPrice);
    map['total'] = Variable<double>(total);
    return map;
  }

  LocalPurchaseItemsCompanion toCompanion(bool nullToAbsent) {
    return LocalPurchaseItemsCompanion(
      id: Value(id),
      purchaseId: Value(purchaseId),
      productId: Value(productId),
      quantity: Value(quantity),
      unitPrice: Value(unitPrice),
      total: Value(total),
    );
  }

  factory LocalPurchaseItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalPurchaseItem(
      id: serializer.fromJson<String>(json['id']),
      purchaseId: serializer.fromJson<String>(json['purchaseId']),
      productId: serializer.fromJson<String>(json['productId']),
      quantity: serializer.fromJson<int>(json['quantity']),
      unitPrice: serializer.fromJson<double>(json['unitPrice']),
      total: serializer.fromJson<double>(json['total']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'purchaseId': serializer.toJson<String>(purchaseId),
      'productId': serializer.toJson<String>(productId),
      'quantity': serializer.toJson<int>(quantity),
      'unitPrice': serializer.toJson<double>(unitPrice),
      'total': serializer.toJson<double>(total),
    };
  }

  LocalPurchaseItem copyWith({
    String? id,
    String? purchaseId,
    String? productId,
    int? quantity,
    double? unitPrice,
    double? total,
  }) => LocalPurchaseItem(
    id: id ?? this.id,
    purchaseId: purchaseId ?? this.purchaseId,
    productId: productId ?? this.productId,
    quantity: quantity ?? this.quantity,
    unitPrice: unitPrice ?? this.unitPrice,
    total: total ?? this.total,
  );
  LocalPurchaseItem copyWithCompanion(LocalPurchaseItemsCompanion data) {
    return LocalPurchaseItem(
      id: data.id.present ? data.id.value : this.id,
      purchaseId: data.purchaseId.present
          ? data.purchaseId.value
          : this.purchaseId,
      productId: data.productId.present ? data.productId.value : this.productId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unitPrice: data.unitPrice.present ? data.unitPrice.value : this.unitPrice,
      total: data.total.present ? data.total.value : this.total,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalPurchaseItem(')
          ..write('id: $id, ')
          ..write('purchaseId: $purchaseId, ')
          ..write('productId: $productId, ')
          ..write('quantity: $quantity, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('total: $total')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, purchaseId, productId, quantity, unitPrice, total);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalPurchaseItem &&
          other.id == this.id &&
          other.purchaseId == this.purchaseId &&
          other.productId == this.productId &&
          other.quantity == this.quantity &&
          other.unitPrice == this.unitPrice &&
          other.total == this.total);
}

class LocalPurchaseItemsCompanion extends UpdateCompanion<LocalPurchaseItem> {
  final Value<String> id;
  final Value<String> purchaseId;
  final Value<String> productId;
  final Value<int> quantity;
  final Value<double> unitPrice;
  final Value<double> total;
  final Value<int> rowid;
  const LocalPurchaseItemsCompanion({
    this.id = const Value.absent(),
    this.purchaseId = const Value.absent(),
    this.productId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unitPrice = const Value.absent(),
    this.total = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalPurchaseItemsCompanion.insert({
    required String id,
    required String purchaseId,
    required String productId,
    required int quantity,
    required double unitPrice,
    required double total,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       purchaseId = Value(purchaseId),
       productId = Value(productId),
       quantity = Value(quantity),
       unitPrice = Value(unitPrice),
       total = Value(total);
  static Insertable<LocalPurchaseItem> custom({
    Expression<String>? id,
    Expression<String>? purchaseId,
    Expression<String>? productId,
    Expression<int>? quantity,
    Expression<double>? unitPrice,
    Expression<double>? total,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (purchaseId != null) 'purchase_id': purchaseId,
      if (productId != null) 'product_id': productId,
      if (quantity != null) 'quantity': quantity,
      if (unitPrice != null) 'unit_price': unitPrice,
      if (total != null) 'total': total,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalPurchaseItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? purchaseId,
    Value<String>? productId,
    Value<int>? quantity,
    Value<double>? unitPrice,
    Value<double>? total,
    Value<int>? rowid,
  }) {
    return LocalPurchaseItemsCompanion(
      id: id ?? this.id,
      purchaseId: purchaseId ?? this.purchaseId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      total: total ?? this.total,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (purchaseId.present) {
      map['purchase_id'] = Variable<String>(purchaseId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (unitPrice.present) {
      map['unit_price'] = Variable<double>(unitPrice.value);
    }
    if (total.present) {
      map['total'] = Variable<double>(total.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalPurchaseItemsCompanion(')
          ..write('id: $id, ')
          ..write('purchaseId: $purchaseId, ')
          ..write('productId: $productId, ')
          ..write('quantity: $quantity, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('total: $total, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalTransfersTable extends LocalTransfers
    with TableInfo<$LocalTransfersTable, LocalTransfer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalTransfersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fromStoreIdMeta = const VerificationMeta(
    'fromStoreId',
  );
  @override
  late final GeneratedColumn<String> fromStoreId = GeneratedColumn<String>(
    'from_store_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toStoreIdMeta = const VerificationMeta(
    'toStoreId',
  );
  @override
  late final GeneratedColumn<String> toStoreId = GeneratedColumn<String>(
    'to_store_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fromWarehouseMeta = const VerificationMeta(
    'fromWarehouse',
  );
  @override
  late final GeneratedColumn<bool> fromWarehouse = GeneratedColumn<bool>(
    'from_warehouse',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("from_warehouse" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _requestedByMeta = const VerificationMeta(
    'requestedBy',
  );
  @override
  late final GeneratedColumn<String> requestedBy = GeneratedColumn<String>(
    'requested_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _approvedByMeta = const VerificationMeta(
    'approvedBy',
  );
  @override
  late final GeneratedColumn<String> approvedBy = GeneratedColumn<String>(
    'approved_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shippedAtMeta = const VerificationMeta(
    'shippedAt',
  );
  @override
  late final GeneratedColumn<String> shippedAt = GeneratedColumn<String>(
    'shipped_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _receivedAtMeta = const VerificationMeta(
    'receivedAt',
  );
  @override
  late final GeneratedColumn<String> receivedAt = GeneratedColumn<String>(
    'received_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _receivedByMeta = const VerificationMeta(
    'receivedBy',
  );
  @override
  late final GeneratedColumn<String> receivedBy = GeneratedColumn<String>(
    'received_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    companyId,
    fromStoreId,
    toStoreId,
    fromWarehouse,
    status,
    requestedBy,
    approvedBy,
    shippedAt,
    receivedAt,
    receivedBy,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_transfers';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalTransfer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('from_store_id')) {
      context.handle(
        _fromStoreIdMeta,
        fromStoreId.isAcceptableOrUnknown(
          data['from_store_id']!,
          _fromStoreIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fromStoreIdMeta);
    }
    if (data.containsKey('to_store_id')) {
      context.handle(
        _toStoreIdMeta,
        toStoreId.isAcceptableOrUnknown(data['to_store_id']!, _toStoreIdMeta),
      );
    } else if (isInserting) {
      context.missing(_toStoreIdMeta);
    }
    if (data.containsKey('from_warehouse')) {
      context.handle(
        _fromWarehouseMeta,
        fromWarehouse.isAcceptableOrUnknown(
          data['from_warehouse']!,
          _fromWarehouseMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('requested_by')) {
      context.handle(
        _requestedByMeta,
        requestedBy.isAcceptableOrUnknown(
          data['requested_by']!,
          _requestedByMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_requestedByMeta);
    }
    if (data.containsKey('approved_by')) {
      context.handle(
        _approvedByMeta,
        approvedBy.isAcceptableOrUnknown(data['approved_by']!, _approvedByMeta),
      );
    }
    if (data.containsKey('shipped_at')) {
      context.handle(
        _shippedAtMeta,
        shippedAt.isAcceptableOrUnknown(data['shipped_at']!, _shippedAtMeta),
      );
    }
    if (data.containsKey('received_at')) {
      context.handle(
        _receivedAtMeta,
        receivedAt.isAcceptableOrUnknown(data['received_at']!, _receivedAtMeta),
      );
    }
    if (data.containsKey('received_by')) {
      context.handle(
        _receivedByMeta,
        receivedBy.isAcceptableOrUnknown(data['received_by']!, _receivedByMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalTransfer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalTransfer(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      fromStoreId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_store_id'],
      )!,
      toStoreId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_store_id'],
      )!,
      fromWarehouse: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}from_warehouse'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      requestedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}requested_by'],
      )!,
      approvedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}approved_by'],
      ),
      shippedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shipped_at'],
      ),
      receivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}received_at'],
      ),
      receivedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}received_by'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalTransfersTable createAlias(String alias) {
    return $LocalTransfersTable(attachedDatabase, alias);
  }
}

class LocalTransfer extends DataClass implements Insertable<LocalTransfer> {
  final String id;
  final String companyId;
  final String fromStoreId;
  final String toStoreId;
  final bool fromWarehouse;
  final String status;
  final String requestedBy;
  final String? approvedBy;
  final String? shippedAt;
  final String? receivedAt;
  final String? receivedBy;
  final String createdAt;
  final String updatedAt;
  const LocalTransfer({
    required this.id,
    required this.companyId,
    required this.fromStoreId,
    required this.toStoreId,
    required this.fromWarehouse,
    required this.status,
    required this.requestedBy,
    this.approvedBy,
    this.shippedAt,
    this.receivedAt,
    this.receivedBy,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_id'] = Variable<String>(companyId);
    map['from_store_id'] = Variable<String>(fromStoreId);
    map['to_store_id'] = Variable<String>(toStoreId);
    map['from_warehouse'] = Variable<bool>(fromWarehouse);
    map['status'] = Variable<String>(status);
    map['requested_by'] = Variable<String>(requestedBy);
    if (!nullToAbsent || approvedBy != null) {
      map['approved_by'] = Variable<String>(approvedBy);
    }
    if (!nullToAbsent || shippedAt != null) {
      map['shipped_at'] = Variable<String>(shippedAt);
    }
    if (!nullToAbsent || receivedAt != null) {
      map['received_at'] = Variable<String>(receivedAt);
    }
    if (!nullToAbsent || receivedBy != null) {
      map['received_by'] = Variable<String>(receivedBy);
    }
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  LocalTransfersCompanion toCompanion(bool nullToAbsent) {
    return LocalTransfersCompanion(
      id: Value(id),
      companyId: Value(companyId),
      fromStoreId: Value(fromStoreId),
      toStoreId: Value(toStoreId),
      fromWarehouse: Value(fromWarehouse),
      status: Value(status),
      requestedBy: Value(requestedBy),
      approvedBy: approvedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(approvedBy),
      shippedAt: shippedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(shippedAt),
      receivedAt: receivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(receivedAt),
      receivedBy: receivedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(receivedBy),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalTransfer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalTransfer(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String>(json['companyId']),
      fromStoreId: serializer.fromJson<String>(json['fromStoreId']),
      toStoreId: serializer.fromJson<String>(json['toStoreId']),
      fromWarehouse: serializer.fromJson<bool>(json['fromWarehouse']),
      status: serializer.fromJson<String>(json['status']),
      requestedBy: serializer.fromJson<String>(json['requestedBy']),
      approvedBy: serializer.fromJson<String?>(json['approvedBy']),
      shippedAt: serializer.fromJson<String?>(json['shippedAt']),
      receivedAt: serializer.fromJson<String?>(json['receivedAt']),
      receivedBy: serializer.fromJson<String?>(json['receivedBy']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String>(companyId),
      'fromStoreId': serializer.toJson<String>(fromStoreId),
      'toStoreId': serializer.toJson<String>(toStoreId),
      'fromWarehouse': serializer.toJson<bool>(fromWarehouse),
      'status': serializer.toJson<String>(status),
      'requestedBy': serializer.toJson<String>(requestedBy),
      'approvedBy': serializer.toJson<String?>(approvedBy),
      'shippedAt': serializer.toJson<String?>(shippedAt),
      'receivedAt': serializer.toJson<String?>(receivedAt),
      'receivedBy': serializer.toJson<String?>(receivedBy),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  LocalTransfer copyWith({
    String? id,
    String? companyId,
    String? fromStoreId,
    String? toStoreId,
    bool? fromWarehouse,
    String? status,
    String? requestedBy,
    Value<String?> approvedBy = const Value.absent(),
    Value<String?> shippedAt = const Value.absent(),
    Value<String?> receivedAt = const Value.absent(),
    Value<String?> receivedBy = const Value.absent(),
    String? createdAt,
    String? updatedAt,
  }) => LocalTransfer(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    fromStoreId: fromStoreId ?? this.fromStoreId,
    toStoreId: toStoreId ?? this.toStoreId,
    fromWarehouse: fromWarehouse ?? this.fromWarehouse,
    status: status ?? this.status,
    requestedBy: requestedBy ?? this.requestedBy,
    approvedBy: approvedBy.present ? approvedBy.value : this.approvedBy,
    shippedAt: shippedAt.present ? shippedAt.value : this.shippedAt,
    receivedAt: receivedAt.present ? receivedAt.value : this.receivedAt,
    receivedBy: receivedBy.present ? receivedBy.value : this.receivedBy,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalTransfer copyWithCompanion(LocalTransfersCompanion data) {
    return LocalTransfer(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      fromStoreId: data.fromStoreId.present
          ? data.fromStoreId.value
          : this.fromStoreId,
      toStoreId: data.toStoreId.present ? data.toStoreId.value : this.toStoreId,
      fromWarehouse: data.fromWarehouse.present
          ? data.fromWarehouse.value
          : this.fromWarehouse,
      status: data.status.present ? data.status.value : this.status,
      requestedBy: data.requestedBy.present
          ? data.requestedBy.value
          : this.requestedBy,
      approvedBy: data.approvedBy.present
          ? data.approvedBy.value
          : this.approvedBy,
      shippedAt: data.shippedAt.present ? data.shippedAt.value : this.shippedAt,
      receivedAt: data.receivedAt.present
          ? data.receivedAt.value
          : this.receivedAt,
      receivedBy: data.receivedBy.present
          ? data.receivedBy.value
          : this.receivedBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalTransfer(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('fromStoreId: $fromStoreId, ')
          ..write('toStoreId: $toStoreId, ')
          ..write('fromWarehouse: $fromWarehouse, ')
          ..write('status: $status, ')
          ..write('requestedBy: $requestedBy, ')
          ..write('approvedBy: $approvedBy, ')
          ..write('shippedAt: $shippedAt, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('receivedBy: $receivedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    companyId,
    fromStoreId,
    toStoreId,
    fromWarehouse,
    status,
    requestedBy,
    approvedBy,
    shippedAt,
    receivedAt,
    receivedBy,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalTransfer &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.fromStoreId == this.fromStoreId &&
          other.toStoreId == this.toStoreId &&
          other.fromWarehouse == this.fromWarehouse &&
          other.status == this.status &&
          other.requestedBy == this.requestedBy &&
          other.approvedBy == this.approvedBy &&
          other.shippedAt == this.shippedAt &&
          other.receivedAt == this.receivedAt &&
          other.receivedBy == this.receivedBy &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LocalTransfersCompanion extends UpdateCompanion<LocalTransfer> {
  final Value<String> id;
  final Value<String> companyId;
  final Value<String> fromStoreId;
  final Value<String> toStoreId;
  final Value<bool> fromWarehouse;
  final Value<String> status;
  final Value<String> requestedBy;
  final Value<String?> approvedBy;
  final Value<String?> shippedAt;
  final Value<String?> receivedAt;
  final Value<String?> receivedBy;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const LocalTransfersCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.fromStoreId = const Value.absent(),
    this.toStoreId = const Value.absent(),
    this.fromWarehouse = const Value.absent(),
    this.status = const Value.absent(),
    this.requestedBy = const Value.absent(),
    this.approvedBy = const Value.absent(),
    this.shippedAt = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.receivedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalTransfersCompanion.insert({
    required String id,
    required String companyId,
    required String fromStoreId,
    required String toStoreId,
    this.fromWarehouse = const Value.absent(),
    required String status,
    required String requestedBy,
    this.approvedBy = const Value.absent(),
    this.shippedAt = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.receivedBy = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       companyId = Value(companyId),
       fromStoreId = Value(fromStoreId),
       toStoreId = Value(toStoreId),
       status = Value(status),
       requestedBy = Value(requestedBy),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LocalTransfer> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? fromStoreId,
    Expression<String>? toStoreId,
    Expression<bool>? fromWarehouse,
    Expression<String>? status,
    Expression<String>? requestedBy,
    Expression<String>? approvedBy,
    Expression<String>? shippedAt,
    Expression<String>? receivedAt,
    Expression<String>? receivedBy,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (fromStoreId != null) 'from_store_id': fromStoreId,
      if (toStoreId != null) 'to_store_id': toStoreId,
      if (fromWarehouse != null) 'from_warehouse': fromWarehouse,
      if (status != null) 'status': status,
      if (requestedBy != null) 'requested_by': requestedBy,
      if (approvedBy != null) 'approved_by': approvedBy,
      if (shippedAt != null) 'shipped_at': shippedAt,
      if (receivedAt != null) 'received_at': receivedAt,
      if (receivedBy != null) 'received_by': receivedBy,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalTransfersCompanion copyWith({
    Value<String>? id,
    Value<String>? companyId,
    Value<String>? fromStoreId,
    Value<String>? toStoreId,
    Value<bool>? fromWarehouse,
    Value<String>? status,
    Value<String>? requestedBy,
    Value<String?>? approvedBy,
    Value<String?>? shippedAt,
    Value<String?>? receivedAt,
    Value<String?>? receivedBy,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalTransfersCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      fromStoreId: fromStoreId ?? this.fromStoreId,
      toStoreId: toStoreId ?? this.toStoreId,
      fromWarehouse: fromWarehouse ?? this.fromWarehouse,
      status: status ?? this.status,
      requestedBy: requestedBy ?? this.requestedBy,
      approvedBy: approvedBy ?? this.approvedBy,
      shippedAt: shippedAt ?? this.shippedAt,
      receivedAt: receivedAt ?? this.receivedAt,
      receivedBy: receivedBy ?? this.receivedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (fromStoreId.present) {
      map['from_store_id'] = Variable<String>(fromStoreId.value);
    }
    if (toStoreId.present) {
      map['to_store_id'] = Variable<String>(toStoreId.value);
    }
    if (fromWarehouse.present) {
      map['from_warehouse'] = Variable<bool>(fromWarehouse.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (requestedBy.present) {
      map['requested_by'] = Variable<String>(requestedBy.value);
    }
    if (approvedBy.present) {
      map['approved_by'] = Variable<String>(approvedBy.value);
    }
    if (shippedAt.present) {
      map['shipped_at'] = Variable<String>(shippedAt.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<String>(receivedAt.value);
    }
    if (receivedBy.present) {
      map['received_by'] = Variable<String>(receivedBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalTransfersCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('fromStoreId: $fromStoreId, ')
          ..write('toStoreId: $toStoreId, ')
          ..write('fromWarehouse: $fromWarehouse, ')
          ..write('status: $status, ')
          ..write('requestedBy: $requestedBy, ')
          ..write('approvedBy: $approvedBy, ')
          ..write('shippedAt: $shippedAt, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('receivedBy: $receivedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalTransferItemsTable extends LocalTransferItems
    with TableInfo<$LocalTransferItemsTable, LocalTransferItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalTransferItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transferIdMeta = const VerificationMeta(
    'transferId',
  );
  @override
  late final GeneratedColumn<String> transferId = GeneratedColumn<String>(
    'transfer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_transfers (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityRequestedMeta = const VerificationMeta(
    'quantityRequested',
  );
  @override
  late final GeneratedColumn<int> quantityRequested = GeneratedColumn<int>(
    'quantity_requested',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityShippedMeta = const VerificationMeta(
    'quantityShipped',
  );
  @override
  late final GeneratedColumn<int> quantityShipped = GeneratedColumn<int>(
    'quantity_shipped',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _quantityReceivedMeta = const VerificationMeta(
    'quantityReceived',
  );
  @override
  late final GeneratedColumn<int> quantityReceived = GeneratedColumn<int>(
    'quantity_received',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    transferId,
    productId,
    quantityRequested,
    quantityShipped,
    quantityReceived,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_transfer_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalTransferItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('transfer_id')) {
      context.handle(
        _transferIdMeta,
        transferId.isAcceptableOrUnknown(data['transfer_id']!, _transferIdMeta),
      );
    } else if (isInserting) {
      context.missing(_transferIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('quantity_requested')) {
      context.handle(
        _quantityRequestedMeta,
        quantityRequested.isAcceptableOrUnknown(
          data['quantity_requested']!,
          _quantityRequestedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_quantityRequestedMeta);
    }
    if (data.containsKey('quantity_shipped')) {
      context.handle(
        _quantityShippedMeta,
        quantityShipped.isAcceptableOrUnknown(
          data['quantity_shipped']!,
          _quantityShippedMeta,
        ),
      );
    }
    if (data.containsKey('quantity_received')) {
      context.handle(
        _quantityReceivedMeta,
        quantityReceived.isAcceptableOrUnknown(
          data['quantity_received']!,
          _quantityReceivedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalTransferItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalTransferItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      transferId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transfer_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      quantityRequested: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity_requested'],
      )!,
      quantityShipped: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity_shipped'],
      )!,
      quantityReceived: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity_received'],
      )!,
    );
  }

  @override
  $LocalTransferItemsTable createAlias(String alias) {
    return $LocalTransferItemsTable(attachedDatabase, alias);
  }
}

class LocalTransferItem extends DataClass
    implements Insertable<LocalTransferItem> {
  final String id;
  final String transferId;
  final String productId;
  final int quantityRequested;
  final int quantityShipped;
  final int quantityReceived;
  const LocalTransferItem({
    required this.id,
    required this.transferId,
    required this.productId,
    required this.quantityRequested,
    required this.quantityShipped,
    required this.quantityReceived,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['transfer_id'] = Variable<String>(transferId);
    map['product_id'] = Variable<String>(productId);
    map['quantity_requested'] = Variable<int>(quantityRequested);
    map['quantity_shipped'] = Variable<int>(quantityShipped);
    map['quantity_received'] = Variable<int>(quantityReceived);
    return map;
  }

  LocalTransferItemsCompanion toCompanion(bool nullToAbsent) {
    return LocalTransferItemsCompanion(
      id: Value(id),
      transferId: Value(transferId),
      productId: Value(productId),
      quantityRequested: Value(quantityRequested),
      quantityShipped: Value(quantityShipped),
      quantityReceived: Value(quantityReceived),
    );
  }

  factory LocalTransferItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalTransferItem(
      id: serializer.fromJson<String>(json['id']),
      transferId: serializer.fromJson<String>(json['transferId']),
      productId: serializer.fromJson<String>(json['productId']),
      quantityRequested: serializer.fromJson<int>(json['quantityRequested']),
      quantityShipped: serializer.fromJson<int>(json['quantityShipped']),
      quantityReceived: serializer.fromJson<int>(json['quantityReceived']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'transferId': serializer.toJson<String>(transferId),
      'productId': serializer.toJson<String>(productId),
      'quantityRequested': serializer.toJson<int>(quantityRequested),
      'quantityShipped': serializer.toJson<int>(quantityShipped),
      'quantityReceived': serializer.toJson<int>(quantityReceived),
    };
  }

  LocalTransferItem copyWith({
    String? id,
    String? transferId,
    String? productId,
    int? quantityRequested,
    int? quantityShipped,
    int? quantityReceived,
  }) => LocalTransferItem(
    id: id ?? this.id,
    transferId: transferId ?? this.transferId,
    productId: productId ?? this.productId,
    quantityRequested: quantityRequested ?? this.quantityRequested,
    quantityShipped: quantityShipped ?? this.quantityShipped,
    quantityReceived: quantityReceived ?? this.quantityReceived,
  );
  LocalTransferItem copyWithCompanion(LocalTransferItemsCompanion data) {
    return LocalTransferItem(
      id: data.id.present ? data.id.value : this.id,
      transferId: data.transferId.present
          ? data.transferId.value
          : this.transferId,
      productId: data.productId.present ? data.productId.value : this.productId,
      quantityRequested: data.quantityRequested.present
          ? data.quantityRequested.value
          : this.quantityRequested,
      quantityShipped: data.quantityShipped.present
          ? data.quantityShipped.value
          : this.quantityShipped,
      quantityReceived: data.quantityReceived.present
          ? data.quantityReceived.value
          : this.quantityReceived,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalTransferItem(')
          ..write('id: $id, ')
          ..write('transferId: $transferId, ')
          ..write('productId: $productId, ')
          ..write('quantityRequested: $quantityRequested, ')
          ..write('quantityShipped: $quantityShipped, ')
          ..write('quantityReceived: $quantityReceived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    transferId,
    productId,
    quantityRequested,
    quantityShipped,
    quantityReceived,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalTransferItem &&
          other.id == this.id &&
          other.transferId == this.transferId &&
          other.productId == this.productId &&
          other.quantityRequested == this.quantityRequested &&
          other.quantityShipped == this.quantityShipped &&
          other.quantityReceived == this.quantityReceived);
}

class LocalTransferItemsCompanion extends UpdateCompanion<LocalTransferItem> {
  final Value<String> id;
  final Value<String> transferId;
  final Value<String> productId;
  final Value<int> quantityRequested;
  final Value<int> quantityShipped;
  final Value<int> quantityReceived;
  final Value<int> rowid;
  const LocalTransferItemsCompanion({
    this.id = const Value.absent(),
    this.transferId = const Value.absent(),
    this.productId = const Value.absent(),
    this.quantityRequested = const Value.absent(),
    this.quantityShipped = const Value.absent(),
    this.quantityReceived = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalTransferItemsCompanion.insert({
    required String id,
    required String transferId,
    required String productId,
    required int quantityRequested,
    this.quantityShipped = const Value.absent(),
    this.quantityReceived = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       transferId = Value(transferId),
       productId = Value(productId),
       quantityRequested = Value(quantityRequested);
  static Insertable<LocalTransferItem> custom({
    Expression<String>? id,
    Expression<String>? transferId,
    Expression<String>? productId,
    Expression<int>? quantityRequested,
    Expression<int>? quantityShipped,
    Expression<int>? quantityReceived,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (transferId != null) 'transfer_id': transferId,
      if (productId != null) 'product_id': productId,
      if (quantityRequested != null) 'quantity_requested': quantityRequested,
      if (quantityShipped != null) 'quantity_shipped': quantityShipped,
      if (quantityReceived != null) 'quantity_received': quantityReceived,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalTransferItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? transferId,
    Value<String>? productId,
    Value<int>? quantityRequested,
    Value<int>? quantityShipped,
    Value<int>? quantityReceived,
    Value<int>? rowid,
  }) {
    return LocalTransferItemsCompanion(
      id: id ?? this.id,
      transferId: transferId ?? this.transferId,
      productId: productId ?? this.productId,
      quantityRequested: quantityRequested ?? this.quantityRequested,
      quantityShipped: quantityShipped ?? this.quantityShipped,
      quantityReceived: quantityReceived ?? this.quantityReceived,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (transferId.present) {
      map['transfer_id'] = Variable<String>(transferId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (quantityRequested.present) {
      map['quantity_requested'] = Variable<int>(quantityRequested.value);
    }
    if (quantityShipped.present) {
      map['quantity_shipped'] = Variable<int>(quantityShipped.value);
    }
    if (quantityReceived.present) {
      map['quantity_received'] = Variable<int>(quantityReceived.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalTransferItemsCompanion(')
          ..write('id: $id, ')
          ..write('transferId: $transferId, ')
          ..write('productId: $productId, ')
          ..write('quantityRequested: $quantityRequested, ')
          ..write('quantityShipped: $quantityShipped, ')
          ..write('quantityReceived: $quantityReceived, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalWarehouseInventoryTable extends LocalWarehouseInventory
    with TableInfo<$LocalWarehouseInventoryTable, LocalWarehouseInventoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalWarehouseInventoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _avgUnitCostMeta = const VerificationMeta(
    'avgUnitCost',
  );
  @override
  late final GeneratedColumn<double> avgUnitCost = GeneratedColumn<double>(
    'avg_unit_cost',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stockMinWarehouseMeta = const VerificationMeta(
    'stockMinWarehouse',
  );
  @override
  late final GeneratedColumn<int> stockMinWarehouse = GeneratedColumn<int>(
    'stock_min_warehouse',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    companyId,
    productId,
    quantity,
    avgUnitCost,
    stockMinWarehouse,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_warehouse_inventory';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalWarehouseInventoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('avg_unit_cost')) {
      context.handle(
        _avgUnitCostMeta,
        avgUnitCost.isAcceptableOrUnknown(
          data['avg_unit_cost']!,
          _avgUnitCostMeta,
        ),
      );
    }
    if (data.containsKey('stock_min_warehouse')) {
      context.handle(
        _stockMinWarehouseMeta,
        stockMinWarehouse.isAcceptableOrUnknown(
          data['stock_min_warehouse']!,
          _stockMinWarehouseMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {companyId, productId};
  @override
  LocalWarehouseInventoryData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalWarehouseInventoryData(
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
      avgUnitCost: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}avg_unit_cost'],
      ),
      stockMinWarehouse: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stock_min_warehouse'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalWarehouseInventoryTable createAlias(String alias) {
    return $LocalWarehouseInventoryTable(attachedDatabase, alias);
  }
}

class LocalWarehouseInventoryData extends DataClass
    implements Insertable<LocalWarehouseInventoryData> {
  final String companyId;
  final String productId;
  final int quantity;
  final double? avgUnitCost;
  final int stockMinWarehouse;
  final String updatedAt;
  const LocalWarehouseInventoryData({
    required this.companyId,
    required this.productId,
    required this.quantity,
    this.avgUnitCost,
    required this.stockMinWarehouse,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['company_id'] = Variable<String>(companyId);
    map['product_id'] = Variable<String>(productId);
    map['quantity'] = Variable<int>(quantity);
    if (!nullToAbsent || avgUnitCost != null) {
      map['avg_unit_cost'] = Variable<double>(avgUnitCost);
    }
    map['stock_min_warehouse'] = Variable<int>(stockMinWarehouse);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  LocalWarehouseInventoryCompanion toCompanion(bool nullToAbsent) {
    return LocalWarehouseInventoryCompanion(
      companyId: Value(companyId),
      productId: Value(productId),
      quantity: Value(quantity),
      avgUnitCost: avgUnitCost == null && nullToAbsent
          ? const Value.absent()
          : Value(avgUnitCost),
      stockMinWarehouse: Value(stockMinWarehouse),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalWarehouseInventoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalWarehouseInventoryData(
      companyId: serializer.fromJson<String>(json['companyId']),
      productId: serializer.fromJson<String>(json['productId']),
      quantity: serializer.fromJson<int>(json['quantity']),
      avgUnitCost: serializer.fromJson<double?>(json['avgUnitCost']),
      stockMinWarehouse: serializer.fromJson<int>(json['stockMinWarehouse']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'companyId': serializer.toJson<String>(companyId),
      'productId': serializer.toJson<String>(productId),
      'quantity': serializer.toJson<int>(quantity),
      'avgUnitCost': serializer.toJson<double?>(avgUnitCost),
      'stockMinWarehouse': serializer.toJson<int>(stockMinWarehouse),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  LocalWarehouseInventoryData copyWith({
    String? companyId,
    String? productId,
    int? quantity,
    Value<double?> avgUnitCost = const Value.absent(),
    int? stockMinWarehouse,
    String? updatedAt,
  }) => LocalWarehouseInventoryData(
    companyId: companyId ?? this.companyId,
    productId: productId ?? this.productId,
    quantity: quantity ?? this.quantity,
    avgUnitCost: avgUnitCost.present ? avgUnitCost.value : this.avgUnitCost,
    stockMinWarehouse: stockMinWarehouse ?? this.stockMinWarehouse,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalWarehouseInventoryData copyWithCompanion(
    LocalWarehouseInventoryCompanion data,
  ) {
    return LocalWarehouseInventoryData(
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      productId: data.productId.present ? data.productId.value : this.productId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      avgUnitCost: data.avgUnitCost.present
          ? data.avgUnitCost.value
          : this.avgUnitCost,
      stockMinWarehouse: data.stockMinWarehouse.present
          ? data.stockMinWarehouse.value
          : this.stockMinWarehouse,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalWarehouseInventoryData(')
          ..write('companyId: $companyId, ')
          ..write('productId: $productId, ')
          ..write('quantity: $quantity, ')
          ..write('avgUnitCost: $avgUnitCost, ')
          ..write('stockMinWarehouse: $stockMinWarehouse, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    companyId,
    productId,
    quantity,
    avgUnitCost,
    stockMinWarehouse,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalWarehouseInventoryData &&
          other.companyId == this.companyId &&
          other.productId == this.productId &&
          other.quantity == this.quantity &&
          other.avgUnitCost == this.avgUnitCost &&
          other.stockMinWarehouse == this.stockMinWarehouse &&
          other.updatedAt == this.updatedAt);
}

class LocalWarehouseInventoryCompanion
    extends UpdateCompanion<LocalWarehouseInventoryData> {
  final Value<String> companyId;
  final Value<String> productId;
  final Value<int> quantity;
  final Value<double?> avgUnitCost;
  final Value<int> stockMinWarehouse;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const LocalWarehouseInventoryCompanion({
    this.companyId = const Value.absent(),
    this.productId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.avgUnitCost = const Value.absent(),
    this.stockMinWarehouse = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalWarehouseInventoryCompanion.insert({
    required String companyId,
    required String productId,
    this.quantity = const Value.absent(),
    this.avgUnitCost = const Value.absent(),
    this.stockMinWarehouse = const Value.absent(),
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : companyId = Value(companyId),
       productId = Value(productId),
       updatedAt = Value(updatedAt);
  static Insertable<LocalWarehouseInventoryData> custom({
    Expression<String>? companyId,
    Expression<String>? productId,
    Expression<int>? quantity,
    Expression<double>? avgUnitCost,
    Expression<int>? stockMinWarehouse,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (companyId != null) 'company_id': companyId,
      if (productId != null) 'product_id': productId,
      if (quantity != null) 'quantity': quantity,
      if (avgUnitCost != null) 'avg_unit_cost': avgUnitCost,
      if (stockMinWarehouse != null) 'stock_min_warehouse': stockMinWarehouse,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalWarehouseInventoryCompanion copyWith({
    Value<String>? companyId,
    Value<String>? productId,
    Value<int>? quantity,
    Value<double?>? avgUnitCost,
    Value<int>? stockMinWarehouse,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalWarehouseInventoryCompanion(
      companyId: companyId ?? this.companyId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      avgUnitCost: avgUnitCost ?? this.avgUnitCost,
      stockMinWarehouse: stockMinWarehouse ?? this.stockMinWarehouse,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (avgUnitCost.present) {
      map['avg_unit_cost'] = Variable<double>(avgUnitCost.value);
    }
    if (stockMinWarehouse.present) {
      map['stock_min_warehouse'] = Variable<int>(stockMinWarehouse.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalWarehouseInventoryCompanion(')
          ..write('companyId: $companyId, ')
          ..write('productId: $productId, ')
          ..write('quantity: $quantity, ')
          ..write('avgUnitCost: $avgUnitCost, ')
          ..write('stockMinWarehouse: $stockMinWarehouse, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalWarehouseMovementsTable extends LocalWarehouseMovements
    with TableInfo<$LocalWarehouseMovementsTable, LocalWarehouseMovement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalWarehouseMovementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _movementKindMeta = const VerificationMeta(
    'movementKind',
  );
  @override
  late final GeneratedColumn<String> movementKind = GeneratedColumn<String>(
    'movement_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitCostMeta = const VerificationMeta(
    'unitCost',
  );
  @override
  late final GeneratedColumn<double> unitCost = GeneratedColumn<double>(
    'unit_cost',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _packagingTypeMeta = const VerificationMeta(
    'packagingType',
  );
  @override
  late final GeneratedColumn<String> packagingType = GeneratedColumn<String>(
    'packaging_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unite'),
  );
  static const VerificationMeta _packsQuantityMeta = const VerificationMeta(
    'packsQuantity',
  );
  @override
  late final GeneratedColumn<double> packsQuantity = GeneratedColumn<double>(
    'packs_quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _referenceTypeMeta = const VerificationMeta(
    'referenceType',
  );
  @override
  late final GeneratedColumn<String> referenceType = GeneratedColumn<String>(
    'reference_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _referenceIdMeta = const VerificationMeta(
    'referenceId',
  );
  @override
  late final GeneratedColumn<String> referenceId = GeneratedColumn<String>(
    'reference_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    companyId,
    productId,
    movementKind,
    quantity,
    unitCost,
    packagingType,
    packsQuantity,
    referenceType,
    referenceId,
    notes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_warehouse_movements';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalWarehouseMovement> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('movement_kind')) {
      context.handle(
        _movementKindMeta,
        movementKind.isAcceptableOrUnknown(
          data['movement_kind']!,
          _movementKindMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_movementKindMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('unit_cost')) {
      context.handle(
        _unitCostMeta,
        unitCost.isAcceptableOrUnknown(data['unit_cost']!, _unitCostMeta),
      );
    }
    if (data.containsKey('packaging_type')) {
      context.handle(
        _packagingTypeMeta,
        packagingType.isAcceptableOrUnknown(
          data['packaging_type']!,
          _packagingTypeMeta,
        ),
      );
    }
    if (data.containsKey('packs_quantity')) {
      context.handle(
        _packsQuantityMeta,
        packsQuantity.isAcceptableOrUnknown(
          data['packs_quantity']!,
          _packsQuantityMeta,
        ),
      );
    }
    if (data.containsKey('reference_type')) {
      context.handle(
        _referenceTypeMeta,
        referenceType.isAcceptableOrUnknown(
          data['reference_type']!,
          _referenceTypeMeta,
        ),
      );
    }
    if (data.containsKey('reference_id')) {
      context.handle(
        _referenceIdMeta,
        referenceId.isAcceptableOrUnknown(
          data['reference_id']!,
          _referenceIdMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalWarehouseMovement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalWarehouseMovement(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      movementKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}movement_kind'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
      unitCost: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}unit_cost'],
      ),
      packagingType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}packaging_type'],
      )!,
      packsQuantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}packs_quantity'],
      )!,
      referenceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_type'],
      )!,
      referenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_id'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LocalWarehouseMovementsTable createAlias(String alias) {
    return $LocalWarehouseMovementsTable(attachedDatabase, alias);
  }
}

class LocalWarehouseMovement extends DataClass
    implements Insertable<LocalWarehouseMovement> {
  final String id;
  final String companyId;
  final String productId;
  final String movementKind;
  final int quantity;
  final double? unitCost;
  final String packagingType;
  final double packsQuantity;
  final String referenceType;
  final String? referenceId;
  final String? notes;
  final String createdAt;
  const LocalWarehouseMovement({
    required this.id,
    required this.companyId,
    required this.productId,
    required this.movementKind,
    required this.quantity,
    this.unitCost,
    required this.packagingType,
    required this.packsQuantity,
    required this.referenceType,
    this.referenceId,
    this.notes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_id'] = Variable<String>(companyId);
    map['product_id'] = Variable<String>(productId);
    map['movement_kind'] = Variable<String>(movementKind);
    map['quantity'] = Variable<int>(quantity);
    if (!nullToAbsent || unitCost != null) {
      map['unit_cost'] = Variable<double>(unitCost);
    }
    map['packaging_type'] = Variable<String>(packagingType);
    map['packs_quantity'] = Variable<double>(packsQuantity);
    map['reference_type'] = Variable<String>(referenceType);
    if (!nullToAbsent || referenceId != null) {
      map['reference_id'] = Variable<String>(referenceId);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  LocalWarehouseMovementsCompanion toCompanion(bool nullToAbsent) {
    return LocalWarehouseMovementsCompanion(
      id: Value(id),
      companyId: Value(companyId),
      productId: Value(productId),
      movementKind: Value(movementKind),
      quantity: Value(quantity),
      unitCost: unitCost == null && nullToAbsent
          ? const Value.absent()
          : Value(unitCost),
      packagingType: Value(packagingType),
      packsQuantity: Value(packsQuantity),
      referenceType: Value(referenceType),
      referenceId: referenceId == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceId),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
    );
  }

  factory LocalWarehouseMovement.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalWarehouseMovement(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String>(json['companyId']),
      productId: serializer.fromJson<String>(json['productId']),
      movementKind: serializer.fromJson<String>(json['movementKind']),
      quantity: serializer.fromJson<int>(json['quantity']),
      unitCost: serializer.fromJson<double?>(json['unitCost']),
      packagingType: serializer.fromJson<String>(json['packagingType']),
      packsQuantity: serializer.fromJson<double>(json['packsQuantity']),
      referenceType: serializer.fromJson<String>(json['referenceType']),
      referenceId: serializer.fromJson<String?>(json['referenceId']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String>(companyId),
      'productId': serializer.toJson<String>(productId),
      'movementKind': serializer.toJson<String>(movementKind),
      'quantity': serializer.toJson<int>(quantity),
      'unitCost': serializer.toJson<double?>(unitCost),
      'packagingType': serializer.toJson<String>(packagingType),
      'packsQuantity': serializer.toJson<double>(packsQuantity),
      'referenceType': serializer.toJson<String>(referenceType),
      'referenceId': serializer.toJson<String?>(referenceId),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  LocalWarehouseMovement copyWith({
    String? id,
    String? companyId,
    String? productId,
    String? movementKind,
    int? quantity,
    Value<double?> unitCost = const Value.absent(),
    String? packagingType,
    double? packsQuantity,
    String? referenceType,
    Value<String?> referenceId = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    String? createdAt,
  }) => LocalWarehouseMovement(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    productId: productId ?? this.productId,
    movementKind: movementKind ?? this.movementKind,
    quantity: quantity ?? this.quantity,
    unitCost: unitCost.present ? unitCost.value : this.unitCost,
    packagingType: packagingType ?? this.packagingType,
    packsQuantity: packsQuantity ?? this.packsQuantity,
    referenceType: referenceType ?? this.referenceType,
    referenceId: referenceId.present ? referenceId.value : this.referenceId,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
  );
  LocalWarehouseMovement copyWithCompanion(
    LocalWarehouseMovementsCompanion data,
  ) {
    return LocalWarehouseMovement(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      productId: data.productId.present ? data.productId.value : this.productId,
      movementKind: data.movementKind.present
          ? data.movementKind.value
          : this.movementKind,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unitCost: data.unitCost.present ? data.unitCost.value : this.unitCost,
      packagingType: data.packagingType.present
          ? data.packagingType.value
          : this.packagingType,
      packsQuantity: data.packsQuantity.present
          ? data.packsQuantity.value
          : this.packsQuantity,
      referenceType: data.referenceType.present
          ? data.referenceType.value
          : this.referenceType,
      referenceId: data.referenceId.present
          ? data.referenceId.value
          : this.referenceId,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalWarehouseMovement(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('productId: $productId, ')
          ..write('movementKind: $movementKind, ')
          ..write('quantity: $quantity, ')
          ..write('unitCost: $unitCost, ')
          ..write('packagingType: $packagingType, ')
          ..write('packsQuantity: $packsQuantity, ')
          ..write('referenceType: $referenceType, ')
          ..write('referenceId: $referenceId, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    companyId,
    productId,
    movementKind,
    quantity,
    unitCost,
    packagingType,
    packsQuantity,
    referenceType,
    referenceId,
    notes,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalWarehouseMovement &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.productId == this.productId &&
          other.movementKind == this.movementKind &&
          other.quantity == this.quantity &&
          other.unitCost == this.unitCost &&
          other.packagingType == this.packagingType &&
          other.packsQuantity == this.packsQuantity &&
          other.referenceType == this.referenceType &&
          other.referenceId == this.referenceId &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt);
}

class LocalWarehouseMovementsCompanion
    extends UpdateCompanion<LocalWarehouseMovement> {
  final Value<String> id;
  final Value<String> companyId;
  final Value<String> productId;
  final Value<String> movementKind;
  final Value<int> quantity;
  final Value<double?> unitCost;
  final Value<String> packagingType;
  final Value<double> packsQuantity;
  final Value<String> referenceType;
  final Value<String?> referenceId;
  final Value<String?> notes;
  final Value<String> createdAt;
  final Value<int> rowid;
  const LocalWarehouseMovementsCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.productId = const Value.absent(),
    this.movementKind = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unitCost = const Value.absent(),
    this.packagingType = const Value.absent(),
    this.packsQuantity = const Value.absent(),
    this.referenceType = const Value.absent(),
    this.referenceId = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalWarehouseMovementsCompanion.insert({
    required String id,
    required String companyId,
    required String productId,
    required String movementKind,
    required int quantity,
    this.unitCost = const Value.absent(),
    this.packagingType = const Value.absent(),
    this.packsQuantity = const Value.absent(),
    this.referenceType = const Value.absent(),
    this.referenceId = const Value.absent(),
    this.notes = const Value.absent(),
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       companyId = Value(companyId),
       productId = Value(productId),
       movementKind = Value(movementKind),
       quantity = Value(quantity),
       createdAt = Value(createdAt);
  static Insertable<LocalWarehouseMovement> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? productId,
    Expression<String>? movementKind,
    Expression<int>? quantity,
    Expression<double>? unitCost,
    Expression<String>? packagingType,
    Expression<double>? packsQuantity,
    Expression<String>? referenceType,
    Expression<String>? referenceId,
    Expression<String>? notes,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (productId != null) 'product_id': productId,
      if (movementKind != null) 'movement_kind': movementKind,
      if (quantity != null) 'quantity': quantity,
      if (unitCost != null) 'unit_cost': unitCost,
      if (packagingType != null) 'packaging_type': packagingType,
      if (packsQuantity != null) 'packs_quantity': packsQuantity,
      if (referenceType != null) 'reference_type': referenceType,
      if (referenceId != null) 'reference_id': referenceId,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalWarehouseMovementsCompanion copyWith({
    Value<String>? id,
    Value<String>? companyId,
    Value<String>? productId,
    Value<String>? movementKind,
    Value<int>? quantity,
    Value<double?>? unitCost,
    Value<String>? packagingType,
    Value<double>? packsQuantity,
    Value<String>? referenceType,
    Value<String?>? referenceId,
    Value<String?>? notes,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return LocalWarehouseMovementsCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      productId: productId ?? this.productId,
      movementKind: movementKind ?? this.movementKind,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      packagingType: packagingType ?? this.packagingType,
      packsQuantity: packsQuantity ?? this.packsQuantity,
      referenceType: referenceType ?? this.referenceType,
      referenceId: referenceId ?? this.referenceId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (movementKind.present) {
      map['movement_kind'] = Variable<String>(movementKind.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (unitCost.present) {
      map['unit_cost'] = Variable<double>(unitCost.value);
    }
    if (packagingType.present) {
      map['packaging_type'] = Variable<String>(packagingType.value);
    }
    if (packsQuantity.present) {
      map['packs_quantity'] = Variable<double>(packsQuantity.value);
    }
    if (referenceType.present) {
      map['reference_type'] = Variable<String>(referenceType.value);
    }
    if (referenceId.present) {
      map['reference_id'] = Variable<String>(referenceId.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalWarehouseMovementsCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('productId: $productId, ')
          ..write('movementKind: $movementKind, ')
          ..write('quantity: $quantity, ')
          ..write('unitCost: $unitCost, ')
          ..write('packagingType: $packagingType, ')
          ..write('packsQuantity: $packsQuantity, ')
          ..write('referenceType: $referenceType, ')
          ..write('referenceId: $referenceId, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalWarehouseDispatchInvoicesTable
    extends LocalWarehouseDispatchInvoices
    with
        TableInfo<
          $LocalWarehouseDispatchInvoicesTable,
          LocalWarehouseDispatchInvoice
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalWarehouseDispatchInvoicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta(
    'customerId',
  );
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
    'customer_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customerNameMeta = const VerificationMeta(
    'customerName',
  );
  @override
  late final GeneratedColumn<String> customerName = GeneratedColumn<String>(
    'customer_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _documentNumberMeta = const VerificationMeta(
    'documentNumber',
  );
  @override
  late final GeneratedColumn<String> documentNumber = GeneratedColumn<String>(
    'document_number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    companyId,
    customerId,
    customerName,
    documentNumber,
    notes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_warehouse_dispatch_invoices';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalWarehouseDispatchInvoice> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('customer_id')) {
      context.handle(
        _customerIdMeta,
        customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta),
      );
    }
    if (data.containsKey('customer_name')) {
      context.handle(
        _customerNameMeta,
        customerName.isAcceptableOrUnknown(
          data['customer_name']!,
          _customerNameMeta,
        ),
      );
    }
    if (data.containsKey('document_number')) {
      context.handle(
        _documentNumberMeta,
        documentNumber.isAcceptableOrUnknown(
          data['document_number']!,
          _documentNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_documentNumberMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalWarehouseDispatchInvoice map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalWarehouseDispatchInvoice(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      customerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_id'],
      ),
      customerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_name'],
      ),
      documentNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_number'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LocalWarehouseDispatchInvoicesTable createAlias(String alias) {
    return $LocalWarehouseDispatchInvoicesTable(attachedDatabase, alias);
  }
}

class LocalWarehouseDispatchInvoice extends DataClass
    implements Insertable<LocalWarehouseDispatchInvoice> {
  final String id;
  final String companyId;
  final String? customerId;
  final String? customerName;
  final String documentNumber;
  final String? notes;
  final String createdAt;
  const LocalWarehouseDispatchInvoice({
    required this.id,
    required this.companyId,
    this.customerId,
    this.customerName,
    required this.documentNumber,
    this.notes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_id'] = Variable<String>(companyId);
    if (!nullToAbsent || customerId != null) {
      map['customer_id'] = Variable<String>(customerId);
    }
    if (!nullToAbsent || customerName != null) {
      map['customer_name'] = Variable<String>(customerName);
    }
    map['document_number'] = Variable<String>(documentNumber);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  LocalWarehouseDispatchInvoicesCompanion toCompanion(bool nullToAbsent) {
    return LocalWarehouseDispatchInvoicesCompanion(
      id: Value(id),
      companyId: Value(companyId),
      customerId: customerId == null && nullToAbsent
          ? const Value.absent()
          : Value(customerId),
      customerName: customerName == null && nullToAbsent
          ? const Value.absent()
          : Value(customerName),
      documentNumber: Value(documentNumber),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
    );
  }

  factory LocalWarehouseDispatchInvoice.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalWarehouseDispatchInvoice(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String>(json['companyId']),
      customerId: serializer.fromJson<String?>(json['customerId']),
      customerName: serializer.fromJson<String?>(json['customerName']),
      documentNumber: serializer.fromJson<String>(json['documentNumber']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String>(companyId),
      'customerId': serializer.toJson<String?>(customerId),
      'customerName': serializer.toJson<String?>(customerName),
      'documentNumber': serializer.toJson<String>(documentNumber),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  LocalWarehouseDispatchInvoice copyWith({
    String? id,
    String? companyId,
    Value<String?> customerId = const Value.absent(),
    Value<String?> customerName = const Value.absent(),
    String? documentNumber,
    Value<String?> notes = const Value.absent(),
    String? createdAt,
  }) => LocalWarehouseDispatchInvoice(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    customerId: customerId.present ? customerId.value : this.customerId,
    customerName: customerName.present ? customerName.value : this.customerName,
    documentNumber: documentNumber ?? this.documentNumber,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
  );
  LocalWarehouseDispatchInvoice copyWithCompanion(
    LocalWarehouseDispatchInvoicesCompanion data,
  ) {
    return LocalWarehouseDispatchInvoice(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      customerId: data.customerId.present
          ? data.customerId.value
          : this.customerId,
      customerName: data.customerName.present
          ? data.customerName.value
          : this.customerName,
      documentNumber: data.documentNumber.present
          ? data.documentNumber.value
          : this.documentNumber,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalWarehouseDispatchInvoice(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('customerId: $customerId, ')
          ..write('customerName: $customerName, ')
          ..write('documentNumber: $documentNumber, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    companyId,
    customerId,
    customerName,
    documentNumber,
    notes,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalWarehouseDispatchInvoice &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.customerId == this.customerId &&
          other.customerName == this.customerName &&
          other.documentNumber == this.documentNumber &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt);
}

class LocalWarehouseDispatchInvoicesCompanion
    extends UpdateCompanion<LocalWarehouseDispatchInvoice> {
  final Value<String> id;
  final Value<String> companyId;
  final Value<String?> customerId;
  final Value<String?> customerName;
  final Value<String> documentNumber;
  final Value<String?> notes;
  final Value<String> createdAt;
  final Value<int> rowid;
  const LocalWarehouseDispatchInvoicesCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.customerId = const Value.absent(),
    this.customerName = const Value.absent(),
    this.documentNumber = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalWarehouseDispatchInvoicesCompanion.insert({
    required String id,
    required String companyId,
    this.customerId = const Value.absent(),
    this.customerName = const Value.absent(),
    required String documentNumber,
    this.notes = const Value.absent(),
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       companyId = Value(companyId),
       documentNumber = Value(documentNumber),
       createdAt = Value(createdAt);
  static Insertable<LocalWarehouseDispatchInvoice> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? customerId,
    Expression<String>? customerName,
    Expression<String>? documentNumber,
    Expression<String>? notes,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (customerId != null) 'customer_id': customerId,
      if (customerName != null) 'customer_name': customerName,
      if (documentNumber != null) 'document_number': documentNumber,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalWarehouseDispatchInvoicesCompanion copyWith({
    Value<String>? id,
    Value<String>? companyId,
    Value<String?>? customerId,
    Value<String?>? customerName,
    Value<String>? documentNumber,
    Value<String?>? notes,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return LocalWarehouseDispatchInvoicesCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      documentNumber: documentNumber ?? this.documentNumber,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (customerName.present) {
      map['customer_name'] = Variable<String>(customerName.value);
    }
    if (documentNumber.present) {
      map['document_number'] = Variable<String>(documentNumber.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalWarehouseDispatchInvoicesCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('customerId: $customerId, ')
          ..write('customerName: $customerName, ')
          ..write('documentNumber: $documentNumber, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalStockMovementsTable extends LocalStockMovements
    with TableInfo<$LocalStockMovementsTable, LocalStockMovement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalStockMovementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storeIdMeta = const VerificationMeta(
    'storeId',
  );
  @override
  late final GeneratedColumn<String> storeId = GeneratedColumn<String>(
    'store_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _referenceTypeMeta = const VerificationMeta(
    'referenceType',
  );
  @override
  late final GeneratedColumn<String> referenceType = GeneratedColumn<String>(
    'reference_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _referenceIdMeta = const VerificationMeta(
    'referenceId',
  );
  @override
  late final GeneratedColumn<String> referenceId = GeneratedColumn<String>(
    'reference_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    storeId,
    productId,
    type,
    quantity,
    referenceType,
    referenceId,
    createdBy,
    createdAt,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_stock_movements';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalStockMovement> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('store_id')) {
      context.handle(
        _storeIdMeta,
        storeId.isAcceptableOrUnknown(data['store_id']!, _storeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storeIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('reference_type')) {
      context.handle(
        _referenceTypeMeta,
        referenceType.isAcceptableOrUnknown(
          data['reference_type']!,
          _referenceTypeMeta,
        ),
      );
    }
    if (data.containsKey('reference_id')) {
      context.handle(
        _referenceIdMeta,
        referenceId.isAcceptableOrUnknown(
          data['reference_id']!,
          _referenceIdMeta,
        ),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalStockMovement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalStockMovement(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      storeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
      referenceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_type'],
      ),
      referenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_id'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $LocalStockMovementsTable createAlias(String alias) {
    return $LocalStockMovementsTable(attachedDatabase, alias);
  }
}

class LocalStockMovement extends DataClass
    implements Insertable<LocalStockMovement> {
  final String id;
  final String storeId;
  final String productId;
  final String type;
  final int quantity;
  final String? referenceType;
  final String? referenceId;
  final String? createdBy;
  final String createdAt;
  final String? notes;
  const LocalStockMovement({
    required this.id,
    required this.storeId,
    required this.productId,
    required this.type,
    required this.quantity,
    this.referenceType,
    this.referenceId,
    this.createdBy,
    required this.createdAt,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['store_id'] = Variable<String>(storeId);
    map['product_id'] = Variable<String>(productId);
    map['type'] = Variable<String>(type);
    map['quantity'] = Variable<int>(quantity);
    if (!nullToAbsent || referenceType != null) {
      map['reference_type'] = Variable<String>(referenceType);
    }
    if (!nullToAbsent || referenceId != null) {
      map['reference_id'] = Variable<String>(referenceId);
    }
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    map['created_at'] = Variable<String>(createdAt);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  LocalStockMovementsCompanion toCompanion(bool nullToAbsent) {
    return LocalStockMovementsCompanion(
      id: Value(id),
      storeId: Value(storeId),
      productId: Value(productId),
      type: Value(type),
      quantity: Value(quantity),
      referenceType: referenceType == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceType),
      referenceId: referenceId == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceId),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      createdAt: Value(createdAt),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory LocalStockMovement.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalStockMovement(
      id: serializer.fromJson<String>(json['id']),
      storeId: serializer.fromJson<String>(json['storeId']),
      productId: serializer.fromJson<String>(json['productId']),
      type: serializer.fromJson<String>(json['type']),
      quantity: serializer.fromJson<int>(json['quantity']),
      referenceType: serializer.fromJson<String?>(json['referenceType']),
      referenceId: serializer.fromJson<String?>(json['referenceId']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'storeId': serializer.toJson<String>(storeId),
      'productId': serializer.toJson<String>(productId),
      'type': serializer.toJson<String>(type),
      'quantity': serializer.toJson<int>(quantity),
      'referenceType': serializer.toJson<String?>(referenceType),
      'referenceId': serializer.toJson<String?>(referenceId),
      'createdBy': serializer.toJson<String?>(createdBy),
      'createdAt': serializer.toJson<String>(createdAt),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  LocalStockMovement copyWith({
    String? id,
    String? storeId,
    String? productId,
    String? type,
    int? quantity,
    Value<String?> referenceType = const Value.absent(),
    Value<String?> referenceId = const Value.absent(),
    Value<String?> createdBy = const Value.absent(),
    String? createdAt,
    Value<String?> notes = const Value.absent(),
  }) => LocalStockMovement(
    id: id ?? this.id,
    storeId: storeId ?? this.storeId,
    productId: productId ?? this.productId,
    type: type ?? this.type,
    quantity: quantity ?? this.quantity,
    referenceType: referenceType.present
        ? referenceType.value
        : this.referenceType,
    referenceId: referenceId.present ? referenceId.value : this.referenceId,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    notes: notes.present ? notes.value : this.notes,
  );
  LocalStockMovement copyWithCompanion(LocalStockMovementsCompanion data) {
    return LocalStockMovement(
      id: data.id.present ? data.id.value : this.id,
      storeId: data.storeId.present ? data.storeId.value : this.storeId,
      productId: data.productId.present ? data.productId.value : this.productId,
      type: data.type.present ? data.type.value : this.type,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      referenceType: data.referenceType.present
          ? data.referenceType.value
          : this.referenceType,
      referenceId: data.referenceId.present
          ? data.referenceId.value
          : this.referenceId,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalStockMovement(')
          ..write('id: $id, ')
          ..write('storeId: $storeId, ')
          ..write('productId: $productId, ')
          ..write('type: $type, ')
          ..write('quantity: $quantity, ')
          ..write('referenceType: $referenceType, ')
          ..write('referenceId: $referenceId, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    storeId,
    productId,
    type,
    quantity,
    referenceType,
    referenceId,
    createdBy,
    createdAt,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalStockMovement &&
          other.id == this.id &&
          other.storeId == this.storeId &&
          other.productId == this.productId &&
          other.type == this.type &&
          other.quantity == this.quantity &&
          other.referenceType == this.referenceType &&
          other.referenceId == this.referenceId &&
          other.createdBy == this.createdBy &&
          other.createdAt == this.createdAt &&
          other.notes == this.notes);
}

class LocalStockMovementsCompanion extends UpdateCompanion<LocalStockMovement> {
  final Value<String> id;
  final Value<String> storeId;
  final Value<String> productId;
  final Value<String> type;
  final Value<int> quantity;
  final Value<String?> referenceType;
  final Value<String?> referenceId;
  final Value<String?> createdBy;
  final Value<String> createdAt;
  final Value<String?> notes;
  final Value<int> rowid;
  const LocalStockMovementsCompanion({
    this.id = const Value.absent(),
    this.storeId = const Value.absent(),
    this.productId = const Value.absent(),
    this.type = const Value.absent(),
    this.quantity = const Value.absent(),
    this.referenceType = const Value.absent(),
    this.referenceId = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalStockMovementsCompanion.insert({
    required String id,
    required String storeId,
    required String productId,
    required String type,
    required int quantity,
    this.referenceType = const Value.absent(),
    this.referenceId = const Value.absent(),
    this.createdBy = const Value.absent(),
    required String createdAt,
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       storeId = Value(storeId),
       productId = Value(productId),
       type = Value(type),
       quantity = Value(quantity),
       createdAt = Value(createdAt);
  static Insertable<LocalStockMovement> custom({
    Expression<String>? id,
    Expression<String>? storeId,
    Expression<String>? productId,
    Expression<String>? type,
    Expression<int>? quantity,
    Expression<String>? referenceType,
    Expression<String>? referenceId,
    Expression<String>? createdBy,
    Expression<String>? createdAt,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (storeId != null) 'store_id': storeId,
      if (productId != null) 'product_id': productId,
      if (type != null) 'type': type,
      if (quantity != null) 'quantity': quantity,
      if (referenceType != null) 'reference_type': referenceType,
      if (referenceId != null) 'reference_id': referenceId,
      if (createdBy != null) 'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalStockMovementsCompanion copyWith({
    Value<String>? id,
    Value<String>? storeId,
    Value<String>? productId,
    Value<String>? type,
    Value<int>? quantity,
    Value<String?>? referenceType,
    Value<String?>? referenceId,
    Value<String?>? createdBy,
    Value<String>? createdAt,
    Value<String?>? notes,
    Value<int>? rowid,
  }) {
    return LocalStockMovementsCompanion(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      productId: productId ?? this.productId,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      referenceType: referenceType ?? this.referenceType,
      referenceId: referenceId ?? this.referenceId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (storeId.present) {
      map['store_id'] = Variable<String>(storeId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (referenceType.present) {
      map['reference_type'] = Variable<String>(referenceType.value);
    }
    if (referenceId.present) {
      map['reference_id'] = Variable<String>(referenceId.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalStockMovementsCompanion(')
          ..write('id: $id, ')
          ..write('storeId: $storeId, ')
          ..write('productId: $productId, ')
          ..write('type: $type, ')
          ..write('quantity: $quantity, ')
          ..write('referenceType: $referenceType, ')
          ..write('referenceId: $referenceId, ')
          ..write('createdBy: $createdBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalCompanySettingsTable extends LocalCompanySettings
    with TableInfo<$LocalCompanySettingsTable, LocalCompanySetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalCompanySettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueTextMeta = const VerificationMeta(
    'valueText',
  );
  @override
  late final GeneratedColumn<String> valueText = GeneratedColumn<String>(
    'value_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [companyId, key, valueText];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_company_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalCompanySetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value_text')) {
      context.handle(
        _valueTextMeta,
        valueText.isAcceptableOrUnknown(data['value_text']!, _valueTextMeta),
      );
    } else if (isInserting) {
      context.missing(_valueTextMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {companyId, key};
  @override
  LocalCompanySetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalCompanySetting(
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      valueText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_text'],
      )!,
    );
  }

  @override
  $LocalCompanySettingsTable createAlias(String alias) {
    return $LocalCompanySettingsTable(attachedDatabase, alias);
  }
}

class LocalCompanySetting extends DataClass
    implements Insertable<LocalCompanySetting> {
  final String companyId;
  final String key;
  final String valueText;
  const LocalCompanySetting({
    required this.companyId,
    required this.key,
    required this.valueText,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['company_id'] = Variable<String>(companyId);
    map['key'] = Variable<String>(key);
    map['value_text'] = Variable<String>(valueText);
    return map;
  }

  LocalCompanySettingsCompanion toCompanion(bool nullToAbsent) {
    return LocalCompanySettingsCompanion(
      companyId: Value(companyId),
      key: Value(key),
      valueText: Value(valueText),
    );
  }

  factory LocalCompanySetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalCompanySetting(
      companyId: serializer.fromJson<String>(json['companyId']),
      key: serializer.fromJson<String>(json['key']),
      valueText: serializer.fromJson<String>(json['valueText']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'companyId': serializer.toJson<String>(companyId),
      'key': serializer.toJson<String>(key),
      'valueText': serializer.toJson<String>(valueText),
    };
  }

  LocalCompanySetting copyWith({
    String? companyId,
    String? key,
    String? valueText,
  }) => LocalCompanySetting(
    companyId: companyId ?? this.companyId,
    key: key ?? this.key,
    valueText: valueText ?? this.valueText,
  );
  LocalCompanySetting copyWithCompanion(LocalCompanySettingsCompanion data) {
    return LocalCompanySetting(
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      key: data.key.present ? data.key.value : this.key,
      valueText: data.valueText.present ? data.valueText.value : this.valueText,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalCompanySetting(')
          ..write('companyId: $companyId, ')
          ..write('key: $key, ')
          ..write('valueText: $valueText')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(companyId, key, valueText);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalCompanySetting &&
          other.companyId == this.companyId &&
          other.key == this.key &&
          other.valueText == this.valueText);
}

class LocalCompanySettingsCompanion
    extends UpdateCompanion<LocalCompanySetting> {
  final Value<String> companyId;
  final Value<String> key;
  final Value<String> valueText;
  final Value<int> rowid;
  const LocalCompanySettingsCompanion({
    this.companyId = const Value.absent(),
    this.key = const Value.absent(),
    this.valueText = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalCompanySettingsCompanion.insert({
    required String companyId,
    required String key,
    required String valueText,
    this.rowid = const Value.absent(),
  }) : companyId = Value(companyId),
       key = Value(key),
       valueText = Value(valueText);
  static Insertable<LocalCompanySetting> custom({
    Expression<String>? companyId,
    Expression<String>? key,
    Expression<String>? valueText,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (companyId != null) 'company_id': companyId,
      if (key != null) 'key': key,
      if (valueText != null) 'value_text': valueText,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalCompanySettingsCompanion copyWith({
    Value<String>? companyId,
    Value<String>? key,
    Value<String>? valueText,
    Value<int>? rowid,
  }) {
    return LocalCompanySettingsCompanion(
      companyId: companyId ?? this.companyId,
      key: key ?? this.key,
      valueText: valueText ?? this.valueText,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (valueText.present) {
      map['value_text'] = Variable<String>(valueText.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalCompanySettingsCompanion(')
          ..write('companyId: $companyId, ')
          ..write('key: $key, ')
          ..write('valueText: $valueText, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalStockMinOverridesTable extends LocalStockMinOverrides
    with TableInfo<$LocalStockMinOverridesTable, LocalStockMinOverride> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalStockMinOverridesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _storeIdMeta = const VerificationMeta(
    'storeId',
  );
  @override
  late final GeneratedColumn<String> storeId = GeneratedColumn<String>(
    'store_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stockMinOverrideMeta = const VerificationMeta(
    'stockMinOverride',
  );
  @override
  late final GeneratedColumn<int> stockMinOverride = GeneratedColumn<int>(
    'stock_min_override',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [storeId, productId, stockMinOverride];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_stock_min_overrides';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalStockMinOverride> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('store_id')) {
      context.handle(
        _storeIdMeta,
        storeId.isAcceptableOrUnknown(data['store_id']!, _storeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storeIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('stock_min_override')) {
      context.handle(
        _stockMinOverrideMeta,
        stockMinOverride.isAcceptableOrUnknown(
          data['stock_min_override']!,
          _stockMinOverrideMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {storeId, productId};
  @override
  LocalStockMinOverride map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalStockMinOverride(
      storeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      stockMinOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stock_min_override'],
      ),
    );
  }

  @override
  $LocalStockMinOverridesTable createAlias(String alias) {
    return $LocalStockMinOverridesTable(attachedDatabase, alias);
  }
}

class LocalStockMinOverride extends DataClass
    implements Insertable<LocalStockMinOverride> {
  final String storeId;
  final String productId;
  final int? stockMinOverride;
  const LocalStockMinOverride({
    required this.storeId,
    required this.productId,
    this.stockMinOverride,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['store_id'] = Variable<String>(storeId);
    map['product_id'] = Variable<String>(productId);
    if (!nullToAbsent || stockMinOverride != null) {
      map['stock_min_override'] = Variable<int>(stockMinOverride);
    }
    return map;
  }

  LocalStockMinOverridesCompanion toCompanion(bool nullToAbsent) {
    return LocalStockMinOverridesCompanion(
      storeId: Value(storeId),
      productId: Value(productId),
      stockMinOverride: stockMinOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(stockMinOverride),
    );
  }

  factory LocalStockMinOverride.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalStockMinOverride(
      storeId: serializer.fromJson<String>(json['storeId']),
      productId: serializer.fromJson<String>(json['productId']),
      stockMinOverride: serializer.fromJson<int?>(json['stockMinOverride']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'storeId': serializer.toJson<String>(storeId),
      'productId': serializer.toJson<String>(productId),
      'stockMinOverride': serializer.toJson<int?>(stockMinOverride),
    };
  }

  LocalStockMinOverride copyWith({
    String? storeId,
    String? productId,
    Value<int?> stockMinOverride = const Value.absent(),
  }) => LocalStockMinOverride(
    storeId: storeId ?? this.storeId,
    productId: productId ?? this.productId,
    stockMinOverride: stockMinOverride.present
        ? stockMinOverride.value
        : this.stockMinOverride,
  );
  LocalStockMinOverride copyWithCompanion(
    LocalStockMinOverridesCompanion data,
  ) {
    return LocalStockMinOverride(
      storeId: data.storeId.present ? data.storeId.value : this.storeId,
      productId: data.productId.present ? data.productId.value : this.productId,
      stockMinOverride: data.stockMinOverride.present
          ? data.stockMinOverride.value
          : this.stockMinOverride,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalStockMinOverride(')
          ..write('storeId: $storeId, ')
          ..write('productId: $productId, ')
          ..write('stockMinOverride: $stockMinOverride')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(storeId, productId, stockMinOverride);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalStockMinOverride &&
          other.storeId == this.storeId &&
          other.productId == this.productId &&
          other.stockMinOverride == this.stockMinOverride);
}

class LocalStockMinOverridesCompanion
    extends UpdateCompanion<LocalStockMinOverride> {
  final Value<String> storeId;
  final Value<String> productId;
  final Value<int?> stockMinOverride;
  final Value<int> rowid;
  const LocalStockMinOverridesCompanion({
    this.storeId = const Value.absent(),
    this.productId = const Value.absent(),
    this.stockMinOverride = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalStockMinOverridesCompanion.insert({
    required String storeId,
    required String productId,
    this.stockMinOverride = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : storeId = Value(storeId),
       productId = Value(productId);
  static Insertable<LocalStockMinOverride> custom({
    Expression<String>? storeId,
    Expression<String>? productId,
    Expression<int>? stockMinOverride,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (storeId != null) 'store_id': storeId,
      if (productId != null) 'product_id': productId,
      if (stockMinOverride != null) 'stock_min_override': stockMinOverride,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalStockMinOverridesCompanion copyWith({
    Value<String>? storeId,
    Value<String>? productId,
    Value<int?>? stockMinOverride,
    Value<int>? rowid,
  }) {
    return LocalStockMinOverridesCompanion(
      storeId: storeId ?? this.storeId,
      productId: productId ?? this.productId,
      stockMinOverride: stockMinOverride ?? this.stockMinOverride,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (storeId.present) {
      map['store_id'] = Variable<String>(storeId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (stockMinOverride.present) {
      map['stock_min_override'] = Variable<int>(stockMinOverride.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalStockMinOverridesCompanion(')
          ..write('storeId: $storeId, ')
          ..write('productId: $productId, ')
          ..write('stockMinOverride: $stockMinOverride, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalCompanyMembersTable extends LocalCompanyMembers
    with TableInfo<$LocalCompanyMembersTable, LocalCompanyMember> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalCompanyMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleIdMeta = const VerificationMeta('roleId');
  @override
  late final GeneratedColumn<String> roleId = GeneratedColumn<String>(
    'role_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleNameMeta = const VerificationMeta(
    'roleName',
  );
  @override
  late final GeneratedColumn<String> roleName = GeneratedColumn<String>(
    'role_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleSlugMeta = const VerificationMeta(
    'roleSlug',
  );
  @override
  late final GeneratedColumn<String> roleSlug = GeneratedColumn<String>(
    'role_slug',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileFullNameMeta = const VerificationMeta(
    'profileFullName',
  );
  @override
  late final GeneratedColumn<String> profileFullName = GeneratedColumn<String>(
    'profile_full_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    companyId,
    userId,
    roleId,
    isActive,
    createdAt,
    roleName,
    roleSlug,
    profileFullName,
    email,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_company_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalCompanyMember> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('role_id')) {
      context.handle(
        _roleIdMeta,
        roleId.isAcceptableOrUnknown(data['role_id']!, _roleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_roleIdMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('role_name')) {
      context.handle(
        _roleNameMeta,
        roleName.isAcceptableOrUnknown(data['role_name']!, _roleNameMeta),
      );
    } else if (isInserting) {
      context.missing(_roleNameMeta);
    }
    if (data.containsKey('role_slug')) {
      context.handle(
        _roleSlugMeta,
        roleSlug.isAcceptableOrUnknown(data['role_slug']!, _roleSlugMeta),
      );
    } else if (isInserting) {
      context.missing(_roleSlugMeta);
    }
    if (data.containsKey('profile_full_name')) {
      context.handle(
        _profileFullNameMeta,
        profileFullName.isAcceptableOrUnknown(
          data['profile_full_name']!,
          _profileFullNameMeta,
        ),
      );
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalCompanyMember map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalCompanyMember(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      roleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role_id'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      roleName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role_name'],
      )!,
      roleSlug: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role_slug'],
      )!,
      profileFullName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_full_name'],
      ),
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
    );
  }

  @override
  $LocalCompanyMembersTable createAlias(String alias) {
    return $LocalCompanyMembersTable(attachedDatabase, alias);
  }
}

class LocalCompanyMember extends DataClass
    implements Insertable<LocalCompanyMember> {
  final String id;
  final String companyId;
  final String userId;
  final String roleId;
  final bool isActive;
  final String createdAt;
  final String roleName;
  final String roleSlug;
  final String? profileFullName;
  final String? email;
  const LocalCompanyMember({
    required this.id,
    required this.companyId,
    required this.userId,
    required this.roleId,
    required this.isActive,
    required this.createdAt,
    required this.roleName,
    required this.roleSlug,
    this.profileFullName,
    this.email,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_id'] = Variable<String>(companyId);
    map['user_id'] = Variable<String>(userId);
    map['role_id'] = Variable<String>(roleId);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<String>(createdAt);
    map['role_name'] = Variable<String>(roleName);
    map['role_slug'] = Variable<String>(roleSlug);
    if (!nullToAbsent || profileFullName != null) {
      map['profile_full_name'] = Variable<String>(profileFullName);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    return map;
  }

  LocalCompanyMembersCompanion toCompanion(bool nullToAbsent) {
    return LocalCompanyMembersCompanion(
      id: Value(id),
      companyId: Value(companyId),
      userId: Value(userId),
      roleId: Value(roleId),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      roleName: Value(roleName),
      roleSlug: Value(roleSlug),
      profileFullName: profileFullName == null && nullToAbsent
          ? const Value.absent()
          : Value(profileFullName),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
    );
  }

  factory LocalCompanyMember.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalCompanyMember(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String>(json['companyId']),
      userId: serializer.fromJson<String>(json['userId']),
      roleId: serializer.fromJson<String>(json['roleId']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      roleName: serializer.fromJson<String>(json['roleName']),
      roleSlug: serializer.fromJson<String>(json['roleSlug']),
      profileFullName: serializer.fromJson<String?>(json['profileFullName']),
      email: serializer.fromJson<String?>(json['email']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String>(companyId),
      'userId': serializer.toJson<String>(userId),
      'roleId': serializer.toJson<String>(roleId),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<String>(createdAt),
      'roleName': serializer.toJson<String>(roleName),
      'roleSlug': serializer.toJson<String>(roleSlug),
      'profileFullName': serializer.toJson<String?>(profileFullName),
      'email': serializer.toJson<String?>(email),
    };
  }

  LocalCompanyMember copyWith({
    String? id,
    String? companyId,
    String? userId,
    String? roleId,
    bool? isActive,
    String? createdAt,
    String? roleName,
    String? roleSlug,
    Value<String?> profileFullName = const Value.absent(),
    Value<String?> email = const Value.absent(),
  }) => LocalCompanyMember(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    userId: userId ?? this.userId,
    roleId: roleId ?? this.roleId,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    roleName: roleName ?? this.roleName,
    roleSlug: roleSlug ?? this.roleSlug,
    profileFullName: profileFullName.present
        ? profileFullName.value
        : this.profileFullName,
    email: email.present ? email.value : this.email,
  );
  LocalCompanyMember copyWithCompanion(LocalCompanyMembersCompanion data) {
    return LocalCompanyMember(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      userId: data.userId.present ? data.userId.value : this.userId,
      roleId: data.roleId.present ? data.roleId.value : this.roleId,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      roleName: data.roleName.present ? data.roleName.value : this.roleName,
      roleSlug: data.roleSlug.present ? data.roleSlug.value : this.roleSlug,
      profileFullName: data.profileFullName.present
          ? data.profileFullName.value
          : this.profileFullName,
      email: data.email.present ? data.email.value : this.email,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalCompanyMember(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('userId: $userId, ')
          ..write('roleId: $roleId, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('roleName: $roleName, ')
          ..write('roleSlug: $roleSlug, ')
          ..write('profileFullName: $profileFullName, ')
          ..write('email: $email')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    companyId,
    userId,
    roleId,
    isActive,
    createdAt,
    roleName,
    roleSlug,
    profileFullName,
    email,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalCompanyMember &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.userId == this.userId &&
          other.roleId == this.roleId &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.roleName == this.roleName &&
          other.roleSlug == this.roleSlug &&
          other.profileFullName == this.profileFullName &&
          other.email == this.email);
}

class LocalCompanyMembersCompanion extends UpdateCompanion<LocalCompanyMember> {
  final Value<String> id;
  final Value<String> companyId;
  final Value<String> userId;
  final Value<String> roleId;
  final Value<bool> isActive;
  final Value<String> createdAt;
  final Value<String> roleName;
  final Value<String> roleSlug;
  final Value<String?> profileFullName;
  final Value<String?> email;
  final Value<int> rowid;
  const LocalCompanyMembersCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.userId = const Value.absent(),
    this.roleId = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.roleName = const Value.absent(),
    this.roleSlug = const Value.absent(),
    this.profileFullName = const Value.absent(),
    this.email = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalCompanyMembersCompanion.insert({
    required String id,
    required String companyId,
    required String userId,
    required String roleId,
    this.isActive = const Value.absent(),
    required String createdAt,
    required String roleName,
    required String roleSlug,
    this.profileFullName = const Value.absent(),
    this.email = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       companyId = Value(companyId),
       userId = Value(userId),
       roleId = Value(roleId),
       createdAt = Value(createdAt),
       roleName = Value(roleName),
       roleSlug = Value(roleSlug);
  static Insertable<LocalCompanyMember> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? userId,
    Expression<String>? roleId,
    Expression<bool>? isActive,
    Expression<String>? createdAt,
    Expression<String>? roleName,
    Expression<String>? roleSlug,
    Expression<String>? profileFullName,
    Expression<String>? email,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (userId != null) 'user_id': userId,
      if (roleId != null) 'role_id': roleId,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (roleName != null) 'role_name': roleName,
      if (roleSlug != null) 'role_slug': roleSlug,
      if (profileFullName != null) 'profile_full_name': profileFullName,
      if (email != null) 'email': email,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalCompanyMembersCompanion copyWith({
    Value<String>? id,
    Value<String>? companyId,
    Value<String>? userId,
    Value<String>? roleId,
    Value<bool>? isActive,
    Value<String>? createdAt,
    Value<String>? roleName,
    Value<String>? roleSlug,
    Value<String?>? profileFullName,
    Value<String?>? email,
    Value<int>? rowid,
  }) {
    return LocalCompanyMembersCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      userId: userId ?? this.userId,
      roleId: roleId ?? this.roleId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      roleName: roleName ?? this.roleName,
      roleSlug: roleSlug ?? this.roleSlug,
      profileFullName: profileFullName ?? this.profileFullName,
      email: email ?? this.email,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (roleId.present) {
      map['role_id'] = Variable<String>(roleId.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (roleName.present) {
      map['role_name'] = Variable<String>(roleName.value);
    }
    if (roleSlug.present) {
      map['role_slug'] = Variable<String>(roleSlug.value);
    }
    if (profileFullName.present) {
      map['profile_full_name'] = Variable<String>(profileFullName.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalCompanyMembersCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('userId: $userId, ')
          ..write('roleId: $roleId, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('roleName: $roleName, ')
          ..write('roleSlug: $roleSlug, ')
          ..write('profileFullName: $profileFullName, ')
          ..write('email: $email, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingActionsTable extends PendingActions
    with TableInfo<$PendingActionsTable, PendingAction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingActionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    payload,
    createdAt,
    updatedAt,
    synced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_actions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingAction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingAction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingAction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
    );
  }

  @override
  $PendingActionsTable createAlias(String alias) {
    return $PendingActionsTable(attachedDatabase, alias);
  }
}

class PendingAction extends DataClass implements Insertable<PendingAction> {
  final int id;
  final String kind;
  final String payload;
  final int createdAt;
  final int updatedAt;
  final bool synced;
  const PendingAction({
    required this.id,
    required this.kind,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
    required this.synced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['kind'] = Variable<String>(kind);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  PendingActionsCompanion toCompanion(bool nullToAbsent) {
    return PendingActionsCompanion(
      id: Value(id),
      kind: Value(kind),
      payload: Value(payload),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      synced: Value(synced),
    );
  }

  factory PendingAction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingAction(
      id: serializer.fromJson<int>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<String>(kind),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  PendingAction copyWith({
    int? id,
    String? kind,
    String? payload,
    int? createdAt,
    int? updatedAt,
    bool? synced,
  }) => PendingAction(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    synced: synced ?? this.synced,
  );
  PendingAction copyWithCompanion(PendingActionsCompanion data) {
    return PendingAction(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingAction(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, kind, payload, createdAt, updatedAt, synced);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingAction &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.synced == this.synced);
}

class PendingActionsCompanion extends UpdateCompanion<PendingAction> {
  final Value<int> id;
  final Value<String> kind;
  final Value<String> payload;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<bool> synced;
  const PendingActionsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.synced = const Value.absent(),
  });
  PendingActionsCompanion.insert({
    this.id = const Value.absent(),
    required String kind,
    required String payload,
    required int createdAt,
    required int updatedAt,
    this.synced = const Value.absent(),
  }) : kind = Value(kind),
       payload = Value(payload),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<PendingAction> custom({
    Expression<int>? id,
    Expression<String>? kind,
    Expression<String>? payload,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<bool>? synced,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (synced != null) 'synced': synced,
    });
  }

  PendingActionsCompanion copyWith({
    Value<int>? id,
    Value<String>? kind,
    Value<String>? payload,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<bool>? synced,
  }) {
    return PendingActionsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingActionsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalProductsTable localProducts = $LocalProductsTable(this);
  late final $StoreInventoryTable storeInventory = $StoreInventoryTable(this);
  late final $LocalSalesTable localSales = $LocalSalesTable(this);
  late final $LocalSaleItemsTable localSaleItems = $LocalSaleItemsTable(this);
  late final $LocalCustomersTable localCustomers = $LocalCustomersTable(this);
  late final $LocalSuppliersTable localSuppliers = $LocalSuppliersTable(this);
  late final $LocalStoresTable localStores = $LocalStoresTable(this);
  late final $LocalCategoriesTable localCategories = $LocalCategoriesTable(
    this,
  );
  late final $LocalBrandsTable localBrands = $LocalBrandsTable(this);
  late final $LocalPurchasesTable localPurchases = $LocalPurchasesTable(this);
  late final $LocalPurchaseItemsTable localPurchaseItems =
      $LocalPurchaseItemsTable(this);
  late final $LocalTransfersTable localTransfers = $LocalTransfersTable(this);
  late final $LocalTransferItemsTable localTransferItems =
      $LocalTransferItemsTable(this);
  late final $LocalWarehouseInventoryTable localWarehouseInventory =
      $LocalWarehouseInventoryTable(this);
  late final $LocalWarehouseMovementsTable localWarehouseMovements =
      $LocalWarehouseMovementsTable(this);
  late final $LocalWarehouseDispatchInvoicesTable
  localWarehouseDispatchInvoices = $LocalWarehouseDispatchInvoicesTable(this);
  late final $LocalStockMovementsTable localStockMovements =
      $LocalStockMovementsTable(this);
  late final $LocalCompanySettingsTable localCompanySettings =
      $LocalCompanySettingsTable(this);
  late final $LocalStockMinOverridesTable localStockMinOverrides =
      $LocalStockMinOverridesTable(this);
  late final $LocalCompanyMembersTable localCompanyMembers =
      $LocalCompanyMembersTable(this);
  late final $PendingActionsTable pendingActions = $PendingActionsTable(this);
  late final Index idxLocalProductsCompanyId = Index(
    'idx_local_products_company_id',
    'CREATE INDEX idx_local_products_company_id ON local_products (company_id)',
  );
  late final Index idxStoreInventoryStoreId = Index(
    'idx_store_inventory_store_id',
    'CREATE INDEX idx_store_inventory_store_id ON store_inventory (store_id)',
  );
  late final Index idxLocalStoresCompanyId = Index(
    'idx_local_stores_company_id',
    'CREATE INDEX idx_local_stores_company_id ON local_stores (company_id)',
  );
  late final Index idxLocalCategoriesCompanyId = Index(
    'idx_local_categories_company_id',
    'CREATE INDEX idx_local_categories_company_id ON local_categories (company_id)',
  );
  late final Index idxLocalBrandsCompanyId = Index(
    'idx_local_brands_company_id',
    'CREATE INDEX idx_local_brands_company_id ON local_brands (company_id)',
  );
  late final Index idxLocalPurchasesCompanyId = Index(
    'idx_local_purchases_company_id',
    'CREATE INDEX idx_local_purchases_company_id ON local_purchases (company_id)',
  );
  late final Index idxLocalTransfersCompanyId = Index(
    'idx_local_transfers_company_id',
    'CREATE INDEX idx_local_transfers_company_id ON local_transfers (company_id)',
  );
  late final Index idxLocalWhInvCompany = Index(
    'idx_local_wh_inv_company',
    'CREATE INDEX idx_local_wh_inv_company ON local_warehouse_inventory (company_id)',
  );
  late final Index idxLocalWhMovCompany = Index(
    'idx_local_wh_mov_company',
    'CREATE INDEX idx_local_wh_mov_company ON local_warehouse_movements (company_id)',
  );
  late final Index idxLocalWhDispatchCompany = Index(
    'idx_local_wh_dispatch_company',
    'CREATE INDEX idx_local_wh_dispatch_company ON local_warehouse_dispatch_invoices (company_id)',
  );
  late final Index idxLocalStockMovementsStoreId = Index(
    'idx_local_stock_movements_store_id',
    'CREATE INDEX idx_local_stock_movements_store_id ON local_stock_movements (store_id)',
  );
  late final Index idxLocalCompanyMembersCompanyId = Index(
    'idx_local_company_members_company_id',
    'CREATE INDEX idx_local_company_members_company_id ON local_company_members (company_id)',
  );
  late final Index idxPendingActionsSynced = Index(
    'idx_pending_actions_synced',
    'CREATE INDEX idx_pending_actions_synced ON pending_actions (synced)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localProducts,
    storeInventory,
    localSales,
    localSaleItems,
    localCustomers,
    localSuppliers,
    localStores,
    localCategories,
    localBrands,
    localPurchases,
    localPurchaseItems,
    localTransfers,
    localTransferItems,
    localWarehouseInventory,
    localWarehouseMovements,
    localWarehouseDispatchInvoices,
    localStockMovements,
    localCompanySettings,
    localStockMinOverrides,
    localCompanyMembers,
    pendingActions,
    idxLocalProductsCompanyId,
    idxStoreInventoryStoreId,
    idxLocalStoresCompanyId,
    idxLocalCategoriesCompanyId,
    idxLocalBrandsCompanyId,
    idxLocalPurchasesCompanyId,
    idxLocalTransfersCompanyId,
    idxLocalWhInvCompany,
    idxLocalWhMovCompany,
    idxLocalWhDispatchCompany,
    idxLocalStockMovementsStoreId,
    idxLocalCompanyMembersCompanyId,
    idxPendingActionsSynced,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'local_sales',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('local_sale_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'local_purchases',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('local_purchase_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'local_transfers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('local_transfer_items', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$LocalProductsTableCreateCompanionBuilder =
    LocalProductsCompanion Function({
      required String id,
      required String companyId,
      required String name,
      Value<String?> sku,
      Value<String?> barcode,
      Value<String> unit,
      Value<double> purchasePrice,
      Value<double> salePrice,
      Value<double?> minPrice,
      Value<int> stockMin,
      Value<String?> description,
      Value<bool> isActive,
      Value<String?> categoryId,
      Value<String?> brandId,
      Value<String?> imageUrl,
      Value<String> productScope,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$LocalProductsTableUpdateCompanionBuilder =
    LocalProductsCompanion Function({
      Value<String> id,
      Value<String> companyId,
      Value<String> name,
      Value<String?> sku,
      Value<String?> barcode,
      Value<String> unit,
      Value<double> purchasePrice,
      Value<double> salePrice,
      Value<double?> minPrice,
      Value<int> stockMin,
      Value<String?> description,
      Value<bool> isActive,
      Value<String?> categoryId,
      Value<String?> brandId,
      Value<String?> imageUrl,
      Value<String> productScope,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$LocalProductsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalProductsTable> {
  $$LocalProductsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sku => $composableBuilder(
    column: $table.sku,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get purchasePrice => $composableBuilder(
    column: $table.purchasePrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get salePrice => $composableBuilder(
    column: $table.salePrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get minPrice => $composableBuilder(
    column: $table.minPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stockMin => $composableBuilder(
    column: $table.stockMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get brandId => $composableBuilder(
    column: $table.brandId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productScope => $composableBuilder(
    column: $table.productScope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalProductsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalProductsTable> {
  $$LocalProductsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sku => $composableBuilder(
    column: $table.sku,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get purchasePrice => $composableBuilder(
    column: $table.purchasePrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get salePrice => $composableBuilder(
    column: $table.salePrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get minPrice => $composableBuilder(
    column: $table.minPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stockMin => $composableBuilder(
    column: $table.stockMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get brandId => $composableBuilder(
    column: $table.brandId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productScope => $composableBuilder(
    column: $table.productScope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalProductsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalProductsTable> {
  $$LocalProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get sku =>
      $composableBuilder(column: $table.sku, builder: (column) => column);

  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<double> get purchasePrice => $composableBuilder(
    column: $table.purchasePrice,
    builder: (column) => column,
  );

  GeneratedColumn<double> get salePrice =>
      $composableBuilder(column: $table.salePrice, builder: (column) => column);

  GeneratedColumn<double> get minPrice =>
      $composableBuilder(column: $table.minPrice, builder: (column) => column);

  GeneratedColumn<int> get stockMin =>
      $composableBuilder(column: $table.stockMin, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get brandId =>
      $composableBuilder(column: $table.brandId, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get productScope => $composableBuilder(
    column: $table.productScope,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalProductsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalProductsTable,
          LocalProduct,
          $$LocalProductsTableFilterComposer,
          $$LocalProductsTableOrderingComposer,
          $$LocalProductsTableAnnotationComposer,
          $$LocalProductsTableCreateCompanionBuilder,
          $$LocalProductsTableUpdateCompanionBuilder,
          (
            LocalProduct,
            BaseReferences<_$AppDatabase, $LocalProductsTable, LocalProduct>,
          ),
          LocalProduct,
          PrefetchHooks Function()
        > {
  $$LocalProductsTableTableManager(_$AppDatabase db, $LocalProductsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> sku = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<double> purchasePrice = const Value.absent(),
                Value<double> salePrice = const Value.absent(),
                Value<double?> minPrice = const Value.absent(),
                Value<int> stockMin = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> brandId = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String> productScope = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalProductsCompanion(
                id: id,
                companyId: companyId,
                name: name,
                sku: sku,
                barcode: barcode,
                unit: unit,
                purchasePrice: purchasePrice,
                salePrice: salePrice,
                minPrice: minPrice,
                stockMin: stockMin,
                description: description,
                isActive: isActive,
                categoryId: categoryId,
                brandId: brandId,
                imageUrl: imageUrl,
                productScope: productScope,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String companyId,
                required String name,
                Value<String?> sku = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<double> purchasePrice = const Value.absent(),
                Value<double> salePrice = const Value.absent(),
                Value<double?> minPrice = const Value.absent(),
                Value<int> stockMin = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> brandId = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String> productScope = const Value.absent(),
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalProductsCompanion.insert(
                id: id,
                companyId: companyId,
                name: name,
                sku: sku,
                barcode: barcode,
                unit: unit,
                purchasePrice: purchasePrice,
                salePrice: salePrice,
                minPrice: minPrice,
                stockMin: stockMin,
                description: description,
                isActive: isActive,
                categoryId: categoryId,
                brandId: brandId,
                imageUrl: imageUrl,
                productScope: productScope,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalProductsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalProductsTable,
      LocalProduct,
      $$LocalProductsTableFilterComposer,
      $$LocalProductsTableOrderingComposer,
      $$LocalProductsTableAnnotationComposer,
      $$LocalProductsTableCreateCompanionBuilder,
      $$LocalProductsTableUpdateCompanionBuilder,
      (
        LocalProduct,
        BaseReferences<_$AppDatabase, $LocalProductsTable, LocalProduct>,
      ),
      LocalProduct,
      PrefetchHooks Function()
    >;
typedef $$StoreInventoryTableCreateCompanionBuilder =
    StoreInventoryCompanion Function({
      required String storeId,
      required String productId,
      Value<int> quantity,
      Value<int> reservedQuantity,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$StoreInventoryTableUpdateCompanionBuilder =
    StoreInventoryCompanion Function({
      Value<String> storeId,
      Value<String> productId,
      Value<int> quantity,
      Value<int> reservedQuantity,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$StoreInventoryTableFilterComposer
    extends Composer<_$AppDatabase, $StoreInventoryTable> {
  $$StoreInventoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reservedQuantity => $composableBuilder(
    column: $table.reservedQuantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoreInventoryTableOrderingComposer
    extends Composer<_$AppDatabase, $StoreInventoryTable> {
  $$StoreInventoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reservedQuantity => $composableBuilder(
    column: $table.reservedQuantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoreInventoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoreInventoryTable> {
  $$StoreInventoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get storeId =>
      $composableBuilder(column: $table.storeId, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<int> get reservedQuantity => $composableBuilder(
    column: $table.reservedQuantity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StoreInventoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoreInventoryTable,
          StoreInventoryData,
          $$StoreInventoryTableFilterComposer,
          $$StoreInventoryTableOrderingComposer,
          $$StoreInventoryTableAnnotationComposer,
          $$StoreInventoryTableCreateCompanionBuilder,
          $$StoreInventoryTableUpdateCompanionBuilder,
          (
            StoreInventoryData,
            BaseReferences<
              _$AppDatabase,
              $StoreInventoryTable,
              StoreInventoryData
            >,
          ),
          StoreInventoryData,
          PrefetchHooks Function()
        > {
  $$StoreInventoryTableTableManager(
    _$AppDatabase db,
    $StoreInventoryTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StoreInventoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StoreInventoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StoreInventoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> storeId = const Value.absent(),
                Value<String> productId = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<int> reservedQuantity = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoreInventoryCompanion(
                storeId: storeId,
                productId: productId,
                quantity: quantity,
                reservedQuantity: reservedQuantity,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String storeId,
                required String productId,
                Value<int> quantity = const Value.absent(),
                Value<int> reservedQuantity = const Value.absent(),
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => StoreInventoryCompanion.insert(
                storeId: storeId,
                productId: productId,
                quantity: quantity,
                reservedQuantity: reservedQuantity,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StoreInventoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoreInventoryTable,
      StoreInventoryData,
      $$StoreInventoryTableFilterComposer,
      $$StoreInventoryTableOrderingComposer,
      $$StoreInventoryTableAnnotationComposer,
      $$StoreInventoryTableCreateCompanionBuilder,
      $$StoreInventoryTableUpdateCompanionBuilder,
      (
        StoreInventoryData,
        BaseReferences<_$AppDatabase, $StoreInventoryTable, StoreInventoryData>,
      ),
      StoreInventoryData,
      PrefetchHooks Function()
    >;
typedef $$LocalSalesTableCreateCompanionBuilder =
    LocalSalesCompanion Function({
      required String id,
      required String companyId,
      required String storeId,
      Value<String?> customerId,
      required String saleNumber,
      required String status,
      Value<double> subtotal,
      Value<double> discount,
      Value<double> tax,
      required double total,
      required String createdBy,
      required String createdAt,
      required String updatedAt,
      Value<bool> synced,
      Value<String?> saleMode,
      Value<String?> documentType,
      Value<int> rowid,
    });
typedef $$LocalSalesTableUpdateCompanionBuilder =
    LocalSalesCompanion Function({
      Value<String> id,
      Value<String> companyId,
      Value<String> storeId,
      Value<String?> customerId,
      Value<String> saleNumber,
      Value<String> status,
      Value<double> subtotal,
      Value<double> discount,
      Value<double> tax,
      Value<double> total,
      Value<String> createdBy,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<bool> synced,
      Value<String?> saleMode,
      Value<String?> documentType,
      Value<int> rowid,
    });

final class $$LocalSalesTableReferences
    extends BaseReferences<_$AppDatabase, $LocalSalesTable, LocalSale> {
  $$LocalSalesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$LocalSaleItemsTable, List<LocalSaleItem>>
  _localSaleItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.localSaleItems,
    aliasName: $_aliasNameGenerator(db.localSales.id, db.localSaleItems.saleId),
  );

  $$LocalSaleItemsTableProcessedTableManager get localSaleItemsRefs {
    final manager = $$LocalSaleItemsTableTableManager(
      $_db,
      $_db.localSaleItems,
    ).filter((f) => f.saleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_localSaleItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LocalSalesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSalesTable> {
  $$LocalSalesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get saleNumber => $composableBuilder(
    column: $table.saleNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get subtotal => $composableBuilder(
    column: $table.subtotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get discount => $composableBuilder(
    column: $table.discount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get tax => $composableBuilder(
    column: $table.tax,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get saleMode => $composableBuilder(
    column: $table.saleMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentType => $composableBuilder(
    column: $table.documentType,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> localSaleItemsRefs(
    Expression<bool> Function($$LocalSaleItemsTableFilterComposer f) f,
  ) {
    final $$LocalSaleItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localSaleItems,
      getReferencedColumn: (t) => t.saleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalSaleItemsTableFilterComposer(
            $db: $db,
            $table: $db.localSaleItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalSalesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSalesTable> {
  $$LocalSalesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get saleNumber => $composableBuilder(
    column: $table.saleNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get subtotal => $composableBuilder(
    column: $table.subtotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get discount => $composableBuilder(
    column: $table.discount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get tax => $composableBuilder(
    column: $table.tax,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get saleMode => $composableBuilder(
    column: $table.saleMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentType => $composableBuilder(
    column: $table.documentType,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalSalesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSalesTable> {
  $$LocalSalesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get storeId =>
      $composableBuilder(column: $table.storeId, builder: (column) => column);

  GeneratedColumn<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get saleNumber => $composableBuilder(
    column: $table.saleNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<double> get subtotal =>
      $composableBuilder(column: $table.subtotal, builder: (column) => column);

  GeneratedColumn<double> get discount =>
      $composableBuilder(column: $table.discount, builder: (column) => column);

  GeneratedColumn<double> get tax =>
      $composableBuilder(column: $table.tax, builder: (column) => column);

  GeneratedColumn<double> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);

  GeneratedColumn<String> get saleMode =>
      $composableBuilder(column: $table.saleMode, builder: (column) => column);

  GeneratedColumn<String> get documentType => $composableBuilder(
    column: $table.documentType,
    builder: (column) => column,
  );

  Expression<T> localSaleItemsRefs<T extends Object>(
    Expression<T> Function($$LocalSaleItemsTableAnnotationComposer a) f,
  ) {
    final $$LocalSaleItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localSaleItems,
      getReferencedColumn: (t) => t.saleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalSaleItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.localSaleItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalSalesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalSalesTable,
          LocalSale,
          $$LocalSalesTableFilterComposer,
          $$LocalSalesTableOrderingComposer,
          $$LocalSalesTableAnnotationComposer,
          $$LocalSalesTableCreateCompanionBuilder,
          $$LocalSalesTableUpdateCompanionBuilder,
          (LocalSale, $$LocalSalesTableReferences),
          LocalSale,
          PrefetchHooks Function({bool localSaleItemsRefs})
        > {
  $$LocalSalesTableTableManager(_$AppDatabase db, $LocalSalesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSalesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSalesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSalesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<String> storeId = const Value.absent(),
                Value<String?> customerId = const Value.absent(),
                Value<String> saleNumber = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<double> subtotal = const Value.absent(),
                Value<double> discount = const Value.absent(),
                Value<double> tax = const Value.absent(),
                Value<double> total = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<String?> saleMode = const Value.absent(),
                Value<String?> documentType = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSalesCompanion(
                id: id,
                companyId: companyId,
                storeId: storeId,
                customerId: customerId,
                saleNumber: saleNumber,
                status: status,
                subtotal: subtotal,
                discount: discount,
                tax: tax,
                total: total,
                createdBy: createdBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                synced: synced,
                saleMode: saleMode,
                documentType: documentType,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String companyId,
                required String storeId,
                Value<String?> customerId = const Value.absent(),
                required String saleNumber,
                required String status,
                Value<double> subtotal = const Value.absent(),
                Value<double> discount = const Value.absent(),
                Value<double> tax = const Value.absent(),
                required double total,
                required String createdBy,
                required String createdAt,
                required String updatedAt,
                Value<bool> synced = const Value.absent(),
                Value<String?> saleMode = const Value.absent(),
                Value<String?> documentType = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSalesCompanion.insert(
                id: id,
                companyId: companyId,
                storeId: storeId,
                customerId: customerId,
                saleNumber: saleNumber,
                status: status,
                subtotal: subtotal,
                discount: discount,
                tax: tax,
                total: total,
                createdBy: createdBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                synced: synced,
                saleMode: saleMode,
                documentType: documentType,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LocalSalesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({localSaleItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (localSaleItemsRefs) db.localSaleItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (localSaleItemsRefs)
                    await $_getPrefetchedData<
                      LocalSale,
                      $LocalSalesTable,
                      LocalSaleItem
                    >(
                      currentTable: table,
                      referencedTable: $$LocalSalesTableReferences
                          ._localSaleItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LocalSalesTableReferences(
                            db,
                            table,
                            p0,
                          ).localSaleItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.saleId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LocalSalesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalSalesTable,
      LocalSale,
      $$LocalSalesTableFilterComposer,
      $$LocalSalesTableOrderingComposer,
      $$LocalSalesTableAnnotationComposer,
      $$LocalSalesTableCreateCompanionBuilder,
      $$LocalSalesTableUpdateCompanionBuilder,
      (LocalSale, $$LocalSalesTableReferences),
      LocalSale,
      PrefetchHooks Function({bool localSaleItemsRefs})
    >;
typedef $$LocalSaleItemsTableCreateCompanionBuilder =
    LocalSaleItemsCompanion Function({
      required String id,
      required String saleId,
      required String productId,
      required int quantity,
      required double unitPrice,
      required double total,
      required String createdAt,
      Value<int> rowid,
    });
typedef $$LocalSaleItemsTableUpdateCompanionBuilder =
    LocalSaleItemsCompanion Function({
      Value<String> id,
      Value<String> saleId,
      Value<String> productId,
      Value<int> quantity,
      Value<double> unitPrice,
      Value<double> total,
      Value<String> createdAt,
      Value<int> rowid,
    });

final class $$LocalSaleItemsTableReferences
    extends BaseReferences<_$AppDatabase, $LocalSaleItemsTable, LocalSaleItem> {
  $$LocalSaleItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LocalSalesTable _saleIdTable(_$AppDatabase db) =>
      db.localSales.createAlias(
        $_aliasNameGenerator(db.localSaleItems.saleId, db.localSales.id),
      );

  $$LocalSalesTableProcessedTableManager get saleId {
    final $_column = $_itemColumn<String>('sale_id')!;

    final manager = $$LocalSalesTableTableManager(
      $_db,
      $_db.localSales,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_saleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LocalSaleItemsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSaleItemsTable> {
  $$LocalSaleItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get unitPrice => $composableBuilder(
    column: $table.unitPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LocalSalesTableFilterComposer get saleId {
    final $$LocalSalesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.saleId,
      referencedTable: $db.localSales,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalSalesTableFilterComposer(
            $db: $db,
            $table: $db.localSales,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalSaleItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSaleItemsTable> {
  $$LocalSaleItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get unitPrice => $composableBuilder(
    column: $table.unitPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LocalSalesTableOrderingComposer get saleId {
    final $$LocalSalesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.saleId,
      referencedTable: $db.localSales,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalSalesTableOrderingComposer(
            $db: $db,
            $table: $db.localSales,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalSaleItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSaleItemsTable> {
  $$LocalSaleItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get unitPrice =>
      $composableBuilder(column: $table.unitPrice, builder: (column) => column);

  GeneratedColumn<double> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$LocalSalesTableAnnotationComposer get saleId {
    final $$LocalSalesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.saleId,
      referencedTable: $db.localSales,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalSalesTableAnnotationComposer(
            $db: $db,
            $table: $db.localSales,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalSaleItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalSaleItemsTable,
          LocalSaleItem,
          $$LocalSaleItemsTableFilterComposer,
          $$LocalSaleItemsTableOrderingComposer,
          $$LocalSaleItemsTableAnnotationComposer,
          $$LocalSaleItemsTableCreateCompanionBuilder,
          $$LocalSaleItemsTableUpdateCompanionBuilder,
          (LocalSaleItem, $$LocalSaleItemsTableReferences),
          LocalSaleItem,
          PrefetchHooks Function({bool saleId})
        > {
  $$LocalSaleItemsTableTableManager(
    _$AppDatabase db,
    $LocalSaleItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSaleItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSaleItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSaleItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> saleId = const Value.absent(),
                Value<String> productId = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<double> unitPrice = const Value.absent(),
                Value<double> total = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSaleItemsCompanion(
                id: id,
                saleId: saleId,
                productId: productId,
                quantity: quantity,
                unitPrice: unitPrice,
                total: total,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String saleId,
                required String productId,
                required int quantity,
                required double unitPrice,
                required double total,
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalSaleItemsCompanion.insert(
                id: id,
                saleId: saleId,
                productId: productId,
                quantity: quantity,
                unitPrice: unitPrice,
                total: total,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LocalSaleItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({saleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (saleId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.saleId,
                                referencedTable: $$LocalSaleItemsTableReferences
                                    ._saleIdTable(db),
                                referencedColumn:
                                    $$LocalSaleItemsTableReferences
                                        ._saleIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LocalSaleItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalSaleItemsTable,
      LocalSaleItem,
      $$LocalSaleItemsTableFilterComposer,
      $$LocalSaleItemsTableOrderingComposer,
      $$LocalSaleItemsTableAnnotationComposer,
      $$LocalSaleItemsTableCreateCompanionBuilder,
      $$LocalSaleItemsTableUpdateCompanionBuilder,
      (LocalSaleItem, $$LocalSaleItemsTableReferences),
      LocalSaleItem,
      PrefetchHooks Function({bool saleId})
    >;
typedef $$LocalCustomersTableCreateCompanionBuilder =
    LocalCustomersCompanion Function({
      required String id,
      required String companyId,
      required String name,
      Value<String> type,
      Value<String?> phone,
      Value<String?> email,
      Value<String?> address,
      Value<String?> notes,
      required String createdAt,
      required String updatedAt,
      Value<bool> synced,
      Value<int> rowid,
    });
typedef $$LocalCustomersTableUpdateCompanionBuilder =
    LocalCustomersCompanion Function({
      Value<String> id,
      Value<String> companyId,
      Value<String> name,
      Value<String> type,
      Value<String?> phone,
      Value<String?> email,
      Value<String?> address,
      Value<String?> notes,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<bool> synced,
      Value<int> rowid,
    });

class $$LocalCustomersTableFilterComposer
    extends Composer<_$AppDatabase, $LocalCustomersTable> {
  $$LocalCustomersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalCustomersTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalCustomersTable> {
  $$LocalCustomersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalCustomersTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalCustomersTable> {
  $$LocalCustomersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);
}

class $$LocalCustomersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalCustomersTable,
          LocalCustomer,
          $$LocalCustomersTableFilterComposer,
          $$LocalCustomersTableOrderingComposer,
          $$LocalCustomersTableAnnotationComposer,
          $$LocalCustomersTableCreateCompanionBuilder,
          $$LocalCustomersTableUpdateCompanionBuilder,
          (
            LocalCustomer,
            BaseReferences<_$AppDatabase, $LocalCustomersTable, LocalCustomer>,
          ),
          LocalCustomer,
          PrefetchHooks Function()
        > {
  $$LocalCustomersTableTableManager(
    _$AppDatabase db,
    $LocalCustomersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalCustomersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalCustomersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalCustomersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalCustomersCompanion(
                id: id,
                companyId: companyId,
                name: name,
                type: type,
                phone: phone,
                email: email,
                address: address,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                synced: synced,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String companyId,
                required String name,
                Value<String> type = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalCustomersCompanion.insert(
                id: id,
                companyId: companyId,
                name: name,
                type: type,
                phone: phone,
                email: email,
                address: address,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                synced: synced,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalCustomersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalCustomersTable,
      LocalCustomer,
      $$LocalCustomersTableFilterComposer,
      $$LocalCustomersTableOrderingComposer,
      $$LocalCustomersTableAnnotationComposer,
      $$LocalCustomersTableCreateCompanionBuilder,
      $$LocalCustomersTableUpdateCompanionBuilder,
      (
        LocalCustomer,
        BaseReferences<_$AppDatabase, $LocalCustomersTable, LocalCustomer>,
      ),
      LocalCustomer,
      PrefetchHooks Function()
    >;
typedef $$LocalSuppliersTableCreateCompanionBuilder =
    LocalSuppliersCompanion Function({
      required String id,
      required String companyId,
      required String name,
      Value<String?> contact,
      Value<String?> phone,
      Value<String?> email,
      Value<String?> address,
      Value<String?> notes,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$LocalSuppliersTableUpdateCompanionBuilder =
    LocalSuppliersCompanion Function({
      Value<String> id,
      Value<String> companyId,
      Value<String> name,
      Value<String?> contact,
      Value<String?> phone,
      Value<String?> email,
      Value<String?> address,
      Value<String?> notes,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$LocalSuppliersTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSuppliersTable> {
  $$LocalSuppliersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contact => $composableBuilder(
    column: $table.contact,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalSuppliersTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSuppliersTable> {
  $$LocalSuppliersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contact => $composableBuilder(
    column: $table.contact,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalSuppliersTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSuppliersTable> {
  $$LocalSuppliersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get contact =>
      $composableBuilder(column: $table.contact, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalSuppliersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalSuppliersTable,
          LocalSupplier,
          $$LocalSuppliersTableFilterComposer,
          $$LocalSuppliersTableOrderingComposer,
          $$LocalSuppliersTableAnnotationComposer,
          $$LocalSuppliersTableCreateCompanionBuilder,
          $$LocalSuppliersTableUpdateCompanionBuilder,
          (
            LocalSupplier,
            BaseReferences<_$AppDatabase, $LocalSuppliersTable, LocalSupplier>,
          ),
          LocalSupplier,
          PrefetchHooks Function()
        > {
  $$LocalSuppliersTableTableManager(
    _$AppDatabase db,
    $LocalSuppliersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSuppliersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSuppliersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSuppliersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> contact = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSuppliersCompanion(
                id: id,
                companyId: companyId,
                name: name,
                contact: contact,
                phone: phone,
                email: email,
                address: address,
                notes: notes,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String companyId,
                required String name,
                Value<String?> contact = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalSuppliersCompanion.insert(
                id: id,
                companyId: companyId,
                name: name,
                contact: contact,
                phone: phone,
                email: email,
                address: address,
                notes: notes,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalSuppliersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalSuppliersTable,
      LocalSupplier,
      $$LocalSuppliersTableFilterComposer,
      $$LocalSuppliersTableOrderingComposer,
      $$LocalSuppliersTableAnnotationComposer,
      $$LocalSuppliersTableCreateCompanionBuilder,
      $$LocalSuppliersTableUpdateCompanionBuilder,
      (
        LocalSupplier,
        BaseReferences<_$AppDatabase, $LocalSuppliersTable, LocalSupplier>,
      ),
      LocalSupplier,
      PrefetchHooks Function()
    >;
typedef $$LocalStoresTableCreateCompanionBuilder =
    LocalStoresCompanion Function({
      required String id,
      required String companyId,
      required String name,
      Value<String?> code,
      Value<String?> address,
      Value<String?> logoUrl,
      Value<String?> phone,
      Value<String?> email,
      Value<String?> description,
      Value<bool> isActive,
      Value<bool> isPrimary,
      Value<bool> posDiscountEnabled,
      required String updatedAt,
      Value<String?> currency,
      Value<String?> primaryColor,
      Value<String?> secondaryColor,
      Value<String?> invoicePrefix,
      Value<String?> footerText,
      Value<String?> legalInfo,
      Value<String?> signatureUrl,
      Value<String?> stampUrl,
      Value<String?> paymentTerms,
      Value<String?> taxLabel,
      Value<String?> taxNumber,
      Value<String?> city,
      Value<String?> country,
      Value<String?> commercialName,
      Value<String?> slogan,
      Value<String?> activity,
      Value<String?> mobileMoney,
      Value<String?> invoiceShortTitle,
      Value<String?> invoiceSignerTitle,
      Value<String?> invoiceSignerName,
      Value<String?> invoiceTemplate,
      Value<int> rowid,
    });
typedef $$LocalStoresTableUpdateCompanionBuilder =
    LocalStoresCompanion Function({
      Value<String> id,
      Value<String> companyId,
      Value<String> name,
      Value<String?> code,
      Value<String?> address,
      Value<String?> logoUrl,
      Value<String?> phone,
      Value<String?> email,
      Value<String?> description,
      Value<bool> isActive,
      Value<bool> isPrimary,
      Value<bool> posDiscountEnabled,
      Value<String> updatedAt,
      Value<String?> currency,
      Value<String?> primaryColor,
      Value<String?> secondaryColor,
      Value<String?> invoicePrefix,
      Value<String?> footerText,
      Value<String?> legalInfo,
      Value<String?> signatureUrl,
      Value<String?> stampUrl,
      Value<String?> paymentTerms,
      Value<String?> taxLabel,
      Value<String?> taxNumber,
      Value<String?> city,
      Value<String?> country,
      Value<String?> commercialName,
      Value<String?> slogan,
      Value<String?> activity,
      Value<String?> mobileMoney,
      Value<String?> invoiceShortTitle,
      Value<String?> invoiceSignerTitle,
      Value<String?> invoiceSignerName,
      Value<String?> invoiceTemplate,
      Value<int> rowid,
    });

class $$LocalStoresTableFilterComposer
    extends Composer<_$AppDatabase, $LocalStoresTable> {
  $$LocalStoresTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get logoUrl => $composableBuilder(
    column: $table.logoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPrimary => $composableBuilder(
    column: $table.isPrimary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get posDiscountEnabled => $composableBuilder(
    column: $table.posDiscountEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get primaryColor => $composableBuilder(
    column: $table.primaryColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get secondaryColor => $composableBuilder(
    column: $table.secondaryColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get invoicePrefix => $composableBuilder(
    column: $table.invoicePrefix,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get footerText => $composableBuilder(
    column: $table.footerText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get legalInfo => $composableBuilder(
    column: $table.legalInfo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signatureUrl => $composableBuilder(
    column: $table.signatureUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stampUrl => $composableBuilder(
    column: $table.stampUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentTerms => $composableBuilder(
    column: $table.paymentTerms,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taxLabel => $composableBuilder(
    column: $table.taxLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taxNumber => $composableBuilder(
    column: $table.taxNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get country => $composableBuilder(
    column: $table.country,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commercialName => $composableBuilder(
    column: $table.commercialName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get slogan => $composableBuilder(
    column: $table.slogan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activity => $composableBuilder(
    column: $table.activity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mobileMoney => $composableBuilder(
    column: $table.mobileMoney,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get invoiceShortTitle => $composableBuilder(
    column: $table.invoiceShortTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get invoiceSignerTitle => $composableBuilder(
    column: $table.invoiceSignerTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get invoiceSignerName => $composableBuilder(
    column: $table.invoiceSignerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get invoiceTemplate => $composableBuilder(
    column: $table.invoiceTemplate,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalStoresTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalStoresTable> {
  $$LocalStoresTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get logoUrl => $composableBuilder(
    column: $table.logoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPrimary => $composableBuilder(
    column: $table.isPrimary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get posDiscountEnabled => $composableBuilder(
    column: $table.posDiscountEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get primaryColor => $composableBuilder(
    column: $table.primaryColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get secondaryColor => $composableBuilder(
    column: $table.secondaryColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get invoicePrefix => $composableBuilder(
    column: $table.invoicePrefix,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get footerText => $composableBuilder(
    column: $table.footerText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get legalInfo => $composableBuilder(
    column: $table.legalInfo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signatureUrl => $composableBuilder(
    column: $table.signatureUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stampUrl => $composableBuilder(
    column: $table.stampUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentTerms => $composableBuilder(
    column: $table.paymentTerms,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taxLabel => $composableBuilder(
    column: $table.taxLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taxNumber => $composableBuilder(
    column: $table.taxNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get country => $composableBuilder(
    column: $table.country,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commercialName => $composableBuilder(
    column: $table.commercialName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get slogan => $composableBuilder(
    column: $table.slogan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activity => $composableBuilder(
    column: $table.activity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mobileMoney => $composableBuilder(
    column: $table.mobileMoney,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get invoiceShortTitle => $composableBuilder(
    column: $table.invoiceShortTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get invoiceSignerTitle => $composableBuilder(
    column: $table.invoiceSignerTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get invoiceSignerName => $composableBuilder(
    column: $table.invoiceSignerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get invoiceTemplate => $composableBuilder(
    column: $table.invoiceTemplate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalStoresTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalStoresTable> {
  $$LocalStoresTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get logoUrl =>
      $composableBuilder(column: $table.logoUrl, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<bool> get isPrimary =>
      $composableBuilder(column: $table.isPrimary, builder: (column) => column);

  GeneratedColumn<bool> get posDiscountEnabled => $composableBuilder(
    column: $table.posDiscountEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get primaryColor => $composableBuilder(
    column: $table.primaryColor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get secondaryColor => $composableBuilder(
    column: $table.secondaryColor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get invoicePrefix => $composableBuilder(
    column: $table.invoicePrefix,
    builder: (column) => column,
  );

  GeneratedColumn<String> get footerText => $composableBuilder(
    column: $table.footerText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get legalInfo =>
      $composableBuilder(column: $table.legalInfo, builder: (column) => column);

  GeneratedColumn<String> get signatureUrl => $composableBuilder(
    column: $table.signatureUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get stampUrl =>
      $composableBuilder(column: $table.stampUrl, builder: (column) => column);

  GeneratedColumn<String> get paymentTerms => $composableBuilder(
    column: $table.paymentTerms,
    builder: (column) => column,
  );

  GeneratedColumn<String> get taxLabel =>
      $composableBuilder(column: $table.taxLabel, builder: (column) => column);

  GeneratedColumn<String> get taxNumber =>
      $composableBuilder(column: $table.taxNumber, builder: (column) => column);

  GeneratedColumn<String> get city =>
      $composableBuilder(column: $table.city, builder: (column) => column);

  GeneratedColumn<String> get country =>
      $composableBuilder(column: $table.country, builder: (column) => column);

  GeneratedColumn<String> get commercialName => $composableBuilder(
    column: $table.commercialName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get slogan =>
      $composableBuilder(column: $table.slogan, builder: (column) => column);

  GeneratedColumn<String> get activity =>
      $composableBuilder(column: $table.activity, builder: (column) => column);

  GeneratedColumn<String> get mobileMoney => $composableBuilder(
    column: $table.mobileMoney,
    builder: (column) => column,
  );

  GeneratedColumn<String> get invoiceShortTitle => $composableBuilder(
    column: $table.invoiceShortTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get invoiceSignerTitle => $composableBuilder(
    column: $table.invoiceSignerTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get invoiceSignerName => $composableBuilder(
    column: $table.invoiceSignerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get invoiceTemplate => $composableBuilder(
    column: $table.invoiceTemplate,
    builder: (column) => column,
  );
}

class $$LocalStoresTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalStoresTable,
          LocalStore,
          $$LocalStoresTableFilterComposer,
          $$LocalStoresTableOrderingComposer,
          $$LocalStoresTableAnnotationComposer,
          $$LocalStoresTableCreateCompanionBuilder,
          $$LocalStoresTableUpdateCompanionBuilder,
          (
            LocalStore,
            BaseReferences<_$AppDatabase, $LocalStoresTable, LocalStore>,
          ),
          LocalStore,
          PrefetchHooks Function()
        > {
  $$LocalStoresTableTableManager(_$AppDatabase db, $LocalStoresTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalStoresTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalStoresTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalStoresTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> code = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> logoUrl = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<bool> isPrimary = const Value.absent(),
                Value<bool> posDiscountEnabled = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String?> currency = const Value.absent(),
                Value<String?> primaryColor = const Value.absent(),
                Value<String?> secondaryColor = const Value.absent(),
                Value<String?> invoicePrefix = const Value.absent(),
                Value<String?> footerText = const Value.absent(),
                Value<String?> legalInfo = const Value.absent(),
                Value<String?> signatureUrl = const Value.absent(),
                Value<String?> stampUrl = const Value.absent(),
                Value<String?> paymentTerms = const Value.absent(),
                Value<String?> taxLabel = const Value.absent(),
                Value<String?> taxNumber = const Value.absent(),
                Value<String?> city = const Value.absent(),
                Value<String?> country = const Value.absent(),
                Value<String?> commercialName = const Value.absent(),
                Value<String?> slogan = const Value.absent(),
                Value<String?> activity = const Value.absent(),
                Value<String?> mobileMoney = const Value.absent(),
                Value<String?> invoiceShortTitle = const Value.absent(),
                Value<String?> invoiceSignerTitle = const Value.absent(),
                Value<String?> invoiceSignerName = const Value.absent(),
                Value<String?> invoiceTemplate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalStoresCompanion(
                id: id,
                companyId: companyId,
                name: name,
                code: code,
                address: address,
                logoUrl: logoUrl,
                phone: phone,
                email: email,
                description: description,
                isActive: isActive,
                isPrimary: isPrimary,
                posDiscountEnabled: posDiscountEnabled,
                updatedAt: updatedAt,
                currency: currency,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                invoicePrefix: invoicePrefix,
                footerText: footerText,
                legalInfo: legalInfo,
                signatureUrl: signatureUrl,
                stampUrl: stampUrl,
                paymentTerms: paymentTerms,
                taxLabel: taxLabel,
                taxNumber: taxNumber,
                city: city,
                country: country,
                commercialName: commercialName,
                slogan: slogan,
                activity: activity,
                mobileMoney: mobileMoney,
                invoiceShortTitle: invoiceShortTitle,
                invoiceSignerTitle: invoiceSignerTitle,
                invoiceSignerName: invoiceSignerName,
                invoiceTemplate: invoiceTemplate,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String companyId,
                required String name,
                Value<String?> code = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> logoUrl = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<bool> isPrimary = const Value.absent(),
                Value<bool> posDiscountEnabled = const Value.absent(),
                required String updatedAt,
                Value<String?> currency = const Value.absent(),
                Value<String?> primaryColor = const Value.absent(),
                Value<String?> secondaryColor = const Value.absent(),
                Value<String?> invoicePrefix = const Value.absent(),
                Value<String?> footerText = const Value.absent(),
                Value<String?> legalInfo = const Value.absent(),
                Value<String?> signatureUrl = const Value.absent(),
                Value<String?> stampUrl = const Value.absent(),
                Value<String?> paymentTerms = const Value.absent(),
                Value<String?> taxLabel = const Value.absent(),
                Value<String?> taxNumber = const Value.absent(),
                Value<String?> city = const Value.absent(),
                Value<String?> country = const Value.absent(),
                Value<String?> commercialName = const Value.absent(),
                Value<String?> slogan = const Value.absent(),
                Value<String?> activity = const Value.absent(),
                Value<String?> mobileMoney = const Value.absent(),
                Value<String?> invoiceShortTitle = const Value.absent(),
                Value<String?> invoiceSignerTitle = const Value.absent(),
                Value<String?> invoiceSignerName = const Value.absent(),
                Value<String?> invoiceTemplate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalStoresCompanion.insert(
                id: id,
                companyId: companyId,
                name: name,
                code: code,
                address: address,
                logoUrl: logoUrl,
                phone: phone,
                email: email,
                description: description,
                isActive: isActive,
                isPrimary: isPrimary,
                posDiscountEnabled: posDiscountEnabled,
                updatedAt: updatedAt,
                currency: currency,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                invoicePrefix: invoicePrefix,
                footerText: footerText,
                legalInfo: legalInfo,
                signatureUrl: signatureUrl,
                stampUrl: stampUrl,
                paymentTerms: paymentTerms,
                taxLabel: taxLabel,
                taxNumber: taxNumber,
                city: city,
                country: country,
                commercialName: commercialName,
                slogan: slogan,
                activity: activity,
                mobileMoney: mobileMoney,
                invoiceShortTitle: invoiceShortTitle,
                invoiceSignerTitle: invoiceSignerTitle,
                invoiceSignerName: invoiceSignerName,
                invoiceTemplate: invoiceTemplate,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalStoresTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalStoresTable,
      LocalStore,
      $$LocalStoresTableFilterComposer,
      $$LocalStoresTableOrderingComposer,
      $$LocalStoresTableAnnotationComposer,
      $$LocalStoresTableCreateCompanionBuilder,
      $$LocalStoresTableUpdateCompanionBuilder,
      (
        LocalStore,
        BaseReferences<_$AppDatabase, $LocalStoresTable, LocalStore>,
      ),
      LocalStore,
      PrefetchHooks Function()
    >;
typedef $$LocalCategoriesTableCreateCompanionBuilder =
    LocalCategoriesCompanion Function({
      required String id,
      required String companyId,
      required String name,
      Value<String?> parentId,
      Value<int> rowid,
    });
typedef $$LocalCategoriesTableUpdateCompanionBuilder =
    LocalCategoriesCompanion Function({
      Value<String> id,
      Value<String> companyId,
      Value<String> name,
      Value<String?> parentId,
      Value<int> rowid,
    });

class $$LocalCategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalCategoriesTable> {
  $$LocalCategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalCategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalCategoriesTable> {
  $$LocalCategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalCategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalCategoriesTable> {
  $$LocalCategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);
}

class $$LocalCategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalCategoriesTable,
          LocalCategory,
          $$LocalCategoriesTableFilterComposer,
          $$LocalCategoriesTableOrderingComposer,
          $$LocalCategoriesTableAnnotationComposer,
          $$LocalCategoriesTableCreateCompanionBuilder,
          $$LocalCategoriesTableUpdateCompanionBuilder,
          (
            LocalCategory,
            BaseReferences<_$AppDatabase, $LocalCategoriesTable, LocalCategory>,
          ),
          LocalCategory,
          PrefetchHooks Function()
        > {
  $$LocalCategoriesTableTableManager(
    _$AppDatabase db,
    $LocalCategoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalCategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalCategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalCategoriesCompanion(
                id: id,
                companyId: companyId,
                name: name,
                parentId: parentId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String companyId,
                required String name,
                Value<String?> parentId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalCategoriesCompanion.insert(
                id: id,
                companyId: companyId,
                name: name,
                parentId: parentId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalCategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalCategoriesTable,
      LocalCategory,
      $$LocalCategoriesTableFilterComposer,
      $$LocalCategoriesTableOrderingComposer,
      $$LocalCategoriesTableAnnotationComposer,
      $$LocalCategoriesTableCreateCompanionBuilder,
      $$LocalCategoriesTableUpdateCompanionBuilder,
      (
        LocalCategory,
        BaseReferences<_$AppDatabase, $LocalCategoriesTable, LocalCategory>,
      ),
      LocalCategory,
      PrefetchHooks Function()
    >;
typedef $$LocalBrandsTableCreateCompanionBuilder =
    LocalBrandsCompanion Function({
      required String id,
      required String companyId,
      required String name,
      Value<int> rowid,
    });
typedef $$LocalBrandsTableUpdateCompanionBuilder =
    LocalBrandsCompanion Function({
      Value<String> id,
      Value<String> companyId,
      Value<String> name,
      Value<int> rowid,
    });

class $$LocalBrandsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalBrandsTable> {
  $$LocalBrandsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalBrandsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalBrandsTable> {
  $$LocalBrandsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalBrandsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalBrandsTable> {
  $$LocalBrandsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);
}

class $$LocalBrandsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalBrandsTable,
          LocalBrand,
          $$LocalBrandsTableFilterComposer,
          $$LocalBrandsTableOrderingComposer,
          $$LocalBrandsTableAnnotationComposer,
          $$LocalBrandsTableCreateCompanionBuilder,
          $$LocalBrandsTableUpdateCompanionBuilder,
          (
            LocalBrand,
            BaseReferences<_$AppDatabase, $LocalBrandsTable, LocalBrand>,
          ),
          LocalBrand,
          PrefetchHooks Function()
        > {
  $$LocalBrandsTableTableManager(_$AppDatabase db, $LocalBrandsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalBrandsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalBrandsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalBrandsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalBrandsCompanion(
                id: id,
                companyId: companyId,
                name: name,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String companyId,
                required String name,
                Value<int> rowid = const Value.absent(),
              }) => LocalBrandsCompanion.insert(
                id: id,
                companyId: companyId,
                name: name,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalBrandsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalBrandsTable,
      LocalBrand,
      $$LocalBrandsTableFilterComposer,
      $$LocalBrandsTableOrderingComposer,
      $$LocalBrandsTableAnnotationComposer,
      $$LocalBrandsTableCreateCompanionBuilder,
      $$LocalBrandsTableUpdateCompanionBuilder,
      (
        LocalBrand,
        BaseReferences<_$AppDatabase, $LocalBrandsTable, LocalBrand>,
      ),
      LocalBrand,
      PrefetchHooks Function()
    >;
typedef $$LocalPurchasesTableCreateCompanionBuilder =
    LocalPurchasesCompanion Function({
      required String id,
      required String companyId,
      required String storeId,
      required String supplierId,
      Value<String?> reference,
      required String status,
      required double total,
      required String createdBy,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$LocalPurchasesTableUpdateCompanionBuilder =
    LocalPurchasesCompanion Function({
      Value<String> id,
      Value<String> companyId,
      Value<String> storeId,
      Value<String> supplierId,
      Value<String?> reference,
      Value<String> status,
      Value<double> total,
      Value<String> createdBy,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

final class $$LocalPurchasesTableReferences
    extends BaseReferences<_$AppDatabase, $LocalPurchasesTable, LocalPurchase> {
  $$LocalPurchasesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$LocalPurchaseItemsTable, List<LocalPurchaseItem>>
  _localPurchaseItemsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.localPurchaseItems,
        aliasName: $_aliasNameGenerator(
          db.localPurchases.id,
          db.localPurchaseItems.purchaseId,
        ),
      );

  $$LocalPurchaseItemsTableProcessedTableManager get localPurchaseItemsRefs {
    final manager = $$LocalPurchaseItemsTableTableManager(
      $_db,
      $_db.localPurchaseItems,
    ).filter((f) => f.purchaseId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _localPurchaseItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LocalPurchasesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalPurchasesTable> {
  $$LocalPurchasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supplierId => $composableBuilder(
    column: $table.supplierId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reference => $composableBuilder(
    column: $table.reference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> localPurchaseItemsRefs(
    Expression<bool> Function($$LocalPurchaseItemsTableFilterComposer f) f,
  ) {
    final $$LocalPurchaseItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localPurchaseItems,
      getReferencedColumn: (t) => t.purchaseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalPurchaseItemsTableFilterComposer(
            $db: $db,
            $table: $db.localPurchaseItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalPurchasesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalPurchasesTable> {
  $$LocalPurchasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supplierId => $composableBuilder(
    column: $table.supplierId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reference => $composableBuilder(
    column: $table.reference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalPurchasesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalPurchasesTable> {
  $$LocalPurchasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get storeId =>
      $composableBuilder(column: $table.storeId, builder: (column) => column);

  GeneratedColumn<String> get supplierId => $composableBuilder(
    column: $table.supplierId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reference =>
      $composableBuilder(column: $table.reference, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<double> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> localPurchaseItemsRefs<T extends Object>(
    Expression<T> Function($$LocalPurchaseItemsTableAnnotationComposer a) f,
  ) {
    final $$LocalPurchaseItemsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.localPurchaseItems,
          getReferencedColumn: (t) => t.purchaseId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LocalPurchaseItemsTableAnnotationComposer(
                $db: $db,
                $table: $db.localPurchaseItems,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$LocalPurchasesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalPurchasesTable,
          LocalPurchase,
          $$LocalPurchasesTableFilterComposer,
          $$LocalPurchasesTableOrderingComposer,
          $$LocalPurchasesTableAnnotationComposer,
          $$LocalPurchasesTableCreateCompanionBuilder,
          $$LocalPurchasesTableUpdateCompanionBuilder,
          (LocalPurchase, $$LocalPurchasesTableReferences),
          LocalPurchase,
          PrefetchHooks Function({bool localPurchaseItemsRefs})
        > {
  $$LocalPurchasesTableTableManager(
    _$AppDatabase db,
    $LocalPurchasesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalPurchasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalPurchasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalPurchasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<String> storeId = const Value.absent(),
                Value<String> supplierId = const Value.absent(),
                Value<String?> reference = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<double> total = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalPurchasesCompanion(
                id: id,
                companyId: companyId,
                storeId: storeId,
                supplierId: supplierId,
                reference: reference,
                status: status,
                total: total,
                createdBy: createdBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String companyId,
                required String storeId,
                required String supplierId,
                Value<String?> reference = const Value.absent(),
                required String status,
                required double total,
                required String createdBy,
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalPurchasesCompanion.insert(
                id: id,
                companyId: companyId,
                storeId: storeId,
                supplierId: supplierId,
                reference: reference,
                status: status,
                total: total,
                createdBy: createdBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LocalPurchasesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({localPurchaseItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (localPurchaseItemsRefs) db.localPurchaseItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (localPurchaseItemsRefs)
                    await $_getPrefetchedData<
                      LocalPurchase,
                      $LocalPurchasesTable,
                      LocalPurchaseItem
                    >(
                      currentTable: table,
                      referencedTable: $$LocalPurchasesTableReferences
                          ._localPurchaseItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LocalPurchasesTableReferences(
                            db,
                            table,
                            p0,
                          ).localPurchaseItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.purchaseId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LocalPurchasesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalPurchasesTable,
      LocalPurchase,
      $$LocalPurchasesTableFilterComposer,
      $$LocalPurchasesTableOrderingComposer,
      $$LocalPurchasesTableAnnotationComposer,
      $$LocalPurchasesTableCreateCompanionBuilder,
      $$LocalPurchasesTableUpdateCompanionBuilder,
      (LocalPurchase, $$LocalPurchasesTableReferences),
      LocalPurchase,
      PrefetchHooks Function({bool localPurchaseItemsRefs})
    >;
typedef $$LocalPurchaseItemsTableCreateCompanionBuilder =
    LocalPurchaseItemsCompanion Function({
      required String id,
      required String purchaseId,
      required String productId,
      required int quantity,
      required double unitPrice,
      required double total,
      Value<int> rowid,
    });
typedef $$LocalPurchaseItemsTableUpdateCompanionBuilder =
    LocalPurchaseItemsCompanion Function({
      Value<String> id,
      Value<String> purchaseId,
      Value<String> productId,
      Value<int> quantity,
      Value<double> unitPrice,
      Value<double> total,
      Value<int> rowid,
    });

final class $$LocalPurchaseItemsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $LocalPurchaseItemsTable,
          LocalPurchaseItem
        > {
  $$LocalPurchaseItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LocalPurchasesTable _purchaseIdTable(_$AppDatabase db) =>
      db.localPurchases.createAlias(
        $_aliasNameGenerator(
          db.localPurchaseItems.purchaseId,
          db.localPurchases.id,
        ),
      );

  $$LocalPurchasesTableProcessedTableManager get purchaseId {
    final $_column = $_itemColumn<String>('purchase_id')!;

    final manager = $$LocalPurchasesTableTableManager(
      $_db,
      $_db.localPurchases,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_purchaseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LocalPurchaseItemsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalPurchaseItemsTable> {
  $$LocalPurchaseItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get unitPrice => $composableBuilder(
    column: $table.unitPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  $$LocalPurchasesTableFilterComposer get purchaseId {
    final $$LocalPurchasesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.purchaseId,
      referencedTable: $db.localPurchases,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalPurchasesTableFilterComposer(
            $db: $db,
            $table: $db.localPurchases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalPurchaseItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalPurchaseItemsTable> {
  $$LocalPurchaseItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get unitPrice => $composableBuilder(
    column: $table.unitPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  $$LocalPurchasesTableOrderingComposer get purchaseId {
    final $$LocalPurchasesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.purchaseId,
      referencedTable: $db.localPurchases,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalPurchasesTableOrderingComposer(
            $db: $db,
            $table: $db.localPurchases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalPurchaseItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalPurchaseItemsTable> {
  $$LocalPurchaseItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get unitPrice =>
      $composableBuilder(column: $table.unitPrice, builder: (column) => column);

  GeneratedColumn<double> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  $$LocalPurchasesTableAnnotationComposer get purchaseId {
    final $$LocalPurchasesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.purchaseId,
      referencedTable: $db.localPurchases,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalPurchasesTableAnnotationComposer(
            $db: $db,
            $table: $db.localPurchases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalPurchaseItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalPurchaseItemsTable,
          LocalPurchaseItem,
          $$LocalPurchaseItemsTableFilterComposer,
          $$LocalPurchaseItemsTableOrderingComposer,
          $$LocalPurchaseItemsTableAnnotationComposer,
          $$LocalPurchaseItemsTableCreateCompanionBuilder,
          $$LocalPurchaseItemsTableUpdateCompanionBuilder,
          (LocalPurchaseItem, $$LocalPurchaseItemsTableReferences),
          LocalPurchaseItem,
          PrefetchHooks Function({bool purchaseId})
        > {
  $$LocalPurchaseItemsTableTableManager(
    _$AppDatabase db,
    $LocalPurchaseItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalPurchaseItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalPurchaseItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalPurchaseItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> purchaseId = const Value.absent(),
                Value<String> productId = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<double> unitPrice = const Value.absent(),
                Value<double> total = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalPurchaseItemsCompanion(
                id: id,
                purchaseId: purchaseId,
                productId: productId,
                quantity: quantity,
                unitPrice: unitPrice,
                total: total,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String purchaseId,
                required String productId,
                required int quantity,
                required double unitPrice,
                required double total,
                Value<int> rowid = const Value.absent(),
              }) => LocalPurchaseItemsCompanion.insert(
                id: id,
                purchaseId: purchaseId,
                productId: productId,
                quantity: quantity,
                unitPrice: unitPrice,
                total: total,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LocalPurchaseItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({purchaseId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (purchaseId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.purchaseId,
                                referencedTable:
                                    $$LocalPurchaseItemsTableReferences
                                        ._purchaseIdTable(db),
                                referencedColumn:
                                    $$LocalPurchaseItemsTableReferences
                                        ._purchaseIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LocalPurchaseItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalPurchaseItemsTable,
      LocalPurchaseItem,
      $$LocalPurchaseItemsTableFilterComposer,
      $$LocalPurchaseItemsTableOrderingComposer,
      $$LocalPurchaseItemsTableAnnotationComposer,
      $$LocalPurchaseItemsTableCreateCompanionBuilder,
      $$LocalPurchaseItemsTableUpdateCompanionBuilder,
      (LocalPurchaseItem, $$LocalPurchaseItemsTableReferences),
      LocalPurchaseItem,
      PrefetchHooks Function({bool purchaseId})
    >;
typedef $$LocalTransfersTableCreateCompanionBuilder =
    LocalTransfersCompanion Function({
      required String id,
      required String companyId,
      required String fromStoreId,
      required String toStoreId,
      Value<bool> fromWarehouse,
      required String status,
      required String requestedBy,
      Value<String?> approvedBy,
      Value<String?> shippedAt,
      Value<String?> receivedAt,
      Value<String?> receivedBy,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$LocalTransfersTableUpdateCompanionBuilder =
    LocalTransfersCompanion Function({
      Value<String> id,
      Value<String> companyId,
      Value<String> fromStoreId,
      Value<String> toStoreId,
      Value<bool> fromWarehouse,
      Value<String> status,
      Value<String> requestedBy,
      Value<String?> approvedBy,
      Value<String?> shippedAt,
      Value<String?> receivedAt,
      Value<String?> receivedBy,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

final class $$LocalTransfersTableReferences
    extends BaseReferences<_$AppDatabase, $LocalTransfersTable, LocalTransfer> {
  $$LocalTransfersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$LocalTransferItemsTable, List<LocalTransferItem>>
  _localTransferItemsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.localTransferItems,
        aliasName: $_aliasNameGenerator(
          db.localTransfers.id,
          db.localTransferItems.transferId,
        ),
      );

  $$LocalTransferItemsTableProcessedTableManager get localTransferItemsRefs {
    final manager = $$LocalTransferItemsTableTableManager(
      $_db,
      $_db.localTransferItems,
    ).filter((f) => f.transferId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _localTransferItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LocalTransfersTableFilterComposer
    extends Composer<_$AppDatabase, $LocalTransfersTable> {
  $$LocalTransfersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromStoreId => $composableBuilder(
    column: $table.fromStoreId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toStoreId => $composableBuilder(
    column: $table.toStoreId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get fromWarehouse => $composableBuilder(
    column: $table.fromWarehouse,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get requestedBy => $composableBuilder(
    column: $table.requestedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get approvedBy => $composableBuilder(
    column: $table.approvedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shippedAt => $composableBuilder(
    column: $table.shippedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receivedBy => $composableBuilder(
    column: $table.receivedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> localTransferItemsRefs(
    Expression<bool> Function($$LocalTransferItemsTableFilterComposer f) f,
  ) {
    final $$LocalTransferItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localTransferItems,
      getReferencedColumn: (t) => t.transferId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalTransferItemsTableFilterComposer(
            $db: $db,
            $table: $db.localTransferItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalTransfersTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalTransfersTable> {
  $$LocalTransfersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromStoreId => $composableBuilder(
    column: $table.fromStoreId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toStoreId => $composableBuilder(
    column: $table.toStoreId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get fromWarehouse => $composableBuilder(
    column: $table.fromWarehouse,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get requestedBy => $composableBuilder(
    column: $table.requestedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get approvedBy => $composableBuilder(
    column: $table.approvedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shippedAt => $composableBuilder(
    column: $table.shippedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receivedBy => $composableBuilder(
    column: $table.receivedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalTransfersTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalTransfersTable> {
  $$LocalTransfersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get fromStoreId => $composableBuilder(
    column: $table.fromStoreId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get toStoreId =>
      $composableBuilder(column: $table.toStoreId, builder: (column) => column);

  GeneratedColumn<bool> get fromWarehouse => $composableBuilder(
    column: $table.fromWarehouse,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get requestedBy => $composableBuilder(
    column: $table.requestedBy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get approvedBy => $composableBuilder(
    column: $table.approvedBy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get shippedAt =>
      $composableBuilder(column: $table.shippedAt, builder: (column) => column);

  GeneratedColumn<String> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get receivedBy => $composableBuilder(
    column: $table.receivedBy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> localTransferItemsRefs<T extends Object>(
    Expression<T> Function($$LocalTransferItemsTableAnnotationComposer a) f,
  ) {
    final $$LocalTransferItemsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.localTransferItems,
          getReferencedColumn: (t) => t.transferId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LocalTransferItemsTableAnnotationComposer(
                $db: $db,
                $table: $db.localTransferItems,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$LocalTransfersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalTransfersTable,
          LocalTransfer,
          $$LocalTransfersTableFilterComposer,
          $$LocalTransfersTableOrderingComposer,
          $$LocalTransfersTableAnnotationComposer,
          $$LocalTransfersTableCreateCompanionBuilder,
          $$LocalTransfersTableUpdateCompanionBuilder,
          (LocalTransfer, $$LocalTransfersTableReferences),
          LocalTransfer,
          PrefetchHooks Function({bool localTransferItemsRefs})
        > {
  $$LocalTransfersTableTableManager(
    _$AppDatabase db,
    $LocalTransfersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalTransfersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalTransfersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalTransfersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<String> fromStoreId = const Value.absent(),
                Value<String> toStoreId = const Value.absent(),
                Value<bool> fromWarehouse = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> requestedBy = const Value.absent(),
                Value<String?> approvedBy = const Value.absent(),
                Value<String?> shippedAt = const Value.absent(),
                Value<String?> receivedAt = const Value.absent(),
                Value<String?> receivedBy = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalTransfersCompanion(
                id: id,
                companyId: companyId,
                fromStoreId: fromStoreId,
                toStoreId: toStoreId,
                fromWarehouse: fromWarehouse,
                status: status,
                requestedBy: requestedBy,
                approvedBy: approvedBy,
                shippedAt: shippedAt,
                receivedAt: receivedAt,
                receivedBy: receivedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String companyId,
                required String fromStoreId,
                required String toStoreId,
                Value<bool> fromWarehouse = const Value.absent(),
                required String status,
                required String requestedBy,
                Value<String?> approvedBy = const Value.absent(),
                Value<String?> shippedAt = const Value.absent(),
                Value<String?> receivedAt = const Value.absent(),
                Value<String?> receivedBy = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalTransfersCompanion.insert(
                id: id,
                companyId: companyId,
                fromStoreId: fromStoreId,
                toStoreId: toStoreId,
                fromWarehouse: fromWarehouse,
                status: status,
                requestedBy: requestedBy,
                approvedBy: approvedBy,
                shippedAt: shippedAt,
                receivedAt: receivedAt,
                receivedBy: receivedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LocalTransfersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({localTransferItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (localTransferItemsRefs) db.localTransferItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (localTransferItemsRefs)
                    await $_getPrefetchedData<
                      LocalTransfer,
                      $LocalTransfersTable,
                      LocalTransferItem
                    >(
                      currentTable: table,
                      referencedTable: $$LocalTransfersTableReferences
                          ._localTransferItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LocalTransfersTableReferences(
                            db,
                            table,
                            p0,
                          ).localTransferItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.transferId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LocalTransfersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalTransfersTable,
      LocalTransfer,
      $$LocalTransfersTableFilterComposer,
      $$LocalTransfersTableOrderingComposer,
      $$LocalTransfersTableAnnotationComposer,
      $$LocalTransfersTableCreateCompanionBuilder,
      $$LocalTransfersTableUpdateCompanionBuilder,
      (LocalTransfer, $$LocalTransfersTableReferences),
      LocalTransfer,
      PrefetchHooks Function({bool localTransferItemsRefs})
    >;
typedef $$LocalTransferItemsTableCreateCompanionBuilder =
    LocalTransferItemsCompanion Function({
      required String id,
      required String transferId,
      required String productId,
      required int quantityRequested,
      Value<int> quantityShipped,
      Value<int> quantityReceived,
      Value<int> rowid,
    });
typedef $$LocalTransferItemsTableUpdateCompanionBuilder =
    LocalTransferItemsCompanion Function({
      Value<String> id,
      Value<String> transferId,
      Value<String> productId,
      Value<int> quantityRequested,
      Value<int> quantityShipped,
      Value<int> quantityReceived,
      Value<int> rowid,
    });

final class $$LocalTransferItemsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $LocalTransferItemsTable,
          LocalTransferItem
        > {
  $$LocalTransferItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LocalTransfersTable _transferIdTable(_$AppDatabase db) =>
      db.localTransfers.createAlias(
        $_aliasNameGenerator(
          db.localTransferItems.transferId,
          db.localTransfers.id,
        ),
      );

  $$LocalTransfersTableProcessedTableManager get transferId {
    final $_column = $_itemColumn<String>('transfer_id')!;

    final manager = $$LocalTransfersTableTableManager(
      $_db,
      $_db.localTransfers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transferIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LocalTransferItemsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalTransferItemsTable> {
  $$LocalTransferItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantityRequested => $composableBuilder(
    column: $table.quantityRequested,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantityShipped => $composableBuilder(
    column: $table.quantityShipped,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantityReceived => $composableBuilder(
    column: $table.quantityReceived,
    builder: (column) => ColumnFilters(column),
  );

  $$LocalTransfersTableFilterComposer get transferId {
    final $$LocalTransfersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transferId,
      referencedTable: $db.localTransfers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalTransfersTableFilterComposer(
            $db: $db,
            $table: $db.localTransfers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalTransferItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalTransferItemsTable> {
  $$LocalTransferItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantityRequested => $composableBuilder(
    column: $table.quantityRequested,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantityShipped => $composableBuilder(
    column: $table.quantityShipped,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantityReceived => $composableBuilder(
    column: $table.quantityReceived,
    builder: (column) => ColumnOrderings(column),
  );

  $$LocalTransfersTableOrderingComposer get transferId {
    final $$LocalTransfersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transferId,
      referencedTable: $db.localTransfers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalTransfersTableOrderingComposer(
            $db: $db,
            $table: $db.localTransfers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalTransferItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalTransferItemsTable> {
  $$LocalTransferItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<int> get quantityRequested => $composableBuilder(
    column: $table.quantityRequested,
    builder: (column) => column,
  );

  GeneratedColumn<int> get quantityShipped => $composableBuilder(
    column: $table.quantityShipped,
    builder: (column) => column,
  );

  GeneratedColumn<int> get quantityReceived => $composableBuilder(
    column: $table.quantityReceived,
    builder: (column) => column,
  );

  $$LocalTransfersTableAnnotationComposer get transferId {
    final $$LocalTransfersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transferId,
      referencedTable: $db.localTransfers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalTransfersTableAnnotationComposer(
            $db: $db,
            $table: $db.localTransfers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalTransferItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalTransferItemsTable,
          LocalTransferItem,
          $$LocalTransferItemsTableFilterComposer,
          $$LocalTransferItemsTableOrderingComposer,
          $$LocalTransferItemsTableAnnotationComposer,
          $$LocalTransferItemsTableCreateCompanionBuilder,
          $$LocalTransferItemsTableUpdateCompanionBuilder,
          (LocalTransferItem, $$LocalTransferItemsTableReferences),
          LocalTransferItem,
          PrefetchHooks Function({bool transferId})
        > {
  $$LocalTransferItemsTableTableManager(
    _$AppDatabase db,
    $LocalTransferItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalTransferItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalTransferItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalTransferItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> transferId = const Value.absent(),
                Value<String> productId = const Value.absent(),
                Value<int> quantityRequested = const Value.absent(),
                Value<int> quantityShipped = const Value.absent(),
                Value<int> quantityReceived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalTransferItemsCompanion(
                id: id,
                transferId: transferId,
                productId: productId,
                quantityRequested: quantityRequested,
                quantityShipped: quantityShipped,
                quantityReceived: quantityReceived,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String transferId,
                required String productId,
                required int quantityRequested,
                Value<int> quantityShipped = const Value.absent(),
                Value<int> quantityReceived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalTransferItemsCompanion.insert(
                id: id,
                transferId: transferId,
                productId: productId,
                quantityRequested: quantityRequested,
                quantityShipped: quantityShipped,
                quantityReceived: quantityReceived,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LocalTransferItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({transferId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (transferId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.transferId,
                                referencedTable:
                                    $$LocalTransferItemsTableReferences
                                        ._transferIdTable(db),
                                referencedColumn:
                                    $$LocalTransferItemsTableReferences
                                        ._transferIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LocalTransferItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalTransferItemsTable,
      LocalTransferItem,
      $$LocalTransferItemsTableFilterComposer,
      $$LocalTransferItemsTableOrderingComposer,
      $$LocalTransferItemsTableAnnotationComposer,
      $$LocalTransferItemsTableCreateCompanionBuilder,
      $$LocalTransferItemsTableUpdateCompanionBuilder,
      (LocalTransferItem, $$LocalTransferItemsTableReferences),
      LocalTransferItem,
      PrefetchHooks Function({bool transferId})
    >;
typedef $$LocalWarehouseInventoryTableCreateCompanionBuilder =
    LocalWarehouseInventoryCompanion Function({
      required String companyId,
      required String productId,
      Value<int> quantity,
      Value<double?> avgUnitCost,
      Value<int> stockMinWarehouse,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$LocalWarehouseInventoryTableUpdateCompanionBuilder =
    LocalWarehouseInventoryCompanion Function({
      Value<String> companyId,
      Value<String> productId,
      Value<int> quantity,
      Value<double?> avgUnitCost,
      Value<int> stockMinWarehouse,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$LocalWarehouseInventoryTableFilterComposer
    extends Composer<_$AppDatabase, $LocalWarehouseInventoryTable> {
  $$LocalWarehouseInventoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get avgUnitCost => $composableBuilder(
    column: $table.avgUnitCost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stockMinWarehouse => $composableBuilder(
    column: $table.stockMinWarehouse,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalWarehouseInventoryTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalWarehouseInventoryTable> {
  $$LocalWarehouseInventoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get avgUnitCost => $composableBuilder(
    column: $table.avgUnitCost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stockMinWarehouse => $composableBuilder(
    column: $table.stockMinWarehouse,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalWarehouseInventoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalWarehouseInventoryTable> {
  $$LocalWarehouseInventoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get avgUnitCost => $composableBuilder(
    column: $table.avgUnitCost,
    builder: (column) => column,
  );

  GeneratedColumn<int> get stockMinWarehouse => $composableBuilder(
    column: $table.stockMinWarehouse,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalWarehouseInventoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalWarehouseInventoryTable,
          LocalWarehouseInventoryData,
          $$LocalWarehouseInventoryTableFilterComposer,
          $$LocalWarehouseInventoryTableOrderingComposer,
          $$LocalWarehouseInventoryTableAnnotationComposer,
          $$LocalWarehouseInventoryTableCreateCompanionBuilder,
          $$LocalWarehouseInventoryTableUpdateCompanionBuilder,
          (
            LocalWarehouseInventoryData,
            BaseReferences<
              _$AppDatabase,
              $LocalWarehouseInventoryTable,
              LocalWarehouseInventoryData
            >,
          ),
          LocalWarehouseInventoryData,
          PrefetchHooks Function()
        > {
  $$LocalWarehouseInventoryTableTableManager(
    _$AppDatabase db,
    $LocalWarehouseInventoryTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalWarehouseInventoryTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalWarehouseInventoryTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalWarehouseInventoryTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> companyId = const Value.absent(),
                Value<String> productId = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<double?> avgUnitCost = const Value.absent(),
                Value<int> stockMinWarehouse = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalWarehouseInventoryCompanion(
                companyId: companyId,
                productId: productId,
                quantity: quantity,
                avgUnitCost: avgUnitCost,
                stockMinWarehouse: stockMinWarehouse,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String companyId,
                required String productId,
                Value<int> quantity = const Value.absent(),
                Value<double?> avgUnitCost = const Value.absent(),
                Value<int> stockMinWarehouse = const Value.absent(),
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalWarehouseInventoryCompanion.insert(
                companyId: companyId,
                productId: productId,
                quantity: quantity,
                avgUnitCost: avgUnitCost,
                stockMinWarehouse: stockMinWarehouse,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalWarehouseInventoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalWarehouseInventoryTable,
      LocalWarehouseInventoryData,
      $$LocalWarehouseInventoryTableFilterComposer,
      $$LocalWarehouseInventoryTableOrderingComposer,
      $$LocalWarehouseInventoryTableAnnotationComposer,
      $$LocalWarehouseInventoryTableCreateCompanionBuilder,
      $$LocalWarehouseInventoryTableUpdateCompanionBuilder,
      (
        LocalWarehouseInventoryData,
        BaseReferences<
          _$AppDatabase,
          $LocalWarehouseInventoryTable,
          LocalWarehouseInventoryData
        >,
      ),
      LocalWarehouseInventoryData,
      PrefetchHooks Function()
    >;
typedef $$LocalWarehouseMovementsTableCreateCompanionBuilder =
    LocalWarehouseMovementsCompanion Function({
      required String id,
      required String companyId,
      required String productId,
      required String movementKind,
      required int quantity,
      Value<double?> unitCost,
      Value<String> packagingType,
      Value<double> packsQuantity,
      Value<String> referenceType,
      Value<String?> referenceId,
      Value<String?> notes,
      required String createdAt,
      Value<int> rowid,
    });
typedef $$LocalWarehouseMovementsTableUpdateCompanionBuilder =
    LocalWarehouseMovementsCompanion Function({
      Value<String> id,
      Value<String> companyId,
      Value<String> productId,
      Value<String> movementKind,
      Value<int> quantity,
      Value<double?> unitCost,
      Value<String> packagingType,
      Value<double> packsQuantity,
      Value<String> referenceType,
      Value<String?> referenceId,
      Value<String?> notes,
      Value<String> createdAt,
      Value<int> rowid,
    });

class $$LocalWarehouseMovementsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalWarehouseMovementsTable> {
  $$LocalWarehouseMovementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get movementKind => $composableBuilder(
    column: $table.movementKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get unitCost => $composableBuilder(
    column: $table.unitCost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get packagingType => $composableBuilder(
    column: $table.packagingType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get packsQuantity => $composableBuilder(
    column: $table.packsQuantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referenceType => $composableBuilder(
    column: $table.referenceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referenceId => $composableBuilder(
    column: $table.referenceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalWarehouseMovementsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalWarehouseMovementsTable> {
  $$LocalWarehouseMovementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get movementKind => $composableBuilder(
    column: $table.movementKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get unitCost => $composableBuilder(
    column: $table.unitCost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get packagingType => $composableBuilder(
    column: $table.packagingType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get packsQuantity => $composableBuilder(
    column: $table.packsQuantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referenceType => $composableBuilder(
    column: $table.referenceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referenceId => $composableBuilder(
    column: $table.referenceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalWarehouseMovementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalWarehouseMovementsTable> {
  $$LocalWarehouseMovementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get movementKind => $composableBuilder(
    column: $table.movementKind,
    builder: (column) => column,
  );

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get unitCost =>
      $composableBuilder(column: $table.unitCost, builder: (column) => column);

  GeneratedColumn<String> get packagingType => $composableBuilder(
    column: $table.packagingType,
    builder: (column) => column,
  );

  GeneratedColumn<double> get packsQuantity => $composableBuilder(
    column: $table.packsQuantity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get referenceType => $composableBuilder(
    column: $table.referenceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get referenceId => $composableBuilder(
    column: $table.referenceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalWarehouseMovementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalWarehouseMovementsTable,
          LocalWarehouseMovement,
          $$LocalWarehouseMovementsTableFilterComposer,
          $$LocalWarehouseMovementsTableOrderingComposer,
          $$LocalWarehouseMovementsTableAnnotationComposer,
          $$LocalWarehouseMovementsTableCreateCompanionBuilder,
          $$LocalWarehouseMovementsTableUpdateCompanionBuilder,
          (
            LocalWarehouseMovement,
            BaseReferences<
              _$AppDatabase,
              $LocalWarehouseMovementsTable,
              LocalWarehouseMovement
            >,
          ),
          LocalWarehouseMovement,
          PrefetchHooks Function()
        > {
  $$LocalWarehouseMovementsTableTableManager(
    _$AppDatabase db,
    $LocalWarehouseMovementsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalWarehouseMovementsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalWarehouseMovementsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalWarehouseMovementsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<String> productId = const Value.absent(),
                Value<String> movementKind = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<double?> unitCost = const Value.absent(),
                Value<String> packagingType = const Value.absent(),
                Value<double> packsQuantity = const Value.absent(),
                Value<String> referenceType = const Value.absent(),
                Value<String?> referenceId = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalWarehouseMovementsCompanion(
                id: id,
                companyId: companyId,
                productId: productId,
                movementKind: movementKind,
                quantity: quantity,
                unitCost: unitCost,
                packagingType: packagingType,
                packsQuantity: packsQuantity,
                referenceType: referenceType,
                referenceId: referenceId,
                notes: notes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String companyId,
                required String productId,
                required String movementKind,
                required int quantity,
                Value<double?> unitCost = const Value.absent(),
                Value<String> packagingType = const Value.absent(),
                Value<double> packsQuantity = const Value.absent(),
                Value<String> referenceType = const Value.absent(),
                Value<String?> referenceId = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalWarehouseMovementsCompanion.insert(
                id: id,
                companyId: companyId,
                productId: productId,
                movementKind: movementKind,
                quantity: quantity,
                unitCost: unitCost,
                packagingType: packagingType,
                packsQuantity: packsQuantity,
                referenceType: referenceType,
                referenceId: referenceId,
                notes: notes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalWarehouseMovementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalWarehouseMovementsTable,
      LocalWarehouseMovement,
      $$LocalWarehouseMovementsTableFilterComposer,
      $$LocalWarehouseMovementsTableOrderingComposer,
      $$LocalWarehouseMovementsTableAnnotationComposer,
      $$LocalWarehouseMovementsTableCreateCompanionBuilder,
      $$LocalWarehouseMovementsTableUpdateCompanionBuilder,
      (
        LocalWarehouseMovement,
        BaseReferences<
          _$AppDatabase,
          $LocalWarehouseMovementsTable,
          LocalWarehouseMovement
        >,
      ),
      LocalWarehouseMovement,
      PrefetchHooks Function()
    >;
typedef $$LocalWarehouseDispatchInvoicesTableCreateCompanionBuilder =
    LocalWarehouseDispatchInvoicesCompanion Function({
      required String id,
      required String companyId,
      Value<String?> customerId,
      Value<String?> customerName,
      required String documentNumber,
      Value<String?> notes,
      required String createdAt,
      Value<int> rowid,
    });
typedef $$LocalWarehouseDispatchInvoicesTableUpdateCompanionBuilder =
    LocalWarehouseDispatchInvoicesCompanion Function({
      Value<String> id,
      Value<String> companyId,
      Value<String?> customerId,
      Value<String?> customerName,
      Value<String> documentNumber,
      Value<String?> notes,
      Value<String> createdAt,
      Value<int> rowid,
    });

class $$LocalWarehouseDispatchInvoicesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalWarehouseDispatchInvoicesTable> {
  $$LocalWarehouseDispatchInvoicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentNumber => $composableBuilder(
    column: $table.documentNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalWarehouseDispatchInvoicesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalWarehouseDispatchInvoicesTable> {
  $$LocalWarehouseDispatchInvoicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentNumber => $composableBuilder(
    column: $table.documentNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalWarehouseDispatchInvoicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalWarehouseDispatchInvoicesTable> {
  $$LocalWarehouseDispatchInvoicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get documentNumber => $composableBuilder(
    column: $table.documentNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalWarehouseDispatchInvoicesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalWarehouseDispatchInvoicesTable,
          LocalWarehouseDispatchInvoice,
          $$LocalWarehouseDispatchInvoicesTableFilterComposer,
          $$LocalWarehouseDispatchInvoicesTableOrderingComposer,
          $$LocalWarehouseDispatchInvoicesTableAnnotationComposer,
          $$LocalWarehouseDispatchInvoicesTableCreateCompanionBuilder,
          $$LocalWarehouseDispatchInvoicesTableUpdateCompanionBuilder,
          (
            LocalWarehouseDispatchInvoice,
            BaseReferences<
              _$AppDatabase,
              $LocalWarehouseDispatchInvoicesTable,
              LocalWarehouseDispatchInvoice
            >,
          ),
          LocalWarehouseDispatchInvoice,
          PrefetchHooks Function()
        > {
  $$LocalWarehouseDispatchInvoicesTableTableManager(
    _$AppDatabase db,
    $LocalWarehouseDispatchInvoicesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalWarehouseDispatchInvoicesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalWarehouseDispatchInvoicesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalWarehouseDispatchInvoicesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<String?> customerId = const Value.absent(),
                Value<String?> customerName = const Value.absent(),
                Value<String> documentNumber = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalWarehouseDispatchInvoicesCompanion(
                id: id,
                companyId: companyId,
                customerId: customerId,
                customerName: customerName,
                documentNumber: documentNumber,
                notes: notes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String companyId,
                Value<String?> customerId = const Value.absent(),
                Value<String?> customerName = const Value.absent(),
                required String documentNumber,
                Value<String?> notes = const Value.absent(),
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalWarehouseDispatchInvoicesCompanion.insert(
                id: id,
                companyId: companyId,
                customerId: customerId,
                customerName: customerName,
                documentNumber: documentNumber,
                notes: notes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalWarehouseDispatchInvoicesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalWarehouseDispatchInvoicesTable,
      LocalWarehouseDispatchInvoice,
      $$LocalWarehouseDispatchInvoicesTableFilterComposer,
      $$LocalWarehouseDispatchInvoicesTableOrderingComposer,
      $$LocalWarehouseDispatchInvoicesTableAnnotationComposer,
      $$LocalWarehouseDispatchInvoicesTableCreateCompanionBuilder,
      $$LocalWarehouseDispatchInvoicesTableUpdateCompanionBuilder,
      (
        LocalWarehouseDispatchInvoice,
        BaseReferences<
          _$AppDatabase,
          $LocalWarehouseDispatchInvoicesTable,
          LocalWarehouseDispatchInvoice
        >,
      ),
      LocalWarehouseDispatchInvoice,
      PrefetchHooks Function()
    >;
typedef $$LocalStockMovementsTableCreateCompanionBuilder =
    LocalStockMovementsCompanion Function({
      required String id,
      required String storeId,
      required String productId,
      required String type,
      required int quantity,
      Value<String?> referenceType,
      Value<String?> referenceId,
      Value<String?> createdBy,
      required String createdAt,
      Value<String?> notes,
      Value<int> rowid,
    });
typedef $$LocalStockMovementsTableUpdateCompanionBuilder =
    LocalStockMovementsCompanion Function({
      Value<String> id,
      Value<String> storeId,
      Value<String> productId,
      Value<String> type,
      Value<int> quantity,
      Value<String?> referenceType,
      Value<String?> referenceId,
      Value<String?> createdBy,
      Value<String> createdAt,
      Value<String?> notes,
      Value<int> rowid,
    });

class $$LocalStockMovementsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalStockMovementsTable> {
  $$LocalStockMovementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referenceType => $composableBuilder(
    column: $table.referenceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referenceId => $composableBuilder(
    column: $table.referenceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalStockMovementsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalStockMovementsTable> {
  $$LocalStockMovementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referenceType => $composableBuilder(
    column: $table.referenceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referenceId => $composableBuilder(
    column: $table.referenceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalStockMovementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalStockMovementsTable> {
  $$LocalStockMovementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get storeId =>
      $composableBuilder(column: $table.storeId, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get referenceType => $composableBuilder(
    column: $table.referenceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get referenceId => $composableBuilder(
    column: $table.referenceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);
}

class $$LocalStockMovementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalStockMovementsTable,
          LocalStockMovement,
          $$LocalStockMovementsTableFilterComposer,
          $$LocalStockMovementsTableOrderingComposer,
          $$LocalStockMovementsTableAnnotationComposer,
          $$LocalStockMovementsTableCreateCompanionBuilder,
          $$LocalStockMovementsTableUpdateCompanionBuilder,
          (
            LocalStockMovement,
            BaseReferences<
              _$AppDatabase,
              $LocalStockMovementsTable,
              LocalStockMovement
            >,
          ),
          LocalStockMovement,
          PrefetchHooks Function()
        > {
  $$LocalStockMovementsTableTableManager(
    _$AppDatabase db,
    $LocalStockMovementsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalStockMovementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalStockMovementsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalStockMovementsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> storeId = const Value.absent(),
                Value<String> productId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<String?> referenceType = const Value.absent(),
                Value<String?> referenceId = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalStockMovementsCompanion(
                id: id,
                storeId: storeId,
                productId: productId,
                type: type,
                quantity: quantity,
                referenceType: referenceType,
                referenceId: referenceId,
                createdBy: createdBy,
                createdAt: createdAt,
                notes: notes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String storeId,
                required String productId,
                required String type,
                required int quantity,
                Value<String?> referenceType = const Value.absent(),
                Value<String?> referenceId = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                required String createdAt,
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalStockMovementsCompanion.insert(
                id: id,
                storeId: storeId,
                productId: productId,
                type: type,
                quantity: quantity,
                referenceType: referenceType,
                referenceId: referenceId,
                createdBy: createdBy,
                createdAt: createdAt,
                notes: notes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalStockMovementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalStockMovementsTable,
      LocalStockMovement,
      $$LocalStockMovementsTableFilterComposer,
      $$LocalStockMovementsTableOrderingComposer,
      $$LocalStockMovementsTableAnnotationComposer,
      $$LocalStockMovementsTableCreateCompanionBuilder,
      $$LocalStockMovementsTableUpdateCompanionBuilder,
      (
        LocalStockMovement,
        BaseReferences<
          _$AppDatabase,
          $LocalStockMovementsTable,
          LocalStockMovement
        >,
      ),
      LocalStockMovement,
      PrefetchHooks Function()
    >;
typedef $$LocalCompanySettingsTableCreateCompanionBuilder =
    LocalCompanySettingsCompanion Function({
      required String companyId,
      required String key,
      required String valueText,
      Value<int> rowid,
    });
typedef $$LocalCompanySettingsTableUpdateCompanionBuilder =
    LocalCompanySettingsCompanion Function({
      Value<String> companyId,
      Value<String> key,
      Value<String> valueText,
      Value<int> rowid,
    });

class $$LocalCompanySettingsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalCompanySettingsTable> {
  $$LocalCompanySettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueText => $composableBuilder(
    column: $table.valueText,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalCompanySettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalCompanySettingsTable> {
  $$LocalCompanySettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueText => $composableBuilder(
    column: $table.valueText,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalCompanySettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalCompanySettingsTable> {
  $$LocalCompanySettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get valueText =>
      $composableBuilder(column: $table.valueText, builder: (column) => column);
}

class $$LocalCompanySettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalCompanySettingsTable,
          LocalCompanySetting,
          $$LocalCompanySettingsTableFilterComposer,
          $$LocalCompanySettingsTableOrderingComposer,
          $$LocalCompanySettingsTableAnnotationComposer,
          $$LocalCompanySettingsTableCreateCompanionBuilder,
          $$LocalCompanySettingsTableUpdateCompanionBuilder,
          (
            LocalCompanySetting,
            BaseReferences<
              _$AppDatabase,
              $LocalCompanySettingsTable,
              LocalCompanySetting
            >,
          ),
          LocalCompanySetting,
          PrefetchHooks Function()
        > {
  $$LocalCompanySettingsTableTableManager(
    _$AppDatabase db,
    $LocalCompanySettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalCompanySettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalCompanySettingsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalCompanySettingsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> companyId = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> valueText = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalCompanySettingsCompanion(
                companyId: companyId,
                key: key,
                valueText: valueText,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String companyId,
                required String key,
                required String valueText,
                Value<int> rowid = const Value.absent(),
              }) => LocalCompanySettingsCompanion.insert(
                companyId: companyId,
                key: key,
                valueText: valueText,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalCompanySettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalCompanySettingsTable,
      LocalCompanySetting,
      $$LocalCompanySettingsTableFilterComposer,
      $$LocalCompanySettingsTableOrderingComposer,
      $$LocalCompanySettingsTableAnnotationComposer,
      $$LocalCompanySettingsTableCreateCompanionBuilder,
      $$LocalCompanySettingsTableUpdateCompanionBuilder,
      (
        LocalCompanySetting,
        BaseReferences<
          _$AppDatabase,
          $LocalCompanySettingsTable,
          LocalCompanySetting
        >,
      ),
      LocalCompanySetting,
      PrefetchHooks Function()
    >;
typedef $$LocalStockMinOverridesTableCreateCompanionBuilder =
    LocalStockMinOverridesCompanion Function({
      required String storeId,
      required String productId,
      Value<int?> stockMinOverride,
      Value<int> rowid,
    });
typedef $$LocalStockMinOverridesTableUpdateCompanionBuilder =
    LocalStockMinOverridesCompanion Function({
      Value<String> storeId,
      Value<String> productId,
      Value<int?> stockMinOverride,
      Value<int> rowid,
    });

class $$LocalStockMinOverridesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalStockMinOverridesTable> {
  $$LocalStockMinOverridesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stockMinOverride => $composableBuilder(
    column: $table.stockMinOverride,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalStockMinOverridesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalStockMinOverridesTable> {
  $$LocalStockMinOverridesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stockMinOverride => $composableBuilder(
    column: $table.stockMinOverride,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalStockMinOverridesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalStockMinOverridesTable> {
  $$LocalStockMinOverridesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get storeId =>
      $composableBuilder(column: $table.storeId, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<int> get stockMinOverride => $composableBuilder(
    column: $table.stockMinOverride,
    builder: (column) => column,
  );
}

class $$LocalStockMinOverridesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalStockMinOverridesTable,
          LocalStockMinOverride,
          $$LocalStockMinOverridesTableFilterComposer,
          $$LocalStockMinOverridesTableOrderingComposer,
          $$LocalStockMinOverridesTableAnnotationComposer,
          $$LocalStockMinOverridesTableCreateCompanionBuilder,
          $$LocalStockMinOverridesTableUpdateCompanionBuilder,
          (
            LocalStockMinOverride,
            BaseReferences<
              _$AppDatabase,
              $LocalStockMinOverridesTable,
              LocalStockMinOverride
            >,
          ),
          LocalStockMinOverride,
          PrefetchHooks Function()
        > {
  $$LocalStockMinOverridesTableTableManager(
    _$AppDatabase db,
    $LocalStockMinOverridesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalStockMinOverridesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalStockMinOverridesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalStockMinOverridesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> storeId = const Value.absent(),
                Value<String> productId = const Value.absent(),
                Value<int?> stockMinOverride = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalStockMinOverridesCompanion(
                storeId: storeId,
                productId: productId,
                stockMinOverride: stockMinOverride,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String storeId,
                required String productId,
                Value<int?> stockMinOverride = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalStockMinOverridesCompanion.insert(
                storeId: storeId,
                productId: productId,
                stockMinOverride: stockMinOverride,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalStockMinOverridesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalStockMinOverridesTable,
      LocalStockMinOverride,
      $$LocalStockMinOverridesTableFilterComposer,
      $$LocalStockMinOverridesTableOrderingComposer,
      $$LocalStockMinOverridesTableAnnotationComposer,
      $$LocalStockMinOverridesTableCreateCompanionBuilder,
      $$LocalStockMinOverridesTableUpdateCompanionBuilder,
      (
        LocalStockMinOverride,
        BaseReferences<
          _$AppDatabase,
          $LocalStockMinOverridesTable,
          LocalStockMinOverride
        >,
      ),
      LocalStockMinOverride,
      PrefetchHooks Function()
    >;
typedef $$LocalCompanyMembersTableCreateCompanionBuilder =
    LocalCompanyMembersCompanion Function({
      required String id,
      required String companyId,
      required String userId,
      required String roleId,
      Value<bool> isActive,
      required String createdAt,
      required String roleName,
      required String roleSlug,
      Value<String?> profileFullName,
      Value<String?> email,
      Value<int> rowid,
    });
typedef $$LocalCompanyMembersTableUpdateCompanionBuilder =
    LocalCompanyMembersCompanion Function({
      Value<String> id,
      Value<String> companyId,
      Value<String> userId,
      Value<String> roleId,
      Value<bool> isActive,
      Value<String> createdAt,
      Value<String> roleName,
      Value<String> roleSlug,
      Value<String?> profileFullName,
      Value<String?> email,
      Value<int> rowid,
    });

class $$LocalCompanyMembersTableFilterComposer
    extends Composer<_$AppDatabase, $LocalCompanyMembersTable> {
  $$LocalCompanyMembersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get roleId => $composableBuilder(
    column: $table.roleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get roleName => $composableBuilder(
    column: $table.roleName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get roleSlug => $composableBuilder(
    column: $table.roleSlug,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileFullName => $composableBuilder(
    column: $table.profileFullName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalCompanyMembersTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalCompanyMembersTable> {
  $$LocalCompanyMembersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roleId => $composableBuilder(
    column: $table.roleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roleName => $composableBuilder(
    column: $table.roleName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roleSlug => $composableBuilder(
    column: $table.roleSlug,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileFullName => $composableBuilder(
    column: $table.profileFullName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalCompanyMembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalCompanyMembersTable> {
  $$LocalCompanyMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get roleId =>
      $composableBuilder(column: $table.roleId, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get roleName =>
      $composableBuilder(column: $table.roleName, builder: (column) => column);

  GeneratedColumn<String> get roleSlug =>
      $composableBuilder(column: $table.roleSlug, builder: (column) => column);

  GeneratedColumn<String> get profileFullName => $composableBuilder(
    column: $table.profileFullName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);
}

class $$LocalCompanyMembersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalCompanyMembersTable,
          LocalCompanyMember,
          $$LocalCompanyMembersTableFilterComposer,
          $$LocalCompanyMembersTableOrderingComposer,
          $$LocalCompanyMembersTableAnnotationComposer,
          $$LocalCompanyMembersTableCreateCompanionBuilder,
          $$LocalCompanyMembersTableUpdateCompanionBuilder,
          (
            LocalCompanyMember,
            BaseReferences<
              _$AppDatabase,
              $LocalCompanyMembersTable,
              LocalCompanyMember
            >,
          ),
          LocalCompanyMember,
          PrefetchHooks Function()
        > {
  $$LocalCompanyMembersTableTableManager(
    _$AppDatabase db,
    $LocalCompanyMembersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalCompanyMembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalCompanyMembersTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalCompanyMembersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> roleId = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> roleName = const Value.absent(),
                Value<String> roleSlug = const Value.absent(),
                Value<String?> profileFullName = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalCompanyMembersCompanion(
                id: id,
                companyId: companyId,
                userId: userId,
                roleId: roleId,
                isActive: isActive,
                createdAt: createdAt,
                roleName: roleName,
                roleSlug: roleSlug,
                profileFullName: profileFullName,
                email: email,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String companyId,
                required String userId,
                required String roleId,
                Value<bool> isActive = const Value.absent(),
                required String createdAt,
                required String roleName,
                required String roleSlug,
                Value<String?> profileFullName = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalCompanyMembersCompanion.insert(
                id: id,
                companyId: companyId,
                userId: userId,
                roleId: roleId,
                isActive: isActive,
                createdAt: createdAt,
                roleName: roleName,
                roleSlug: roleSlug,
                profileFullName: profileFullName,
                email: email,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalCompanyMembersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalCompanyMembersTable,
      LocalCompanyMember,
      $$LocalCompanyMembersTableFilterComposer,
      $$LocalCompanyMembersTableOrderingComposer,
      $$LocalCompanyMembersTableAnnotationComposer,
      $$LocalCompanyMembersTableCreateCompanionBuilder,
      $$LocalCompanyMembersTableUpdateCompanionBuilder,
      (
        LocalCompanyMember,
        BaseReferences<
          _$AppDatabase,
          $LocalCompanyMembersTable,
          LocalCompanyMember
        >,
      ),
      LocalCompanyMember,
      PrefetchHooks Function()
    >;
typedef $$PendingActionsTableCreateCompanionBuilder =
    PendingActionsCompanion Function({
      Value<int> id,
      required String kind,
      required String payload,
      required int createdAt,
      required int updatedAt,
      Value<bool> synced,
    });
typedef $$PendingActionsTableUpdateCompanionBuilder =
    PendingActionsCompanion Function({
      Value<int> id,
      Value<String> kind,
      Value<String> payload,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<bool> synced,
    });

class $$PendingActionsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingActionsTable> {
  $$PendingActionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingActionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingActionsTable> {
  $$PendingActionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingActionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingActionsTable> {
  $$PendingActionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);
}

class $$PendingActionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingActionsTable,
          PendingAction,
          $$PendingActionsTableFilterComposer,
          $$PendingActionsTableOrderingComposer,
          $$PendingActionsTableAnnotationComposer,
          $$PendingActionsTableCreateCompanionBuilder,
          $$PendingActionsTableUpdateCompanionBuilder,
          (
            PendingAction,
            BaseReferences<_$AppDatabase, $PendingActionsTable, PendingAction>,
          ),
          PendingAction,
          PrefetchHooks Function()
        > {
  $$PendingActionsTableTableManager(
    _$AppDatabase db,
    $PendingActionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingActionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingActionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingActionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
              }) => PendingActionsCompanion(
                id: id,
                kind: kind,
                payload: payload,
                createdAt: createdAt,
                updatedAt: updatedAt,
                synced: synced,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String kind,
                required String payload,
                required int createdAt,
                required int updatedAt,
                Value<bool> synced = const Value.absent(),
              }) => PendingActionsCompanion.insert(
                id: id,
                kind: kind,
                payload: payload,
                createdAt: createdAt,
                updatedAt: updatedAt,
                synced: synced,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingActionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingActionsTable,
      PendingAction,
      $$PendingActionsTableFilterComposer,
      $$PendingActionsTableOrderingComposer,
      $$PendingActionsTableAnnotationComposer,
      $$PendingActionsTableCreateCompanionBuilder,
      $$PendingActionsTableUpdateCompanionBuilder,
      (
        PendingAction,
        BaseReferences<_$AppDatabase, $PendingActionsTable, PendingAction>,
      ),
      PendingAction,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalProductsTableTableManager get localProducts =>
      $$LocalProductsTableTableManager(_db, _db.localProducts);
  $$StoreInventoryTableTableManager get storeInventory =>
      $$StoreInventoryTableTableManager(_db, _db.storeInventory);
  $$LocalSalesTableTableManager get localSales =>
      $$LocalSalesTableTableManager(_db, _db.localSales);
  $$LocalSaleItemsTableTableManager get localSaleItems =>
      $$LocalSaleItemsTableTableManager(_db, _db.localSaleItems);
  $$LocalCustomersTableTableManager get localCustomers =>
      $$LocalCustomersTableTableManager(_db, _db.localCustomers);
  $$LocalSuppliersTableTableManager get localSuppliers =>
      $$LocalSuppliersTableTableManager(_db, _db.localSuppliers);
  $$LocalStoresTableTableManager get localStores =>
      $$LocalStoresTableTableManager(_db, _db.localStores);
  $$LocalCategoriesTableTableManager get localCategories =>
      $$LocalCategoriesTableTableManager(_db, _db.localCategories);
  $$LocalBrandsTableTableManager get localBrands =>
      $$LocalBrandsTableTableManager(_db, _db.localBrands);
  $$LocalPurchasesTableTableManager get localPurchases =>
      $$LocalPurchasesTableTableManager(_db, _db.localPurchases);
  $$LocalPurchaseItemsTableTableManager get localPurchaseItems =>
      $$LocalPurchaseItemsTableTableManager(_db, _db.localPurchaseItems);
  $$LocalTransfersTableTableManager get localTransfers =>
      $$LocalTransfersTableTableManager(_db, _db.localTransfers);
  $$LocalTransferItemsTableTableManager get localTransferItems =>
      $$LocalTransferItemsTableTableManager(_db, _db.localTransferItems);
  $$LocalWarehouseInventoryTableTableManager get localWarehouseInventory =>
      $$LocalWarehouseInventoryTableTableManager(
        _db,
        _db.localWarehouseInventory,
      );
  $$LocalWarehouseMovementsTableTableManager get localWarehouseMovements =>
      $$LocalWarehouseMovementsTableTableManager(
        _db,
        _db.localWarehouseMovements,
      );
  $$LocalWarehouseDispatchInvoicesTableTableManager
  get localWarehouseDispatchInvoices =>
      $$LocalWarehouseDispatchInvoicesTableTableManager(
        _db,
        _db.localWarehouseDispatchInvoices,
      );
  $$LocalStockMovementsTableTableManager get localStockMovements =>
      $$LocalStockMovementsTableTableManager(_db, _db.localStockMovements);
  $$LocalCompanySettingsTableTableManager get localCompanySettings =>
      $$LocalCompanySettingsTableTableManager(_db, _db.localCompanySettings);
  $$LocalStockMinOverridesTableTableManager get localStockMinOverrides =>
      $$LocalStockMinOverridesTableTableManager(
        _db,
        _db.localStockMinOverrides,
      );
  $$LocalCompanyMembersTableTableManager get localCompanyMembers =>
      $$LocalCompanyMembersTableTableManager(_db, _db.localCompanyMembers);
  $$PendingActionsTableTableManager get pendingActions =>
      $$PendingActionsTableTableManager(_db, _db.pendingActions);
}
