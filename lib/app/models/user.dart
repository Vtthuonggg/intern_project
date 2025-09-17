import 'dart:developer';

import 'package:flutter_app/app/utils/dashboard.dart';
import 'package:nylo_framework/nylo_framework.dart';

class User extends Model {
  int? id;
  String? name;
  String? email;
  String? phone;
  String? address;
  int? type;
  List<String> roles = [];
  List<String> permissions = [];
  bool? isAction;
  DateTime? createdAt;
  num? money;
  num? moneySub;
  int? businessId;
  CareerType careerType = CareerType.other;
  int usingDays = 0;
  dynamic miniApp;
  dynamic theme;
  bool? isManager;
  String? apiKey;
  String? seri;
  num? vat;
  int storeId = -1;
  bool isPos = false;
  bool isPosSunmi = false;
  String? deviceId;
  User();

  User.fromJson(dynamic data) {
    id = data['id'];
    miniApp = data['miniapp'];
    theme = data['theme'];
    name = data['name'];
    email = data['email'];
    address = data['address'];
    type = data['type'];
    moneySub = data?['money_sub'];
    money = data?['money'];
    roles = data['roles'] != null ? List<String>.from(data['roles']) : [];
    permissions = data['permissions'] != null
        ? List<String>.from(data['permissions'])
        : [];
    isAction = data['is_action'];
    phone = data['phone'];
    createdAt = data['created_at'] != null
        ? DateTime.parse(data['created_at'])
        : DateTime.now();
    businessId = data['business_id'];
    isManager = data['is_management'] ?? false;
    apiKey = data['api_key'];
    seri = data['seri'];
    setCareerType();
    usingDays = data['using_days'] != null ? data['using_days'] : 0;

    vat = data['vat'];
  }

  setCareerType() {
    careerType = CareerTypeExtension.fromValue(businessId);
  }

  toJson() => {
        "id": id,
        "name": name,
        "email": email,
        "address": address,
        "roles": roles,
        "permissions": permissions,
        "is_action": isAction,
        "phone": phone,
        "type": type,
        "created_at": createdAt?.toString(),
        'business_id': businessId,
      };

  get editProductPath => careerType.editProductPath();

  bool get showWholeSale =>
      [6, 7, 8, 9, 10, 11, 17, 19, 20, 21].contains(businessId);

  bool get showImei =>
      [6, 7, 8, 9, 10, 11, 17, 19, 20, 21].contains(businessId);

  bool get showBarcode =>
      [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 17, 19, 20, 21].contains(businessId);

  bool get allowCreateProductFromFile =>
      [6, 7, 8, 9, 10, 11, 17, 19, 20, 21].contains(businessId);

  bool get allowCreateBulkProduct =>
      [6, 7, 8, 9, 10, 11, 17, 19, 20, 21].contains(businessId);

  bool get allowCreateBulkProductService =>
      [1, 4, 3, 5, 21].contains(businessId);

  get notifyChannel => "private-App.Notify.${id}";

  bool get isPosRoomUser =>
      isPos &&
      (careerType == CareerType.cafe || careerType == CareerType.restaurant);
}

enum CareerType {
  bia,
  restaurant,
  cafe,
  karaoke,
  hostel,
  hotel,
  other,
  nail,
  football
}

extension CareerTypeExtension on CareerType {
  String editProductPath() {
    switch (this) {
      default:
        return EditProductPage.path;
    }
  }

  List<DashboardItem> get dashboardItems {
    switch (this) {
      case CareerType.other: // Kiểu tạo đơn bán hàng
        return [
          DashboardItem.OrderPurchase,
          DashboardItem.OrderList,
          DashboardItem.OrderSale,
          DashboardItem.Storage,
          DashboardItem.CashBook,
          DashboardItem.Employee,
          DashboardItem.Customer,
          DashboardItem.Supplier,
          DashboardItem.Report,
          // DashboardItem.Salary,
          // DashboardItem.TimekeepingCreate,
          // DashboardItem.TimekeepingReport,
          // DashboardItem.Works,
        ];
      default: // Kiểu tạo đơn bán theo phòng/ bàn
        return [
          DashboardItem.Table,
          DashboardItem.OrderList,
          DashboardItem.OrderPurchase,
          DashboardItem.Service,
          DashboardItem.Storage,
          DashboardItem.CashBook,
          DashboardItem.Employee,
          DashboardItem.Customer,
          DashboardItem.Supplier,
          DashboardItem.Report,
          // DashboardItem.Salary,
          // DashboardItem.TimekeepingCreate,
          // DashboardItem.TimekeepingReport,
          // DashboardItem.Works,
        ];
    }
  }

  static CareerType fromValue(int? value) {
    switch (value) {
      case 1:
        return CareerType.bia;
      case 2:
        return CareerType.restaurant;
      case 3:
        return CareerType.karaoke;
      case 4:
        return CareerType.hostel;
      case 5:
        return CareerType.hotel;
      case 12:
        return CareerType.cafe;
      case 19:
        return CareerType.other;
      case 21:
        return CareerType.football;
      default:
        return CareerType.other;
    }
  }
}
