import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:developer';
import 'package:collection/collection.dart';
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/app/models/product.dart';
import 'package:flutter_app/app/models/storage_item.dart';
import 'package:flutter_app/app/networking/order_api_service.dart';
import 'package:flutter_app/app/networking/product_api_service.dart';
import 'package:flutter_app/app/networking/room_api_service.dart';
import 'package:flutter_app/app/utils/formatters.dart';
import 'package:flutter_app/app/utils/getters.dart';
import 'package:flutter_app/app/utils/message.dart';
import 'package:flutter_app/bootstrap/helpers.dart';
import 'package:flutter_app/resources/pages/setting/setting_order_sale_page.dart';
import 'package:flutter_app/resources/widgets/breadcrumb.dart';
import 'package:flutter_app/resources/widgets/manage_table/select_topping.dart';
import 'package:flutter_app/resources/widgets/manage_table/table_item.dart';
import 'package:flutter_app/resources/widgets/single_tap_detector.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:nylo_framework/nylo_framework.dart';
import '../../widgets/order_storage_item.dart';
import 'package:flutter_app/resources/pages/custom_toast.dart';

class CreateOrderPos extends NyStatefulWidget {
  final String Function()? getRoomId;
  final String? Function()? getButtonType;
  final String Function()? getAreaName;
  final String Function()? getRoomName;
  final String? Function()? getCurrentRoomType;
  final bool Function()? getIsEditing;
  final dynamic Function()? getEditData;
  final bool Function()? getShowPay;
  final String? Function()? getNote;
  final List<StorageItem> Function()? getItems;
  final String? Function()? getAddress;
  final dynamic editData;

  CreateOrderPos({
    Key? key,
    this.getRoomId,
    this.getButtonType,
    this.getAreaName,
    this.getRoomName,
    this.getCurrentRoomType,
    this.getIsEditing,
    this.getEditData,
    this.getShowPay,
    this.getNote,
    this.getItems,
    this.getAddress,
    this.editData,
  }) : super(key: key);

  @override
  NyState<CreateOrderPos> createState() => CreateOrderPosPageState();
}

class CreateOrderPosPageState extends NyState<CreateOrderPos> {
  String get roomId => widget.getRoomId?.call() ?? '';
  String? get buttonType => widget.getButtonType?.call();
  String get areaName => widget.getAreaName?.call() ?? '';
  String get roomName => widget.getRoomName?.call() ?? '';
  TableStatus get currentRoomType =>
      TableStatusExtension.fromValue(widget.getCurrentRoomType?.call() ?? '');
  bool get isEditing => widget.getIsEditing?.call() ?? false;
  dynamic _editData;

  dynamic get editData => _editData ?? widget.getEditData?.call();
  bool get showPay => widget.getShowPay?.call() ?? false;
  String? get note => widget.getNote?.call();
  List<StorageItem> get items => widget.getItems?.call() ?? [];
  String? get address => widget.getAddress?.call();
  set editData(dynamic value) {
    _editData = value;
  }

  final discountController = TextEditingController();
  final vatController = TextEditingController();
  bool _toastShown = false;

  int? orderId;
  DiscountType _discountType = DiscountType.percent;
  int? selectedCustomerId;

  final GlobalKey<FormBuilderState> _formKey = GlobalKey<FormBuilderState>();

  List<StorageItem> selectedItems = [];
  bool _isLoading = false;

  Map<int, num> variantToCurrentBaseCost = {};

