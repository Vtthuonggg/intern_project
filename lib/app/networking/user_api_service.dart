import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import '/app/networking/dio/base_api_service.dart';
import 'package:nylo_framework/nylo_framework.dart';

import 'dio/interceptors/bearer_auth_interceptor.dart';

class UserApiService extends BaseApiService {
  UserApiService({BuildContext? buildContext}) : super(buildContext);

  @override
  String get baseUrl => getEnv('API_BASE_URL');
  @override
  final interceptors = {
    BearerAuthInterceptor: BearerAuthInterceptor(),
    // LoggingInterceptor: LoggingInterceptor()
  };

  /// Example API Request
  Future<dynamic> fetchData() async {
    return await network(
      request: (request) => request.get("/endpoint-path"),
    );
  }

  Future currentUser() async {
    return await network(
        request: (request) => request.get("/user/info"),
        handleFailure: (error) => throw error,
        handleSuccess: (response) async {
          return response.data["data"];
        });
  }

  Future deleteAccount() async {
    return await network(
        request: (request) => request.delete("/user"),
        handleFailure: (error) => throw error,
        handleSuccess: (response) async {
          return response.data;
        });
  }

  Future saveDeviceToken(String token) async {
    return await network(
        request: (request) => request.post("/user/device-token", data: {
              "device_token": token,
              "device_type": Platform.isIOS ? 1 : 2
            }),
        handleFailure: (error) => throw error,
        handleSuccess: (response) async {
          return response.data;
        });
  }

  Future getHomeBanner() async {
    return await network(
      request: (request) => request.get("/banner"),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data['data'];
      },
    );
  }

  Future homeSearchAll(String keyword, int page, int size) async {
    Map<String, dynamic> queryParameters = {
      "page": page,
      "search": keyword,
      "per_page": size,
    };
    return await network(
      request: (request) =>
          request.get("/search", queryParameters: queryParameters),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }

  Future changePassword(dynamic payload) async {
    return await network(
        request: (request) =>
            request.post("/user/change-password", data: payload),
        handleFailure: (error) => throw error,
        handleSuccess: (response) async {
          return response.data;
        });
  }

  Future updateInfo(dynamic payload) async {
    return await network(
        request: (request) => request.post("/user", data: payload),
        handleFailure: (error) => throw error,
        handleSuccess: (response) async {
          return response.data;
        });
  }

  Future buyPurchase(String productId) async {
    return await network(
        request: (request) => request.post("/purchase", data: {
              "transactionReceipt": '',
              "transactionId": '',
              "productId": productId
            }),
        handleFailure: (error) => throw error,
        handleSuccess: (response) async {
          return response.data;
        });
  }

  Future checkTimeShowData() async {
    return await network(
      request: (request) => request.get("/check-hide-ios"),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }

  Future getVersion() async {
    return await network(
      request: (request) => request.get("/version"),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }
}
