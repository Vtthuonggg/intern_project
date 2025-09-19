import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/app/models/user.dart';
import 'package:flutter_app/app/networking/user_api_service.dart';
import 'package:flutter_app/config/common_define.dart';
import 'package:flutter_app/resources/pages/dash_board_page.dart';
import 'package:flutter_app/resources/pages/product/list_product_page.dart';
import 'package:flutter_app/resources/pages/setting/setting_page.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:global_configuration/global_configuration.dart';
import 'package:nylo_framework/nylo_framework.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent-tab-view.dart';
import '../../bootstrap/helpers.dart';
import '/app/controllers/controller.dart';
import 'order_list_all_page.dart';

enum ScreenTab { SCREEN_HOME, SCREEN_ORDERS, SCREEN_PRODUCTS, SCREEN_ACCOUNT }

extension ScreenTabExt on ScreenTab {
  int get position {
    switch (this) {
      case ScreenTab.SCREEN_HOME:
        return 0;
      case ScreenTab.SCREEN_ORDERS:
        return 1;
      case ScreenTab.SCREEN_PRODUCTS:
        return 2;
      case ScreenTab.SCREEN_ACCOUNT:
        return 3;
    }
  }
}

class MainPage extends NyStatefulWidget {
  final Controller controller = Controller();

  static const path = '/main';

