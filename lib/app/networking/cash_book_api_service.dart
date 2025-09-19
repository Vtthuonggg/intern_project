import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_app/bootstrap/helpers.dart';
import '/app/networking/dio/base_api_service.dart';
import 'package:nylo_framework/nylo_framework.dart';

import 'dio/interceptors/bearer_auth_interceptor.dart';
import 'dio/interceptors/logging_interceptor.dart';

class CashBookApiService extends BaseApiService {
  CashBookApiService({BuildContext? buildContext}) : super(buildContext);

  @override
  String get baseUrl => getEnv('API_BASE_URL');

  @override
  final interceptors = {
    BearerAuthInterceptor: BearerAuthInterceptor(),
    // LoggingInterceptor: LoggingInterceptor()
  };

  Future createPayment(dynamic payload) async {
    return await network(
      request: (request) =>
          request.post("/receipt-payment/payment", data: payload),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data["data"];
      },
    );
  }

  Future createReceipt(dynamic payload) async {
    return await network(
      request: (request) =>
          request.post("/receipt-payment/receipt", data: payload),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data["data"];
      },
    );
  }

  Future createPaymentOrReceipt(dynamic payload, int type) async {
    if (type == 2) return createPayment(payload);
    return createReceipt(payload);
  }

  Future updaetPayment(int id, dynamic payload) async {
    print(id);
    return await network(
      request: (request) =>
          request.put("/receipt-payment/payment/${id}", data: payload),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data["data"];
      },
    );
  }

  Future deleteReceiptPayment(int id) async {
    print(id);
    return await network(
      request: (request) => request.delete("/receipt-payment/${id}"),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data["data"];
      },
    );
  }

  Future updateReceipt(int id, dynamic payload) async {
    return await network(
      request: (request) =>
          request.put("/receipt-payment/receipt/${id}", data: payload),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data["data"];
      },
    );
  }

  Future printReceipt(int id) async {
    return await network(
      request: (request) => request.post("/receipt-payment/receipt/${id}"),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }

  Future printPayment(int id) async {
    return await network(
      request: (request) => request.post("/receipt-payment/payment/${id}"),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }

  Future updatePaymentOrReceipt(int id, dynamic payload, int type) async {
    if (type == 2) return updaetPayment(id, payload);
    return updateReceipt(id, payload);
  }

  Future deleteCashBook(int id, {bool? isReturn, int? storeId}) async {
    Map<String, dynamic> payload = {};
    if (isReturn != null) {
      payload["is_return"] = isReturn;
    }
    Map<String, dynamic> queryParams = {};
    if (storeId != null) {
      queryParams["store_id"] = storeId;
    }
    return await network(
      request: (request) => request.delete("/order/$id",
          data: payload, queryParameters: queryParams),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data["data"];
      },
    );
  }

  Future detailCashBook(int id) async {
    return await network(
      request: (request) => request.get("/receipt-payment/${id}"),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data["data"];
      },
    );
  }
}
