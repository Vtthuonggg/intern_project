import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/app/networking/auth_api_service.dart';
import 'package:flutter_app/app/utils/message.dart';
import 'package:flutter_app/bootstrap/helpers.dart';
import 'package:flutter_app/resources/pages/authentication/reset_password_page.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nylo_framework/nylo_framework.dart';
import 'package:otp_text_field/otp_field.dart';
import 'package:otp_text_field/style.dart';
import '/app/controllers/controller.dart';
import 'package:flutter_app/resources/pages/custom_toast.dart';

const int OTP_TIMEOUT = 60;

class ConfirmOtpResetPage extends NyStatefulWidget {
  final Controller controller = Controller();

  static const path = '/confirm-otp-reset';

  ConfirmOtpResetPage({Key? key}) : super(key: key);

  @override
  _ConfirmOtpPageState createState() => _ConfirmOtpPageState();
}

class _ConfirmOtpPageState extends NyState<ConfirmOtpResetPage> {
  String phone = '';
  int type = 0;

  String verificationId = '';
  OtpFieldController otpController = OtpFieldController();
  bool isWaiting = false;
  Timer? _timer;
  int _start = OTP_TIMEOUT;
  BuildContext? saveDialogLoadingContext;
  bool _isLoading = false;

  String? errorMessages;

  @override
  init() async {
    super.init();
  }

  @override
  void dispose() {
    super.dispose();
    if (_timer?.isActive ?? false) {
      _timer?.cancel();
    }
  }

  @override
  void initState() {
    phone = widget.data()?['phone'];
    type = widget.data()?['type'];
    super.initState();

    _startTimer();
    setState(() {
      isWaiting = true;
    });
  }

  void _startTimer() {
    const oneSec = const Duration(seconds: 1);
    _start = OTP_TIMEOUT;
    _timer = new Timer.periodic(
      oneSec,
      (Timer timer) {
        if (_start == 0) {
          setState(() {
            timer.cancel();
            isWaiting = false;
          });
        } else {
          setState(() {
            _start--;
          });
        }
      },
    );
  }

  _requestOtp() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await api<AuthApiService>(
          (request) => request.requestResetOtp(phone, type));

      _startTimer();

      setState(() {
        isWaiting = true;
      });
    } catch (e) {
      CustomToast.showToastError(context, description: getResponseError(e));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Xác nhận OTP',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Container(
          margin: EdgeInsets.only(bottom: 100),
          child: Center(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (errorMessages != null)
                Text(
                  errorMessages!,
                  style: TextStyle(color: Colors.red),
                ),
              32.verticalSpace,
              OTPTextField(
                controller: otpController,
                length: 4,
                width: 0.6.sw,
                spaceBetween: 8,
                fieldWidth: 0.8.sw / 6 - 12,
                style: TextStyle(fontSize: 16),
                fieldStyle: FieldStyle.box,
                onCompleted: (otp) async {
                  try {
                    final res = await api<AuthApiService>((request) =>
                        request.resetPasswordConfirm(phone, otp, type));

                    routeTo(ResetPasswordPage.path, data: {
                      'phone': phone,
                      'type': type,
                    });
                  } catch (e) {
                    print(e);
                    otpController.clear();
                    setState(() {
                      errorMessages = getResponseError(e);
                    });
                  }
                },
              ),
              32.verticalSpace,
              Container(
                width: 150,
                height: 40,
                child: ElevatedButton(
                  onPressed: () {
                    if (isWaiting) {
                      return;
                    } else {
                      _requestOtp();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: isWaiting
                        ? Colors.grey[300]
                        : ThemeColor.get(context).primaryAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _start > 0
                              ? 'Gửi lại OTP (${_start}s)'
                              : 'Gửi lại OTP',
                        ),
                ),
              )
            ],
          )),
        ),
      ),
    );
  }
}
