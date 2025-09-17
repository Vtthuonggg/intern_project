import 'package:flutter/cupertino.dart';
import 'package:flutter_app/app/events/logout_event.dart';
import 'package:flutter_app/app/models/user.dart';
import 'package:flutter_app/bootstrap/helpers.dart';
import 'package:nylo_framework/nylo_framework.dart';

class ApiKeyInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    String? apiKey = Auth.user<User>()?.apiKey;
    if (apiKey != null) {
      options.queryParameters.addAll({"apiKey": apiKey});
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
