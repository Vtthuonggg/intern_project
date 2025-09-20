import 'dart:convert';
import 'dart:developer';

import 'package:collection/collection.dart';
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_app/app/models/customer.dart';
import 'package:flutter_app/app/models/printer.dart';
import 'package:flutter_app/app/models/product.dart';
import 'package:flutter_app/app/models/storage_item.dart';
import 'package:flutter_app/app/models/user.dart';
import 'package:flutter_app/app/networking/customer_api_service.dart';
import 'package:flutter_app/app/networking/order_api_service.dart';
import 'package:flutter_app/app/networking/post_ingredients_api.dart';
import 'package:flutter_app/app/networking/product_api_service.dart';
import 'package:flutter_app/app/networking/room_api_service.dart';
import 'package:flutter_app/app/services/usb_printer_service.dart';
import 'package:flutter_app/app/utils/formatters.dart';
import 'package:flutter_app/app/utils/getters.dart';
import 'package:flutter_app/app/utils/message.dart';
import 'package:flutter_app/app/utils/printter.dart';
import 'package:flutter_app/app/utils/socket_manager.dart';
import 'package:flutter_app/app/utils/text.dart';
import 'package:flutter_app/bootstrap/helpers.dart';
import 'package:flutter_app/resources/dashed_divider.dart';
import 'package:flutter_app/resources/pages/add_storage_page.dart';
import 'package:flutter_app/resources/pages/customer/customer_search.dart';
import 'package:flutter_app/resources/pages/customer/customer_search_order.dart';
import 'package:flutter_app/resources/pages/manage_table/config_fee/list_ingredients.dart';
import 'package:flutter_app/resources/pages/order/list_order_page.dart';
import 'package:flutter_app/resources/pages/order_invoice_page.dart';
import 'package:flutter_app/resources/pages/product/edit_product_page.dart';
import 'package:flutter_app/resources/pages/setting/setting_order_sale_page.dart';
import 'package:flutter_app/resources/widgets/breadcrumb.dart';
import 'package:flutter_app/resources/widgets/manage_table/select_topping.dart';
import 'package:flutter_app/resources/widgets/product_scan.dart';
import 'package:flutter_app/resources/widgets/quantity_form_field.dart';
import 'package:flutter_app/resources/widgets/single_tap_detector.dart';
import 'package:flutter_app/resources/widgets/manage_table/table_item.dart';
import 'package:flutter_app/resources/widgets/manage_table/select_multi_variant.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:intl/intl.dart';
import 'package:nylo_framework/nylo_framework.dart';
import 'package:thermal_printer/esc_pos_utils_platform/src/capability_profile.dart';
import 'package:thermal_printer/esc_pos_utils_platform/src/enums.dart';
import 'package:thermal_printer/esc_pos_utils_platform/src/generator.dart';
import 'package:thermal_printer/thermal_printer.dart';
import '../../widgets/order_storage_item.dart';
import '/app/controllers/controller.dart';
import 'package:flutter_app/resources/pages/custom_toast.dart';
import 'package:image/image.dart' as img;

class TableReservationPage extends NyStatefulWidget {
  final Controller controller = Controller();

  static const path = '/table-reservation';

  TableReservationPage({Key? key}) : super(key: key);

  @override
  _TableReservationPageState createState() => _TableReservationPageState();
}

class _TableReservationPageState extends NyState<TableReservationPage> {
  final discountController = TextEditingController();
  final vatController = TextEditingController();
  bool _toastShown = false;

  SocketManager _socketManager = SocketManager();

  final selectMultiKey = GlobalKey<DropdownSearchState<StorageItem>>();
  int? orderId;
  bool _isShowingScan = false;
  String? _scanError;
  DiscountType _discountType = DiscountType.percent;
  int? selectedCustomerId;
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

  Map<int, num> variantToCurrentBaseCost = {}; // current base cost of variant

  bool isWholesale = false;
  Future<dynamic> _roomDetailFuture = Future.value(null);
  int orderIdIngre = 0;
  List<Map<String, dynamic>> selecteDishes = [];
  Map<String, bool> featuresConfig = {};
  PrinterModel? selectedPrinter;
  PrinterModel? savedPrinter;
  BTStatus _currentBluetoothStatus = BTStatus.none;
  List<int>? pendingTask;
  var printerManager = PrinterManager.instance;
  int invoiceId = 0;
  List<dynamic> otherFee = [];
  List<dynamic> cloneOtherFee = [];
  num getOtherFee = 0;
  bool isReload = true;
  List<dynamic> initProductNotes = [];
  final selectMultiKeyCustomer = GlobalKey<DropdownSearchState<Customer>>();
  Customer? selectedCustomer;
  final GlobalKey<CustomerSearchOrderState> _multiSelectKeyCustomer =
      GlobalKey<CustomerSearchOrderState>();
  bool _usbReady = false;

  List<int>? _cachedPrintBytes;
  static const _usbTimeout = Duration(seconds: 5);
  CapabilityProfile? _profile;
  Uint8List imageHtmlContent = Uint8List(0);
  String imageBase64Decode = '';
  bool get isConnectedPrinterUsb => usbReady.value;
  final usbReady = ValueNotifier<bool>(false);
  final _usbService = UsbPrinterService();
  List<Map<String, dynamic>> itemId = [];
  IngredientApi apiIngre = IngredientApi();

