// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ProductsTable extends Products with TableInfo<$ProductsTable, Product> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<double> price = GeneratedColumn<double>(
    'price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
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
  @override
  List<GeneratedColumn> get $columns => [id, name, price, imageUrl, isActive];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'products';
  @override
  VerificationContext validateIntegrity(
    Insertable<Product> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    } else if (isInserting) {
      context.missing(_priceMeta);
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Product map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Product(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}price'],
      )!,
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  $ProductsTable createAlias(String alias) {
    return $ProductsTable(attachedDatabase, alias);
  }
}

class Product extends DataClass implements Insertable<Product> {
  final int id;
  final String name;
  final double price;
  final String? imageUrl;
  final bool isActive;
  const Product({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['price'] = Variable<double>(price);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  ProductsCompanion toCompanion(bool nullToAbsent) {
    return ProductsCompanion(
      id: Value(id),
      name: Value(name),
      price: Value(price),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      isActive: Value(isActive),
    );
  }

  factory Product.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Product(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      price: serializer.fromJson<double>(json['price']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'price': serializer.toJson<double>(price),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  Product copyWith({
    int? id,
    String? name,
    double? price,
    Value<String?> imageUrl = const Value.absent(),
    bool? isActive,
  }) => Product(
    id: id ?? this.id,
    name: name ?? this.name,
    price: price ?? this.price,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    isActive: isActive ?? this.isActive,
  );
  Product copyWithCompanion(ProductsCompanion data) {
    return Product(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      price: data.price.present ? data.price.value : this.price,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Product(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('price: $price, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, price, imageUrl, isActive);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Product &&
          other.id == this.id &&
          other.name == this.name &&
          other.price == this.price &&
          other.imageUrl == this.imageUrl &&
          other.isActive == this.isActive);
}

class ProductsCompanion extends UpdateCompanion<Product> {
  final Value<int> id;
  final Value<String> name;
  final Value<double> price;
  final Value<String?> imageUrl;
  final Value<bool> isActive;
  const ProductsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.price = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.isActive = const Value.absent(),
  });
  ProductsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required double price,
    this.imageUrl = const Value.absent(),
    this.isActive = const Value.absent(),
  }) : name = Value(name),
       price = Value(price);
  static Insertable<Product> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<double>? price,
    Expression<String>? imageUrl,
    Expression<bool>? isActive,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (price != null) 'price': price,
      if (imageUrl != null) 'image_url': imageUrl,
      if (isActive != null) 'is_active': isActive,
    });
  }

  ProductsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<double>? price,
    Value<String?>? imageUrl,
    Value<bool>? isActive,
  }) {
    return ProductsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (price.present) {
      map['price'] = Variable<double>(price.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('price: $price, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }
}

class $SuppliesTable extends Supplies with TableInfo<$SuppliesTable, Supply> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SuppliesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentStockMeta = const VerificationMeta(
    'currentStock',
  );
  @override
  late final GeneratedColumn<double> currentStock = GeneratedColumn<double>(
    'current_stock',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 10,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _costPerUnitMeta = const VerificationMeta(
    'costPerUnit',
  );
  @override
  late final GeneratedColumn<double> costPerUnit = GeneratedColumn<double>(
    'cost_per_unit',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _reorderPointMeta = const VerificationMeta(
    'reorderPoint',
  );
  @override
  late final GeneratedColumn<double> reorderPoint = GeneratedColumn<double>(
    'reorder_point',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    currentStock,
    unit,
    costPerUnit,
    reorderPoint,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'supplies';
  @override
  VerificationContext validateIntegrity(
    Insertable<Supply> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('current_stock')) {
      context.handle(
        _currentStockMeta,
        currentStock.isAcceptableOrUnknown(
          data['current_stock']!,
          _currentStockMeta,
        ),
      );
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('cost_per_unit')) {
      context.handle(
        _costPerUnitMeta,
        costPerUnit.isAcceptableOrUnknown(
          data['cost_per_unit']!,
          _costPerUnitMeta,
        ),
      );
    }
    if (data.containsKey('reorder_point')) {
      context.handle(
        _reorderPointMeta,
        reorderPoint.isAcceptableOrUnknown(
          data['reorder_point']!,
          _reorderPointMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Supply map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Supply(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      currentStock: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}current_stock'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      costPerUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cost_per_unit'],
      )!,
      reorderPoint: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}reorder_point'],
      )!,
    );
  }

  @override
  $SuppliesTable createAlias(String alias) {
    return $SuppliesTable(attachedDatabase, alias);
  }
}

class Supply extends DataClass implements Insertable<Supply> {
  final int id;
  final String name;
  final double currentStock;
  final String unit;
  final double costPerUnit;
  final double reorderPoint;
  const Supply({
    required this.id,
    required this.name,
    required this.currentStock,
    required this.unit,
    required this.costPerUnit,
    required this.reorderPoint,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['current_stock'] = Variable<double>(currentStock);
    map['unit'] = Variable<String>(unit);
    map['cost_per_unit'] = Variable<double>(costPerUnit);
    map['reorder_point'] = Variable<double>(reorderPoint);
    return map;
  }

  SuppliesCompanion toCompanion(bool nullToAbsent) {
    return SuppliesCompanion(
      id: Value(id),
      name: Value(name),
      currentStock: Value(currentStock),
      unit: Value(unit),
      costPerUnit: Value(costPerUnit),
      reorderPoint: Value(reorderPoint),
    );
  }

  factory Supply.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Supply(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      currentStock: serializer.fromJson<double>(json['currentStock']),
      unit: serializer.fromJson<String>(json['unit']),
      costPerUnit: serializer.fromJson<double>(json['costPerUnit']),
      reorderPoint: serializer.fromJson<double>(json['reorderPoint']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'currentStock': serializer.toJson<double>(currentStock),
      'unit': serializer.toJson<String>(unit),
      'costPerUnit': serializer.toJson<double>(costPerUnit),
      'reorderPoint': serializer.toJson<double>(reorderPoint),
    };
  }

  Supply copyWith({
    int? id,
    String? name,
    double? currentStock,
    String? unit,
    double? costPerUnit,
    double? reorderPoint,
  }) => Supply(
    id: id ?? this.id,
    name: name ?? this.name,
    currentStock: currentStock ?? this.currentStock,
    unit: unit ?? this.unit,
    costPerUnit: costPerUnit ?? this.costPerUnit,
    reorderPoint: reorderPoint ?? this.reorderPoint,
  );
  Supply copyWithCompanion(SuppliesCompanion data) {
    return Supply(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      currentStock: data.currentStock.present
          ? data.currentStock.value
          : this.currentStock,
      unit: data.unit.present ? data.unit.value : this.unit,
      costPerUnit: data.costPerUnit.present
          ? data.costPerUnit.value
          : this.costPerUnit,
      reorderPoint: data.reorderPoint.present
          ? data.reorderPoint.value
          : this.reorderPoint,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Supply(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('currentStock: $currentStock, ')
          ..write('unit: $unit, ')
          ..write('costPerUnit: $costPerUnit, ')
          ..write('reorderPoint: $reorderPoint')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, currentStock, unit, costPerUnit, reorderPoint);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Supply &&
          other.id == this.id &&
          other.name == this.name &&
          other.currentStock == this.currentStock &&
          other.unit == this.unit &&
          other.costPerUnit == this.costPerUnit &&
          other.reorderPoint == this.reorderPoint);
}

class SuppliesCompanion extends UpdateCompanion<Supply> {
  final Value<int> id;
  final Value<String> name;
  final Value<double> currentStock;
  final Value<String> unit;
  final Value<double> costPerUnit;
  final Value<double> reorderPoint;
  const SuppliesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.currentStock = const Value.absent(),
    this.unit = const Value.absent(),
    this.costPerUnit = const Value.absent(),
    this.reorderPoint = const Value.absent(),
  });
  SuppliesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.currentStock = const Value.absent(),
    required String unit,
    this.costPerUnit = const Value.absent(),
    this.reorderPoint = const Value.absent(),
  }) : name = Value(name),
       unit = Value(unit);
  static Insertable<Supply> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<double>? currentStock,
    Expression<String>? unit,
    Expression<double>? costPerUnit,
    Expression<double>? reorderPoint,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (currentStock != null) 'current_stock': currentStock,
      if (unit != null) 'unit': unit,
      if (costPerUnit != null) 'cost_per_unit': costPerUnit,
      if (reorderPoint != null) 'reorder_point': reorderPoint,
    });
  }

  SuppliesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<double>? currentStock,
    Value<String>? unit,
    Value<double>? costPerUnit,
    Value<double>? reorderPoint,
  }) {
    return SuppliesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      currentStock: currentStock ?? this.currentStock,
      unit: unit ?? this.unit,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      reorderPoint: reorderPoint ?? this.reorderPoint,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (currentStock.present) {
      map['current_stock'] = Variable<double>(currentStock.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (costPerUnit.present) {
      map['cost_per_unit'] = Variable<double>(costPerUnit.value);
    }
    if (reorderPoint.present) {
      map['reorder_point'] = Variable<double>(reorderPoint.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SuppliesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('currentStock: $currentStock, ')
          ..write('unit: $unit, ')
          ..write('costPerUnit: $costPerUnit, ')
          ..write('reorderPoint: $reorderPoint')
          ..write(')'))
        .toString();
  }
}

class $RecipesTable extends Recipes with TableInfo<$RecipesTable, Recipe> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecipesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<int> productId = GeneratedColumn<int>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES products (id)',
    ),
  );
  static const VerificationMeta _supplyIdMeta = const VerificationMeta(
    'supplyId',
  );
  @override
  late final GeneratedColumn<int> supplyId = GeneratedColumn<int>(
    'supply_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES supplies (id)',
    ),
  );
  static const VerificationMeta _quantityRequiredMeta = const VerificationMeta(
    'quantityRequired',
  );
  @override
  late final GeneratedColumn<double> quantityRequired = GeneratedColumn<double>(
    'quantity_required',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    productId,
    supplyId,
    quantityRequired,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recipes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Recipe> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('supply_id')) {
      context.handle(
        _supplyIdMeta,
        supplyId.isAcceptableOrUnknown(data['supply_id']!, _supplyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_supplyIdMeta);
    }
    if (data.containsKey('quantity_required')) {
      context.handle(
        _quantityRequiredMeta,
        quantityRequired.isAcceptableOrUnknown(
          data['quantity_required']!,
          _quantityRequiredMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_quantityRequiredMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Recipe map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Recipe(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}product_id'],
      )!,
      supplyId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}supply_id'],
      )!,
      quantityRequired: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity_required'],
      )!,
    );
  }

  @override
  $RecipesTable createAlias(String alias) {
    return $RecipesTable(attachedDatabase, alias);
  }
}

class Recipe extends DataClass implements Insertable<Recipe> {
  final int id;
  final int productId;
  final int supplyId;
  final double quantityRequired;
  const Recipe({
    required this.id,
    required this.productId,
    required this.supplyId,
    required this.quantityRequired,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['product_id'] = Variable<int>(productId);
    map['supply_id'] = Variable<int>(supplyId);
    map['quantity_required'] = Variable<double>(quantityRequired);
    return map;
  }

  RecipesCompanion toCompanion(bool nullToAbsent) {
    return RecipesCompanion(
      id: Value(id),
      productId: Value(productId),
      supplyId: Value(supplyId),
      quantityRequired: Value(quantityRequired),
    );
  }

  factory Recipe.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Recipe(
      id: serializer.fromJson<int>(json['id']),
      productId: serializer.fromJson<int>(json['productId']),
      supplyId: serializer.fromJson<int>(json['supplyId']),
      quantityRequired: serializer.fromJson<double>(json['quantityRequired']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'productId': serializer.toJson<int>(productId),
      'supplyId': serializer.toJson<int>(supplyId),
      'quantityRequired': serializer.toJson<double>(quantityRequired),
    };
  }

  Recipe copyWith({
    int? id,
    int? productId,
    int? supplyId,
    double? quantityRequired,
  }) => Recipe(
    id: id ?? this.id,
    productId: productId ?? this.productId,
    supplyId: supplyId ?? this.supplyId,
    quantityRequired: quantityRequired ?? this.quantityRequired,
  );
  Recipe copyWithCompanion(RecipesCompanion data) {
    return Recipe(
      id: data.id.present ? data.id.value : this.id,
      productId: data.productId.present ? data.productId.value : this.productId,
      supplyId: data.supplyId.present ? data.supplyId.value : this.supplyId,
      quantityRequired: data.quantityRequired.present
          ? data.quantityRequired.value
          : this.quantityRequired,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Recipe(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('supplyId: $supplyId, ')
          ..write('quantityRequired: $quantityRequired')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, productId, supplyId, quantityRequired);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Recipe &&
          other.id == this.id &&
          other.productId == this.productId &&
          other.supplyId == this.supplyId &&
          other.quantityRequired == this.quantityRequired);
}

class RecipesCompanion extends UpdateCompanion<Recipe> {
  final Value<int> id;
  final Value<int> productId;
  final Value<int> supplyId;
  final Value<double> quantityRequired;
  const RecipesCompanion({
    this.id = const Value.absent(),
    this.productId = const Value.absent(),
    this.supplyId = const Value.absent(),
    this.quantityRequired = const Value.absent(),
  });
  RecipesCompanion.insert({
    this.id = const Value.absent(),
    required int productId,
    required int supplyId,
    required double quantityRequired,
  }) : productId = Value(productId),
       supplyId = Value(supplyId),
       quantityRequired = Value(quantityRequired);
  static Insertable<Recipe> custom({
    Expression<int>? id,
    Expression<int>? productId,
    Expression<int>? supplyId,
    Expression<double>? quantityRequired,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (productId != null) 'product_id': productId,
      if (supplyId != null) 'supply_id': supplyId,
      if (quantityRequired != null) 'quantity_required': quantityRequired,
    });
  }

  RecipesCompanion copyWith({
    Value<int>? id,
    Value<int>? productId,
    Value<int>? supplyId,
    Value<double>? quantityRequired,
  }) {
    return RecipesCompanion(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      supplyId: supplyId ?? this.supplyId,
      quantityRequired: quantityRequired ?? this.quantityRequired,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<int>(productId.value);
    }
    if (supplyId.present) {
      map['supply_id'] = Variable<int>(supplyId.value);
    }
    if (quantityRequired.present) {
      map['quantity_required'] = Variable<double>(quantityRequired.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecipesCompanion(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('supplyId: $supplyId, ')
          ..write('quantityRequired: $quantityRequired')
          ..write(')'))
        .toString();
  }
}

class $SalesTable extends Sales with TableInfo<$SalesTable, Sale> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SalesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _totalAmountMeta = const VerificationMeta(
    'totalAmount',
  );
  @override
  late final GeneratedColumn<double> totalAmount = GeneratedColumn<double>(
    'total_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paymentMethodMeta = const VerificationMeta(
    'paymentMethod',
  );
  @override
  late final GeneratedColumn<String> paymentMethod = GeneratedColumn<String>(
    'payment_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('CASH'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, date, totalAmount, paymentMethod];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sales';
  @override
  VerificationContext validateIntegrity(
    Insertable<Sale> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    }
    if (data.containsKey('total_amount')) {
      context.handle(
        _totalAmountMeta,
        totalAmount.isAcceptableOrUnknown(
          data['total_amount']!,
          _totalAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalAmountMeta);
    }
    if (data.containsKey('payment_method')) {
      context.handle(
        _paymentMethodMeta,
        paymentMethod.isAcceptableOrUnknown(
          data['payment_method']!,
          _paymentMethodMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Sale map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Sale(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      totalAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_amount'],
      )!,
      paymentMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_method'],
      )!,
    );
  }

  @override
  $SalesTable createAlias(String alias) {
    return $SalesTable(attachedDatabase, alias);
  }
}

class Sale extends DataClass implements Insertable<Sale> {
  final int id;
  final DateTime date;
  final double totalAmount;
  final String paymentMethod;
  const Sale({
    required this.id,
    required this.date,
    required this.totalAmount,
    required this.paymentMethod,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    map['total_amount'] = Variable<double>(totalAmount);
    map['payment_method'] = Variable<String>(paymentMethod);
    return map;
  }

  SalesCompanion toCompanion(bool nullToAbsent) {
    return SalesCompanion(
      id: Value(id),
      date: Value(date),
      totalAmount: Value(totalAmount),
      paymentMethod: Value(paymentMethod),
    );
  }

  factory Sale.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Sale(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      totalAmount: serializer.fromJson<double>(json['totalAmount']),
      paymentMethod: serializer.fromJson<String>(json['paymentMethod']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'totalAmount': serializer.toJson<double>(totalAmount),
      'paymentMethod': serializer.toJson<String>(paymentMethod),
    };
  }

  Sale copyWith({
    int? id,
    DateTime? date,
    double? totalAmount,
    String? paymentMethod,
  }) => Sale(
    id: id ?? this.id,
    date: date ?? this.date,
    totalAmount: totalAmount ?? this.totalAmount,
    paymentMethod: paymentMethod ?? this.paymentMethod,
  );
  Sale copyWithCompanion(SalesCompanion data) {
    return Sale(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      totalAmount: data.totalAmount.present
          ? data.totalAmount.value
          : this.totalAmount,
      paymentMethod: data.paymentMethod.present
          ? data.paymentMethod.value
          : this.paymentMethod,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Sale(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('totalAmount: $totalAmount, ')
          ..write('paymentMethod: $paymentMethod')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, date, totalAmount, paymentMethod);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Sale &&
          other.id == this.id &&
          other.date == this.date &&
          other.totalAmount == this.totalAmount &&
          other.paymentMethod == this.paymentMethod);
}

class SalesCompanion extends UpdateCompanion<Sale> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<double> totalAmount;
  final Value<String> paymentMethod;
  const SalesCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.totalAmount = const Value.absent(),
    this.paymentMethod = const Value.absent(),
  });
  SalesCompanion.insert({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    required double totalAmount,
    this.paymentMethod = const Value.absent(),
  }) : totalAmount = Value(totalAmount);
  static Insertable<Sale> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<double>? totalAmount,
    Expression<String>? paymentMethod,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (totalAmount != null) 'total_amount': totalAmount,
      if (paymentMethod != null) 'payment_method': paymentMethod,
    });
  }

  SalesCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? date,
    Value<double>? totalAmount,
    Value<String>? paymentMethod,
  }) {
    return SalesCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (totalAmount.present) {
      map['total_amount'] = Variable<double>(totalAmount.value);
    }
    if (paymentMethod.present) {
      map['payment_method'] = Variable<String>(paymentMethod.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SalesCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('totalAmount: $totalAmount, ')
          ..write('paymentMethod: $paymentMethod')
          ..write(')'))
        .toString();
  }
}

class $SaleItemsTable extends SaleItems
    with TableInfo<$SaleItemsTable, SaleItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SaleItemsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _saleIdMeta = const VerificationMeta('saleId');
  @override
  late final GeneratedColumn<int> saleId = GeneratedColumn<int>(
    'sale_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sales (id)',
    ),
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<int> productId = GeneratedColumn<int>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES products (id)',
    ),
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    saleId,
    productId,
    quantity,
    unitPrice,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sale_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<SaleItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SaleItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SaleItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      saleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sale_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}product_id'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      )!,
      unitPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}unit_price'],
      )!,
    );
  }

  @override
  $SaleItemsTable createAlias(String alias) {
    return $SaleItemsTable(attachedDatabase, alias);
  }
}

class SaleItem extends DataClass implements Insertable<SaleItem> {
  final int id;
  final int saleId;
  final int productId;
  final double quantity;
  final double unitPrice;
  const SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['sale_id'] = Variable<int>(saleId);
    map['product_id'] = Variable<int>(productId);
    map['quantity'] = Variable<double>(quantity);
    map['unit_price'] = Variable<double>(unitPrice);
    return map;
  }

  SaleItemsCompanion toCompanion(bool nullToAbsent) {
    return SaleItemsCompanion(
      id: Value(id),
      saleId: Value(saleId),
      productId: Value(productId),
      quantity: Value(quantity),
      unitPrice: Value(unitPrice),
    );
  }

  factory SaleItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SaleItem(
      id: serializer.fromJson<int>(json['id']),
      saleId: serializer.fromJson<int>(json['saleId']),
      productId: serializer.fromJson<int>(json['productId']),
      quantity: serializer.fromJson<double>(json['quantity']),
      unitPrice: serializer.fromJson<double>(json['unitPrice']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'saleId': serializer.toJson<int>(saleId),
      'productId': serializer.toJson<int>(productId),
      'quantity': serializer.toJson<double>(quantity),
      'unitPrice': serializer.toJson<double>(unitPrice),
    };
  }

  SaleItem copyWith({
    int? id,
    int? saleId,
    int? productId,
    double? quantity,
    double? unitPrice,
  }) => SaleItem(
    id: id ?? this.id,
    saleId: saleId ?? this.saleId,
    productId: productId ?? this.productId,
    quantity: quantity ?? this.quantity,
    unitPrice: unitPrice ?? this.unitPrice,
  );
  SaleItem copyWithCompanion(SaleItemsCompanion data) {
    return SaleItem(
      id: data.id.present ? data.id.value : this.id,
      saleId: data.saleId.present ? data.saleId.value : this.saleId,
      productId: data.productId.present ? data.productId.value : this.productId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unitPrice: data.unitPrice.present ? data.unitPrice.value : this.unitPrice,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SaleItem(')
          ..write('id: $id, ')
          ..write('saleId: $saleId, ')
          ..write('productId: $productId, ')
          ..write('quantity: $quantity, ')
          ..write('unitPrice: $unitPrice')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, saleId, productId, quantity, unitPrice);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SaleItem &&
          other.id == this.id &&
          other.saleId == this.saleId &&
          other.productId == this.productId &&
          other.quantity == this.quantity &&
          other.unitPrice == this.unitPrice);
}

