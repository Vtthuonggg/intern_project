import 'package:flutter/material.dart';
import 'package:flutter_app/app/utils/message.dart';
import 'package:flutter_app/resources/pages/authentication/login_new_page.dart';
import 'package:flutter_app/resources/pages/custom_toast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nylo_framework/nylo_framework.dart';
import '../../../app/networking/auth_api_service.dart';
import '../../../bootstrap/helpers.dart';
import '/app/controllers/controller.dart';

class ResetPasswordPage extends NyStatefulWidget {
  final Controller controller = Controller();

  static const path = '/reset-password';

  ResetPasswordPage({Key? key}) : super(key: key);

  @override
  _ResetPasswordPageState createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends NyState<ResetPasswordPage> {
  var _isLoading = false;
  TextEditingController _passwordController = TextEditingController();
  TextEditingController _passwordConfirmationController =
      TextEditingController();
  bool _isPasswordVisible = false;

  bool agree = false;

  final _formKey = GlobalKey<FormState>();
  @override
  init() async {
    super.init();
  }

  @override
  void dispose() {
    super.dispose();
  }

  _sendPassword() async {
    if (_isLoading) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_passwordController.text != _passwordConfirmationController.text) {
      CustomToast.showToastError(context, description: 'Mật khẩu không khớp');
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      dynamic res =
          await api<AuthApiService>((request) => request.resetPassword(
                widget.data()?['phone'] ?? '',
                _passwordController.text,
                _passwordConfirmationController.text,
                widget.data()?['type'] ?? '',
              ));
      CustomToast.showToastSuccess(context,
          description: 'Cập nhật thành công!');
      routeTo(LoginPageNew.path,
          data: {'type': widget.data()?['type'] ?? ''},
          navigationType: NavigationType.pushAndForgetAll);
    } catch (err) {
      CustomToast.showToastError(context, description: getResponseError(err));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Đặt mật khẩu'),
      ),
      body: SafeArea(
        child: Container(
          child: Column(
            children: [
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Không được để trống';
                          }

                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu',
                          labelStyle: TextStyle(
                              color: ThemeColor.get(context).primaryAccent,
                              fontWeight: FontWeight.bold),
                          hintText: 'Điền mật khẩu',
                          contentPadding: const EdgeInsets.all(0),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: ThemeColor.get(context).primaryAccent),
                          ),
                          border: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.black12),
                          ),
                          suffix: GestureDetector(
                            onTap: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                            child: Icon(
                              _isPasswordVisible
                                  ? FontAwesomeIcons.eyeSlash
                                  : FontAwesomeIcons.solidEye,
                              color: Colors.black26,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordConfirmationController,
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Xác nhận mật khẩu',
                          labelStyle: TextStyle(
                              color: ThemeColor.get(context).primaryAccent,
                              fontWeight: FontWeight.bold),
                          hintText: 'Điền lại mật khẩu',
                          contentPadding: const EdgeInsets.all(0),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: ThemeColor.get(context).primaryAccent),
                          ),
                          border: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.black12),
                          ),
                          suffix: GestureDetector(
                            onTap: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                            child: Icon(
                              _isPasswordVisible
                                  ? FontAwesomeIcons.eyeSlash
                                  : FontAwesomeIcons.solidEye,
                              color: Colors.black26,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _sendPassword,
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor:
                                ThemeColor.get(context).primaryAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Cập nhật'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
