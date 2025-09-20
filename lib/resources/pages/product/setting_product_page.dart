import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_app/app/models/user.dart';
import 'package:flutter_app/bootstrap/helpers.dart';
import 'package:flutter_app/resources/pages/custom_toast.dart';
import 'package:nylo_framework/nylo_framework.dart';
import '/app/controllers/controller.dart';

final List<Map<String, String>> features = [
  {'key': 'product_code', 'title': 'Mã sản phẩm'},
  {'key': 'product_barcode', 'title': 'Mã vạch'},
  {'key': 'product_weight', 'title': 'Trọng lượng'},
  {'key': 'product_weight_unit', 'title': 'Đơn vị trọng lượng'},
  {'key': 'product_unit', 'title': 'Đơn vị tính'},
  {'key': 'product_base_cost', 'title': 'Giá nhập'},
  {'key': 'product_retail_cost', 'title': 'Giá bán lẻ'},
  {'key': 'product_whoolsale_cost', 'title': 'Giá bán buôn'},
  {'key': 'product_vat', 'title': 'VAT'},
  // {'key': 'product_discount', 'title': 'Chiết khấu bán hàng'},
  {'key': 'product_category', 'title': 'Nhóm hàng'},
  {'key': 'product_brand', 'title': 'Nhãn hiệu'},
  {'key': 'product_image', 'title': 'Ảnh sản phẩm'},
  {'key': 'product_note', 'title': 'Ghi chú'},
  {'key': 'product_batch', 'title': 'Lô - Hạn sử dụng'},
  {'key': 'product_imei', 'title': 'Sản phẩm Imei'},
  {'key': 'product_storage', 'title': 'Khởi tạo kho hàng'},
  {'key': 'product_buy_alway', 'title': 'Cho phép bán âm'},
  {'key': 'product_unit2', 'title': 'Quy đổi'},
  {'key': 'product_variant', 'title': 'Thuộc tính'},
  {'key': 'food_type', 'title': 'Loại sản phẩm'},
];

String getProductConfigKey() {
  final userPhone = Auth.user<User>()?.phone;
  final productConfigKey = 'product_config_$userPhone';
  return productConfigKey;
}

Map<String, bool> defaultFeaturesStatus = {
  'product_code': true,
  'product_barcode': true,
  'product_weight': false,
  'product_weight_unit': false,
  'product_unit': true,
  'product_base_cost': true,
  'product_retail_cost': true,
  'product_whoolsale_cost': true,
  'product_discount': true,
  'product_category': false,
  'product_brand': true,
  'product_image': true,
  'product_note': true,
  'product_batch': false,
  'product_imei': false,
  'product_storage': false,
  'product_buy_alway': false,
  'product_unit2': false,
  'product_variant': false,
  'product_vat': false,
  'food_type': false,
};

Future<Map<String, bool>> getProductConfig() async {
  try {
    final configKey = getProductConfigKey();
    final data = await NyStorage.read(configKey,
        defaultValue: jsonEncode(defaultFeaturesStatus));
    // Kiểm tra nếu data là một chuỗi JSON hợp lệ
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        return Map<String, bool>.from(decoded);
      }
    }

    // Nếu data không phải là chuỗi JSON hợp lệ, trả về giá trị mặc định
    return defaultFeaturesStatus;
  } catch (e) {
    print(e);
    return defaultFeaturesStatus;
  }
}

Future<void> saveProductConfig(Map<String, bool> data) async {
  final configKey = getProductConfigKey();
  await NyStorage.store(configKey, jsonEncode(data), inBackpack: true);
}

class SettingProductPage extends NyStatefulWidget {
  final Controller controller = Controller();

  static const path = '/setting-product';

  SettingProductPage({Key? key}) : super(key: key);

  @override
  _SettingProductPageState createState() => _SettingProductPageState();
}

class _SettingProductPageState extends NyState<SettingProductPage> {
  Map<String, bool> featuresStatus = {};

  @override
  init() async {
    super.init();
    featuresStatus = await getProductConfig();
    setState(() {});
  }

  @override
  void dispose() {
    super.dispose();
  }

  void saveConfig() async {
    try {
      await saveProductConfig(featuresStatus);
      CustomToast.showToastSuccess(context,
          description: "Lưu cài đặt thành công");
      Navigator.pop(context);
      // routeTo(ListProductPage.path);
    } catch (e) {
      print(e);
      CustomToast.showToastError(context, description: "Lưu cài đặt thất bại");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cài đặt tạo sản phẩm'),
      ),
      body: SafeArea(
        child: Container(
            child: ListView.separated(
          itemCount: features.length,
          separatorBuilder: (context, index) => Divider(),
          itemBuilder: (context, index) {
            if (features[index]['key'] == 'product_whoolsale_cost' &&
                !Auth.user<User>()!.showWholeSale) {
              features.remove(features[index]);
            }
            return ListTile(
              title: Text(features[index]['title'] ?? ''),
              trailing: Switch(
                inactiveThumbColor: Colors.white,
                activeColor: ThemeColor.get(context).primaryAccent,
                value: featuresStatus[features[index]['key']] ?? false,
                onChanged: (value) {
                  setState(() {
                    featuresStatus[features[index]['key']!] = value;
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
