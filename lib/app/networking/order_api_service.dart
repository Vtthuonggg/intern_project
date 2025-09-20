import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import '/app/networking/dio/base_api_service.dart';
import 'package:nylo_framework/nylo_framework.dart';

import 'dio/interceptors/bearer_auth_interceptor.dart';
import 'dio/interceptors/logging_interceptor.dart';

class OrderApiService extends BaseApiService {
  OrderApiService({BuildContext? buildContext}) : super(buildContext);

  @override
  String get baseUrl => getEnv('API_BASE_URL');

  String get basePrintUrl => getEnv('ESC_GEN_URL');
  String get basePrintUrlV2 => getEnv('ESC_GEN_URL_2');

  @override
  final interceptors = {
    BearerAuthInterceptor: BearerAuthInterceptor(),
    LoggingInterceptor: LoggingInterceptor()
  };
  Future createOrder(dynamic payload) async {
    return await network(
      request: (request) => request.post("/order", data: payload),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data["data"];
      },
    );
  }

  Future updateOrder(dynamic payload, int id) async {
    return await network(
      request: (request) => request.put("/order/$id", data: payload),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data["data"];
      },
    );
  }

  Future updateSuccessOrder(dynamic payload, int id) async {
    return await network(
      request: (request) =>
          request.put("/order/update-success/$id", data: payload),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data["data"];
      },
    );
  }

  Future getReceiptHtml(int orderId, int? invoiceType) async {
    String endPoint = 'order/print';

    if (invoiceType != null && invoiceType == 1) {
      endPoint = 'print-t3';
    }

    return await network(
      request: (request) => request.post("/$endPoint/$orderId"),
      headers: {
        "Content-Type": "application/json;charset=UTF-8",
      },
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }

  Future listOrder(int page, int size, DateTimeRange? rage, String? search,
      String? sort, List<int> statusOrder, List<int> statusPayment,
      {dynamic customerId}) async {
    Map<String, dynamic> queryParameters = {
      "per_page": size,
      "page": page,
      "type": 1,
      "customer_id": customerId == -1 ? "null" : customerId,
    };

    if (rage != null) {
      String startDate = rage.start.toString().split(' ')[0];
      String endDate = rage.end.toString().split(' ')[0];

      queryParameters.addAll({
        "start_date": startDate,
        "end_date": endDate,
      });
    }
    if (statusOrder.length > 0) {
      queryParameters.addAll({'status_order': json.encode(statusOrder)});
    }
    if (statusPayment.length > 0) {
      queryParameters.addAll({'status': json.encode(statusPayment)});
    }
    if (search != null) {
      queryParameters.addAll({
        "search": search,
      });
    }

    if (sort != null) {
      queryParameters.addAll({
        "sort": sort,
      });
    }

    return await network(
      request: (request) =>
          request.get("/order", queryParameters: queryParameters),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }

  Future listOrderV3(int page, int size, DateTimeRange? rage, String? search,
      String? sort, List<int> statusOrder, List<int> statusPayment,
      {dynamic customerId,
      int? storeId,
      String? dateType = 'created_at'}) async {
    Map<String, dynamic> queryParameters = {
      "per_page": size,
      "page": page,
      "type": 1,
      "customer_id": customerId == -1 ? "null" : customerId,
      "store_id": storeId,
      "date_type": dateType,
    };

    if (rage != null) {
      String startDate = rage.start.toString().split(' ')[0];
      String endDate = rage.end.toString().split(' ')[0];

      queryParameters.addAll({
        "start_date": startDate,
        "end_date": endDate,
      });
    }
    if (statusOrder.length > 0) {
      queryParameters.addAll({'status_order': json.encode(statusOrder)});
    }
    if (statusPayment.length > 0) {
      queryParameters.addAll({'status': json.encode(statusPayment)});
    }
    if (search != null) {
      queryParameters.addAll({
        "search": search,
      });
    }

    if (sort != null) {
      queryParameters.addAll({
        "sort": sort,
      });
    }

    return await network(
      request: (request) =>
          request.get("/order-v3", queryParameters: queryParameters),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }

  Future listOrderHistory(int page, int size, int id, String? sort) async {
    Map<String, dynamic> queryParameters = {
      "per_page": size,
      "page": page,
      "type": 1,
    };

    if (sort != null) {
      queryParameters.addAll({
        "sort": sort,
      });
    }
    queryParameters.addAll({
      "customer_id": id,
    });
    return await network(
      request: (request) =>
          request.get("/order", queryParameters: queryParameters),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }

  Future listOrderHistoryBySupplier(
      int page, int size, int supplierId, String? sort) async {
    Map<String, dynamic> queryParameters = {
      "per_page": size,
      "page": page,
      "type": 2,
    };

    if (sort != null) {
      queryParameters.addAll({
        "sort": sort,
      });
    }
    queryParameters.addAll({
      "supplier_id": supplierId,
    });

    return await network(
      request: (request) =>
          request.get("/order", queryParameters: queryParameters),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }

  Future listOrderOfVariant(int type, int variantId, int page,
      {int size = 6, DateTimeRange? rage}) async {
    Map<String, dynamic> queryParameters = {
      "per_page": size,
      "page": page,
      "type": type,
      "variant_id": variantId,
    };
    if (rage != null) {
      String startDate = rage.start.toString().split(' ')[0];
      String endDate = rage.end.toString().split(' ')[0];
      queryParameters.addAll({
        "start_date": startDate,
        "end_date": endDate,
      });
    }
    return await network(
      request: (request) =>
          request.get("/order/variant", queryParameters: queryParameters),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }

  Future listAddStorageOrder(
      int page,
      int size,
      DateTimeRange? rage,
      String? search,
      String? sort,
      List<int> statusOrder,
      List<int> statusPayment) async {
    Map<String, dynamic> queryParameters = {
      "per_page": size,
      "page": page,
      "type": 2,
    };

    if (rage != null) {
      String startDate = rage.start.toString().split(' ')[0];
      String endDate = rage.end.toString().split(' ')[0];

      queryParameters.addAll({
        "start_date": startDate,
        "end_date": endDate,
      });
    }
    if (statusOrder.length > 0) {
      queryParameters.addAll({'status_order': json.encode(statusOrder)});
    }
    if (statusPayment.length > 0) {
      queryParameters.addAll({'status': json.encode(statusPayment)});
    }
    if (search != null) {
      queryParameters.addAll({
        "search": search,
      });
    }

    if (sort != null) {
      queryParameters.addAll({
        "sort": sort,
      });
    }

    return await network(
      request: (request) =>
          request.get("/order-v2", queryParameters: queryParameters),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }

  Future listAddStorageOrderV3(
      int page,
      int size,
      DateTimeRange? rage,
      String? search,
      String? sort,
      List<int> statusOrder,
      List<int> statusPayment,
      {int? storeId,
      String? dateType = 'created_at'}) async {
    Map<String, dynamic> queryParameters = {
      "per_page": size,
      "page": page,
      "type": 2,
      "store_id": storeId,
      "date_type": dateType,
    };

    if (rage != null) {
      String startDate = rage.start.toString().split(' ')[0];
      String endDate = rage.end.toString().split(' ')[0];

      queryParameters.addAll({
        "start_date": startDate,
        "end_date": endDate,
      });
    }
    if (statusOrder.length > 0) {
      queryParameters.addAll({'status_order': json.encode(statusOrder)});
    }
    if (statusPayment.length > 0) {
      queryParameters.addAll({'status': json.encode(statusPayment)});
    }
    if (search != null) {
      queryParameters.addAll({
        "search": search,
      });
    }

    if (sort != null) {
      queryParameters.addAll({
        "sort": sort,
      });
    }
    if (storeId != null) {
      queryParameters['store_id'] = storeId;
    }
    return await network(
      request: (request) =>
          request.get("/order-v3", queryParameters: queryParameters),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }

  Future listAddStorageOrderOfVariant(
      int variantId, DateTimeRange? rage) async {
    Map<String, dynamic> queryParameters = {
      "per_page": 1000,
      "type": 2,
      "variant_id": variantId,
    };
    if (rage != null) {
      String startDate = rage.start.toString().split(' ')[0];
      String endDate = rage.end.toString().split(' ')[0];

      queryParameters.addAll({
        "start_date": startDate,
        "end_date": endDate,
      });
    }
    return await network(
      request: (request) =>
          request.get("/order", queryParameters: queryParameters),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }

  Future updateStatusOrder(int id, int status) async {
    return await network(
      request: (request) =>
          request.patch("/order/$id", data: {"status_order": status}),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data["data"];
      },
    );
  }

  Future addPayment(int id, dynamic payload) async {
    return await network(
      request: (request) => request.post("/order/payment/$id", data: payload),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }

  Future addShippingCode(int id, dynamic payload) async {
    return await network(
      request: (request) =>
          request.post("/order/shipping-code/$id", data: payload),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }

  Future detailOrder(int id, {int? storeId}) async {
    Map<String, dynamic> queryParameters = {};
    if (storeId != null) {
      queryParameters['store_id'] = storeId;
    }
    return await network(
      request: (request) =>
          request.get("/order/$id", queryParameters: queryParameters),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data["data"];
      },
    );
  }

  Future cancelOrder(int id, {bool? isReturn}) async {
    Map<String, dynamic> payload = {};
    if (isReturn != null) {
      payload = {"is_return": isReturn};
    }
    return await network(
      request: (request) => request.post("/order/cancel/$id", data: payload),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response;
      },
    );
  }

  Future deleteOrder(int id) async {
    return await network(
      request: (request) => request.delete("/order/$id"),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data["data"];
      },
    );
  }

  Future returnOrder(dynamic payload) async {
    return await network(
      request: (request) => request.post("/order", data: payload),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data["data"];
      },
    );
  }

  Future createTableReservation(dynamic payload) async {
    return await network(
      request: (request) => request.post("/order/service", data: payload),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data["data"];
      },
    );
  }

  updateTableReservation(int orderId, Map<String, dynamic> orderPayload) {
    return network(
      request: (request) => request.put("/order/$orderId", data: orderPayload),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }

  Future uploadImeiFile(int variantId, MultipartFile file) async {
    final Map<String, dynamic> payload = {
      "file": file,
    };
    return await network(
      request: (request) => request.post(
        "/product/import-imei/$variantId",
        data: FormData.fromMap(payload),
      ),
      headers: {
        "Content-Type": "multipart/form-data",
      },
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }

  Future getBatchId(int id, Map<String, dynamic> payload) async {
    return await network(
      request: (request) => request.post("/variant/batch/$id", data: payload),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data['data'][0];
      },
    );
  }

  Future deleteBatch(int variantId, int batchId) async {
    return await network(
      request: (request) => request
          .delete("/variant/$variantId/batch", data: {'batch_id': batchId}),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }

  // 1: size 58mm,
  // 2: size 76mm
  Future getInvoiceImageNode(String html, int printerSize) async {
    final size = printerSize == 1 ? 384 : 546;
    return await network(
      request: (request) => request.post(basePrintUrl + "/image", data: {
        "html": html,
        "type": "base64",
        "selector": ".container",
        "width": size
      }),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }

  Future getInvoiceText(int orderId) async {
    return await network(
      request: (request) => request.get(basePrintUrlV2 + "/order/$orderId"),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        log(response.data.toString());
        return response.data;
      },
    );
  }

  // 1: size 58mm,
  // 2: size 76mm
  Future getInvoiceImageNodeV2(
      int orderId, int? userType, int invoiceId, int printerSize) async {
    final size = printerSize == 1 ? 384 : 546;
    return await network(
      request: (request) => request.post(basePrintUrlV2 + "/image", data: {
        "orderId": orderId,
        "userType": userType,
        "temp": invoiceId,
        "width": size
      }),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }

  // 1: size 58mm,
  // 2: size 76mm
  Future getInvoiceImage(int orderId, int type, int orderType, int? invoiceType,
      {int? sendInvoice = null}) async {
    Map<String, dynamic> queryParameters = {};
    if (sendInvoice != null) {
      queryParameters["send_invoice"] = sendInvoice;
      queryParameters["type"] = type;
    } else {
      queryParameters["type"] = type;
    }
    if (orderType == 2) {
      if (invoiceType != null && invoiceType == 1) {
        return await network(
          request: (request) => request.post("/print-t3/image-buy/$orderId",
              queryParameters: queryParameters),
          handleFailure: (error) {
            throw error;
          },
          handleSuccess: (response) async {
            return response.data;
          },
        );
      }
      return await network(
        request: (request) =>
            request.post("/order/$orderId/print_buy?type=$type"),
        handleFailure: (error) {
          print(error);
          throw error;
        },
        handleSuccess: (response) async {
          return response.data;
        },
      );
    } else {
      if (invoiceType != null && invoiceType == 1) {
        return await network(
          request: (request) =>
              request.post("/print-t3/image/$orderId?type=$type"),
          handleFailure: (error) {
            throw error;
          },
          handleSuccess: (response) async {
            return response.data;
          },
        );
      }
      return await network(
        request: (request) => request.post("/order/$orderId/print?type=$type"),
        handleFailure: (error) {
          throw error;
        },
        handleSuccess: (response) async {
          return response.data;
        },
      );
    }
  }

  Future updateOrderCode(int id, dynamic payload) async {
    return await network(
      request: (request) =>
          request.patch("/order/update-code/$id", data: payload),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }

  Future getDefaultStatus(int type) async {
    return await network(
      request: (request) => request.get('/config/status-order?type=$type'),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }

  Future updateDefaultStatus(dynamic payload) async {
    return await network(
      request: (request) => request.put('/config/status-order', data: payload),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }

  Future getListFee() async {
    return await network(
      request: (request) => request.get("/order/cost"),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data['data'];
      },
    );
  }

  Future editFee(int id, dynamic payload) async {
    return await network(
      request: (request) => request.put("/order/cost/$id", data: payload),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }

  Future createNewFee(dynamic payload) async {
    return await network(
      request: (request) => request.post("/order/cost", data: payload),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }

  Future deleteFee(int id) async {
    return await network(
      request: (request) => request.delete("/order/cost/$id"),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }
}
