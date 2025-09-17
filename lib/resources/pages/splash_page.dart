import 'package:flutter/material.dart';
import 'package:flutter_app/resources/pages/introduction_page.dart';
import 'package:nylo_framework/nylo_framework.dart';
import '../../app/events/login_event.dart';
import '../../app/models/user.dart';
import '../../app/networking/user_api_service.dart';
import '../../bootstrap/helpers.dart';
import '../../config/common_define.dart';
import '/app/controllers/controller.dart';

class SplashPage extends NyStatefulWidget {
  final Controller controller = Controller();

  static const path = '/splash';

  SplashPage({Key? key}) : super(key: key);

  @override
  _SplashPageState createState() => _SplashPageState();
}

class _SplashPageState extends NyState<SplashPage>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    _loadConfigAndData();
  }

  Future<void> _loadConfigAndData() async {
    try {
      var data = await api<UserApiService>((request) => request.currentUser());

      if (data != null) {
        event<LoginEvent>(data: {
          'user': User.fromJson(data),
        });

        await getFCMTokenAndSave();
      }
    } catch (e) {
      routeTo(IntroductionPage.path,
          navigationType: NavigationType.pushReplace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                getImageAsset("logo.png"),
                height: 100, // Adjust the size of the logo
                width: 100,
              )
            ],
          ),
        ),
      ),
    );
  }
}
