import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app/app/models/user.dart';
import '../../config/storage_keys.dart';
import '/app/networking/dio/base_api_service.dart';
import 'package:nylo_framework/nylo_framework.dart';

import 'dio/interceptors/logging_interceptor.dart';

class AuthApiService extends BaseApiService {
  AuthApiService({BuildContext? buildContext}) : super(buildContext);
  @override
  final interceptors = {
    // BearerAuthInterceptor: BearerAuthInterceptor(),
    LoggingInterceptor: LoggingInterceptor()
  };
  @override
  String get baseUrl => getEnv('API_BASE_URL');

  Future<User?> login(dynamic data) async {
    return await network(
        request: (request) => request.post("/login", data: data),
        handleFailure: (error) => throw error,
        handleSuccess: (response) async {
          User user = User.fromJson(response.data["data"]["user"]);
          await NyStorage.store(
              StorageKey.userToken, response.data["data"]["access_token"],
              inBackpack: true);

          return user;
        });
  }

  Future<dynamic> logout(String token) async {
    return await network(
        request: (request) => request.get("/logout"),
        headers: {
          "Authorization": "Bearer $token",
          "accept": "application/json"
        },
        handleFailure: (error) => throw error,
        handleSuccess: (response) async {
          return response.data;
        });
  }

  Future<dynamic> checkUser(String phoneNumber) async {
    return await network(
        request: (request) => request.post("/check-new", data: {
              "phone": phoneNumber,
            }),
        handleFailure: (error) => throw error,
        handleSuccess: (response) async {
          return response.data;
        });
  }

  Future<User?> socialLogin(String socialType, String token) async {
    return await network(
        request: (request) =>
            request.post("/login/$socialType", data: {"access_token": token}),
        handleFailure: (error) => throw error,
        handleSuccess: (response) async {
          User user = User.fromJson(response.data["data"]["user"]);

          await NyStorage.store(
              StorageKey.userToken, response.data["data"]["access_token"],
              inBackpack: true);

          return user;
        });
  }

  // Register
  Future register(String phone, String password, String password_confirmation,
      String? ref, String? shopName) async {
    return await network(
        request: (request) => request.post(
              "/register",
              data: {
                "phone": phone,
                "password": password,
                "password_confirmation": password_confirmation,
                // "name": name,
                // "email": email,
                "referral": ref,
                "shop_name": shopName,
                "device_type": Platform.isAndroid ? 2 : 1,
              },
            ),
        handleFailure: (error) => throw error,
        handleSuccess: (response) async {
          return response.data['data'];
        });
  }

  Future activeUser(String otp, String token) async {
    Dio dio = new Dio();
    dio.options.headers['accept'] = 'application/json';
    dio.options.headers['content-Type'] = 'application/json';
    dio.options.headers["authorization"] = "Bearer ${token}";
    dynamic response =
        await dio.post(baseUrl + "/user/active", data: {"otp": otp});
    User user = User.fromJson(response.data["data"]["user"]);
    await NyStorage.store(StorageKey.userToken, token, inBackpack: true);
    return user;
  }

  Future resetPassword(
      String phone, String password, String rePassword, int type) async {
    return await network(
        request: (request) =>
            request.post("/user/reset-password-success", data: {
              "phone": phone,
              "password": password,
              "password_confirmation": rePassword,
              "type": type
            }),
        handleFailure: (error) => throw error,
        handleSuccess: (response) async {
          return response.data;
        });
  }

  Future checkPhoneExist(String phone) async {
    return await network(
        request: (request) => request.post("/user/reset-password", data: {
              "phone": phone,
            }),
        handleFailure: (error) => throw error,
        handleSuccess: (response) async {
          return response.data;
        });
  }

  Future<List<dynamic>> getListCareer() async {
    return await network(
      request: (request) => request.get("/business"),
      bearerToken: Backpack.instance.read(StorageKey.userToken) ?? '',
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data['data'];
      },
    );
  }

  Future<dynamic> updateCareer(int id) async {
    return await network(
      request: (request) => request.post(
        "/user",
        data: {"business_id": id},
      ),
      bearerToken: Backpack.instance.read(StorageKey.userToken) ?? '',
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }

  Future requestOtp(String token) async {
    return await network(
        request: (request) => request.post("/otp"),
        headers: {
          "Authorization": "Bearer $token",
          "accept": "application/json"
        },
        handleFailure: (error) {
          throw error;
        },
        handleSuccess: (response) async {
          return response.data;
        });
  }

  Future requestResetOtp(String phone, int type) async {
    return await network(
        request: (request) => request
            .post("/user/reset-password", data: {"phone": phone, "type": type}),
        handleFailure: (error) => throw error,
        handleSuccess: (response) async {
          return response.data;
        });
  }

  Future resetPasswordConfirm(String phone, String otp, int type) async {
    return await network(
        request: (request) => request.post("/user/reset-password-confirm",
            data: {"phone": phone, "otp": otp, "type": type}),
        handleFailure: (error) => throw error,
        handleSuccess: (response) async {
          return response.data;
        });
  }
}