class SaleItemsCompanion extends UpdateCompanion<SaleItem> {
  final Value<int> id;
  final Value<int> saleId;
  final Value<int> productId;
  final Value<double> quantity;
  final Value<double> unitPrice;
  const SaleItemsCompanion({
    this.id = const Value.absent(),
    this.saleId = const Value.absent(),
    this.productId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unitPrice = const Value.absent(),
  });
  SaleItemsCompanion.insert({
    this.id = const Value.absent(),
    required int saleId,
    required int productId,
    required double quantity,
    required double unitPrice,
  }) : saleId = Value(saleId),
       productId = Value(productId),
       quantity = Value(quantity),
       unitPrice = Value(unitPrice);
  static Insertable<SaleItem> custom({
    Expression<int>? id,
    Expression<int>? saleId,
    Expression<int>? productId,
    Expression<double>? quantity,
    Expression<double>? unitPrice,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (saleId != null) 'sale_id': saleId,
      if (productId != null) 'product_id': productId,
      if (quantity != null) 'quantity': quantity,
      if (unitPrice != null) 'unit_price': unitPrice,
    });
  }

  SaleItemsCompanion copyWith({
    Value<int>? id,
    Value<int>? saleId,
    Value<int>? productId,
    Value<double>? quantity,
    Value<double>? unitPrice,
  }) {
    return SaleItemsCompanion(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (saleId.present) {
      map['sale_id'] = Variable<int>(saleId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<int>(productId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (unitPrice.present) {
      map['unit_price'] = Variable<double>(unitPrice.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SaleItemsCompanion(')
          ..write('id: $id, ')
          ..write('saleId: $saleId, ')
          ..write('productId: $productId, ')
          ..write('quantity: $quantity, ')
          ..write('unitPrice: $unitPrice')
          ..write(')'))
        .toString();
  }
}

class $InventoryLogsTable extends InventoryLogs
    with TableInfo<$InventoryLogsTable, InventoryLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InventoryLogsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _supplyIdMeta = const VerificationMeta(
    'supplyId',
  );
  @override
  late final GeneratedColumn<int> supplyId = GeneratedColumn<int>(
    'supply_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES supplies (id)',
    ),
  );
  static const VerificationMeta _changeAmountMeta = const VerificationMeta(
    'changeAmount',
  );
  @override
  late final GeneratedColumn<double> changeAmount = GeneratedColumn<double>(
    'change_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    supplyId,
    changeAmount,
    reason,
    date,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inventory_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<InventoryLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('supply_id')) {
      context.handle(
        _supplyIdMeta,
        supplyId.isAcceptableOrUnknown(data['supply_id']!, _supplyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_supplyIdMeta);
    }
    if (data.containsKey('change_amount')) {
      context.handle(
        _changeAmountMeta,
        changeAmount.isAcceptableOrUnknown(
          data['change_amount']!,
          _changeAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_changeAmountMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InventoryLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InventoryLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      supplyId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}supply_id'],
      )!,
      changeAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}change_amount'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
    );
  }

  @override
  $InventoryLogsTable createAlias(String alias) {
    return $InventoryLogsTable(attachedDatabase, alias);
  }
}

class InventoryLog extends DataClass implements Insertable<InventoryLog> {
  final int id;
  final int supplyId;
  final double changeAmount;
  final String reason;
  final DateTime date;
  const InventoryLog({
    required this.id,
    required this.supplyId,
    required this.changeAmount,
    required this.reason,
    required this.date,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['supply_id'] = Variable<int>(supplyId);
    map['change_amount'] = Variable<double>(changeAmount);
    map['reason'] = Variable<String>(reason);
    map['date'] = Variable<DateTime>(date);
    return map;
  }

  InventoryLogsCompanion toCompanion(bool nullToAbsent) {
    return InventoryLogsCompanion(
      id: Value(id),
      supplyId: Value(supplyId),
      changeAmount: Value(changeAmount),
      reason: Value(reason),
      date: Value(date),
    );
  }

  factory InventoryLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InventoryLog(
      id: serializer.fromJson<int>(json['id']),
      supplyId: serializer.fromJson<int>(json['supplyId']),
      changeAmount: serializer.fromJson<double>(json['changeAmount']),
      reason: serializer.fromJson<String>(json['reason']),
      date: serializer.fromJson<DateTime>(json['date']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'supplyId': serializer.toJson<int>(supplyId),
      'changeAmount': serializer.toJson<double>(changeAmount),
      'reason': serializer.toJson<String>(reason),
      'date': serializer.toJson<DateTime>(date),
    };
  }

  InventoryLog copyWith({
    int? id,
    int? supplyId,
    double? changeAmount,
    String? reason,
    DateTime? date,
  }) => InventoryLog(
    id: id ?? this.id,
    supplyId: supplyId ?? this.supplyId,
    changeAmount: changeAmount ?? this.changeAmount,
    reason: reason ?? this.reason,
    date: date ?? this.date,
  );
  InventoryLog copyWithCompanion(InventoryLogsCompanion data) {
    return InventoryLog(
      id: data.id.present ? data.id.value : this.id,
      supplyId: data.supplyId.present ? data.supplyId.value : this.supplyId,
      changeAmount: data.changeAmount.present
          ? data.changeAmount.value
          : this.changeAmount,
      reason: data.reason.present ? data.reason.value : this.reason,
      date: data.date.present ? data.date.value : this.date,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InventoryLog(')
          ..write('id: $id, ')
          ..write('supplyId: $supplyId, ')
          ..write('changeAmount: $changeAmount, ')
          ..write('reason: $reason, ')
          ..write('date: $date')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, supplyId, changeAmount, reason, date);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InventoryLog &&
          other.id == this.id &&
          other.supplyId == this.supplyId &&
          other.changeAmount == this.changeAmount &&
          other.reason == this.reason &&
          other.date == this.date);
}

class InventoryLogsCompanion extends UpdateCompanion<InventoryLog> {
  final Value<int> id;
  final Value<int> supplyId;
  final Value<double> changeAmount;
  final Value<String> reason;
  final Value<DateTime> date;
  const InventoryLogsCompanion({
    this.id = const Value.absent(),
    this.supplyId = const Value.absent(),
    this.changeAmount = const Value.absent(),
    this.reason = const Value.absent(),
    this.date = const Value.absent(),
  });
  InventoryLogsCompanion.insert({
    this.id = const Value.absent(),
    required int supplyId,
    required double changeAmount,
    required String reason,
    this.date = const Value.absent(),
  }) : supplyId = Value(supplyId),
       changeAmount = Value(changeAmount),
       reason = Value(reason);
  static Insertable<InventoryLog> custom({
    Expression<int>? id,
    Expression<int>? supplyId,
    Expression<double>? changeAmount,
    Expression<String>? reason,
    Expression<DateTime>? date,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (supplyId != null) 'supply_id': supplyId,
      if (changeAmount != null) 'change_amount': changeAmount,
      if (reason != null) 'reason': reason,
      if (date != null) 'date': date,
    });
  }

  InventoryLogsCompanion copyWith({
    Value<int>? id,
    Value<int>? supplyId,
    Value<double>? changeAmount,
    Value<String>? reason,
    Value<DateTime>? date,
  }) {
    return InventoryLogsCompanion(
      id: id ?? this.id,
      supplyId: supplyId ?? this.supplyId,
      changeAmount: changeAmount ?? this.changeAmount,
      reason: reason ?? this.reason,
      date: date ?? this.date,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (supplyId.present) {
      map['supply_id'] = Variable<int>(supplyId.value);
    }
    if (changeAmount.present) {
      map['change_amount'] = Variable<double>(changeAmount.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InventoryLogsCompanion(')
          ..write('id: $id, ')
          ..write('supplyId: $supplyId, ')
          ..write('changeAmount: $changeAmount, ')
          ..write('reason: $reason, ')
          ..write('date: $date')
          ..write(')'))
        .toString();
  }
}

class $ModifierGroupsTable extends ModifierGroups
    with TableInfo<$ModifierGroupsTable, ModifierGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ModifierGroupsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minSelectionMeta = const VerificationMeta(
    'minSelection',
  );
  @override
  late final GeneratedColumn<int> minSelection = GeneratedColumn<int>(
    'min_selection',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _maxSelectionMeta = const VerificationMeta(
    'maxSelection',
  );
  @override
  late final GeneratedColumn<int> maxSelection = GeneratedColumn<int>(
    'max_selection',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, minSelection, maxSelection];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'modifier_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<ModifierGroup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('min_selection')) {
      context.handle(
        _minSelectionMeta,
        minSelection.isAcceptableOrUnknown(
          data['min_selection']!,
          _minSelectionMeta,
        ),
      );
    }
    if (data.containsKey('max_selection')) {
      context.handle(
        _maxSelectionMeta,
        maxSelection.isAcceptableOrUnknown(
          data['max_selection']!,
          _maxSelectionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_maxSelectionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ModifierGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ModifierGroup(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      minSelection: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}min_selection'],
      )!,
      maxSelection: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_selection'],
      )!,
    );
  }

  @override
  $ModifierGroupsTable createAlias(String alias) {
    return $ModifierGroupsTable(attachedDatabase, alias);
  }
}

class ModifierGroup extends DataClass implements Insertable<ModifierGroup> {
  final int id;
  final String name;
  final int minSelection;
  final int maxSelection;
  const ModifierGroup({
    required this.id,
    required this.name,
    required this.minSelection,
    required this.maxSelection,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['min_selection'] = Variable<int>(minSelection);
    map['max_selection'] = Variable<int>(maxSelection);
    return map;
  }

  ModifierGroupsCompanion toCompanion(bool nullToAbsent) {
    return ModifierGroupsCompanion(
      id: Value(id),
      name: Value(name),
      minSelection: Value(minSelection),
      maxSelection: Value(maxSelection),
    );
  }

  factory ModifierGroup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ModifierGroup(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      minSelection: serializer.fromJson<int>(json['minSelection']),
      maxSelection: serializer.fromJson<int>(json['maxSelection']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'minSelection': serializer.toJson<int>(minSelection),
      'maxSelection': serializer.toJson<int>(maxSelection),
    };
  }

  ModifierGroup copyWith({
    int? id,
    String? name,
    int? minSelection,
    int? maxSelection,
  }) => ModifierGroup(
    id: id ?? this.id,
    name: name ?? this.name,
    minSelection: minSelection ?? this.minSelection,
    maxSelection: maxSelection ?? this.maxSelection,
  );
  ModifierGroup copyWithCompanion(ModifierGroupsCompanion data) {
    return ModifierGroup(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      minSelection: data.minSelection.present
          ? data.minSelection.value
          : this.minSelection,
      maxSelection: data.maxSelection.present
          ? data.maxSelection.value
          : this.maxSelection,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ModifierGroup(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('minSelection: $minSelection, ')
          ..write('maxSelection: $maxSelection')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, minSelection, maxSelection);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModifierGroup &&
          other.id == this.id &&
          other.name == this.name &&
          other.minSelection == this.minSelection &&
          other.maxSelection == this.maxSelection);
}

class ModifierGroupsCompanion extends UpdateCompanion<ModifierGroup> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> minSelection;
  final Value<int> maxSelection;
  const ModifierGroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.minSelection = const Value.absent(),
    this.maxSelection = const Value.absent(),
  });
  ModifierGroupsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.minSelection = const Value.absent(),
    required int maxSelection,
  }) : name = Value(name),
       maxSelection = Value(maxSelection);
  static Insertable<ModifierGroup> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? minSelection,
    Expression<int>? maxSelection,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (minSelection != null) 'min_selection': minSelection,
      if (maxSelection != null) 'max_selection': maxSelection,
    });
  }

  ModifierGroupsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? minSelection,
    Value<int>? maxSelection,
  }) {
    return ModifierGroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      minSelection: minSelection ?? this.minSelection,
      maxSelection: maxSelection ?? this.maxSelection,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (minSelection.present) {
      map['min_selection'] = Variable<int>(minSelection.value);
    }
    if (maxSelection.present) {
      map['max_selection'] = Variable<int>(maxSelection.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ModifierGroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('minSelection: $minSelection, ')
          ..write('maxSelection: $maxSelection')
          ..write(')'))
        .toString();
  }
}

class $ProductModifiersTable extends ProductModifiers
    with TableInfo<$ProductModifiersTable, ProductModifier> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductModifiersTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<int> productId = GeneratedColumn<int>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES products (id)',
    ),
  );
  static const VerificationMeta _modifierGroupIdMeta = const VerificationMeta(
    'modifierGroupId',
  );
  @override
  late final GeneratedColumn<int> modifierGroupId = GeneratedColumn<int>(
    'modifier_group_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES modifier_groups (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [id, productId, modifierGroupId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'product_modifiers';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProductModifier> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('modifier_group_id')) {
      context.handle(
        _modifierGroupIdMeta,
        modifierGroupId.isAcceptableOrUnknown(
          data['modifier_group_id']!,
          _modifierGroupIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_modifierGroupIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProductModifier map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProductModifier(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}product_id'],
      )!,
      modifierGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}modifier_group_id'],
      )!,
    );
  }

  @override
  $ProductModifiersTable createAlias(String alias) {
    return $ProductModifiersTable(attachedDatabase, alias);
  }
}

