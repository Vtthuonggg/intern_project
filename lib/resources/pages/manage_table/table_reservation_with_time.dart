import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:collection/collection.dart';
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/app/models/customer.dart';
import 'package:flutter_app/app/models/product.dart';
import 'package:flutter_app/app/models/storage_item.dart';
import 'package:flutter_app/app/models/user.dart';
import 'package:flutter_app/app/networking/config_time_api_service.dart';
import 'package:flutter_app/app/networking/customer_api_service.dart';
import 'package:flutter_app/app/networking/get_point_api.dart';
import 'package:flutter_app/app/networking/order_api_service.dart';
import 'package:flutter_app/app/networking/price_policy_api_service.dart';
import 'package:flutter_app/app/networking/product_api_service.dart';
import 'package:flutter_app/app/networking/room_api_service.dart';
import 'package:flutter_app/app/utils/formatters.dart';
import 'package:flutter_app/app/utils/getters.dart';
import 'package:flutter_app/app/utils/message.dart';
import 'package:flutter_app/app/utils/service_fee.dart';
import 'package:flutter_app/app/utils/socket_manager.dart';
import 'package:flutter_app/app/utils/text.dart';
import 'package:flutter_app/bootstrap/helpers.dart';
import 'package:flutter_app/resources/pages/add_storage_page.dart';
import 'package:flutter_app/resources/pages/customer/customer_search_order.dart';
import 'package:flutter_app/resources/pages/manage_table/config_fee/config_time_page.dart';
import 'package:flutter_app/resources/pages/order/list_order_page.dart';
import 'package:flutter_app/resources/pages/order_invoice_page.dart';
import 'package:flutter_app/resources/pages/product/edit_product_page.dart';
import 'package:flutter_app/resources/pages/setting/setting_order_sale_page.dart';
import 'package:flutter_app/resources/widgets/breadcrumb.dart';
import 'package:flutter_app/resources/widgets/product_scan.dart';
import 'package:flutter_app/resources/widgets/quantity_form_field.dart';
import 'package:flutter_app/resources/widgets/single_tap_detector.dart';
import 'package:flutter_app/resources/widgets/manage_table/table_item.dart';
import 'package:flutter_app/resources/widgets/manage_table/select_multi_variant.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:intl/intl.dart';
import 'package:nylo_framework/nylo_framework.dart';
import '/app/controllers/controller.dart';
import 'package:flutter_app/resources/pages/custom_toast.dart';

class TableReservationWithTimePage extends NyStatefulWidget {
  final Controller controller = Controller();

  static const path = '/table-reservation-with-time';

  TableReservationWithTimePage({Key? key}) : super(key: key);

  @override
  _TableReservationPageState createState() => _TableReservationPageState();
}

class _TableReservationPageState extends NyState<TableReservationWithTimePage> {
  final discountController = TextEditingController();
  final vatController = TextEditingController();
  bool _toastShown = false;

  final selectMultiKey = GlobalKey<DropdownSearchState<StorageItem>>();
  int? orderId;
  bool _isShowingScan = false;
  String? _scanError;
  DiscountType _discountType = DiscountType.percent;
  Map<String, bool> featuresConfig = {};
  String get roomId => widget.data()['room_id'].toString();
  String? get buttonType => widget.data()['button_type'].toString();
  TableStatus get currentRoomType => TableStatusExtension.fromValue(
      widget.data()['current_room_type'].toString());

  bool get isEditing => widget.data()?['edit_data'] != null;

  dynamic get editData => widget.data()?['edit_data'];

  bool get showPay => widget.data()?['show_pay'] ?? false;

  String? get note => widget.data()?['note'];

  final GlobalKey<FormBuilderState> _formKey = GlobalKey<FormBuilderState>();

  List<StorageItem> selectedItems = [];
  bool _isLoading = false;
  dynamic selectedTableFee;
  Map<int, num> variantToCurrentBaseCost = {}; // current base cost of variant

  bool isWholesale = false;
  SocketManager _socketManager = SocketManager();

  List<dynamic> _serviceFeeConfig = [];
  int invoiceId = 0;
  dynamic _roomFuture;
  dynamic roomDetail;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  List<dynamic> otherFee = [];
  List<dynamic> cloneOtherFee = [];
  num getOtherFee = 0;
  bool isReload = true;
  int? selectedCustomerId;
  Map<String, dynamic>? selectedPromotion;
  final selectMultiKeyCustomer = GlobalKey<DropdownSearchState<Customer>>();
  Customer? selectedCustomer;
  final GlobalKey<CustomerSearchOrderState> _multiSelectKeyCustomer =
      GlobalKey<CustomerSearchOrderState>();

  int? currentPolicy;
  List<dynamic> listPolicies = [];
  List<dynamic> saveChangeProductPrice = [];

  List<dynamic> otherFeeList = [];
  final SlidableController slidableController = SlidableController();

