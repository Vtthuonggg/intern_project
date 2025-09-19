import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_app/app/events/logout_event.dart';

import 'package:flutter_app/bootstrap/helpers.dart';

import 'package:nylo_framework/nylo_framework.dart';
import '/app/controllers/controller.dart';

class SettingPage extends NyStatefulWidget {
  final Controller controller = Controller();

  static const path = '/setting';

  SettingPage({Key? key}) : super(key: key);

  @override
  _SettingPageState createState() => _SettingPageState();
}

class _SettingPageState extends NyState<SettingPage> {
  bool isAvailable = false;
  bool loading = true;

  @override
  init() async {
    super.init();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Future<String?> _getToken() async {
  //   try {
  //     return await NyStorage.read(StorageKey.userToken);
  //   } catch (e) {
  //     CustomToast.showToastOops(description: 'Lấy token thất bại');
  //     return null;
  //   }
  // }

  _logout() async {
    // String? token = await _getToken();
    // await api<AuthApiService>((request) => request.logout(token ?? ''));
    // _socketManager.dispose();
    await event<LogoutEvent>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cài đặt'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 20),
              buildLogout(),
            ],
          ),
        ),
      ),
    );
  }

  InkWell buildLogout() {
    return InkWell(
      onTap: () {
        _logout();
      },
      child: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Colors.grey[300]!,
                width: 1,
              ),
              bottom: BorderSide(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.logout,
                color: Colors.red,
              ),
              Text(
                'Đăng xuất',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          )),
    );
  }
}