  @override
  init() async {
    super.init();
    initPrinter();
    getSelectedInvoiceId();
    final config = await getOrderSaleConfig();

    final _savedPrinter = await getFirstPrinterOrAdd(context);
    setState(() {
      selectedPrinter = _savedPrinter;
      featuresConfig = config;
    });
    _roomDetailFuture =
        api<RoomApiService>((request) => request.fetchRoom(int.parse(roomId)));
    if (isEditing) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _patchEditData(context));
    } else {
      orderId = await _roomDetailFuture.then((value) => value['order']?['id']);
      _formKey.currentState!.patchValue({
        'note': note,
      });
    }
  }

  Future<void> _bootstrap() async {
    try {
      if (mounted) setState(() {});
      await Future.wait([
        _setupUsb(),
        if (_usbReady == true) _autoConnectSavedPrinter(),
      ]);
    } catch (e, st) {
      CustomToast.showToastError(context, description: e.toString());
    } finally {
      setState(() {});
    }
  }

  Future<void> _prepare() async {
    _profile ??= await CapabilityProfile.load(name: 'default');

    final paperWidthPx =
        selectedPrinter?.paperSize == PaperSize.mm58 ? 384 : 576;

    final processed = await compute(
        resizeIsolate,
        ResizeParams(
          base64Decode(imageBase64Decode),
          paperWidthPx,
        ));

    final gen = Generator(PaperSize.mm58, _profile!);
    final image = img.decodeImage(processed)!;
    _cachedPrintBytes = [
      ...gen.imageRaster(image, align: PosAlign.left),
      ...gen.cut(),
    ];
    // CustomToast.showToastSuccess(context,
    //     description: _cachedPrintBytes.toString());
  }

  Future<void> _autoConnectSavedPrinter() async {
    final sp = await getFirstPrinterOrAdd(context);
    selectedPrinter = sp;

    if (sp == null) return;

    switch (sp.typePrinter) {
      case PrinterType.bluetooth:
        await _connectBluetooth(sp);
        break;
      case PrinterType.network:
        await _connectTcp(sp);
        break;
      default:
        break;
    }
  }

  Future<void> _connectBluetooth(PrinterModel p) async {
    await printerManager.connect(
      type: PrinterType.bluetooth,
      model: BluetoothPrinterInput(
        name: p.deviceName,
        address: p.address!,
        isBle: p.isBle ?? false,
        autoConnect: false,
      ),
    );
  }

  Future<void> _connectTcp(PrinterModel p) async {
    await printerManager.connect(
      type: PrinterType.network,
      model: TcpPrinterInput(ipAddress: p.address!),
    );
  }

  Future<void> _setupUsb() async {
    try {
      await _usbService.scanUsb().timeout(_usbTimeout,
          onTimeout: () => throw Exception('USB scan timeout'));

      await _usbService.connectUsb().timeout(_usbTimeout,
          onTimeout: () => throw Exception('USB connect timeout'));

      usbReady.value = true;
      _usbReady = true;
      CustomToast.showToastSuccess(context, description: 'USB sẵn sàng');
    } catch (e) {
      usbReady.value = false;
      _usbReady = false;
    }
  }

  Future<void> _getInvoiceImage() async {
    try {
      Map<String, dynamic> data = {'order_id': orderId, 'variant': itemId};
      var response = await apiIngre.postIngredients(data);
      imageHtmlContent = base64Decode(response["base64"]
          .toString()
          .replaceAll("data:image/png;base64,", ""));
      if (_usbReady == true) {
        imageBase64Decode = response['base64'].toString().split(',').last;
      }
    } catch (e) {
      CustomToast.showToastError(context, description: e.toString());
    }
  }

  Future printUsb() async {
    if (selecteDishes.isEmpty) {
      CustomToast.showToastError(context, description: 'Vui lòng chọn món');
      return;
    }
    await _getInvoiceImage();
    await _prepare();
    // for (var item in selecteDishes) {
    //   listIngredients.removeWhere((e) => e['id'] == item['id']);
    // }
    if (!_usbReady) {
      CustomToast.showToastError(context, description: 'USB chưa sẵn sàng');
      return;
    }
    if (_cachedPrintBytes == null) {
      CustomToast.showToastError(context,
          description: 'Chưa chuẩn bị dữ liệu in xong vui lòng thử lại');
      return;
    }
    try {
      await _usbService.printUsb(_cachedPrintBytes!);
      CustomToast.showToastSuccess(context,
          description: 'Báo chế biến thành công');
      Navigator.of(context)
        ..pop()
        ..pop();
    } catch (e) {
      CustomToast.showToastError(context, description: e.toString());
    } finally {
      setState(() {});
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
    setState(() {
      _isLoading = true;
    });
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
    _formKey.currentState!.patchValue({
      'note': note,
      'date_time': dateTime,
      'number_customer': editData['number_customer'],
      'time_intend': editData['time_intend'],
      'status_order': 1,
      'vat': (editData['vat'] != null && editData['vat'] != 0)
          ? editData['vat'].toString()
          : '0',
      'discount': editData['discount'] != null && editData['discount'] != 0
          ? (_discountType == DiscountType.price
              ? vnd.format(editData['discount'])
              : editData['discount'].toString())
          : '',
      'payment_type':
          (editData['order_payment'] as List<dynamic>).firstOrNull['type'],
      'paid': vnd.format((editData['order_payment'] as List<dynamic>)
              .map((e) => e['price'])
              .reduce((value, element) => value + element) ??
          0),
      'address': editData['address'],
      'other_fee': vnd.format(getOtherFee),
      'create_date': editData['created_at'] != null
          ? DateTime.parse(editData['created_at']).toLocal()
          : null,
    });
    if (widget.data()['customer_id'] != null) {
      selectedCustomerId = editData['customer_id'];
      var customer = await getCustomerWithId(widget.data()?['customer_id']);
      selectedCustomer = customer;
    }
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
      } else {
        selectItem.wholesaleCost = item['wholesale_cost'];
        // selectItem.baseCost = item['base_cost'];
        selectItem.retailCost = item['user_cost'];
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
      selectItem.txtQuantity.text = item['quantity'].toString();
    }
    setState(() {
      _isLoading = false;
    });
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

  initPrinter() {
    PrinterManager.instance.stateBluetooth.listen((status) {
      _currentBluetoothStatus = status;
      if (status == BTStatus.connected && pendingTask != null) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          PrinterManager.instance
              .send(type: PrinterType.bluetooth, bytes: pendingTask!);
          pendingTask = null;
        });
      }
    });
  }

  clearAllData() {
    _formKey.currentState!.patchValue({
      'note': '',
      'status_order': 1,
      'discount': "0",
      'payment_type': 1,
      'paid': '',
      'address': '',
      'number_customer': 1,
      'time_intend': 60,
      'create_date': null,
      'vat': '0',
    });
    getOtherFee = 0;
    selectedCustomerId = null;
    _discountType = DiscountType.percent;
    selectedCustomer = null;
    // for(var item in selectedItems) {
    //   _formKey.currentState?.fields['${item.id}.quantity']?.reset();
    //   _formKey.currentState?.fields['${item.id}.price']?.reset();
    //   _formKey.currentState?.fields['${item.id}.discount']?.reset();
    // }
    selectedItems = [];
    setState(() {});
  }

  @override
  void dispose() {
    // if (selectedPrinter != null) {
    //   printerManager.disconnect(type: selectedPrinter!.typePrinter!);
    // }
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

  void addItem(StorageItem item, num? weight) {
    // var index = selectedItems.indexWhere((element) => element.id == item.id);
    // if (index == -1) {
    //   setState(() {
    //     selectedItems.add(item);
    //     variantToCurrentBaseCost[item.id!] =
    //         (isWholesale ? item.wholesaleCost : item.retailCost) ?? 0;
    //   });
    // } else {
    //   setState(() {
    //     selectedItems[index].quantity += 1;
    //     _formKey.currentState!.patchValue({
    //       '${item.id}.quantity': '${selectedItems[index].quantity}',
    //     });
    //   });
    // }
    // updatePaid();

    final isImeiProduct = item.product?.isImei == true;

    var index = selectedItems.indexWhere((element) => element.id == item.id);
    if (index == -1) {
      selectedItems.add(item);
      item.quantity = weight == null ? 1 : weight / 1000;
      variantToCurrentBaseCost[item.id!] =
          (isWholesale ? item.wholesaleCost : item.retailCost) ?? 0;
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

    updatePaid();
    setState(() {});
  }

  void addMultiItems(List<StorageItem> items) {
    if (items.isEmpty) {
      for (var i in selectedItems) {
        removeItem(i);
      }
      return;
    }
    for (var item in items) {
      if (selectedItems.indexWhere((element) => element.id == item.id) == -1) {
        setState(() {
          selectedItems.insert(0, item);

          variantToCurrentBaseCost[item.id!] =
              (isWholesale ? item.wholesaleCost : item.retailCost) ?? 0;
        });
      } else {
        for (var i in selectedItems) {
          if (items.firstWhereOrNull((element) => element.id == i.id) == null) {
            removeItem(i);
          } else {
            setState(() {
              _formKey.currentState!.patchValue({
                '${i.id}.quantity': '${i.quantity}',
              });
            });
          }
        }
      }
    }
    updatePaid();
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
    _formKey.currentState
        ?.patchValue({'${item.id}.quantity': '${item.quantity}'});
    _formKey.currentState?.patchValue({
      '${item.id}.price':
          vnd.format(isWholesale ? item.copyWholesaleCost : item.copyRetailCost)
    });
    _formKey.currentState?.patchValue({
      '${item.id}.discount': item.discountType == DiscountType.price
          ? vnd.format((item.copyDiscount ?? 0) / item.quantity)
          : roundQuantity(item.copyDiscount ?? 0)
    });
    setState(() {
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
    num finalPrice = getFinalPrice();
    _formKey.currentState!.patchValue({
      'paid': vnd.format(roundMoney(finalPrice)),
    });
  }

  Future<List<StorageItem>> _fetchVariantItems(String search) async {
    try {
      final items = await api<ProductApiService>(
          (request) => request.listVariant(search));

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

  Future submit(TableStatus roomType,
      {bool isPay = false, bool isIngredient = false}) async {
    final isReservation = roomType == TableStatus.preOrder;
    if (!isReservation) {
      if (selectedItems.isEmpty) {
        CustomToast.showToastError(context, description: "Vui lòng chọn món");
        return;
      }
    }
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
      await updateOrder(roomType);
    } else {
      await saveOrder(roomType, isPay: isPay, isIngredient: isIngredient);
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
    filterNewFee();
    Map<String, dynamic> orderPayload =
        getOrderPayloadEditFromForm(currentRoomType);
    orderPayload['discount_type'] = _discountType.getValueRequest();
    orderPayload["status_order"] = 4;
    orderPayload["room_type"] = TableStatus.free.toValue();
    orderPayload["service_fee"] = 0;

    try {
      await api<OrderApiService>(
          (request) => request.updateTableReservation(orderId!, orderPayload));

      CustomToast.showToastSuccess(context,
          description: 'Thanh toán thành công');
      _socketManager.sendEvent('user', {'user_id': Auth.user<User>()!.id});

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
      orderIdIngre = await res['id'];
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
          'count_item': selectedItems.length,
        });
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

  Future _submitIngredients(
      List<Map<String, dynamic>> selectedDishes, int orderId) async {
    IngredientApi apiIngre = IngredientApi();

    setState(() {
      _isLoading = true;
    });
    Map<String, dynamic> data = {
      'order_id': orderId,
      'variant': selectedDishes,
    };
    if (selectedDishes.isEmpty) {
      CustomToast.showToastError(context, description: 'Vui lòng chọn món');
      setState(() {
        _isLoading = false;
      });
      return;
    } else {
      if (mounted) {
        try {
          var response = await apiIngre.postIngredients(data);

          CustomToast.showToastSuccess(context,
              description: 'Báo chế biến thành công');
          var imageHtmlContent = base64Decode(response["base64"]
              .toString()
              .replaceAll("data:image/png;base64,", ""));
          if (selectedPrinter != Null) {
            List<int> bytesPrinterCmdPre = [];
            if (selectedPrinter!.commandType == 'esc') {
              bytesPrinterCmdPre = await genEscCommand(imageHtmlContent,
                  paperSize: selectedPrinter!.paperSize!);
            } else {
              bytesPrinterCmdPre = await genTsplCommand(imageHtmlContent,
                  paperSize: selectedPrinter!.paperSize!);
            }
            await sendToPrinter(bytesPrinterCmdPre);
          }
        } catch (e) {
          print('Failed to post ingredients: $e');
        }
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  dynamic getOrderPayloadFromForm(TableStatus roomType, {bool isPay = false}) {
    DateTime? createDate = _formKey.currentState!.value['create_date'];

    DateTime dateTime = _formKey.currentState!.value['date_time'];
    final date = dateTime.toIso8601String().split('T')[0];
    final hour =
        dateTime.toIso8601String().split('T')[1].split('.')[0].substring(0, 5);
    Map<String, dynamic> orderPayload = {
      'type': 3,
      'room_id': roomId,
      'room_type': roomType.toValue(),
      'note': featuresConfig['note'] == true
          ? _formKey.currentState!.value['note']
          : widget.data()?['note'],
      'order_service_fee': featuresConfig['other_fee'] != true ? [] : otherFee,
      'is_retail': !isWholesale,
      'phone': selectedCustomer?.phone ?? '',
      'discount_type': _discountType.getValueRequest(),
      'name': selectedCustomer?.name ?? '',
      'customer_id': selectedCustomerId ?? null,
      'create_date': createDate != null
          ? DateFormat('yyyy/MM/dd HH:mm:ss').format(createDate)
          : null,
      'address': _formKey.currentState!.value['address'],
      'status_order': isPay ? 4 : 1,
      'discount': _discountType == DiscountType.percent
          ? stringToDouble(_formKey.currentState!.value['discount']) ?? 0
          : stringToInt(_formKey.currentState!.value['discount']) ?? 0,
      'vat': stringToDouble(_formKey.currentState!.value['vat']) ?? 0,
      'service_fee': 0,
      'number_customer': _formKey.currentState!.value['number_customer'] ?? 1,
      'time_intend': _formKey.currentState!.value['time_intend'] ?? 60,
      'date': date,
      'hour': hour,
      'order_detail': selectedItems.map((item) {
        return {
          'product_id': item.product?.id ?? 0,
          'variant_id': item.id ?? 0,
          'quantity': item.quantity ?? 1,
          'discount': item.discount ?? '',
          'notes': item.productNotes,
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
      }).toList(),
      'payment': {
        "type": _formKey.currentState!.value['payment_type'],
        // if paid > final price, then set paid = final price
        "price": getPaid() > getFinalPrice() ? getFinalPrice() : getPaid(),
      }
    };
    return orderPayload;
  }

  dynamic getOrderPayloadEditFromForm(TableStatus roomType) {
    var lstOrder = editData['order_detail'] as List<dynamic>;
    List<Map<String, dynamic>> orderDetailRequest = [];
    for (Map<String, dynamic> order in lstOrder) {
      Map<String, dynamic> orderDetail = {
        'id': order['id'],
        'product_id': order['product']['id'] ?? 0,
        'create_date': order['create_date'],
        'variant_id': order['variant']['id'] ?? 0,
        'vat': order['product']['vat'] ?? 0,
        'notes': order['order_detail_note'] ?? [],
        'topping': order['topping'] ?? [],
      };
      var filterInSelected = selectedItems
          .firstWhereOrNull((element) => element.id == order['variant']['id']);
      if (filterInSelected != null) {
        orderDetail['is_delete'] = false;
        orderDetail['quantity'] = filterInSelected.quantity;
        orderDetail['discount'] = filterInSelected.discount ?? '';
        orderDetail['discount_type'] =
            filterInSelected.discountType.getValueRequest();
        orderDetail['price'] = isWholesale
            ? filterInSelected.wholesaleCost
            : filterInSelected.retailCost;
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
    final hour =
        dateTime.toIso8601String().split('T')[1].split('.')[0].substring(0, 5);
    DateTime? createDate = _formKey.currentState!.value['create_date'];

    Map<String, dynamic> orderPayload = {
      'type': 3, // 1: order, 2: storage
      'room_id': roomId,
      'order_service_fee': featuresConfig['other_fee'] != true ? [] : otherFee,
      'room_type': roomType.toValue(),
      'date': date,
      'hour': hour,
      'number_customer': _formKey.currentState!.value['number_customer'],
      'time_intend': _formKey.currentState!.value['time_intend'],
      'is_retail': !isWholesale,
      'discount_type': _discountType.getValueRequest(),
      'phone': selectedCustomer?.phone ?? '',
      'name': selectedCustomer?.name ?? '',
      'customer_id': selectedCustomerId ?? null,
      'address':
          _formKey.currentState!.value['address'] ?? widget.data()?['address'],
      'status_order': 1,
      'create_date': createDate != null
          ? DateFormat('yyyy/MM/dd HH:mm:ss').format(createDate)
          : null,
      'discount': _discountType == DiscountType.percent
          ? stringToDouble(_formKey.currentState!.value['discount']) ?? 0
          : stringToInt(_formKey.currentState!.value['discount']) ?? 0,
      'vat': stringToDouble(_formKey.currentState!.value['vat']) ?? 0,
      'service_fee': 0,
      'payment': {
        "type": _formKey.currentState!.value['payment_type'],
        // if paid > final price, then set paid = final price
        "price": getPaid() > getFinalPrice() ? getFinalPrice() : getPaid(),
      },
      'order_detail': orderDetailRequest,
      'note': _formKey.currentState!.value['note'],
    };
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
    dynamic retailCostValue = _formKey.currentState?.value['${item.id}.price'];
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
    total = total - discountPrice;
    var vat = item.product?.vat ?? 0;
    if (vat > 0) {
      total = total + total * vat / 100;
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
        ? stringToInt(_formKey.currentState?.value['discount']) ?? 0
        : stringToDouble(_formKey.currentState?.value['discount']) ?? 0;
    num discountPrice = _discountType == DiscountType.percent
        ? total * discountVal / 100
        : discountVal;
    total = total - discountPrice;

    // apply service fee
    // num serviceFee = stringToNum(_formKey.currentState?.value['service_fee']) ?? 0;
    //
    // total += serviceFee;

    // vat
    num vat = stringToDouble(_formKey.currentState?.value['vat']) ?? 0;
    total = total + total * vat / 100;

    return total + getOtherFee;
  }

  num getPaid() {
    return stringToInt(_formKey.currentState?.value['paid']) ?? 0;
  }

  num getDebt() {
    final paid = getPaid();
    if (paid == 0) {
      return getFinalPrice();
    }
    num debt = getFinalPrice() - paid;
    return roundMoney(debt);
  }

  resetItemPrice() {
    selectedItems.forEach((item) {
      _formKey.currentState!.patchValue({
        '${item.id}.price':
            vnd.format(isWholesale ? item.wholesaleCost : item.retailCost)
      });
    });
  }

  updateList(List<StorageItem> selectedItems, List<dynamic> itemQuantity) {
    List<Map<String, dynamic>> temp = [];
    if (itemQuantity.isNotEmpty) {
      for (var ingredient in selectedItems) {
        num quantity = ingredient.quantity;
        for (var item in itemQuantity) {
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
                                    addItem(product, stringToInt(weight));
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
                          if (Auth.user<User>()!.showWholeSale)
                            Expanded(
                              child: Row(
                                children: [
                                  Spacer(),
                                  Radio<int>(
                                    value: 1,
                                    groupValue: isWholesale ? 1 : 0,
                                    onChanged: (value) {
                                      setState(() {
                                        isWholesale = value == 1;
                                        resetItemPrice();
                                      });
                                      updatePaid();
                                    },
                                  ),
                                  Text(
                                    'Giá buôn',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                                // title: const ,
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
              SizedBox(height: 5),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: Colors.orange),
                  onPressed: currentRoomType == TableStatus.free
                      ? () async {
                          for (var item in selectedItems) {
                            for (var note in item.productNotes!) {
                              if (note['name'].isEmpty) {
                                CustomToast.showToastError(context,
                                    description:
                                        "Ghi chú sản phẩm không được để trống");
                                return;
                              }
                            }
                          }
                          for (var item in selectedItems) {
                            selecteDishes.add({
                              'id': item.id,
                              'quantity': item.quantity,
                              'notes': (item.productNotes != null &&
                                      item.productNotes!.isNotEmpty)
                                  ? item.productNotes
                                      ?.map((e) => e['name'])
                                      .toList()
                                  : []
                            });
                          }
                          await submit(TableStatus.using, isIngredient: true);
                          isConnectedPrinterUsb
                              ? printUsb()
                              : await _submitIngredients(
                                  selecteDishes, orderId!);
                          Navigator.pop(context);
                        }
                      : () async {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (BuildContext context) {
                              return Container(
                                height:
                                    MediaQuery.of(context).size.height * 0.85,
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.pop(context);
                                    setState(() {});
                                  },
                                  child: Container(
                                    color: Colors.transparent,
                                    child: GestureDetector(
                                      onTap: () {},
                                      child: ClipRRect(
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(20),
                                            topRight: Radius.circular(20),
                                          ),
                                          child: ListIngredients(
                                            orderId: orderId,
                                            selectedItems: updateList(
                                                selectedItems,
                                                editData != null
                                                    ? editData[
                                                        'order_ingredient']
                                                    : []),
                                            onBack: () {
                                              if (buttonType == 'reserve') {
                                                submit(TableStatus.preOrder);
                                              } else {
                                                submit(TableStatus.using);
                                              }
                                            },
                                          )),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        FontAwesomeIcons.utensils,
                        color: Colors.white,
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Text(
                        "Báo chế biến",
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  )),
              SizedBox(height: 20),
            ],
          ),
        ),
      )),
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
                        minimumSize: Size(80, 40)),
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
                              Text(
                                'Cập nhật',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          )),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                  child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          minimumSize: Size(80, 40),
                          backgroundColor: Colors.blue),
                      onPressed: _pay,
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    backgroundColor: Colors.green,
                    minimumSize: Size(80, 40)),
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
                          Text(
                            'Cập nhật',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      )),
          ),
          SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    backgroundColor: Colors.blue,
                    minimumSize: Size(80, 40)),
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
                          Text(
                            'Tạo đơn',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      )),
          ),
        ],
      );
    }

    return Row(
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
                  _showDialogOtherFee(context);
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
      ],
    );
  }

  void _handleCustomerSelected(Customer? customer) {
    selectedCustomer = customer;
    selectedCustomerId = customer?.id;
  }

  Widget buildCustomerDetail() {
    return Column(children: [
      buildInfoCustomer(),
      SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: FormBuilderDateTimePicker(
              format: DateFormat('dd/MM/yyyy HH:mm'),
              name: 'date_time',
              inputType: InputType.both,
              decoration: InputDecoration(
                labelText: 'Ngày đặt',
              ),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              initialValue: DateTime.now(),
            ),
          ),
        ],
      ),
      SizedBox(height: 12),
      if (featuresConfig['customer_quantity'] == true)
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
        )
    ]);
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
                                addItem(newItems.first, null);
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
            SizedBox(
              height: 40,
              width: 180,
              child: FormBuilderTextField(
                controller: vatController,
                name: 'vat',
                onChanged: (value) {
                  double? parsedValue = double.tryParse(value!);

                  if (parsedValue != null && parsedValue > 100) {
                    if (!_toastShown) {
                      CustomToast.showToastError(context,
                          description: "Thuế VAT không được lớn hơn 100%");
                      _toastShown = true;
                    }
                    Future.delayed(Duration(milliseconds: 100), () {
                      vatController.text = '100';
                      vatController.selection = TextSelection.fromPosition(
                          TextPosition(offset: vatController.text.length));
                    });
                    return;
                  }
                  if (mounted) {
                    setState(() {});
                    updatePaid();
                    _toastShown = false;
                  }
                },
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d+\.?\d{0,2}'),
                  ),
                ],
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
                  suffixText: '%',
                ),
              ),
            )
          ],
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
            // initialValue: '0',
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

  // summary
  Widget buildSummary() {
    return Column(
      children: [
        buildOrderDiscount(),
        buildOtherFee(),
        buildOrderVAT(),
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
                // initialValue: vndCurrency.format(getFinalPrice()),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                textAlign: TextAlign.right,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  // border: UnderlineInputBorder(),
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
            // Text(vndCurrency.format(getFinalPrice()),
            //     style: TextStyle(fontWeight: FontWeight.bold)),
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
        ])
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

  Widget buildItem(StorageItem item, int index) {
    bool itemExists = false;
    if (editData?['order_ingredient'] != null) {
      itemExists = editData['order_ingredient']
          .any((ingredient) => ingredient['variant_id'] == item.id);
    }

    return TableOrderStorageItem(
      setState: () {
        setState(() {});
      },
      featuresConfig: featuresConfig,
      item: item,
      index: index,
      itemExists: itemExists,
      removeItem: removeItem,
      updatePaid: updatePaid,
      costType: isWholesale ? CostType.wholesale : CostType.retail,
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
            final currentValue =
                _formKey.currentState?.value['${item.id}.discount'];
            item.discount = (stringToInt(currentValue) ?? 0) * item.quantity;
          }
          _formKey.currentState
              ?.patchValue({'${item.id}.quantity': '${item.quantity}'});
          setState(() {});
          if (newQuantity == newQuantity.floor()) {
            item.quantity = newQuantity.toInt();
          } else {
            item.quantity = newQuantity.toDouble();
          }

          _formKey.currentState
              ?.patchValue({'${item.id}.quantity': '${item.quantity}'});
          setState(() {});
        }
      },
      getPrice: () => getPrice(item),
      onChangeQuantity: (value) {
        num newQuantity = stringToDouble(value) ?? 0;
        num maxQuantity = item.temporality ?? 0;

        if (!isEditing &&
            item.isBuyAlways == false &&
            newQuantity > maxQuantity) {
          Future.microtask(() {
            _formKey.currentState?.patchValue(
                {'${item.id}.quantity': roundQuantity(maxQuantity)});

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
        checkDiscountItem(item);
        checkOnChange();
        setState(() {});
        updatePaid();
      },
      onIncreaseQuantity: () {
        String newQuantityStr = (item.quantity + 1).toStringAsFixed(3);
        num newQuantity = stringToDouble(newQuantityStr) ?? 0;
        if (!isEditing &&
            item.isBuyAlways == false &&
            newQuantity.toDouble() > (item.temporality ?? 0)) {
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
          final currentValue =
              _formKey.currentState?.value['${item.id}.discount'];
          item.discount = (stringToInt(currentValue) ?? 0) * item.quantity;
        }
        _formKey.currentState
            ?.patchValue({'${item.id}.quantity': '${item.quantity}'});
        setState(() {});
      },
      onChangePrice: (value) {
        if (isWholesale) {
          item.wholesaleCost = stringToInt(value) ?? 0;
        } else {
          item.retailCost = stringToInt(value) ?? 0;
        }
        if (item.discountType == DiscountType.price &&
            item.discount! > stringToInt(value)! * item.quantity) {
          _formKey.currentState?.patchValue({
            '${item.id}.discount': '0',
          });
        }
        updatePaid();
        checkDiscountItem(item);
        setState(() {});
      },
      onChangeDiscount: (value) {
        item.discount = item.discountType == DiscountType.percent
            ? (stringToDouble(value) ?? 0)
            : (stringToInt(value) ?? 0) * item.quantity;
        updatePaid();
        checkDiscountItem(item);
        setState(() {});
      },
      onChangeDiscountType: (value) {
        setState(() {
          final currentValue =
              _formKey.currentState?.value['${item.id}.discount'];

          if (currentValue == null || currentValue.isEmpty) {
            _formKey.currentState?.patchValue({'${item.id}.discount': ''});
          } else {
            if (value == DiscountType.percent) {
              double discount = stringToDouble(currentValue) ?? 0;
              if (discount > 100) {
                discount = 100;
              }
              _formKey.currentState?.patchValue({
                '${item.id}.discount': discount.toStringAsFixed(0),
              });
            } else {
              _formKey.currentState?.patchValue({
                '${item.id}.discount':
                    vnd.format(stringToInt(currentValue) ?? 0)
              });
            }
          }
          item.discountType = value ?? DiscountType.percent;
          item.discount = item.discountType == DiscountType.percent
              ? stringToDouble(currentValue) ?? 0
              : stringToInt(currentValue) ?? 0;
          if (item.discountType == DiscountType.percent &&
              stringToDouble(currentValue)! > 100) {
            _formKey.currentState?.patchValue({
              '${item.id}.discount': '100',
            });
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

  Future sendToPrinter(
    List<int> bytes,
  ) async {
    if (selectedPrinter == null) return;
    pendingTask = bytes;
    var printer = selectedPrinter!;

    // connect
    switch (printer.typePrinter) {
      case PrinterType.bluetooth:
        await printerManager.connect(
            type: PrinterType.bluetooth,
            model: BluetoothPrinterInput(
                name: printer.deviceName,
                address: printer.address!,
                isBle: printer.isBle ?? false,
                autoConnect: false));

        if (_currentBluetoothStatus == BTStatus.connected) {
          await Future.delayed(const Duration(milliseconds: 1000), () async {
            await printerManager.send(type: printer.typePrinter!, bytes: bytes);
            pendingTask = null;
            await printerManager.disconnect(type: printer.typePrinter!);
          });
        }
        break;
      case PrinterType.network:
        final connectedTCP = await printerManager.connect(
            type: PrinterType.network,
            model: TcpPrinterInput(ipAddress: printer.address!));
        if (!connectedTCP)
          CustomToast.showToastError(context, description: "Lỗi kết nối");

        await Future.delayed(const Duration(milliseconds: 1000), () async {
          await printerManager.send(type: printer.typePrinter!, bytes: bytes);
          pendingTask = null;
          await printerManager.disconnect(type: printer.typePrinter!);
        });
        break;
      default:
        CustomToast.showToastError(context,
            description: "Loại máy in không hỗ trợ");
        return;
    }
  }

  void _showDialogOtherFee(BuildContext context) {
    List<TextEditingController> nameControllers = [];
    List<TextEditingController> priceControllers = [];

    for (var fee in cloneOtherFee) {
      nameControllers.add(TextEditingController(text: fee['name']));
      priceControllers
          .add(TextEditingController(text: vnd.format(fee['price'])));
    }
    if (cloneOtherFee.isEmpty) {
      cloneOtherFee.add({'name': '', 'price': 0});
      nameControllers.add(TextEditingController());
      priceControllers.add(TextEditingController());
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: ((context, setState) {
          return AlertDialog(
            title: Row(
              children: [
                Text('Chi phí khác'),
                Spacer(),
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
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 15),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: nameControllers[index],
                                    cursorColor:
                                        ThemeColor.get(context).primaryAccent,
                                    decoration: InputDecoration(
                                      labelText: 'Tên chi phí',
                                      labelStyle:
                                          TextStyle(color: Colors.grey[700]),
                                      floatingLabelBehavior:
                                          FloatingLabelBehavior.always,
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: ThemeColor.get(context)
                                              .primaryAccent,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
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
                                  ),
                                ),
                                SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      cloneOtherFee.removeAt(index);
                                      nameControllers.removeAt(index);
                                      priceControllers.removeAt(index);
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
    _formKey.currentState?.patchValue({'other_fee': vnd.format(totalOtherFee)});
    updatePaid();
  }
}

class TableOrderStorageItem extends StatelessWidget {
  final StorageItem item;
  final int index;
  final CostType costType;
  final bool itemExists;
  final Function updatePaid;
  final Function(StorageItem) removeItem;
  final Function(List<StorageItem>?, StorageItem item) addMultiTopping;
  final Function() onMinusQuantity;
  final Function() getPrice;
  final Function(String?) onChangeQuantity;
  final Function() onIncreaseQuantity;
  final Function(String?) onChangePrice;
  final Function(String?) onChangeDiscount;
  final Function(DiscountType?) onChangeDiscountType;

  final Function() setState;
  Map<String, bool> featuresConfig = {};

  TableOrderStorageItem({
    super.key,
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
    required this.onChangeDiscount,
    required this.onChangeDiscountType,
    required this.setState,
    this.featuresConfig = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 4),
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
                            onMinusQuantity();
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
                      width: 50,
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
                        // validator: FormBuilderValidators.compose([
                        //   FormBuilderValidators.numeric(),
                        //   FormBuilderValidators.min(0.001),
                        // ]),
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
                            onIncreaseQuantity();
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
                  // controller: item.txtPrice,
                  key: item.priceKey,
                  name: '${item.id}.price',
                  initialValue: getInitPrice(),
                  onTapOutside: (value) {
                    FocusScope.of(context).unfocus();
                  },
                  onChanged: (value) {
                    onChangePrice(value);
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
                            ? (item.discountType == DiscountType.price
                                ? vnd.format(
                                    (item.discount ?? 0) / item.quantity)
                                : roundQuantity(item.discount ?? 0))
                            : '',
                        name: '${item.id}.discount',
                        onChanged: (value) {
                          onChangeDiscount(value);
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
                              onChangeDiscountType(value);
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
          if (featuresConfig['product_note'] == true) buildProductNote(),
          buildTopping(),
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
                      text: '${vndCurrency.format(getPrice())}',
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

  Widget buildProductNote() {
    return Column(
      children: [
        SizedBox(height: 12),
        InkWell(
          onTap: () {
            item.productNotes?.add({
              'variant_id': item.id,
              'name': '',
              'price': 0,
            });
            setState();
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
                    InkWell(
                      onTap: () {
                        item.productNotes?.removeAt(index);
                        setState();
                      },
                      child: Icon(
                        Icons.delete_outline,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              );
            }),
        DashedDivider()
      ],
    );
  }

  String getInitPrice() {
    final value = CostTypeExtension.getCost(item, costType);
    if (value == 0) {
      return '0';
    }
    return vnd.format(value);
  }

  Widget buildTopping() {
    return Column(
      children: [
        SelectTopping(
          onSelect: (List<StorageItem>? topping) {
            addMultiTopping(topping, item);
          },
          selectedItems: item.toppings,
        ),
        if (item.toppings.isNotEmpty)
          ...item.toppings.map((e) => Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.circle_rounded, size: 10, color: Colors.blue),
                      SizedBox(
                        width: 5,
                      ),
                      Text(
                        e.name ?? '',
                        style: TextStyle(
                            overflow: TextOverflow.ellipsis,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700]),
                      ),
                    ]),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      InkWell(
                        onTap: () {
                          if (e.quantity > 1) {
                            e.quantity -= 1;
                          }
                          updatePaid();
                          setState();
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
                          setState();
                        },
                        child: Icon(Icons.add, size: 20, color: Colors.blue),
                      ),
                    ]),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          vndCurrency.format((e.retailCost ?? 0) * e.quantity),
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700]),
                        ),
                        SizedBox(width: 10),
                        InkWell(
                          onTap: () {
                            item.toppings.remove(e);
                            updatePaid();
                          },
                          child: Icon(Icons.delete_outline,
                              color: Colors.blue, size: 20),
                        )
                      ],
                    )
                  ],
                ),
              ))
      ],
    );
  }
}
