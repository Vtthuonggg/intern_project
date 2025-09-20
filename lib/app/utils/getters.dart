import 'dart:convert';
import 'dart:developer';

import 'package:flutter_app/config/constant.dart';
import 'package:nylo_framework/nylo_framework.dart';

String getVariantFirstImage(dynamic variant) {
  if (variant?.image != null && variant.image.isNotEmpty) {
    return variant.image.first;
  }
  if (variant?.product != null &&
      variant.product.image != null &&
      variant.product.image.isNotEmpty) {
    return variant.product.image.first;
  }
  return PLACE_HOLD_URL;
}

String getProductFirstImage(dynamic product) {
  if (product?.image != null && product?.image!.isNotEmpty) {
    return product.image!.first;
  } else if (product?.variants != null && product!.variants!.isNotEmpty) {
    if (product.variants![0].image != null &&
        product.variants![0].image!.isNotEmpty) {
      return product.variants![0].image!.first;
    }
  }
  return PLACE_HOLD_URL;
}

String getHomeScannerProductImage(dynamic product) {
  if (product?.variantImage != null && product?.variantImage!.isNotEmpty) {
    return product.variantImage!.first;
  } else if (product?.image != null && product?.image!.isNotEmpty) {
    return product.image!.first;
  }
  return PLACE_HOLD_URL;
}

String getOrderItemFirstImage(dynamic order) {
  if (order["order_detail"] != null && order["order_detail"]!.isNotEmpty) {
    dynamic imageData = order["order_detail"]!.first?["product"]?["image"];
    dynamic imageList = imageData != null ? jsonDecode(imageData) : null;
    if (imageList != null && imageList.isNotEmpty) {
      return imageList.first;
    }
  }

  return PLACE_HOLD_URL;
}
