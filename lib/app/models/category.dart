import 'package:flutter/material.dart';
import 'package:flutter_app/app/models/product.dart';
import 'package:nylo_framework/nylo_framework.dart';

class CategoryModel extends Model {
  int? id;
  String? name;
  String? description;
  String? descriptionEn;
  int? status;
  String? createdAt;
  String? updatedAt;
  List<Product>? products;
  bool isSelected = false;
  num? vat;
  TextEditingController txtVat = TextEditingController(text: "0");
  CategoryModel();

  CategoryModel.fromJson(data) {
    List<dynamic> productList = data['products'] ?? [];
    id = data['id'];
    name = data['name'];
    description = data['description'];
    descriptionEn = data['description_en'];
    status = data['status'];
    createdAt = data['created_at'];
    updatedAt = data['updated_at'];
    products = productList.map((v) => Product.fromJson(v)).toList();
    vat = data['vat'];
  }

  toJson() {
    return {
      "id": id,
      "name": name,
      "description": description,
      "description_en": descriptionEn,
      "status": status,
      "created_at": createdAt,
      "updated_at": updatedAt,
      "products": products?.map((v) => v.toJson()).toList(),
      "vat": vat,
    };
  }

  asString() {
    return "$name";
  }

  copyWith() {
    return CategoryModel.fromJson(this.toJson());
  }
}