  int costPoint = 0;
  int totalPointCost = 0;
  num lostCost = 0;
  int customerPoint = 0;
  TextEditingController _pointController = TextEditingController();
  bool isAutoServicePrice = false;
  dynamic minutesConfig = {};
  @override
  init() async {
    super.init();
    getSelectedInvoiceId();
    await fetchRoomDetail();
    if (!isEditing) {
      await _fetchListPolicies();
    }
    await _initServiceFeeConfig();
    final config = await getOrderSaleConfig();
    setState(() {
      featuresConfig = config;
    });

    if (isEditing) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _patchEditData(context));
    } else {
      _formKey.currentState!.patchValue({
        'note': note,
      });
    }
    await _fetchListFee();
    getDataPointCost();
  }

  getDataPointCost() async {
    try {
      final response = await api<PointApi>((request) => request.getPoint());
      if (response['data'] != null) {
        costPoint = response['data']['cost'];
      }
    } catch (e) {
      print(e);
    }
  }

  getPointCost(int point) {
    totalPointCost = point * costPoint;
    String valueStr = point.toString();

    if (valueStr.length > 1) {
      int lostValue = int.parse(valueStr.substring(0, valueStr.length - 1));
      lostCost = lostValue * costPoint;
    } else {
      lostCost = 0;
    }
    setState(() {});
  }

  getPreviousCost(int point) {
    return point * costPoint;
  }

  checkValidatePoint(String value) {
    if (_isLoading) {
      return;
    }
    int parsedValue = stringToInt(value) ?? 0;
    String newValue =
        value.substring(0, value.length != 0 ? value.length - 1 : value.length);

    if (parsedValue > customerPoint) {
      CustomToast.showToastError(context,
          description: "Không được quá số điểm khách hiện có");
      Future.delayed(Duration(milliseconds: 100), () {
        _pointController.text = newValue;
        _pointController.selection = TextSelection.fromPosition(
            TextPosition(offset: _pointController.text.length));
      });
      return;
    }
    if (totalPointCost > getFinalPrice()) {
      CustomToast.showToastError(context,
          description: "Số tiền quy đổi không được lớn hơn số tiền phải trả");
      Future.delayed(Duration(milliseconds: 100), () {
        _pointController.text = newValue;
        _pointController.selection = TextSelection.fromPosition(
            TextPosition(offset: _pointController.text.length));
      });
      return;
    }
  }

  Future _fetchListFee() async {
    try {
      final response =
          await api<OrderApiService>((request) => request.getListFee());
      otherFeeList = response;
      setState(() {});
    } catch (e) {
      CustomToast.showToastError(context, description: 'Có lỗi xảy ra');
    }
  }

  Future _deleteFee(int id) async {
    try {
      await api<OrderApiService>((request) => request.deleteFee(id));
      CustomToast.showToastSuccess(context, description: "Xóa thành công");
      setState(() {});
      // await _fetchListFee();
      Navigator.pop(context);
      Navigator.pop(context);
      _showDialogOtherFee();
    } catch (e) {
      CustomToast.showToastError(context, description: 'Có lỗi xảy ra');
    }
  }

  Future _fetchListPolicies() async {
    try {
      final response = await api<PricePolicyApiService>(
          (request) => request.getAllPolicy(1, 100, 1));
      for (var item in response) {
        if (item['type'] == 1) {
          listPolicies.add(item);
        }
      }
      setState(() {});
    } catch (e) {
      CustomToast.showToastError(context, description: "Có lỗi xảy ra");
    }
  }

  Future<Customer> getCustomerWithId(int customerId) async {
    try {
      final items = await api<CustomerApiService>(
          (request) => request.getCustomerDetail(customerId));

      return items;
    } catch (e) {
      String errorMessage = getResponseError(e);
      CustomToast.showToastError(context, description: errorMessage);
      return Customer();
    }
  }

  Future<void> _patchEditData(BuildContext context) async {
    if (!isReload) {
      return;
    }
    await _fetchListPolicies();
    setState(() {
      _isLoading = true;
    });
    if (editData['point'] != null) {
      getPointCost(editData['point']);
    }
    DateTime startDateTime =
        DateTime.parse('${editData['date']} ${editData['hour']}');
    DateTime startDate =
        DateTime(startDateTime.year, startDateTime.month, startDateTime.day);
    DateTime startTime =
        DateTime(0, 1, 1, startDateTime.hour, startDateTime.minute);

    DateTime? endDate;
    DateTime? endTime;
    if (editData['date_end'] != null && editData['hour_end'] != null) {
      DateTime endDateTime =
          DateTime.parse('${editData['date_end']} ${editData['hour_end']}');
      endDate = DateTime(endDateTime.year, endDateTime.month, endDateTime.day);
      endTime = DateTime(0, 1, 1, endDateTime.hour, endDateTime.minute);
    }
    selectedPromotion = editData['promotion'];
    if (editData['order_service_fee'] != null) {
      for (var item in editData['order_service_fee']) {
        getOtherFee += item['price'];
      }
    }
    currentPolicy = editData['policy_id'];

    otherFee = (editData['order_service_fee'] ?? []).map((fee) {
      return {
        'id': fee['id'],
        'name': fee['name'],
        'price': fee['price'],
      };
    }).toList();
    cloneOtherFee = [...otherFee];
    selectedItems = [];
    isWholesale = !(editData?['is_retail'] ?? true);
    _discountType = DiscountType.values.firstWhereOrNull((element) =>
            element.getValueRequest() == editData['discount_type']) ??
        DiscountType.percent;
    _formKey.currentState!.patchValue({
      'note': note,
      'point': editData['point'].toString(),
      'room_service_id': editData['room_service_price_id'] != null &&
              editData['room_service_id'] != null
          ? int.parse(
              '${editData['room_service_id']}${editData['room_service_price_id']}')
          : editData['room_service_id'],
      'start_date': startDate,
      'start_time': startTime,
      'end_time': showPay ? DateTime.now() : endTime,
      'end_date': showPay
          ? DateTime.now()
          : (endDate != null ? endDate : DateTime.now()),
      'number_customer': editData['number_customer'],
      'time_intend': editData['time_intend'],
      'status_order': 1,
      // 'vat': (editData['vat'] != null && editData['vat'] != 0)
      //     ? editData['vat']
      //     : '0',
      'discount': (editData['discount'] != null && editData['discount'] != 0)
          ? (_discountType == DiscountType.percent
              ? roundQuantity(editData['discount'])
              : vnd.format(editData['discount']))
          : '',
      'payment_type':
          (editData['order_payment'] as List<dynamic>).firstOrNull['type'],
      'paid': editData['order_payment'] != null
          ? vnd.format((editData['order_payment'] as List<dynamic>)
                  .map((e) => e['price'])
                  .reduce((value, element) => value + element) -
              totalPointCost)
          : '',
      'address': editData['address'],
      'other_fee': vnd.format(getOtherFee),
      'create_date': editData['created_at'] != null
          ? DateTime.parse(editData['created_at']).toLocal()
          : null,
    });
    _startDate = startDate;
    _endDate = endDate ?? DateTime.now();

    selectedCustomerId = editData?['customer_id'];
    if (editData?['customer_id'] != null) {
      var customer = await getCustomerWithId(editData['customer_id']);
      selectedCustomer = customer;
    }
    orderId = editData['id'];
    var listOrder = editData['order_detail'] as List<dynamic>;
    for (Map<String, dynamic> item in listOrder) {
      var selectItem = StorageItem.fromJson(item['variant']);
      selectItem.product = Product.fromJson(item['product']);
      selectItem.quantity = (item['quantity'] as num).toDouble();
      selectItem.discount = item['discount'];
      selectItem.productNotes = item['order_detail_note'] != null
          ? item['order_detail_note']
              .map((note) => Map<String, dynamic>.from(note))
              .toList()
          : [];
      if (isWholesale) {
        selectItem.wholesaleCost = item['user_cost'];
        selectItem.retailCost = item['variant']['retail_cost'];
        selectItem.txtPrice.text = vnd.format(selectItem.wholesaleCost ?? 0);
      } else {
        selectItem.wholesaleCost = item['wholesale_cost'];
        // selectItem.baseCost = item['base_cost'];
        selectItem.retailCost = item['user_cost'];
        selectItem.txtPrice.text = vnd.format(selectItem.retailCost ?? 0);
      }
      final policy = selectItem.policies?.firstWhereOrNull(
        (element) => element['policy_id'] == currentPolicy,
      );
      if (policy != null && policy['policy_value'] != null) {
        selectItem.policyPrice = stringToInt(policy['policy_value'] ?? '0');
      } else {
        selectItem.policyPrice = 0;
      }
      if (stringToInt(selectItem.txtPrice.text) !=
              selectItem.copyWholesaleCost &&
          stringToInt(selectItem.txtPrice.text) != selectItem.copyRetailCost &&
          stringToInt(selectItem.txtPrice.text) != selectItem.policyPrice) {
        selectItem.overriddenPrice = stringToInt(selectItem.txtPrice.text);
        selectItem.isManuallyEdited = true;
      }
      selectItem.discountType = DiscountType.values.firstWhereOrNull(
              (element) =>
                  element.getValueRequest() == item['discount_type']) ??
          DiscountType.percent;
      selectItem.txtQuantity.text = item['quantity'].toString();
      selectItem.product?.vat = item['vat'];
      selectItem.txtVAT.text = roundQuantity(item['vat']);
      selectedItems.add(selectItem);
      _formKey.currentState?.patchValue({
        '${selectItem.id}.quantity': item['quantity'].toString(),
        '${selectItem.id}.discount':
            selectItem.discountType == DiscountType.percent
                ? selectItem.discount.toString()
                : vnd.format((selectItem.discount ?? 0) / selectItem.quantity),
      });
    }
    setState(() {
      _isLoading = false;
    });
    updatePromotion();
    updatePaid();
  }

  Future<Map<String, bool>> getOrderSaleConfig() async {
    try {
      final configKey = getOrderSaleConfigkey();
      final data = await NyStorage.read(configKey,
          defaultValue: jsonEncode(defaultFeatturesStatus));
      if (data is String) {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          return Map<String, bool>.from(decoded);
        }
      }
      return defaultFeatturesStatus;
    } catch (e) {
      return defaultFeatturesStatus;
    }
  }

  Future<void> getSelectedInvoiceId() async {
    try {
      int? selectedInvoiceId = await NyStorage.read('selectedInvoiceId');
      if (selectedInvoiceId != null) {
        invoiceId = selectedInvoiceId;
      }
    } catch (e) {}
  }

  Future<dynamic> fetchRoomDetail() async {
    _roomFuture =
        api<RoomApiService>((request) => request.fetchRoom(int.parse(roomId)));

    roomDetail = await _roomFuture;
    selectedPromotion = roomDetail['promotion'];
    setState(() {});
  }

  _initServiceFeeConfig() async {
    try {
      final response =
          await api<ConfigTimeApiService>((request) => request.getConfigTime());

      final List<dynamic> commonConfigs = response.data['data'];
      isAutoServicePrice =
          commonConfigs.isNotEmpty ? commonConfigs.first['is_sync'] : false;
      final isAll =
          commonConfigs.isNotEmpty ? commonConfigs.first['is_all'] : false;
      List<dynamic> configs =
          isAll ? commonConfigs : (roomDetail['service'] ?? []);
      configs = await configs.where((element) {
        return element['status'] == true;
      }).toList();
      minutesConfig = configs.first;
      setState(() {
        _serviceFeeConfig = flattenConfigs(configs);
      });
      await Future.delayed(Duration(milliseconds: 100), () {});
    } catch (e) {
      CustomToast.showToastError(context, description: getResponseError(e));
    }
  }

  clearAllData() {
    _formKey.currentState!.patchValue({
      'status_order': 1,
      'discount': '',
      'payment_type': 1,
      'point': '',
      'paid': '',
      'address': '',
      'number_customer': 1,
      'time_intend': 60,
      'create_date': null,
    });
    vatController.text = '';
    getOtherFee = 0;
    selectedCustomerId = null;
    _discountType = DiscountType.percent;
    selectedCustomer = null;
    selectedItems = [];
    setState(() {});
  }

  @override
  void dispose() {
    super.dispose();
  }

  List<dynamic> flattenConfigs(List<dynamic> configs) {
    List<dynamic> flattenedList = [];

    for (var config in configs) {
      flattenedList.add({
        "id": config["id"],
        "user_id": config["user_id"],
        "price": config["price"],
        "unit": config["unit"],
        "unit_name": config["unit_name"],
        "is_all": config["is_all"],
        "created_at": config["created_at"],
        "updated_at": config["updated_at"],
        "status": config["status"],
        "type": config["type"],
        "prices": config["price"],
      });

      for (var price in config["prices"] ?? []) {
        flattenedList.add({
          "id": int.parse("${config['id']}${price['id']}"),
          "price_id": price["id"],
          "room_service_id": price["room_service_id"],
          "config_service_id": price["config_service_id"],
          "price": price["price"],
          "start": price["start"],
          "end": price["end"],
          "created_at": price["created_at"],
          "updated_at": price["updated_at"],
          "unit": config["unit"],
          "unit_name": config["unit_name"],
          "type": config["type"],
          "parent_id": config["id"],
        });
      }
    }

    return flattenedList;
  }

  void addItem(StorageItem item) {
    var index = selectedItems.indexWhere((element) => element.id == item.id);
    if (index == -1) {
      setState(() {
        selectedItems.insert(0, item);
        variantToCurrentBaseCost[item.id!] =
            (isWholesale ? item.wholesaleCost : item.retailCost) ?? 0;
        num price = 0;
        if (item.isManuallyEdited && item.overriddenPrice != null) {
          price = item.overriddenPrice!;
        } else if (currentPolicy != null && item.policies != null) {
          final policy = item.policies!.firstWhereOrNull(
            (e) => e['policy_id'] == currentPolicy,
          );
          if (policy != null && policy['policy_value'] != null) {
            item.policyPrice =
                stringToInt(policy['policy_value'].replaceAll('.', '')) ?? 0;
            if (item.policyPrice == 0) {
              price = isWholesale
                  ? item.copyWholesaleCost ?? 0
                  : item.copyRetailCost ?? 0;
            } else {
              price = item.policyPrice ?? 0;
            }
          }
        } else {
          price = isWholesale
              ? item.copyWholesaleCost ?? 0
              : item.copyRetailCost ?? 0;
        }
        item.txtPrice.text = vnd.format(price ?? 0);
      });
    } else {
      setState(() {
        selectedItems[index].quantity += 1;
        _formKey.currentState!.patchValue({
          '${item.id}.quantity': '${selectedItems[index].quantity}',
        });
      });
    }
    updatePaid();
  }

  void addMultiItems(List<StorageItem> items) {
    if (items.isEmpty) {
      for (var i in selectedItems) {
        removeItem(i);
      }
      return;
    }
    for (var item in items) {
      num price = 0;

      if (item.isManuallyEdited && item.overriddenPrice != null) {
        price = item.overriddenPrice!;
      } else if (currentPolicy != null && item.policies != null) {
        final policy = item.policies!.firstWhereOrNull(
          (e) => e['policy_id'] == currentPolicy,
        );
        if (policy != null && policy['policy_value'] != null) {
          item.policyPrice =
              stringToInt(policy['policy_value'].replaceAll('.', '')) ?? 0;
          if (item.policyPrice == 0) {
            price = isWholesale
                ? item.copyWholesaleCost ?? 0
                : item.copyRetailCost ?? 0;
          } else {
            price = item.policyPrice ?? 0;
          }
        } else {
          price = isWholesale
              ? item.copyWholesaleCost ?? 0
              : item.copyRetailCost ?? 0;
        }
      } else {
        price = isWholesale
            ? item.copyWholesaleCost ?? 0
            : item.copyRetailCost ?? 0;
      }
      setState(() {});

      if (selectedItems.indexWhere((element) => element.id == item.id) == -1) {
        setState(() {
          selectedItems.insert(0, item);
          variantToCurrentBaseCost[item.id!] =
              (isWholesale ? item.wholesaleCost : item.retailCost) ?? 0;
          item.txtPrice.text = vnd.format(price);
        });
      } else {
        for (var i in selectedItems) {
          if (items.firstWhereOrNull((element) => element.id == i.id) == null) {
            removeItem(i);
          } else {
            item.txtPrice.text = vnd.format(price);
          }
        }
        // removeItem(item);
      }
    }
    resetItemPrice();
    updatePaid();
  }

  void removeItem(StorageItem item) {
    item.quantity = 1;
    _formKey.currentState
        ?.patchValue({'${item.id}.quantity': '${item.quantity}'});
    _formKey.currentState?.patchValue({
      '${item.id}.price':
          vnd.format(isWholesale ? item.copyWholesaleCost : item.copyRetailCost)
    });
    _formKey.currentState?.patchValue({
      '${item.id}.discount': item.discountType == DiscountType.price
          ? vnd.format(item.copyDiscount ?? 0)
          : roundQuantity(item.copyDiscount ?? 0)
    });
    setState(() {
      selectedItems.remove(item);
      _formKey.currentState!.patchValue({
        'point': '0',
      });
      resetItemPrice();
    });
    updatePaid();
  }

  void updatePaid() {
//update vat
    num totalVat = 0;
    for (var item in selectedItems) {
      dynamic retailCostValue =
          _formKey.currentState?.value['${item.id}.price'];
      dynamic quantityValue = item.quantity.toString();
      num retailCost = stringToInt(retailCostValue) ?? item.retailCost ?? 0;
      num wholesaleCost =
          stringToInt(retailCostValue) ?? item.wholesaleCost ?? 0;
      num quantity = num.tryParse(quantityValue) ?? 0;
      num total =
          isWholesale ? wholesaleCost * quantity : retailCost * quantity;
      num discountVal = (item.discount ?? 0);
      num discountPrice = item.discountType == DiscountType.percent
          ? total * discountVal / 100
          : discountVal;
      total = total - discountPrice;
      if (item.product?.useVat ?? true) {
        var vat = item.product?.vat ?? 0;
        if (vat > 0) {
          totalVat += total * vat / 100;
        }
      }
    }
    vatController.text = vnd.format(totalVat);

    //update paid
    num finalPrice = getFinalPrice();
    _formKey.currentState!.fields['paid']!
        .didChange(vnd.format(roundMoney(finalPrice)));
  }

  num getTotalQty(List<StorageItem> items) {
    num total = 0;
    for (var item in items) {
      total += item.quantity ?? 0;
    }
    return total;
  }

  Future<List<StorageItem>> _fetchVariantItems(String search) async {
    try {
      final items = await api<ProductApiService>(
          (request) => request.listVariant(search));

      // filter out items that already exists
      return items
          .where((element) =>
              selectedItems.indexWhere((item) => item.id == element.id) == -1)
          .toList();
    } catch (e) {
      String errorMessage = getResponseError(e);
      CustomToast.showToastError(context, description: errorMessage);
      return [];
    }
  }

  Future submit(TableStatus roomType, {bool isPay = false}) async {
    if (!selectedItems.isEmpty &&
        selectedItems.firstWhereOrNull((element) => element.quantity == 0) !=
            null) {
      CustomToast.showToastError(context,
          description: "Vui lòng chọn số lượng món");
      return;
    }
    if (!_formKey.currentState!.saveAndValidate()) {
      return;
    }
    filterNewFee();
    if (isEditing) {
      await updateOrder(roomType, isPay: isPay);
    } else {
      await saveOrder(roomType, isPay: isPay);
    }
  }

  void filterNewFee() {
    cloneOtherFee.removeWhere((element) => element['name'].isEmpty);
    if (!isEditing) {
      otherFee = cloneOtherFee;
    } else {
      for (var fee in cloneOtherFee) {
        if (!fee.containsKey('id')) {
          otherFee.add(fee);
        }
      }

      for (var fee in otherFee) {
        if (!cloneOtherFee.any((cloneFee) => cloneFee['id'] == fee['id'])) {
          fee['is_delete'] = true;
        }
      }
    }
  }

  void showCreateFee({dynamic item}) {
    String? feeName = item != null ? item['name'] : "";
    bool _loading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, SetState) {
          Future _createNewFee() async {
            try {
              dynamic payload = {
                'name': feeName,
              };
              await api<OrderApiService>(
                  (request) => request.createNewFee(payload));
              setState(() {});
              CustomToast.showToastSuccess(context,
                  description: "Tạo mới thành công");
              Navigator.pop(context);
              // Trong showCreateFee, sau khi tạo mới thành công:
              Navigator.pop(context);
              Navigator.pop(context);
              _showDialogOtherFee();
            } catch (e) {
              CustomToast.showToastError(context, description: 'Có lỗi xảy ra');
            }
          }

          Future _updateNewFee(int id) async {
            try {
              dynamic payload = {
                'name': feeName,
              };
              await api<OrderApiService>(
                  (request) => request.editFee(item['id'], payload));
              setState(() {});
              CustomToast.showToastSuccess(context,
                  description: "Sửa thành công");
              Navigator.pop(context);
              Navigator.pop(context);
              Navigator.pop(context);

              _showDialogOtherFee();
            } catch (e) {
              CustomToast.showToastError(context, description: 'Có lỗi xảy ra');
            }
          }

          Future submit({bool? isEdit, int? id}) async {
            setState(() {
              _loading = true;
            });
            if (feeName == null || feeName!.isEmpty) {
              CustomToast.showToastError(context,
                  description: "Tên không được để trống");
              return;
            }

            if (item != null) {
              await _updateNewFee(item['id']);
            } else {
              await _createNewFee();
            }
            await _fetchListFee();
            setState(() {
              _loading = false;
            });
          }

          return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10.0))),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    (item != null) ? 'Sửa chi phí' : 'Tạo chi phí',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  InkWell(
                    child: Icon(Icons.close),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  )
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Divider(
                      color: Colors.grey,
                    ),
                    SizedBox(height: 10),
                    TextFormField(
                      initialValue: feeName ?? '',
                      onChanged: (value) => feeName = value,
                      cursorColor: ThemeColor.get(context).primaryAccent,
                      decoration: InputDecoration(
                        labelText: 'Tên chi phí',
                        hintText: 'Nhập tên',
                        labelStyle: TextStyle(color: Colors.grey[700]),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color: ThemeColor.get(context).primaryAccent)),
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                      ),
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              actions: [
                Center(
                  child: TextButton(
                    style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        backgroundColor: ThemeColor.get(context)
                            .primaryAccent
                            .withOpacity(0.2),
                        foregroundColor: ThemeColor.get(context).primaryAccent),
                    onPressed: () {
                      submit();
                    },
                    child: _loading
                        ? CircularProgressIndicator()
                        : Text('Xác nhận'),
                  ),
                ),
              ]);
        });
      },
    );
  }

  void showListFee(dynamic otherFeeList) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, SetState) {
          return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10.0))),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      "Tên",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  InkWell(
                    child: Icon(Icons.close),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              content: SizedBox(
                height: 0.3.sh,
                width: 0.3.sw,
                child: ListView.builder(
                  itemCount: otherFeeList.length,
                  itemBuilder: (BuildContext context, int index) {
                    if (otherFeeList.isNotEmpty) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Divider(
                            color: Colors.grey,
                          ),
                          Slidable(
                            actionPane: SlidableDrawerActionPane(),
                            controller: slidableController,
                            actionExtentRatio: 0.3,
                            secondaryActions: <Widget>[
                              Padding(
                                padding: const EdgeInsets.all(5.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                  child: IconSlideAction(
                                    caption: 'Sửa',
                                    color: Colors.transparent,
                                    icon: Icons.edit,
                                    onTap: () {
                                      showCreateFee(item: otherFeeList[index]);
                                      slidableController.activeState?.close();
                                    },
                                    closeOnTap: false,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(5.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                  child: IconSlideAction(
                                    caption: 'Xóa',
                                    color: Colors.transparent,
                                    icon: Icons.delete,
                                    onTap: () {
                                      _deleteFee(otherFeeList[index]['id']);
                                      slidableController.activeState?.close();
                                    },
                                    closeOnTap: false,
                                  ),
                                ),
                              )
                            ],
                            child: ListTile(
                              title: Text(
                                otherFeeList[index]['name'],
                                style: TextStyle(fontSize: 17),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Center(
                          child: Text("Bạn chưa có danh sách chi phí"));
                    }
                  },
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                                color: ThemeColor.get(context).primaryAccent)),
                        backgroundColor: Colors.white.withOpacity(0.2),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        showCreateFee(item: null);
                      },
                      child: Text(
                        'Thêm mới',
                        style: TextStyle(
                            color: ThemeColor.get(context).primaryAccent),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          backgroundColor: ThemeColor.get(context)
                              .primaryAccent
                              .withOpacity(0.2),
                          foregroundColor:
                              ThemeColor.get(context).primaryAccent),
                      onPressed: () {
                        // submit();
                        Navigator.pop(context);
                        Navigator.pop(context);
                        _showDialogOtherFee();
                      },
                      child: Text('Xác nhận'),
                    ),
                  ],
                ),
              ]);
        });
      },
    );
  }

  void openConfigTimePage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ConfigTimePage()),
    );
    if (result != null && result == true) {
      await init();
      if (_serviceFeeConfig.length > 1) {
        setState(() {
          _formKey.currentState!.patchValue(
              {'room_service_id': _serviceFeeConfig[1]['id'] ?? null});
          updatePromotion();
        });
      }
    }
  }

  Future<void> _pay() async {
    if (_isLoading) {
      return;
    }
    for (var item in selectedItems) {
      for (var note in item.productNotes!) {
        if (note['name'].isEmpty) {
          CustomToast.showToastError(context,
              description: "Ghi chú sản phẩm không được để trống");
          return;
        }
      }
    }
    setState(() {
      _isLoading = true;
    });

    Map<String, dynamic> orderPayload =
        getOrderPayloadEditFromForm(currentRoomType);
    orderPayload['discount_type'] = _discountType.getValueRequest();

    orderPayload["status_order"] = 4;
    orderPayload["room_type"] = TableStatus.free.toValue();
    orderPayload["service_fee"] = getServiceFee();

    try {
      final res = await api<OrderApiService>(
          (request) => request.updateTableReservation(orderId!, orderPayload));
      _socketManager.sendEvent('user', {'user_id': Auth.user<User>()!.id});
      CustomToast.showToastSuccess(context,
          description: 'Thanh toán thành công');

      Navigator.of(context).pop();
      routeTo(OrderInvoicePage.path, data: {
        'id': orderId,
        'showCreate': false,
        'order_type': 1,
        'invoice_id': invoiceId,
        'customer_id': selectedCustomerId,
        'name': selectedCustomer?.name,
        'phone': selectedCustomer?.phone,
        'address': _formKey.currentState?.value['address'],
        'status_order': orderPayload['status_order'],
        'count_item': selectedItems.length,
        'payment_type': _formKey.currentState?.value['payment_type'],
        'order_service_fee':
            featuresConfig['other_fee'] != true ? [] : otherFee,
      });
    } catch (e) {
      CustomToast.showToastError(context, description: getResponseError(e));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<dynamic> getVariantNeedUpdateCost() {
    List<dynamic> changedBaseCost = [];
    selectedItems.forEach((item) {
      num currentBaseCost = variantToCurrentBaseCost[item.id] ?? 0;
      int newBaseCost =
          stringToInt(_formKey.currentState!.value['${item.id}.retail_cost']) ??
              0;

      if (currentBaseCost != newBaseCost) {
        changedBaseCost.add({
          'variant_id': item.id,
          'retail_cost': newBaseCost,
        });
      }
    });

    return changedBaseCost;
  }

  Future saveOrder(TableStatus roomType, {bool isPay = false}) async {
    for (var item in selectedItems) {
      for (var note in item.productNotes!) {
        if (note['name'].isEmpty) {
          CustomToast.showToastError(context,
              description: "Ghi chú sản phẩm không được để trống");
          return;
        }
      }
    }
    setState(() {
      _isLoading = true;
    });
    try {
      Map<String, dynamic> orderPayload =
          getOrderPayloadFromForm(roomType, isPay: isPay);
      Map<String, dynamic> res = await api<OrderApiService>(
          (request) => request.createTableReservation(orderPayload));
      if (isPay) {
        _socketManager.sendEvent('user', {'user_id': Auth.user<User>()!.id});
        CustomToast.showToastSuccess(context,
            description: 'Thanh toán thành công');

        Navigator.of(context).pop();
        routeTo(OrderInvoicePage.path, data: {
          'id': res['id'],
          'showCreate': false,
          'order_type': 1,
          'invoice_id': invoiceId,
          'customer_id': selectedCustomerId,
          'name': selectedCustomer?.name,
          'phone': selectedCustomer?.phone,
          'address': _formKey.currentState?.value['address'],
          'status_order': orderPayload['status_order'],
          'count_item': selectedItems.length,
          'payment_type': _formKey.currentState?.value['payment_type'],
          'order_service_fee':
              featuresConfig['other_fee'] != true ? [] : otherFee,
        });
      } else {
        Navigator.of(context).pop();
      }
      clearAllData();

      ;
    } catch (e) {
      CustomToast.showToastError(context, description: getResponseError(e));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future updateOrder(TableStatus roomType, {bool isPay = false}) async {
    for (var item in selectedItems) {
      for (var note in item.productNotes!) {
        if (note['name'].isEmpty) {
          CustomToast.showToastError(context,
              description: "Ghi chú sản phẩm không được để trống");
          return null;
        }
      }
    }
    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic> orderPayload =
          getOrderPayloadEditFromForm(roomType, isPay: isPay);
      orderPayload['discount_type'] = _discountType.getValueRequest();
      await api<OrderApiService>(
          (request) => request.updateTableReservation(orderId!, orderPayload));
      if (isPay) {
        _socketManager.sendEvent('user', {'user_id': Auth.user<User>()!.id});
        CustomToast.showToastSuccess(context,
            description: 'Thanh toán thành công');

        Navigator.of(context).pop();

        routeTo(OrderInvoicePage.path, data: {
          'id': orderId,
          'showCreate': false,
          'order_type': 1,
          'invoice_id': invoiceId,
          'customer_id': selectedCustomerId,
          'name': selectedCustomer?.name,
          'phone': selectedCustomer?.phone,
          'address': _formKey.currentState?.value['address'],
          'status_order': orderPayload['status_order'],
          'count_item': selectedItems.length,
          'payment_type': _formKey.currentState?.value['payment_type'],
          'order_service_fee':
              featuresConfig['other_fee'] != true ? [] : otherFee,
        });
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print(e);
      CustomToast.showToastError(context, description: getResponseError(e));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future cancelOrder(TableStatus roomType) async {
    Map<String, dynamic> orderPayload = getOrderPayloadFromForm(roomType);
    orderPayload['status_order'] = 5;
    setState(() {
      _isLoading = true;
    });
    try {
      await api<OrderApiService>(
          (request) => request.updateTableReservation(orderId!, orderPayload));
    } catch (e) {
      CustomToast.showToastError(context, description: getResponseError(e));
    }
    setState(() {
      _isLoading = false;
      Navigator.of(context).pop();
    });
  }

  dynamic getOrderPayloadFromForm(TableStatus roomType, {bool isPay = false}) {
    DateTime startDate = _formKey.currentState!.value['start_date'];
    DateTime startTime = _formKey.currentState!.value['start_time'];
    final date = startDate.toIso8601String().split('T')[0];
    final hour =
        startTime.toIso8601String().split('T')[1].split('.')[0].substring(0, 5);
    DateTime? createDate = _formKey.currentState!.value['create_date'];

    Map<String, dynamic> orderPayload = {
      'type': 3,
      'point': stringToInt(_formKey.currentState!.value['point']) ?? 0,
      'room_id': roomId,
      'room_type': roomType.toValue(),
      'is_retail': !isWholesale,
      'note': _formKey.currentState!.value['note'],
      'order_service_fee': featuresConfig['other_fee'] != true ? [] : otherFee,
      'phone': selectedCustomer?.phone ?? '',
      'customer_id': selectedCustomerId ?? null,
      'create_date': createDate != null
          ? DateFormat('yyyy/MM/dd HH:mm:ss').format(createDate)
          : null,
      'discount_type': _discountType.getValueRequest(),
      'name': selectedCustomer?.name ?? '',
      'address': _formKey.currentState!.value['address'],
      'status_order': isPay ? 4 : 1,
      'discount': _discountType == DiscountType.percent
          ? stringToDouble(_formKey.currentState!.value['discount']) ?? 0
          : stringToInt(_formKey.currentState!.value['discount']) ?? 0,
      // 'vat': stringToDouble(_formKey.currentState!.value['vat']) ?? 0,
      'service_fee': getServiceFee() - getPromotionPrice(),
      'number_customer': _formKey.currentState!.value['number_customer'] ?? 1,
      'time_intend': _formKey.currentState!.value['time_intend'] ?? 60,
      'date': date,
      'hour': hour,
      'room_service_id': selectedTableFee != null
          ? selectedTableFee['parent_id'] ?? selectedTableFee['id']
          : _formKey.currentState!.value['room_service_id'],
      'room_service_price_id':
          selectedTableFee != null && selectedTableFee['parent_id'] != null
              ? selectedTableFee['price_id']
              : null,
      'promotion_id': selectedPromotion?['id'],
      'order_detail': selectedItems.map((item) {
        return {
          'product_id': item.product?.id ?? 0,
          'variant_id': item.id ?? 0,
          'quantity': item.quantity ?? 1,
          'discount': item.discount ?? 0,
          'discount_type': item.discountType.getValueRequest(),
          'price': num.parse((item.txtPrice.text ?? '0').replaceAll('.', '')),
          'notes': item.productNotes,
          'vat': item.product?.vat ?? 0,
        };
      }).toList(),
      'payment': {
        "type": _formKey.currentState!.value['payment_type'],
        // if paid > final price, then set paid = final price
        "price": getPaid() > getFinalPrice() ? getFinalPrice() : getPaid(),
      }
    };

    DateTime? endDate = _formKey.currentState!.value['end_date'];
    DateTime? endTime = _formKey.currentState!.value['end_time'];
    if (endDate != null && endTime != null) {
      final dateEnd = endDate.toIso8601String().split('T')[0];
      final hourEnd =
          endTime.toIso8601String().split('T')[1].split('.')[0].substring(0, 5);

      orderPayload['date_end'] = dateEnd;
      orderPayload['hour_end'] = hourEnd;
    }
    return orderPayload;
  }

  dynamic getOrderPayloadEditFromForm(TableStatus roomType,
      {bool isPay = false}) {
    var lstOrder = editData['order_detail'] as List<dynamic>;
    List<Map<String, dynamic>> orderDetailRequest = [];
    for (Map<String, dynamic> order in lstOrder) {
      Map<String, dynamic> orderDetail = {
        'id': order['id'],
        'create_date': order['create_date'],
        'product_id': order['product']['id'] ?? 0,
        'variant_id': order['variant']['id'] ?? 0,
        'notes': order['order_detail_note'] ?? [],
      };
      var filterInSelected = selectedItems
          .firstWhereOrNull((element) => element.id == order['variant']['id']);
      if (filterInSelected != null) {
        orderDetail['is_delete'] = false;
        orderDetail['quantity'] = filterInSelected.quantity;
        orderDetail['discount'] = filterInSelected.discount ?? 0;
        orderDetail['note'] = filterInSelected.productNotes;
        orderDetail['discount_type'] =
            filterInSelected.discountType.getValueRequest();
        orderDetail['price'] = isWholesale
            ? filterInSelected.wholesaleCost
            : filterInSelected.retailCost;
        orderDetail['vat'] = filterInSelected.product?.vat ?? 0;

        for (var note in orderDetail['notes']) {
          bool found = false;
          for (var selectedNote in filterInSelected.productNotes!) {
            if (note['id'] == selectedNote['id']) {
              note['name'] = selectedNote['name'];
              note['price'] = selectedNote['price'];
              note['is_delete'] = false;
              note['variant_id'] = order['variant']['id'];

              found = true;
              break;
            }
          }
          if (!found) {
            note['is_delete'] = true;
            note['variant_id'] = order['variant']['id'];
          }
        }
        for (var selectedNote in filterInSelected.productNotes!) {
          if (selectedNote['id'] == null) {
            orderDetail['notes'].add({
              'name': selectedNote['name'],
              'price': selectedNote['price'],
              'variant_id': selectedNote['variant_id'],
            });
          }
        }
      } else {
        orderDetail['is_delete'] = true;
        orderDetail['quantity'] = order['quantity'];
        orderDetail['discount'] = order['discount'] ?? 0;
        orderDetail['discount_type'] = order['discountType'];
        orderDetail['price'] = 1;
      }
      orderDetailRequest.add(orderDetail);
    }
    for (var item in selectedItems) {
      if (lstOrder.firstWhereOrNull(
              (element) => element['variant']['id'] == item.id) ==
          null) {
        var newVal = {
          'product_id': item.product?.id ?? 0,
          'variant_id': item.id ?? 0,
          'quantity': item.quantity,
          'notes': item.productNotes,
          'vat': item.product?.vat ?? 0,
          'discount': item.discount ?? 0,
          'discount_type': item.discountType.getValueRequest(),
          'price': isWholesale ? item.wholesaleCost : item.retailCost
        };
        orderDetailRequest.add(newVal);
      }
    }

    DateTime startDate = _formKey.currentState!.value['start_date'];
    DateTime startTime = _formKey.currentState!.value['start_time'];
    final date = startDate.toIso8601String().split('T')[0];
    final hour =
        startTime.toIso8601String().split('T')[1].split('.')[0].substring(0, 5);
    DateTime? createDate = _formKey.currentState!.value['create_date'];
    Map<String, dynamic> orderPayload = {
      'type': 3, // 1: order, 2: storage
      'point': stringToInt(_formKey.currentState!.value['point']) ?? 0,
      'room_id': roomId,
      'room_type': roomType.toValue(),
      'date': date,
      'hour': hour,
      'create_date': createDate != null
          ? DateFormat('yyyy/MM/dd HH:mm:ss').format(createDate)
          : null,
      'policy_id': currentPolicy,
      'order_service_fee': featuresConfig['other_fee'] != true ? [] : otherFee,
      'number_customer': _formKey.currentState!.value['number_customer'],
      'time_intend': _formKey.currentState!.value['time_intend'],
      'room_service_id': selectedTableFee != null
          ? selectedTableFee['parent_id'] ?? selectedTableFee['id']
          : _formKey.currentState!.value['room_service_id'],
      'room_service_price_id':
          selectedTableFee != null && selectedTableFee['parent_id'] != null
              ? selectedTableFee['price_id']
              : null,
      'is_retail': !isWholesale,
      'discount_type': _discountType.getValueRequest(),
      'phone': selectedCustomer?.phone ?? '',
      'name': selectedCustomer?.name ?? '',
      'customer_id': selectedCustomerId ?? null,
      'address':
          _formKey.currentState!.value['address'] ?? widget.data()?['address'],
      'status_order': isPay ? 4 : 1,
      'discount': _discountType == DiscountType.percent
          ? stringToDouble(_formKey.currentState!.value['discount']) ?? 0
          : stringToInt(_formKey.currentState!.value['discount']) ?? 0,
      // 'vat': stringToDouble(_formKey.currentState!.value['vat']) ?? 0,
      'service_fee': getServiceFee() - getPromotionPrice(),
      'promotion_id': selectedPromotion?['id'],
      'payment': {
        "type": _formKey.currentState!.value['payment_type'],
        // if paid > final price, then set paid = final price
        "price": getPaid() > getFinalPrice() ? getFinalPrice() : getPaid(),
      },
      'order_detail': orderDetailRequest,
      'note': featuresConfig['note'] == true
          ? _formKey.currentState!.value['note']
          : widget.data()?['note'],
    };

    DateTime? endDate = _formKey.currentState!.value['end_date'];
    DateTime? endTime = _formKey.currentState!.value['end_time'];
    if (endDate != null && endTime != null) {
      final dateEnd = endDate.toIso8601String().split('T')[0];
      final hourEnd =
          endTime.toIso8601String().split('T')[1].split('.')[0].substring(0, 5);

      orderPayload['date_end'] = dateEnd;
      orderPayload['hour_end'] = hourEnd;
    }
    return orderPayload;
  }

  void checkDiscountOrder() {
    if (_isLoading) return;
    num discount = _discountType == DiscountType.price
        ? stringToInt(_formKey.currentState?.value['discount']) ?? 0
        : stringToDouble(_formKey.currentState?.value['discount']) ?? 0;
    if (_discountType == DiscountType.price && discount > getTotalPrice()) {
      if (!_toastShown) {
        CustomToast.showToastError(context,
            description: "Chiết khấu không được lớn hơn tổng tiền");
        _toastShown = true;
      }
      Future.delayed(Duration(milliseconds: 100), () {
        String currentText = discountController.text;
        if (currentText.isNotEmpty) {
          discountController.text = vnd.format(getTotalPrice());
          ;
          discountController.selection = TextSelection.fromPosition(
            TextPosition(offset: discountController.text.length),
          );
        }
      });

      return;
    }

    if (_discountType == DiscountType.percent && discount > 100) {
      Future.delayed(Duration(milliseconds: 100), () {
        discountController.text = '100';
        discountController.selection = TextSelection.fromPosition(
            TextPosition(offset: discountController.text.length));
      });
      return;
    }
    if (mounted) {
      setState(() {});
      updatePaid();

      _toastShown = false;
    }

    _toastShown = false;
  }

  void checkDiscountItem(StorageItem item) {
    if (_isLoading) return;
    num currentPrice =
        stringToInt(_formKey.currentState?.value['${item.id}.price']) ?? 0;
    num discount = item.discount ?? 0;
    if (item.discountType == DiscountType.price &&
        discount > currentPrice * item.quantity) {
      if (!_toastShown) {
        CustomToast.showToastError(context,
            description: "Chiết khấu không được lớn hơn đơn giá");
        _toastShown = true;
      }
      Future.delayed(Duration(milliseconds: 100), () {
        String currentText =
            _formKey.currentState?.value['${item.id}.discount'];
        if (currentText.isNotEmpty) {
          _formKey.currentState
              ?.patchValue({'${item.id}.discount': vnd.format(currentPrice)});
        }
      });
      return;
    }

    if (item.discountType == DiscountType.percent && discount > 100) {
      if (!_toastShown) {
        CustomToast.showToastError(context,
            description: "Chiết khấu không được lớn hơn 100%");
        _toastShown = true;
      }
      Future.delayed(Duration(milliseconds: 100), () {
        _formKey.currentState?.patchValue({'${item.id}.discount': '100'});
      });
      return;
    }
    if (mounted) {
      setState(() {});
      updatePaid();
      _toastShown = false;
    }
  }

  void checkOnChange() {
    int discountOrder =
        stringToInt(_formKey.currentState?.value['discount']) ?? 0;
    if (_discountType == DiscountType.price &&
        discountOrder > getTotalPrice()) {
      _formKey.currentState
          ?.patchValue({'discount': vnd.format(getTotalPrice())});
    }
  }

  num getPrice(StorageItem item) {
    dynamic quantityValue = item.quantity.toString();
    num retailCost =
        stringToInt(item.txtPrice.text) ?? item.copyRetailCost ?? 0;
    num quantity = num.tryParse(quantityValue) ?? 0;

    num total = retailCost * quantity;

    // discount
    num discountVal = (item.discount ?? 0);
    num discountPrice = item.discountType == DiscountType.percent
        ? total * discountVal / 100
        : discountVal;

    // apply discount
    total = total - discountPrice;
    if (item.product?.useVat ?? true) {
      var vat = item.product?.vat ?? 0;
      if (vat > 0) {
        total = total + total * vat / 100;
      }
    }
    return total;
  }

  // tổng tiền hàng
  num getTotalPrice() {
    num total = 0;
    selectedItems.forEach((item) {
      total += getPrice(item);
    });

    return total;
  }

  num getServiceFee() {
    if (_serviceFeeConfig.isEmpty) return 0;
    if (_formKey.currentState == null) return 0;

    final startDate = _formKey.currentState?.value['start_date'];
    final startTime = _formKey.currentState?.value['start_time'];
    final endDate = _formKey.currentState?.value['end_date'];
    final endTime = _formKey.currentState?.value['end_time'];

    DateTime? combinedStartDateTime, combinedEndDateTime;
    if (startDate != null && startTime != null) {
      combinedStartDateTime = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
        startTime.hour,
        startTime.minute,
      );
    }
    if (endDate != null && endTime != null) {
      combinedEndDateTime = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        endTime.hour,
        endTime.minute,
      );
    }
    if (combinedStartDateTime == null || combinedEndDateTime == null) return 0;

    if (isAutoServicePrice &&
        minutesConfig != null &&
        minutesConfig['prices'] != null) {
      final prices = minutesConfig['prices'] as List;
      final unit = minutesConfig['unit'] ?? 60;
      final parentPrice = minutesConfig['price'] ?? 0;

      // 1. Tạo biểu đồ giá 24h (1440 phút) mặc định là giá cha
      List<num> priceTimeline = List.filled(1440, parentPrice);

      // 2. Sắp xếp prices theo start time tăng dần
      final sortedPrices = [...prices];
      sortedPrices.sort((a, b) {
        final aStart = (a['start'] as String).split(':');
        final bStart = (b['start'] as String).split(':');
        final aMinute = int.parse(aStart[0]) * 60 + int.parse(aStart[1]);
        final bMinute = int.parse(bStart[0]) * 60 + int.parse(bStart[1]);
        return aMinute.compareTo(bMinute);
      });

      // 3. Gán giá từng khoảng, ưu tiên khoảng bắt đầu sớm hơn
      for (var priceConfig in sortedPrices) {
        final startParts = (priceConfig['start'] as String).split(':');
        final endParts = (priceConfig['end'] as String).split(':');
        int startMinute =
            int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
        int endMinute = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
        num price = priceConfig['price'] ?? 0;

        // Nếu end < start => qua ngày
        if (endMinute <= startMinute) endMinute += 1440;
        for (int i = startMinute; i < endMinute; i++) {
          int idx = i % 1440;
          // Chỉ gán nếu chưa bị khoảng trước đó đè lên (ưu tiên khoảng bắt đầu sớm hơn)
          if (priceTimeline[idx] == parentPrice) priceTimeline[idx] = price;
        }
      }

      // 4. Duyệt từng phút trong khoảng thời gian chơi, cộng tiền
      num totalFee = 0;
      DateTime current = combinedStartDateTime;
      while (current.isBefore(combinedEndDateTime)) {
        int minuteOfDay = current.hour * 60 + current.minute;
        num pricePerUnit = priceTimeline[minuteOfDay];
        totalFee += (pricePerUnit / unit);
        current = current.add(Duration(minutes: 1));
      }
      return totalFee > 0 ? totalFee.round() : 0;
    }

    int? selectedConfig = _formKey.currentState!.value['room_service_id'];
    if (selectedConfig == null) return 0;
    dynamic config = _serviceFeeConfig.firstWhereOrNull((element) {
      return element['id'] == selectedConfig;
    });

    return calculateServiceFee(
        combinedStartDateTime, combinedEndDateTime, config);
  }

  num getTotalPriceWithDiscount() {
    num total = getTotalPrice();

    num discountVal = _discountType == DiscountType.price
        ? stringToInt(_formKey.currentState?.value['discount']) ?? 0
        : stringToDouble(_formKey.currentState?.value['discount']) ?? 0;
    num discountPrice = _discountType == DiscountType.percent
        ? total * discountVal / 100
        : discountVal;

    // apply discount
    total = total - discountPrice;

    return total;
  }

  // phải trả
  num getFinalPrice() {
    num total = getTotalPriceWithDiscount();
    num serviceFee = getServiceFee();
    num promotionFee = getPromotionPrice();
    total += serviceFee;

    // vat
    // num vat = stringToDouble(_formKey.currentState?.value['vat']) ?? 0;
    // total = total + total * vat / 100;

    return total + getOtherFee - promotionFee;
  }

  num getPaid() {
    return (stringToInt(_formKey.currentState?.value['paid']) ?? 0) +
        totalPointCost;
  }

  num getDebt() {
    final paid = getPaid();
    if (paid == 0) {
      return getFinalPrice();
    }
    num debt = getFinalPrice() - paid;
    return roundMoney(debt);
  }

  void resetItemPrice() {
    for (var item in selectedItems) {
      // Ưu tiên giá sửa tay
      if (item.isManuallyEdited && item.overriddenPrice != null) {
        _formKey.currentState?.patchValue(
            {'${item.id}.price': vnd.format(item.overriddenPrice)});
        continue;
      }

      // Nếu có policy → áp dụng policy
      if (currentPolicy != null && item.policies != null) {
        final policy = item.policies!.firstWhereOrNull(
          (e) => e['policy_id'] == currentPolicy,
        );
        if (policy != null && policy['policy_value'] != null) {
          final policyPrice = stringToInt(policy['policy_value']) ?? 0;
          item.policyPrice = policyPrice;
          if (item.policyPrice != 0) {
            _formKey.currentState
                ?.patchValue({'${item.id}.price': vnd.format(policyPrice)});
          } else {
            final defaultPrice =
                isWholesale ? item.copyWholesaleCost : item.copyRetailCost;
            _formKey.currentState
                ?.patchValue({'${item.id}.price': vnd.format(defaultPrice)});
          }
          continue;
        }
      }

      // Nếu không có policy hoặc không khớp → dùng giá mặc định
      final defaultPrice =
          isWholesale ? item.copyWholesaleCost : item.copyRetailCost;
      _formKey.currentState
          ?.patchValue({'${item.id}.price': vnd.format(defaultPrice)});
    }
  }

  void showUpdateCostConfirm(
      List<dynamic> changedBaseCost, TableStatus roomType) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Cập nhật giá'),
            content: Text('Bạn có muốn cập nhật giá'),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                    side: BorderSide(
                      color: ThemeColor.get(context).primaryAccent,
                    ),
                    backgroundColor: Colors.transparent,
                    foregroundColor: ThemeColor.get(context).primaryAccent),
                onPressed: () async {
                  if (isEditing) {
                    await updateOrder(roomType);
                  } else {
                    await saveOrder(roomType);
                  }
                },
                child: Text('Giữ nguyên giá'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                    backgroundColor: ThemeColor.get(context).primaryAccent,
                    foregroundColor: Colors.white),
                onPressed: () async {
                  Navigator.of(context).pop();
                  try {
                    await api<ProductApiService>((request) =>
                        request.updateVariantPrice(changedBaseCost));
                  } catch (e) {
                    CustomToast.showToastError(context,
                        description: getResponseError(e));
                  }

                  await saveOrder(roomType);
                },
                child: Text('Cập nhật'),
              ),
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);
    return Scaffold(
      // key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: showPay
            ? Text(
                text('table_reserve_pay_title', 'Thanh toán bàn'),
                style: TextStyle(fontSize: 20),
              )
            : Text(
                text('table_reserve_create_title', 'Đặt bàn'),
                style: TextStyle(fontSize: 20),
              ),
        actions: [
          if (!isEditing)
            SizedBox(
              width: 45,
              child: IconButton(
                icon: Image.asset(
                  getImageAsset('list_icon.png'),
                ),
                onPressed: () {
                  routeTo(ListOrderPage.path);
                },
              ),
            ),
          IconButton(
            icon: _isShowingScan
                ? Icon(FontAwesomeIcons.times)
                : Icon(FontAwesomeIcons.barcode, size: 30),
            onPressed: () {
              setState(() {
                _isShowingScan = !_isShowingScan;
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.settings, size: 30),
            onPressed: () {
              routeTo(SettingOrderSalePage.path, onPop: (value) async {
                if (value != null) {
                  isReload = false;
                  await init();
                  setState(() {
                    updatePaid();
                  });
                }
              });
            },
          ),
        ],
      ),
      body: SafeArea(
          child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: SingleChildScrollView(
          child: Column(
            children: [
              buildBreadCrumb(),
              FormBuilder(
                key: _formKey,
                onChanged: () {
                  _formKey.currentState!.save();
                },
                clearValueOnUnregister: true,
                autovalidateMode: AutovalidateMode.disabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isShowingScan)
                      Column(
                        children: [
                          SizedBox(
                            height: 250,
                            child: ProductScan(
                              onDetectProduct: (product, weight) {
                                if (product != null) {
                                  setState(() {
                                    _scanError = null;
                                    addItem(product);
                                  });
                                } else {
                                  setState(() {
                                    _scanError = 'Không tìm thấy sản phẩm';
                                  });
                                }
                              },
                            ),
                          ),
                          SizedBox(height: 20),
                          if (_scanError != null)
                            Text(
                              _scanError!,
                              style: TextStyle(
                                  color: ThemeColor.get(context).primaryAccent),
                            ),
                        ],
                      )
                    else
                      buildCustomerDetail(),
                    SizedBox(height: 20),
                    SelectMulti(
                      onSelect: (items) {
                        if (items != null) {
                          addMultiItems(items);
                        }
                      },
                      selectedItems: selectedItems,
                      multiKey: selectMultiKey,
                    ),
                    Container(
                      padding:
                          EdgeInsets.symmetric(vertical: 0.0, horizontal: 6.0),
                      decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                                color: Colors.grey[200] ?? Colors.grey),
                            left: BorderSide(
                                color: Colors.grey[200] ?? Colors.grey),
                            right: BorderSide(
                                color: Colors.grey[200] ?? Colors.grey),
                            top: BorderSide(
                                color: Colors.grey[200] ?? Colors.grey),
                          ),
                          borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(10.0),
                              topRight: Radius.circular(10.0))),
                      child: Row(
                        // mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 10, bottom: 10),
                            child: Text.rich(
                              TextSpan(
                                text: 'Tổng SL món: ',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600]),
                                children: <TextSpan>[
                                  TextSpan(
                                    text:
                                        '${roundQuantity(getTotalQty(selectedItems))}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                        fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    buildListItem(),
                    // SizedBox(height: 20),
                    buildSummary(),
                    Divider(),
                    buildCreateAt(),
                    buildNote(),
                  ],
                ),
              ),
              SizedBox(height: 20),
              buildActions(),
              SizedBox(height: 20),
            ],
          ),
        ),
      )),
    );
  }

  Widget buildPointPayment() {
    if (featuresConfig['point_payment'] != true) {
      return SizedBox();
    }
    return Column(
      children: [
        SizedBox(
          height: 12.0,
        ),
        ListTileTheme(
          contentPadding: EdgeInsets.symmetric(horizontal: 0),
          dense: true,
          child: ExpansionTile(
            initiallyExpanded: widget.data()?['phone'] != null,
            shape: Border.all(color: Colors.transparent),
            title: Text('Thanh toán bằng điểm',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black)),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    "*Điểm hiện tại: $customerPoint",
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              SizedBox(
                height: 5,
              ),
              FormBuilderTextField(
                controller: _pointController,
                name: 'point',
                decoration: InputDecoration(
                  hintText: 'Nhập số điểm',
                  suffix: Text(
                    '= ${vndCurrency.format(totalPointCost)}',
                  ),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*$'))
                ],
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  getPointCost(int.tryParse(value ?? '0') ?? 0);
                  checkValidatePoint(value ?? '0');
                  getDebt();
                },
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget buildActions() {
    if (currentRoomType == TableStatus.using) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                  child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ElevatedButton.icon(
                    icon: Icon(Icons.close, color: Colors.white),
                    style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        minimumSize: Size(80, 40),
                        backgroundColor: Colors.red),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('Xác nhận'),
                            content:
                                Text('Bạn có chắc chắn muốn hủy đơn không?'),
                            actions: [
                              TextButton(
                                style: TextButton.styleFrom(
                                    side: BorderSide(
                                      color: Colors.red,
                                    ),
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.red),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: Text('Không'),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  cancelOrder(currentRoomType);
                                },
                                child: Text('Có'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    label: _isLoading
                        ? CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : Text(
                            'Hủy đơn',
                            style: TextStyle(color: Colors.white),
                          )),
              )),
              Expanded(
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        backgroundColor: Colors.green,
                        minimumSize: Size(80,
                            40) // put the width and height you want, standard ones are 64, 40
                        ),
                    onPressed: () => submit(currentRoomType),
                    child: _isLoading
                        ? CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_shopping_cart,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text('Cập nhật',
                                  style: TextStyle(color: Colors.white)),
                            ],
                          )),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                  child: ElevatedButton.icon(
                      icon: Icon(Icons.attach_money, color: Colors.white),
                      style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          minimumSize: Size(80, 40),
                          backgroundColor: Colors.blue),
                      onPressed: () => submit(currentRoomType, isPay: true),
                      label: _isLoading
                          ? CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : Text(
                              'Thanh toán',
                              style: TextStyle(color: Colors.white),
                            ))),
            ],
          ),
        ],
      );
    } else if (currentRoomType == TableStatus.preOrder) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    backgroundColor: Colors.green,
                    minimumSize: Size(80,
                        40) // put the width and height you want, standard ones are 64, 40
                    ),
                onPressed: () => submit(currentRoomType),
                child: _isLoading
                    ? CircularProgressIndicator(
                        color: Colors.white,
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_shopping_cart,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text('Cập nhật',
                              style: TextStyle(color: Colors.white)),
                        ],
                      )),
          ),
          SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    backgroundColor: Colors.blue,
                    minimumSize: Size(80,
                        40) // put the width and height you want, standard ones are 64, 40
                    ),
                onPressed: () => submit(TableStatus.using),
                child: _isLoading
                    ? CircularProgressIndicator(
                        color: Colors.white,
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.save,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text('Tạo đơn',
                              style: TextStyle(color: Colors.white)),
                        ],
                      )),
          ),
        ],
      );
    }

    // type is TableStatus.empty
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (buttonType == 'null' || buttonType == 'create_order')
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: Colors.green,
                      minimumSize: Size(80,
                          40) // put the width and height you want, standard ones are 64, 40
                      ),
                  onPressed: () => submit(TableStatus.using),
                  child: _isLoading
                      ? CircularProgressIndicator(
                          color: Colors.white,
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Tạo đơn',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        )),
            ),
          ),
        (buttonType == 'reserve')
            ? Expanded(
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        backgroundColor: Colors.blue,
                        minimumSize: Size(80, 40)),
                    onPressed: () => submit(TableStatus.preOrder),
                    child: _isLoading
                        ? CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.save,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Đặt ${text('_table_title', 'bàn')}',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          )),
              )
            : Expanded(
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        minimumSize: Size(80, 40),
                        backgroundColor: Colors.blue),
                    onPressed: () => submit(TableStatus.free, isPay: true),
                    child: _isLoading
                        ? CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.attach_money,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Thanh toán',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          )),
              ),
      ],
    );
  }

  Widget buildInfoCustomer() {
    if (featuresConfig['customer_info'] != true) {
      return SizedBox();
    }
    return Column(
      children: [
        SizedBox(height: 20),
        CustomerSearchOrder(
          multiKey: selectMultiKeyCustomer,
          key: _multiSelectKeyCustomer,
          onSelect: (Customer? selected) {
            _handleCustomerSelected(selected);
            setState(() {});
          },
          selectedCustomer: selectedCustomer,
        ),
        if (featuresConfig['customer_address'] == true)
          Column(
            children: [
              SizedBox(height: 10.0),
              FormBuilderTextField(
                name: 'address',
                keyboardType: TextInputType.streetAddress,
                initialValue: widget.data()?['address'] ?? '',
                decoration: InputDecoration(
                  labelText: 'Địa chỉ',
                ),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
      ],
    );
  }

  void _handleCustomerSelected(Customer? customer) {
    selectedCustomer = customer;
    customerPoint = customer?.point ?? 0;

    selectedCustomerId = customer?.id;
    _formKey.currentState!.patchValue({
      'address': selectedCustomer?.address,
    });
  }

  Widget buildCustomerDetail() {
    return Column(children: [
      buildInfoCustomer(),
      if (featuresConfig['customer_quantity'] == true) ...[
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Số lượng khách',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  FormBuilderField(
                    name: 'number_customer',
                    builder: (FormFieldState<dynamic> field) {
                      return QuantityFormField(
                        min: 1,
                        initialValue:
                            isEditing ? (editData['number_customer'] ?? 1) : 1,
                        onChanged: (value) {
                          field.didChange(value);
                          return;
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Thời gian dự kiến (phút)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  FormBuilderField(
                    name: 'time_intend',
                    builder: (FormFieldState<dynamic> field) {
                      return QuantityFormField(
                        min: 1,
                        max: 9999,
                        initialValue: editData?['time_intend'] ?? 60,
                        onChanged: (value) {
                          field.didChange(value);
                          return;
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
      SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tính phí theo',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                isAutoServicePrice
                    ? InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              final prices =
                                  minutesConfig['prices'] as List? ?? [];
                              final unit = minutesConfig['unit'] ?? 60;
                              final unitName =
                                  minutesConfig['unit_name'] ?? 'phút';
                              return AlertDialog(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                title: Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: ThemeColor.get(context)
                                            .primaryAccent),
                                    SizedBox(width: 8),
                                    Flexible(
                                      child: Text('Bảng giá theo khoảng giờ',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                content: prices.isEmpty
                                    ? Text('Chưa cấu hình khoảng giờ.')
                                    : Container(
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.7,
                                        constraints: BoxConstraints(
                                          maxHeight: 300,
                                        ),
                                        child: ListView(
                                          shrinkWrap: true,
                                          children: prices.map((p) {
                                            String start = (p['start'] ?? '')
                                                .toString()
                                                .substring(0, 5);
                                            String end = (p['end'] ?? '')
                                                .toString()
                                                .substring(0, 5);
                                            num price = p['price'] ?? 0;
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 4),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.access_time,
                                                      size: 18,
                                                      color: ThemeColor.get(
                                                              context)
                                                          .primaryAccent),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    '$start - $end',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                  SizedBox(width: 12),
                                                  Text(
                                                    '${vnd.format(price)} / $unit $unitName',
                                                    style: TextStyle(
                                                        color: Colors.blue),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                actions: [
                                  Center(
                                    child: TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text(
                                        'Đóng',
                                        style: TextStyle(
                                            color: ThemeColor.get(context)
                                                .primaryAccent),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: Container(
                          height: 45,
                          alignment: Alignment.centerLeft,
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: ThemeColor.get(context)
                                .primaryAccent
                                .withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: ThemeColor.get(context).primaryAccent),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lock,
                                  color: ThemeColor.get(context).primaryAccent,
                                  size: 18),
                              SizedBox(width: 8),
                              Text(
                                "Tự động tính tiền theo phút",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: ThemeColor.get(context).primaryAccent,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : (_serviceFeeConfig.isEmpty
                        ? GestureDetector(
                            onTap: () {
                              CustomToast.showToastError(context,
                                  description:
                                      '${roomDetail['name']} chưa cấu hình phí dịch vụ');
                              openConfigTimePage();
                            },
                            child: Container(
                              height: 45,
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "Cấu hình phí dịch vụ",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        : FormBuilderDropdown<int>(
                            name: 'room_service_id',
                            items: _serviceFeeConfig.map((e) {
                              final int id = e['id'];
                              return DropdownMenuItem(
                                value: id,
                                child: Text(getServiceFeeLabel(e)),
                              );
                            }).toList(),
                            initialValue: _serviceFeeConfig.isNotEmpty
                                ? _serviceFeeConfig[0]['id']
                                : null,
                            onChanged: (value) {
                              selectedTableFee = _serviceFeeConfig.firstWhere(
                                (e) => e['id'] == value,
                                orElse: () => null,
                              );
                              updatePromotion();
                              updatePaid();
                              setState(() {});
                            },
                          )),
              ],
            ),
          ),
        ],
      ),
      SizedBox(height: 12),
      Row(
        children: [
          Text('Thời gian bắt đầu',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      SizedBox(height: 4),
      Row(
        children: [
          Expanded(
            flex: 3,
            child: FormBuilderDateTimePicker(
              format: DateFormat('dd/MM/yyyy'),
              name: 'start_date',
              inputType: InputType.date,
              lastDate: _endDate ?? null,
              decoration: InputDecoration(
                labelText: 'Ngày',
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              initialValue: DateTime.now(),
              onChanged: (value) {
                _startDate = value ?? DateTime.now();
                updatePaid();
                updatePromotion();
                setState(() {});
              },
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FormBuilderDateTimePicker(
              format: DateFormat('HH:mm'),
              name: 'start_time',
              decoration: InputDecoration(
                labelText: 'Giờ',
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              inputType: InputType.time,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              initialValue: DateTime.now(),
              onChanged: (value) {
                updatePaid();
                updatePromotion();
                setState(() {});
              },
            ),
          ),
        ],
      ),
      SizedBox(
        height: 10,
      ),
      Row(
        children: [
          Text('Thời gian kết thúc',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      SizedBox(height: 4),
      Row(
        children: [
          Expanded(
            flex: 3,
            child: FormBuilderDateTimePicker(
              format: DateFormat('dd/MM/yyyy'),
              decoration: InputDecoration(
                labelText: 'Ngày',
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              name: 'end_date',
              initialValue: DateTime.now(),
              firstDate: _startDate,
              inputType: InputType.date,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              onChanged: (value) {
                _endDate = value ?? DateTime.now();
                updatePaid();
                updatePromotion();
                setState(() {});
              },
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FormBuilderDateTimePicker(
              format: DateFormat('HH:mm'),
              name: 'end_time',
              decoration: InputDecoration(
                labelText: 'Giờ',
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              inputType: InputType.time,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              onChanged: (value) {
                updatePaid();
                updatePromotion();
                setState(() {});
              },
            ),
          ),
        ],
      ),
      buildTotalTime(),
    ]);
  }

  Widget buildTotalTime() {
    final selectedConfigTime = _serviceFeeConfig.firstWhereOrNull((element) =>
        element['id'] == _formKey.currentState?.value['room_service_id']);

    if (selectedConfigTime == null) {
      return Container();
    }
    final startDate = _formKey.currentState?.value['start_date'];
    final startTime = _formKey.currentState?.value['start_time'];

    DateTime? startDateTime;
    if (startDate != null && startTime != null) {
      startDateTime = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
        startTime.hour,
        startTime.minute,
      );
    }
    final endDate = _formKey.currentState?.value['end_date'];
    final endTime = _formKey.currentState?.value['end_time'];

    DateTime? endDateTime;
    if (endDate != null && endTime != null) {
      endDateTime = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        endTime.hour,
        endTime.minute,
      );
    }
    if (startDateTime == null || endDateTime == null) {
      return Container();
    }
    final diff =
        calculateTimeDifference(startDateTime, endDateTime, selectedConfigTime);
    final unitName = selectedConfigTime['unit_name'];
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text.rich(
            TextSpan(
              text: 'Tổng thời gian: ',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600]),
              children: <TextSpan>[
                TextSpan(
                  text: '${diff.toStringAsFixed(0)} $unitName',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget buildDropdownProduct(BuildContext context, List<StorageItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map((e) => Container(
                height: 32,
                padding: EdgeInsets.only(left: 8, right: 1),
                margin: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: ThemeColor.get(context).primaryAccent,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        e.name ?? '',
                        maxLines: 2,
                        style: Theme.of(context).textTheme.titleSmall,
                        // overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    MaterialButton(
                      height: 20,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(0),
                      minWidth: 20,
                      onPressed: () {
                        removeItem(e);
                      },
                      child: Icon(
                        Icons.close_outlined,
                        size: 20,
                      ),
                    )
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget buildPopupSelect(BuildContext context, List<StorageItem> items) {
    return Container(
        padding: EdgeInsets.all(16.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          backgroundColor:
                              ThemeColor.get(context).primaryAccent,
                          minimumSize: Size(80,
                              40) // put the width and height you want, standard ones are 64, 40
                          ),
                      onPressed: () {
                        Navigator.pop(context);
                        addMultiItems(items);
                        // _multiKey.currentState?.changeSelectedItems(items);
                      },
                      child: Text(
                        'Tiếp tục đơn hàng',
                        style: TextStyle(color: Colors.white),
                      )),
                )
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            backgroundColor: Colors.green,
                            minimumSize: Size(80, 40)),
                        onPressed: () {
                          routeTo(EditProductPage.path, onPop: (result) async {
                            if (result != null) {
                              dynamic newItems = await _fetchVariantItems('');
                              if (newItems.isEmpty) {
                                return;
                              }
                              setState(() {
                                addItem(newItems.first);
                                Navigator.of(context).pop();
                              });
                            }
                          });
                        },
                        child: Text('Thêm mới sản phẩm',
                            style: TextStyle(color: Colors.white))))
              ],
            )
          ],
        ));
  }

  Widget buildPopupItem(
      BuildContext context, StorageItem item, bool isSelected) {
    return ListTile(
      // leading: Image.network(getVariantFirstImage(item)),
      leading: FadeInImage(
        placeholder: AssetImage(getImageAsset('placeholder.png')),
        image: NetworkImage(getVariantFirstImage(item)),
        imageErrorBuilder: (context, error, stackTrace) {
          return Image.asset(
            getImageAsset('placeholder.png'),
          );
        },
      ),

      title: Text(item.name ?? item.product?.name ?? ''),
      subtitle: Text(item.code ?? item.product?.code ?? ''),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(vndCurrency.format(item.retailCost).replaceAll('vnđ', 'đ'),
              style: TextStyle(fontSize: 14)),
          Text("SL: ${roundQuantity(item.inStock ?? 0)}",
              style: TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget buildOtherFee() {
    if (featuresConfig['other_fee'] != true) {
      return SizedBox();
    }
    return Column(
      children: [
        SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Chi phí khác', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(
              width: 180,
              height: 40,
              child: FormBuilderTextField(
                name: 'other_fee',
                readOnly: true,
                initialValue: vnd.format(getOtherFee),
                onTap: () {
                  _showDialogOtherFee();
                },
                inputFormatters: [
                  CurrencyTextInputFormatter(
                    locale: 'vi',
                    symbol: '',
                  )
                ],
                decoration: InputDecoration(
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: ThemeColor.get(context).primaryAccent,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixText: 'đ',
                ),
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            )
          ],
        ),
      ],
    );
  }

  Widget buildListPolicies() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Chính sách giá',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        SizedBox(
          width: 180,
          height: 40,
          child: Stack(
            children: [
              FormBuilderDropdown<int>(
                name: 'policy_id',
                initialValue: currentPolicy,
                decoration: InputDecoration(
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  hintText: 'Chọn chính sách',
                ),
                items: listPolicies.map((policy) {
                  return DropdownMenuItem<int>(
                    value: policy['id'],
                    child: Text(
                      policy['name'].toString(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    currentPolicy = value;
                    resetItemPrice();
                    updatePaid();
                  });
                },
              ),
              if (currentPolicy != null)
                Positioned(
                  right: 30,
                  top: 12,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        currentPolicy = null;
                        _formKey.currentState?.fields['policy_id']
                            ?.didChange(null);
                        resetItemPrice();
                        updatePaid();
                      });
                    },
                    child: Icon(Icons.clear, size: 16, color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // summary
  Widget buildSummary() {
    return Column(
      children: [
        buildListPolicies(),
        SizedBox(height: 12),
        buildOrderDiscount(),
        buildOtherFee(),
        buildOrderVAT(),
        SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Tổng tiền món',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(
              height: 40,
              width: 180,
              child: TextField(
                enabled: false,
                controller: TextEditingController(
                    text: vndCurrency
                        .format(getTotalPriceWithDiscount())
                        .replaceAll('vnđ', 'đ')),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  disabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.grey,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  hintText: '',
                  suffixText: '',
                ),
              ),
            )
          ],
        ),
        SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Tổng tiền ${text('_table_title', 'bàn')}',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(
              height: 40,
              width: 180,
              child: TextField(
                enabled: false,
                controller: TextEditingController(
                    text: vndCurrency
                        .format(getServiceFee())
                        .replaceAll('vnđ', 'đ')),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  disabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.grey,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  hintText: '',
                  suffixText: '',
                ),
              ),
            )
          ],
        ),
        SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(
            children: [
              Text(
                'Mã giảm giá',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 8),
              InkWell(
                onTapDown: (TapDownDetails details) {
                  selectedPromotion != null
                      ? _showPopupMenuPackage(context, details.globalPosition)
                      : null;
                },
                child: Icon(FontAwesomeIcons.ticket,
                    size: 16,
                    color: selectedPromotion == null
                        ? Colors.grey
                        : ThemeColor.get(context).primaryAccent),
              ),
            ],
          ),
          SizedBox(
              height: 40,
              width: 180,
              child: FormBuilderTextField(
                name: 'promotion_price',
                initialValue: vnd.format(getPromotionPrice()),
                readOnly: true,
                decoration: InputDecoration(
                  suffixText: 'đ',
                ),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                textAlign: TextAlign.right,
              )),
        ]),
        SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Tổng tiền T.Toán',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(
              height: 40,
              width: 180,
              child: FormBuilderTextField(
                name: 'total_price',
                enabled: false,
                controller: TextEditingController(
                    text: vndCurrency
                        .format(roundMoney(getFinalPrice()))
                        .replaceAll('vnđ', 'đ')),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                textAlign: TextAlign.right,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  disabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.grey,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  hintText: '',
                  suffixText: '',
                ),
              ),
            )
          ],
        ),
        SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Khách T.Toán', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
                child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                    height: 45,
                    width: 180,
                    child: Column(
                      children: [
                        Expanded(
                            child: FormBuilderTextField(
                          keyboardType: TextInputType.number,
                          name: 'paid',
                          initialValue: '0',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                          onChanged: (vale) {
                            setState(() {});
                          },
                          onTap: () {
                            _formKey.currentState!.patchValue({
                              'paid': '',
                            });
                          },
                          inputFormatters: [
                            CurrencyTextInputFormatter(
                              locale: 'vi',
                              symbol: '',
                            )
                          ],
                          decoration: InputDecoration(
                            // border: InputBorder.none,
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                            suffixText: 'đ',
                          ),
                        )),
                        SizedBox(height: 4.0),
                        // Container(
                        //   height: 1,
                        //   color: Colors.black12,
                        // )
                      ],
                    )),
              ],
            ))
          ],
        ),
        getDebt() != 0
            ? Column(
                children: [
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(getDebt() > 0 ? 'Còn nợ' : 'Tiền thừa',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(
                        height: 40,
                        width: 180,
                        child: FormBuilderTextField(
                          name: '',
                          enabled: false,
                          controller: TextEditingController(
                              text: vndCurrency
                                  .format(getDebt().abs())
                                  .replaceAll('vnđ', 'đ')),
                          // initialValue: vndCurrency.format(getFinalPrice()),
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            disabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.grey,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                            hintText: '',
                            suffixText: '',
                          ),
                        ),
                      )
                      // Text(vndCurrency.format(getDebt().abs()),
                      //     style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              )
            : SizedBox(height: 0),
        SizedBox(
          height: 12.0,
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Hình thức T.Toán',
              style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(
            width: 180,
            height: 40,
            child: FormBuilderDropdown(
              name: 'payment_type',
              initialValue: 1,
              items: [
                DropdownMenuItem(
                  value: 1,
                  child: Text(
                    'Tiền mặt',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                DropdownMenuItem(
                  value: 2,
                  child: Text(
                    'Chuyển khoản',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                DropdownMenuItem(
                  value: 3,
                  child: Text(
                    'Quẹt thẻ',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ]),
        buildPointPayment(),
      ],
    );
  }

  Widget buildCreateAt() {
    if (featuresConfig['create_date'] != true) {
      return SizedBox();
    }

    return Column(
      children: [
        SizedBox(height: 12),
        ListTileTheme(
          contentPadding: EdgeInsets.symmetric(horizontal: 0),
          dense: true,
          child: ExpansionTile(
            maintainState: true,
            initiallyExpanded: true,
            onExpansionChanged: (bool expand) {
              expand = !expand;
            },
            shape: Border.all(color: Colors.transparent),
            title: Text('Thời gian tạo đơn',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black)),
            children: [
              FormBuilderDateTimePicker(
                name: 'create_date',
                decoration: InputDecoration(
                  hintText: 'Chọn ngày giờ',
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.clear,
                      size: 15,
                    ),
                    onPressed: () {
                      _formKey.currentState!.patchValue({
                        'create_date': null,
                      });
                      setState(() {});
                    },
                  ),
                ),
                inputType: InputType.both,
                format: DateFormat('dd/MM/yyyy HH:mm'),
                lastDate: DateTime.now(),
                onChanged: (DateTime? dateTime) async {
                  if (dateTime != null) {
                    if (dateTime.isAfter(DateTime.now())) {
                      final confirm = await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Xác nhận'),
                          content: Text(
                              'Bạn không thể tạo trước đơn. Vui lòng chọn lại thời gian.'),
                          actions: <Widget>[
                            TextButton(
                              style: TextButton.styleFrom(
                                  side: BorderSide(
                                    color:
                                        ThemeColor.get(context).primaryAccent,
                                  ),
                                  backgroundColor: Colors.transparent,
                                  foregroundColor:
                                      ThemeColor.get(context).primaryAccent),
                              child: Text(
                                'Đồng ý',
                              ),
                              onPressed: () {
                                Navigator.of(context).pop(true);
                              },
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        _formKey.currentState!.patchValue({
                          'create_date': null,
                        });
                        setState(() {});
                      }
                    } else if (!isEditing &&
                        dateTime.isBefore(DateTime(DateTime.now().year,
                            DateTime.now().month, DateTime.now().day))) {
                      final confirm = await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Xác nhận'),
                          content: Text(
                              'Bạn tạo đơn hàng với ngày ${DateFormat('dd-MM-yyyy HH:mm').format(dateTime)} thì báo cáo sẽ được tính vào ngày hôm đó, bạn đồng ý?'),
                          actions: <Widget>[
                            TextButton(
                              style: TextButton.styleFrom(
                                  side: BorderSide(
                                    color:
                                        ThemeColor.get(context).primaryAccent,
                                  ),
                                  backgroundColor: Colors.transparent,
                                  foregroundColor:
                                      ThemeColor.get(context).primaryAccent),
                              child: Text(
                                'Hủy',
                              ),
                              onPressed: () {
                                Navigator.of(context).pop(false);
                              },
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                  backgroundColor:
                                      ThemeColor.get(context).primaryAccent,
                                  foregroundColor: Colors.white),
                              child: Text(
                                'Đồng ý',
                              ),
                              onPressed: () {
                                Navigator.of(context).pop(true);
                              },
                            ),
                          ],
                        ),
                      );
                      if (confirm != true) {
                        _formKey.currentState!.patchValue({
                          'create_date': null,
                        });
                        setState(() {});
                      }
                    }
                  }
                },
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget buildNote() {
    if (featuresConfig['note'] != true) {
      return SizedBox();
    }
    return Column(
      children: [
        SizedBox(height: 25),
        FormBuilderTextField(
          keyboardType: TextInputType.streetAddress,
          name: 'note',
          onTapOutside: (event) {
            FocusScope.of(context).unfocus();
          },
          onChanged: (vale) {
            setState(() {});
          },
          decoration: InputDecoration(
            labelText: 'Ghi chú đơn',
            labelStyle: TextStyle(color: Colors.grey[700]),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            hintText: 'Nhập ghi chú',
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: ThemeColor.get(context).primaryAccent,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildOrderDiscount() {
    if (featuresConfig['order_discount'] != true) {
      return SizedBox();
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Chiết khấu', style: TextStyle(fontWeight: FontWeight.bold)),
        Spacer(),
        SizedBox(
          height: 40,
          width: 180,
          child: FormBuilderTextField(
            controller: discountController,
            name: 'discount',
            onChanged: (value) {
              checkDiscountOrder();
            },
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
            keyboardType: TextInputType.number,
            inputFormatters: _discountType == DiscountType.percent
                ? [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}'),
                    ),
                  ]
                : [
                    CurrencyTextInputFormatter(
                      locale: 'vi',
                      symbol: '',
                    ),
                    FilteringTextInputFormatter.deny(
                      RegExp(r'-'),
                    ),
                  ],
            decoration: InputDecoration(
              suffixIcon: SizedBox(
                  child: CupertinoSlidingSegmentedControl<DiscountType>(
                thumbColor: ThemeColor.get(context).primaryAccent,
                onValueChanged: (DiscountType? value) {
                  if (value == DiscountType.percent) {
                    double discount = stringToDouble(
                            _formKey.currentState?.value['discount']) ??
                        0;
                    if (discount > 100) {
                      discount = 100;
                    }
                    _formKey.currentState?.patchValue({
                      'discount':
                          discount == 0.0 ? '' : discount.toStringAsFixed(0),
                    });
                  } else {
                    num discount =
                        stringToInt(_formKey.currentState?.value['discount']) ??
                            0;
                    _formKey.currentState?.patchValue({
                      'discount': discount != 0 ? vnd.format(discount) : '',
                    });
                  }
                  setState(() {
                    _discountType = value!;
                    checkDiscountOrder();
                  });
                },
                children: {
                  DiscountType.percent: Container(
                    child: Text(
                      '%',
                      style: TextStyle(
                          color: _discountType == DiscountType.percent
                              ? Colors.white
                              : Colors.black),
                    ),
                  ),
                  DiscountType.price: Container(
                    child: Text(
                      'đ',
                      style: TextStyle(
                          color: _discountType == DiscountType.price
                              ? Colors.white
                              : Colors.black),
                    ),
                  )
                },
                groupValue: _discountType,
              )),
              floatingLabelBehavior: FloatingLabelBehavior.never,
              hintText: '0',
              suffixText: _discountType == DiscountType.percent ? '' : '',
            ),
          ),
        ),
      ],
    );
  }

  void showDetailVat(context, Offset position) async {
    final vatItems = selectedItems
        .where((item) =>
            item.product != null &&
            item.product?.vat != null &&
            item.product!.vat! > 0 &&
            (item.product?.useVat != false))
        .toList();
    getVatPrice(StorageItem item) {
      dynamic retailCostValue =
          _formKey.currentState?.value['${item.id}.price'];
      dynamic quantityValue = item.quantity.toString();
      num retailCost = stringToInt(retailCostValue) ?? item.retailCost ?? 0;
      num wholesaleCost =
          stringToInt(retailCostValue) ?? item.wholesaleCost ?? 0;
      num quantity = num.tryParse(quantityValue) ?? 0;
      num total =
          isWholesale ? wholesaleCost * quantity : retailCost * quantity;
      var vat = item.product?.vat ?? 0;
      return total * vat / 100;
    }

    await showMenu(
      context: context,
      color: Colors.white,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        PopupMenuItem(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: vatItems.isEmpty
                ? [Text('Không có sản phẩm chịu VAT')]
                : vatItems
                    .map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${item.product?.name ?? ''}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black),
                              ),
                              TextSpan(
                                text: ': ',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.black),
                              ),
                              TextSpan(
                                text: '${item.product?.vat ?? ''}%',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w500),
                              ),
                              TextSpan(
                                text: ' → ',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: vndCurrency.format(getVatPrice(item)),
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.deepOrange,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )))
                    .toList(),
          ),
        ),
      ],
    );
  }

  Widget buildOrderVAT() {
    if (featuresConfig['vat'] != true) {
      return SizedBox();
    }

    return Column(
      children: [
        SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('VAT', style: TextStyle(fontWeight: FontWeight.bold)),
            Container(
              height: 40,
              width: 180,
              child: Builder(
                builder: (fieldContext) => FormBuilderTextField(
                  name: 'vat',
                  controller: vatController,
                  readOnly: true,
                  onTap: () {
                    RenderBox renderBox =
                        fieldContext.findRenderObject() as RenderBox;
                    Offset position = renderBox.localToGlobal(Offset.zero);
                    showDetailVat(fieldContext, position);
                  },
                  onChanged: (value) {
                    if (mounted) {
                      setState(() {});
                      updatePaid();
                      _toastShown = false;
                    }
                  },
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey),
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                    disabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.grey,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.grey,
                      ),
                    ),
                    suffixText: 'đ',
                    suffixStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ],
    );
  }

  Widget buildPopupCustomer(
      BuildContext context, Customer customer, bool isSelected) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      leading: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.contact_page),
        ],
      ),
      title: Text("${customer.name}"),
      trailing: Text("SĐT: ${customer.phone}"),
      subtitle: Text(customer.address ?? ''),
    );
  }

  Widget buildListItem() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: selectedItems.map((item) {
        return buildItem(item, selectedItems.indexOf(item));
      }).toList(),
    );
  }

  // initPrice(StorageItem item) {
  //   final priceValue = (item.policies ?? [])
  //       .indexWhere((element) => element['policy_id'] == currentPolicy);
  //   if (priceValue == -1) {
  //     // Không tìm thấy policy phù hợp
  //     return vnd.format(item.retailCost ?? 0);
  //   }
  //   final dynamic policyValue;
  //   if (item.policies != null) {
  //     policyValue = item.policies![priceValue]['policy_value'];
  //   } else {
  //     policyValue = null;
  //   }

  //   num price = 0;
  //   if (policyValue != null) {
  //     if (policyValue is String) {
  //       price = num.tryParse(policyValue.replaceAll('.', '')) ?? 0;
  //     } else if (policyValue is num) {
  //       price = policyValue;
  //     }
  //   }
  //   // resetItemPrice();
  //   return vnd.format(price);
  // }

  Widget buildItem(StorageItem item, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: 4),
      // padding: EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "${index + 1}. ${item.name ?? ''}",
                  maxLines: 2,
                  // overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, overflow: TextOverflow.fade),
                ),
              ),
              InkWell(
                onTap: () {
                  removeItem(item);
                },
                child: Icon(Icons.delete_outline,
                    size: 25, color: ThemeColor.get(context).primaryAccent),
              ),
            ],
          ),
          6.verticalSpace,
          Row(
            children: [
              Container(
                height: 40,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(10.0)),
                    color: ThemeColor.get(context).primaryAccent),
                child: Row(
                  // crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                        width: 30,
                        height: 40,
                        child: SingleTapDetector(
                          onTap: () {
                            if (item.quantity >= 1) {
                              String newQuantityStr =
                                  (item.quantity - 1).toStringAsFixed(3);
                              num newQuantity =
                                  num.tryParse(newQuantityStr) ?? 0;
                              if (newQuantity == newQuantity.floor()) {
                                item.quantity = newQuantity.toInt();
                              } else {
                                item.quantity = newQuantity.toDouble();
                              }
                              _formKey.currentState?.patchValue(
                                  {'${item.id}.quantity': '${item.quantity}'});
                              setState(() {});
                              if (newQuantity == newQuantity.floor()) {
                                item.quantity = newQuantity.toInt();
                              } else {
                                item.quantity = newQuantity.toDouble();
                              }
                              if (item.discountType == DiscountType.price) {
                                final currentValue = _formKey
                                    .currentState?.value['${item.id}.discount'];
                                item.discount =
                                    (stringToInt(currentValue) ?? 0) *
                                        item.quantity;
                              }
                              _formKey.currentState?.patchValue(
                                  {'${item.id}.quantity': '${item.quantity}'});
                              setState(() {});
                            }
                          },
                          child: Container(
                            alignment: Alignment.center,
                            child: Icon(
                              FontAwesomeIcons.minus,
                              size: 15.0,
                              color: Colors.white,
                            ),
                          ),
                        )),
                    Container(
                      width: 55,
                      decoration: BoxDecoration(
                          // border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.all(Radius.circular(10.0)),
                          color: Colors.white),
                      // height: 36,
                      child: FormBuilderTextField(
                        controller: item.txtQuantity,
                        key: item.quantityKey,
                        name: '${item.id}.quantity',
                        // initialValue: item.quantity
                        //     .toStringAsFixed(3)
                        //     .replaceAll(RegExp(r"0*$"), "")
                        //     .replaceAll(RegExp(r"\.$"), ""),
                        onTapOutside: (value) {
                          FocusScope.of(context).unfocus();
                        },
                        onChanged: (value) {
                          num inputValue = stringToDouble(value) ?? 0;
                          num maxQuantity = item.temporality ?? 0;
                          checkDiscountItem(item);
                          checkOnChange();
                          if (!isEditing &&
                              item.isBuyAlways == false &&
                              inputValue > maxQuantity) {
                            Future.microtask(() {
                              _formKey.currentState?.patchValue({
                                '${item.id}.quantity':
                                    roundQuantity(maxQuantity)
                              });

                              item.quantity = maxQuantity;

                              CustomToast.showToastError(context,
                                  description: "Quá số lượng tồn kho");
                            });
                          } else {
                            item.quantity = inputValue;
                          }

                          if (item.discountType == DiscountType.price) {
                            final currentValue = _formKey
                                .currentState?.value['${item.id}.discount'];
                            item.discount = (stringToInt(currentValue) ?? 0) *
                                item.quantity;
                          }
                          updatePaid();
                          setState(() {});
                        },
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.numeric(),
                          FormBuilderValidators.min(0.001),
                        ]),
                        keyboardType: TextInputType.numberWithOptions(
                            signed: true, decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,3}'),
                          ),
                        ],
                        decoration: InputDecoration(
                          floatingLabelBehavior: FloatingLabelBehavior.never,
                          hintText: '0',
                          suffixText: '',
                        ),
                      ),
                    ),
                    SizedBox(
                        width: 30,
                        height: 40,
                        child: SingleTapDetector(
                          onTap: () {
                            String newQuantityStr =
                                (item.quantity + 1).toStringAsFixed(3);
                            num newQuantity =
                                stringToDouble(newQuantityStr) ?? 0;
                            if (!isEditing &&
                                item.isBuyAlways == false &&
                                newQuantity.toDouble() >
                                    (item.temporality ?? 0)) {
                              CustomToast.showToastError(context,
                                  description: "Quá số lượng tồn kho");
                              return;
                            }
                            if (newQuantity == newQuantity.floor()) {
                              item.quantity = newQuantity.toInt();
                            } else {
                              item.quantity = newQuantity;
                            }
                            if (item.discountType == DiscountType.price) {
                              final currentValue = _formKey
                                  .currentState?.value['${item.id}.discount'];
                              item.discount = (stringToInt(currentValue) ?? 0) *
                                  item.quantity;
                            }
                            _formKey.currentState?.patchValue(
                                {'${item.id}.quantity': '${item.quantity}'});
                            setState(() {});
                          },
                          child: Container(
                            alignment: Alignment.center,
                            child: Icon(
                              FontAwesomeIcons.plus,
                              size: 15.0,
                              color: Colors.white,
                            ),
                          ),
                        )),
                  ],
                ),
              ),
              8.horizontalSpace,
              Container(
                width: 110,
                height: 40,
                // height: 36,
                child: FormBuilderTextField(
                  key: item.priceKey,
                  name: '${item.id}.price',
                  controller: item.txtPrice,
                  // initialValue:
                  //     '${currentPolicy == null ? vnd.format(item.copyRetailCost ?? 0) : initPrice(item)}',
                  onTapOutside: (value) {
                    FocusScope.of(context).unfocus();
                  },
                  onEditingComplete: () {
                    item.isUserTyping = false;
                  },
                  onTap: () {
                    item.isUserTyping = true;
                  },
                  onChanged: (value) {
                    final inputPrice = stringToInt(value) ?? 0;

                    // Check giá hiện tại
                    num? policyValue;
                    if (item.policies != null && currentPolicy != null) {
                      final policy = item.policies!.firstWhereOrNull(
                        (e) => e['policy_id'] == currentPolicy,
                      );
                      if (policy != null && policy['policy_value'] != null) {
                        policyValue = stringToInt(policy['policy_value']);
                      }
                    }

                    final num defaultPrice =
                        currentPolicy != null && policyValue != null
                            ? policyValue
                            : isWholesale
                                ? item.copyWholesaleCost ?? 0
                                : item.copyRetailCost ?? 0;

                    // Nếu khác giá mặc định -> sửa tay
                    if (item.isUserTyping) {
                      if (inputPrice != defaultPrice) {
                        item.isManuallyEdited = true;
                        item.overriddenPrice = inputPrice;
                      } else {
                        item.isManuallyEdited = false;
                        item.overriddenPrice = null;
                      }
                    }

                    // Cập nhật retail/wholesale cost hiển thị để hiển thị đúng tổng tiền
                    if (isWholesale) {
                      item.wholesaleCost = inputPrice;
                    } else {
                      item.retailCost = inputPrice;
                    }
                    updatePaid();
                    checkDiscountItem(item);
                    setState(() {});
                  },
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    CurrencyTextInputFormatter(
                      locale: 'vi',
                      symbol: '',
                    )
                  ],
                  decoration: InputDecoration(
                    disabledBorder: OutlineInputBorder(
                      // borderSide: BorderSide(
                      //   color: Colors.grey,
                      // ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                    suffixText: 'đ',
                  ),
                ),
              ),
              8.horizontalSpace,
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                        child: SizedBox(
                      height: 40,
                      child: FormBuilderTextField(
                        // controller: item.txtDiscount,
                        key: item.discountKey,
                        textAlign: TextAlign.right,
                        initialValue: item.discount != 0
                            ? (item.discountType == DiscountType.percent
                                ? roundQuantity(item.discount ?? 0)
                                : vnd.format(
                                    (item.discount ?? 0) / item.quantity))
                            : '',
                        name: '${item.id}.discount',
                        onChanged: (value) {
                          item.discount =
                              item.discountType == DiscountType.percent
                                  ? stringToDouble(value) ?? 0
                                  : (stringToInt(value) ?? 0) * item.quantity;
                          updatePaid();
                          checkDiscountItem(item);
                          setState(() {});
                        },
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                        keyboardType: TextInputType.number,
                        inputFormatters:
                            item.discountType == DiscountType.percent
                                ? [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d+\.?\d{0,2}'),
                                    ),
                                  ]
                                : [
                                    CurrencyTextInputFormatter(
                                      locale: 'vi',
                                      symbol: '',
                                    )
                                  ],
                        decoration: InputDecoration(
                          suffixIcon:
                              CupertinoSlidingSegmentedControl<DiscountType>(
                            thumbColor: ThemeColor.get(context).primaryAccent,
                            onValueChanged: (DiscountType? value) {
                              final currentValue = _formKey
                                  .currentState?.value['${item.id}.discount'];

                              if (currentValue == null ||
                                  currentValue.isEmpty) {
                                _formKey.currentState
                                    ?.patchValue({'${item.id}.discount': ''});
                              } else {
                                if (value == DiscountType.percent) {
                                  double discount =
                                      stringToDouble(currentValue) ?? 0;
                                  if (discount > 100) {
                                    discount = 100;
                                  }
                                  _formKey.currentState?.patchValue({
                                    '${item.id}.discount':
                                        discount.toStringAsFixed(0),
                                  });
                                } else {
                                  _formKey.currentState?.patchValue({
                                    '${item.id}.discount': vnd
                                        .format(stringToInt(currentValue) ?? 0)
                                  });
                                }
                              }
                              item.discountType = value ?? DiscountType.percent;
                              item.discount =
                                  item.discountType == DiscountType.percent
                                      ? stringToDouble(currentValue) ?? 0
                                      : stringToInt(currentValue) ?? 0;
                              if (item.discountType == DiscountType.percent &&
                                  stringToDouble(currentValue)! > 100) {
                                _formKey.currentState?.patchValue({
                                  '${item.id}.discount': '100',
                                });
                              }
                              updatePaid();
                            },
                            children: {
                              DiscountType.percent: Container(
                                child: Text('%',
                                    style: TextStyle(
                                        // color: Colors.white
                                        color: item.discountType ==
                                                DiscountType.percent
                                            ? Colors.white
                                            : Colors.black)),
                              ),
                              DiscountType.price: Container(
                                child: Text('đ',
                                    style: TextStyle(
                                        // color: Colors.white
                                        color: item.discountType ==
                                                DiscountType.price
                                            ? Colors.white
                                            : Colors.black)),
                              )
                            },
                            groupValue: item.discountType,
                          ),
                          // icon: Icon(Icons.contact_page),
                          floatingLabelBehavior: FloatingLabelBehavior.never,
                          hintText: '0',
                          suffixText: item.discountType == DiscountType.percent
                              ? ''
                              : '',
                        ),
                      ),
                    )),
                  ],
                ),
              ),
              // Spacer(),
            ],
          ),
          8.verticalSpace,
          if (featuresConfig['vat'] == true && item.product?.useVat != false)
            SizedBox(
              height: 40,
              child: Row(
                children: [
                  buildVATItem(context, item),
                ],
              ),
            ),
          if (featuresConfig['product_note'] == true)
            buildProductNote(item, context),
          8.verticalSpace,
          Row(
            children: [
              Spacer(),
              Text.rich(
                TextSpan(
                  text: 'Tổng tiền: ',
                  style: TextStyle(fontSize: 14),
                  children: <TextSpan>[
                    TextSpan(
                      text: '${vndCurrency.format(getPrice(item))}',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          4.verticalSpace,
          Divider()
        ],
      ),
    );
  }

  Widget buildVATItem(BuildContext context, StorageItem item) {
    if (featuresConfig['vat'] != true) {
      return Container();
    }
    return Expanded(
      child: FormBuilderTextField(
        name: '${item.id}.vat',
        controller: item.txtVAT,
        onTapOutside: (value) {
          FocusScope.of(context).unfocus();
        },
        key: item.vatKey,
        enabled: false,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            RegExp(r'^\d+\.?\d{0,2}'),
          ),
        ],
        textAlign: TextAlign.right,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        onChanged: (value) {
          if (value != null) {
            double? parsedValue = double.tryParse(value!);
            if (parsedValue != null && parsedValue > 100) {
              CustomToast.showToastError(context,
                  description: "Thuế VAT không được lớn hơn 100%");

              Future.delayed(Duration(milliseconds: 100), () {
                item.txtVAT.text = '100';
                item.txtVAT.selection = TextSelection.fromPosition(
                    TextPosition(offset: item.txtVAT.text.length));
              });
              return;
            }
            item.product?.vat = stringToDouble(value) ?? 0;
          }
        },
        decoration: InputDecoration(
          suffixText: '%',
          labelText: 'VAT',
          labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget buildProductNote(StorageItem item, context) {
    return Column(
      children: [
        SizedBox(height: 12),
        InkWell(
          onTap: () {
            item.productNotes?.add({
              'name': '',
              'price': 0,
              'variant_id': item.id,
            });
            setState(() {});
          },
          child: Row(
            children: [
              Icon(
                Icons.add,
                size: 15,
                color: Colors.blue,
              ),
              Text(
                'Thêm ghi chú',
                style: TextStyle(color: Colors.blue),
              )
            ],
          ),
        ),
        SizedBox(height: 15),
        ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 10),
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: item.productNotes?.length,
            itemBuilder: (context, index) {
              var note = item.productNotes?[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: Row(
                  key: ValueKey(note.hashCode),
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: note?['name'] ?? '',
                        cursorColor: ThemeColor.get(context).primaryAccent,
                        onChanged: (value) {
                          note['name'] = value;
                        },
                        decoration: InputDecoration(
                          labelText: 'Nhập ghi chú',
                          labelStyle: TextStyle(color: Colors.grey[700]),
                          // floatingLabelBehavior: FloatingLabelBehavior.always,
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: ThemeColor.get(context).primaryAccent,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    // SizedBox(width: 10),
                    // Expanded(
                    //   child: TextFormField(
                    // initialValue: note?['price'] ?? '',
                    //     cursorColor: ThemeColor.get(context).primaryAccent,
                    //     onChanged: (value) {
                    //       note[index]['price'] = stringToInt(value) ?? 0;
                    //     },
                    //     decoration: InputDecoration(
                    //       labelText: 'Số tiền',
                    //       labelStyle: TextStyle(color: Colors.grey[700]),
                    //       floatingLabelBehavior: FloatingLabelBehavior.always,
                    //       suffixText: 'đ',
                    //       focusedBorder: OutlineInputBorder(
                    //         borderSide: BorderSide(
                    //           color: ThemeColor.get(context).primaryAccent,
                    //         ),
                    //         borderRadius: BorderRadius.circular(10),
                    //       ),
                    //     ),
                    //     inputFormatters: [
                    //       CurrencyTextInputFormatter(
                    //         locale: 'vi',
                    //         symbol: '',
                    //       )
                    //     ],
                    //     keyboardType: TextInputType.number,
                    //   ),
                    // ),
                    SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        item.productNotes?.remove(note);
                        setState(() {});
                      },
                      child: Icon(
                        Icons.delete_outline,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              );
            })
      ],
    );
  }

  void _showDialogOtherFee() async {
    List<TextEditingController> nameControllers = [];
    List<TextEditingController> priceControllers = [];
    await _fetchListFee();
    for (var fee in cloneOtherFee) {
      nameControllers.add(TextEditingController(text: fee['name']));
      priceControllers
          .add(TextEditingController(text: vnd.format(fee['price'])));
    }
    if (cloneOtherFee.isEmpty) {
      cloneOtherFee.add({'name': '', 'price': 0, 'type_cost': 1});
      nameControllers.add(TextEditingController());
      priceControllers.add(TextEditingController());
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: ((context, setState) {
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Chi phí khác'),
                Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.settings,
                    color: ThemeColor.get(context).primaryAccent,
                  ),
                  onPressed: () {
                    showListFee(otherFeeList);
                  },
                ),
                SizedBox(width: 10),
                IconButton(
                  icon: Icon(
                    Icons.add_circle,
                    color: ThemeColor.get(context).primaryAccent,
                  ),
                  onPressed: () {
                    setState(() {
                      cloneOtherFee.add({
                        'name': '',
                        'price': 0,
                        'type_cost': 1,
                      });
                      nameControllers.add(TextEditingController());
                      priceControllers.add(TextEditingController());
                    });
                  },
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Divider(),
                    SizedBox(height: 10),
                    ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: cloneOtherFee.length,
                        itemBuilder: (context, index) {
                          List feeId = [];
                          cloneOtherFee.forEach((fee) {
                            otherFeeList.forEach((item) {
                              if (item['name'] == fee['name']) {
                                feeId.add(item['id']);
                              }
                            });
                          });
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 15),
                            child: Row(
                              children: [
                                SizedBox(
                                  height: 50,
                                  width: 150,
                                  child: FormBuilderDropdown<int>(
                                    name: 'other_fee_selection_$index',
                                    initialValue: (feeId.isEmpty ||
                                            feeId == [] ||
                                            index == feeId.length ||
                                            index > feeId.length)
                                        ? null
                                        : feeId[index],
                                    decoration: InputDecoration(
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      floatingLabelBehavior:
                                          FloatingLabelBehavior.never,
                                      hintText: 'Tên chi phí',
                                    ),
                                    items: otherFeeList.map((item) {
                                      return DropdownMenuItem<int>(
                                        value: item['id'],
                                        child: Text(
                                          item['name'].toString(),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      final selected = otherFeeList.firstWhere(
                                        (e) => e['id'] == value,
                                        orElse: () => null,
                                      );
                                      if (selected != null) {
                                        nameControllers[index].text =
                                            selected['name'];
                                        cloneOtherFee[index]['name'] =
                                            selected['name'];
                                        // cloneOtherFee[index]['id'] =
                                        //     selected['id'];
                                      }
                                      setState(() {});
                                    },
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: priceControllers[index],
                                    cursorColor:
                                        ThemeColor.get(context).primaryAccent,
                                    decoration: InputDecoration(
                                      labelText: 'Số tiền',
                                      labelStyle:
                                          TextStyle(color: Colors.grey[700]),
                                      floatingLabelBehavior:
                                          FloatingLabelBehavior.always,
                                      suffixText: 'đ',
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: ThemeColor.get(context)
                                              .primaryAccent,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    inputFormatters: [
                                      CurrencyTextInputFormatter(
                                        locale: 'vi',
                                        symbol: '',
                                      )
                                    ],
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      cloneOtherFee[index]['price'] =
                                          stringToInt(value) ?? 0;
                                      getTotalOtherFee();
                                    },
                                  ),
                                ),
                                SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      cloneOtherFee.removeAt(index);
                                      nameControllers.removeAt(index);
                                      priceControllers.removeAt(index);

                                      if (cloneOtherFee.isEmpty) {
                                        cloneOtherFee.add({
                                          'name': '',
                                          'price': 0,
                                          'type_cost': 1
                                        });
                                        nameControllers
                                            .add(TextEditingController());
                                        priceControllers
                                            .add(TextEditingController());
                                      }
                                      getTotalOtherFee();
                                    });
                                  },
                                  child: Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          );
                        })
                  ],
                ),
              ),
            ),
            insetPadding:
                EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            contentPadding: EdgeInsets.all(16.0),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(20.0))),
            actions: [
              TextButton(
                  style: TextButton.styleFrom(
                      side: BorderSide(
                        color: ThemeColor.get(context).primaryAccent,
                      ),
                      backgroundColor: Colors.transparent,
                      foregroundColor: ThemeColor.get(context).primaryAccent),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Hủy')),
              TextButton(
                style: TextButton.styleFrom(
                    backgroundColor: ThemeColor.get(context).primaryAccent,
                    foregroundColor: Colors.white),
                child: Text('Xác nhận'),
                onPressed: () {
                  for (int i = 0; i < cloneOtherFee.length; i++) {
                    cloneOtherFee[i]['name'] = nameControllers[i].text;
                    cloneOtherFee[i]['price'] =
                        stringToInt(priceControllers[i].text) ?? 0;
                  }
                  if (cloneOtherFee.isNotEmpty) {
                    for (var fee in cloneOtherFee) {
                      if (fee['name'].isEmpty) {
                        CustomToast.showToastError(context,
                            description: "Tên chi phí không được để trống");
                        return;
                      }
                    }
                  }
                  getTotalOtherFee();
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        }));
      },
    );
  }

  void _showPopupMenuPackage(BuildContext context, Offset position) async {
    await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem<int>(
          value: 1,
          child: Container(
              child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(selectedPromotion!['name'] ?? '',
                  style: TextStyle(
                      color: ThemeColor.get(context).primaryAccent,
                      overflow: TextOverflow.ellipsis,
                      fontWeight: FontWeight.bold)),
              SizedBox(width: 10),
              Text('-${selectedPromotion!['discount']}%',
                  style: TextStyle(fontWeight: FontWeight.bold))
            ],
          )),
        ),
      ],
      color: Colors.white,
    );
  }

  void getTotalOtherFee() {
    num totalOtherFee = 0;

    for (var fee in cloneOtherFee) {
      if (fee['is_delete'] == null || fee['is_delete'] != true) {
        totalOtherFee += fee['price'] ?? 0;
      }
    }
    getOtherFee = totalOtherFee;
    _formKey.currentState?.patchValue({'other_fee': vnd.format(totalOtherFee)});
    updatePaid();
  }

  Widget buildBreadCrumb() {
    return FutureBuilder<dynamic>(
      future: _roomFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Container();
        }

        final tableName = snapshot.data?['name'];
        final areaName = snapshot.data?['area']?['name'];
        if (tableName == null || areaName == null) {
          return Container();
        }

        return Breadcrumb(
          items: [areaName, tableName],
        );
      },
    );
  }

  void updatePromotion() {
    num price = getPromotionPrice();
    setState(() {
      if (price > 0) {
        _formKey.currentState!.fields['promotion_price']!
            .didChange("-${vnd.format(roundMoney(price))}");
      } else {
        _formKey.currentState!.fields['promotion_price']!
            .didChange("${vnd.format(roundMoney(price))}");
      }
    });
  }

  num getPromotionPrice() {
    if (selectedPromotion == null) {
      return 0;
    } else {
      num total = getServiceFee();
      num discount = selectedPromotion?['discount'];
      total -= total * (discount / 100);
      return getServiceFee() - total;
    }
  }
}

String getServiceFeeLabel(dynamic config) {
  String unitName = config['unit_name'] ?? '';
  String price = vndCurrency.format(config['price'] ?? 0);
  int unit = config['unit'];
  String start = config['start'] != null
      ? config['start'] = config['start'].split(':').sublist(0, 2).join(':')
      : '';
  String end = config['end'] != null
      ? config['end'] = config['end'].split(':').sublist(0, 2).join(':')
      : '';
  if (config['parent_id'] != null) {
    return '$unitName  ($price/$unit $unitName) - $start đến $end';
  }

  return '$unitName  ($price/$unit $unitName)';
}
