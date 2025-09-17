import 'package:flutter/cupertino.dart';
import 'package:flutter_app/app/events/logout_event.dart';
import 'package:flutter_app/bootstrap/helpers.dart';
import 'package:flutter_app/config/storage_keys.dart';
import 'package:nylo_framework/nylo_framework.dart';

class BearerAuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    String? userToken = Backpack.instance.read(StorageKey.userToken);
    if (userToken != null) {
      options.headers
          .addAll({"Authorization": "Bearer $userToken", "storeId": -1});
    }
    return super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    int? statusCode = err.response?.statusCode;
    if (statusCode == 401) {
      debugPrint("BearerAuthInterceptor: 401");
      event<LogoutEvent>();
    }
    handler.next(err);
  }
}
