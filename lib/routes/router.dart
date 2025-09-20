import 'package:flutter_app/resources/pages/authentication/confirm_otp_register_page.dart';
import 'package:flutter_app/resources/pages/authentication/confirm_otp_reset_page.dart';
import 'package:flutter_app/resources/pages/authentication/input_password_page.dart';
import 'package:flutter_app/resources/pages/authentication/login_new_page.dart';
import 'package:flutter_app/resources/pages/authentication/reset_password_page.dart';
import 'package:flutter_app/resources/pages/dash_board_page.dart';
import 'package:flutter_app/resources/pages/detail_add_storage_order_page.dart';
import 'package:flutter_app/resources/pages/introduction_page.dart';
import 'package:flutter_app/resources/pages/main_page.dart';
import 'package:flutter_app/resources/pages/order/detail_order_page.dart';
import 'package:flutter_app/resources/pages/order_list_all_page.dart';
import 'package:flutter_app/resources/pages/product/detail_product_page.dart';
import 'package:flutter_app/resources/pages/product/edit_product_page.dart';
import 'package:flutter_app/resources/pages/product/list_product_page.dart';
import 'package:flutter_app/resources/pages/product/setting_product_page.dart';
import 'package:flutter_app/resources/pages/setting/setting_page.dart';
import 'package:flutter_app/resources/pages/splash_page.dart';

import 'package:nylo_framework/nylo_framework.dart';

/* App Router
|--------------------------------------------------------------------------
| * [Tip] Create pages faster 🚀
| Run the below in the terminal to create new a page.
| "dart run nylo_framework:main make:page profile_page"
| Learn more https://nylo.dev/docs/5.20.0/router
|-------------------------------------------------------------------------- */

appRouter() => nyRoutes((router) {
      router.route(
        MainPage.path,
        (context) => MainPage(),
        transition: PageTransitionType.rightToLeft,
        pageTransitionSettings: const PageTransitionSettings(),
      );
      router.route(
        DashboardPage.path,
        (context) => DashboardPage(),
        transition: PageTransitionType.rightToLeft,
        pageTransitionSettings: const PageTransitionSettings(),
      );
      router.route(
        SplashPage.path,
        (context) => SplashPage(),
        transition: PageTransitionType.rightToLeft,
        pageTransitionSettings: const PageTransitionSettings(),
      );
      router.route(
        IntroductionPage.path,
        (context) => IntroductionPage(),
        transition: PageTransitionType.rightToLeft,
        pageTransitionSettings: const PageTransitionSettings(),
      );
      router.route(
        ConfirmOtpRegisterPage.path,
        (context) => ConfirmOtpRegisterPage(),
        transition: PageTransitionType.rightToLeft,
        pageTransitionSettings: const PageTransitionSettings(),
      );
      router.route(
        ConfirmOtpResetPage.path,
        (context) => ConfirmOtpResetPage(),
        transition: PageTransitionType.rightToLeft,
        pageTransitionSettings: const PageTransitionSettings(),
      );
      router.route(
        InputPasswordPage.path,
        (context) => InputPasswordPage(),
        transition: PageTransitionType.rightToLeft,
        pageTransitionSettings: const PageTransitionSettings(),
      );
      router.route(
        LoginPageNew.path,
        (context) => LoginPageNew(),
        transition: PageTransitionType.rightToLeft,
        pageTransitionSettings: const PageTransitionSettings(),
      );
      router.route(
        ResetPasswordPage.path,
        (context) => ResetPasswordPage(),
        transition: PageTransitionType.rightToLeft,
        pageTransitionSettings: const PageTransitionSettings(),
      );
      router.route(
        DetailAddStorageOrderPage.path,
        (context) => DetailAddStorageOrderPage(),
        transition: PageTransitionType.rightToLeft,
        pageTransitionSettings: const PageTransitionSettings(),
      );
      router.route(
        DetailOrderPage.path,
        (context) => DetailOrderPage(),
        transition: PageTransitionType.rightToLeft,
        pageTransitionSettings: const PageTransitionSettings(),
      );
      router.route(
        OrderListAllPage.path,
        (context) => OrderListAllPage(),
        transition: PageTransitionType.rightToLeft,
        pageTransitionSettings: const PageTransitionSettings(),
      );
      router.route(
        ListProductPage.path,
        (context) => ListProductPage(),
        transition: PageTransitionType.rightToLeft,
        pageTransitionSettings: const PageTransitionSettings(),
      );
      router.route(
        DetailProductPage.path,
        (context) => DetailProductPage(),
        transition: PageTransitionType.rightToLeft,
        pageTransitionSettings: const PageTransitionSettings(),
      );
      router.route(
        EditProductPage.path,
        (context) => EditProductPage(),
        transition: PageTransitionType.rightToLeft,
        pageTransitionSettings: const PageTransitionSettings(),
      );
      router.route(
        SettingProductPage.path,
        (context) => SettingProductPage(),
        transition: PageTransitionType.rightToLeft,
        pageTransitionSettings: const PageTransitionSettings(),
      );
      router.route(
        SettingPage.path,
        (context) => SettingPage(),
        transition: PageTransitionType.rightToLeft,
        pageTransitionSettings: const PageTransitionSettings(),
      );
    });
