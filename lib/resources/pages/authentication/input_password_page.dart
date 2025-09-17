import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_app/app/controllers/controller.dart';
import 'package:flutter_app/app/events/login_event.dart';
import 'package:flutter_app/app/models/user.dart';
import 'package:flutter_app/app/networking/auth_api_service.dart';
import 'package:flutter_app/app/utils/message.dart';
import 'package:flutter_app/app/utils/utils.dart';
import 'package:flutter_app/resources/pages/authentication/confirm_otp_register_page.dart';
import 'package:flutter_app/resources/pages/custom_toast.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nylo_framework/nylo_framework.dart';
import 'package:flutter/material.dart';

import '../../../bootstrap/helpers.dart';
import '../../../config/common_define.dart';
import 'confirm_otp_reset_page.dart';

class InputPasswordPage extends NyStatefulWidget {
  static const path = '/input-password';
  final Controller controller = Controller();

  InputPasswordPage({Key? key}) : super(key: key);

  @override
  _InputPasswordPageState createState() => _InputPasswordPageState();
}

class _InputPasswordPageState extends NyState<InputPasswordPage>
    with WidgetsBindingObserver {
  bool _isPasswordVisible = false;
  bool _isConfirmPassVisible = false;

  TextEditingController _phoneNumberController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();
  TextEditingController _confirmPasswordController = TextEditingController();
  TextEditingController _textFieldController = TextEditingController();

  int loginType = 2;

  String get phoneNumber => widget.data()['phone'];
  String _errorMessage = '';

  bool isEmployee = false;

  bool? get pushViewLogin => widget.data()['login'];

  bool? get isNew => widget.data()['is_new'];
  bool _isLoading = false;

  bool isStaff = false;

  TextEditingController _refController = TextEditingController();
  TextEditingController _nameShopController = TextEditingController();

  final ScrollController _scrollController = ScrollController();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _passFocusNode = FocusNode();
  final FocusNode _confirmPassFocusNode = FocusNode();

  @override
  init() async {
    super.init();
  }

  @override
  void initState() {
    super.initState();
    _passFocusNode.addListener(() {
      setState(() {});
    });
    _confirmPassFocusNode.addListener(() {
      setState(() {});
    });
    _phoneFocusNode.addListener(() {
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
      // _passFocusNode.requestFocus();
      _phoneFocusNode.requestFocus();
      WidgetsBinding.instance.addObserver(this);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _phoneNumberController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _textFieldController.dispose();
    _refController.dispose();
    _passFocusNode.dispose();
    _phoneFocusNode.dispose();
    _nameShopController.dispose();
    _confirmPassFocusNode.dispose();
    super.dispose();
  }

  RegExp newPhoneRegExp = new RegExp(r'^(84|0[3|5|7|8|9])+([0-9]{8,9})\b');

  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  void _toggleConfirmPasswordVisibility() {
    setState(() {
      _isConfirmPassVisible = !_isConfirmPassVisible;
    });
  }

  _login() async {
    setState(() {
      _errorMessage = '';
    });
    if (_isLoading) {
      return;
    }

    if (_phoneNumberController.text.isEmpty && pushViewLogin == true) {
      _errorMessage = 'Vui lòng điền số điện thoại';
      return;
    }
    // validate
    if (_passwordController.text.isEmpty ||
        _passwordController.text.length < 6) {
      return;
    }

    setState(() {
      _isLoading = true;
    });
    dynamic data = {
      'phone': pushViewLogin != null && pushViewLogin == true
          ? _phoneNumberController.text
          : phoneNumber,
      'password': _passwordController.text,
      'type': loginType,
    };

    try {
      User user = await api<AuthApiService>((request) => request.login(data));
      if (user.businessId == null) {
        showChooseCareerPopup(context, user, false);
      } else {
        event<LoginEvent>(data: {
          'user': user,
        });

        await getFCMTokenAndSave();
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        setState(() {
          _errorMessage = 'Sai tài khoản hoặc mật khẩu';
        });
      } else if (e.response?.statusCode == 422) {
        String token = e.response?.data['message'] ?? '';
        if (phoneNumber.isNotEmpty || _phoneNumberController.text.isNotEmpty) {
          _activeUserWithPhone(
              pushViewLogin != null && pushViewLogin == true
                  ? _phoneNumberController.text
                  : phoneNumber,
              token);
        }
      } else {
        setState(() {
          _errorMessage = 'Đã có lỗi xảy ra';
        });
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  _activeUserWithPhone(String phone, String token) {
    routeTo(ConfirmOtpRegisterPage.path,
        data: {'token': token, 'sendImmediately': true}, onPop: (user) async {
      if (user != null) {
        try {
          CustomToast.showToastSuccess(context,
              description: 'Đăng ký thành công!');

          await getFCMTokenAndSave();

          showChooseCareerPopup(context, user, false);
        } catch (e) {
          _errorMessage = getResponseError(e);
        } finally {
          setState(() {
            _isLoading = false;
          });
        }
      }
    });
  }

  _signup() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _errorMessage = '';
    });

    if (_passwordController.text != _confirmPasswordController.text) {
      _errorMessage = 'Mật khẩu không trùng khớp';
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      String token = await api<AuthApiService>((request) => request.register(
            phoneNumber,
            _passwordController.text,
            _passwordController.text,
            _refController.text,
            _nameShopController.text,
          ));
      routeTo(ConfirmOtpRegisterPage.path, data: {'token': token},
          onPop: (user) async {
        if (user != null) {
          try {
            CustomToast.showToastSuccess(context,
                description: 'Đăng ký thành công!');
            showChooseCareerPopup(context, user, false);
          } catch (e) {
            _errorMessage = getResponseError(e);
          } finally {
            setState(() {
              _isLoading = false;
            });
          }
        }
      });
    } catch (e) {
      print(e);
      setState(() {
        _errorMessage = getResponseError(e);
      });
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
  void didChangeMetrics() {
    super.didChangeMetrics();
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
    if (bottomInset == 0) {
      _scrollController.animateTo(
        0.0,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
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
            child: LayoutBuilder(builder: (context, constraints) {
              bool isLandscape = constraints.maxWidth > constraints.maxHeight;
              return SingleChildScrollView(
                controller: _scrollController,
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                          height: isLandscape
                              ? 10
                              : (isNew != null && isNew == true ? 12 : 62)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 30,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                              children: <TextSpan>[
                                TextSpan(
                                  text: isNew != null && isNew == true
                                      ? 'Đăng ký'
                                      : 'Đăng nhập',
                                  style: TextStyle(
                                    color:
                                        ThemeColor.get(context).primaryAccent,
                                  ),
                                ),
                                TextSpan(
                                  text: pushViewLogin == false
                                      ? ' tài khoản'
                                      : '',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 15,
                      ),
                      if (pushViewLogin == false)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                                children: <TextSpan>[
                                  const TextSpan(text: 'Số điện thoại'),
                                  TextSpan(
                                    text: ' $phoneNumber',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' của bạn',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      if (pushViewLogin == false)
                        SizedBox(
                          height: 20,
                        ),
                      if (pushViewLogin == true)
                        TextFormField(
                          controller: _phoneNumberController,
                          focusNode: _phoneFocusNode,
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
                                    _phoneNumberController.text.isNotEmpty
                                ? Padding(
                                    padding: const EdgeInsets.only(right: 5.0),
                                    child: GestureDetector(
                                        onTap: () {
                                          _clearText(_phoneNumberController);
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
                        ),
                      SizedBox(
                        height: 5,
                      ),
                      NyTextField(
                        cursorColor: ThemeColor.get(context).primaryAccent,
                        autoFocus: isNew == false ? true : false,
                        focusNode: _passFocusNode,
                        validationRules: "not_empty",
                        validationErrorMessage: "Vui lòng điền mật khẩu",
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.all(0),
                          labelText: 'Mật khẩu',
                          labelStyle: TextStyle(color: Colors.black),
                          floatingLabelStyle: TextStyle(
                            color: Colors.red,
                          ),
                          hintText: 'Điền mật khẩu',
                          hintStyle: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: ThemeColor.get(context).primaryAccent),
                          ),
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.black12),
                          ),
                          suffix: _passFocusNode.hasFocus
                              ? Padding(
                                  padding: EdgeInsets.only(right: 5.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          _clearText(_passwordController);
                                        },
                                        child: Icon(
                                          Icons.cancel,
                                          color: Colors.black26,
                                          size: 18,
                                        ),
                                      ),
                                      SizedBox(width: 5),
                                      GestureDetector(
                                        onTap: _togglePasswordVisibility,
                                        child: Icon(
                                          _isPasswordVisible
                                              ? FontAwesomeIcons.eyeSlash
                                              : FontAwesomeIcons.solidEye,
                                          color: Colors.black26,
                                          size: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : null,
                        ),
                      ),
                      if (isNew != null &&
                          isNew == true &&
                          pushViewLogin == false)
                        Column(
                          children: [
                            SizedBox(height: 10),
                            NyTextField(
                              cursorColor:
                                  ThemeColor.get(context).primaryAccent,
                              validationRules: "not_empty",
                              validationErrorMessage: "Xác nhận mật khẩu",
                              controller: _confirmPasswordController,
                              focusNode: _confirmPassFocusNode,
                              obscureText: !_isConfirmPassVisible,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.all(0),
                                labelText: 'Nhắc lại mật khẩu',
                                labelStyle: TextStyle(color: Colors.black),
                                floatingLabelStyle: TextStyle(
                                  color: Colors.red,
                                ),
                                hintText: 'Nhắc lại mật khẩu',
                                hintStyle: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color:
                                        ThemeColor.get(context).primaryAccent,
                                  ),
                                ),
                                border: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black12),
                                ),
                                suffix: _confirmPassFocusNode.hasFocus
                                    ? Padding(
                                        padding: EdgeInsets.only(right: 5.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            GestureDetector(
                                              onTap: () {
                                                _clearText(
                                                    _confirmPasswordController);
                                              },
                                              child: Icon(
                                                Icons.cancel,
                                                color: Colors.black26,
                                                size: 18,
                                              ),
                                            ),
                                            SizedBox(width: 5),
                                            GestureDetector(
                                              onTap:
                                                  _toggleConfirmPasswordVisibility,
                                              child: Icon(
                                                _isConfirmPassVisible
                                                    ? FontAwesomeIcons.eyeSlash
                                                    : FontAwesomeIcons.solidEye,
                                                color: Colors.black26,
                                                size: 18,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            SizedBox(height: 10),
                            Column(
                              children: [
                                const SizedBox(height: 15),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Thông tin thêm',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _nameShopController,
                                  decoration: InputDecoration(
                                    labelText:
                                        'Tên cửa hàng hoặc tên liên hệ của bạn',
                                    labelStyle: TextStyle(color: Colors.black),
                                    floatingLabelStyle: TextStyle(
                                      color: Colors.red,
                                    ),
                                    hintText: 'Ví dụ: Aibat xuân đỉnh',
                                    hintStyle: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                    contentPadding: const EdgeInsets.all(0),
                                    focusedBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                          color: ThemeColor.get(context)
                                              .primaryAccent),
                                    ),
                                    border: const UnderlineInputBorder(
                                      borderSide:
                                          BorderSide(color: Colors.black12),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 15),
                                TextFormField(
                                  controller: _refController,
                                  decoration: InputDecoration(
                                    labelText: 'Mã giới thiệu (nếu có)',
                                    labelStyle: TextStyle(color: Colors.black),
                                    floatingLabelStyle: TextStyle(
                                      color: Colors.red,
                                    ),
                                    hintText: 'Ví dụ: AIB123',
                                    hintStyle: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                    contentPadding: const EdgeInsets.all(0),
                                    focusedBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                          color: ThemeColor.get(context)
                                              .primaryAccent),
                                    ),
                                    border: const UnderlineInputBorder(
                                      borderSide:
                                          BorderSide(color: Colors.black12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      if (_errorMessage.isNotEmpty)
                        Column(
                          children: [
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _errorMessage,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.left,
                              ),
                            ),
                          ],
                        ),
                      SizedBox(height: 5),
                      if (isNew != null && isNew == false)
                        Padding(
                          padding: EdgeInsets.only(top: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  text: 'Quên mật khẩu?',
                                  style: TextStyle(
                                    color: Colors.blue,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      _displayPhoneInputDialog(context);
                                    },
                                ),
                              ),
                              Spacer(),
                              Row(
                                children: [
                                  SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: Checkbox(
                                      value: isStaff,
                                      onChanged: (value) {
                                        setState(() {
                                          isStaff = value!;
                                          loginType = isStaff ? 3 : 2;
                                        });
                                      },
                                      checkColor: Colors.white,
                                      activeColor: Colors.blue,
                                    ),
                                  ),
                                  SizedBox(width: 5),
                                  Text('Bạn là nhân viên'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      SizedBox(
                        height: 50,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                                style: TextButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    backgroundColor:
                                        ThemeColor.get(context).primaryAccent,
                                    foregroundColor: Colors.white),
                                onPressed: () {
                                  isNew != null && isNew == true
                                      ? _signup()
                                      : _login();
                                },
                                child: _isLoading
                                    ? CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    : Text(
                                        isNew != null && isNew == true
                                            ? 'Tiếp tục'
                                            : 'Đăng nhập',
                                        style: TextStyle(fontSize: 18),
                                      )),
                          ),
                        ],
                      ),
                      if (pushViewLogin == false && isNew == false)
                        SizedBox(
                            height: isLandscape
                                ? 20
                                : (MediaQuery.of(context).size.height / 2) -
                                    135),
                      if (pushViewLogin == false && isNew == true)
                        SizedBox(
                            height: isLandscape
                                ? 20
                                : (MediaQuery.of(context).size.height / 2) -
                                    270),
                      if (pushViewLogin != null &&
                          pushViewLogin == true &&
                          isNew == false)
                        SizedBox(
                            height: isLandscape
                                ? 20
                                : (MediaQuery.of(context).size.height / 2) -
                                    145),
                      Column(
                        children: [
                          Image(
                              image:
                                  AssetImage(getImageAsset('ic_shield.png'))),
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
                    ],
                  ),
                ),
              );
            }),
          ),
        ));
  }

  Future<void> _displayPhoneInputDialog(BuildContext context) async {
    Dialog dialog = Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0)), //this right here
      child: Container(
        width: 0.9.sw,
        margin: EdgeInsets.only(top: 10, bottom: 10),
        padding: EdgeInsets.only(top: 8, right: 8, left: 8, bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
                alignment: Alignment.center,
                child: Container(
                  margin: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Bạn quên mật khẩu?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                )),
            Container(
              padding: EdgeInsets.only(left: 12, right: 12),
              child: Divider(
                color: Colors.grey[600],
              ),
            ),
            Container(
              padding: EdgeInsets.only(left: 12, right: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  12.verticalSpace,
                  Text('Vui lòng nhập số điện thoại để lấy lại mật khẩu.'),
                  12.verticalSpace,
                  NyTextField(
                    validationRules: "not_empty",
                    validationErrorMessage: "Vui lòng điền số điện thoại",
                    controller: _textFieldController,
                    keyboardType: TextInputType.phone,
                    cursorColor: ThemeColor.get(context).primaryAccent,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.all(0),
                      labelText: 'Số điện thoại',
                      labelStyle: TextStyle(
                        color: ThemeColor.get(context).primaryAccent,
                        fontSize: 15,
                        fontWeight: FontWeight.normal,
                      ),
                      hintText: 'Điền số điện thoại',
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: ThemeColor.get(context).primaryAccent),
                      ),
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.black12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          child: const Text('Tiếp tục'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor:
                                ThemeColor.get(context).primaryAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () async {
                            if (_textFieldController.text.isEmpty) {
                              CustomToast.showToastError(context,
                                  description: 'Chưa nhập số điện thoại');
                              return;
                            }
                            handleResetPass(
                                _textFieldController.text, loginType);
                          },
                        ),
                      ),
                      //   ],
                      // ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return showDialog(
        context: context, builder: (BuildContext context) => dialog);
  }

  Future handleResetPass(String phone, int positionType) async {
    try {
      await api<AuthApiService>(
          (request) => request.requestResetOtp(phone, positionType));
      routeTo(ConfirmOtpResetPage.path,
          data: {'phone': phone, 'type': positionType});
    } catch (e) {
      CustomToast.showToastError(context, description: getResponseError(e));
    }
  }
}
