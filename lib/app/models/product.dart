import 'dart:convert';

import 'package:flutter_app/app/models/category.dart';
import 'package:nylo_framework/nylo_framework.dart';

class Product extends Model {
  int? id;
  String? name;
  String? code;
  String? unit;
  String? subUnit;
  String? description;
  List<String>? image;
  int? supplierId;
  int? weight;
  int? type;
  bool? status;
  bool? show;
  bool? isBatch;
  List<int>? categoryIds;
  List<CategoryModel>? categories;
  List<ProductVariant>? variants;
  num? vat;
  num? printCounter = 0;
  bool? isImei = false;
  bool? isIngredient;
  bool? isTopping;
  bool? useVat;
  Product({
    this.id,
    this.name,
    this.code,
    this.description,
    this.image,
    this.supplierId,
    this.weight,
    this.type,
    this.status,
    this.show,
    this.categoryIds,
    this.unit,
    this.variants,
    this.categories,
    this.isImei,
    this.isIngredient,
    this.isBatch,
    this.isTopping,
  });

  Product.fromJson(data) {
    List<dynamic> variantsList = data['variants'] ?? [];
    List<dynamic> categoriesList = data['categories'] ?? data['category'] ?? [];
    List<dynamic> imageList = [];
    if (data['image'] is String) {
      try {
        imageList = jsonDecode(data['image']);
      } catch (e) {
        imageList = [];
      }
    } else {
      imageList = data['image'] ?? [];
    }

    id = data['id'];
    name = data['name'].toString();
    code = data['code'].toString();
    description = data['description'].toString();
    // image = data['image'].split(',');
    image = imageList.cast<String>();
    supplierId = data['supplier_id'] ?? 0;
    weight = data['weight'];
    type = data['type'];
    show = data['show'];
    isBatch = data['is_batch'] ?? false;
    // status = data['status'];
    categoryIds = data['category_ids'] ?? [];
    variants = variantsList.map((v) => ProductVariant.fromJson(v)).toList();
    categories = categoriesList.map((v) => CategoryModel.fromJson(v)).toList();
    if (data['category'] != null &&
        data['category'].isNotEmpty &&
        data['category'][0]['vat'] != null) {
      vat = data['category'][0]['vat'];
    } else {
      vat = data['vat'] ?? 0;
    }

    unit = data['unit'] ?? '';
    isImei = data['is_imei'] ?? false;
    isIngredient = data['is_ingredient'] ?? false;
    isTopping = data['is_topping'] ?? false;
    useVat = data['use_vat'] ?? true;
    if (useVat == false) {
      vat = 0;
    }
  }

  toJson() {
    return {
      'name': name,
      'code': code,
      'description': description,
      'image': image,
      'is_ingredient': isIngredient ?? false,
      'is_topping': isTopping ?? false,
      'supplier_id': supplierId,
      'weight': weight,
      'type': type,
      'status': status,
      'show': show,
      'category_ids': categoryIds,
      'variants': variants?.map((v) => v.toJson()).toList(),
      'vat': vat,
      'unit': unit ?? '',
      'is_batch': isBatch ?? false,
      'is_imei': isImei ?? false,
      'use_vat': useVat ?? true,
    };
  }

  String asString() {
    return '${this.name} (mã: ${this.code})';
  }

  bool isEqual(Product? model) {
    return this.id == model?.id;
  }
}

class ProductVariant extends Model {
  bool? show;
  double? inStock;
  int? baseCost;
  int? retailCost;
  int? wholesaleCost;
  int? entryCost;

  num? available;

  int? id;
  String? sku;
  String? name;
  String? barcode;
  num? printCounter = 0;
  List<String>? image;
  List<dynamic>? attributeValues;
  Product? product;

  ProductVariant(
      {this.show,
      this.inStock,
      this.baseCost,
      this.retailCost,
      this.wholesaleCost,
      this.entryCost,
      this.attributeValues,
      this.product,
      this.image,
      this.available});

  ProductVariant.fromJson(data) {
    dynamic showValue = data['show'];
    List<dynamic> imageList = [];
    if (data['image'] != null) {
      if (data['image'] is String) {
        try {
          imageList = jsonDecode(data['image']);
        } catch (e) {
          imageList = [];
        }
      } else {
        imageList = data['image'];
      }
    } else if (data['product'] != null && data['product']['image'] != null) {
      if (data['product']['image'] is String) {
        try {
          imageList = jsonDecode(data['product']['image']);
        } catch (e) {
          imageList = [];
        }
      } else {
        imageList = data['product']['image'];
      }
    } else {
      imageList = [];
    }

    if (showValue is bool)
      show = showValue;
    else if (showValue is int && showValue == 1)
      show = true;
    else if (showValue is int && showValue == 0)
      show = false;
    else
      show = false;

    // baseCost = data['base_cost'];
    // retailCost = data['retail_cost'];
    // wholesaleCost = data['wholesale_cost'];
    // convert to int from double
    baseCost = data['base_cost']?.toInt();
    retailCost = data['retail_cost']?.toInt();
    wholesaleCost = data['wholesale_cost']?.toInt();

    available = data["available"]?.toDouble();

    inStock = (data['in_stock'] as num).toDouble();
    attributeValues = data['attribute_values'];
    barcode = data['bar_code'];
    entryCost = data['entry_cost'].toInt();
    id = data['id'];
    sku = data['sku'];
    name = data['name'];
    product =
        data['product'] != null ? Product.fromJson(data['product']) : null;
    image = imageList.cast<String>();
  }

  toJson() {
    return {
      'show': show,
      'in_stock': inStock,
      'base_cost': baseCost,
      'retail_cost': retailCost,
      'wholesale_cost': wholesaleCost,
      'attribute_values': attributeValues,
      'bar_code': barcode,
      'id': id,
      'sku': sku,
      'name': name,
      'image': image,
    };
  }

  asString() {
    return '${this.name} (SKU: ${this.sku})';
  }
}
