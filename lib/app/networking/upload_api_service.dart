import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app/app/networking/dio/interceptors/bearer_auth_interceptor.dart';
import '/app/networking/dio/base_api_service.dart';
import 'package:nylo_framework/nylo_framework.dart';

class UploadApiService extends BaseApiService {
  UploadApiService({BuildContext? buildContext}) : super(buildContext);

  @override
  String get baseUrl => getEnv('API_BASE_URL');
  String get baseUrlAsset => getEnv('ASSET_HOST');

  @override
  final interceptors = {BearerAuthInterceptor: BearerAuthInterceptor()};

  Future<dynamic> fetchData() async {
    return await network(
      request: (request) => request.get("/endpoint-path"),
    );
  }

  Future<List<String>> uploadFiles(List<String> paths) async {
    FormData formData = FormData();

    paths.forEach((path) {
      File file = File(path);
      formData.files.add(MapEntry(
        "images[]",
        MultipartFile.fromFileSync(file.path,
            filename: file.path.split("/").last),
      ));
    });
    formData.fields.add(MapEntry(
        "token", base64Encode(utf8.encode(Auth.user().id.toString()))));
    return await network(
      request: (request) =>
          request.post(baseUrlAsset + "/uploads", data: formData),
      headers: {
        "Content-Type": "multipart/form-data",
      },
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        List<dynamic> paths = response.data["data"];

        List<String> urls = paths.cast<String>().map((path) {
          return path;
        }).toList();
        return urls;
      },
    );
  }

  Future<List<String>> uploadFilesVariant(List<String> paths) async {
    FormData formData = FormData();

    paths.forEach((path) {
      File file = File(path);
      formData.files.add(MapEntry(
        "images[]",
        MultipartFile.fromFileSync(file.path,
            filename: file.path.split("/").last),
      ));
    });

    return await network(
      request: (request) =>
          request.post(baseUrlAsset + "/uploads/variant", data: formData),
      headers: {
        "Content-Type": "multipart/form-data",
      },
      handleFailure: (error) {
        throw error;
      },
      handleSuccess: (response) async {
        List<dynamic> paths = response.data["data"];
        List<String> urls = paths.cast<String>().map((path) {
          return path;
        }).toList();
        return urls;
      },
    );
  }
}
