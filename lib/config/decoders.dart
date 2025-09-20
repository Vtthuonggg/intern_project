import 'package:flutter_app/app/networking/auth_api_service.dart';
import 'package:flutter_app/app/networking/cash_book_api_service.dart';
import 'package:flutter_app/app/networking/dio/base_api_service.dart';
import 'package:flutter_app/app/networking/order_api_service.dart';
import 'package:flutter_app/app/networking/post_ingredients_api.dart';
import 'package:flutter_app/app/networking/product_api_service.dart';
import 'package:flutter_app/app/networking/room_api_service.dart';
import 'package:flutter_app/app/networking/upload_api_service.dart';
import 'package:flutter_app/app/networking/user_api_service.dart';
import '/app/models/user.dart';

/* Model Decoders
|--------------------------------------------------------------------------
| Model decoders are used in 'app/networking/' for morphing json payloads
| into Models.
|
| Learn more https://nylo.dev/docs/5.20.0/decoders#model-decoders
|-------------------------------------------------------------------------- */

final Map<Type, dynamic> modelDecoders = {
  List<User>: (data) =>
      List.from(data).map((json) => User.fromJson(json)).toList(),
  //
  User: (data) => User.fromJson(data),

  // User: (data) => User.fromJson(data),
};

/* API Decoders
| -------------------------------------------------------------------------
| API decoders are used when you need to access an API service using the
| 'api' helper. E.g. api<MyApiService>((request) => request.fetchData());
|
| Learn more https://nylo.dev/docs/5.20.0/decoders#api-decoders
|-------------------------------------------------------------------------- */

final Map<Type, BaseApiService> apiDecoders = {
  AuthApiService: AuthApiService(),
  UserApiService: UserApiService(),
  ProductApiService: ProductApiService(),
  OrderApiService: OrderApiService(),
  CashBookApiService: CashBookApiService(),
  UploadApiService: UploadApiService(),
  IngredientApi: IngredientApi(),
  RoomApiService: RoomApiService(),
};


/* Controller Decoders
| -------------------------------------------------------------------------
| Controller are used in pages.
|
| Learn more https://nylo.dev/docs/5.20.0/controllers
|-------------------------------------------------------------------------- */