  bool isWholesale = false;
  Future<dynamic> _roomDetailFuture = Future.value(null);
  int orderIdIngre = 0;
  List<Map<String, dynamic>> selectedDishes = [];
  Map<String, bool> featuresConfig = {};
  List<int>? pendingTask;
  int invoiceId = 0;
  List<dynamic> otherFee = [];
  List<dynamic> cloneOtherFee = [];
  num getOtherFee = 0;
  bool isReload = true;
  List<dynamic> initProductNotes = [];
  String imageBase64Decode = '';
  int? currentPolicy;
  List<dynamic> listPolicies = [];
  bool changePriceValue = false;
  String orderCode = '';
  List<dynamic> otherFeeList = [];
  final SlidableController slidableController = SlidableController();
  List<dynamic> saveChangeProductPrice = [];
  bool tempPrinting = false;
  dynamic tempData = {};
  final paidController = TextEditingController();
  final otherFeeController = TextEditingController();
  int selectPaymentType = 1;
  String orderNote = '';
  int numberCustomer = 1;
  DateTime? createDate;
  int timeIntend = 60;
  int customerPoint = 0;
  int costPoint = 0;
  int totalPointCost = 0;
  num lostCost = 0;
  int pointToPay = 0;
  @override
  init() async {
    super.init();

    final config = await getOrderSaleConfig();
    setState(() {
      featuresConfig = config;
    });

    getSelectedInvoiceId();

    _roomDetailFuture =
        api<RoomApiService>((request) => request.fetchRoom(int.parse(roomId)));
    if (widget.data()?['items'] != null) {
      selectedItems = widget.data()?['items'] as List<StorageItem>;
      selectedItems.forEach((item) {
        item.txtQuantity.text = roundQuantity(item.quantity);
        item.txtPrice.text =
            vnd.format(isWholesale ? item.wholesaleCost : item.retailCost);
      });
      updatePaid();
    }
    getDataPointCost();
    if (isEditing) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _patchEditData(context));
    } else {
      orderId = await _roomDetailFuture.then((value) => value['order']?['id']);
      orderNote = note ?? '';
    }
    await _fetchListFee();
  }

  getDataPointCost() async {
    try {
      costPoint = 0;
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

  Future createAndSubmitIngre() async {
    for (var item in selectedItems) {
      for (var note in item.productNotes!) {
        if (note['name'].isEmpty) {
          CustomToast.showToastError(context,
              description: "Ghi chú sản phẩm không được để trống");
          return;
        }
      }
    }
    for (var item in selectedItems) {
      selectedDishes.add({
        'name': item.name,
        'id': item.id,
        'quantity': item.quantity,
        'notes': (item.productNotes != null && item.productNotes!.isNotEmpty)
            ? item.productNotes?.map((e) => e['name']).toList()
            : [],
        'topping': item.toppings
            .map((e) => {
                  'name': e.name,
                  'quantity': e.quantity.toInt(),
                })
            .toList(),
      });
    }

    await submit(TableStatus.using, isIngredient: true);
    Navigator.pop(context, true);
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

  num getTotalQty(List<StorageItem> items) {
    num total = 0;
    for (var item in items) {
      total += item.quantity ?? 0;
    }
    return total;
  }

  Future<void> _patchEditData(BuildContext context) async {
    if (!isReload) {
      return;
    }
    orderCode = editData['code'] ?? '';
    setState(() {
      _isLoading = true;
    });
    currentPolicy = editData['policy_id'];
    if (editData['point'] != null) {
      getPointCost(editData['point']);
    }
    String dateTimeString = '${editData['date']} ${editData['hour']}';
    DateTime dateTime = DateTime.parse(dateTimeString);

    if (editData['order_service_fee'] != null) {
      for (var item in editData['order_service_fee']) {
        getOtherFee += item['price'];
      }
    }

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
    int paymentType =
        (editData['order_payment'] as List<dynamic>).firstOrNull['type'] ?? 1;

    _formKey.currentState!.patchValue({
      'date_time': dateTime,
      'status_order': 1,
      'address': editData['address'],
    });
    pointToPay = editData['point'] ?? 0;
    timeIntend = editData['time_intend'] ?? 60;
    createDate = editData['created_at'] != null
        ? DateTime.parse(editData['created_at']).toLocal()
        : null;
    numberCustomer = editData['number_customer'] ?? 1;
    vatController.text = (editData['vat'] != null && editData['vat'] != 0)
        ? editData['vat'].toString()
        : '0';
    otherFeeController.text = vnd.format(getOtherFee);
    selectPaymentType = paymentType;
    discountController.text =
        editData['discount'] != null && editData['discount'] != 0
            ? (_discountType == DiscountType.price
                ? vnd.format(editData['discount'])
                : editData['discount'].toString())
            : '';
    paidController.text = editData['order_payment'] != null
        ? vnd.format((editData['order_payment'] as List<dynamic>)
                .map((e) => e['price'])
                .reduce((value, element) => value + element) -
            totalPointCost)
        : '';
    selectedCustomerId = editData['customer_id'];

    orderId = editData['id'];
    var lstOrder = editData['order_detail'] as List<dynamic>;
    for (Map<String, dynamic> item in lstOrder) {
      var selectItem = StorageItem.fromJson(item['variant']);
      selectItem.product = Product.fromJson(item['product']);
      selectItem.quantity = item['quantity'].toDouble();
      selectItem.discount = item['discount'];
      if (item['topping'] != null) {
        for (var topping in item['topping']) {
          var toppingItem = StorageItem.fromJson(topping);
          toppingItem.quantity = topping['quantity'].toDouble();
          selectItem.toppings.add(toppingItem);
        }
      }
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
      selectItem.discountType = DiscountType.values.firstWhereOrNull(
              (element) =>
                  element.getValueRequest() == item['discount_type']) ??
          DiscountType.percent;
      selectedItems.add(selectItem);
      _formKey.currentState?.patchValue({
        '${selectItem.id}.quantity': item['quantity'].toString(),
        '${selectItem.id}.discount':
            selectItem.discountType == DiscountType.percent
                ? selectItem.discount.toString()
                : vnd.format((selectItem.discount ?? 0) / selectItem.quantity),
      });
      selectItem.product?.vat = item['vat'];
      selectItem.txtVAT.text = roundQuantity(item['vat']);
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
      selectItem.txtQuantity.text = item['quantity'].toString();
    }
    setState(() {
      _isLoading = false;
    });
  }

  String getInitPrice(StorageItem item, CostType costType) {
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
      price =
          isWholesale ? item.copyWholesaleCost ?? 0 : item.copyRetailCost ?? 0;
    }
    return vnd.format(price);
  }

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

      return defaultFeatturesStatus;
    } catch (e) {
      return defaultFeatturesStatus;
    }
  }

  clearAllData() {
    _formKey.currentState!.patchValue({
      'status_order': 1,
      'address': '',
    });
    pointToPay = 0;
    timeIntend = 60;
    createDate = null;
    numberCustomer = 1;
    orderNote = '';
    vatController.text = '0';
    selectPaymentType = 1;
    discountController.text = '0';
    paidController.text = '0';
    otherFeeController.text = '0';
    currentPolicy = null;
    vatController.text = '0';
    getOtherFee = 0;
    selectedCustomerId = null;
    _discountType = DiscountType.percent;
    selectedItems = [];
    setState(() {});
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> getSelectedInvoiceId() async {
    try {
      int? selectedInvoiceId = await NyStorage.read('selectedInvoiceId');
      if (selectedInvoiceId != null) {
        invoiceId = selectedInvoiceId;
      }
    } catch (e) {}
  }

  Future<void> reloadEditData() async {
    if (orderId != null) {
      try {
        setState(() {
          _isLoading = true;
        });

        final newEditData = await api<OrderApiService>(
            (request) => request.detailOrder(orderId!));
        editData = newEditData;
        isReload = true;
        await _patchEditData(context);
      } catch (e) {
        CustomToast.showToastError(context,
            description: 'Có lỗi khi tải lại dữ liệu: ${e.toString()}');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void addItem(StorageItem item, num? weight) {
    final isImeiProduct = item.product?.isImei == true;

    var index = selectedItems.indexWhere((element) => element.id == item.id);
    if (index == -1) {
      selectedItems.add(item);
      item.quantity = weight == null ? 1 : weight / 1000;
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
      item.txtPrice.text = vnd.format(price);
    } else {
      if (isImeiProduct) {
        final newImei = item.imei.first;
        final isContained = selectedItems[index].imei.contains(newImei);
        if (!isContained) {
          selectedItems[index].imei.add(newImei);
        }

        selectedItems[index].quantity = selectedItems[index].imei.length;
        _formKey.currentState!.patchValue({
          '${item.id}.quantity': '${selectedItems[index].quantity}',
        });
      } else {
        selectedItems[index].quantity = weight == null
            ? (selectedItems[index].quantity ?? 0) + 1
            : (selectedItems[index].quantity ?? 0) + weight / 1000;
        _formKey.currentState!.patchValue({
          '${item.id}.quantity': roundQuantity(selectedItems[index].quantity),
        });
      }
    }
    resetItemPrice();
    updatePaid();
    setState(() {});
  }

  void addMultiTopping(List<StorageItem> toppings, StorageItem item) {
    if (toppings.isEmpty) {
      for (var i in item.toppings) {
        removeTopping(item, i);
      }
      return;
    }
    for (var topping in toppings) {
      if (item.toppings.indexWhere((element) => element.id == topping.id) ==
          -1) {
        setState(() {
          item.toppings.insert(0, topping);
          variantToCurrentBaseCost[item.id!] =
              (isWholesale ? item.wholesaleCost : item.retailCost) ?? 0;
        });
      } else {
        for (var i in item.toppings) {
          if (toppings.firstWhereOrNull((element) => element.id == i.id) ==
              null) {
            removeTopping(item, i);
          }
        }
      }
    }
    updatePaid();
  }

  void removeItem(StorageItem item) {
    item.quantity = 1;
    item.isSelected = false;
    item.discount = item.copyDiscount;
    item.discountType = item.copyDiscountType;
    item.txtQuantity.text = roundQuantity(item.quantity);
    item.txtPrice.text =
        vnd.format(isWholesale ? item.copyWholesaleCost : item.copyRetailCost);
    item.txtDiscount.text = item.discountType == DiscountType.price
        ? vnd.format((item.copyDiscount ?? 0) / item.quantity)
        : roundQuantity(item.copyDiscount ?? 0);
    setState(() {
      item.toppings.clear();
      selectedItems.remove(item);
      resetItemPrice();
    });
    checkDiscountOrder();
    updatePaid();
  }

  void removeTopping(StorageItem item, StorageItem topping) {
    topping.quantity = 1;
    _formKey.currentState
        ?.patchValue({'${topping.id}.quantity': '${topping.quantity}'});
    _formKey.currentState?.patchValue({
      '${topping.id}.price': vnd.format(
          isWholesale ? topping.copyWholesaleCost : topping.copyRetailCost)
    });
    _formKey.currentState?.patchValue({
      '${topping.id}.discount': topping.discountType == DiscountType.price
          ? vnd.format((topping.copyDiscount ?? 0) / topping.quantity)
          : roundQuantity(topping.copyDiscount ?? 0)
    });
    setState(() {
      item.toppings.remove(topping);
      resetItemPrice();
    });
    checkDiscountOrder();
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
    paidController.text = vnd.format(roundMoney(finalPrice));

    //update other fee
    num totalOtherFee = 0;
    for (var item in otherFee) {
      totalOtherFee += item['price'] ?? 0;
    }
    otherFeeController.text = vnd.format(totalOtherFee);
    setState(() {});
  }

  Future submit(TableStatus roomType,
      {bool isPay = false, bool isIngredient = false}) async {
    final isReservation = roomType == TableStatus.preOrder;
    if (!isReservation) {
      if (selectedItems.isEmpty) {
        CustomToast.showToastWarning(context, description: "Vui lòng chọn món");
        return;
      }
    }
    if (!selectedItems.isEmpty &&
        selectedItems.firstWhereOrNull((element) => element.quantity == 0) !=
            null) {
      CustomToast.showToastWarning(context,
          description: "Vui lòng chọn số lượng món");
      return;
    }

    if (!_formKey.currentState!.saveAndValidate()) {
      return;
    }
    filterNewFee();

    if (isEditing) {
      await updateOrder(roomType);
    } else {
      await saveOrder(roomType, isPay: isPay, isIngredient: isIngredient);
    }
  }

  Future<void> _pay() async {
    // if (_isLoading) {
    //   return;
    // }

    setState(() {
      _isLoading = true;
    });
    filterNewFee();
    Map<String, dynamic> orderPayload =
        getOrderPayloadEditFromForm(currentRoomType);
    orderPayload['discount_type'] = _discountType.getValueRequest();
    orderPayload["status_order"] = 4;
    orderPayload["room_type"] = TableStatus.free.toValue();
    orderPayload["service_fee"] = 0;

    try {
      final res = await api<OrderApiService>(
          (request) => request.updateTableReservation(orderId!, orderPayload));
      CustomToast.showToastSuccess(context,
          description: 'Thanh toán thành công');
      tempData['items'] = selectedItems.map((item) {
        return {
          'name': item.name,
          'price': num.parse((item.txtPrice.text).replaceAll('.', '')),
          'quantity': item.quantity,
          'toppings': (item.toppings)
              .map((t) => {
                    'name': t.name,
                    'quantity': t.quantity,
                  })
              .toList(),
          'notes': (item.productNotes != null && item.productNotes!.isNotEmpty)
              ? item.productNotes?.map((e) => e['name']).toList()
              : [],
        };
      }).toList();
      Navigator.of(context).pop();
      pop();
    } catch (e) {
      log('Error while paying: $e');
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

  Future saveOrder(TableStatus roomType,
      {bool isPay = false, bool isIngredient = false}) async {
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
      orderIdIngre = res['id'];
      orderCode = res['code'] ?? '';
      if (isPay) {
        CustomToast.showToastSuccess(context,
            description: 'Thanh toán thành công');
        tempData['items'] = selectedItems.map((item) {
          return {
            'name': item.name,
            'price': num.parse((item.txtPrice.text).replaceAll('.', '')),
            'quantity': item.quantity,
            'toppings': (item.toppings)
                .map((t) => {
                      'name': t.name,
                      'quantity': t.quantity,
                    })
                .toList(),
            'notes':
                (item.productNotes != null && item.productNotes!.isNotEmpty)
                    ? item.productNotes?.map((e) => e['name']).toList()
                    : [],
          };
        }).toList();
        tempData['code'] = res['code'];
        Navigator.of(context).pop();
        pop();
      } else if (!isIngredient) {
        Navigator.of(context).pop();
      }
      clearAllData();
    } catch (e) {
      CustomToast.showToastError(context, description: getResponseError(e));
    } finally {
      setState(() {
        orderId = orderIdIngre;
        _isLoading = false;
      });
    }
  }

  Future updateOrder(TableStatus roomType) async {
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
      Map<String, dynamic> orderPayload = getOrderPayloadEditFromForm(roomType);
      orderPayload['discount_type'] = _discountType.getValueRequest();

      await api<OrderApiService>(
          (request) => request.updateTableReservation(orderId!, orderPayload));
      Navigator.pop(context);
      CustomToast.showToastSuccess(context, description: 'Cập nhật thành công');
    } catch (e) {
      log(e.toString());
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
    DateTime dateTime = _formKey.currentState!.value['date_time'];
    final date = dateTime.toIso8601String().split('T')[0];
    final hour =
        dateTime.toIso8601String().split('T')[1].split('.')[0].substring(0, 5);
    Map<String, dynamic> orderPayload = {
      'type': 3,
      'room_id': roomId,
      'room_type': roomType.toValue(),
      'point': pointToPay,
      'note':
          featuresConfig['note'] == true ? orderNote : widget.data()?['note'],
      'order_service_fee': featuresConfig['other_fee'] != true ? [] : otherFee,
      'is_retail': !isWholesale,
      'phone': '',
      'discount_type': _discountType.getValueRequest(),
      'name': '',
      'customer_id': selectedCustomerId ?? null,
      'create_date': createDate != null
          ? DateFormat('yyyy/MM/dd HH:mm:ss').format(createDate!)
          : null,
      'address': _formKey.currentState!.value['address'],
      'status_order': isPay ? 4 : 1,
      'discount': _discountType == DiscountType.percent
          ? stringToDouble(discountController.text) ?? 0
          : stringToInt(discountController.text) ?? 0,
      'service_fee': 0,
      'number_customer': numberCustomer,
      'time_intend': timeIntend,
      'date': date,
      'hour': hour,
      'policy_id': currentPolicy,
      'order_detail': selectedItems.map((item) {
        return {
          'vat': item.product?.vat ?? 0,
          'product_id': item.product?.id ?? 0,
          'variant_id': item.id ?? 0,
          'quantity': item.quantity ?? 1,
          'discount': item.discount ?? '',
          'notes': item.productNotes,
          'discount_type': item.discountType.getValueRequest(),
          'price': num.parse((item.txtPrice.text ?? '0').replaceAll('.', '')),
          'topping': item.toppings.map((e) {
            return {
              'variant_id': e.id,
              'quantity': e.quantity.toInt(),
              'price': e.retailCost,
            };
          }).toList()
        };
      }).toList(),
      'payment': {
        "type": selectPaymentType,
        // if paid > final price, then set paid = final price
        "price": getPaid() > getFinalPrice() ? getFinalPrice() : getPaid(),
      }
    };
    return orderPayload;
  }

  dynamic getOrderPayloadEditFromForm(TableStatus roomType) {
    try {
      var lstOrder = editData['order_detail'] as List<dynamic>;
      List<Map<String, dynamic>> orderDetailRequest = [];
      for (Map<String, dynamic> order in lstOrder) {
        Map<String, dynamic> orderDetail = {
          'id': order['id'],
          'product_id': order['product']['id'] ?? 0,
          'create_date': order['create_date'],
          'variant_id': order['variant']['id'] ?? 0,
          'notes': order['order_detail_note'] ?? [],
          'topping': order['topping'] ?? [],
        };
        var filterInSelected = selectedItems.firstWhereOrNull(
            (element) => element.id == order['variant']['id']);
        if (filterInSelected != null) {
          orderDetail['is_delete'] = false;
          orderDetail['quantity'] = filterInSelected.quantity;
          orderDetail['discount'] = filterInSelected.discount ?? '';
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
          List<dynamic> toppings = [];
          Map<int, Map<String, dynamic>> initToppingsMap = {
            for (var topping in orderDetail['topping'])
              if (topping['id'] != null) topping['id']: topping
          };
          for (var selectedTopping in filterInSelected.toppings) {
            if (selectedTopping.orderDetailId != null &&
                initToppingsMap.containsKey(selectedTopping.id)) {
              toppings.add({
                'id': selectedTopping.id,
                'name': selectedTopping.name,
                'topping_id': selectedTopping.toppingId,
                'quantity': selectedTopping.quantity.toInt(),
                'price': selectedTopping.retailCost,
                'is_delete': false,
              });
              initToppingsMap.remove(selectedTopping.id);
            } else if (selectedTopping.orderDetailId == null) {
              toppings.add({
                'name': selectedTopping.name,
                'quantity': selectedTopping.quantity.toInt(),
                'price': selectedTopping.retailCost,
                'variant_id': selectedTopping.id,
              });
            }
          }
          for (var topping in initToppingsMap.values) {
            topping['is_delete'] = true;
            topping['price'] = topping['retail_cost'];
            toppings.add(topping);
          }
          orderDetail['topping'] = toppings;
        } else {
          orderDetail['is_delete'] = true;
          orderDetail['quantity'] = order['quantity'];
          orderDetail['discount'] = order['discount'] ?? '';
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
            'discount': item.discount ?? '',
            'discount_type': item.discountType.getValueRequest(),
            'price': isWholesale ? item.wholesaleCost : item.retailCost,
            'topping': item.toppings.map((e) {
              return {
                'variant_id': e.id,
                'quantity': e.quantity.toInt(),
                'price': e.retailCost,
              };
            }).toList()
          };
          orderDetailRequest.add(newVal);
        }
      }

      DateTime dateTime = _formKey.currentState!.value['date_time'];
      final date = dateTime.toIso8601String().split('T')[0];
      final hour = dateTime
          .toIso8601String()
          .split('T')[1]
          .split('.')[0]
          .substring(0, 5);

      Map<String, dynamic> orderPayload = {
        'type': 3, // 1: order, 2: storage
        'room_id': roomId,
        'point': pointToPay,
        'order_service_fee':
            featuresConfig['other_fee'] != true ? [] : otherFee,
        'room_type': roomType.toValue(),
        'date': date,
        'hour': hour,
        'number_customer': numberCustomer,
        'time_intend': timeIntend,
        'is_retail': !isWholesale,
        'discount_type': _discountType.getValueRequest(),
        'phone': '',
        'name': '',
        'customer_id': selectedCustomerId ?? null,
        'address': _formKey.currentState!.value['address'] ??
            widget.data()?['address'],
        'status_order': 1,
        'create_date': createDate != null
            ? DateFormat('yyyy/MM/dd HH:mm:ss').format(createDate!)
            : null,
        'discount': _discountType == DiscountType.percent
            ? stringToDouble(_formKey.currentState!.value['discount']) ?? 0
            : stringToInt(_formKey.currentState!.value['discount']) ?? 0,
        // 'vat': stringToDouble(_formKey.currentState!.value['vat']) ?? 0,
        'service_fee': 0,
        'policy_id': currentPolicy,
        'payment': {
          "type": selectPaymentType,
          // if paid > final price, then set paid = final price
          "price": getPaid() > getFinalPrice() ? getFinalPrice() : getPaid(),
        },
        'order_detail': orderDetailRequest,
        'note': orderNote,
      };

      return orderPayload;
    } catch (e) {
      log('Error in getOrderPayloadEditFromForm: $e');
      return {};
    }
  }

  void checkDiscountOrder() {
    if (_isLoading) return;
    num discount = _discountType == DiscountType.price
        ? stringToInt(discountController.text) ?? 0
        : stringToDouble(discountController.text) ?? 0;
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
    num discount = item.discount ?? 0;
    num currentPrice =
        item.txtPrice.text.isEmpty ? 0 : stringToInt(item.txtPrice.text) ?? 0;
    if (item.discountType == DiscountType.price &&
        discount > currentPrice * item.quantity) {
      Future.delayed(Duration(milliseconds: 100), () {
        String currentText = item.txtDiscount.text;
        if (currentText.isNotEmpty) {
          item.txtDiscount.text = vnd.format(currentPrice);
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
        item.txtDiscount.text = '100';
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
    int discountOrder = stringToInt(discountController.text) ?? 0;
    if (_discountType == DiscountType.price &&
        discountOrder > getTotalPrice()) {
      discountController.text = vnd.format(getTotalPrice());
    }
  }

  num getPrice(StorageItem item) {
    dynamic retailCostValue = item.txtPrice.text;
    dynamic quantityValue = item.quantity.toString();

    num retailCost = stringToInt(retailCostValue) ?? item.retailCost ?? 0;
    num quantity = num.tryParse(quantityValue) ?? 0;

    num toppingPrice = 0;
    for (var topping in item.toppings) {
      toppingPrice += (topping.retailCost ?? 0) * (topping.quantity ?? 0);
    }
    num total = retailCost * quantity + toppingPrice;

    // discount
    num discountVal = (item.discount ?? 0);
    num discountPrice = item.discountType == DiscountType.percent
        ? total * discountVal / 100
        : discountVal;

    // apply discount
    total = total - discountPrice < 0 ? 0 : total - discountPrice;
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

  // phải trả
  num getFinalPrice() {
    num total = getTotalPrice();
    // apply discount
    num discountVal = _discountType == DiscountType.price
        ? stringToInt(discountController.text) ?? 0
        : stringToDouble(discountController.text) ?? 0;
    num discountPrice = _discountType == DiscountType.percent
        ? total * discountVal / 100
        : discountVal;
    total = total - discountPrice;

    // apply service fee
    // num serviceFee = stringToNum(_formKey.currentState?.value['service_fee']) ?? 0;
    //
    // total += serviceFee;

    // vat
    // num vat = stringToDouble(_formKey.currentState?.value['vat']) ?? 0;
    // total = total + total * vat / 100;

    return total + getOtherFee;
  }

  num getPaid() {
    return (stringToInt(paidController.text) ?? 0) + totalPointCost;
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

  updateList(List<StorageItem> selectedItems, List<dynamic> initIngredients) {
    List<Map<String, dynamic>> temp = [];
    if (initIngredients.isNotEmpty) {
      for (var ingredient in selectedItems) {
        num quantity = ingredient.quantity;
        for (var item in initIngredients) {
          if (item['variant_id'] == ingredient.id) {
            quantity = ingredient.quantity - item['quantity'];
            break;
          }
        }
        if (quantity > 0) {
          temp.add({
            'ingredient': ingredient.ingredient,
            'name': ingredient.name,
            'id': ingredient.id,
            'quantity': quantity,
            'product': ingredient.product,
            'isIngredient': ingredient.product?.isIngredient,
            'notes': ingredient.productNotes,
            'topping': ingredient.toppings
                .map((e) => {
                      'name': e.name,
                      'quantity': e.quantity.toInt(),
                    })
                .toList(),
          });
        }
      }

      return temp;
    } else {
      return selectedItems
          .map((item) => {
                'ingredient': item.ingredient,
                'name': item.name,
                'id': item.id,
                'quantity': item.quantity,
                'product': item.product,
                'isIngredient': item.product?.isIngredient,
                'notes': item.productNotes,
                'topping': item.toppings
                    .map((e) => {
                          'name': e.name,
                          'quantity': e.quantity.toInt(),
                        })
                    .toList(),
              })
          .toList();
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
      appBar: AppBar(
        backgroundColor: ThemeColor.get(context).primaryAccent,
        elevation: 0,
        toolbarHeight: 40,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: IntrinsicWidth(
          child: Container(
            alignment: Alignment.center,
            padding:
                const EdgeInsets.only(left: 16, right: 20, top: 10, bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.table_restaurant,
                  color: ThemeColor.get(context).primaryAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isEditing ? 'Cập nhật $roomName' : 'Tạo đơn bàn mới',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_horiz, size: 22, color: Colors.white),
            onPressed: () {
              showMenuItems(context);
            },
          ),
        ],
      ),
      body: SafeArea(
          child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: FormBuilder(
          key: _formKey,
          onChanged: () {
            _formKey.currentState!.save();
          },
          clearValueOnUnregister: true,
          autovalidateMode: AutovalidateMode.disabled,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      buildBreadCrumb(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 20),
                          buildListItem(),
                        ],
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              Divider(color: Colors.grey),
              buildFooter(),
              Row(
                children: [
                  Expanded(flex: 2, child: buildOptionsButton(context)),
                  SizedBox(width: 12),
                  Expanded(flex: 3, child: buildPaymentButton(context)),
                ],
              ),
              SizedBox(height: 5),
            ],
          ),
        ),
      )),
    );
  }

  Widget buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (featuresConfig['note'] == true) ...[
              InkWell(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  alignment: Alignment.center,
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        ThemeColor.get(context).primaryAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.edit_note_rounded,
                      color: ThemeColor.get(context).primaryAccent),
                ),
                onTap: () {
                  showNoteDialog(context);
                },
              ),
              SizedBox(width: 5),
            ],
            if (featuresConfig['customer_quantity'] == true) ...[
              InkWell(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  alignment: Alignment.center,
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        ThemeColor.get(context).primaryAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.person_add_alt_1_rounded,
                      color: ThemeColor.get(context).primaryAccent),
                ),
                onTap: () {
                  showNumberDialog(context, false);
                },
              ),
              SizedBox(width: 5),
            ],
            if (featuresConfig['create_date'] == true) ...[
              InkWell(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  alignment: Alignment.center,
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        ThemeColor.get(context).primaryAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.date_range_rounded,
                      color: ThemeColor.get(context).primaryAccent),
                ),
                onTap: () {
                  showCreateDateDialog(context);
                },
              ),
              SizedBox(width: 5)
            ],
            if (featuresConfig['customer_quantity'] == true) ...[
              InkWell(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  alignment: Alignment.center,
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        ThemeColor.get(context).primaryAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.av_timer,
                      color: ThemeColor.get(context).primaryAccent),
                ),
                onTap: () {
                  showNumberDialog(context, true);
                },
              ),
              SizedBox(width: 5)
            ],
          ]),
          Text.rich(
            TextSpan(
              text: 'Tổng tiền',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Container(
                    margin: EdgeInsets.only(right: 6, left: 4),
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: ThemeColor.get(context)
                          .primaryAccent
                          .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${roundQuantity(getTotalQty(selectedItems))}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: ThemeColor.get(context).primaryAccent,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                TextSpan(
                  text: ': ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                TextSpan(
                  text: vnd.format(getTotalPrice()),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ThemeColor.get(context).primaryAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPaymentButton(BuildContext context) {
    if (buttonType == 'reserve') {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: ThemeColor.get(context).primaryAccent,
          minimumSize: Size(80, 40),
        ),
        icon: Icon(Icons.table_restaurant, color: Colors.white),
        label: Text(
          'Đặt bàn',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        onPressed: () {
          submit(TableStatus.preOrder);
        },
      );
    }
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: ThemeColor.get(context).primaryAccent,
        minimumSize: Size(80, 40),
      ),
      icon: Icon(Icons.attach_money, color: Colors.white),
      label: Text(
        "Thanh toán",
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
      onPressed: () {
        showSummary();
      },
    );
  }

  Widget buildOptionsButton(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.grey[50],
        minimumSize: Size(80, 40),
        side: BorderSide(
          color: ThemeColor.get(context).primaryAccent,
          width: 0.5,
        ),
      ),
      icon:
          Icon(Icons.more_horiz, color: ThemeColor.get(context).primaryAccent),
      label: Text(
        "Tuỳ chọn",
        style: TextStyle(
          color: ThemeColor.get(context).primaryAccent,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
      onPressed: () async {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (BuildContext context) {
            return StatefulBuilder(builder: (context, setState) {
              return Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 80,
                  top: 20,
                  left: 20,
                  right: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: ThemeColor.get(context)
                                .primaryAccent
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.flash_on,
                            color: ThemeColor.get(context).primaryAccent,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Tuỳ chọn',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[900],
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    Material(
                      color: Colors.transparent,
                      child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            children: [
                              if (currentRoomType == TableStatus.using)
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    // alignment: Alignment.centerLeft,
                                    minimumSize: Size(double.infinity, 56),
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 8),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    foregroundColor: Colors.green,
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    submit(currentRoomType);
                                  },
                                  icon: Icon(Icons.add_shopping_cart,
                                      color: Colors.green),
                                  label: Text("Cập nhật",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black)),
                                )
                              else if (buttonType == 'null' ||
                                  buttonType == 'create_order')
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    // alignment: Alignment.centerLeft,
                                    minimumSize: Size(double.infinity, 56),
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 8),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    foregroundColor: Colors.green,
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    submit(TableStatus.using);
                                  },
                                  icon: Icon(Icons.save, color: Colors.green),
                                  label: Text("Tạo đơn",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black)),
                                ),
                            ],
                          )),
                    )
                  ],
                ),
              );
            });
          },
        );
      },
    );
  }

  Widget buildOtherFee(StateSetter setState) {
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
                controller: otherFeeController,
                name: 'other_fee',
                readOnly: true,
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

  void showCreateDateDialog(BuildContext context) {
    DateTime selectedDate = createDate ?? DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.grey[50],
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        ThemeColor.get(context).primaryAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.date_range_rounded,
                      color: ThemeColor.get(context).primaryAccent, size: 28),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Thời gian tạo đơn',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.grey[600]),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            content: Container(
              padding: EdgeInsets.only(top: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      elevation: 0,
                      backgroundColor: Colors.grey[200],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(Icons.calendar_today,
                        color: ThemeColor.get(context).primaryAccent),
                    label: Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(selectedDate),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(selectedDate),
                        );
                        if (time != null) {
                          final dateTime = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            time.hour,
                            time.minute,
                          );
                          if (dateTime.isAfter(DateTime.now())) {
                            await showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18)),
                                title: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: ThemeColor.get(context)
                                            .primaryAccent
                                            .withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(Icons.warning_amber_rounded,
                                          color: ThemeColor.get(context)
                                              .primaryAccent,
                                          size: 28),
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Xác nhận',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: ThemeColor.get(context)
                                              .primaryAccent,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                content: Text(
                                  'Bạn không thể tạo trước đơn. Vui lòng chọn lại thời gian.',
                                  style: TextStyle(fontSize: 16),
                                ),
                                actionsPadding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                actions: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: ThemeColor.get(context)
                                            .primaryAccent,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        padding:
                                            EdgeInsets.symmetric(vertical: 14),
                                      ),
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: Text('Đồng ý',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            return;
                          } else if (dateTime.isBefore(DateTime(
                              DateTime.now().year,
                              DateTime.now().month,
                              DateTime.now().day))) {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18)),
                                title: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: ThemeColor.get(context)
                                            .primaryAccent
                                            .withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(Icons.info_outline,
                                          color: ThemeColor.get(context)
                                              .primaryAccent,
                                          size: 28),
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Xác nhận',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: ThemeColor.get(context)
                                              .primaryAccent,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                content: Text(
                                  'Báo cáo của đơn hàng sẽ được tính vào ngày ${DateFormat('dd-MM-yyyy HH:mm').format(dateTime)}, bạn đồng ý?',
                                  style: TextStyle(fontSize: 16),
                                ),
                                actionsPadding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                actions: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.grey[700],
                                          side: BorderSide(
                                              color: Colors.grey[300]!),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 24, vertical: 14),
                                        ),
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: Text('Không',
                                            style: TextStyle(fontSize: 16)),
                                      ),
                                      SizedBox(width: 12),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              ThemeColor.get(context)
                                                  .primaryAccent,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 28, vertical: 14),
                                        ),
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: Text('Có',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                            if (confirm != true) return;
                          }
                          setState(() {
                            selectedDate = dateTime;
                          });
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            actionsPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text('Hủy'),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeColor.get(context).primaryAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      createDate = selectedDate;
                      setState(() {});
                      Navigator.pop(context);
                    },
                    child: Text('Xác nhận',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          );
        });
      },
    );
  }

  void showPointPaymentDialog(BuildContext context) {
    TextEditingController _pointController = TextEditingController(
        text: pointToPay != 0 ? pointToPay.toString() : '');
    checkValidatePoint(String value) {
      if (_isLoading) {
        return;
      }
      int parsedValue = stringToInt(value) ?? 0;
      String newValue = value.substring(
          0, value.length != 0 ? value.length - 1 : value.length);

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

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.grey[50],
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        ThemeColor.get(context).primaryAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.star,
                      color: ThemeColor.get(context).primaryAccent, size: 28),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Thanh toán bằng điểm',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.grey[600]),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            content: Container(
              padding: EdgeInsets.only(top: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '*Điểm hiện tại: $customerPoint',
                    style: TextStyle(
                      color: ThemeColor.get(context).primaryAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 12),
                  FormBuilderTextField(
                    controller: _pointController,
                    name: 'point',
                    autofocus: true,
                    cursorColor: ThemeColor.get(context).primaryAccent,
                    decoration: InputDecoration(
                      hintText: 'Nhập số điểm',
                      suffix: Text(
                        '= ${vndCurrency.format(totalPointCost)}',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: ThemeColor.get(context).primaryAccent,
                        ),
                      ),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*$'))
                    ],
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    onChanged: (value) {
                      getPointCost(int.tryParse(value ?? '0') ?? 0);
                      checkValidatePoint(value ?? '0');
                      getDebt();
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
            actionsPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text('Hủy'),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeColor.get(context).primaryAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      pointToPay = stringToInt(_pointController.text) ?? 0;
                      Navigator.pop(context);
                    },
                    child: Text('Xác nhận',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          );
        });
      },
    );
  }

  void showNumberDialog(BuildContext context, bool isTimeIntend) {
    int quantity = isTimeIntend ? timeIntend : numberCustomer;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          void updateQuantity(int value) {
            quantity = value < 1 ? 1 : value;
            setState(() {});
          }

          void onKeyTap(String key) {
            if (key == 'C') {
              quantity = 1;
            } else if (key == '←') {
              quantity = int.tryParse(quantity
                      .toString()
                      .substring(0, quantity.toString().length - 1)) ??
                  1;
              if (quantity < 1) quantity = 1;
            } else {
              String newValue = quantity == 0 ? key : quantity.toString() + key;
              quantity = int.tryParse(newValue) ?? quantity;
            }
            setState(() {});
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        ThemeColor.get(context).primaryAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(isTimeIntend ? Icons.access_time : Icons.people,
                      color: ThemeColor.get(context).primaryAccent, size: 28),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isTimeIntend
                        ? 'Thời gian dự kiến (phút)'
                        : 'Số lượng khách',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.grey[600]),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.4,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: CircleBorder(),
                          backgroundColor: ThemeColor.get(context)
                              .primaryAccent
                              .withOpacity(0.15),
                          elevation: 0,
                          padding: EdgeInsets.all(0),
                        ),
                        onPressed: () {
                          updateQuantity(quantity - 1);
                        },
                        child: Icon(Icons.remove,
                            color: ThemeColor.get(context).primaryAccent,
                            size: 32),
                      ),
                      SizedBox(width: 24),
                      Container(
                        width: 160,
                        height: 60,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: ThemeColor.get(context).primaryAccent,
                              width: 1.5),
                        ),
                        child: Text(
                          '$quantity',
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.black),
                        ),
                      ),
                      SizedBox(width: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: CircleBorder(),
                          backgroundColor: ThemeColor.get(context)
                              .primaryAccent
                              .withOpacity(0.15),
                          elevation: 0,
                          padding: EdgeInsets.all(0),
                        ),
                        onPressed: () {
                          updateQuantity(quantity + 1);
                        },
                        child: Icon(Icons.add,
                            color: ThemeColor.get(context).primaryAccent,
                            size: 32),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    height: MediaQuery.of(context).size.width * 0.3,
                    child: GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 2.5,
                      physics: NeverScrollableScrollPhysics(),
                      children: [
                        for (var i = 1; i <= 9; i++)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor:
                                  ThemeColor.get(context).primaryAccent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                              padding: EdgeInsets.symmetric(vertical: 18),
                            ),
                            onPressed: () => onKeyTap('$i'),
                            child: Text('$i',
                                style: TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.bold)),
                          ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor:
                                ThemeColor.get(context).primaryAccent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                            padding: EdgeInsets.symmetric(vertical: 18),
                          ),
                          onPressed: () => onKeyTap('C'),
                          child: Text('C',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor:
                                ThemeColor.get(context).primaryAccent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                            padding: EdgeInsets.symmetric(vertical: 18),
                          ),
                          onPressed: () => onKeyTap('0'),
                          child: Text('0',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor:
                                ThemeColor.get(context).primaryAccent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                            padding: EdgeInsets.symmetric(vertical: 18),
                          ),
                          onPressed: () => onKeyTap('←'),
                          child: Icon(Icons.backspace_outlined, size: 22),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actionsPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeColor.get(context).primaryAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    if (isTimeIntend) {
                      timeIntend = quantity;
                    } else {
                      numberCustomer = quantity;
                    }
                    setState(() {});
                    Navigator.pop(context);
                  },
                  child: Text('Xác nhận',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
              ),
            ],
          );
        });
      },
    );
  }

  void showNoteDialog(BuildContext context) {
    final TextEditingController noteController =
        TextEditingController(text: orderNote);
    log(orderNote);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ThemeColor.get(context).primaryAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.edit_note_rounded,
                    color: ThemeColor.get(context).primaryAccent, size: 28),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nhập ghi chú',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.grey[600]),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: Container(
            padding: EdgeInsets.only(top: 8),
            child: TextField(
              controller: noteController,
              maxLines: 4,
              autofocus: true,
              onTapOutside: (event) {
                FocusScope.of(context).unfocus();
              },
              cursorColor: ThemeColor.get(context).primaryAccent,
              style: TextStyle(fontSize: 16),
              decoration: InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                hintText: 'Nhập ghi chú cho đơn hàng...',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          actionsPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text('Hủy'),
                ),
                SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeColor.get(context).primaryAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    orderNote = noteController.text;
                    Navigator.pop(context);
                  },
                  child: Text('Lưu',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void showMenuItems(context) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) {
          return Container(
              height: MediaQuery.of(context).size.height * 0.3,
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          'Tuỳ chọn',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      )
                    ],
                  ),
                  Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10.0, horizontal: 10),
                    child: InkWell(
                      onTap: () {
                        listPolicies.clear();
                        routeTo(SettingOrderSalePage.path,
                            onPop: (value) async {
                          if (value != null) {
                            Navigator.pop(context);
                            isReload = false;
                            await init();
                            setState(() {
                              updatePaid();
                            });
                          }
                        });
                      },
                      child: Row(
                        children: [
                          Icon(Icons.settings_outlined),
                          SizedBox(width: 10),
                          Text(
                            'Cài đặt',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (currentRoomType == TableStatus.using) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Divider(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10.0, horizontal: 10),
                      child: InkWell(
                        onTap: () {
                          deleteOrder(context);
                        },
                        child: Row(
                          children: [
                            Icon(Icons.close, color: Colors.red),
                            SizedBox(width: 10),
                            Text(
                              'Huỷ đơn',
                              style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.red,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    )
                  ]
                ],
              ));
        });
  }

  void deleteOrder(contecxt) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Xác nhận'),
          content: Text('Bạn có chắc chắn muốn hủy đơn không?'),
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
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
                cancelOrder(currentRoomType);
              },
              child: Text('Có'),
            ),
          ],
        );
      },
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

  void showDetailVat(context, Offset position) async {
    final vatItems = selectedItems
        .where((item) =>
            item.product != null &&
            item.product?.vat != null &&
            item.product!.vat! > 0 &&
            (item.product?.useVat != false))
        .toList();
    getVatPrice(StorageItem item) {
      dynamic retailCostValue = item.txtPrice.text;
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

  Widget buildOrderVAT(StateSetter setState) {
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
                  controller: vatController,
                  name: 'vat',
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

  Widget buildOrderDiscount(
      StateSetter setState, GlobalKey<FormBuilderState> sheetFormKey) {
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
              if (mounted) {
                setState(() {});
              }
            },
            onTapOutside: (event) {
              FocusScope.of(context).unfocus();
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
              suffixIcon: CupertinoSlidingSegmentedControl<DiscountType>(
                thumbColor: ThemeColor.get(context).primaryAccent,
                onValueChanged: (DiscountType? value) {
                  if (value == DiscountType.percent) {
                    double discount = stringToDouble(
                            sheetFormKey.currentState?.value['discount']) ??
                        0;
                    sheetFormKey.currentState?.patchValue({
                      'discount':
                          discount == 0.0 ? '' : discount.toStringAsFixed(0),
                    });
                  } else {
                    num discount = stringToInt(
                            sheetFormKey.currentState?.value['discount']) ??
                        0;
                    sheetFormKey.currentState?.patchValue({
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
              ),
              // icon: Icon(Icons.contact_page),
              // border: UnderlineInputBorder(),
              floatingLabelBehavior: FloatingLabelBehavior.never,
              hintText: '0',
              suffixText: _discountType == DiscountType.percent ? '' : '',
            ),
          ),
        ),
      ],
    );
  }

  Widget buildListPolicies(
      StateSetter setState, GlobalKey<FormBuilderState> sheetFormKey) {
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
                        sheetFormKey.currentState!
                            .patchValue({'policy_id': null});
                        currentPolicy = null;
                        resetItemPrice();
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
  void showSummary() {
    final sheetFormKey = GlobalKey<FormBuilderState>();
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return SafeArea(
            child: FormBuilder(
              key: sheetFormKey,
              child: Container(
                margin: EdgeInsets.only(top: 60, left: 0, right: 0),
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 24,
                      offset: Offset(0, -8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tóm tắt đơn hàng',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: ThemeColor.get(context).primaryAccent,
                      ),
                    ),
                    SizedBox(height: 18),
                    buildListPolicies(setState, sheetFormKey),
                    SizedBox(height: 12),
                    buildOrderDiscount(setState, sheetFormKey),
                    buildOtherFee(setState),
                    buildOrderVAT(setState),
                    Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Tổng tiền T.Toán',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.grey[700])),
                        Text(
                          vndCurrency
                              .format(roundMoney(getFinalPrice()))
                              .replaceAll('vnđ', 'đ'),
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.orange[700]),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Khách T.Toán',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.grey[700])),
                        SizedBox(
                          width: 180,
                          height: 40,
                          child: FormBuilderTextField(
                            controller: paidController,
                            keyboardType: TextInputType.number,
                            name: 'paid',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.right,
                            onChanged: (vale) {
                              setState(() {});
                            },
                            onTap: () {
                              sheetFormKey.currentState!.patchValue({
                                'paid': '',
                              });
                              setState(() {});
                            },
                            cursorColor: ThemeColor.get(context).primaryAccent,
                            inputFormatters: [
                              CurrencyTextInputFormatter(
                                locale: 'vi',
                                symbol: '',
                              )
                            ],
                            decoration: InputDecoration(
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.never,
                              suffixText: 'đ',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                    color:
                                        ThemeColor.get(context).primaryAccent),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (getDebt() != 0) ...[
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(getDebt() > 0 ? 'Còn nợ' : 'Tiền thừa',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.redAccent)),
                          Text(
                            vndCurrency
                                .format(getDebt().abs())
                                .replaceAll('vnđ', 'đ'),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.redAccent),
                          ),
                        ],
                      ),
                    ],
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Hình thức T.Toán',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.grey[700])),
                        SizedBox(
                          width: 180,
                          height: 40,
                          child: FormBuilderDropdown(
                            name: 'payment_type',
                            onChanged: (value) {
                              selectPaymentType = value ?? 1;
                            },
                            initialValue: selectPaymentType,
                            items: [
                              DropdownMenuItem(
                                value: 1,
                                child: Text(
                                  'Tiền mặt',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 2,
                                child: Text(
                                  'Chuyển khoản',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 3,
                                child: Text(
                                  'Quẹt thẻ',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              ThemeColor.get(context).primaryAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        icon: Icon(Icons.attach_money, color: Colors.white),
                        label: Text(
                          'Thanh toán',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          if (currentRoomType == TableStatus.free) {
                            submit(TableStatus.free, isPay: true);
                          } else {
                            _pay();
                          }
                        },
                      ),
                    ),
                    SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        });
      },
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

  Widget buildItem(StorageItem item, int index) {
    bool itemExists = false;
    if (editData?['order_ingredient'] != null) {
      itemExists = editData['order_ingredient']
          .any((ingredient) => ingredient['variant_id'] == item.id);
    }

    return BeverageOrderStorageItemPos(
      setState: () {
        setState(() {});
      },
      onVATChange: (value) {
        item.product?.vat = stringToDouble(value) ?? 0;
      },
      formKey: _formKey,
      featuresConfig: featuresConfig,
      currentPolicy: currentPolicy,
      item: item,
      index: index,
      itemExists: itemExists,
      removeItem: removeItem,
      updatePaid: updatePaid,
      costType: isWholesale ? CostType.wholesale : CostType.retail,
      isLast: index == selectedItems.length - 1,
      checkDiscountItem: (item) {
        checkDiscountItem(item);
      },
      onMinusQuantity: () {
        if (item.quantity >= 1) {
          String newQuantityStr = (item.quantity - 1).toStringAsFixed(3);
          num newQuantity = num.tryParse(newQuantityStr) ?? 0;
          if (newQuantity == newQuantity.floor()) {
            item.quantity = newQuantity.toInt();
          } else {
            item.quantity = newQuantity.toDouble();
          }
          if (item.discountType == DiscountType.price) {
            final currentValue = item.txtDiscount.text;
            item.discount = (stringToInt(currentValue) ?? 0) * item.quantity;
          }
          item.txtQuantity.text = roundQuantity(item.quantity);
          setState(() {});
          if (newQuantity == newQuantity.floor()) {
            item.quantity = newQuantity.toInt();
          } else {
            item.quantity = newQuantity.toDouble();
          }

          item.txtQuantity.text = roundQuantity(item.quantity);
          setState(() {});
        }
      },
      getPrice: () => getPrice(item),
      onChangeQuantity: (value) {
        num newQuantity = stringToDouble(value) ?? 0;
        num maxQuantity = item.temporality ?? 0;

        if (item.isBuyAlways == false && newQuantity > maxQuantity) {
          Future.microtask(() {
            item.txtQuantity.text = roundQuantity(maxQuantity);
            item.quantity = maxQuantity;
            CustomToast.showToastError(context,
                description: "Quá số lượng tồn kho");
          });
        } else {
          item.quantity = newQuantity;
        }
        if (newQuantity == newQuantity.floor()) {
          item.quantity = newQuantity.toInt();
        } else {
          item.quantity = newQuantity;
        }
        if (item.discountType == DiscountType.price) {
          final currentValue = item.txtDiscount.text;
          item.discount = (stringToInt(currentValue) ?? 0) * item.quantity;
        }
        checkDiscountItem(item);
        checkOnChange();
        setState(() {});
        updatePaid();
      },
      onIncreaseQuantity: () {
        String newQuantityStr = (item.quantity + 1).toStringAsFixed(3);
        num newQuantity = stringToDouble(newQuantityStr) ?? 0;
        if (item.isBuyAlways == false &&
            newQuantity.toDouble() > (item.temporality ?? 0)) {
          CustomToast.showToastError(context,
              description: "Sản phẩm không thể bán âm");
          return;
        }
        if (newQuantity == newQuantity.floor()) {
          item.quantity = newQuantity.toInt();
        } else {
          item.quantity = newQuantity;
        }
        if (item.discountType == DiscountType.price) {
          final currentValue = item.txtDiscount.text;
          item.discount = (stringToInt(currentValue) ?? 0) * item.quantity;
        }
        item.txtQuantity.text = roundQuantity(item.quantity);
        setState(() {});
      },
      onChangePrice: (value) {
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

        final num defaultPrice = currentPolicy != null && policyValue != null
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
      onChangeDiscountType: (value) {
        setState(() {
          final currentValue = item.txtDiscount.text;

          if (currentValue.isEmpty) {
            item.txtDiscount.text = '';
          } else {
            if (value == DiscountType.percent) {
              double discount = stringToDouble(currentValue) ?? 0;
              item.txtDiscount.text = discount.toStringAsFixed(0);
            } else {
              item.txtDiscount.text =
                  vnd.format(stringToInt(currentValue) ?? 0);
            }
          }
          item.discountType = value ?? DiscountType.percent;
          item.discount = item.discountType == DiscountType.percent
              ? stringToDouble(currentValue) ?? 0
              : stringToInt(currentValue) ?? 0;
          if (item.discountType == DiscountType.percent &&
              (stringToDouble(currentValue) ?? 0) > 100) {
            item.txtDiscount.text = '100';
          }
          updatePaid();
        });
      },
      addMultiTopping: (List<StorageItem>? toppings, StorageItem item) {
        if (toppings != null) {
          addMultiTopping(toppings, item);
        }
      },
    );
  }

  Widget buildBreadCrumb() {
    return FutureBuilder<dynamic>(
      future: _roomDetailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(
            color: ThemeColor.get(context).primaryAccent,
          ));
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
            backgroundColor: Colors.white,
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
                width: MediaQuery.of(context).size.width * 0.3,
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

  void getTotalOtherFee() {
    num totalOtherFee = 0;

    for (var fee in cloneOtherFee) {
      if (fee['is_delete'] == null || fee['is_delete'] != true) {
        totalOtherFee += fee['price'] ?? 0;
      }
    }
    getOtherFee = totalOtherFee;
    otherFeeController.text = vnd.format(totalOtherFee);
    updatePaid();
  }
}

class BeverageOrderStorageItemPos extends StatelessWidget {
  final GlobalKey<FormBuilderState> formKey;
  StorageItem item;
  final int index;
  final CostType costType;
  final bool itemExists;
  final Function updatePaid;
  final bool isLast;
  int? currentPolicy;
  final Function(StorageItem) removeItem;
  final Function(List<StorageItem>?, StorageItem item) addMultiTopping;
  final Function() onMinusQuantity;
  final Function() getPrice;
  final Function(String?) onChangeQuantity;
  final Function() onIncreaseQuantity;
  final Function(String?) onChangePrice;
  final Function(StorageItem) checkDiscountItem;
  final Function(DiscountType?) onChangeDiscountType;
  void Function(String)? onVATChange = null;

  final Function() setState;
  Map<String, bool> featuresConfig = {};

  BeverageOrderStorageItemPos({
    super.key,
    required this.checkDiscountItem,
    required this.formKey,
    required this.addMultiTopping,
    required this.item,
    required this.index,
    required this.itemExists,
    required this.removeItem,
    required this.updatePaid,
    required this.costType,
    required this.onMinusQuantity,
    required this.getPrice,
    required this.onChangeQuantity,
    required this.onIncreaseQuantity,
    required this.onChangePrice,
    required this.onChangeDiscountType,
    required this.setState,
    this.isLast = false,
    this.onVATChange,
    this.featuresConfig = const {},
    this.currentPolicy,
  });

  @override
  Widget build(BuildContext context) {
    return SingleTapDetector(
      onTap: () {
        showDetailItem(context);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "${index + 1}. ${item.name ?? ''} ${(featuresConfig['unit'] != true) ? "" : (item.product?.unit != "") ? "( ${item.product!.unit} )" : ""}",
                  maxLines: 2,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, overflow: TextOverflow.fade),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  vnd.format(getPrice()),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ),
              InkWell(
                onTap: () => removeItem(item),
                child: Icon(
                  Icons.delete_outline,
                  color: itemExists
                      ? Colors.grey
                      : ThemeColor.get(context).primaryAccent,
                ),
              ),
            ],
          ),
          6.verticalSpace,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: FadeInImage(
                    placeholder: AssetImage(getImageAsset('placeholder.png')),
                    fit: BoxFit.cover,
                    image: NetworkImage(getVariantFirstImage(item)),
                    imageErrorBuilder: (context, error, stackTrace) {
                      return Image.asset(
                        getImageAsset('placeholder.png'),
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                ),
              ),
              8.horizontalSpace,
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 110,
                      height: 40,
                      child: FormBuilderTextField(
                        key: item.priceKey,
                        name: '${item.id}.price',
                        controller: item.txtPrice,
                        onTapOutside: (value) {
                          FocusScope.of(context).unfocus();
                        },
                        onChanged: (value) {
                          onChangePrice(value);
                        },
                        onTap: () {
                          item.isUserTyping = true;
                        },
                        onEditingComplete: () {
                          item.isUserTyping = false;
                        },
                        textAlign: TextAlign.left,
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          CurrencyTextInputFormatter(
                            locale: 'vi',
                            symbol: '',
                          )
                        ],
                        decoration: InputDecoration(
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Container(
                        height: 35,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey[400]!,
                          ),
                          borderRadius: BorderRadius.all(
                            Radius.circular(10.0),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                                width: 30,
                                height: 35,
                                child: SingleTapDetector(
                                  onTap: () {
                                    onMinusQuantity();
                                  },
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: Icon(
                                      FontAwesomeIcons.minus,
                                      size: 15.0,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                )),
                            Container(
                              width: 50,
                              height: 35,
                              decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(10.0)),
                                  color: Colors.white),
                              child: FormBuilderTextField(
                                controller: item.txtQuantity,
                                key: item.quantityKey,
                                name: '${item.id}.quantity',
                                cursorColor: Colors.grey[400],
                                onTapOutside: (value) {
                                  FocusScope.of(context).unfocus();
                                },
                                onChanged: (value) {
                                  onChangeQuantity(value);
                                },
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.bold),
                                keyboardType: TextInputType.numberWithOptions(
                                    signed: true, decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d+\.?\d{0,3}'),
                                  ),
                                ],
                                maxLines: 1,
                                decoration: InputDecoration(
                                  contentPadding: EdgeInsets.only(bottom: 14),
                                  floatingLabelBehavior:
                                      FloatingLabelBehavior.never,
                                  hintText: '0',
                                  suffixText: '',
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            SizedBox(
                                width: 30,
                                height: 35,
                                child: SingleTapDetector(
                                  onTap: () {
                                    onIncreaseQuantity();
                                  },
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: Icon(
                                      FontAwesomeIcons.plus,
                                      size: 15.0,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (item.toppings.isNotEmpty) ...[
            6.verticalSpace,
            buildListTopping(context)
          ],
          if (item.productNotes != null && item.productNotes!.isNotEmpty) ...[
            buildListProductNote(context)
          ],
          4.verticalSpace,
          if (!isLast) Divider()
        ],
      ),
    );
  }

  Widget buildListProductNote(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ghi chú:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        ...item.productNotes!.map((note) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      '- ${note['name'] ?? ''}',
                      style: TextStyle(
                          overflow: TextOverflow.ellipsis,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ))
      ],
    );
  }

  Widget buildVAT(BuildContext context) {
    if (featuresConfig['vat'] != true) {
      return Container();
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'VAT',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(
          width: 150,
          height: 35,
          child: FormBuilderTextField(
            name: '${item.id}.vat',
            controller: item.txtVAT,
            readOnly: true,
            enabled: false,
            onTapOutside: (value) {
              FocusScope.of(context).unfocus();
            },
            key: item.vatKey,
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
                onVATChange!(value);
              }
            },
            decoration: InputDecoration(
              suffixText: '%',
            ),
          ),
        ),
      ],
    );
  }

  Widget buildProductNote(Function setDetailState) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ghi chú',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            InkWell(
              onTap: () {
                item.productNotes?.add({
                  'variant_id': item.id,
                  'name': '',
                  'price': 0,
                });
                setDetailState();
              },
              child: Row(
                children: [
                  Icon(
                    Icons.edit_note,
                    size: 15,
                    color: Colors.blue,
                  ),
                  Text('Thêm ghi chú',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ))
                ],
              ),
            ),
          ],
        ),
        if (item.productNotes != null && item.productNotes!.isNotEmpty)
          SizedBox(height: 15),
        ListView.builder(
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
                      onTapOutside: (event) {
                        FocusScope.of(context).unfocus();
                      },
                      decoration: InputDecoration(
                        labelText: 'Nhập ghi chú',
                        labelStyle: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                        hintText: 'Nhập nội dung ghi chú...',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.edit_note,
                          color: ThemeColor.get(context).primaryAccent,
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 15, horizontal: 15),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: ThemeColor.get(context).primaryAccent,
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.redAccent,
                            width: 1.5,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.redAccent,
                            width: 2,
                          ),
                        ),
                      ),
                      textInputAction: TextInputAction
                          .done, // Hiển thị nút "Done" trên bàn phím
                    )),
                    SizedBox(width: 10),
                    InkWell(
                      onTap: () {
                        item.productNotes?.removeAt(index);
                        setDetailState();
                      },
                      child: Icon(
                        Icons.delete_outline,
                        color: ThemeColor.get(context).primaryAccent,
                      ),
                    ),
                  ],
                ),
              );
            }),
      ],
    );
  }

  String getInitPrice() {
    if (currentPolicy == null) {
      final value = CostTypeExtension.getCost(item, costType);
      if (value == 0) {
        return '0';
      }
      return vnd.format(value);
    } else {
      final priceValue = (item.policies ?? [])
          .indexWhere((element) => element['policy_id'] == currentPolicy);
      if (priceValue == -1) {
        // Không tìm thấy policy phù hợp
        return "0";
      }
      final dynamic policyValue;
      if (item.policies != null) {
        policyValue = item.policies![priceValue]['policy_value'];
      } else {
        policyValue = null;
      }

      num price = 0;
      if (policyValue != null) {
        if (policyValue is String) {
          price = num.tryParse(policyValue.replaceAll('.', '')) ?? 0;
        } else if (policyValue is num) {
          price = policyValue;
        }
      }
      return vnd.format(price);
    }
  }

  Widget buildListTopping(context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Topping:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        ...item.toppings.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    '+ ${item.name} (x${roundQuantity(item.quantity)})',
                    style: TextStyle(
                        overflow: TextOverflow.ellipsis,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600]),
                  ),
                ),
              ],
            )))
      ],
    );
  }

  Widget buildTopping(Function setDetailState) {
    return Column(
      children: [
        SelectTopping(
          onSelect: (List<StorageItem>? topping) {
            addMultiTopping(topping, item);
            setDetailState();
          },
          selectedItems: item.toppings,
        ),
        SizedBox(height: 10),
        ...item.toppings.map((e) => Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 3,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.circle_rounded, size: 10, color: Colors.blue),
                      SizedBox(
                        width: 5,
                      ),
                      Flexible(
                        child: Text(
                          e.name ?? '',
                          style: TextStyle(
                              overflow: TextOverflow.ellipsis,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700]),
                        ),
                      ),
                    ]),
                  ),
                  Expanded(
                    flex: 2,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      InkWell(
                        onTap: () {
                          if (e.quantity > 1) {
                            e.quantity -= 1;
                          }
                          updatePaid();
                          setDetailState();
                        },
                        child: Icon(Icons.remove, size: 20, color: Colors.blue),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5.0),
                        child: Text(
                          'SL: ${roundQuantity(e.quantity)}',
                          style: TextStyle(
                              overflow: TextOverflow.ellipsis,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700]),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          e.quantity += 1;
                          updatePaid();
                          setDetailState();
                        },
                        child: Icon(Icons.add, size: 20, color: Colors.blue),
                      ),
                    ]),
                  ),
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            vndCurrency
                                .format((e.retailCost ?? 0) * e.quantity),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                overflow: TextOverflow.ellipsis,
                                color: Colors.grey[700]),
                          ),
                        ),
                        SizedBox(width: 10),
                        InkWell(
                          onTap: () {
                            item.toppings.remove(e);
                            updatePaid();
                            setDetailState();
                          },
                          child: Icon(Icons.delete_outline,
                              color: Colors.blue, size: 20),
                        )
                      ],
                    ),
                  )
                ],
              ),
            ))
      ],
    );
  }

  void showDetailItem(context) async {
    final initialQuantity = item.quantity;
    final initialPrice = item.retailCost;
    final initialDiscount = item.discount;
    final initialDiscountType = item.discountType;
    item.txtDiscount.text = item.discount != 0
        ? (item.discountType == DiscountType.price
            ? (item.quantity != 0
                ? vnd.format((item.discount ?? 0) / item.quantity)
                : '0')
            : roundQuantity(item.discount ?? 0))
        : '';
    final List<StorageItem> initialToppings = item.toppings
        .map((topping) => StorageItem.fromJson(topping.toJson()))
        .toList();
    final List<dynamic> initialProductNotes = item.productNotes != null
        ? item.productNotes!
            .map((note) => Map<String, dynamic>.from(note))
            .toList()
        : [];
    final initVat = item.product?.vat ?? 0;

    item.txtPrice.text = getInitPrice();
    final result = await showModalBottomSheet(
        isScrollControlled: true,
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            ScreenUtil.init(context);
            void onChangeDiscount(String? value) {
              item.discount = item.discountType == DiscountType.percent
                  ? (stringToDouble(value) ?? 0)
                  : (stringToInt(value) ?? 0) * item.quantity;
              updatePaid();
              checkDiscountItem(item);
              setState(() {});
            }

            final shortesSize = MediaQuery.of(context).size.shortestSide;
            return SafeArea(
              child: Container(
                color: Colors.white,
                height: MediaQuery.of(context).size.height,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 20),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                        Text(
                          item.name ?? '',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Divider(),
                    Expanded(
                        child: Padding(
                      padding: MediaQuery.of(context).viewInsets,
                      child: SingleChildScrollView(
                          child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 5),
                            child: Container(
                              height: 0.05.sw,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    width: 0.05.sw,
                                    height: 0.05.sw,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8.0),
                                      child: FadeInImage(
                                        placeholder: AssetImage(
                                            getImageAsset('placeholder.png')),
                                        fit: BoxFit.cover,
                                        image: NetworkImage(
                                            getVariantFirstImage(item)),
                                        imageErrorBuilder:
                                            (context, error, stackTrace) {
                                          return Image.asset(
                                            getImageAsset('placeholder.png'),
                                            fit: BoxFit.cover,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      height: 35,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey[400]!,
                                        ),
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(10.0),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          SizedBox(
                                              width: 30,
                                              height: 35,
                                              child: GestureDetector(
                                                onTap: () {
                                                  onMinusQuantity();
                                                  setState(() {});
                                                },
                                                child: Container(
                                                  alignment: Alignment.center,
                                                  child: Icon(
                                                    FontAwesomeIcons.minus,
                                                    size: 15.0,
                                                    color: Colors.grey[400],
                                                  ),
                                                ),
                                              )),
                                          Container(
                                            width: 50,
                                            height: 35,
                                            decoration: BoxDecoration(
                                                borderRadius: BorderRadius.all(
                                                    Radius.circular(10.0)),
                                                color: Colors.white),
                                            child: FormBuilderTextField(
                                              controller: item.txtQuantity,
                                              key: item.quantityKey,
                                              name: '${item.id}.quantity',
                                              cursorColor: Colors.grey[400],
                                              onTapOutside: (value) {
                                                FocusScope.of(context)
                                                    .unfocus();
                                              },
                                              onChanged: (value) {
                                                onChangeQuantity(value);
                                                setState(() {});
                                              },
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold),
                                              keyboardType: TextInputType
                                                  .numberWithOptions(
                                                      signed: true,
                                                      decimal: true),
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .allow(
                                                  RegExp(r'^\d+\.?\d{0,3}'),
                                                ),
                                              ],
                                              maxLines: 1,
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    EdgeInsets.only(bottom: 14),
                                                floatingLabelBehavior:
                                                    FloatingLabelBehavior.never,
                                                hintText: '0',
                                                suffixText: '',
                                                border: InputBorder.none,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                              width: 30,
                                              height: 35,
                                              child: GestureDetector(
                                                onTap: () {
                                                  onIncreaseQuantity();
                                                  setState(() {});
                                                },
                                                child: Container(
                                                  alignment: Alignment.center,
                                                  child: Icon(
                                                    FontAwesomeIcons.plus,
                                                    size: 15.0,
                                                    color: Colors.grey[400],
                                                  ),
                                                ),
                                              )),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 16),
                            child: Divider(color: Colors.grey[200]),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 16, right: 16, bottom: 16),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Đơn giá',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Container(
                                      width: 110,
                                      height: 40,
                                      child: FormBuilderTextField(
                                        key: item.priceKey,
                                        name: '${item.id}.price',
                                        controller: item.txtPrice,
                                        onTapOutside: (value) {
                                          FocusScope.of(context).unfocus();
                                        },
                                        onChanged: (value) {
                                          onChangePrice(value);
                                          setState(() {});
                                        },
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          CurrencyTextInputFormatter(
                                            locale: 'vi',
                                            symbol: '',
                                          )
                                        ],
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                          contentPadding:
                                              EdgeInsets.only(bottom: 10),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 5),
                                  child: Divider(color: Colors.grey[200]),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Chiết khấu',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(
                                        width: 150,
                                        height: 35,
                                        child: FormBuilderTextField(
                                          key: item.discountKey,
                                          textAlign: TextAlign.right,
                                          controller: item.txtDiscount,
                                          name: '${item.id}.discount',
                                          onChanged: (value) {
                                            onChangeDiscount(value);
                                          },
                                          onTapOutside: (value) {
                                            FocusScope.of(context).unfocus();
                                          },
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold),
                                          keyboardType: TextInputType.number,
                                          inputFormatters: item.discountType ==
                                                  DiscountType.percent
                                              ? [
                                                  FilteringTextInputFormatter
                                                      .allow(
                                                    RegExp(r'^\d+\.?\d{0,2}'),
                                                  ),
                                                ]
                                              : [
                                                  CurrencyTextInputFormatter(
                                                    locale: 'vi',
                                                    symbol: '',
                                                  )
                                                ],
                                          cursorColor: Colors.grey[400],
                                          decoration: InputDecoration(
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: BorderSide(
                                                  color: Colors.grey[400]!,
                                                  width: 1),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: BorderSide(
                                                  color: Colors.grey[400]!,
                                                  width: 1),
                                            ),
                                            suffixIcon:
                                                CupertinoSlidingSegmentedControl<
                                                    DiscountType>(
                                              thumbColor:
                                                  ThemeColor.get(context)
                                                      .primaryAccent,
                                              onValueChanged:
                                                  (DiscountType? value) {
                                                setState(() {
                                                  onChangeDiscountType(value);
                                                });
                                              },
                                              children: {
                                                DiscountType.percent: Container(
                                                  child: Text('%',
                                                      style: TextStyle(
                                                          // color: Colors.white
                                                          color: item.discountType ==
                                                                  DiscountType
                                                                      .percent
                                                              ? Colors.white
                                                              : Colors.black)),
                                                ),
                                                DiscountType.price: Container(
                                                  child: Text('đ',
                                                      style: TextStyle(
                                                          // color: Colors.white
                                                          color:
                                                              item.discountType ==
                                                                      DiscountType
                                                                          .price
                                                                  ? Colors.white
                                                                  : Colors
                                                                      .black)),
                                                )
                                              },
                                              groupValue: item.discountType,
                                            ),
                                            floatingLabelBehavior:
                                                FloatingLabelBehavior.never,
                                            hintText: '0',
                                            suffixText: item.discountType ==
                                                    DiscountType.percent
                                                ? ''
                                                : '',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (featuresConfig['vat'] == true &&
                                    item.product?.useVat != false) ...[
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 5),
                                    child: Divider(color: Colors.grey[200]),
                                  ),
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    child: buildVAT(context),
                                  ),
                                ],
                                if (featuresConfig['product_note'] == true) ...[
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 5),
                                    child: Divider(color: Colors.grey[200]),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    child: buildProductNote(() {
                                      setState(() {});
                                    }),
                                  ),
                                ],
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 5),
                                  child: Divider(color: Colors.grey[200]),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: buildTopping(() {
                                    setState(() {});
                                  }),
                                ),
                              ],
                            ),
                          )
                        ],
                      )),
                    )),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Divider(color: Colors.grey[200]),
                        SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Tổng tiền',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                vnd.format(getPrice()),
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: SizedBox(
                                width: shortesSize < 600 ? 1.sw - 32 : 0.3.sw,
                                child: TextButton(
                                    onPressed: () {
                                      for (var note in item.productNotes!) {
                                        if (note['name'].isEmpty) {
                                          CustomToast.showToastError(context,
                                              description:
                                                  "Ghi chú sản phẩm không được để trống");
                                          return;
                                        }
                                      }
                                      updatePaid();
                                      Navigator.pop(context, true);
                                    },
                                    style: TextButton.styleFrom(
                                      backgroundColor:
                                          ThemeColor.get(context).primaryAccent,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Text("Lưu")),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            );
          });
        });
    if (result != true) {
      item.quantity = initialQuantity;
      item.retailCost = initialPrice;
      item.discount = initialDiscount;
      item.discountType = initialDiscountType;
      item.txtQuantity.text = roundQuantity(initialQuantity);
      item.txtPrice.text = getInitPrice();
      item.toppings = initialToppings;
      item.productNotes = initialProductNotes;
      item.product?.vat = initVat;
      item.txtVAT.text = item.product != null && item.product?.vat != null
          ? roundQuantity(item.product?.vat ?? 0)
          : '0';
      updatePaid();
    }
  }
}
