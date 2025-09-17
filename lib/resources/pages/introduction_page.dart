import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_app/bootstrap/helpers.dart';
import 'package:flutter_app/resources/pages/custom_toast.dart';
import 'package:flutter_app/resources/widgets/qr_scanner.dart';
import 'package:intro_slider/intro_slider.dart';
import 'package:nylo_framework/nylo_framework.dart';
import '/app/controllers/controller.dart';
import 'authentication/input_password_page.dart';
import 'authentication/login_new_page.dart';

class IntroductionPage extends NyStatefulWidget {
  final Controller controller = Controller();

  static const path = '/introduction';

  IntroductionPage({Key? key}) : super(key: key);

  @override
  _IntroductionPageState createState() => _IntroductionPageState();
}

class _IntroductionPageState extends NyState<IntroductionPage> {
  List<ContentConfig> listContentConfig = [];

  @override
  init() async {
    super.init();
  }

  @override
  void initState() {
    super.initState();

    listContentConfig.add(ContentConfig(
        backgroundImage: getImageAsset("intro/1.png"),
        backgroundFilterOpacity: 0));

    listContentConfig.add(ContentConfig(
        backgroundImage: getImageAsset("intro/2.png"),
        backgroundFilterOpacity: 0));

    listContentConfig.add(ContentConfig(
        backgroundImage: getImageAsset("intro/3.png"),
        backgroundFilterOpacity: 0));

    listContentConfig.add(ContentConfig(
        backgroundImage: getImageAsset("intro/4.png"),
        backgroundFilterOpacity: 0));

    listContentConfig.add(ContentConfig(
        backgroundImage: getImageAsset("intro/5.png"),
        backgroundFilterOpacity: 0));

    listContentConfig.add(ContentConfig(
        backgroundImage: getImageAsset("intro/6.png"),
        backgroundFilterOpacity: 0));
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _handleQRCodeScanned(String qrData) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );

      await Future.delayed(Duration(seconds: 2));

      Navigator.pop(context);

      CustomToast.showToastSuccess(context,
          description: 'Đăng nhập thành công');
    } catch (e) {
      Navigator.pop(context);
      CustomToast.showToastError(context, description: 'Mã QR không hợp lệ');
    }
  }

  void _openQRScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRScannerWidget(
          onQRCodeScanned: _handleQRCodeScanned,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              decoration: BoxDecoration(
                image: DecorationImage(
                  fit: BoxFit.cover,
                  opacity: 1,
                  image: AssetImage(getImageAsset('intro/bg.png')),
                ),
              ),
            ),
          ),
          Container(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: IntroSlider(
                    isShowSkipBtn: false,
                    isShowPrevBtn: false,
                    isShowNextBtn: false,
                    isShowDoneBtn: false,
                    key: UniqueKey(),
                    listContentConfig: listContentConfig,
                    indicatorConfig: IndicatorConfig(
                      colorIndicator: Color(0xFF32B265),
                      colorActiveIndicator: Color(0xFF058F75),
                    ),
                    onDonePress: () {},
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      // Button chính
                      Expanded(
                        child: Container(
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              backgroundColor:
                                  ThemeColor.get(context).primaryAccent,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              routeTo(LoginPageNew.path);
                            },
                            child: Text(
                              'TIẾP TỤC VỚI SỐ ĐIỆN THOẠI',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(width: 5),

                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: ThemeColor.get(context).primaryAccent,
                              width: 1),
                          color: Colors.white,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: _openQRScanner,
                            child: Icon(
                              Icons.qr_code_scanner,
                              color: ThemeColor.get(context).primaryAccent,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                Padding(
                  padding: EdgeInsets.only(left: 20, right: 20),
                  child: Row(
                    children: [
                      Text(
                        'Bạn đã có tài khoản?',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 16,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      Spacer(),
                      GestureDetector(
                        onTap: () {
                          routeTo(InputPasswordPage.path, data: {
                            'phone': "",
                            'login': true,
                            'is_new': false
                          });
                        },
                        child: Row(
                          children: [
                            Icon(
                              Icons.login,
                              color: Color(0xFF32B265),
                              size: 18,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'ĐĂNG NHẬP',
                              style: TextStyle(
                                color: Color(0xFF32B265),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 30,
                ),
                Column(
                  children: [
                    Align(
                        alignment: Alignment.center,
                        child: Image(
                            image: AssetImage(getImageAsset('ic_shield.png')))),
                    SizedBox(height: 5),
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        'An toàn & bảo mật',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
