import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_app/app/models/user.dart';
import 'package:flutter_app/bootstrap/helpers.dart';
import 'package:flutter_app/resources/pages/custom_toast.dart';
import 'package:nylo_framework/nylo_framework.dart';
import '/app/controllers/controller.dart';

final List<Map<String, String>> features = [
  {'key': 'customer_info', 'title': 'Thông tin khách hàng'},
  {'key': 'customer_address', 'title': 'Địa chỉ khách hàng'},
  {'key': 'employee_info', 'title': 'Thông tin nhân viên'},
  {'key': 'product_discount', 'title': 'Chiết khấu từng sản phẩm'},
  {'key': 'order_discount', 'title': 'Chiết khấu tổng đơn'},
  {'key': 'vat', 'title': 'VAT'},
  // {'key': 'shipping_code', 'title': 'Mã vận đơn'},
  {'key': 'input_size', 'title': 'Input nhập kích thước'},
  {'key': 'select_category', 'title': 'Chọn nhóm sản phẩm'},
  {'key': 'other_fee', 'title': 'Chi phí khác'},
  {'key': 'point_payment', 'title': 'Thanh toán bằng điểm'},
  {'key': 'create_date', 'title': 'Thời gian tạo đơn'},
  {'key': 'order_form', 'title': 'Mẫu đơn'},
  {'key': 'sub_unit_quantity', 'title': 'Đơn vị'},
  {'key': 'note', 'title': 'Ghi chú'},
  {'key': 'switch_price', 'title': 'Chọn giá bán buôn - bán lẻ'},
];
final List<Map<String, String>> featuresTable = [
  {'key': 'customer_info', 'title': 'Thông tin khách hàng'},
  {'key': 'customer_address', 'title': 'Địa chỉ khách hàng'},
  {'key': 'order_discount', 'title': 'Chiết khấu tổng đơn'},
  {'key': 'vat', 'title': 'VAT'},
  {'key': 'other_fee', 'title': 'Chi phí khác'},
  {'key': 'point_payment', 'title': 'Thanh toán bằng điểm'},
  {'key': 'note', 'title': 'Ghi chú đơn'},
  {'key': 'unit', 'title': 'Đơn vị tính'},
  {'key': 'product_note', 'title': 'Ghi chú món'},
  {'key': 'create_date', 'title': 'Thời gian tạo đơn'},
  {'key': 'customer_quantity', 'title': 'Hiển thị khách hàng, thời gian'},
];
String getOrderSaleConfigkey() {
  final userPhone = Auth.user<User>()?.phone;
  final orderSaleConfigKey = 'order_sale_config_$userPhone';
  return orderSaleConfigKey;
}

Map<String, bool> defaultFeatturesStatus = {
  'customer_info': true,
  'employee_info': false,
  'sale_price': false,
  'wholesale_price': false,
  'product_discount': false,
  'order_discount': false,
  'vat': false,
  // 'shipping_code': false,
  'input_size': false,
  'select_category': false,
  'other_fee': false,
  'point_payment': false,
  'create_date': false,
  'note': false,
  'unit': false,
  'switch_price': false,
  'product_note': true,
  'customer_address': false,
  'customer_quantity': false,
};

Future<Map<String, bool>> getOrderSaleConfig() async {
  try {
    final configKey = getOrderSaleConfigkey();
    final data = await NyStorage.read(configKey,
        defaultValue: jsonEncode(defaultFeatturesStatus));
    // Kiểm tra nếu data là một chuỗi JSON hợp lệ
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        return Map<String, bool>.from(decoded);
      }
    }

    // Nếu data không phải là chuỗi JSON hợp lệ, trả về giá trị mặc định
    return defaultFeatturesStatus;
  } catch (e) {
    print(e);
    return defaultFeatturesStatus;
  }
}

Future<void> saveOrderSaleConfig(Map<String, bool> data) async {
  final configKey = getOrderSaleConfigkey();
  await NyStorage.store(configKey, jsonEncode(data), inBackpack: true);
}

class SettingOrderSalePage extends NyStatefulWidget {
  final Controller controller = Controller();

  static const path = '/setting-order-sale';

  SettingOrderSalePage({Key? key}) : super(key: key);

  @override
  _SettingOrderSalePageState createState() => _SettingOrderSalePageState();
}

class _SettingOrderSalePageState extends NyState<SettingOrderSalePage> {
  Map<String, bool> featturesStatus = {};

  @override
  init() async {
    super.init();
    featturesStatus = await getOrderSaleConfig();
    setState(() {});
  }

  @override
  void dispose() {
    super.dispose();
  }

  void saveConfig() async {
    try {
      await saveOrderSaleConfig(featturesStatus);
      CustomToast.showToastSuccess(context,
          description: "Lưu cài đặt thành công");
      Navigator.pop(context, true);
    } catch (e) {
      print(e);
      CustomToast.showToastError(context, description: "Lưu cài đặt thất bại");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cài đặt đơn bán'),
      ),
      body: SafeArea(
        child: Container(
            child: ListView.separated(
          itemCount: Auth.user<User>()?.careerType == CareerType.other
              ? features.length
              : featuresTable.length,
          separatorBuilder: (context, index) => Divider(),
          itemBuilder: (context, index) {
            String key = Auth.user<User>()?.careerType == CareerType.other
                ? features[index]['key']!
                : featuresTable[index]['key']!;
            bool isCustomerInfo = key == 'customer_info';
            bool isCustomerAddress = key == 'customer_address';
            bool isCustomerInfoEnabled =
                featturesStatus['customer_info'] ?? false;
            return ListTile(
              title: Text(Auth.user<User>()?.careerType == CareerType.other
                  ? features[index]['title'] ?? ''
                  : featuresTable[index]['title'] ?? ''),
              trailing: Switch(
                inactiveThumbColor: Colors.white,
                activeColor: ThemeColor.get(context).primaryAccent,
                value: Auth.user<User>()?.careerType == CareerType.other
                    ? featturesStatus[features[index]['key']] ?? false
                    : featturesStatus[featuresTable[index]['key']] ?? false,
                onChanged: isCustomerAddress && !isCustomerInfoEnabled
                    ? null
                    : (value) {
                        setState(() {
                          String key =
                              Auth.user<User>()?.careerType == CareerType.other
                                  ? features[index]['key']!
                                  : featuresTable[index]['key']!;
                          featturesStatus[key] = value;
                          if (isCustomerInfo && !value) {
                            featturesStatus['customer_address'] = false;
                          }
                        });
                      },
              ),
            );
          },
        )),
      ),
      persistentFooterButtons: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              backgroundColor: ThemeColor.get(context).primaryAccent),
          onPressed: () {
            saveConfig();
          },
          child: Text('Lưu cài đặt', style: TextStyle(color: Colors.white)),
        )
      ],
    );
  }
}
