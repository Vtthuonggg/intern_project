import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_app/app/networking/dio/base_api_service.dart';
import 'package:flutter_app/app/networking/dio/interceptors/bearer_auth_interceptor.dart';
import 'package:nylo_framework/nylo_framework.dart';

class IngredientApi extends BaseApiService {
  IngredientApi({BuildContext? buildContext}) : super(buildContext);

  @override
  String get baseUrl => getEnv('API_BASE_URL');

  @override
  final interceptors = {
    BearerAuthInterceptor: BearerAuthInterceptor(),
    // LoggingInterceptor: LoggingInterceptor()
  };
  Future postIngredients(dynamic data) async {
    return await network(
      request: (request) => request.post("/order/ingredient", data: data),
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        return response.data;
      },
    );
  }
}