class ProductModifier extends DataClass implements Insertable<ProductModifier> {
  final int id;
  final int productId;
  final int modifierGroupId;
  const ProductModifier({
    required this.id,
    required this.productId,
    required this.modifierGroupId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['product_id'] = Variable<int>(productId);
    map['modifier_group_id'] = Variable<int>(modifierGroupId);
    return map;
  }

  ProductModifiersCompanion toCompanion(bool nullToAbsent) {
    return ProductModifiersCompanion(
      id: Value(id),
      productId: Value(productId),
      modifierGroupId: Value(modifierGroupId),
    );
  }

  factory ProductModifier.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProductModifier(
      id: serializer.fromJson<int>(json['id']),
      productId: serializer.fromJson<int>(json['productId']),
      modifierGroupId: serializer.fromJson<int>(json['modifierGroupId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'productId': serializer.toJson<int>(productId),
      'modifierGroupId': serializer.toJson<int>(modifierGroupId),
    };
  }

  ProductModifier copyWith({int? id, int? productId, int? modifierGroupId}) =>
      ProductModifier(
        id: id ?? this.id,
        productId: productId ?? this.productId,
        modifierGroupId: modifierGroupId ?? this.modifierGroupId,
      );
  ProductModifier copyWithCompanion(ProductModifiersCompanion data) {
    return ProductModifier(
      id: data.id.present ? data.id.value : this.id,
      productId: data.productId.present ? data.productId.value : this.productId,
      modifierGroupId: data.modifierGroupId.present
          ? data.modifierGroupId.value
          : this.modifierGroupId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProductModifier(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('modifierGroupId: $modifierGroupId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, productId, modifierGroupId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductModifier &&
          other.id == this.id &&
          other.productId == this.productId &&
          other.modifierGroupId == this.modifierGroupId);
}

class ProductModifiersCompanion extends UpdateCompanion<ProductModifier> {
  final Value<int> id;
  final Value<int> productId;
  final Value<int> modifierGroupId;
  const ProductModifiersCompanion({
    this.id = const Value.absent(),
    this.productId = const Value.absent(),
    this.modifierGroupId = const Value.absent(),
  });
  ProductModifiersCompanion.insert({
    this.id = const Value.absent(),
    required int productId,
    required int modifierGroupId,
  }) : productId = Value(productId),
       modifierGroupId = Value(modifierGroupId);
  static Insertable<ProductModifier> custom({
    Expression<int>? id,
    Expression<int>? productId,
    Expression<int>? modifierGroupId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (productId != null) 'product_id': productId,
      if (modifierGroupId != null) 'modifier_group_id': modifierGroupId,
    });
  }

  ProductModifiersCompanion copyWith({
    Value<int>? id,
    Value<int>? productId,
    Value<int>? modifierGroupId,
  }) {
    return ProductModifiersCompanion(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      modifierGroupId: modifierGroupId ?? this.modifierGroupId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<int>(productId.value);
    }
    if (modifierGroupId.present) {
      map['modifier_group_id'] = Variable<int>(modifierGroupId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductModifiersCompanion(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('modifierGroupId: $modifierGroupId')
          ..write(')'))
        .toString();
  }
}

class $ModifierOptionsTable extends ModifierOptions
    with TableInfo<$ModifierOptionsTable, ModifierOption> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ModifierOptionsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _modifierGroupIdMeta = const VerificationMeta(
    'modifierGroupId',
  );
  @override
  late final GeneratedColumn<int> modifierGroupId = GeneratedColumn<int>(
    'modifier_group_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES modifier_groups (id)',
    ),
  );
  static const VerificationMeta _supplyIdMeta = const VerificationMeta(
    'supplyId',
  );
  @override
  late final GeneratedColumn<int> supplyId = GeneratedColumn<int>(
    'supply_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES supplies (id)',
    ),
  );
  static const VerificationMeta _quantityDeductedMeta = const VerificationMeta(
    'quantityDeducted',
  );
  @override
  late final GeneratedColumn<double> quantityDeducted = GeneratedColumn<double>(
    'quantity_deducted',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceExtraMeta = const VerificationMeta(
    'priceExtra',
  );
  @override
  late final GeneratedColumn<double> priceExtra = GeneratedColumn<double>(
    'price_extra',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    modifierGroupId,
    supplyId,
    quantityDeducted,
    priceExtra,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'modifier_options';
  @override
  VerificationContext validateIntegrity(
    Insertable<ModifierOption> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('modifier_group_id')) {
      context.handle(
        _modifierGroupIdMeta,
        modifierGroupId.isAcceptableOrUnknown(
          data['modifier_group_id']!,
          _modifierGroupIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_modifierGroupIdMeta);
    }
    if (data.containsKey('supply_id')) {
      context.handle(
        _supplyIdMeta,
        supplyId.isAcceptableOrUnknown(data['supply_id']!, _supplyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_supplyIdMeta);
    }
    if (data.containsKey('quantity_deducted')) {
      context.handle(
        _quantityDeductedMeta,
        quantityDeducted.isAcceptableOrUnknown(
          data['quantity_deducted']!,
          _quantityDeductedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_quantityDeductedMeta);
    }
    if (data.containsKey('price_extra')) {
      context.handle(
        _priceExtraMeta,
        priceExtra.isAcceptableOrUnknown(data['price_extra']!, _priceExtraMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ModifierOption map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ModifierOption(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      modifierGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}modifier_group_id'],
      )!,
      supplyId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}supply_id'],
      )!,
      quantityDeducted: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity_deducted'],
      )!,
      priceExtra: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}price_extra'],
      )!,
    );
  }

  @override
  $ModifierOptionsTable createAlias(String alias) {
    return $ModifierOptionsTable(attachedDatabase, alias);
  }
}

class ModifierOption extends DataClass implements Insertable<ModifierOption> {
  final int id;
  final int modifierGroupId;
  final int supplyId;
  final double quantityDeducted;
  final double priceExtra;
  const ModifierOption({
    required this.id,
    required this.modifierGroupId,
    required this.supplyId,
    required this.quantityDeducted,
    required this.priceExtra,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['modifier_group_id'] = Variable<int>(modifierGroupId);
    map['supply_id'] = Variable<int>(supplyId);
    map['quantity_deducted'] = Variable<double>(quantityDeducted);
    map['price_extra'] = Variable<double>(priceExtra);
    return map;
  }

  ModifierOptionsCompanion toCompanion(bool nullToAbsent) {
    return ModifierOptionsCompanion(
      id: Value(id),
      modifierGroupId: Value(modifierGroupId),
      supplyId: Value(supplyId),
      quantityDeducted: Value(quantityDeducted),
      priceExtra: Value(priceExtra),
    );
  }

  factory ModifierOption.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ModifierOption(
      id: serializer.fromJson<int>(json['id']),
      modifierGroupId: serializer.fromJson<int>(json['modifierGroupId']),
      supplyId: serializer.fromJson<int>(json['supplyId']),
      quantityDeducted: serializer.fromJson<double>(json['quantityDeducted']),
      priceExtra: serializer.fromJson<double>(json['priceExtra']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'modifierGroupId': serializer.toJson<int>(modifierGroupId),
      'supplyId': serializer.toJson<int>(supplyId),
      'quantityDeducted': serializer.toJson<double>(quantityDeducted),
      'priceExtra': serializer.toJson<double>(priceExtra),
    };
  }

  ModifierOption copyWith({
    int? id,
    int? modifierGroupId,
    int? supplyId,
    double? quantityDeducted,
    double? priceExtra,
  }) => ModifierOption(
    id: id ?? this.id,
    modifierGroupId: modifierGroupId ?? this.modifierGroupId,
    supplyId: supplyId ?? this.supplyId,
    quantityDeducted: quantityDeducted ?? this.quantityDeducted,
    priceExtra: priceExtra ?? this.priceExtra,
  );
  ModifierOption copyWithCompanion(ModifierOptionsCompanion data) {
    return ModifierOption(
      id: data.id.present ? data.id.value : this.id,
      modifierGroupId: data.modifierGroupId.present
          ? data.modifierGroupId.value
          : this.modifierGroupId,
      supplyId: data.supplyId.present ? data.supplyId.value : this.supplyId,
      quantityDeducted: data.quantityDeducted.present
          ? data.quantityDeducted.value
          : this.quantityDeducted,
      priceExtra: data.priceExtra.present
          ? data.priceExtra.value
          : this.priceExtra,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ModifierOption(')
          ..write('id: $id, ')
          ..write('modifierGroupId: $modifierGroupId, ')
          ..write('supplyId: $supplyId, ')
          ..write('quantityDeducted: $quantityDeducted, ')
          ..write('priceExtra: $priceExtra')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, modifierGroupId, supplyId, quantityDeducted, priceExtra);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModifierOption &&
          other.id == this.id &&
          other.modifierGroupId == this.modifierGroupId &&
          other.supplyId == this.supplyId &&
          other.quantityDeducted == this.quantityDeducted &&
          other.priceExtra == this.priceExtra);
}

class ModifierOptionsCompanion extends UpdateCompanion<ModifierOption> {
  final Value<int> id;
  final Value<int> modifierGroupId;
  final Value<int> supplyId;
  final Value<double> quantityDeducted;
  final Value<double> priceExtra;
  const ModifierOptionsCompanion({
    this.id = const Value.absent(),
    this.modifierGroupId = const Value.absent(),
    this.supplyId = const Value.absent(),
    this.quantityDeducted = const Value.absent(),
    this.priceExtra = const Value.absent(),
  });
  ModifierOptionsCompanion.insert({
    this.id = const Value.absent(),
    required int modifierGroupId,
    required int supplyId,
    required double quantityDeducted,
    this.priceExtra = const Value.absent(),
  }) : modifierGroupId = Value(modifierGroupId),
       supplyId = Value(supplyId),
       quantityDeducted = Value(quantityDeducted);
  static Insertable<ModifierOption> custom({
    Expression<int>? id,
    Expression<int>? modifierGroupId,
    Expression<int>? supplyId,
    Expression<double>? quantityDeducted,
    Expression<double>? priceExtra,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (modifierGroupId != null) 'modifier_group_id': modifierGroupId,
      if (supplyId != null) 'supply_id': supplyId,
      if (quantityDeducted != null) 'quantity_deducted': quantityDeducted,
      if (priceExtra != null) 'price_extra': priceExtra,
    });
  }

  ModifierOptionsCompanion copyWith({
    Value<int>? id,
    Value<int>? modifierGroupId,
    Value<int>? supplyId,
    Value<double>? quantityDeducted,
    Value<double>? priceExtra,
  }) {
    return ModifierOptionsCompanion(
      id: id ?? this.id,
      modifierGroupId: modifierGroupId ?? this.modifierGroupId,
      supplyId: supplyId ?? this.supplyId,
      quantityDeducted: quantityDeducted ?? this.quantityDeducted,
      priceExtra: priceExtra ?? this.priceExtra,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (modifierGroupId.present) {
      map['modifier_group_id'] = Variable<int>(modifierGroupId.value);
    }
    if (supplyId.present) {
      map['supply_id'] = Variable<int>(supplyId.value);
    }
    if (quantityDeducted.present) {
      map['quantity_deducted'] = Variable<double>(quantityDeducted.value);
    }
    if (priceExtra.present) {
      map['price_extra'] = Variable<double>(priceExtra.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ModifierOptionsCompanion(')
          ..write('id: $id, ')
          ..write('modifierGroupId: $modifierGroupId, ')
          ..write('supplyId: $supplyId, ')
          ..write('quantityDeducted: $quantityDeducted, ')
          ..write('priceExtra: $priceExtra')
          ..write(')'))
        .toString();
  }
}

class $ParkedOrdersTable extends ParkedOrders
    with TableInfo<$ParkedOrdersTable, ParkedOrder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ParkedOrdersTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _itemsJsonMeta = const VerificationMeta(
    'itemsJson',
  );
  @override
  late final GeneratedColumn<String> itemsJson = GeneratedColumn<String>(
    'items_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parkedAtMeta = const VerificationMeta(
    'parkedAt',
  );
  @override
  late final GeneratedColumn<DateTime> parkedAt = GeneratedColumn<DateTime>(
    'parked_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _totalAmountMeta = const VerificationMeta(
    'totalAmount',
  );
  @override
  late final GeneratedColumn<double> totalAmount = GeneratedColumn<double>(
    'total_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    customerName,
    itemsJson,
    parkedAt,
    totalAmount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'parked_orders';
  @override
  VerificationContext validateIntegrity(
    Insertable<ParkedOrder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
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
    if (data.containsKey('items_json')) {
      context.handle(
        _itemsJsonMeta,
        itemsJson.isAcceptableOrUnknown(data['items_json']!, _itemsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_itemsJsonMeta);
    }
    if (data.containsKey('parked_at')) {
      context.handle(
        _parkedAtMeta,
        parkedAt.isAcceptableOrUnknown(data['parked_at']!, _parkedAtMeta),
      );
    }
    if (data.containsKey('total_amount')) {
      context.handle(
        _totalAmountMeta,
        totalAmount.isAcceptableOrUnknown(
          data['total_amount']!,
          _totalAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalAmountMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ParkedOrder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ParkedOrder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      customerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_name'],
      ),
      itemsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}items_json'],
      )!,
      parkedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}parked_at'],
      )!,
      totalAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_amount'],
      )!,
    );
  }

  @override
  $ParkedOrdersTable createAlias(String alias) {
    return $ParkedOrdersTable(attachedDatabase, alias);
  }
}

class ParkedOrder extends DataClass implements Insertable<ParkedOrder> {
  final int id;
  final String? customerName;
  final String itemsJson;
  final DateTime parkedAt;
  final double totalAmount;
  const ParkedOrder({
    required this.id,
    this.customerName,
    required this.itemsJson,
    required this.parkedAt,
    required this.totalAmount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || customerName != null) {
      map['customer_name'] = Variable<String>(customerName);
    }
    map['items_json'] = Variable<String>(itemsJson);
    map['parked_at'] = Variable<DateTime>(parkedAt);
    map['total_amount'] = Variable<double>(totalAmount);
    return map;
  }

  ParkedOrdersCompanion toCompanion(bool nullToAbsent) {
    return ParkedOrdersCompanion(
      id: Value(id),
      customerName: customerName == null && nullToAbsent
          ? const Value.absent()
          : Value(customerName),
      itemsJson: Value(itemsJson),
      parkedAt: Value(parkedAt),
      totalAmount: Value(totalAmount),
    );
  }

  factory ParkedOrder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ParkedOrder(
      id: serializer.fromJson<int>(json['id']),
      customerName: serializer.fromJson<String?>(json['customerName']),
      itemsJson: serializer.fromJson<String>(json['itemsJson']),
      parkedAt: serializer.fromJson<DateTime>(json['parkedAt']),
      totalAmount: serializer.fromJson<double>(json['totalAmount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'customerName': serializer.toJson<String?>(customerName),
      'itemsJson': serializer.toJson<String>(itemsJson),
      'parkedAt': serializer.toJson<DateTime>(parkedAt),
      'totalAmount': serializer.toJson<double>(totalAmount),
    };
  }

  ParkedOrder copyWith({
    int? id,
    Value<String?> customerName = const Value.absent(),
    String? itemsJson,
    DateTime? parkedAt,
    double? totalAmount,
  }) => ParkedOrder(
    id: id ?? this.id,
    customerName: customerName.present ? customerName.value : this.customerName,
    itemsJson: itemsJson ?? this.itemsJson,
    parkedAt: parkedAt ?? this.parkedAt,
    totalAmount: totalAmount ?? this.totalAmount,
  );
  ParkedOrder copyWithCompanion(ParkedOrdersCompanion data) {
    return ParkedOrder(
      id: data.id.present ? data.id.value : this.id,
      customerName: data.customerName.present
          ? data.customerName.value
          : this.customerName,
      itemsJson: data.itemsJson.present ? data.itemsJson.value : this.itemsJson,
      parkedAt: data.parkedAt.present ? data.parkedAt.value : this.parkedAt,
      totalAmount: data.totalAmount.present
          ? data.totalAmount.value
          : this.totalAmount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ParkedOrder(')
          ..write('id: $id, ')
          ..write('customerName: $customerName, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('parkedAt: $parkedAt, ')
          ..write('totalAmount: $totalAmount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, customerName, itemsJson, parkedAt, totalAmount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ParkedOrder &&
          other.id == this.id &&
          other.customerName == this.customerName &&
          other.itemsJson == this.itemsJson &&
          other.parkedAt == this.parkedAt &&
          other.totalAmount == this.totalAmount);
}

class ParkedOrdersCompanion extends UpdateCompanion<ParkedOrder> {
  final Value<int> id;
  final Value<String?> customerName;
  final Value<String> itemsJson;
  final Value<DateTime> parkedAt;
  final Value<double> totalAmount;
  const ParkedOrdersCompanion({
    this.id = const Value.absent(),
    this.customerName = const Value.absent(),
    this.itemsJson = const Value.absent(),
    this.parkedAt = const Value.absent(),
    this.totalAmount = const Value.absent(),
  });
  ParkedOrdersCompanion.insert({
    this.id = const Value.absent(),
    this.customerName = const Value.absent(),
    required String itemsJson,
    this.parkedAt = const Value.absent(),
    required double totalAmount,
  }) : itemsJson = Value(itemsJson),
       totalAmount = Value(totalAmount);
  static Insertable<ParkedOrder> custom({
    Expression<int>? id,
    Expression<String>? customerName,
    Expression<String>? itemsJson,
    Expression<DateTime>? parkedAt,
    Expression<double>? totalAmount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (customerName != null) 'customer_name': customerName,
      if (itemsJson != null) 'items_json': itemsJson,
      if (parkedAt != null) 'parked_at': parkedAt,
      if (totalAmount != null) 'total_amount': totalAmount,
    });
  }

  ParkedOrdersCompanion copyWith({
    Value<int>? id,
    Value<String?>? customerName,
    Value<String>? itemsJson,
    Value<DateTime>? parkedAt,
    Value<double>? totalAmount,
  }) {
    return ParkedOrdersCompanion(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      itemsJson: itemsJson ?? this.itemsJson,
      parkedAt: parkedAt ?? this.parkedAt,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (customerName.present) {
      map['customer_name'] = Variable<String>(customerName.value);
    }
    if (itemsJson.present) {
      map['items_json'] = Variable<String>(itemsJson.value);
    }
    if (parkedAt.present) {
      map['parked_at'] = Variable<DateTime>(parkedAt.value);
    }
    if (totalAmount.present) {
      map['total_amount'] = Variable<double>(totalAmount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ParkedOrdersCompanion(')
          ..write('id: $id, ')
          ..write('customerName: $customerName, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('parkedAt: $parkedAt, ')
          ..write('totalAmount: $totalAmount')
          ..write(')'))
        .toString();
  }
}

class $DiscountsTable extends Discounts
    with TableInfo<$DiscountsTable, Discount> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiscountsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _percentageMeta = const VerificationMeta(
    'percentage',
  );
  @override
  late final GeneratedColumn<double> percentage = GeneratedColumn<double>(
    'percentage',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    code,
    percentage,
    description,
    isActive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'discounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Discount> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('percentage')) {
      context.handle(
        _percentageMeta,
        percentage.isAcceptableOrUnknown(data['percentage']!, _percentageMeta),
      );
    } else if (isInserting) {
      context.missing(_percentageMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Discount map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Discount(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      percentage: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}percentage'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  $DiscountsTable createAlias(String alias) {
    return $DiscountsTable(attachedDatabase, alias);
  }
}

class Discount extends DataClass implements Insertable<Discount> {
  final int id;
  final String code;
  final double percentage;
  final String description;
  final bool isActive;
  const Discount({
    required this.id,
    required this.code,
    required this.percentage,
    required this.description,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['code'] = Variable<String>(code);
    map['percentage'] = Variable<double>(percentage);
    map['description'] = Variable<String>(description);
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  DiscountsCompanion toCompanion(bool nullToAbsent) {
    return DiscountsCompanion(
      id: Value(id),
      code: Value(code),
      percentage: Value(percentage),
      description: Value(description),
      isActive: Value(isActive),
    );
  }

  factory Discount.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Discount(
      id: serializer.fromJson<int>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      percentage: serializer.fromJson<double>(json['percentage']),
      description: serializer.fromJson<String>(json['description']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'code': serializer.toJson<String>(code),
      'percentage': serializer.toJson<double>(percentage),
      'description': serializer.toJson<String>(description),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  Discount copyWith({
    int? id,
    String? code,
    double? percentage,
    String? description,
    bool? isActive,
  }) => Discount(
    id: id ?? this.id,
    code: code ?? this.code,
    percentage: percentage ?? this.percentage,
    description: description ?? this.description,
    isActive: isActive ?? this.isActive,
  );
  Discount copyWithCompanion(DiscountsCompanion data) {
    return Discount(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      percentage: data.percentage.present
          ? data.percentage.value
          : this.percentage,
      description: data.description.present
          ? data.description.value
          : this.description,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Discount(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('percentage: $percentage, ')
          ..write('description: $description, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, code, percentage, description, isActive);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Discount &&
          other.id == this.id &&
          other.code == this.code &&
          other.percentage == this.percentage &&
          other.description == this.description &&
          other.isActive == this.isActive);
}

class DiscountsCompanion extends UpdateCompanion<Discount> {
  final Value<int> id;
  final Value<String> code;
  final Value<double> percentage;
  final Value<String> description;
  final Value<bool> isActive;
  const DiscountsCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.percentage = const Value.absent(),
    this.description = const Value.absent(),
    this.isActive = const Value.absent(),
  });
  DiscountsCompanion.insert({
    this.id = const Value.absent(),
    required String code,
    required double percentage,
    required String description,
    this.isActive = const Value.absent(),
  }) : code = Value(code),
       percentage = Value(percentage),
       description = Value(description);
  static Insertable<Discount> custom({
    Expression<int>? id,
    Expression<String>? code,
    Expression<double>? percentage,
    Expression<String>? description,
    Expression<bool>? isActive,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (percentage != null) 'percentage': percentage,
      if (description != null) 'description': description,
      if (isActive != null) 'is_active': isActive,
    });
  }

  DiscountsCompanion copyWith({
    Value<int>? id,
    Value<String>? code,
    Value<double>? percentage,
    Value<String>? description,
    Value<bool>? isActive,
  }) {
    return DiscountsCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      percentage: percentage ?? this.percentage,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (percentage.present) {
      map['percentage'] = Variable<double>(percentage.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiscountsCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('percentage: $percentage, ')
          ..write('description: $description, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }
}

class $BundlesTable extends Bundles with TableInfo<$BundlesTable, Bundle> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BundlesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<double> price = GeneratedColumn<double>(
    'price',
    aliasedName,
    false,
    type: DriftSqlType.double,
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
  @override
  List<GeneratedColumn> get $columns => [id, name, price, isActive];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bundles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Bundle> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    } else if (isInserting) {
      context.missing(_priceMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Bundle map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Bundle(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}price'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  $BundlesTable createAlias(String alias) {
    return $BundlesTable(attachedDatabase, alias);
  }
}

class Bundle extends DataClass implements Insertable<Bundle> {
  final int id;
  final String name;
  final double price;
  final bool isActive;
  const Bundle({
    required this.id,
    required this.name,
    required this.price,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['price'] = Variable<double>(price);
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  BundlesCompanion toCompanion(bool nullToAbsent) {
    return BundlesCompanion(
      id: Value(id),
      name: Value(name),
      price: Value(price),
      isActive: Value(isActive),
    );
  }

  factory Bundle.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Bundle(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      price: serializer.fromJson<double>(json['price']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'price': serializer.toJson<double>(price),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  Bundle copyWith({int? id, String? name, double? price, bool? isActive}) =>
      Bundle(
        id: id ?? this.id,
        name: name ?? this.name,
        price: price ?? this.price,
        isActive: isActive ?? this.isActive,
      );
  Bundle copyWithCompanion(BundlesCompanion data) {
    return Bundle(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      price: data.price.present ? data.price.value : this.price,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Bundle(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('price: $price, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, price, isActive);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bundle &&
          other.id == this.id &&
          other.name == this.name &&
          other.price == this.price &&
          other.isActive == this.isActive);
}

class BundlesCompanion extends UpdateCompanion<Bundle> {
  final Value<int> id;
  final Value<String> name;
  final Value<double> price;
  final Value<bool> isActive;
  const BundlesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.price = const Value.absent(),
    this.isActive = const Value.absent(),
  });
  BundlesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required double price,
    this.isActive = const Value.absent(),
  }) : name = Value(name),
       price = Value(price);
  static Insertable<Bundle> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<double>? price,
    Expression<bool>? isActive,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (price != null) 'price': price,
      if (isActive != null) 'is_active': isActive,
    });
  }

  BundlesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<double>? price,
    Value<bool>? isActive,
  }) {
    return BundlesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (price.present) {
      map['price'] = Variable<double>(price.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BundlesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('price: $price, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }
}

class $BundleItemsTable extends BundleItems
    with TableInfo<$BundleItemsTable, BundleItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BundleItemsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _bundleIdMeta = const VerificationMeta(
    'bundleId',
  );
  @override
  late final GeneratedColumn<int> bundleId = GeneratedColumn<int>(
    'bundle_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES bundles (id)',
    ),
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<int> productId = GeneratedColumn<int>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES products (id)',
    ),
  );
  static const VerificationMeta _quantityRequiredMeta = const VerificationMeta(
    'quantityRequired',
  );
  @override
  late final GeneratedColumn<double> quantityRequired = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bundleId,
    productId,
    quantityRequired,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bundle_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<BundleItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('bundle_id')) {
      context.handle(
        _bundleIdMeta,
        bundleId.isAcceptableOrUnknown(data['bundle_id']!, _bundleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bundleIdMeta);
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
        _quantityRequiredMeta,
        quantityRequired.isAcceptableOrUnknown(
          data['quantity']!,
          _quantityRequiredMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BundleItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BundleItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bundleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bundle_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}product_id'],
      )!,
      quantityRequired: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      )!,
    );
  }

  @override
  $BundleItemsTable createAlias(String alias) {
    return $BundleItemsTable(attachedDatabase, alias);
  }
}

class BundleItem extends DataClass implements Insertable<BundleItem> {
  final int id;
  final int bundleId;
  final int productId;
  final double quantityRequired;
  const BundleItem({
    required this.id,
    required this.bundleId,
    required this.productId,
    required this.quantityRequired,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['bundle_id'] = Variable<int>(bundleId);
    map['product_id'] = Variable<int>(productId);
    map['quantity'] = Variable<double>(quantityRequired);
    return map;
  }

  BundleItemsCompanion toCompanion(bool nullToAbsent) {
    return BundleItemsCompanion(
      id: Value(id),
      bundleId: Value(bundleId),
      productId: Value(productId),
      quantityRequired: Value(quantityRequired),
    );
  }

  factory BundleItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BundleItem(
      id: serializer.fromJson<int>(json['id']),
      bundleId: serializer.fromJson<int>(json['bundleId']),
      productId: serializer.fromJson<int>(json['productId']),
      quantityRequired: serializer.fromJson<double>(json['quantityRequired']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bundleId': serializer.toJson<int>(bundleId),
      'productId': serializer.toJson<int>(productId),
      'quantityRequired': serializer.toJson<double>(quantityRequired),
    };
  }

  BundleItem copyWith({
    int? id,
    int? bundleId,
    int? productId,
    double? quantityRequired,
  }) => BundleItem(
    id: id ?? this.id,
    bundleId: bundleId ?? this.bundleId,
    productId: productId ?? this.productId,
    quantityRequired: quantityRequired ?? this.quantityRequired,
  );
  BundleItem copyWithCompanion(BundleItemsCompanion data) {
    return BundleItem(
      id: data.id.present ? data.id.value : this.id,
      bundleId: data.bundleId.present ? data.bundleId.value : this.bundleId,
      productId: data.productId.present ? data.productId.value : this.productId,
      quantityRequired: data.quantityRequired.present
          ? data.quantityRequired.value
          : this.quantityRequired,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BundleItem(')
          ..write('id: $id, ')
          ..write('bundleId: $bundleId, ')
          ..write('productId: $productId, ')
          ..write('quantityRequired: $quantityRequired')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, bundleId, productId, quantityRequired);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BundleItem &&
          other.id == this.id &&
          other.bundleId == this.bundleId &&
          other.productId == this.productId &&
          other.quantityRequired == this.quantityRequired);
}

class BundleItemsCompanion extends UpdateCompanion<BundleItem> {
  final Value<int> id;
  final Value<int> bundleId;
  final Value<int> productId;
  final Value<double> quantityRequired;
  const BundleItemsCompanion({
    this.id = const Value.absent(),
    this.bundleId = const Value.absent(),
    this.productId = const Value.absent(),
    this.quantityRequired = const Value.absent(),
  });
  BundleItemsCompanion.insert({
    this.id = const Value.absent(),
    required int bundleId,
    required int productId,
    this.quantityRequired = const Value.absent(),
  }) : bundleId = Value(bundleId),
       productId = Value(productId);
  static Insertable<BundleItem> custom({
    Expression<int>? id,
    Expression<int>? bundleId,
    Expression<int>? productId,
    Expression<double>? quantityRequired,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bundleId != null) 'bundle_id': bundleId,
      if (productId != null) 'product_id': productId,
      if (quantityRequired != null) 'quantity': quantityRequired,
    });
  }

  BundleItemsCompanion copyWith({
    Value<int>? id,
    Value<int>? bundleId,
    Value<int>? productId,
    Value<double>? quantityRequired,
  }) {
    return BundleItemsCompanion(
      id: id ?? this.id,
      bundleId: bundleId ?? this.bundleId,
      productId: productId ?? this.productId,
      quantityRequired: quantityRequired ?? this.quantityRequired,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bundleId.present) {
      map['bundle_id'] = Variable<int>(bundleId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<int>(productId.value);
    }
    if (quantityRequired.present) {
      map['quantity'] = Variable<double>(quantityRequired.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BundleItemsCompanion(')
          ..write('id: $id, ')
          ..write('bundleId: $bundleId, ')
          ..write('productId: $productId, ')
          ..write('quantityRequired: $quantityRequired')
          ..write(')'))
        .toString();
  }
}

class $ShiftsTable extends Shifts with TableInfo<$ShiftsTable, Shift> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShiftsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<DateTime> startTime = GeneratedColumn<DateTime>(
    'start_time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _endTimeMeta = const VerificationMeta(
    'endTime',
  );
  @override
  late final GeneratedColumn<DateTime> endTime = GeneratedColumn<DateTime>(
    'end_time',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startingFundMeta = const VerificationMeta(
    'startingFund',
  );
  @override
  late final GeneratedColumn<double> startingFund = GeneratedColumn<double>(
    'starting_fund',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, startTime, endTime, startingFund];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shifts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Shift> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('start_time')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta),
      );
    }
    if (data.containsKey('end_time')) {
      context.handle(
        _endTimeMeta,
        endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta),
      );
    }
    if (data.containsKey('starting_fund')) {
      context.handle(
        _startingFundMeta,
        startingFund.isAcceptableOrUnknown(
          data['starting_fund']!,
          _startingFundMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Shift map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Shift(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_time'],
      )!,
      endTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_time'],
      ),
      startingFund: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}starting_fund'],
      )!,
    );
  }

  @override
  $ShiftsTable createAlias(String alias) {
    return $ShiftsTable(attachedDatabase, alias);
  }
}

class Shift extends DataClass implements Insertable<Shift> {
  final int id;
  final DateTime startTime;
  final DateTime? endTime;
  final double startingFund;
  const Shift({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.startingFund,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['start_time'] = Variable<DateTime>(startTime);
    if (!nullToAbsent || endTime != null) {
      map['end_time'] = Variable<DateTime>(endTime);
    }
    map['starting_fund'] = Variable<double>(startingFund);
    return map;
  }

  ShiftsCompanion toCompanion(bool nullToAbsent) {
    return ShiftsCompanion(
      id: Value(id),
      startTime: Value(startTime),
      endTime: endTime == null && nullToAbsent
          ? const Value.absent()
          : Value(endTime),
      startingFund: Value(startingFund),
    );
  }

  factory Shift.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Shift(
      id: serializer.fromJson<int>(json['id']),
      startTime: serializer.fromJson<DateTime>(json['startTime']),
      endTime: serializer.fromJson<DateTime?>(json['endTime']),
      startingFund: serializer.fromJson<double>(json['startingFund']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'startTime': serializer.toJson<DateTime>(startTime),
      'endTime': serializer.toJson<DateTime?>(endTime),
      'startingFund': serializer.toJson<double>(startingFund),
    };
  }

  Shift copyWith({
    int? id,
    DateTime? startTime,
    Value<DateTime?> endTime = const Value.absent(),
    double? startingFund,
  }) => Shift(
    id: id ?? this.id,
    startTime: startTime ?? this.startTime,
    endTime: endTime.present ? endTime.value : this.endTime,
    startingFund: startingFund ?? this.startingFund,
  );
  Shift copyWithCompanion(ShiftsCompanion data) {
    return Shift(
      id: data.id.present ? data.id.value : this.id,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      startingFund: data.startingFund.present
          ? data.startingFund.value
          : this.startingFund,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Shift(')
          ..write('id: $id, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('startingFund: $startingFund')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, startTime, endTime, startingFund);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Shift &&
          other.id == this.id &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.startingFund == this.startingFund);
}

class ShiftsCompanion extends UpdateCompanion<Shift> {
  final Value<int> id;
  final Value<DateTime> startTime;
  final Value<DateTime?> endTime;
  final Value<double> startingFund;
  const ShiftsCompanion({
    this.id = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.startingFund = const Value.absent(),
  });
  ShiftsCompanion.insert({
    this.id = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.startingFund = const Value.absent(),
  });
  static Insertable<Shift> custom({
    Expression<int>? id,
    Expression<DateTime>? startTime,
    Expression<DateTime>? endTime,
    Expression<double>? startingFund,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (startingFund != null) 'starting_fund': startingFund,
    });
  }

  ShiftsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? startTime,
    Value<DateTime?>? endTime,
    Value<double>? startingFund,
  }) {
    return ShiftsCompanion(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      startingFund: startingFund ?? this.startingFund,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<DateTime>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<DateTime>(endTime.value);
    }
    if (startingFund.present) {
      map['starting_fund'] = Variable<double>(startingFund.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShiftsCompanion(')
          ..write('id: $id, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('startingFund: $startingFund')
          ..write(')'))
        .toString();
  }
}

class $CashMovementsTable extends CashMovements
    with TableInfo<$CashMovementsTable, CashMovement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CashMovementsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _shiftIdMeta = const VerificationMeta(
    'shiftId',
  );
  @override
  late final GeneratedColumn<int> shiftId = GeneratedColumn<int>(
    'shift_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES shifts (id)',
    ),
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, shiftId, amount, reason, date];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cash_movements';
  @override
  VerificationContext validateIntegrity(
    Insertable<CashMovement> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('shift_id')) {
      context.handle(
        _shiftIdMeta,
        shiftId.isAcceptableOrUnknown(data['shift_id']!, _shiftIdMeta),
      );
    } else if (isInserting) {
      context.missing(_shiftIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CashMovement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CashMovement(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      shiftId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}shift_id'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
    );
  }

  @override
  $CashMovementsTable createAlias(String alias) {
    return $CashMovementsTable(attachedDatabase, alias);
  }
}

class CashMovement extends DataClass implements Insertable<CashMovement> {
  final int id;
  final int shiftId;
  final double amount;
  final String reason;
  final DateTime date;
  const CashMovement({
    required this.id,
    required this.shiftId,
    required this.amount,
    required this.reason,
    required this.date,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['shift_id'] = Variable<int>(shiftId);
    map['amount'] = Variable<double>(amount);
    map['reason'] = Variable<String>(reason);
    map['date'] = Variable<DateTime>(date);
    return map;
  }

  CashMovementsCompanion toCompanion(bool nullToAbsent) {
    return CashMovementsCompanion(
      id: Value(id),
      shiftId: Value(shiftId),
      amount: Value(amount),
      reason: Value(reason),
      date: Value(date),
    );
  }

  factory CashMovement.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CashMovement(
      id: serializer.fromJson<int>(json['id']),
      shiftId: serializer.fromJson<int>(json['shiftId']),
      amount: serializer.fromJson<double>(json['amount']),
      reason: serializer.fromJson<String>(json['reason']),
      date: serializer.fromJson<DateTime>(json['date']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'shiftId': serializer.toJson<int>(shiftId),
      'amount': serializer.toJson<double>(amount),
      'reason': serializer.toJson<String>(reason),
      'date': serializer.toJson<DateTime>(date),
    };
  }

  CashMovement copyWith({
    int? id,
    int? shiftId,
    double? amount,
    String? reason,
    DateTime? date,
  }) => CashMovement(
    id: id ?? this.id,
    shiftId: shiftId ?? this.shiftId,
    amount: amount ?? this.amount,
    reason: reason ?? this.reason,
    date: date ?? this.date,
  );
  CashMovement copyWithCompanion(CashMovementsCompanion data) {
    return CashMovement(
      id: data.id.present ? data.id.value : this.id,
      shiftId: data.shiftId.present ? data.shiftId.value : this.shiftId,
      amount: data.amount.present ? data.amount.value : this.amount,
      reason: data.reason.present ? data.reason.value : this.reason,
      date: data.date.present ? data.date.value : this.date,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CashMovement(')
          ..write('id: $id, ')
          ..write('shiftId: $shiftId, ')
          ..write('amount: $amount, ')
          ..write('reason: $reason, ')
          ..write('date: $date')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, shiftId, amount, reason, date);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CashMovement &&
          other.id == this.id &&
          other.shiftId == this.shiftId &&
          other.amount == this.amount &&
          other.reason == this.reason &&
          other.date == this.date);
}

class CashMovementsCompanion extends UpdateCompanion<CashMovement> {
  final Value<int> id;
  final Value<int> shiftId;
  final Value<double> amount;
  final Value<String> reason;
  final Value<DateTime> date;
  const CashMovementsCompanion({
    this.id = const Value.absent(),
    this.shiftId = const Value.absent(),
    this.amount = const Value.absent(),
    this.reason = const Value.absent(),
    this.date = const Value.absent(),
  });
  CashMovementsCompanion.insert({
    this.id = const Value.absent(),
    required int shiftId,
    required double amount,
    required String reason,
    this.date = const Value.absent(),
  }) : shiftId = Value(shiftId),
       amount = Value(amount),
       reason = Value(reason);
  static Insertable<CashMovement> custom({
    Expression<int>? id,
    Expression<int>? shiftId,
    Expression<double>? amount,
    Expression<String>? reason,
    Expression<DateTime>? date,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (shiftId != null) 'shift_id': shiftId,
      if (amount != null) 'amount': amount,
      if (reason != null) 'reason': reason,
      if (date != null) 'date': date,
    });
  }

  CashMovementsCompanion copyWith({
    Value<int>? id,
    Value<int>? shiftId,
    Value<double>? amount,
    Value<String>? reason,
    Value<DateTime>? date,
  }) {
    return CashMovementsCompanion(
      id: id ?? this.id,
      shiftId: shiftId ?? this.shiftId,
      amount: amount ?? this.amount,
      reason: reason ?? this.reason,
      date: date ?? this.date,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (shiftId.present) {
      map['shift_id'] = Variable<int>(shiftId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CashMovementsCompanion(')
          ..write('id: $id, ')
          ..write('shiftId: $shiftId, ')
          ..write('amount: $amount, ')
          ..write('reason: $reason, ')
          ..write('date: $date')
          ..write(')'))
        .toString();
  }
}

class $ShiftClosuresTable extends ShiftClosures
    with TableInfo<$ShiftClosuresTable, ShiftClosure> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShiftClosuresTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _shiftIdMeta = const VerificationMeta(
    'shiftId',
  );
  @override
  late final GeneratedColumn<int> shiftId = GeneratedColumn<int>(
    'shift_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES shifts (id)',
    ),
  );
  static const VerificationMeta _closingTimeMeta = const VerificationMeta(
    'closingTime',
  );
  @override
  late final GeneratedColumn<DateTime> closingTime = GeneratedColumn<DateTime>(
    'closing_time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _systemExpectedCashMeta =
      const VerificationMeta('systemExpectedCash');
  @override
  late final GeneratedColumn<double> systemExpectedCash =
      GeneratedColumn<double>(
        'system_expected_cash',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _declaredCashMeta = const VerificationMeta(
    'declaredCash',
  );
  @override
  late final GeneratedColumn<double> declaredCash = GeneratedColumn<double>(
    'declared_cash',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _differenceMeta = const VerificationMeta(
    'difference',
  );
  @override
  late final GeneratedColumn<double> difference = GeneratedColumn<double>(
    'difference',
    aliasedName,
    false,
    type: DriftSqlType.double,
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
    shiftId,
    closingTime,
    systemExpectedCash,
    declaredCash,
    difference,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shift_closures';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShiftClosure> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('shift_id')) {
      context.handle(
        _shiftIdMeta,
        shiftId.isAcceptableOrUnknown(data['shift_id']!, _shiftIdMeta),
      );
    } else if (isInserting) {
      context.missing(_shiftIdMeta);
    }
    if (data.containsKey('closing_time')) {
      context.handle(
        _closingTimeMeta,
        closingTime.isAcceptableOrUnknown(
          data['closing_time']!,
          _closingTimeMeta,
        ),
      );
    }
    if (data.containsKey('system_expected_cash')) {
      context.handle(
        _systemExpectedCashMeta,
        systemExpectedCash.isAcceptableOrUnknown(
          data['system_expected_cash']!,
          _systemExpectedCashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_systemExpectedCashMeta);
    }
    if (data.containsKey('declared_cash')) {
      context.handle(
        _declaredCashMeta,
        declaredCash.isAcceptableOrUnknown(
          data['declared_cash']!,
          _declaredCashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_declaredCashMeta);
    }
    if (data.containsKey('difference')) {
      context.handle(
        _differenceMeta,
        difference.isAcceptableOrUnknown(data['difference']!, _differenceMeta),
      );
    } else if (isInserting) {
      context.missing(_differenceMeta);
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
  ShiftClosure map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShiftClosure(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      shiftId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}shift_id'],
      )!,
      closingTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}closing_time'],
      )!,
      systemExpectedCash: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}system_expected_cash'],
      )!,
      declaredCash: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}declared_cash'],
      )!,
      difference: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}difference'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $ShiftClosuresTable createAlias(String alias) {
    return $ShiftClosuresTable(attachedDatabase, alias);
  }
}

class ShiftClosure extends DataClass implements Insertable<ShiftClosure> {
  final int id;
  final int shiftId;
  final DateTime closingTime;
  final double systemExpectedCash;
  final double declaredCash;
  final double difference;
  final String? notes;
  const ShiftClosure({
    required this.id,
    required this.shiftId,
    required this.closingTime,
    required this.systemExpectedCash,
    required this.declaredCash,
    required this.difference,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['shift_id'] = Variable<int>(shiftId);
    map['closing_time'] = Variable<DateTime>(closingTime);
    map['system_expected_cash'] = Variable<double>(systemExpectedCash);
    map['declared_cash'] = Variable<double>(declaredCash);
    map['difference'] = Variable<double>(difference);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  ShiftClosuresCompanion toCompanion(bool nullToAbsent) {
    return ShiftClosuresCompanion(
      id: Value(id),
      shiftId: Value(shiftId),
      closingTime: Value(closingTime),
      systemExpectedCash: Value(systemExpectedCash),
      declaredCash: Value(declaredCash),
      difference: Value(difference),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory ShiftClosure.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShiftClosure(
      id: serializer.fromJson<int>(json['id']),
      shiftId: serializer.fromJson<int>(json['shiftId']),
      closingTime: serializer.fromJson<DateTime>(json['closingTime']),
      systemExpectedCash: serializer.fromJson<double>(
        json['systemExpectedCash'],
      ),
      declaredCash: serializer.fromJson<double>(json['declaredCash']),
      difference: serializer.fromJson<double>(json['difference']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'shiftId': serializer.toJson<int>(shiftId),
      'closingTime': serializer.toJson<DateTime>(closingTime),
      'systemExpectedCash': serializer.toJson<double>(systemExpectedCash),
      'declaredCash': serializer.toJson<double>(declaredCash),
      'difference': serializer.toJson<double>(difference),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  ShiftClosure copyWith({
    int? id,
    int? shiftId,
    DateTime? closingTime,
    double? systemExpectedCash,
    double? declaredCash,
    double? difference,
    Value<String?> notes = const Value.absent(),
  }) => ShiftClosure(
    id: id ?? this.id,
    shiftId: shiftId ?? this.shiftId,
    closingTime: closingTime ?? this.closingTime,
    systemExpectedCash: systemExpectedCash ?? this.systemExpectedCash,
    declaredCash: declaredCash ?? this.declaredCash,
    difference: difference ?? this.difference,
    notes: notes.present ? notes.value : this.notes,
  );
  ShiftClosure copyWithCompanion(ShiftClosuresCompanion data) {
    return ShiftClosure(
      id: data.id.present ? data.id.value : this.id,
      shiftId: data.shiftId.present ? data.shiftId.value : this.shiftId,
      closingTime: data.closingTime.present
          ? data.closingTime.value
          : this.closingTime,
      systemExpectedCash: data.systemExpectedCash.present
          ? data.systemExpectedCash.value
          : this.systemExpectedCash,
      declaredCash: data.declaredCash.present
          ? data.declaredCash.value
          : this.declaredCash,
      difference: data.difference.present
          ? data.difference.value
          : this.difference,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShiftClosure(')
          ..write('id: $id, ')
          ..write('shiftId: $shiftId, ')
          ..write('closingTime: $closingTime, ')
          ..write('systemExpectedCash: $systemExpectedCash, ')
          ..write('declaredCash: $declaredCash, ')
          ..write('difference: $difference, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    shiftId,
    closingTime,
    systemExpectedCash,
    declaredCash,
    difference,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShiftClosure &&
          other.id == this.id &&
          other.shiftId == this.shiftId &&
          other.closingTime == this.closingTime &&
          other.systemExpectedCash == this.systemExpectedCash &&
          other.declaredCash == this.declaredCash &&
          other.difference == this.difference &&
          other.notes == this.notes);
}

class ShiftClosuresCompanion extends UpdateCompanion<ShiftClosure> {
  final Value<int> id;
  final Value<int> shiftId;
  final Value<DateTime> closingTime;
  final Value<double> systemExpectedCash;
  final Value<double> declaredCash;
  final Value<double> difference;
  final Value<String?> notes;
  const ShiftClosuresCompanion({
    this.id = const Value.absent(),
    this.shiftId = const Value.absent(),
    this.closingTime = const Value.absent(),
    this.systemExpectedCash = const Value.absent(),
    this.declaredCash = const Value.absent(),
    this.difference = const Value.absent(),
    this.notes = const Value.absent(),
  });
  ShiftClosuresCompanion.insert({
    this.id = const Value.absent(),
    required int shiftId,
    this.closingTime = const Value.absent(),
    required double systemExpectedCash,
    required double declaredCash,
    required double difference,
    this.notes = const Value.absent(),
  }) : shiftId = Value(shiftId),
       systemExpectedCash = Value(systemExpectedCash),
       declaredCash = Value(declaredCash),
       difference = Value(difference);
  static Insertable<ShiftClosure> custom({
    Expression<int>? id,
    Expression<int>? shiftId,
    Expression<DateTime>? closingTime,
    Expression<double>? systemExpectedCash,
    Expression<double>? declaredCash,
    Expression<double>? difference,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (shiftId != null) 'shift_id': shiftId,
      if (closingTime != null) 'closing_time': closingTime,
      if (systemExpectedCash != null)
        'system_expected_cash': systemExpectedCash,
      if (declaredCash != null) 'declared_cash': declaredCash,
      if (difference != null) 'difference': difference,
      if (notes != null) 'notes': notes,
    });
  }

  ShiftClosuresCompanion copyWith({
    Value<int>? id,
    Value<int>? shiftId,
    Value<DateTime>? closingTime,
    Value<double>? systemExpectedCash,
    Value<double>? declaredCash,
    Value<double>? difference,
    Value<String?>? notes,
  }) {
    return ShiftClosuresCompanion(
      id: id ?? this.id,
      shiftId: shiftId ?? this.shiftId,
      closingTime: closingTime ?? this.closingTime,
      systemExpectedCash: systemExpectedCash ?? this.systemExpectedCash,
      declaredCash: declaredCash ?? this.declaredCash,
      difference: difference ?? this.difference,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (shiftId.present) {
      map['shift_id'] = Variable<int>(shiftId.value);
    }
    if (closingTime.present) {
      map['closing_time'] = Variable<DateTime>(closingTime.value);
    }
    if (systemExpectedCash.present) {
      map['system_expected_cash'] = Variable<double>(systemExpectedCash.value);
    }
    if (declaredCash.present) {
      map['declared_cash'] = Variable<double>(declaredCash.value);
    }
    if (difference.present) {
      map['difference'] = Variable<double>(difference.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShiftClosuresCompanion(')
          ..write('id: $id, ')
          ..write('shiftId: $shiftId, ')
          ..write('closingTime: $closingTime, ')
          ..write('systemExpectedCash: $systemExpectedCash, ')
          ..write('declaredCash: $declaredCash, ')
          ..write('difference: $difference, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProductsTable products = $ProductsTable(this);
  late final $SuppliesTable supplies = $SuppliesTable(this);
  late final $RecipesTable recipes = $RecipesTable(this);
  late final $SalesTable sales = $SalesTable(this);
  late final $SaleItemsTable saleItems = $SaleItemsTable(this);
  late final $InventoryLogsTable inventoryLogs = $InventoryLogsTable(this);
  late final $ModifierGroupsTable modifierGroups = $ModifierGroupsTable(this);
  late final $ProductModifiersTable productModifiers = $ProductModifiersTable(
    this,
  );
  late final $ModifierOptionsTable modifierOptions = $ModifierOptionsTable(
    this,
  );
  late final $ParkedOrdersTable parkedOrders = $ParkedOrdersTable(this);
  late final $DiscountsTable discounts = $DiscountsTable(this);
  late final $BundlesTable bundles = $BundlesTable(this);
  late final $BundleItemsTable bundleItems = $BundleItemsTable(this);
  late final $ShiftsTable shifts = $ShiftsTable(this);
  late final $CashMovementsTable cashMovements = $CashMovementsTable(this);
  late final $ShiftClosuresTable shiftClosures = $ShiftClosuresTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    products,
    supplies,
    recipes,
    sales,
    saleItems,
    inventoryLogs,
    modifierGroups,
    productModifiers,
    modifierOptions,
    parkedOrders,
    discounts,
    bundles,
    bundleItems,
    shifts,
    cashMovements,
    shiftClosures,
  ];
}

typedef $$ProductsTableCreateCompanionBuilder =
    ProductsCompanion Function({
      Value<int> id,
      required String name,
      required double price,
      Value<String?> imageUrl,
      Value<bool> isActive,
    });
typedef $$ProductsTableUpdateCompanionBuilder =
    ProductsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<double> price,
      Value<String?> imageUrl,
      Value<bool> isActive,
    });

final class $$ProductsTableReferences
    extends BaseReferences<_$AppDatabase, $ProductsTable, Product> {
  $$ProductsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RecipesTable, List<Recipe>> _recipesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.recipes,
    aliasName: $_aliasNameGenerator(db.products.id, db.recipes.productId),
  );

  $$RecipesTableProcessedTableManager get recipesRefs {
    final manager = $$RecipesTableTableManager(
      $_db,
      $_db.recipes,
    ).filter((f) => f.productId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_recipesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SaleItemsTable, List<SaleItem>>
  _saleItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.saleItems,
    aliasName: $_aliasNameGenerator(db.products.id, db.saleItems.productId),
  );

  $$SaleItemsTableProcessedTableManager get saleItemsRefs {
    final manager = $$SaleItemsTableTableManager(
      $_db,
      $_db.saleItems,
    ).filter((f) => f.productId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_saleItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ProductModifiersTable, List<ProductModifier>>
  _productModifiersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.productModifiers,
    aliasName: $_aliasNameGenerator(
      db.products.id,
      db.productModifiers.productId,
    ),
  );

  $$ProductModifiersTableProcessedTableManager get productModifiersRefs {
    final manager = $$ProductModifiersTableTableManager(
      $_db,
      $_db.productModifiers,
    ).filter((f) => f.productId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _productModifiersRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BundleItemsTable, List<BundleItem>>
  _bundleItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.bundleItems,
    aliasName: $_aliasNameGenerator(db.products.id, db.bundleItems.productId),
  );

  $$BundleItemsTableProcessedTableManager get bundleItemsRefs {
    final manager = $$BundleItemsTableTableManager(
      $_db,
      $_db.bundleItems,
    ).filter((f) => f.productId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_bundleItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProductsTableFilterComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> recipesRefs(
    Expression<bool> Function($$RecipesTableFilterComposer f) f,
  ) {
    final $$RecipesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableFilterComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> saleItemsRefs(
    Expression<bool> Function($$SaleItemsTableFilterComposer f) f,
  ) {
    final $$SaleItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.saleItems,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SaleItemsTableFilterComposer(
            $db: $db,
            $table: $db.saleItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> productModifiersRefs(
    Expression<bool> Function($$ProductModifiersTableFilterComposer f) f,
  ) {
    final $$ProductModifiersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.productModifiers,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductModifiersTableFilterComposer(
            $db: $db,
            $table: $db.productModifiers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> bundleItemsRefs(
    Expression<bool> Function($$BundleItemsTableFilterComposer f) f,
  ) {
    final $$BundleItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bundleItems,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BundleItemsTableFilterComposer(
            $db: $db,
            $table: $db.bundleItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProductsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProductsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  Expression<T> recipesRefs<T extends Object>(
    Expression<T> Function($$RecipesTableAnnotationComposer a) f,
  ) {
    final $$RecipesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableAnnotationComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> saleItemsRefs<T extends Object>(
    Expression<T> Function($$SaleItemsTableAnnotationComposer a) f,
  ) {
    final $$SaleItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.saleItems,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SaleItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.saleItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> productModifiersRefs<T extends Object>(
    Expression<T> Function($$ProductModifiersTableAnnotationComposer a) f,
  ) {
    final $$ProductModifiersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.productModifiers,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductModifiersTableAnnotationComposer(
            $db: $db,
            $table: $db.productModifiers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> bundleItemsRefs<T extends Object>(
    Expression<T> Function($$BundleItemsTableAnnotationComposer a) f,
  ) {
    final $$BundleItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bundleItems,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BundleItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.bundleItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProductsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProductsTable,
          Product,
          $$ProductsTableFilterComposer,
          $$ProductsTableOrderingComposer,
          $$ProductsTableAnnotationComposer,
          $$ProductsTableCreateCompanionBuilder,
          $$ProductsTableUpdateCompanionBuilder,
          (Product, $$ProductsTableReferences),
          Product,
          PrefetchHooks Function({
            bool recipesRefs,
            bool saleItemsRefs,
            bool productModifiersRefs,
            bool bundleItemsRefs,
          })
        > {
  $$ProductsTableTableManager(_$AppDatabase db, $ProductsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> price = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
              }) => ProductsCompanion(
                id: id,
                name: name,
                price: price,
                imageUrl: imageUrl,
                isActive: isActive,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required double price,
                Value<String?> imageUrl = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
              }) => ProductsCompanion.insert(
                id: id,
                name: name,
                price: price,
                imageUrl: imageUrl,
                isActive: isActive,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProductsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                recipesRefs = false,
                saleItemsRefs = false,
                productModifiersRefs = false,
                bundleItemsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (recipesRefs) db.recipes,
                    if (saleItemsRefs) db.saleItems,
                    if (productModifiersRefs) db.productModifiers,
                    if (bundleItemsRefs) db.bundleItems,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (recipesRefs)
                        await $_getPrefetchedData<
                          Product,
                          $ProductsTable,
                          Recipe
                        >(
                          currentTable: table,
                          referencedTable: $$ProductsTableReferences
                              ._recipesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProductsTableReferences(
                                db,
                                table,
                                p0,
                              ).recipesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.productId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (saleItemsRefs)
                        await $_getPrefetchedData<
                          Product,
                          $ProductsTable,
                          SaleItem
                        >(
                          currentTable: table,
                          referencedTable: $$ProductsTableReferences
                              ._saleItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProductsTableReferences(
                                db,
                                table,
                                p0,
                              ).saleItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.productId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (productModifiersRefs)
                        await $_getPrefetchedData<
                          Product,
                          $ProductsTable,
                          ProductModifier
                        >(
                          currentTable: table,
                          referencedTable: $$ProductsTableReferences
                              ._productModifiersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProductsTableReferences(
                                db,
                                table,
                                p0,
                              ).productModifiersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.productId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (bundleItemsRefs)
                        await $_getPrefetchedData<
                          Product,
                          $ProductsTable,
                          BundleItem
                        >(
                          currentTable: table,
                          referencedTable: $$ProductsTableReferences
                              ._bundleItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProductsTableReferences(
                                db,
                                table,
                                p0,
                              ).bundleItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.productId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ProductsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProductsTable,
      Product,
      $$ProductsTableFilterComposer,
      $$ProductsTableOrderingComposer,
      $$ProductsTableAnnotationComposer,
      $$ProductsTableCreateCompanionBuilder,
      $$ProductsTableUpdateCompanionBuilder,
      (Product, $$ProductsTableReferences),
      Product,
      PrefetchHooks Function({
        bool recipesRefs,
        bool saleItemsRefs,
        bool productModifiersRefs,
        bool bundleItemsRefs,
      })
    >;
typedef $$SuppliesTableCreateCompanionBuilder =
    SuppliesCompanion Function({
      Value<int> id,
      required String name,
      Value<double> currentStock,
      required String unit,
      Value<double> costPerUnit,
      Value<double> reorderPoint,
    });
typedef $$SuppliesTableUpdateCompanionBuilder =
    SuppliesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<double> currentStock,
      Value<String> unit,
      Value<double> costPerUnit,
      Value<double> reorderPoint,
    });

final class $$SuppliesTableReferences
    extends BaseReferences<_$AppDatabase, $SuppliesTable, Supply> {
  $$SuppliesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RecipesTable, List<Recipe>> _recipesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.recipes,
    aliasName: $_aliasNameGenerator(db.supplies.id, db.recipes.supplyId),
  );

  $$RecipesTableProcessedTableManager get recipesRefs {
    final manager = $$RecipesTableTableManager(
      $_db,
      $_db.recipes,
    ).filter((f) => f.supplyId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_recipesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$InventoryLogsTable, List<InventoryLog>>
  _inventoryLogsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.inventoryLogs,
    aliasName: $_aliasNameGenerator(db.supplies.id, db.inventoryLogs.supplyId),
  );

  $$InventoryLogsTableProcessedTableManager get inventoryLogsRefs {
    final manager = $$InventoryLogsTableTableManager(
      $_db,
      $_db.inventoryLogs,
    ).filter((f) => f.supplyId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_inventoryLogsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ModifierOptionsTable, List<ModifierOption>>
  _modifierOptionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.modifierOptions,
    aliasName: $_aliasNameGenerator(
      db.supplies.id,
      db.modifierOptions.supplyId,
    ),
  );

  $$ModifierOptionsTableProcessedTableManager get modifierOptionsRefs {
    final manager = $$ModifierOptionsTableTableManager(
      $_db,
      $_db.modifierOptions,
    ).filter((f) => f.supplyId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _modifierOptionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SuppliesTableFilterComposer
    extends Composer<_$AppDatabase, $SuppliesTable> {
  $$SuppliesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get currentStock => $composableBuilder(
    column: $table.currentStock,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get costPerUnit => $composableBuilder(
    column: $table.costPerUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get reorderPoint => $composableBuilder(
    column: $table.reorderPoint,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> recipesRefs(
    Expression<bool> Function($$RecipesTableFilterComposer f) f,
  ) {
    final $$RecipesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.supplyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableFilterComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> inventoryLogsRefs(
    Expression<bool> Function($$InventoryLogsTableFilterComposer f) f,
  ) {
    final $$InventoryLogsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.inventoryLogs,
      getReferencedColumn: (t) => t.supplyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InventoryLogsTableFilterComposer(
            $db: $db,
            $table: $db.inventoryLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> modifierOptionsRefs(
    Expression<bool> Function($$ModifierOptionsTableFilterComposer f) f,
  ) {
    final $$ModifierOptionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.modifierOptions,
      getReferencedColumn: (t) => t.supplyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModifierOptionsTableFilterComposer(
            $db: $db,
            $table: $db.modifierOptions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SuppliesTableOrderingComposer
    extends Composer<_$AppDatabase, $SuppliesTable> {
  $$SuppliesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get currentStock => $composableBuilder(
    column: $table.currentStock,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get costPerUnit => $composableBuilder(
    column: $table.costPerUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get reorderPoint => $composableBuilder(
    column: $table.reorderPoint,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SuppliesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SuppliesTable> {
  $$SuppliesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get currentStock => $composableBuilder(
    column: $table.currentStock,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<double> get costPerUnit => $composableBuilder(
    column: $table.costPerUnit,
    builder: (column) => column,
  );

  GeneratedColumn<double> get reorderPoint => $composableBuilder(
    column: $table.reorderPoint,
    builder: (column) => column,
  );

  Expression<T> recipesRefs<T extends Object>(
    Expression<T> Function($$RecipesTableAnnotationComposer a) f,
  ) {
    final $$RecipesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.supplyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableAnnotationComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> inventoryLogsRefs<T extends Object>(
    Expression<T> Function($$InventoryLogsTableAnnotationComposer a) f,
  ) {
    final $$InventoryLogsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.inventoryLogs,
      getReferencedColumn: (t) => t.supplyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InventoryLogsTableAnnotationComposer(
            $db: $db,
            $table: $db.inventoryLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> modifierOptionsRefs<T extends Object>(
    Expression<T> Function($$ModifierOptionsTableAnnotationComposer a) f,
  ) {
    final $$ModifierOptionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.modifierOptions,
      getReferencedColumn: (t) => t.supplyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModifierOptionsTableAnnotationComposer(
            $db: $db,
            $table: $db.modifierOptions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SuppliesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SuppliesTable,
          Supply,
          $$SuppliesTableFilterComposer,
          $$SuppliesTableOrderingComposer,
          $$SuppliesTableAnnotationComposer,
          $$SuppliesTableCreateCompanionBuilder,
          $$SuppliesTableUpdateCompanionBuilder,
          (Supply, $$SuppliesTableReferences),
          Supply,
          PrefetchHooks Function({
            bool recipesRefs,
            bool inventoryLogsRefs,
            bool modifierOptionsRefs,
          })
        > {
  $$SuppliesTableTableManager(_$AppDatabase db, $SuppliesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SuppliesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SuppliesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SuppliesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> currentStock = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<double> costPerUnit = const Value.absent(),
                Value<double> reorderPoint = const Value.absent(),
              }) => SuppliesCompanion(
                id: id,
                name: name,
                currentStock: currentStock,
                unit: unit,
                costPerUnit: costPerUnit,
                reorderPoint: reorderPoint,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<double> currentStock = const Value.absent(),
                required String unit,
                Value<double> costPerUnit = const Value.absent(),
                Value<double> reorderPoint = const Value.absent(),
              }) => SuppliesCompanion.insert(
                id: id,
                name: name,
                currentStock: currentStock,
                unit: unit,
                costPerUnit: costPerUnit,
                reorderPoint: reorderPoint,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SuppliesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                recipesRefs = false,
                inventoryLogsRefs = false,
                modifierOptionsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (recipesRefs) db.recipes,
                    if (inventoryLogsRefs) db.inventoryLogs,
                    if (modifierOptionsRefs) db.modifierOptions,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (recipesRefs)
                        await $_getPrefetchedData<
                          Supply,
                          $SuppliesTable,
                          Recipe
                        >(
                          currentTable: table,
                          referencedTable: $$SuppliesTableReferences
                              ._recipesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SuppliesTableReferences(
                                db,
                                table,
                                p0,
                              ).recipesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.supplyId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (inventoryLogsRefs)
                        await $_getPrefetchedData<
                          Supply,
                          $SuppliesTable,
                          InventoryLog
                        >(
                          currentTable: table,
                          referencedTable: $$SuppliesTableReferences
                              ._inventoryLogsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SuppliesTableReferences(
                                db,
                                table,
                                p0,
                              ).inventoryLogsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.supplyId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (modifierOptionsRefs)
                        await $_getPrefetchedData<
                          Supply,
                          $SuppliesTable,
                          ModifierOption
                        >(
                          currentTable: table,
                          referencedTable: $$SuppliesTableReferences
                              ._modifierOptionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SuppliesTableReferences(
                                db,
                                table,
                                p0,
                              ).modifierOptionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.supplyId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SuppliesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SuppliesTable,
      Supply,
      $$SuppliesTableFilterComposer,
      $$SuppliesTableOrderingComposer,
      $$SuppliesTableAnnotationComposer,
      $$SuppliesTableCreateCompanionBuilder,
      $$SuppliesTableUpdateCompanionBuilder,
      (Supply, $$SuppliesTableReferences),
      Supply,
      PrefetchHooks Function({
        bool recipesRefs,
        bool inventoryLogsRefs,
        bool modifierOptionsRefs,
      })
    >;
typedef $$RecipesTableCreateCompanionBuilder =
    RecipesCompanion Function({
      Value<int> id,
      required int productId,
      required int supplyId,
      required double quantityRequired,
    });
typedef $$RecipesTableUpdateCompanionBuilder =
    RecipesCompanion Function({
      Value<int> id,
      Value<int> productId,
      Value<int> supplyId,
      Value<double> quantityRequired,
    });

final class $$RecipesTableReferences
    extends BaseReferences<_$AppDatabase, $RecipesTable, Recipe> {
  $$RecipesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProductsTable _productIdTable(_$AppDatabase db) => db.products
      .createAlias($_aliasNameGenerator(db.recipes.productId, db.products.id));

  $$ProductsTableProcessedTableManager get productId {
    final $_column = $_itemColumn<int>('product_id')!;

    final manager = $$ProductsTableTableManager(
      $_db,
      $_db.products,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SuppliesTable _supplyIdTable(_$AppDatabase db) => db.supplies
      .createAlias($_aliasNameGenerator(db.recipes.supplyId, db.supplies.id));

  $$SuppliesTableProcessedTableManager get supplyId {
    final $_column = $_itemColumn<int>('supply_id')!;

    final manager = $$SuppliesTableTableManager(
      $_db,
      $_db.supplies,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_supplyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RecipesTableFilterComposer
    extends Composer<_$AppDatabase, $RecipesTable> {
  $$RecipesTableFilterComposer({
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

  ColumnFilters<double> get quantityRequired => $composableBuilder(
    column: $table.quantityRequired,
    builder: (column) => ColumnFilters(column),
  );

  $$ProductsTableFilterComposer get productId {
    final $$ProductsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableFilterComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SuppliesTableFilterComposer get supplyId {
    final $$SuppliesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.supplyId,
      referencedTable: $db.supplies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SuppliesTableFilterComposer(
            $db: $db,
            $table: $db.supplies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipesTableOrderingComposer
    extends Composer<_$AppDatabase, $RecipesTable> {
  $$RecipesTableOrderingComposer({
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

  ColumnOrderings<double> get quantityRequired => $composableBuilder(
    column: $table.quantityRequired,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProductsTableOrderingComposer get productId {
    final $$ProductsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableOrderingComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SuppliesTableOrderingComposer get supplyId {
    final $$SuppliesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.supplyId,
      referencedTable: $db.supplies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SuppliesTableOrderingComposer(
            $db: $db,
            $table: $db.supplies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecipesTable> {
  $$RecipesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get quantityRequired => $composableBuilder(
    column: $table.quantityRequired,
    builder: (column) => column,
  );

  $$ProductsTableAnnotationComposer get productId {
    final $$ProductsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableAnnotationComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SuppliesTableAnnotationComposer get supplyId {
    final $$SuppliesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.supplyId,
      referencedTable: $db.supplies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SuppliesTableAnnotationComposer(
            $db: $db,
            $table: $db.supplies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecipesTable,
          Recipe,
          $$RecipesTableFilterComposer,
          $$RecipesTableOrderingComposer,
          $$RecipesTableAnnotationComposer,
          $$RecipesTableCreateCompanionBuilder,
          $$RecipesTableUpdateCompanionBuilder,
          (Recipe, $$RecipesTableReferences),
          Recipe,
          PrefetchHooks Function({bool productId, bool supplyId})
        > {
  $$RecipesTableTableManager(_$AppDatabase db, $RecipesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecipesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecipesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecipesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> productId = const Value.absent(),
                Value<int> supplyId = const Value.absent(),
                Value<double> quantityRequired = const Value.absent(),
              }) => RecipesCompanion(
                id: id,
                productId: productId,
                supplyId: supplyId,
                quantityRequired: quantityRequired,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int productId,
                required int supplyId,
                required double quantityRequired,
              }) => RecipesCompanion.insert(
                id: id,
                productId: productId,
                supplyId: supplyId,
                quantityRequired: quantityRequired,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RecipesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({productId = false, supplyId = false}) {
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
                    if (productId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.productId,
                                referencedTable: $$RecipesTableReferences
                                    ._productIdTable(db),
                                referencedColumn: $$RecipesTableReferences
                                    ._productIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (supplyId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.supplyId,
                                referencedTable: $$RecipesTableReferences
                                    ._supplyIdTable(db),
                                referencedColumn: $$RecipesTableReferences
                                    ._supplyIdTable(db)
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

typedef $$RecipesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecipesTable,
      Recipe,
      $$RecipesTableFilterComposer,
      $$RecipesTableOrderingComposer,
      $$RecipesTableAnnotationComposer,
      $$RecipesTableCreateCompanionBuilder,
      $$RecipesTableUpdateCompanionBuilder,
      (Recipe, $$RecipesTableReferences),
      Recipe,
      PrefetchHooks Function({bool productId, bool supplyId})
    >;
typedef $$SalesTableCreateCompanionBuilder =
    SalesCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      required double totalAmount,
      Value<String> paymentMethod,
    });
typedef $$SalesTableUpdateCompanionBuilder =
    SalesCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      Value<double> totalAmount,
      Value<String> paymentMethod,
    });

final class $$SalesTableReferences
    extends BaseReferences<_$AppDatabase, $SalesTable, Sale> {
  $$SalesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SaleItemsTable, List<SaleItem>>
  _saleItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.saleItems,
    aliasName: $_aliasNameGenerator(db.sales.id, db.saleItems.saleId),
  );

  $$SaleItemsTableProcessedTableManager get saleItemsRefs {
    final manager = $$SaleItemsTableTableManager(
      $_db,
      $_db.saleItems,
    ).filter((f) => f.saleId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_saleItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SalesTableFilterComposer extends Composer<_$AppDatabase, $SalesTable> {
  $$SalesTableFilterComposer({
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

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> saleItemsRefs(
    Expression<bool> Function($$SaleItemsTableFilterComposer f) f,
  ) {
    final $$SaleItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.saleItems,
      getReferencedColumn: (t) => t.saleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SaleItemsTableFilterComposer(
            $db: $db,
            $table: $db.saleItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SalesTableOrderingComposer
    extends Composer<_$AppDatabase, $SalesTable> {
  $$SalesTableOrderingComposer({
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

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SalesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SalesTable> {
  $$SalesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<double> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => column,
  );

  Expression<T> saleItemsRefs<T extends Object>(
    Expression<T> Function($$SaleItemsTableAnnotationComposer a) f,
  ) {
    final $$SaleItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.saleItems,
      getReferencedColumn: (t) => t.saleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SaleItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.saleItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SalesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SalesTable,
          Sale,
          $$SalesTableFilterComposer,
          $$SalesTableOrderingComposer,
          $$SalesTableAnnotationComposer,
          $$SalesTableCreateCompanionBuilder,
          $$SalesTableUpdateCompanionBuilder,
          (Sale, $$SalesTableReferences),
          Sale,
          PrefetchHooks Function({bool saleItemsRefs})
        > {
  $$SalesTableTableManager(_$AppDatabase db, $SalesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SalesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SalesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SalesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<double> totalAmount = const Value.absent(),
                Value<String> paymentMethod = const Value.absent(),
              }) => SalesCompanion(
                id: id,
                date: date,
                totalAmount: totalAmount,
                paymentMethod: paymentMethod,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                required double totalAmount,
                Value<String> paymentMethod = const Value.absent(),
              }) => SalesCompanion.insert(
                id: id,
                date: date,
                totalAmount: totalAmount,
                paymentMethod: paymentMethod,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$SalesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({saleItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (saleItemsRefs) db.saleItems],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (saleItemsRefs)
                    await $_getPrefetchedData<Sale, $SalesTable, SaleItem>(
                      currentTable: table,
                      referencedTable: $$SalesTableReferences
                          ._saleItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SalesTableReferences(db, table, p0).saleItemsRefs,
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

typedef $$SalesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SalesTable,
      Sale,
      $$SalesTableFilterComposer,
      $$SalesTableOrderingComposer,
      $$SalesTableAnnotationComposer,
      $$SalesTableCreateCompanionBuilder,
      $$SalesTableUpdateCompanionBuilder,
      (Sale, $$SalesTableReferences),
      Sale,
      PrefetchHooks Function({bool saleItemsRefs})
    >;
typedef $$SaleItemsTableCreateCompanionBuilder =
    SaleItemsCompanion Function({
      Value<int> id,
      required int saleId,
      required int productId,
      required double quantity,
      required double unitPrice,
    });
typedef $$SaleItemsTableUpdateCompanionBuilder =
    SaleItemsCompanion Function({
      Value<int> id,
      Value<int> saleId,
      Value<int> productId,
      Value<double> quantity,
      Value<double> unitPrice,
    });

final class $$SaleItemsTableReferences
    extends BaseReferences<_$AppDatabase, $SaleItemsTable, SaleItem> {
  $$SaleItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SalesTable _saleIdTable(_$AppDatabase db) => db.sales.createAlias(
    $_aliasNameGenerator(db.saleItems.saleId, db.sales.id),
  );

  $$SalesTableProcessedTableManager get saleId {
    final $_column = $_itemColumn<int>('sale_id')!;

    final manager = $$SalesTableTableManager(
      $_db,
      $_db.sales,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_saleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ProductsTable _productIdTable(_$AppDatabase db) =>
      db.products.createAlias(
        $_aliasNameGenerator(db.saleItems.productId, db.products.id),
      );

  $$ProductsTableProcessedTableManager get productId {
    final $_column = $_itemColumn<int>('product_id')!;

    final manager = $$ProductsTableTableManager(
      $_db,
      $_db.products,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SaleItemsTableFilterComposer
    extends Composer<_$AppDatabase, $SaleItemsTable> {
  $$SaleItemsTableFilterComposer({
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

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get unitPrice => $composableBuilder(
    column: $table.unitPrice,
    builder: (column) => ColumnFilters(column),
  );

  $$SalesTableFilterComposer get saleId {
    final $$SalesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.saleId,
      referencedTable: $db.sales,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SalesTableFilterComposer(
            $db: $db,
            $table: $db.sales,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductsTableFilterComposer get productId {
    final $$ProductsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableFilterComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SaleItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $SaleItemsTable> {
  $$SaleItemsTableOrderingComposer({
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

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get unitPrice => $composableBuilder(
    column: $table.unitPrice,
    builder: (column) => ColumnOrderings(column),
  );

  $$SalesTableOrderingComposer get saleId {
    final $$SalesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.saleId,
      referencedTable: $db.sales,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SalesTableOrderingComposer(
            $db: $db,
            $table: $db.sales,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductsTableOrderingComposer get productId {
    final $$ProductsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableOrderingComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SaleItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SaleItemsTable> {
  $$SaleItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get unitPrice =>
      $composableBuilder(column: $table.unitPrice, builder: (column) => column);

  $$SalesTableAnnotationComposer get saleId {
    final $$SalesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.saleId,
      referencedTable: $db.sales,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SalesTableAnnotationComposer(
            $db: $db,
            $table: $db.sales,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductsTableAnnotationComposer get productId {
    final $$ProductsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableAnnotationComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SaleItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SaleItemsTable,
          SaleItem,
          $$SaleItemsTableFilterComposer,
          $$SaleItemsTableOrderingComposer,
          $$SaleItemsTableAnnotationComposer,
          $$SaleItemsTableCreateCompanionBuilder,
          $$SaleItemsTableUpdateCompanionBuilder,
          (SaleItem, $$SaleItemsTableReferences),
          SaleItem,
          PrefetchHooks Function({bool saleId, bool productId})
        > {
  $$SaleItemsTableTableManager(_$AppDatabase db, $SaleItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SaleItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SaleItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SaleItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> saleId = const Value.absent(),
                Value<int> productId = const Value.absent(),
                Value<double> quantity = const Value.absent(),
                Value<double> unitPrice = const Value.absent(),
              }) => SaleItemsCompanion(
                id: id,
                saleId: saleId,
                productId: productId,
                quantity: quantity,
                unitPrice: unitPrice,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int saleId,
                required int productId,
                required double quantity,
                required double unitPrice,
              }) => SaleItemsCompanion.insert(
                id: id,
                saleId: saleId,
                productId: productId,
                quantity: quantity,
                unitPrice: unitPrice,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SaleItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({saleId = false, productId = false}) {
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
                                referencedTable: $$SaleItemsTableReferences
                                    ._saleIdTable(db),
                                referencedColumn: $$SaleItemsTableReferences
                                    ._saleIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (productId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.productId,
                                referencedTable: $$SaleItemsTableReferences
                                    ._productIdTable(db),
                                referencedColumn: $$SaleItemsTableReferences
                                    ._productIdTable(db)
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

typedef $$SaleItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SaleItemsTable,
      SaleItem,
      $$SaleItemsTableFilterComposer,
      $$SaleItemsTableOrderingComposer,
      $$SaleItemsTableAnnotationComposer,
      $$SaleItemsTableCreateCompanionBuilder,
      $$SaleItemsTableUpdateCompanionBuilder,
      (SaleItem, $$SaleItemsTableReferences),
      SaleItem,
      PrefetchHooks Function({bool saleId, bool productId})
    >;
typedef $$InventoryLogsTableCreateCompanionBuilder =
    InventoryLogsCompanion Function({
      Value<int> id,
      required int supplyId,
      required double changeAmount,
      required String reason,
      Value<DateTime> date,
    });
typedef $$InventoryLogsTableUpdateCompanionBuilder =
    InventoryLogsCompanion Function({
      Value<int> id,
      Value<int> supplyId,
      Value<double> changeAmount,
      Value<String> reason,
      Value<DateTime> date,
    });

final class $$InventoryLogsTableReferences
    extends BaseReferences<_$AppDatabase, $InventoryLogsTable, InventoryLog> {
  $$InventoryLogsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SuppliesTable _supplyIdTable(_$AppDatabase db) =>
      db.supplies.createAlias(
        $_aliasNameGenerator(db.inventoryLogs.supplyId, db.supplies.id),
      );

  $$SuppliesTableProcessedTableManager get supplyId {
    final $_column = $_itemColumn<int>('supply_id')!;

    final manager = $$SuppliesTableTableManager(
      $_db,
      $_db.supplies,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_supplyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$InventoryLogsTableFilterComposer
    extends Composer<_$AppDatabase, $InventoryLogsTable> {
  $$InventoryLogsTableFilterComposer({
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

  ColumnFilters<double> get changeAmount => $composableBuilder(
    column: $table.changeAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  $$SuppliesTableFilterComposer get supplyId {
    final $$SuppliesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.supplyId,
      referencedTable: $db.supplies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SuppliesTableFilterComposer(
            $db: $db,
            $table: $db.supplies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InventoryLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $InventoryLogsTable> {
  $$InventoryLogsTableOrderingComposer({
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

  ColumnOrderings<double> get changeAmount => $composableBuilder(
    column: $table.changeAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  $$SuppliesTableOrderingComposer get supplyId {
    final $$SuppliesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.supplyId,
      referencedTable: $db.supplies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SuppliesTableOrderingComposer(
            $db: $db,
            $table: $db.supplies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InventoryLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InventoryLogsTable> {
  $$InventoryLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get changeAmount => $composableBuilder(
    column: $table.changeAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  $$SuppliesTableAnnotationComposer get supplyId {
    final $$SuppliesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.supplyId,
      referencedTable: $db.supplies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SuppliesTableAnnotationComposer(
            $db: $db,
            $table: $db.supplies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InventoryLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InventoryLogsTable,
          InventoryLog,
          $$InventoryLogsTableFilterComposer,
          $$InventoryLogsTableOrderingComposer,
          $$InventoryLogsTableAnnotationComposer,
          $$InventoryLogsTableCreateCompanionBuilder,
          $$InventoryLogsTableUpdateCompanionBuilder,
          (InventoryLog, $$InventoryLogsTableReferences),
          InventoryLog,
          PrefetchHooks Function({bool supplyId})
        > {
  $$InventoryLogsTableTableManager(_$AppDatabase db, $InventoryLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InventoryLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InventoryLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InventoryLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> supplyId = const Value.absent(),
                Value<double> changeAmount = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
              }) => InventoryLogsCompanion(
                id: id,
                supplyId: supplyId,
                changeAmount: changeAmount,
                reason: reason,
                date: date,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int supplyId,
                required double changeAmount,
                required String reason,
                Value<DateTime> date = const Value.absent(),
              }) => InventoryLogsCompanion.insert(
                id: id,
                supplyId: supplyId,
                changeAmount: changeAmount,
                reason: reason,
                date: date,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$InventoryLogsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({supplyId = false}) {
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
                    if (supplyId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.supplyId,
                                referencedTable: $$InventoryLogsTableReferences
                                    ._supplyIdTable(db),
                                referencedColumn: $$InventoryLogsTableReferences
                                    ._supplyIdTable(db)
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

typedef $$InventoryLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InventoryLogsTable,
      InventoryLog,
      $$InventoryLogsTableFilterComposer,
      $$InventoryLogsTableOrderingComposer,
      $$InventoryLogsTableAnnotationComposer,
      $$InventoryLogsTableCreateCompanionBuilder,
      $$InventoryLogsTableUpdateCompanionBuilder,
      (InventoryLog, $$InventoryLogsTableReferences),
      InventoryLog,
      PrefetchHooks Function({bool supplyId})
    >;
typedef $$ModifierGroupsTableCreateCompanionBuilder =
    ModifierGroupsCompanion Function({
      Value<int> id,
      required String name,
      Value<int> minSelection,
      required int maxSelection,
    });
typedef $$ModifierGroupsTableUpdateCompanionBuilder =
    ModifierGroupsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> minSelection,
      Value<int> maxSelection,
    });

final class $$ModifierGroupsTableReferences
    extends BaseReferences<_$AppDatabase, $ModifierGroupsTable, ModifierGroup> {
  $$ModifierGroupsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$ProductModifiersTable, List<ProductModifier>>
  _productModifiersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.productModifiers,
    aliasName: $_aliasNameGenerator(
      db.modifierGroups.id,
      db.productModifiers.modifierGroupId,
    ),
  );

  $$ProductModifiersTableProcessedTableManager get productModifiersRefs {
    final manager = $$ProductModifiersTableTableManager(
      $_db,
      $_db.productModifiers,
    ).filter((f) => f.modifierGroupId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _productModifiersRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ModifierOptionsTable, List<ModifierOption>>
  _modifierOptionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.modifierOptions,
    aliasName: $_aliasNameGenerator(
      db.modifierGroups.id,
      db.modifierOptions.modifierGroupId,
    ),
  );

  $$ModifierOptionsTableProcessedTableManager get modifierOptionsRefs {
    final manager = $$ModifierOptionsTableTableManager(
      $_db,
      $_db.modifierOptions,
    ).filter((f) => f.modifierGroupId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _modifierOptionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ModifierGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $ModifierGroupsTable> {
  $$ModifierGroupsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minSelection => $composableBuilder(
    column: $table.minSelection,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxSelection => $composableBuilder(
    column: $table.maxSelection,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> productModifiersRefs(
    Expression<bool> Function($$ProductModifiersTableFilterComposer f) f,
  ) {
    final $$ProductModifiersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.productModifiers,
      getReferencedColumn: (t) => t.modifierGroupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductModifiersTableFilterComposer(
            $db: $db,
            $table: $db.productModifiers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> modifierOptionsRefs(
    Expression<bool> Function($$ModifierOptionsTableFilterComposer f) f,
  ) {
    final $$ModifierOptionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.modifierOptions,
      getReferencedColumn: (t) => t.modifierGroupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModifierOptionsTableFilterComposer(
            $db: $db,
            $table: $db.modifierOptions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ModifierGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $ModifierGroupsTable> {
  $$ModifierGroupsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minSelection => $composableBuilder(
    column: $table.minSelection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxSelection => $composableBuilder(
    column: $table.maxSelection,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ModifierGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ModifierGroupsTable> {
  $$ModifierGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get minSelection => $composableBuilder(
    column: $table.minSelection,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxSelection => $composableBuilder(
    column: $table.maxSelection,
    builder: (column) => column,
  );

  Expression<T> productModifiersRefs<T extends Object>(
    Expression<T> Function($$ProductModifiersTableAnnotationComposer a) f,
  ) {
    final $$ProductModifiersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.productModifiers,
      getReferencedColumn: (t) => t.modifierGroupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductModifiersTableAnnotationComposer(
            $db: $db,
            $table: $db.productModifiers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> modifierOptionsRefs<T extends Object>(
    Expression<T> Function($$ModifierOptionsTableAnnotationComposer a) f,
  ) {
    final $$ModifierOptionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.modifierOptions,
      getReferencedColumn: (t) => t.modifierGroupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModifierOptionsTableAnnotationComposer(
            $db: $db,
            $table: $db.modifierOptions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ModifierGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ModifierGroupsTable,
          ModifierGroup,
          $$ModifierGroupsTableFilterComposer,
          $$ModifierGroupsTableOrderingComposer,
          $$ModifierGroupsTableAnnotationComposer,
          $$ModifierGroupsTableCreateCompanionBuilder,
          $$ModifierGroupsTableUpdateCompanionBuilder,
          (ModifierGroup, $$ModifierGroupsTableReferences),
          ModifierGroup,
          PrefetchHooks Function({
            bool productModifiersRefs,
            bool modifierOptionsRefs,
          })
        > {
  $$ModifierGroupsTableTableManager(
    _$AppDatabase db,
    $ModifierGroupsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ModifierGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ModifierGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ModifierGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> minSelection = const Value.absent(),
                Value<int> maxSelection = const Value.absent(),
              }) => ModifierGroupsCompanion(
                id: id,
                name: name,
                minSelection: minSelection,
                maxSelection: maxSelection,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int> minSelection = const Value.absent(),
                required int maxSelection,
              }) => ModifierGroupsCompanion.insert(
                id: id,
                name: name,
                minSelection: minSelection,
                maxSelection: maxSelection,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ModifierGroupsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({productModifiersRefs = false, modifierOptionsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (productModifiersRefs) db.productModifiers,
                    if (modifierOptionsRefs) db.modifierOptions,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (productModifiersRefs)
                        await $_getPrefetchedData<
                          ModifierGroup,
                          $ModifierGroupsTable,
                          ProductModifier
                        >(
                          currentTable: table,
                          referencedTable: $$ModifierGroupsTableReferences
                              ._productModifiersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ModifierGroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).productModifiersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.modifierGroupId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (modifierOptionsRefs)
                        await $_getPrefetchedData<
                          ModifierGroup,
                          $ModifierGroupsTable,
                          ModifierOption
                        >(
                          currentTable: table,
                          referencedTable: $$ModifierGroupsTableReferences
                              ._modifierOptionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ModifierGroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).modifierOptionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.modifierGroupId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ModifierGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ModifierGroupsTable,
      ModifierGroup,
      $$ModifierGroupsTableFilterComposer,
      $$ModifierGroupsTableOrderingComposer,
      $$ModifierGroupsTableAnnotationComposer,
      $$ModifierGroupsTableCreateCompanionBuilder,
      $$ModifierGroupsTableUpdateCompanionBuilder,
      (ModifierGroup, $$ModifierGroupsTableReferences),
      ModifierGroup,
      PrefetchHooks Function({
        bool productModifiersRefs,
        bool modifierOptionsRefs,
      })
    >;
typedef $$ProductModifiersTableCreateCompanionBuilder =
    ProductModifiersCompanion Function({
      Value<int> id,
      required int productId,
      required int modifierGroupId,
    });
typedef $$ProductModifiersTableUpdateCompanionBuilder =
    ProductModifiersCompanion Function({
      Value<int> id,
      Value<int> productId,
      Value<int> modifierGroupId,
    });

final class $$ProductModifiersTableReferences
    extends
        BaseReferences<_$AppDatabase, $ProductModifiersTable, ProductModifier> {
  $$ProductModifiersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProductsTable _productIdTable(_$AppDatabase db) =>
      db.products.createAlias(
        $_aliasNameGenerator(db.productModifiers.productId, db.products.id),
      );

  $$ProductsTableProcessedTableManager get productId {
    final $_column = $_itemColumn<int>('product_id')!;

    final manager = $$ProductsTableTableManager(
      $_db,
      $_db.products,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ModifierGroupsTable _modifierGroupIdTable(_$AppDatabase db) =>
      db.modifierGroups.createAlias(
        $_aliasNameGenerator(
          db.productModifiers.modifierGroupId,
          db.modifierGroups.id,
        ),
      );

  $$ModifierGroupsTableProcessedTableManager get modifierGroupId {
    final $_column = $_itemColumn<int>('modifier_group_id')!;

    final manager = $$ModifierGroupsTableTableManager(
      $_db,
      $_db.modifierGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_modifierGroupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ProductModifiersTableFilterComposer
    extends Composer<_$AppDatabase, $ProductModifiersTable> {
  $$ProductModifiersTableFilterComposer({
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

  $$ProductsTableFilterComposer get productId {
    final $$ProductsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableFilterComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ModifierGroupsTableFilterComposer get modifierGroupId {
    final $$ModifierGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.modifierGroupId,
      referencedTable: $db.modifierGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModifierGroupsTableFilterComposer(
            $db: $db,
            $table: $db.modifierGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProductModifiersTableOrderingComposer
    extends Composer<_$AppDatabase, $ProductModifiersTable> {
  $$ProductModifiersTableOrderingComposer({
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

  $$ProductsTableOrderingComposer get productId {
    final $$ProductsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableOrderingComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ModifierGroupsTableOrderingComposer get modifierGroupId {
    final $$ModifierGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.modifierGroupId,
      referencedTable: $db.modifierGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModifierGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.modifierGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProductModifiersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProductModifiersTable> {
  $$ProductModifiersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  $$ProductsTableAnnotationComposer get productId {
    final $$ProductsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableAnnotationComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ModifierGroupsTableAnnotationComposer get modifierGroupId {
    final $$ModifierGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.modifierGroupId,
      referencedTable: $db.modifierGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModifierGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.modifierGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProductModifiersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProductModifiersTable,
          ProductModifier,
          $$ProductModifiersTableFilterComposer,
          $$ProductModifiersTableOrderingComposer,
          $$ProductModifiersTableAnnotationComposer,
          $$ProductModifiersTableCreateCompanionBuilder,
          $$ProductModifiersTableUpdateCompanionBuilder,
          (ProductModifier, $$ProductModifiersTableReferences),
          ProductModifier,
          PrefetchHooks Function({bool productId, bool modifierGroupId})
        > {
  $$ProductModifiersTableTableManager(
    _$AppDatabase db,
    $ProductModifiersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductModifiersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductModifiersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductModifiersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> productId = const Value.absent(),
                Value<int> modifierGroupId = const Value.absent(),
              }) => ProductModifiersCompanion(
                id: id,
                productId: productId,
                modifierGroupId: modifierGroupId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int productId,
                required int modifierGroupId,
              }) => ProductModifiersCompanion.insert(
                id: id,
                productId: productId,
                modifierGroupId: modifierGroupId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProductModifiersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({productId = false, modifierGroupId = false}) {
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
                        if (productId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.productId,
                                    referencedTable:
                                        $$ProductModifiersTableReferences
                                            ._productIdTable(db),
                                    referencedColumn:
                                        $$ProductModifiersTableReferences
                                            ._productIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (modifierGroupId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.modifierGroupId,
                                    referencedTable:
                                        $$ProductModifiersTableReferences
                                            ._modifierGroupIdTable(db),
                                    referencedColumn:
                                        $$ProductModifiersTableReferences
                                            ._modifierGroupIdTable(db)
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

typedef $$ProductModifiersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProductModifiersTable,
      ProductModifier,
      $$ProductModifiersTableFilterComposer,
      $$ProductModifiersTableOrderingComposer,
      $$ProductModifiersTableAnnotationComposer,
      $$ProductModifiersTableCreateCompanionBuilder,
      $$ProductModifiersTableUpdateCompanionBuilder,
      (ProductModifier, $$ProductModifiersTableReferences),
      ProductModifier,
      PrefetchHooks Function({bool productId, bool modifierGroupId})
    >;
typedef $$ModifierOptionsTableCreateCompanionBuilder =
    ModifierOptionsCompanion Function({
      Value<int> id,
      required int modifierGroupId,
      required int supplyId,
      required double quantityDeducted,
      Value<double> priceExtra,
    });
typedef $$ModifierOptionsTableUpdateCompanionBuilder =
    ModifierOptionsCompanion Function({
      Value<int> id,
      Value<int> modifierGroupId,
      Value<int> supplyId,
      Value<double> quantityDeducted,
      Value<double> priceExtra,
    });

final class $$ModifierOptionsTableReferences
    extends
        BaseReferences<_$AppDatabase, $ModifierOptionsTable, ModifierOption> {
  $$ModifierOptionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ModifierGroupsTable _modifierGroupIdTable(_$AppDatabase db) =>
      db.modifierGroups.createAlias(
        $_aliasNameGenerator(
          db.modifierOptions.modifierGroupId,
          db.modifierGroups.id,
        ),
      );

  $$ModifierGroupsTableProcessedTableManager get modifierGroupId {
    final $_column = $_itemColumn<int>('modifier_group_id')!;

    final manager = $$ModifierGroupsTableTableManager(
      $_db,
      $_db.modifierGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_modifierGroupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SuppliesTable _supplyIdTable(_$AppDatabase db) =>
      db.supplies.createAlias(
        $_aliasNameGenerator(db.modifierOptions.supplyId, db.supplies.id),
      );

  $$SuppliesTableProcessedTableManager get supplyId {
    final $_column = $_itemColumn<int>('supply_id')!;

    final manager = $$SuppliesTableTableManager(
      $_db,
      $_db.supplies,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_supplyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ModifierOptionsTableFilterComposer
    extends Composer<_$AppDatabase, $ModifierOptionsTable> {
  $$ModifierOptionsTableFilterComposer({
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

  ColumnFilters<double> get quantityDeducted => $composableBuilder(
    column: $table.quantityDeducted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get priceExtra => $composableBuilder(
    column: $table.priceExtra,
    builder: (column) => ColumnFilters(column),
  );

  $$ModifierGroupsTableFilterComposer get modifierGroupId {
    final $$ModifierGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.modifierGroupId,
      referencedTable: $db.modifierGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModifierGroupsTableFilterComposer(
            $db: $db,
            $table: $db.modifierGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SuppliesTableFilterComposer get supplyId {
    final $$SuppliesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.supplyId,
      referencedTable: $db.supplies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SuppliesTableFilterComposer(
            $db: $db,
            $table: $db.supplies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ModifierOptionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ModifierOptionsTable> {
  $$ModifierOptionsTableOrderingComposer({
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

  ColumnOrderings<double> get quantityDeducted => $composableBuilder(
    column: $table.quantityDeducted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get priceExtra => $composableBuilder(
    column: $table.priceExtra,
    builder: (column) => ColumnOrderings(column),
  );

  $$ModifierGroupsTableOrderingComposer get modifierGroupId {
    final $$ModifierGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.modifierGroupId,
      referencedTable: $db.modifierGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModifierGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.modifierGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SuppliesTableOrderingComposer get supplyId {
    final $$SuppliesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.supplyId,
      referencedTable: $db.supplies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SuppliesTableOrderingComposer(
            $db: $db,
            $table: $db.supplies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ModifierOptionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ModifierOptionsTable> {
  $$ModifierOptionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get quantityDeducted => $composableBuilder(
    column: $table.quantityDeducted,
    builder: (column) => column,
  );

  GeneratedColumn<double> get priceExtra => $composableBuilder(
    column: $table.priceExtra,
    builder: (column) => column,
  );

  $$ModifierGroupsTableAnnotationComposer get modifierGroupId {
    final $$ModifierGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.modifierGroupId,
      referencedTable: $db.modifierGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModifierGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.modifierGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SuppliesTableAnnotationComposer get supplyId {
    final $$SuppliesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.supplyId,
      referencedTable: $db.supplies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SuppliesTableAnnotationComposer(
            $db: $db,
            $table: $db.supplies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ModifierOptionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ModifierOptionsTable,
          ModifierOption,
          $$ModifierOptionsTableFilterComposer,
          $$ModifierOptionsTableOrderingComposer,
          $$ModifierOptionsTableAnnotationComposer,
          $$ModifierOptionsTableCreateCompanionBuilder,
          $$ModifierOptionsTableUpdateCompanionBuilder,
          (ModifierOption, $$ModifierOptionsTableReferences),
          ModifierOption,
          PrefetchHooks Function({bool modifierGroupId, bool supplyId})
        > {
  $$ModifierOptionsTableTableManager(
    _$AppDatabase db,
    $ModifierOptionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ModifierOptionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ModifierOptionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ModifierOptionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> modifierGroupId = const Value.absent(),
                Value<int> supplyId = const Value.absent(),
                Value<double> quantityDeducted = const Value.absent(),
                Value<double> priceExtra = const Value.absent(),
              }) => ModifierOptionsCompanion(
                id: id,
                modifierGroupId: modifierGroupId,
                supplyId: supplyId,
                quantityDeducted: quantityDeducted,
                priceExtra: priceExtra,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int modifierGroupId,
                required int supplyId,
                required double quantityDeducted,
                Value<double> priceExtra = const Value.absent(),
              }) => ModifierOptionsCompanion.insert(
                id: id,
                modifierGroupId: modifierGroupId,
                supplyId: supplyId,
                quantityDeducted: quantityDeducted,
                priceExtra: priceExtra,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ModifierOptionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({modifierGroupId = false, supplyId = false}) {
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
                    if (modifierGroupId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.modifierGroupId,
                                referencedTable:
                                    $$ModifierOptionsTableReferences
                                        ._modifierGroupIdTable(db),
                                referencedColumn:
                                    $$ModifierOptionsTableReferences
                                        ._modifierGroupIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (supplyId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.supplyId,
                                referencedTable:
                                    $$ModifierOptionsTableReferences
                                        ._supplyIdTable(db),
                                referencedColumn:
                                    $$ModifierOptionsTableReferences
                                        ._supplyIdTable(db)
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

typedef $$ModifierOptionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ModifierOptionsTable,
      ModifierOption,
      $$ModifierOptionsTableFilterComposer,
      $$ModifierOptionsTableOrderingComposer,
      $$ModifierOptionsTableAnnotationComposer,
      $$ModifierOptionsTableCreateCompanionBuilder,
      $$ModifierOptionsTableUpdateCompanionBuilder,
      (ModifierOption, $$ModifierOptionsTableReferences),
      ModifierOption,
      PrefetchHooks Function({bool modifierGroupId, bool supplyId})
    >;
typedef $$ParkedOrdersTableCreateCompanionBuilder =
    ParkedOrdersCompanion Function({
      Value<int> id,
      Value<String?> customerName,
      required String itemsJson,
      Value<DateTime> parkedAt,
      required double totalAmount,
    });
typedef $$ParkedOrdersTableUpdateCompanionBuilder =
    ParkedOrdersCompanion Function({
      Value<int> id,
      Value<String?> customerName,
      Value<String> itemsJson,
      Value<DateTime> parkedAt,
      Value<double> totalAmount,
    });

class $$ParkedOrdersTableFilterComposer
    extends Composer<_$AppDatabase, $ParkedOrdersTable> {
  $$ParkedOrdersTableFilterComposer({
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

  ColumnFilters<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemsJson => $composableBuilder(
    column: $table.itemsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get parkedAt => $composableBuilder(
    column: $table.parkedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ParkedOrdersTableOrderingComposer
    extends Composer<_$AppDatabase, $ParkedOrdersTable> {
  $$ParkedOrdersTableOrderingComposer({
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

  ColumnOrderings<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemsJson => $composableBuilder(
    column: $table.itemsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get parkedAt => $composableBuilder(
    column: $table.parkedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ParkedOrdersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ParkedOrdersTable> {
  $$ParkedOrdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get itemsJson =>
      $composableBuilder(column: $table.itemsJson, builder: (column) => column);

  GeneratedColumn<DateTime> get parkedAt =>
      $composableBuilder(column: $table.parkedAt, builder: (column) => column);

  GeneratedColumn<double> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => column,
  );
}

class $$ParkedOrdersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ParkedOrdersTable,
          ParkedOrder,
          $$ParkedOrdersTableFilterComposer,
          $$ParkedOrdersTableOrderingComposer,
          $$ParkedOrdersTableAnnotationComposer,
          $$ParkedOrdersTableCreateCompanionBuilder,
          $$ParkedOrdersTableUpdateCompanionBuilder,
          (
            ParkedOrder,
            BaseReferences<_$AppDatabase, $ParkedOrdersTable, ParkedOrder>,
          ),
          ParkedOrder,
          PrefetchHooks Function()
        > {
  $$ParkedOrdersTableTableManager(_$AppDatabase db, $ParkedOrdersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ParkedOrdersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ParkedOrdersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ParkedOrdersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> customerName = const Value.absent(),
                Value<String> itemsJson = const Value.absent(),
                Value<DateTime> parkedAt = const Value.absent(),
                Value<double> totalAmount = const Value.absent(),
              }) => ParkedOrdersCompanion(
                id: id,
                customerName: customerName,
                itemsJson: itemsJson,
                parkedAt: parkedAt,
                totalAmount: totalAmount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> customerName = const Value.absent(),
                required String itemsJson,
                Value<DateTime> parkedAt = const Value.absent(),
                required double totalAmount,
              }) => ParkedOrdersCompanion.insert(
                id: id,
                customerName: customerName,
                itemsJson: itemsJson,
                parkedAt: parkedAt,
                totalAmount: totalAmount,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ParkedOrdersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ParkedOrdersTable,
      ParkedOrder,
      $$ParkedOrdersTableFilterComposer,
      $$ParkedOrdersTableOrderingComposer,
      $$ParkedOrdersTableAnnotationComposer,
      $$ParkedOrdersTableCreateCompanionBuilder,
      $$ParkedOrdersTableUpdateCompanionBuilder,
      (
        ParkedOrder,
        BaseReferences<_$AppDatabase, $ParkedOrdersTable, ParkedOrder>,
      ),
      ParkedOrder,
      PrefetchHooks Function()
    >;
typedef $$DiscountsTableCreateCompanionBuilder =
    DiscountsCompanion Function({
      Value<int> id,
      required String code,
      required double percentage,
      required String description,
      Value<bool> isActive,
    });
typedef $$DiscountsTableUpdateCompanionBuilder =
    DiscountsCompanion Function({
      Value<int> id,
      Value<String> code,
      Value<double> percentage,
      Value<String> description,
      Value<bool> isActive,
    });

class $$DiscountsTableFilterComposer
    extends Composer<_$AppDatabase, $DiscountsTable> {
  $$DiscountsTableFilterComposer({
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

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get percentage => $composableBuilder(
    column: $table.percentage,
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
}

class $$DiscountsTableOrderingComposer
    extends Composer<_$AppDatabase, $DiscountsTable> {
  $$DiscountsTableOrderingComposer({
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

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get percentage => $composableBuilder(
    column: $table.percentage,
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
}

class $$DiscountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiscountsTable> {
  $$DiscountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<double> get percentage => $composableBuilder(
    column: $table.percentage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);
}

class $$DiscountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiscountsTable,
          Discount,
          $$DiscountsTableFilterComposer,
          $$DiscountsTableOrderingComposer,
          $$DiscountsTableAnnotationComposer,
          $$DiscountsTableCreateCompanionBuilder,
          $$DiscountsTableUpdateCompanionBuilder,
          (Discount, BaseReferences<_$AppDatabase, $DiscountsTable, Discount>),
          Discount,
          PrefetchHooks Function()
        > {
  $$DiscountsTableTableManager(_$AppDatabase db, $DiscountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiscountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiscountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiscountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<double> percentage = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
              }) => DiscountsCompanion(
                id: id,
                code: code,
                percentage: percentage,
                description: description,
                isActive: isActive,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String code,
                required double percentage,
                required String description,
                Value<bool> isActive = const Value.absent(),
              }) => DiscountsCompanion.insert(
                id: id,
                code: code,
                percentage: percentage,
                description: description,
                isActive: isActive,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DiscountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiscountsTable,
      Discount,
      $$DiscountsTableFilterComposer,
      $$DiscountsTableOrderingComposer,
      $$DiscountsTableAnnotationComposer,
      $$DiscountsTableCreateCompanionBuilder,
      $$DiscountsTableUpdateCompanionBuilder,
      (Discount, BaseReferences<_$AppDatabase, $DiscountsTable, Discount>),
      Discount,
      PrefetchHooks Function()
    >;
typedef $$BundlesTableCreateCompanionBuilder =
    BundlesCompanion Function({
      Value<int> id,
      required String name,
      required double price,
      Value<bool> isActive,
    });
typedef $$BundlesTableUpdateCompanionBuilder =
    BundlesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<double> price,
      Value<bool> isActive,
    });

final class $$BundlesTableReferences
    extends BaseReferences<_$AppDatabase, $BundlesTable, Bundle> {
  $$BundlesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$BundleItemsTable, List<BundleItem>>
  _bundleItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.bundleItems,
    aliasName: $_aliasNameGenerator(db.bundles.id, db.bundleItems.bundleId),
  );

  $$BundleItemsTableProcessedTableManager get bundleItemsRefs {
    final manager = $$BundleItemsTableTableManager(
      $_db,
      $_db.bundleItems,
    ).filter((f) => f.bundleId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_bundleItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BundlesTableFilterComposer
    extends Composer<_$AppDatabase, $BundlesTable> {
  $$BundlesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> bundleItemsRefs(
    Expression<bool> Function($$BundleItemsTableFilterComposer f) f,
  ) {
    final $$BundleItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bundleItems,
      getReferencedColumn: (t) => t.bundleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BundleItemsTableFilterComposer(
            $db: $db,
            $table: $db.bundleItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BundlesTableOrderingComposer
    extends Composer<_$AppDatabase, $BundlesTable> {
  $$BundlesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BundlesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BundlesTable> {
  $$BundlesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  Expression<T> bundleItemsRefs<T extends Object>(
    Expression<T> Function($$BundleItemsTableAnnotationComposer a) f,
  ) {
    final $$BundleItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bundleItems,
      getReferencedColumn: (t) => t.bundleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BundleItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.bundleItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BundlesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BundlesTable,
          Bundle,
          $$BundlesTableFilterComposer,
          $$BundlesTableOrderingComposer,
          $$BundlesTableAnnotationComposer,
          $$BundlesTableCreateCompanionBuilder,
          $$BundlesTableUpdateCompanionBuilder,
          (Bundle, $$BundlesTableReferences),
          Bundle,
          PrefetchHooks Function({bool bundleItemsRefs})
        > {
  $$BundlesTableTableManager(_$AppDatabase db, $BundlesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BundlesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BundlesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BundlesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> price = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
              }) => BundlesCompanion(
                id: id,
                name: name,
                price: price,
                isActive: isActive,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required double price,
                Value<bool> isActive = const Value.absent(),
              }) => BundlesCompanion.insert(
                id: id,
                name: name,
                price: price,
                isActive: isActive,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BundlesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bundleItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (bundleItemsRefs) db.bundleItems],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (bundleItemsRefs)
                    await $_getPrefetchedData<
                      Bundle,
                      $BundlesTable,
                      BundleItem
                    >(
                      currentTable: table,
                      referencedTable: $$BundlesTableReferences
                          ._bundleItemsRefsTable(db),
                      managerFromTypedResult: (p0) => $$BundlesTableReferences(
                        db,
                        table,
                        p0,
                      ).bundleItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.bundleId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$BundlesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BundlesTable,
      Bundle,
      $$BundlesTableFilterComposer,
      $$BundlesTableOrderingComposer,
      $$BundlesTableAnnotationComposer,
      $$BundlesTableCreateCompanionBuilder,
      $$BundlesTableUpdateCompanionBuilder,
      (Bundle, $$BundlesTableReferences),
      Bundle,
      PrefetchHooks Function({bool bundleItemsRefs})
    >;
typedef $$BundleItemsTableCreateCompanionBuilder =
    BundleItemsCompanion Function({
      Value<int> id,
      required int bundleId,
      required int productId,
      Value<double> quantityRequired,
    });
typedef $$BundleItemsTableUpdateCompanionBuilder =
    BundleItemsCompanion Function({
      Value<int> id,
      Value<int> bundleId,
      Value<int> productId,
      Value<double> quantityRequired,
    });

final class $$BundleItemsTableReferences
    extends BaseReferences<_$AppDatabase, $BundleItemsTable, BundleItem> {
  $$BundleItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BundlesTable _bundleIdTable(_$AppDatabase db) =>
      db.bundles.createAlias(
        $_aliasNameGenerator(db.bundleItems.bundleId, db.bundles.id),
      );

  $$BundlesTableProcessedTableManager get bundleId {
    final $_column = $_itemColumn<int>('bundle_id')!;

    final manager = $$BundlesTableTableManager(
      $_db,
      $_db.bundles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bundleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ProductsTable _productIdTable(_$AppDatabase db) =>
      db.products.createAlias(
        $_aliasNameGenerator(db.bundleItems.productId, db.products.id),
      );

  $$ProductsTableProcessedTableManager get productId {
    final $_column = $_itemColumn<int>('product_id')!;

    final manager = $$ProductsTableTableManager(
      $_db,
      $_db.products,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BundleItemsTableFilterComposer
    extends Composer<_$AppDatabase, $BundleItemsTable> {
  $$BundleItemsTableFilterComposer({
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

  ColumnFilters<double> get quantityRequired => $composableBuilder(
    column: $table.quantityRequired,
    builder: (column) => ColumnFilters(column),
  );

  $$BundlesTableFilterComposer get bundleId {
    final $$BundlesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bundleId,
      referencedTable: $db.bundles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BundlesTableFilterComposer(
            $db: $db,
            $table: $db.bundles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductsTableFilterComposer get productId {
    final $$ProductsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableFilterComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BundleItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $BundleItemsTable> {
  $$BundleItemsTableOrderingComposer({
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

  ColumnOrderings<double> get quantityRequired => $composableBuilder(
    column: $table.quantityRequired,
    builder: (column) => ColumnOrderings(column),
  );

  $$BundlesTableOrderingComposer get bundleId {
    final $$BundlesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bundleId,
      referencedTable: $db.bundles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BundlesTableOrderingComposer(
            $db: $db,
            $table: $db.bundles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductsTableOrderingComposer get productId {
    final $$ProductsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableOrderingComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BundleItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BundleItemsTable> {
  $$BundleItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get quantityRequired => $composableBuilder(
    column: $table.quantityRequired,
    builder: (column) => column,
  );

  $$BundlesTableAnnotationComposer get bundleId {
    final $$BundlesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bundleId,
      referencedTable: $db.bundles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BundlesTableAnnotationComposer(
            $db: $db,
            $table: $db.bundles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductsTableAnnotationComposer get productId {
    final $$ProductsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableAnnotationComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BundleItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BundleItemsTable,
          BundleItem,
          $$BundleItemsTableFilterComposer,
          $$BundleItemsTableOrderingComposer,
          $$BundleItemsTableAnnotationComposer,
          $$BundleItemsTableCreateCompanionBuilder,
          $$BundleItemsTableUpdateCompanionBuilder,
          (BundleItem, $$BundleItemsTableReferences),
          BundleItem,
          PrefetchHooks Function({bool bundleId, bool productId})
        > {
  $$BundleItemsTableTableManager(_$AppDatabase db, $BundleItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BundleItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BundleItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BundleItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> bundleId = const Value.absent(),
                Value<int> productId = const Value.absent(),
                Value<double> quantityRequired = const Value.absent(),
              }) => BundleItemsCompanion(
                id: id,
                bundleId: bundleId,
                productId: productId,
                quantityRequired: quantityRequired,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int bundleId,
                required int productId,
                Value<double> quantityRequired = const Value.absent(),
              }) => BundleItemsCompanion.insert(
                id: id,
                bundleId: bundleId,
                productId: productId,
                quantityRequired: quantityRequired,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BundleItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bundleId = false, productId = false}) {
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
                    if (bundleId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.bundleId,
                                referencedTable: $$BundleItemsTableReferences
                                    ._bundleIdTable(db),
                                referencedColumn: $$BundleItemsTableReferences
                                    ._bundleIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (productId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.productId,
                                referencedTable: $$BundleItemsTableReferences
                                    ._productIdTable(db),
                                referencedColumn: $$BundleItemsTableReferences
                                    ._productIdTable(db)
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

typedef $$BundleItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BundleItemsTable,
      BundleItem,
      $$BundleItemsTableFilterComposer,
      $$BundleItemsTableOrderingComposer,
      $$BundleItemsTableAnnotationComposer,
      $$BundleItemsTableCreateCompanionBuilder,
      $$BundleItemsTableUpdateCompanionBuilder,
      (BundleItem, $$BundleItemsTableReferences),
      BundleItem,
      PrefetchHooks Function({bool bundleId, bool productId})
    >;
typedef $$ShiftsTableCreateCompanionBuilder =
    ShiftsCompanion Function({
      Value<int> id,
      Value<DateTime> startTime,
      Value<DateTime?> endTime,
      Value<double> startingFund,
    });
typedef $$ShiftsTableUpdateCompanionBuilder =
    ShiftsCompanion Function({
      Value<int> id,
      Value<DateTime> startTime,
      Value<DateTime?> endTime,
      Value<double> startingFund,
    });

final class $$ShiftsTableReferences
    extends BaseReferences<_$AppDatabase, $ShiftsTable, Shift> {
  $$ShiftsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CashMovementsTable, List<CashMovement>>
  _cashMovementsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.cashMovements,
    aliasName: $_aliasNameGenerator(db.shifts.id, db.cashMovements.shiftId),
  );

  $$CashMovementsTableProcessedTableManager get cashMovementsRefs {
    final manager = $$CashMovementsTableTableManager(
      $_db,
      $_db.cashMovements,
    ).filter((f) => f.shiftId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_cashMovementsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ShiftClosuresTable, List<ShiftClosure>>
  _shiftClosuresRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.shiftClosures,
    aliasName: $_aliasNameGenerator(db.shifts.id, db.shiftClosures.shiftId),
  );

  $$ShiftClosuresTableProcessedTableManager get shiftClosuresRefs {
    final manager = $$ShiftClosuresTableTableManager(
      $_db,
      $_db.shiftClosures,
    ).filter((f) => f.shiftId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_shiftClosuresRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ShiftsTableFilterComposer
    extends Composer<_$AppDatabase, $ShiftsTable> {
  $$ShiftsTableFilterComposer({
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

  ColumnFilters<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get startingFund => $composableBuilder(
    column: $table.startingFund,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> cashMovementsRefs(
    Expression<bool> Function($$CashMovementsTableFilterComposer f) f,
  ) {
    final $$CashMovementsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cashMovements,
      getReferencedColumn: (t) => t.shiftId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CashMovementsTableFilterComposer(
            $db: $db,
            $table: $db.cashMovements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> shiftClosuresRefs(
    Expression<bool> Function($$ShiftClosuresTableFilterComposer f) f,
  ) {
    final $$ShiftClosuresTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shiftClosures,
      getReferencedColumn: (t) => t.shiftId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftClosuresTableFilterComposer(
            $db: $db,
            $table: $db.shiftClosures,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ShiftsTableOrderingComposer
    extends Composer<_$AppDatabase, $ShiftsTable> {
  $$ShiftsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get startingFund => $composableBuilder(
    column: $table.startingFund,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ShiftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShiftsTable> {
  $$ShiftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<DateTime> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<double> get startingFund => $composableBuilder(
    column: $table.startingFund,
    builder: (column) => column,
  );

  Expression<T> cashMovementsRefs<T extends Object>(
    Expression<T> Function($$CashMovementsTableAnnotationComposer a) f,
  ) {
    final $$CashMovementsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cashMovements,
      getReferencedColumn: (t) => t.shiftId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CashMovementsTableAnnotationComposer(
            $db: $db,
            $table: $db.cashMovements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> shiftClosuresRefs<T extends Object>(
    Expression<T> Function($$ShiftClosuresTableAnnotationComposer a) f,
  ) {
    final $$ShiftClosuresTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shiftClosures,
      getReferencedColumn: (t) => t.shiftId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftClosuresTableAnnotationComposer(
            $db: $db,
            $table: $db.shiftClosures,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ShiftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShiftsTable,
          Shift,
          $$ShiftsTableFilterComposer,
          $$ShiftsTableOrderingComposer,
          $$ShiftsTableAnnotationComposer,
          $$ShiftsTableCreateCompanionBuilder,
          $$ShiftsTableUpdateCompanionBuilder,
          (Shift, $$ShiftsTableReferences),
          Shift,
          PrefetchHooks Function({
            bool cashMovementsRefs,
            bool shiftClosuresRefs,
          })
        > {
  $$ShiftsTableTableManager(_$AppDatabase db, $ShiftsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShiftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShiftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShiftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> startTime = const Value.absent(),
                Value<DateTime?> endTime = const Value.absent(),
                Value<double> startingFund = const Value.absent(),
              }) => ShiftsCompanion(
                id: id,
                startTime: startTime,
                endTime: endTime,
                startingFund: startingFund,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> startTime = const Value.absent(),
                Value<DateTime?> endTime = const Value.absent(),
                Value<double> startingFund = const Value.absent(),
              }) => ShiftsCompanion.insert(
                id: id,
                startTime: startTime,
                endTime: endTime,
                startingFund: startingFund,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$ShiftsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({cashMovementsRefs = false, shiftClosuresRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (cashMovementsRefs) db.cashMovements,
                    if (shiftClosuresRefs) db.shiftClosures,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (cashMovementsRefs)
                        await $_getPrefetchedData<
                          Shift,
                          $ShiftsTable,
                          CashMovement
                        >(
                          currentTable: table,
                          referencedTable: $$ShiftsTableReferences
                              ._cashMovementsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ShiftsTableReferences(
                                db,
                                table,
                                p0,
                              ).cashMovementsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.shiftId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (shiftClosuresRefs)
                        await $_getPrefetchedData<
                          Shift,
                          $ShiftsTable,
                          ShiftClosure
                        >(
                          currentTable: table,
                          referencedTable: $$ShiftsTableReferences
                              ._shiftClosuresRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ShiftsTableReferences(
                                db,
                                table,
                                p0,
                              ).shiftClosuresRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.shiftId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ShiftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShiftsTable,
      Shift,
      $$ShiftsTableFilterComposer,
      $$ShiftsTableOrderingComposer,
      $$ShiftsTableAnnotationComposer,
      $$ShiftsTableCreateCompanionBuilder,
      $$ShiftsTableUpdateCompanionBuilder,
      (Shift, $$ShiftsTableReferences),
      Shift,
      PrefetchHooks Function({bool cashMovementsRefs, bool shiftClosuresRefs})
    >;
typedef $$CashMovementsTableCreateCompanionBuilder =
    CashMovementsCompanion Function({
      Value<int> id,
      required int shiftId,
      required double amount,
      required String reason,
      Value<DateTime> date,
    });
typedef $$CashMovementsTableUpdateCompanionBuilder =
    CashMovementsCompanion Function({
      Value<int> id,
      Value<int> shiftId,
      Value<double> amount,
      Value<String> reason,
      Value<DateTime> date,
    });

final class $$CashMovementsTableReferences
    extends BaseReferences<_$AppDatabase, $CashMovementsTable, CashMovement> {
  $$CashMovementsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ShiftsTable _shiftIdTable(_$AppDatabase db) => db.shifts.createAlias(
    $_aliasNameGenerator(db.cashMovements.shiftId, db.shifts.id),
  );

  $$ShiftsTableProcessedTableManager get shiftId {
    final $_column = $_itemColumn<int>('shift_id')!;

    final manager = $$ShiftsTableTableManager(
      $_db,
      $_db.shifts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_shiftIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CashMovementsTableFilterComposer
    extends Composer<_$AppDatabase, $CashMovementsTable> {
  $$CashMovementsTableFilterComposer({
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

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  $$ShiftsTableFilterComposer get shiftId {
    final $$ShiftsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shiftId,
      referencedTable: $db.shifts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftsTableFilterComposer(
            $db: $db,
            $table: $db.shifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CashMovementsTableOrderingComposer
    extends Composer<_$AppDatabase, $CashMovementsTable> {
  $$CashMovementsTableOrderingComposer({
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

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  $$ShiftsTableOrderingComposer get shiftId {
    final $$ShiftsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shiftId,
      referencedTable: $db.shifts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftsTableOrderingComposer(
            $db: $db,
            $table: $db.shifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CashMovementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CashMovementsTable> {
  $$CashMovementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  $$ShiftsTableAnnotationComposer get shiftId {
    final $$ShiftsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shiftId,
      referencedTable: $db.shifts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftsTableAnnotationComposer(
            $db: $db,
            $table: $db.shifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CashMovementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CashMovementsTable,
          CashMovement,
          $$CashMovementsTableFilterComposer,
          $$CashMovementsTableOrderingComposer,
          $$CashMovementsTableAnnotationComposer,
          $$CashMovementsTableCreateCompanionBuilder,
          $$CashMovementsTableUpdateCompanionBuilder,
          (CashMovement, $$CashMovementsTableReferences),
          CashMovement,
          PrefetchHooks Function({bool shiftId})
        > {
  $$CashMovementsTableTableManager(_$AppDatabase db, $CashMovementsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CashMovementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CashMovementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CashMovementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> shiftId = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
              }) => CashMovementsCompanion(
                id: id,
                shiftId: shiftId,
                amount: amount,
                reason: reason,
                date: date,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int shiftId,
                required double amount,
                required String reason,
                Value<DateTime> date = const Value.absent(),
              }) => CashMovementsCompanion.insert(
                id: id,
                shiftId: shiftId,
                amount: amount,
                reason: reason,
                date: date,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CashMovementsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({shiftId = false}) {
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
                    if (shiftId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.shiftId,
                                referencedTable: $$CashMovementsTableReferences
                                    ._shiftIdTable(db),
                                referencedColumn: $$CashMovementsTableReferences
                                    ._shiftIdTable(db)
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

typedef $$CashMovementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CashMovementsTable,
      CashMovement,
      $$CashMovementsTableFilterComposer,
      $$CashMovementsTableOrderingComposer,
      $$CashMovementsTableAnnotationComposer,
      $$CashMovementsTableCreateCompanionBuilder,
      $$CashMovementsTableUpdateCompanionBuilder,
      (CashMovement, $$CashMovementsTableReferences),
      CashMovement,
      PrefetchHooks Function({bool shiftId})
    >;
typedef $$ShiftClosuresTableCreateCompanionBuilder =
    ShiftClosuresCompanion Function({
      Value<int> id,
      required int shiftId,
      Value<DateTime> closingTime,
      required double systemExpectedCash,
      required double declaredCash,
      required double difference,
      Value<String?> notes,
    });
typedef $$ShiftClosuresTableUpdateCompanionBuilder =
    ShiftClosuresCompanion Function({
      Value<int> id,
      Value<int> shiftId,
      Value<DateTime> closingTime,
      Value<double> systemExpectedCash,
      Value<double> declaredCash,
      Value<double> difference,
      Value<String?> notes,
    });

final class $$ShiftClosuresTableReferences
    extends BaseReferences<_$AppDatabase, $ShiftClosuresTable, ShiftClosure> {
  $$ShiftClosuresTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ShiftsTable _shiftIdTable(_$AppDatabase db) => db.shifts.createAlias(
    $_aliasNameGenerator(db.shiftClosures.shiftId, db.shifts.id),
  );

  $$ShiftsTableProcessedTableManager get shiftId {
    final $_column = $_itemColumn<int>('shift_id')!;

    final manager = $$ShiftsTableTableManager(
      $_db,
      $_db.shifts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_shiftIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ShiftClosuresTableFilterComposer
    extends Composer<_$AppDatabase, $ShiftClosuresTable> {
  $$ShiftClosuresTableFilterComposer({
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

  ColumnFilters<DateTime> get closingTime => $composableBuilder(
    column: $table.closingTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get systemExpectedCash => $composableBuilder(
    column: $table.systemExpectedCash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get declaredCash => $composableBuilder(
    column: $table.declaredCash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get difference => $composableBuilder(
    column: $table.difference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$ShiftsTableFilterComposer get shiftId {
    final $$ShiftsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shiftId,
      referencedTable: $db.shifts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftsTableFilterComposer(
            $db: $db,
            $table: $db.shifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShiftClosuresTableOrderingComposer
    extends Composer<_$AppDatabase, $ShiftClosuresTable> {
  $$ShiftClosuresTableOrderingComposer({
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

  ColumnOrderings<DateTime> get closingTime => $composableBuilder(
    column: $table.closingTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get systemExpectedCash => $composableBuilder(
    column: $table.systemExpectedCash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get declaredCash => $composableBuilder(
    column: $table.declaredCash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get difference => $composableBuilder(
    column: $table.difference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$ShiftsTableOrderingComposer get shiftId {
    final $$ShiftsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shiftId,
      referencedTable: $db.shifts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftsTableOrderingComposer(
            $db: $db,
            $table: $db.shifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShiftClosuresTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShiftClosuresTable> {
  $$ShiftClosuresTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get closingTime => $composableBuilder(
    column: $table.closingTime,
    builder: (column) => column,
  );

  GeneratedColumn<double> get systemExpectedCash => $composableBuilder(
    column: $table.systemExpectedCash,
    builder: (column) => column,
  );

  GeneratedColumn<double> get declaredCash => $composableBuilder(
    column: $table.declaredCash,
    builder: (column) => column,
  );

  GeneratedColumn<double> get difference => $composableBuilder(
    column: $table.difference,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$ShiftsTableAnnotationComposer get shiftId {
    final $$ShiftsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shiftId,
      referencedTable: $db.shifts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShiftsTableAnnotationComposer(
            $db: $db,
            $table: $db.shifts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShiftClosuresTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShiftClosuresTable,
          ShiftClosure,
          $$ShiftClosuresTableFilterComposer,
          $$ShiftClosuresTableOrderingComposer,
          $$ShiftClosuresTableAnnotationComposer,
          $$ShiftClosuresTableCreateCompanionBuilder,
          $$ShiftClosuresTableUpdateCompanionBuilder,
          (ShiftClosure, $$ShiftClosuresTableReferences),
          ShiftClosure,
          PrefetchHooks Function({bool shiftId})
        > {
  $$ShiftClosuresTableTableManager(_$AppDatabase db, $ShiftClosuresTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShiftClosuresTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShiftClosuresTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShiftClosuresTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> shiftId = const Value.absent(),
                Value<DateTime> closingTime = const Value.absent(),
                Value<double> systemExpectedCash = const Value.absent(),
                Value<double> declaredCash = const Value.absent(),
                Value<double> difference = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => ShiftClosuresCompanion(
                id: id,
                shiftId: shiftId,
                closingTime: closingTime,
                systemExpectedCash: systemExpectedCash,
                declaredCash: declaredCash,
                difference: difference,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int shiftId,
                Value<DateTime> closingTime = const Value.absent(),
                required double systemExpectedCash,
                required double declaredCash,
                required double difference,
                Value<String?> notes = const Value.absent(),
              }) => ShiftClosuresCompanion.insert(
                id: id,
                shiftId: shiftId,
                closingTime: closingTime,
                systemExpectedCash: systemExpectedCash,
                declaredCash: declaredCash,
                difference: difference,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ShiftClosuresTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({shiftId = false}) {
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
                    if (shiftId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.shiftId,
                                referencedTable: $$ShiftClosuresTableReferences
                                    ._shiftIdTable(db),
                                referencedColumn: $$ShiftClosuresTableReferences
                                    ._shiftIdTable(db)
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

typedef $$ShiftClosuresTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShiftClosuresTable,
      ShiftClosure,
      $$ShiftClosuresTableFilterComposer,
      $$ShiftClosuresTableOrderingComposer,
      $$ShiftClosuresTableAnnotationComposer,
      $$ShiftClosuresTableCreateCompanionBuilder,
      $$ShiftClosuresTableUpdateCompanionBuilder,
      (ShiftClosure, $$ShiftClosuresTableReferences),
      ShiftClosure,
      PrefetchHooks Function({bool shiftId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db, _db.products);
  $$SuppliesTableTableManager get supplies =>
      $$SuppliesTableTableManager(_db, _db.supplies);
  $$RecipesTableTableManager get recipes =>
      $$RecipesTableTableManager(_db, _db.recipes);
  $$SalesTableTableManager get sales =>
      $$SalesTableTableManager(_db, _db.sales);
  $$SaleItemsTableTableManager get saleItems =>
      $$SaleItemsTableTableManager(_db, _db.saleItems);
  $$InventoryLogsTableTableManager get inventoryLogs =>
      $$InventoryLogsTableTableManager(_db, _db.inventoryLogs);
  $$ModifierGroupsTableTableManager get modifierGroups =>
      $$ModifierGroupsTableTableManager(_db, _db.modifierGroups);
  $$ProductModifiersTableTableManager get productModifiers =>
      $$ProductModifiersTableTableManager(_db, _db.productModifiers);
  $$ModifierOptionsTableTableManager get modifierOptions =>
      $$ModifierOptionsTableTableManager(_db, _db.modifierOptions);
  $$ParkedOrdersTableTableManager get parkedOrders =>
      $$ParkedOrdersTableTableManager(_db, _db.parkedOrders);
  $$DiscountsTableTableManager get discounts =>
      $$DiscountsTableTableManager(_db, _db.discounts);
  $$BundlesTableTableManager get bundles =>
      $$BundlesTableTableManager(_db, _db.bundles);
  $$BundleItemsTableTableManager get bundleItems =>
      $$BundleItemsTableTableManager(_db, _db.bundleItems);
  $$ShiftsTableTableManager get shifts =>
      $$ShiftsTableTableManager(_db, _db.shifts);
  $$CashMovementsTableTableManager get cashMovements =>
      $$CashMovementsTableTableManager(_db, _db.cashMovements);
  $$ShiftClosuresTableTableManager get shiftClosures =>
      $$ShiftClosuresTableTableManager(_db, _db.shiftClosures);
}