  MainPage({Key? key}) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends NyState<MainPage> with WidgetsBindingObserver {
  GlobalKey<NavigatorState>? _currentGlobalKey() {
    if (prePosition == ScreenTab.SCREEN_HOME.position) {
      return _homeNavKey;
    }
    if (prePosition == ScreenTab.SCREEN_ACCOUNT.position) {
      return _accountNavKey;
    }
    if (prePosition == ScreenTab.SCREEN_PRODUCTS.position) {
      return _productNavKey;
    }
    if (prePosition == ScreenTab.SCREEN_ORDERS.position) {
      return _orderNavKey;
    }
    return null;
  }

  List<Widget> _buildScreens() {
    return [
      DashboardPage(key: _homeNavKey),
      OrderListAllPage(key: _orderNavKey, onTabbar: true),
      ListProductPage(key: _productNavKey, onTabbar: true),
      SettingPage(
        key: _accountNavKey,
      ),
    ];
  }

  final GlobalKey<NavigatorState> _homeNavKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _accountNavKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _productNavKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _orderNavKey = GlobalKey<NavigatorState>();
  int prePosition = 0;
  int _currentIndex = 0;
  dynamic setting;

  final GlobalKey<ScaffoldState> _mainScaffoldKey = GlobalKey<ScaffoldState>();

  final PersistentTabController _tabController =
      PersistentTabController(initialIndex: 0);
  Future<void>? _checkShowDataFuture;
  int? storeId;
  @override
  init() async {
    super.init();
    await GlobalConfiguration().loadFromAsset("app_config");
    await checkAndSetDevice(Auth.user(), context);
  }

  @override
  void initState() {
    super.initState();
    _checkShowDataFuture = checkShowData();
    mainScaffoldKey = _mainScaffoldKey;
    tabController = _tabController;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> checkAndSetDevice(User user, BuildContext context) async {
    try {
      final size = MediaQuery.of(context).size;
      final isLargeScreen = size.shortestSide >= 600;

      user.isPos = isLargeScreen;
      user.isPosSunmi = false;
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        user.deviceId = androidInfo.id;
        final model = (androidInfo.model ?? '').toLowerCase();
        final manufacturer = (androidInfo.manufacturer ?? '').toLowerCase();

        if (isLargeScreen) {
          user.isPos = true;

          if (model.contains('sunmi') || manufacturer.contains('sunmi')) {
            user.isPosSunmi = true;
          } else {
            user.isPosSunmi = false;
          }
        } else {
          user.isPos = false;
          user.isPosSunmi = false;
        }
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        user.deviceId = iosInfo.identifierForVendor;
        user.isPos = isLargeScreen;
        user.isPosSunmi = false;
      }
    } catch (e) {
      final size = MediaQuery.of(context).size;
      user.isPos = size.shortestSide >= 600;
      user.isPosSunmi = false;
    }
  }

  Future<void> checkShowData() async {
    try {
      var data =
          await api<UserApiService>((request) => request.checkTimeShowData());
      if (data['success'] && data != null) {
        await NyStorage.store('isShowData', data['data']['is_show']);
      }
    } catch (e) {
      await NyStorage.store('isShowData', false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (mainScaffoldKey == null) {
      mainScaffoldKey = GlobalKey<ScaffoldState>();
    }
    if (tabController == null) {
      tabController = PersistentTabController(initialIndex: 0);
    }
    return FutureBuilder(
      future: _checkShowDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(
            color: ThemeColor.get(context).primaryAccent,
          ));
        } else if (snapshot.hasError) {
          return Center(child: Text('Đã có lỗi xảy ra'));
        } else {
          return Scaffold(
            key: _mainScaffoldKey,
            body: PersistentTabView(context,
                controller: _tabController,
                screens: _buildScreens(),
                items: _navBarsItems(),
                confineInSafeArea: true,
                backgroundColor: Theme.of(context).colorScheme.onPrimary,
                // Default is Colors.white.
                handleAndroidBackButtonPress: true,
                // Default is true.
                resizeToAvoidBottomInset: true,
                // This needs to be true if you want to move up the screen when keyboard appears. Default is true.
                stateManagement: true,
                selectedTabScreenContext: (context) {},
                // Default is true.
                hideNavigationBarWhenKeyboardShows: true,
                // navBarHeight: 56.h,
                // Recommended to set 'resizeToAvoidBottomInset' as true while using this argument. Default is true.
                decoration: NavBarDecoration(
                    borderRadius: BorderRadius.zero,
                    colorBehindNavBar: ThemeColor.get(context).primaryAccent,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: const Offset(0, 2))
                    ]),
                popAllScreensOnTapOfSelectedTab: true,
                popActionScreens: PopActionScreensType.all,
                onWillPop: (context) async {
              if (_currentIndex == prePosition) {
                GlobalKey<NavigatorState>? currentKey = _currentGlobalKey();
                if (currentKey != null) {
                  if (await currentKey.currentState?.maybePop() != true) {
                    tabController?.jumpToTab(_currentIndex);
                  }
                }
              }
              return true;
            }, navBarHeight: 60.0, navBarStyle: NavBarStyle.style6),
          );
        }
      },
    );
  }

  List<PersistentBottomNavBarItem> _navBarsItems() {
    Color activeColor = Color(0XFF179A6E);
    Color inactiveColor = Color(0XFFA3AFBD);
    return [
      PersistentBottomNavBarItem(
          title: 'Trang chủ',
          icon: Icon(
            Icons.home_filled,
            color: activeColor,
          ),
          inactiveIcon: Icon(
            Icons.home_filled,
            color: inactiveColor,
          ),
          activeColorPrimary: activeColor,
          inactiveColorPrimary: inactiveColor,
          textStyle: TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      PersistentBottomNavBarItem(
          title: 'Đơn hàng',
          icon: Icon(Icons.fact_check, color: activeColor),
          inactiveIcon: Icon(
            Icons.fact_check_outlined,
            color: inactiveColor,
          ),
          activeColorPrimary: activeColor,
          inactiveColorPrimary: inactiveColor,
          textStyle: TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      PersistentBottomNavBarItem(
          title: 'Sản phẩm',
          icon: Icon(
            Icons.inventory,
            color: activeColor,
          ),
          inactiveIcon: Icon(
            Icons.inventory,
            color: inactiveColor,
          ),
          activeColorPrimary: activeColor,
          inactiveColorPrimary: inactiveColor,
          textStyle: TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      PersistentBottomNavBarItem(
          title: 'Cài đặt',
          icon: Icon(
            FontAwesomeIcons.cog,
            color: activeColor,
            size: 25,
          ),
          inactiveIcon: Icon(
            FontAwesomeIcons.cog,
            color: inactiveColor,
            size: 22,
          ),
          activeColorPrimary: activeColor,
          inactiveColorPrimary: inactiveColor,
          textStyle: TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
    ];
  }
}
