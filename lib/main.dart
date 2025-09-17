import 'dart:io';

import 'package:dart_ping_ios/dart_ping_ios.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/resources/pages/splash_page.dart';
import 'package:flutter_app/resources/themes/styles/light_theme_colors.dart';
import 'package:nylo_framework/nylo_framework.dart';
import 'bootstrap/app.dart';
import 'bootstrap/boot.dart';
import 'config/common_define.dart';
import 'config/restart_app_config.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _setOrientationForDevice();
  DartPingIOS.register();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    systemNavigationBarColor: createColor(LightThemeColors().primaryAccent),
  ));
  if (Platform.isAndroid) {
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
      final isProduct = getEnv("APP_ENV", defaultValue: true) == "production";
      if (isProduct) {
        FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
      }
    } catch (e) {
      print(e);
    }
  }
  Nylo nylo = await Nylo.init(setup: Boot.nylo, setupFinished: Boot.finished);
  runApp(RestartWidget(
    child: AppBuild(
      navigatorKey: NyNavigator.instance.router.navigatorKey,
      onGenerateRoute: nylo.router!.generator(),
      debugShowCheckedModeBanner: false,
      initialRoute: SplashPage.path,
      navigatorObservers: (Platform.isAndroid)
          ? [
              FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
            ]
          : [],
      themeData: ThemeData(
        dialogTheme: DialogTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.black.withOpacity(0.1),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          contentTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          actionsPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        textSelectionTheme: TextSelectionThemeData(
          selectionColor: Colors.grey.shade400.withOpacity(0.3),
          selectionHandleColor: Colors.grey.shade600,
          cursorColor: Colors.grey.shade700,
        ),
        brightness: Brightness.light,
        primarySwatch: createColor(LightThemeColors().primaryAccent),
        inputDecorationTheme: InputDecorationTheme(
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              width: 1.0,
            ),
          ),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.resolveWith<Color>(
              (Set<MaterialState> states) {
                if (states.contains(MaterialState.selected)) {
                  return createColor(LightThemeColors().primaryAccent);
                }

                return Colors.white;
              },
            ),
            foregroundColor: MaterialStateProperty.resolveWith<Color>(
              (Set<MaterialState> states) {
                if (states.contains(MaterialState.selected)) {
                  return Colors.white;
                }

                return createColor(LightThemeColors().primaryAccent);
              },
            ),
            overlayColor: MaterialStateProperty.all<Color>(
              Colors.white.withOpacity(.1),
            ),
            shape: MaterialStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            side: MaterialStateProperty.all<BorderSide>(
              BorderSide(
                color: createColor(LightThemeColors().primaryAccent),
              ),
            ),
          ),
        ),
        datePickerTheme: DatePickerThemeData(
          backgroundColor: Colors.white,
          headerBackgroundColor: createColor(LightThemeColors().primaryAccent),
          headerForegroundColor: Colors.white,
          weekdayStyle: TextStyle(color: Colors.black87),
          dayStyle: TextStyle(color: Colors.black87),
          yearStyle: TextStyle(color: Colors.black87),
          dayForegroundColor: MaterialStateProperty.resolveWith<Color?>(
            (Set<MaterialState> states) {
              if (states.contains(MaterialState.selected)) {
                return Colors.white;
              }
              if (states.contains(MaterialState.hovered)) {
                return createColor(LightThemeColors().primaryAccent);
              }
              return Colors.black87;
            },
          ),
          dayBackgroundColor: MaterialStateProperty.resolveWith<Color?>(
            (Set<MaterialState> states) {
              if (states.contains(MaterialState.selected)) {
                return createColor(LightThemeColors().primaryAccent);
              }
              return Colors.white;
            },
          ),
          todayBackgroundColor: MaterialStateProperty.resolveWith<Color?>(
            (Set<MaterialState> states) {
              if (states.contains(MaterialState.selected)) {
                return createColor(LightThemeColors().primaryAccent);
              }
              return Colors.white;
            },
          ),
          todayForegroundColor: MaterialStateProperty.resolveWith<Color?>(
            (Set<MaterialState> states) {
              if (states.contains(MaterialState.selected)) {
                return Colors.white;
              }
              return createColor(LightThemeColors().primaryAccent);
            },
          ),
          todayBorder: BorderSide(
            color: createColor(LightThemeColors().primaryAccent),
            width: 1,
          ),
          surfaceTintColor: Colors.transparent,
        ),
        timePickerTheme: TimePickerThemeData(
          backgroundColor: Colors.white,
          dialBackgroundColor: Colors.grey.shade50,
          hourMinuteColor: MaterialStateColor.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return Colors.blue.shade100;
            }
            return Colors.grey.shade100;
          }),
          hourMinuteTextColor: MaterialStateColor.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return Colors.blue.shade700;
            }
            return Colors.grey.shade800;
          }),
          dayPeriodColor: MaterialStateColor.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return Colors.blue.shade100;
            }
            return Colors.grey.shade100;
          }),
          dayPeriodTextColor: MaterialStateColor.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return Colors.blue.shade700;
            }
            return Colors.grey.shade800;
          }),
          dialHandColor: Colors.blue.shade600,
          dialTextColor: Colors.black87,
          entryModeIconColor: Colors.blue.shade600,
          helpTextStyle: TextStyle(color: Colors.grey.shade700),
          hourMinuteTextStyle: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w600,
          ),
          dayPeriodTextStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        colorScheme: ColorScheme.light(
          primary: createColor(LightThemeColors().primaryAccent),
          onPrimary: Colors.white,
          secondary:
              createColor(LightThemeColors().primaryAccent).withOpacity(0.2),
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black87,
          surfaceVariant: Colors.white,
          outline: Colors.grey.shade300,
          primaryContainer: Colors.white,
          onPrimaryContainer: Colors.black87,
          background: Colors.white,
          onBackground: Colors.black87,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.grey.shade600,
          foregroundColor: Colors.white,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: MaterialStateProperty.resolveWith<Color>(
            (Set<MaterialState> states) {
              if (states.contains(MaterialState.selected)) {
                return createColor(LightThemeColors().primaryAccent);
              }
              return Colors.white;
            },
          ),
          trackColor: MaterialStateProperty.resolveWith<Color>(
            (Set<MaterialState> states) {
              if (states.contains(MaterialState.selected)) {
                return createColor(LightThemeColors().primaryAccent)
                    .withOpacity(0.3);
              }
              return Colors.grey.shade300;
            },
          ),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: MaterialStateProperty.resolveWith<Color>(
            (Set<MaterialState> states) {
              if (states.contains(MaterialState.selected)) {
                return Colors.grey.shade600;
              }
              return Colors.transparent;
            },
          ),
          checkColor: MaterialStateProperty.all(Colors.white),
        ),
        radioTheme: RadioThemeData(
          fillColor: MaterialStateProperty.resolveWith<Color>(
            (Set<MaterialState> states) {
              if (states.contains(MaterialState.selected)) {
                return Colors.grey.shade600;
              }
              return Colors.grey.shade400;
            },
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: createColor(LightThemeColors().primaryAccent),
          foregroundColor: Colors.white,
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          menuStyle: MenuStyle(
            backgroundColor: MaterialStateProperty.all(Colors.white),
            surfaceTintColor: MaterialStateProperty.all(Colors.transparent),
            shadowColor:
                MaterialStateProperty.all(Colors.black.withOpacity(0.15)),
            elevation: MaterialStateProperty.all(8),
            shape: MaterialStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.black.withOpacity(0.15),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        menuButtonTheme: MenuButtonThemeData(
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all(Colors.white),
            foregroundColor: MaterialStateProperty.all(Colors.black87),
          ),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          modalBackgroundColor: Colors.white,
        ),
        dividerTheme: DividerThemeData(
          color: Colors.grey[400],
        ),
      ),
    ),
  ));
}

Future<void> _setOrientationForDevice() async {
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  bool isTablet = false;

  if (Platform.isAndroid) {
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

    String model = androidInfo.model.toLowerCase();
    isTablet = model.contains('tab') ||
        model.contains('pad') ||
        model.contains('tablet');
  } else if (Platform.isIOS) {
    IosDeviceInfo iosInfo = await deviceInfo.iosInfo;

    isTablet = iosInfo.model.toLowerCase().contains('ipad');
  }

  if (isTablet) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  } else {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }
}

class FCMService {
  static const MethodChannel _platform =
      MethodChannel('com.aibat.sale_manager/fcm');

  static Future<String?> getFCMToken() async {
    try {
      final String? token = await _platform.invokeMethod('getFCMToken');
      print("fcm tokkken: $token");
      return token;
    } on PlatformException catch (e) {
      print("Failed to get FCM token: '${e.message}'.");
      return null;
    }
  }
}
