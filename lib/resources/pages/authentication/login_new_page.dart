import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_app/app/controllers/controller.dart';
import 'package:flutter_app/app/networking/auth_api_service.dart';
import 'package:flutter_app/bootstrap/helpers.dart';
import 'package:flutter_app/resources/pages/authentication/input_password_page.dart';
import 'package:flutter_app/resources/pages/custom_toast.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nylo_framework/nylo_framework.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginPageNew extends NyStatefulWidget {
  static const path = '/login-employee';
  final Controller controller = Controller();

  LoginPageNew({Key? key}) : super(key: key);

  @override
  _LoginEmployeePageState createState() => _LoginEmployeePageState();
}

class _LoginEmployeePageState extends NyState<LoginPageNew> {
  TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  bool agree = true;
  TextEditingController _textFieldController = TextEditingController();
  String _errorMessage = '';
  final FocusNode _phoneFocusNode = FocusNode();

  @override
  init() async {
    super.init();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _phoneFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _textFieldController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  RegExp newPhoneRegExp = new RegExp(r'^(84|0[3|5|7|8|9])+([0-9]{8,9})\b');

  _checkAccount() async {
    setState(() {
      _errorMessage = '';
    });

    if (!agree) {
      return;
    }

    if (_phoneController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng nhập số điện thoại';
      });
      return;
    }
    if (newPhoneRegExp.hasMatch(_phoneController.text) == false) {
      setState(() {
        _errorMessage = 'Số điện thoại không hợp lệ';
      });
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      var response = await api<AuthApiService>(
          (request) => request.checkUser(_phoneController.text));

      var data = response['data'];
      if (data['is_new'] == false) {
        routeTo(InputPasswordPage.path, data: {
          'phone': _phoneController.text,
          'login': false,
          'is_new': false
        });
      } else {
        routeTo(InputPasswordPage.path, data: {
          'phone': _phoneController.text,
          'login': false,
          'is_new': true
        });
      }
    } catch (e) {
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearText(TextEditingController controller) {
    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);
    return Scaffold(
        appBar: AppBar(
          title: Text(''),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 62),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 30,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                          children: <TextSpan>[
                            TextSpan(
                              text: 'Nhập',
                            ),
                            TextSpan(
                              text: ' số điện thoại',
                              style: TextStyle(
                                color: ThemeColor.get(context).primaryAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  TextFormField(
                    controller: _phoneController,
                    focusNode: _phoneFocusNode,
                    cursorColor: ThemeColor.get(context).primaryAccent,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Số điện thoại',
                      labelStyle: TextStyle(color: Colors.black),
                      floatingLabelStyle: TextStyle(
                        color: Colors.red,
                      ),
                      hintText: ' Ví dụ: 0987 654 321',
                      hintStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                      contentPadding: const EdgeInsets.all(0),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: ThemeColor.get(context).primaryAccent),
                      ),
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.black12),
                      ),
                      suffix: _phoneFocusNode.hasFocus &&
                              _phoneController.text.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(right: 5.0),
                              child: GestureDetector(
                                  onTap: () {
                                    _clearText(_phoneController);
                                  },
                                  child: Icon(
                                    Icons.cancel,
                                    color: Colors.black26,
                                    size: 18,
                                  )),
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Không được để trống';
                      }
                      if (newPhoneRegExp.hasMatch(value) == false)
                        return 'Số điện thoại không hợp lệ';
                      return null;
                    },
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_errorMessage.isNotEmpty)
                    Column(
                      children: [
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text(
                              _errorMessage,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  const SizedBox(height: 25),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Baseline(
                        baseline: 23.0,
                        baselineType: TextBaseline.alphabetic,
                        child: SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: agree,
                            onChanged: (value) {
                              setState(() {
                                agree = value!;
                              });
                            },
                            checkColor: Colors.white,
                            activeColor: Colors.blue,
                          ),
                        ),
                      ),
                      SizedBox(width: 5),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                            children: [
                              const TextSpan(
                                text: 'Đồng ý với các ',
                              ),
                              TextSpan(
                                text: 'Chính sách bảo mật',
                                style: TextStyle(
                                  color: Colors.blue,
                                ),
                                // Add onTap handler for the link
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    launchUrl(
                                        Uri.parse(
                                            'https://aibat.vn/chinh-sach-bao-mat.html'),
                                        mode: LaunchMode.externalApplication);
                                  },
                              ),
                              const TextSpan(
                                text: ' và ',
                              ),
                              TextSpan(
                                text: 'quy định sử dụng',
                                style: TextStyle(
                                  color: Colors.blue,
                                ),
                                // Add onTap handler for the link
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    launchUrl(
                                        Uri.parse(
                                            'https://aibat.vn/quy-dinh-su-dung.html'),
                                        mode: LaunchMode.externalApplication);
                                  },
                              ),
                              const TextSpan(
                                text: ' của ứng dụng',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 50),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 48,
                          child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                backgroundColor:
                                    _phoneController.text.isEmpty ||
                                            !agree ||
                                            _phoneController.text.length > 11
                                        ? Colors.grey
                                        : ThemeColor.get(context).primaryAccent,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: (_phoneController.text.isEmpty ||
                                      !agree ||
                                      _phoneController.text.length > 11)
                                  ? null
                                  : () {
                                      _checkAccount();
                                    },
                              child: _isLoading
                                  ? CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : Text(
                                      'Tiếp tục',
                                      style: TextStyle(fontSize: 18),
                                    )),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 200),
                  Column(
                    children: [
                      Image(image: AssetImage(getImageAsset('ic_shield.png'))),
                      SizedBox(height: 5),
                      Text(
                        'An toàn & bảo mật',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ));
  }
}
