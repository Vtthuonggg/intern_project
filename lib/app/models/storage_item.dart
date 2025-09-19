import 'package:flutter/cupertino.dart';
import 'package:flutter_app/app/models/product.dart';
import 'package:flutter_app/app/utils/formatters.dart';
import 'package:nylo_framework/nylo_framework.dart';

class StorageItem extends Model {
  int? id;
  String? name;
  List<String>? image;
  String? sku;
  String? code;
  num? inStock;
  num? available;
  num? temporality;
  num? baseCost;
  num? saveBaseCost;
  num? entryCost;
  num? retailCost;
  num? wholesaleCost;
  num? copyBaseCost;
  num? copyRetailCost;
  num? copyWholesaleCost;
  int? active;
  Product? product;
  int? productId;
  String? createdAt;
  String? updatedAt;
  num? discount;
  num? copyDiscount;
  num quantity = 1;
  int? orderDetailId;
  List<dynamic>? ingredient = [];
  DiscountType discountType = DiscountType.percent;
  DiscountType copyDiscountType = DiscountType.percent;
  TextEditingController txtQuantity = TextEditingController(text: '1');
  TextEditingController txtDiscount = TextEditingController();
  TextEditingController txtVAT = TextEditingController();
  TextEditingController txtPrice = TextEditingController();
  UniqueKey? quantityKey = UniqueKey();
  UniqueKey? discountKey = UniqueKey();
  UniqueKey? priceKey = UniqueKey();
  UniqueKey? sizeKey = UniqueKey();
  UniqueKey? vatKey = UniqueKey();
  UniqueKey? categoryKey = UniqueKey();
  bool isSelected = false;
  List<String> imei = [];
  List<String> selectedImei = [];
  bool isBuyAlways = false;
  String? barcode;
  bool? isNameOnly = false;
  String? size = '';
  int? categoryId = 0;
  int? orderIngredientId;
  List<dynamic>? batch = [];
  List<dynamic>? selectedBatch = [];
  List<dynamic> conversionUnit = [];
  List<dynamic>? productNotes = [];
  List<StorageItem> toppings = [];
  int? toppingId;
  String? dosage = '';
  num? subUnitQuantity;
  bool? isTopping;
  List? policies;
  num? policyPrice;
  num? overriddenPrice;
  bool isManuallyEdited = false;
  bool isUserTyping = false;
  dynamic selectedSalePromotion;
  FoodType? foodType;

  StorageItem.fromJson(data) {
    id = data['id'];
    name = data['name'];
    image = data['image'] != null ? List<String>.from(data['image']) : null;
    sku = data['sku'];
    ingredient = data['ingredients'] ?? [];
    orderDetailId = data['order_detail_id'] ?? null;
    inStock =
        data['in_stock'] != null ? (data['in_stock'] as num).toDouble() : null;
    baseCost = data['base_cost'] != null ? data['base_cost']?.toInt() : null;
    saveBaseCost = data['base_cost']?.toInt();
    retailCost = data['retail_cost']?.toInt();
    wholesaleCost = data['wholesale_cost']?.toInt();
    entryCost = data['entry_cost']?.toInt();
    copyBaseCost = data['base_cost']?.toInt();
    copyRetailCost = data['retail_cost']?.toInt();
    copyWholesaleCost = data['wholesale_cost']?.toInt();
    active = data['active'];
    batch = data['batch'] ?? [];
    conversionUnit = data['conversion_unit'] ?? [];
    if (data['product'] != null) {
      product = Product.fromJson(data['product']);
      quantity = ((data['product']['is_batch'] ?? false) ||
              (data['product']['is_imei'] ?? false))
          ? 0
          : 1;
    }
    isTopping = data['is_topping'] ?? data['product'] != null
        ? (data['product']['is_topping'] ?? false)
        : false;
    if (isTopping!) {
      quantity = data['quantity'] ?? 1;
    }
    productId = data['product_id'];
    createdAt = data['created_at'];
    updatedAt = data['updated_at'];
    discount = data['discount'];
    discountType = DiscountType.fromValueRequest(data['discount_type'] ?? 1);
    copyDiscountType =
        DiscountType.fromValueRequest(data['discount_type'] ?? 1);
    copyDiscount = data['discount'];
    available = data['available'] != null
        ? (data['available'] as num).toDouble()
        : null;
    temporality = data['temporality'] != null
        ? (data['temporality'] as num).toDouble()
        : null;
    code = data['code'];
    isBuyAlways = data['is_buy_alway'] ?? true;
    barcode = data['bar_code']?.toString();
    toppings = data['topping'] ?? [];
    categoryId = getFirstCategoryId(data);
    toppingId = data['topping_id'] ?? null;
    try {
      imei = data['imei'] != null
          ? List<String>.from(data['imei'].map((x) => x['imei']))
          : [];
    } catch (e) {
      imei = [];
    }
    txtVAT.text = product != null ? roundQuantity(product?.vat ?? 0) : '';
    policies = data['policies'];
    foodType =
        data['food_type'] != null ? FoodType.fromJson(data['food_type']) : null;
  }

  toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'sku': sku,
      'in_stock': inStock,
      'base_cost': baseCost,
      'entry_cost': entryCost,
      'retail_cost': retailCost,
      'wholesale_cost': wholesaleCost,
      'active': active,
      'product': product?.toJson(),
      'product_id': productId,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'discount': discount,
      'discount_type': discountType.getValueRequest(),
      'available': available,
      'temporality': temporality,
      'code': code,
      'ingredients': ingredient,
      'batch': batch,
      'conversion_unit': conversionUnit,
      'order_detail_id': orderDetailId,
      'notes': productNotes,
      'topping': toppings,
      'is_topping': isTopping,
      'imei': imei
    };
  }

  String asString() {
    return '${this.name} - ${this.sku}';
  }

  bool isEqual(Product? model) {
    return this.id == model?.id;
  }

  // constructor
  StorageItem({
    this.ingredient,
    this.orderIngredientId,
    this.id,
    this.name,
    this.retailCost,
    this.discount,
    this.quantity = 1,
    this.barcode,
    this.discountType = DiscountType.percent,
    Product? product,
  });
}

int? getFirstCategoryId(dynamic data) {
  final categories = data['product']?['category'];

  if (categories == null) {
    return null;
  }

  if (categories.isNotEmpty) {
    return categories.first['id'];
  }

  return null;
}

class FoodType extends Model {
  String? name;
  int? value;

  FoodType.fromJson(Map<String, dynamic> data) {
    name = data['name'];
    value = data['value'];
  }

  toJson() {
    return {
      'name': name,
      'value': value,
    };
  }

  static FoodType fromValueRequest(int? value) {
    switch (value) {
      case 1:
        return FoodType(name: 'Đồ uống', value: 1);
      case 2:
        return FoodType(name: 'Đồ ăn', value: 2);
      default:
        return FoodType(name: 'Không', value: null);
    }
  }

  FoodType({this.name, this.value});

  @override
  String toString() {
    return 'FoodType{name: $name, value: $value}';
  }
}

enum DiscountType {
  percent,
  price;

  int getValueRequest() {
    switch (this) {
      case DiscountType.percent:
        return 1;
      case DiscountType.price:
        return 2;
    }
  }

  static DiscountType fromValueRequest(int value) {
    switch (value) {
      case 1:
        return DiscountType.percent;
      case 2:
        return DiscountType.price;
      default:
        return DiscountType.percent;
    }
  }
}
