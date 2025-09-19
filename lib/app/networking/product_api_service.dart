import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_app/app/models/storage_item.dart';
import 'package:flutter_app/app/models/storage_item.dart';
import 'package:form_builder_file_picker/form_builder_file_picker.dart';
import '/app/networking/dio/base_api_service.dart';
import 'package:nylo_framework/nylo_framework.dart';

import 'dio/interceptors/bearer_auth_interceptor.dart';
import 'dio/interceptors/logging_interceptor.dart';

class ProductApiService extends BaseApiService {
  ProductApiService({BuildContext? buildContext}) : super(buildContext);

  @override
  String get baseUrl => getEnv('API_BASE_URL');

  @override
  final interceptors = {
    BearerAuthInterceptor: BearerAuthInterceptor(),
    LoggingInterceptor: LoggingInterceptor()
  };

  Future<dynamic> listProduct(String? name, int page, int size) async {
    return await network(
      request: (request) => request.get("/product",
          queryParameters: {"name": name, "page": page, "per_page": size}),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        // List<Product> products = [];
        // response.data["data"].forEach((category) {
        //   products.add(Product.fromJson(category));
        // });
        return response.data;
      },
    );
  }

  Future<dynamic> listProductNew(String? name, int page, int size, int type,
      {int? storeId}) async {
    var queryParameters = {
      "name": name,
      "page": page,
      "type": type,
      "per_page": size,
    };
    if (storeId != null) {
      queryParameters['store_id'] = storeId;
    }
    return await network(
      request: (request) =>
          request.get("/product", queryParameters: queryParameters),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        // List<Product> products = [];
        // response.data["data"].forEach((category) {
        //   products.add(Product.fromJson(category));
        // });
        return response.data;
      },
    );
  }

  Future<void> deleteListProduct(List<dynamic> ids) async {
    return await network(
      request: (request) =>
          request.delete("/product/delete-list", data: {'ids': ids}),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }

  Future<StorageItem> getProudctIdTemp(String itemCode) async {
    return await network(
      request: (request) =>
          request.get("/product", queryParameters: {'item_code': itemCode}),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        var result = response.data["data"][0]['variants']
            .firstWhere((element) => element['item_code'] == itemCode);

        return StorageItem.fromJson(result);
      },
    );
  }

  Future<List<dynamic>> listVariant(String search,
      {int? page, int? size, int? type, int? cate}) async {
    Map<String, dynamic> queryParameters = {"name": search};
    if (page != null) {
      queryParameters["page"] = page;
    }
    if (size != null) {
      queryParameters["size"] = size;
    }
    if (type != null) {
      queryParameters["type"] = type;
    }
    if (cate != null) {
      queryParameters['category_id'] = cate;
    }

    return await network(
      request: (request) =>
          request.get("/v4/product", queryParameters: queryParameters),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        List<dynamic> products = [];
        response.data["data"].forEach((p) {
          products.add(p);
        });

        List<dynamic> variants = [];

        products.forEach((p) {
          p["variants"].forEach((v) {
            variants.add({
              ...v,
              "product": {
                ...p,
                "variants": null,
              }
            });
          });
        });
        return variants.map((e) => StorageItem.fromJson(e)).toList();
      },
    );
  }

  Future<List<dynamic>> listVariantV1(String search,
      {int? page, int? size, int? type, int? cate}) async {
    Map<String, dynamic> queryParameters = {"name": search};
    if (page != null) {
      queryParameters["page"] = page;
    }
    if (size != null) {
      queryParameters["size"] = size;
    }
    if (type != null) {
      queryParameters["type"] = type;
    }
    if (cate != null) {
      queryParameters['category_id'] = cate;
    }

    return await network(
      request: (request) =>
          request.get("/product", queryParameters: queryParameters),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        List<dynamic> products = [];
        response.data["data"].forEach((p) {
          products.add(p);
        });

        List<dynamic> variants = [];

        products.forEach((p) {
          p["variants"].forEach((v) {
            variants.add({
              ...v,
              "product": {
                ...p,
                "variants": null,
              }
            });
          });
        });
        return variants.map((e) => StorageItem.fromJson(e)).toList();
      },
    );
  }

  Future<List<dynamic>> listVariantTable(String search,
      {int? page, int? size, int? type, int? cate, bool? isTopping}) async {
    Map<String, dynamic> queryParameters = {
      "name": search,
    };
    if (page != null) {
      queryParameters["page"] = page;
    }
    if (size != null) {
      queryParameters["size"] = size;
    }
    if (type != null) {
      queryParameters["type"] = type;
    }
    if (cate != null) {
      queryParameters['category_id'] = cate;
    }
    if (isTopping != null) {
      queryParameters['is_topping'] = isTopping;
    }

    return await network(
      request: (request) =>
          request.get("/variant", queryParameters: queryParameters),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        List<dynamic> variants = [];
        response.data["data"].forEach((p) {
          variants.add(p);
        });

        // List<dynamic> variants = [];

        // products.forEach((p) {
        //   p["product"].forEach((v) {
        //     variants.add({
        //       ...v,
        //       "product": {
        //         ...p,
        //         "variants": null,
        //       }
        //     });
        //   });
        // });
        return variants.map((e) => StorageItem.fromJson(e)).toList();
      },
    );
  }

  Future<dynamic> createProduct(dynamic product) async {
    return await network(
      request: (request) => request.post("/product", data: product),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data["data"];
      },
    );
  }

  Future<dynamic> getProduct(int id, {int? storeId}) async {
    Map<String, dynamic> queryParameters = {};
    if (storeId != null) {
      queryParameters['store_id'] = storeId;
    }
    return await network(
      request: (request) =>
          request.get("/product/$id", queryParameters: queryParameters),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data["data"];
      },
    );
  }

  Future<StorageItem> getVariantByBarcode(String barcode) async {
    return await network(
      request: (request) => request.get("/product/bar-code/$barcode"),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return StorageItem.fromJson(response.data["data"]);
      },
    );
  }

  Future<dynamic> updateProduct(int id, dynamic product, {int? storeId}) async {
    Map<String, dynamic> queryParameters = {};
    if (storeId != null && storeId != -1) {
      queryParameters['store_id'] = storeId;
    }
    return await network(
      request: (request) => request.put("/product/$id",
          data: product, queryParameters: queryParameters),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data["data"];
      },
    );
  }

  Future<dynamic> updateVariantPrice(List<dynamic> payload) async {
    return await network(
      request: (request) =>
          request.post("/product/price", data: {"data": payload}),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data["data"];
      },
    );
  }

  Future<List<dynamic>> historyStorage(int variantId, {int? storeId}) async {
    Map<String, dynamic> queryParameters = {};
    if (storeId != null) {
      queryParameters['store_id'] = storeId;
    }
    return await network(
      request: (request) =>
          request.get("/product-storage/history-storage", data: {
        "variant_id": variantId,
      }),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data["data"];
      },
    );
  }

  Future deleteProduct(int id) async {
    return await network(
      request: (request) => request.delete("/product/$id"),
      handleFailure: (error) {
        return null;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }

  createBulkProduct(payload) {
    return network(
      request: (request) => request.post("/product/list", data: payload),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }

  Future<dynamic> uploadProductsExcel(PlatformFile file) async {
    FormData formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path != null ? file.path! : "",
          filename: file.name)
    });
    return await network(
        request: (request) => request.post("/product/import", data: formData),
        headers: {
          "Content-Type": "multipart/form-data",
        },
        handleFailure: (error) {
          print("uploadProductsExcel: \n${error}");
          return null;
        },
        handleSuccess: (response) async {
          return response;
        });
  }

  Future<List<dynamic>> listImeiOfVariant(int variantId) async {
    return await network(
      request: (request) =>
          request.get("/variant/imei/$variantId?per_page=1000"),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) {
        return response.data["data"]?["data"]?.cast<dynamic>() ?? [];
      },
    );
  }

  Future show(int id, bool show) async {
    return await network(
      request: (request) =>
          request.post("/product/$id/show", data: {"show": show}),
      handleFailure: (error) {
        return null;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }

  Future<dynamic> listProductHaveBarcode(
      String? name, int page, int size) async {
    return await network(
      request: (request) => request.get("/product", queryParameters: {
        "name": name,
        "page": page,
        "per_page": size,
        "in": true
      }),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }

  Future<List<dynamic>> getCalendarEvent(
      num roomId, String fromDate, String toDate) async {
    Map<String, dynamic> queryParameters = {
      "room_id": roomId,
      // "start_date": fromDate,
      // "end_date": toDate,
      "type": "list"
    };

    return await network(
      request: (request) =>
          request.get("/calendar", queryParameters: queryParameters),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        List<dynamic> items = [];
        response.data["data"].forEach((p) {
          items.add(p);
        });

        return items;
      },
    );
  }

  Future<List<dynamic>> getDetailEvent(num roomId, String day) async {
    Map<String, dynamic> queryParameters = {"room_id": roomId, "date": day};

    return await network(
      request: (request) =>
          request.get("/calendar/detail", queryParameters: queryParameters),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        List<dynamic> items = [];
        response.data["data"].forEach((p) {
          items.add(p);
        });

        return items;
      },
    );
  }

  Future<List<dynamic>> createCalendarSchedule(
      num roomId, List<String> date, String hourStart, String hourEnd,
      {String? phone, String? name, num? customerId, String? note}) async {
    Map<String, dynamic> body = {
      "room_id": roomId,
      // "phone": phone,
      // "name": name,
      "date": date,
      "hour_start": hourStart,
      "hour_end": hourEnd,
    };
    if (phone?.isNotEmpty ?? false) {
      body.addAll({"phone": phone});
    }
    if (name?.isNotEmpty ?? false) {
      body.addAll({"name": name});
    }
    if (customerId == null) {
    } else {
      body.addAll({"customer_id": customerId});
    }
    if (note?.isNotEmpty ?? false) {
      body.addAll({"note": note});
    }
    return await network(
      request: (request) => request.post("/calendar", data: body),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data["data"];
      },
    );
  }

  Future<List<dynamic>> updateCalendarSchedule(num roomId, num scheduleId,
      List<String> date, String hourStart, String hourEnd,
      {String? phone, String? name, num? customerId, String? note}) async {
    Map<String, dynamic> body = {
      "room_id": roomId,
      // "phone": phone,
      // "name": name,
      "date": date,
      "hour_start": hourStart,
      "hour_end": hourEnd,
      "phone": phone,
      "name": name,
      "note": note
    };
    if (customerId == null) {
    } else {
      body.addAll({"customer_id": customerId});
    }

    var path = '/calendar';
    if (date.length == 1) {
      path = "/calendar/$scheduleId";
    }
    return await network(
      request: (request) => request.put(path, data: body),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data["data"];
      },
    );
  }

  Future<List<dynamic>> deleteMultiCalendarSchedule(
      num roomId, num customerId, List<String> date) async {
    Map<String, dynamic> body = {
      "room_id": roomId,
      "customer_id": customerId,
      "date": date
    };

    return await network(
      request: (request) => request.delete("/calendar/delete-many", data: body),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data["data"];
      },
    );
  }

  Future<List<dynamic>> deleteSingleCalendarSchedule(num id) async {
    return await network(
      request: (request) => request.delete("/calendar/${id}"),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data["data"];
      },
    );
  }

  Future<dynamic> listToppings(String? name, int page, int size) async {
    return await network(
      request: (request) => request.get("/product", queryParameters: {
        "name": name,
        "page": page,
        "per_page": size,
        "is_topping": true
      }),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }
}
