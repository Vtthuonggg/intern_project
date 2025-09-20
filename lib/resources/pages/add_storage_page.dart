import 'dart:io';

import 'package:collection/collection.dart';
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/app/models/product.dart';
import 'package:flutter_app/app/models/storage_item.dart';
import 'package:flutter_app/app/models/user.dart';
import 'package:flutter_app/app/networking/order_api_service.dart';
import 'package:flutter_app/app/networking/product_api_service.dart';
import 'package:flutter_app/app/networking/upload_api_service.dart';
import 'package:flutter_app/app/utils/formatters.dart';
import 'package:flutter_app/app/utils/getters.dart';
import 'package:flutter_app/app/utils/message.dart';
import 'package:flutter_app/bootstrap/helpers.dart';
import 'package:flutter_app/resources/pages/custom_toast.dart';
import 'package:flutter_app/resources/pages/order_list_all_page.dart';
import 'package:flutter_app/resources/pages/product/edit_product_page.dart';
import 'package:flutter_app/resources/widgets/order_storage_item.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:nylo_framework/nylo_framework.dart';
import '../widgets/select_multi_variant.dart';
import '/app/controllers/controller.dart';

class AddStoragePage extends NyStatefulWidget {
  final Controller controller = Controller();

  static const path = '/add-storage';

  AddStoragePage({Key? key}) : super(key: key);

  @override
  _AddStoragePageState createState() => _AddStoragePageState();
}

class _AddStoragePageState extends NyState<AddStoragePage> {
  String? _scanError;
  final discountController = TextEditingController();
  final vatController = TextEditingController();
  final GlobalKey<FormBuilderState> _formKey = GlobalKey<FormBuilderState>();
  final selectMultiKey = GlobalKey<DropdownSearchState<StorageItem>>();
  final TextEditingController _confirmPaidController = TextEditingController();
  ImagePicker imagePicker = ImagePicker();
  List<StorageItem> selectedItems = [];
  bool _toastShown = false;
  bool isExpan = false;
  bool _isLoading = false;
  DiscountType _discountType = DiscountType.percent;

  Map<int, num> variantToCurrentBaseCost = {}; // current base cost of variant

  final SuggestionsBoxController _suggestionsBoxController =
      SuggestionsBoxController();

  bool get isEditing => widget.data() != null;
  bool get isClone => widget.data()['is_clone'] == true;
  int? orderId;
  int invoiceId = 0;
  List<dynamic> otherFee = [];
  List<dynamic> cloneOtherFee = [];
  num getOtherFee = 0;
  num paidPrice = 0;
  int variantBatchId = 0;
  TextEditingController _noteController = TextEditingController();
  List<CroppedFile> images = [];
  List<dynamic> listPolicies = [];
  int? currentPolicy;
  bool changedPriceValue = false;
  int? initStatusStorageValue;
  List<dynamic> saveChangeProductPrice = [];
  List<dynamic> otherFeeList = [];
  final SlidableController slidableController = SlidableController();

  List<String> savedImages = [];
  int? filterProductType() {
    CareerType type = Auth.user<User>()!.careerType;

    switch (type) {
      case CareerType.other:
        return null;
      default:
        return 1;
    }
  }

  @override
  init() async {
    super.init();

    if (!isEditing) {
      await getStatusStorage();
    }
    if (isEditing) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _patchEditData(context));
    }
    discountController.addListener(() {
      checkDiscountOrder();
      setState(() {});
    });
    await _fetchListFee();
  }

  Future getStatusStorage() async {
    setState(() {});
    try {
      var res =
          await api<OrderApiService>((request) => request.getDefaultStatus(2));
      initStatusStorageValue = res['status_order'];
      _formKey.currentState?.patchValue({
        'status_order': initStatusStorageValue,
      });
      setState(() {});
    } catch (e) {
      CustomToast.showToastError(context, description: getResponseError(e));
    }
  }

  Future _fetchListFee() async {
    try {
      final response =
          await api<OrderApiService>((request) => request.getListFee());
      otherFeeList = response;
      setState(() {});
    } catch (e) {
      CustomToast.showToastError(context, description: "Có lỗi xảy ra");
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
      CustomToast.showToastError(context, description: "Có lỗi xảy ra");
    }
  }

  Future<void> _patchEditData(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });
    if (listPolicies.isNotEmpty) {
      currentPolicy = widget.data()['policy_id'];
      _formKey.currentState?.patchValue({
        'policy_id': currentPolicy,
      });
    }

    selectedItems = [];
    _discountType = DiscountType.values.firstWhereOrNull((element) =>
            element.getValueRequest() == widget.data()['discount_type']) ??
        DiscountType.percent;
    getOtherFee = 0;
    if (widget.data()['order_service_fee'] != null) {
      for (var item in widget.data()['order_service_fee']) {
        getOtherFee += item['price'];
      }
    }
    otherFee = (widget.data()['order_service_fee'] ?? []).map((fee) {
      return {
        'id': fee['id'],
        'name': fee['name'],
        'price': fee['price'],
      };
    }).toList();
    cloneOtherFee = [...otherFee];
    _formKey.currentState!.patchValue({
      'status_order': isEditing
          ? widget.data()['status_order']
          : (isClone ? widget.data()['status_order'] : initStatusStorageValue),
      'discount': widget.data()['discount'] != 0
          ? (_discountType == DiscountType.price
              ? vnd.format(widget.data()['discount'])
              : widget.data()['discount'].toString())
          : '',
      'payment_type':
          (widget.data()['order_payment'] as List<dynamic>).firstOrNull['type'],
      'paid': vnd.format((widget.data()['order_payment'] as List<dynamic>)
          .map((e) => e['price'])
          .reduce((value, element) => value + element)),
      'vat': (widget.data()['vat'] != null && widget.data()['vat'] != 0)
          ? widget.data()['vat'].toString()
          : '',
      'other_fee': vnd.format(getOtherFee),
      'create_date': widget.data()['created_at'] != null
          ? DateTime.parse(widget.data()['created_at']).toLocal()
          : null,
    });
    paidPrice = (widget.data()['order_payment'] as List<dynamic>)
        .map((e) => e['price'])
        .reduce((value, element) => value + element);
    _formKey.currentState!.patchValue({
      'paid': vnd.format((widget.data()['order_payment'] as List<dynamic>)
          .map((e) => e['price'])
          .reduce((value, element) => value + element))
    });
    _noteController.text = widget.data()['note'] ?? '';
    orderId = widget.data()?['id'];

    var lstOrder = widget.data()['order_detail'] as List<dynamic>;
    for (Map<String, dynamic> item in lstOrder) {
      var selectItem = StorageItem.fromJson(item['variant']);
      selectItem.product = Product.fromJson(item['product']);
      selectItem.quantity = item['quantity'];
      selectItem.discount = item['discount'];
      selectItem.wholesaleCost = item['wholesale_cost'];
      selectItem.subUnitQuantity = item['sub_unit_quantity'];
      selectItem.product?.vat = item['vat'];
      selectItem.txtVAT.text = roundQuantity(item['vat']);
      selectItem.txtPrice.text = vnd.format(item['variant']['base_cost'] ?? 0);
      final policy = selectItem.policies?.firstWhereOrNull(
        (element) => element['policy_id'] == currentPolicy,
      );
      if (policy != null && policy['policy_value'] != null) {
        selectItem.policyPrice = stringToInt(policy['policy_value'] ?? '0');
      } else {
        selectItem.policyPrice = 0;
      }
      if (stringToInt(selectItem.txtPrice.text) != selectItem.copyBaseCost &&
          stringToInt(selectItem.txtPrice.text) != selectItem.policyPrice) {
        selectItem.overriddenPrice = stringToInt(selectItem.txtPrice.text);
        selectItem.isManuallyEdited = true;
      }
      selectItem.selectedBatch =
          item['batch'].map((item) => Map<String, dynamic>.from(item)).toList();
      ;
      final listBathTemp = [];
      listBathTemp.addAll(item['variant']['batch']);

      for (var item in selectItem.batch!) {
        for (var batch in selectItem.selectedBatch!) {
          if (item['name'] == batch['name']) {
            item['hide'] = true;
          }
        }
      }
      selectItem.discountType = DiscountType.values.firstWhereOrNull(
              (element) =>
                  element.getValueRequest() == item['discount_type']) ??
          DiscountType.percent;
      selectItem.selectedImei = item['imei'] != null
          ? List<String>.from(item['imei'].map((x) => x['imei']))
          : [];
      if (isClone && selectItem.product != null) {
        if ((selectItem.product!.isBatch ?? false) ||
            (selectItem.product!.isImei ?? false)) {
          selectItem.selectedBatch = [];
          selectItem.selectedImei = [];
          selectItem.quantity = 0;
        }
      }
      selectedItems.add(selectItem);
      _formKey.currentState?.patchValue({
        '${selectItem.id}.quantity': item['quantity'].toString(),
        '${selectItem.id}.discount': vnd.format(item['discount']),
      });
    }
    // patch images
    List<String> images = [];
    try {
      images = List<String>.from(widget.data()['image_attach']);
    } catch (e) {
      images = [];
    }

    setState(() {
      savedImages = images;
      _isLoading = false;
    });
    updatePaid();
  }

  clearAllData() {
    _formKey.currentState!.patchValue({
      'status_order': 4,
      'discount': '',
      'payment_type': 1,
      'paid': '0',
      'name': '',
      'address': '',
      'vat': '',
      'create_date': null,
      'other_fee': '0',
      'policy_id': null,
    });
    currentPolicy = null;
    vatController.text = '';
    getOtherFee = 0;
    otherFee = [];
    cloneOtherFee = [];
    _discountType = DiscountType.percent;

    _noteController.text = '';
    for (var item in selectedItems) {
      item.quantity = item.product?.isImei ?? false ? 0 : 1;
      _formKey.currentState
          ?.patchValue({'${item.id}.quantity': '${item.quantity}'});
      _formKey.currentState
          ?.patchValue({'${item.id}.price': vnd.format(item.baseCost)});
      _formKey.currentState?.patchValue(
          {'${item.id}.discount': vnd.format(item.copyDiscount ?? 0)});
    }
    selectedItems = [];
    savedImages = [];
    images = [];
    updatePaid();
    setState(() {});
  }

  @override
  void dispose() {
    _confirmPaidController.dispose();
    _noteController.dispose();
    discountController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> pushBatch(int id, dynamic data) async {
    dynamic payload = {
      'id': id,
      'batch': data,
    };
    try {
      var res = await api<OrderApiService>(
          (request) => request.getBatchId(id, payload));
      return res;
    } catch (e) {
      return {};
    }
  }

  void checkDiscountItem(StorageItem item) {
    if (_isLoading) return;

    num currentPrice = item.baseCost ?? 0;
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

  void checkOnChange() {
    if (_isLoading) return;

    int discountOrder =
        stringToInt(_formKey.currentState?.value['discount']) ?? 0;
    if (_discountType == DiscountType.price &&
        discountOrder > getTotalPrice()) {
      _formKey.currentState
          ?.patchValue({'discount': vnd.format(getTotalPrice())});
    }
  }

  void addItem(StorageItem item) {
    item.discountType = DiscountType.price;
    item.discount = 0;
    var index = selectedItems.indexWhere((element) => element.id == item.id);
    if (index == -1) {
      setState(() {
        selectedItems.add(item);
        variantToCurrentBaseCost[item.id!] = item.baseCost ?? 0;
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
              price = item.copyBaseCost ?? 0;
            } else {
              price = item.policyPrice ?? 0;
            }
          }
        } else {
          price = item.copyBaseCost ?? 0;
        }
        item.txtPrice.text = vnd.format(price);
      });
    } else {
      setState(() {
        selectedItems[index].quantity += 1;
        _formKey.currentState!.patchValue({
          '${item.id}.quantity':
              '${roundQuantity(selectedItems[index].quantity)}',
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
          if (item.policyPrice == 0 && item.policyPrice != null) {
            price = item.copyBaseCost ?? 0;
          } else {
            price = item.policyPrice ?? 0;
          }
        } else {
          price = item.copyBaseCost ?? 0;
        }
      } else {
        price = item.copyBaseCost ?? 0;
      }

      if (selectedItems.indexWhere((element) => element.id == item.id) == -1) {
        setState(() {
          selectedItems.add(item);
          variantToCurrentBaseCost[item.id!] = item.copyBaseCost ?? 0;
        });
      } else {
        for (var i in selectedItems) {
          if (items.firstWhereOrNull((element) => element.id == i.id) == null) {
            removeItem(i);
          }
        }
        // removeItem(item);
      }

      item.txtPrice.text = vnd.format(price);
    }
    resetItemPrice();

    updatePaid();
  }

  bool isEditSuccessOrder() {
    return widget.data()?['status_order'] == 4 && !isClone;
  }

  void removeItem(StorageItem item) {
    item.quantity = item.product?.isImei ?? false
        ? 0
        : (item.product?.isBatch ?? false ? 0 : 1);
    item.subUnitQuantity = 0;
    _formKey.currentState?.patchValue({
      '${item.id}.sub_unit_quantity': '0',
    });
    _formKey.currentState
        ?.patchValue({'${item.id}.quantity': '${item.quantity}'});
    _formKey.currentState
        ?.patchValue({'${item.id}.price': vnd.format(item.copyBaseCost ?? 0)});
    _formKey.currentState?.patchValue({
      '${item.id}.discount': item.discountType == DiscountType.price
          ? vnd.format(0)
          : roundQuantity(0)
    });
    setState(() {
      item.discount = 0;
      item.discountType = DiscountType.price;
      selectedItems.remove(item);
    });
    updatePaid();
  }

  num getTotalQty(List<StorageItem> items) {
    num total = 0;
    for (var item in items) {
      total += item.quantity ?? 0;
    }
    return total;
  }

  void updatePaid() {
    //update vat
    num totalVat = 0;
    for (var item in selectedItems) {
      dynamic quantityValue = item.quantity.toString();
      num baseCost = item.baseCost ?? 0;

      num quantity = num.tryParse(quantityValue) ?? 0;
      num total = baseCost * quantity;
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

    if (isEditing && !isClone && !isEditSuccessOrder()) {
      setState(() {});
      return;
    }
    num finalPrice = getFinalPrice();
    paidPrice = finalPrice;
    _formKey.currentState!.patchValue({
      'paid': vnd.format(roundMoney(finalPrice)).isEmpty
          ? '0'
          : vnd.format(roundMoney(finalPrice))
    });
  }

  Future<List<StorageItem>> _fetchVariantItems(String search) async {
    try {
      final items = await api<ProductApiService>(
          (request) => request.listVariant(search));

      // remove items already selected
      return items
          .where((item) =>
              selectedItems.indexWhere((element) => element.id == item.id) ==
              -1)
          .toList();
    } catch (e) {
      String errorMessage = getResponseError(e);
      CustomToast.showToastError(context, description: errorMessage);
      return [];
    }
  }

  Future submit({bool isPaid = false}) async {
    if (_isLoading) {
      return;
    }
    if (selectedItems.isEmpty) {
      CustomToast.showToastError(context,
          description: "Vui lòng chọn sản phẩm");
      return;
    }

    if ((getPaid() - getFinalPrice()) > 50) {
      CustomToast.showToastError(context,
          description: "Số tiền đã trả không được lớn hơn số tiền phải trả");
      return;
    }

    if (!_formKey.currentState!.saveAndValidate()) {
      return;
    }
    filterNewFee(); //Lọc ra những phí mới thêm
    if (isEditing && !isClone) {
      await updateOrder(isPaid: isPaid);
    } else {
      await saveOrder();
    }
  }

  Future takePicture() async {
    XFile? file = await imagePicker.pickImage(source: ImageSource.camera);

    if (file != null) {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: file.path,
        aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
      );
      if (croppedFile != null) {
        setState(() {
          images = [...images, croppedFile];
        });
      }
    }
  }

  Future pickImage() async {
    XFile? file = await imagePicker.pickImage(source: ImageSource.gallery);

    if (file != null) {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: file.path,
        aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
      );
      if (croppedFile != null) {
        setState(() {
          images = [...images, croppedFile];
        });
      }
    }
  }

  List<dynamic> getVariantNeedUpdateCost() {
    List<dynamic> changedBaseCost = [];
    selectedItems.forEach((item) {
      num currentBaseCost = variantToCurrentBaseCost[item.id] ?? 0;
      num newBaseCost =
          stringToInt(_formKey.currentState!.value['${item.id}.base_cost']) ??
              0;

      if (currentBaseCost != newBaseCost) {
        changedBaseCost.add({
          'variant_id': item.id,
          'base_cost': newBaseCost,
        });
      }
    });

    return changedBaseCost;
  }

  Future saveOrder() async {
    if (selectedItems.firstWhereOrNull(
                (element) => element.saveBaseCost != element.baseCost) !=
            null &&
        currentPolicy == null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              'Lưu giá nhập',
              textAlign: TextAlign.center,
            ),
            content: Text(
                'Đơn nhập hàng có sản phẩm có đơn giá khác với đơn giá nhập đã lưu. Bạn có muốn cập nhật giá nhập mới cho sản phẩm không?'),
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
                child: Text('Không'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                    backgroundColor: ThemeColor.get(context).primaryAccent,
                    foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.of(context).pop();
                  callSaveApi();
                },
                child: Text('Có'),
              ),
            ],
          );
        },
      );
    } else {
      callSaveApi();
    }
  }

  callSaveApi() async {
    Map<String, dynamic> orderPayload = getOrderPayloadFromForm();
    // if have variant with quantity = 0, show error
    if (orderPayload['order_detail'].any((item) => item['quantity'] == 0)) {
      CustomToast.showToastError(context,
          description: "Số lượng sản phẩm không được bằng 0");
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      if (images.isNotEmpty) {
        List<String> image = await api<UploadApiService>((request) =>
            request.uploadFiles(images.map((e) => e.path).toList()));
        orderPayload['image_attach'] = image;
      }

      if (savedImages.isNotEmpty) {
        orderPayload['image_attach'] = [
          ...orderPayload['image_attach'],
          ...savedImages
        ];
      }

      final res = await api<OrderApiService>(
          (request) => request.createOrder(orderPayload));
      if (_formKey.currentState!.value['status_order'] != 5) {
        pop();
      } else {
        CustomToast.showToastSuccess(context,
            description: "Tạo đơn thành công");
      }
      clearAllData();
    } catch (e) {
      CustomToast.showToastError(context, description: getResponseError(e));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future updateOrder({bool? isPaid}) async {
    if (selectedItems.firstWhereOrNull(
                (element) => element.saveBaseCost != element.baseCost) !=
            null &&
        isPaid != true) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Lưu giá nhập'),
            content: Text(
                'Đơn nhập hàng có sản phẩm có đơn giá khác với đơn giá nhập đã lưu. Bạn có muốn cập nhật giá nhập mới cho sản phẩm không?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(
                    side: BorderSide(
                      color: ThemeColor.get(context).primaryAccent,
                    ),
                    backgroundColor: Colors.transparent,
                    foregroundColor: ThemeColor.get(context).primaryAccent),
                child: Text('Hủy'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                    backgroundColor: ThemeColor.get(context).primaryAccent,
                    foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.of(context).pop();
                  callUpdateApi();
                },
                child: Text('Đồng ý'),
              ),
            ],
          );
        },
      );
    } else {
      callUpdateApi(isPaid: isPaid);
    }
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
          if (item.policyPrice != 0 && item.policyPrice != null) {
            _formKey.currentState
                ?.patchValue({'${item.id}.price': vnd.format(policyPrice)});
          } else {
            final defaultPrice = item.copyBaseCost;
            _formKey.currentState
                ?.patchValue({'${item.id}.price': vnd.format(defaultPrice)});
          }
          continue;
        }
      }

      // Nếu không có policy hoặc không khớp → dùng giá mặc định
      final defaultPrice = item.copyBaseCost;
      _formKey.currentState
          ?.patchValue({'${item.id}.price': vnd.format(defaultPrice)});
    }
  }

  callUpdateApi({bool? isPaid}) async {
    setState(() {
      _isLoading = true;
    });
    try {
      Map<String, dynamic> orderPayload = getOrderPayloadEditFromForm();
      if (images.isNotEmpty) {
        List<String> image = await api<UploadApiService>((request) =>
            request.uploadFiles(images.map((e) => e.path).toList()));
        orderPayload['image_attach'] = image;
      }

      if (savedImages.isNotEmpty) {
        orderPayload['image_attach'] = [
          ...orderPayload['image_attach'],
          ...savedImages
        ];
      }
      if (selectedItems.any((item) => item.quantity == 0)) {
        CustomToast.showToastError(context,
            description: "Số lượng sản phẩm không được bằng 0");
        return;
      }
      if (isPaid == true) {
        orderPayload['status_order'] = 4;
        orderPayload['payment']['price'] = getConfirmPaid() > getFinalPrice()
            ? getFinalPrice()
            : getConfirmPaid();
      }
      orderPayload['discount_type'] = _discountType.getValueRequest();
      isEditSuccessOrder()
          ? await api<OrderApiService>((request) =>
              request.updateSuccessOrder(orderPayload, orderId ?? 0))
          : await api<OrderApiService>(
              (request) => request.updateOrder(orderPayload, orderId ?? 0));

      CustomToast.showToastSuccess(context, description: "Nhập kho thành công");
      Navigator.of(context).pop();
    } catch (e) {
      CustomToast.showToastError(context, description: getResponseError(e));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void showUpdateCostConfirm(List<dynamic> changedBaseCost) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Cập nhật giá'),
            content: Text('Bạn có muốn cập nhật giá'),
            actions: [
              TextButton(
                onPressed: () async {
                  if (isEditing && !isClone) {
                    await updateOrder();
                  } else {
                    await saveOrder();
                  }
                },
                style: TextButton.styleFrom(
                    side: BorderSide(
                      color: ThemeColor.get(context).primaryAccent,
                    ),
                    backgroundColor: Colors.transparent,
                    foregroundColor: ThemeColor.get(context).primaryAccent),
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

                  await saveOrder();
                },
                child: Text('Cập nhật'),
              ),
            ],
          );
        });
  }

  dynamic getOrderPayloadFromForm() {
    DateTime? createDate = _formKey.currentState!.value['create_date'];
    Map<String, dynamic> orderPayload = {
      'type': 2, // 1: order, 2: storage
      'note': _noteController.text,
      'order_service_fee': otherFee ?? [],
      'discount_type': _discountType.getValueRequest(),
      'name': null,
      'create_date': createDate != null
          ? DateFormat('yyyy/MM/dd HH:mm:ss').format(createDate)
          : null,
      'status_order': _formKey.currentState!.value['status_order'],
      'discount': _discountType == DiscountType.percent
          ? stringToDouble(_formKey.currentState!.value['discount']) ?? 0
          : stringToInt(_formKey.currentState!.value['discount']) ?? 0,
      'service_fee': 0,
      "image_attach": [],
      'policy_id': currentPolicy,
      'payment': {
        "type": _formKey.currentState!.value['payment_type'],
        "price": stringToInt(_formKey.currentState!.value['paid']) ?? 0
      },
      'order_detail': selectedItems.map((item) {
        return {
          'is_batch': item.product?.isBatch ?? false,
          if (item.product?.isBatch == true) 'batch': item.selectedBatch,
          'product_id': item.product?.id ?? 0,
          'variant_id': item.id ?? 0,
          'quantity': item.quantity,
          'vat': item.product?.vat ?? 0,
          'discount': item.discount ?? 0,
          'discount_type': item.discountType.getValueRequest(),
          'price': stringToInt(item.txtPrice.text),
          'imei': item.selectedImei,
          'sub_unit_quantity': item.subUnitQuantity,
        };
      }).toList(),
    };

    if (orderPayload['discount'] == null || orderPayload['discount'] == '') {
      orderPayload['discount'] = 0;
    }
    return orderPayload;
  }

  dynamic getOrderPayloadEditFromForm() {
    var lstOrder = widget.data()['order_detail'] as List<dynamic>;
    List<Map<String, dynamic>> orderDetailRequest = [];
    for (Map<String, dynamic> order in lstOrder) {
      Map<String, dynamic> orderDetail = {
        'id': order['id'],
        'create_date': order['create_date'],
        'product_id': order['product']['id'] ?? 0,
        'variant_id': order['variant']['id'] ?? 0,
        'vat': order['product']['vat'] ?? 0,
        'is_batch': order['product']['is_batch'],
        'batch': order['batch'],
        'sub_unit_quantity': order['sub_unit_quantity'],
      };
      var filterInSelected = selectedItems
          .firstWhereOrNull((element) => element.id == order['variant']['id']);
      if (filterInSelected != null) {
        orderDetail['is_delete'] = false;
        orderDetail['quantity'] = filterInSelected.quantity;
        orderDetail['discount'] = filterInSelected.discount ?? 0;
        orderDetail['discount_type'] =
            filterInSelected.discountType.getValueRequest();
        orderDetail['price'] = filterInSelected.baseCost;
        orderDetail['imei'] = filterInSelected.selectedImei;
        orderDetail['sub_unit_quantity'] = filterInSelected.subUnitQuantity;
        orderDetail['is_batch'] = order['product']['is_batch'];
        orderDetail['vat'] = filterInSelected.product?.vat ?? 0;
        List<String> processedBatchNames = [];
        for (var batch in orderDetail['batch']) {
          bool found = false;
          for (var selectedBatch in filterInSelected.selectedBatch!) {
            if (batch['name'] == selectedBatch['name']) {
              found = true;
              batch['is_delete'] = false;
              batch['quantity'] = selectedBatch['quantity'];
              processedBatchNames.add(batch['name']);
              break;
            }
          }
          if (!found) {
            batch['is_delete'] = true;
          }
        }
        for (var selectedBatch in filterInSelected.selectedBatch!) {
          if (!processedBatchNames.contains(selectedBatch['name'])) {
            orderDetail['batch'].add({
              'quantity': selectedBatch['quantity'],
              'variant_batch_id': selectedBatch['variant_batch_id'],
              'name': selectedBatch['name'],
              'start': selectedBatch['start'],
              'end': selectedBatch['end'],
            });
          }
        }
      } else {
        orderDetail['is_delete'] = true;
        orderDetail['quantity'] = 0;
        orderDetail['discount'] = 0;
        orderDetail['discount_type'] = order['discountType'];
        orderDetail['price'] = 0;
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
          'vat': item.product?.vat ?? 0,
          'discount': item.discount ?? 0,
          'discount_type': item.discountType.getValueRequest(),
          'price': item.baseCost,
          'imei': item.selectedImei,
          'is_batch': item.product?.isBatch,
          'batch': item.selectedBatch,
          'sub_unit_quantity': item.subUnitQuantity,
        };
        orderDetailRequest.add(newVal);
      }
    }
    DateTime? createDate = _formKey.currentState!.value['create_date'];

    Map<String, dynamic> orderPayload = {
      'type': 2, // 1: order, 2: storage
      'note': _noteController.text,
      'order_service_fee': otherFee,
      'discount_type': _discountType.getValueRequest(),
      'name': '',
      'status_order': _formKey.currentState!.value['status_order'],
      'discount': _discountType == DiscountType.percent
          ? stringToDouble(_formKey.currentState!.value['discount']) ?? 0
          : stringToInt(_formKey.currentState!.value['discount']) ?? 0,
      'service_fee': 0,
      "image_attach": [],
      'policy_id': currentPolicy,
      'create_date': createDate != null
          ? DateFormat('yyyy/MM/dd HH:mm:ss').format(createDate)
          : null,
      'payment': {
        "type": _formKey.currentState!.value['payment_type'],
        "price": stringToInt(_formKey.currentState!.value['paid']) ?? 0,
      },
      'order_detail': orderDetailRequest,
    };

    if (orderPayload['discount'] == null || orderPayload['discount'] == '') {
      orderPayload['discount'] = 0;
    }
    return orderPayload;
  }

  num getPrice(StorageItem item) {
    dynamic baseCostValue = item.txtPrice.text.isNotEmpty
        ? item.txtPrice.text.replaceAll('.', '')
        : _formKey.currentState?.value['${item.id}.base_cost'];
    num baseCost = stringToInt(baseCostValue) ?? item.baseCost ?? 0;
    dynamic quantityValue = item.quantity.toString();
    num quantity = num.tryParse(quantityValue) ?? 0;
    num price = baseCost;
    num total = price * quantity;

    // discount
    num discountVal = (item.discount ?? 0);
    num discountPrice = item.discountType == DiscountType.percent
        ? total * discountVal / 100
        : discountVal;
    total = total - discountPrice;
    if (item.product?.useVat ?? true) {
      var vat = item.product?.vat ?? 0;
      if (vat > 0) {
        total = total + total * vat / 100;
      }
    }
    return total;
  }

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
    num discountVal = _discountType == DiscountType.percent
        ? stringToDouble(discountController.text) ?? 0
        : stringToInt(discountController.text) ?? 0;
    // apply discount
    num discountPrice = _discountType == DiscountType.percent
        ? total * discountVal / 100
        : discountVal;
    total = total - discountPrice;
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
    num debt = roundMoney(getFinalPrice()) - roundMoney(paid);
    return debt;
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          "${(isEditing && !isClone) ? 'Cập nhật' : 'Tạo'} đơn nhập hàng",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (!isEditing || isEditing && isClone)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: IconButton(
                  icon: Image.asset(
                    getImageAsset('list_icon.png'),
                  ),
                  onPressed: () {
                    routeTo(OrderListAllPage.path, data: {'is_order': false});
                  },
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
          child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: SingleChildScrollView(
          child: Column(
            children: [
              FormBuilder(
                key: _formKey,
                onChanged: () {
                  _formKey.currentState!.save();
                },
                autovalidateMode: AutovalidateMode.disabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 20),
                    SelectMultiVariant(
                      costField: 'baseCost',
                      type: filterProductType(),
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
                          EdgeInsets.symmetric(vertical: 12.0, horizontal: 6.0),
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
                          Text.rich(
                            TextSpan(
                              text: 'Tổng SL sản phẩm: ',
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
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    buildListItem(),
                    // SizedBox(height: 10),
                    buildSummary(),
                    Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Trạng thái',
                            style: TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.left),
                        SizedBox(
                          width: 180,
                          height: 40,
                          child: FormBuilderDropdown<int>(
                            name: 'status_order',
                            enabled: !isEditSuccessOrder(),
                            decoration: InputDecoration(
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.never,
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: ThemeColor.get(context).primaryAccent,
                                ),
                              ),
                            ),
                            initialValue: 4,
                            items: [
                              if (!((isEditing && !isClone) &&
                                  widget.data()['status_order'] == 8))
                                DropdownMenuItem(
                                  value: 1,
                                  child: Text(
                                    'Chờ xác nhận',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange),
                                  ),
                                ),
                              DropdownMenuItem(
                                value: 5,
                                child: Text(
                                  'Đã hủy',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 4,
                                child: Text(
                                  'Hoàn thành',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green),
                                ),
                              ),
                              if (Auth.user<User>()?.careerType ==
                                      CareerType.other &&
                                  (!isEditing ||
                                      (isEditing &&
                                          widget.data()['status_order'] == 8)))
                                DropdownMenuItem(
                                  value: 8,
                                  child: Text(
                                    'Đặt cọc',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.pink),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
                                                color: ThemeColor.get(context)
                                                    .primaryAccent,
                                              ),
                                              backgroundColor:
                                                  Colors.transparent,
                                              foregroundColor:
                                                  ThemeColor.get(context)
                                                      .primaryAccent),
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
                                } else if (dateTime.isBefore(DateTime(
                                    DateTime.now().year,
                                    DateTime.now().month,
                                    DateTime.now().day))) {
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
                                                color: ThemeColor.get(context)
                                                    .primaryAccent,
                                              ),
                                              backgroundColor:
                                                  Colors.transparent,
                                              foregroundColor:
                                                  ThemeColor.get(context)
                                                      .primaryAccent),
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
                                                  ThemeColor.get(context)
                                                      .primaryAccent,
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
                    SizedBox(height: 25),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _noteController,
                            keyboardType: TextInputType.multiline,
                            maxLines: null,
                            minLines: 3,
                            cursorColor: ThemeColor.get(context).primaryAccent,
                            onTapOutside: (event) {
                              FocusScope.of(context).unfocus();
                            },
                            onChanged: (vale) {
                              setState(() {});
                            },
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 10),
                              labelText: 'Ghi chú',
                              labelStyle: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.always,
                              hintText: 'Nhập ghi chú',
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        (images.isEmpty && savedImages.isEmpty)
                            ? SizedBox(
                                width: 80,
                                height: 80,
                                child: InkWell(
                                  child: Icon(
                                    Icons.photo_library,
                                    color: Colors.grey,
                                    size: 50,
                                  ),
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return SafeArea(
                                          child: Wrap(
                                            children: <Widget>[
                                              ListTile(
                                                leading: Icon(Icons.camera_alt),
                                                title: Text('Chụp ảnh'),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  takePicture();
                                                },
                                              ),
                                              ListTile(
                                                leading: Icon(
                                                  Icons.photo_library,
                                                ),
                                                title: Text('Chọn ảnh'),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  pickImage();
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              )
                            : Stack(
                                children: images.isNotEmpty
                                    ? [
                                        Image.file(
                                          File(images[0].path),
                                          width: 80,
                                          height: 80,
                                        ),
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                images.removeAt(0);
                                              });
                                            },
                                            child: Container(
                                              padding: EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                              ),
                                              child: Icon(
                                                Icons.close,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ]
                                    : [],
                              ),
                        SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: savedImages.isNotEmpty
                              ? [
                                  Stack(
                                    children: [
                                      Image.network(
                                        savedImages[0],
                                        width: 80,
                                        height: 80,
                                      ),
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              savedImages.removeAt(0);
                                            });
                                          },
                                          child: Container(
                                            padding: EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                            ),
                                            child: Icon(
                                              Icons.close,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ]
                              : [],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              if (!isEditSuccessOrder())
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                        flex: 1,
                        child: ElevatedButton(
                            onPressed: () {
                              if (isEditing &&
                                  !isClone &&
                                  _formKey.currentState!
                                          .value['status_order'] ==
                                      4) {
                                confirmPaymentDialog(context);
                              } else {
                                submit();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                backgroundColor: (isEditing && !isClone)
                                    ? Color.fromARGB(255, 255, 146, 56)
                                    : Colors.green,
                                minimumSize: Size(80, 40)),
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
                                      SizedBox(width: 5),
                                      Text(
                                        '${(isEditing && !isClone) ? 'Cập nhật' : 'Tạo'} đơn',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ))),
                  ],
                ),
              if (isEditing && !isClone && !isEditSuccessOrder())
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                backgroundColor: Color(0xff2caee2),
                                minimumSize: Size(80,
                                    40) // put the width and height you want, standard ones are 64, 40
                                ),
                            onPressed: () {
                              confirmPaymentDialog(context);
                            },
                            child: _isLoading
                                ? CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check,
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
                  ),
                ),
              if (isEditSuccessOrder())
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                backgroundColor: Colors.blue,
                                minimumSize: Size(80, 40)),
                            onPressed: () {
                              submit();
                            },
                            child: _isLoading
                                ? CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check,
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
                ),
              SizedBox(height: 20),
            ],
          ),
        ),
      )),
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
                          backgroundColor: Colors.blue,
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
                        child: Text(
                          'Thêm mới sản phẩm',
                          style: TextStyle(color: Colors.white),
                        )))
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
          Text(vndCurrency.format(item.baseCost).replaceAll('vnđ', 'đ'),
              style: TextStyle(fontSize: 14)),
          Text("SL: ${roundQuantity(item.inStock ?? 0)}",
              style: TextStyle(fontSize: 14)),
        ],
      ),
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
    return OrderStorageItem(
      key: ValueKey(item.id),
      selectedBatch: item.selectedBatch,
      listBatch: item.batch,
      item: item,
      currentPolicy: currentPolicy,
      isImei: item.product?.isImei ?? false,
      index: index,
      removeItem: removeItem,
      updatePaid: updatePaid,
      costType: CostType.base,
      onMinusQuantity: () {
        if (item.quantity >= 1) {
          String newQuantityStr = (item.quantity - 1).toStringAsFixed(3);
          num newQuantity = stringToDouble(newQuantityStr) ?? 0;
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
        }
      },
      getPrice: () => getPrice(item),
      onChangeQuantity: (value) {
        item.quantity = stringToDouble(value) ?? 0;
        if (item.discountType == DiscountType.price) {
          final currentValue =
              _formKey.currentState?.value['${item.id}.discount'];
          item.discount = (stringToInt(currentValue) ?? 0) * item.quantity;
        }
        checkDiscountItem(item);
        checkOnChange();
        updatePaid();
        setState(() {});
      },
      onIncreaseQuantity: () {
        String newQuantityStr = (item.quantity + 1).toStringAsFixed(3);
        num newQuantity = stringToDouble(newQuantityStr) ?? 0;
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
            : item.copyBaseCost ?? 0;

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
        item.baseCost = inputPrice;

        updatePaid();
        checkOnChange();
        setState(() {});
      },
      onChangeDiscount: (value) {
        item.discount = item.discountType == DiscountType.percent
            ? (stringToDouble(value) ?? 0)
            : (stringToInt(value) ?? 0) * item.quantity;
        checkDiscountItem(item);
        checkDiscountOrder();
        updatePaid();
        setState(() {});
      },
      onChangeImei: (imeis) {
        final count = imeis.length;
        item.selectedImei = imeis;
        item.quantity = count.toDouble();

        _formKey.currentState
            ?.patchValue({'${item.id}.quantity': roundQuantity(item.quantity)});

        updatePaid();
        setState(() {});
      },
      onChangeDiscountType: (value) {
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
              '${item.id}.discount': vnd.format(stringToInt(currentValue) ?? 0)
            });
          }
        }

        item.discountType = value!;
        item.discount = item.discountType == DiscountType.percent
            ? (stringToDouble(currentValue) ?? 0)
            : (stringToInt(currentValue) ?? 0) * item.quantity;

        updatePaid();
      },
      updateQuantity: (value) {
        item.quantity = num.parse(value!);
        _formKey.currentState?.patchValue({'${item.id}.quantity': value});
        updatePaid();
        setState(() {});
      },
      filterBatch: (type) async {
        //add new batch
        if (type == 1) {
          List<dynamic> tempBatch = item.batch!
              .where((element) => element.containsKey('quantity'))
              .map((element) {
            var newElement = Map<String, dynamic>.from(element);
            newElement['quantity'] = 0;
            return newElement;
          }).toList();

          if (tempBatch.isNotEmpty) {
            tempBatch = [tempBatch.last];
          } else {
            tempBatch = [];
          }
          Map<String, dynamic> res = await pushBatch(item.id!, tempBatch);
          item.selectedBatch!.add({
            'name': item.batch!.last['name'],
            'variant_batch_id': res['id'],
            'start': res['start'],
            'end': res['end'],
            'quantity': item.batch!.last['quantity'],
          });
          item.batch!.last['id'] = res['id'];
          item.batch!.last['hide'] = true;
        }
        setState(() {});
      },
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
        if (listPolicies.isNotEmpty) ...[
          buildListPolicies(),
          SizedBox(
            height: 12,
          ),
        ],
        Row(
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
                  setState(() {
                    checkDiscountOrder();
                  });
                },
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                textAlign: TextAlign.right,
                keyboardType: TextInputType.numberWithOptions(
                    decimal: true, signed: true),
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
                          'discount': discount == 0.0
                              ? ''
                              : discount.toStringAsFixed(0),
                        });
                      } else {
                        _formKey.currentState?.patchValue({
                          'discount': vnd.format(stringToInt(
                                  _formKey.currentState?.value['discount']) ??
                              0),
                        });
                      }

                      setState(() {
                        _discountType = value!;
                        checkDiscountOrder();

                        updatePaid();
                      });
                    },
                    children: {
                      DiscountType.percent: Container(
                        child: Text(
                          '%',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _discountType == DiscountType.percent
                                  ? Colors.white
                                  : Colors.black),
                        ),
                      ),
                      DiscountType.price: Container(
                        child: Text(
                          'đ',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _discountType == DiscountType.price
                                  ? Colors.white
                                  : Colors.black),
                        ),
                      )
                    },
                    groupValue: _discountType,
                  )),
                  // icon: Icon(Icons.contact_page),
                  // border: UnderlineInputBorder(),
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  hintText: '0',
                  suffixText: _discountType == DiscountType.percent ? '' : '',
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('VAT', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(
              height: 40,
              width: 180,
              child: Builder(
                builder: (fieldContext) => FormBuilderTextField(
                  name: 'vat',
                  readOnly: true,
                  controller: vatController,
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
        SizedBox(height: 12.0),
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
                initialValue: '0',
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
        SizedBox(height: 12.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Tổng tiền T.Toán',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(
              height: 40,
              width: 180,
              child: FormBuilderTextField(
                name: '',
                enabled: false,
                controller: TextEditingController(
                    text: vndCurrency
                        .format(roundMoney(getFinalPrice()))
                        .replaceAll('vnđ', 'đ')),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
            ),
            // Text(vndCurrency.format(getFinalPrice()),
            //     style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        SizedBox(height: 12.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Đã T.Toán', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
                child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                    height: 40,
                    width: 180.0,
                    child: Column(
                      children: [
                        Expanded(
                            child: FormBuilderTextField(
                          keyboardType: TextInputType.number,
                          initialValue: '0',
                          name: 'paid',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                          onTap: () {
                            _formKey.currentState!.patchValue({
                              'paid': '',
                            });
                          },
                          onChanged: (vale) {
                            setState(() {});
                          },
                          inputFormatters: [
                            CurrencyTextInputFormatter(
                              locale: 'vi',
                              symbol: '',
                            )
                          ],
                          decoration: InputDecoration(
                            disabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.grey,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                            suffixText: 'đ',
                          ),
                        )),
                      ],
                    )),
              ],
            ))
          ],
        ),
        SizedBox(height: 12),
        if (getDebt() != 0)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Còn nợ', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(
                height: 40,
                width: 180,
                child: FormBuilderTextField(
                  name: '',
                  enabled: false,
                  controller: TextEditingController(
                      text:
                          vndCurrency.format(getDebt()).replaceAll('vnđ', 'đ')),
                  // initialValue: vndCurrency.format(getDebt()),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
              ),
              // Text(vndCurrency.format(getDebt()),
              //     style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
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

  void filterNewFee() {
    cloneOtherFee.removeWhere((element) => element['name'].isEmpty);
    if (!isEditing || (isEditing && isClone)) {
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
              CustomToast.showToastError(context, description: "Có lỗi xảy ra");
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
              CustomToast.showToastError(context, description: "Có lỗi xảy ra");
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
                        mainAxisAlignment: MainAxisAlignment.center,
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

  void confirmPaymentDialog(BuildContext context) {
    _confirmPaidController.text = initConfirmPaid();
    showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0)),
            child: Container(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Align(
                          alignment: Alignment.center,
                          child: Text(
                            "Xác nhận thanh toán",
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              icon: Icon(Icons.close))),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 10,
                        ),
                        Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tổng tiền T.Toán',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              vndCurrency
                                  .format(roundMoney(getFinalPrice()))
                                  .replaceAll('vnđ', 'đ'),
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            )
                          ],
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tiền đã trả',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _formKey.currentState?.value['paid'] != ''
                                  ? '${_formKey.currentState?.value['paid']} đ'
                                  : '0 đ',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            )
                          ],
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tiền phải trả',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(
                              height: 40,
                              width: 130,
                              child: TextField(
                                controller: _confirmPaidController,
                                readOnly:
                                    stringToInt(_confirmPaidController.text) ==
                                        0,
                                textAlign: TextAlign.right,
                                keyboardType: TextInputType.number,
                                style: TextStyle(fontWeight: FontWeight.bold),
                                cursorColor:
                                    ThemeColor.get(context).primaryAccent,
                                decoration: InputDecoration(
                                  enabledBorder: UnderlineInputBorder(),
                                  focusedBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                          color: ThemeColor.get(context)
                                              .primaryAccent)),
                                  hintText: '0',
                                  suffixText: 'đ',
                                ),
                                inputFormatters: [
                                  CurrencyTextInputFormatter(
                                    locale: 'vi',
                                    symbol: '',
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                        Divider(),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                  style: TextButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      side: BorderSide(
                                        color: Colors.blue,
                                      ),
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.blue),
                                  onPressed: () => Navigator.pop(context),
                                  child: Text('Hủy')),
                            ),
                            SizedBox(
                              width: 10,
                            ),
                            Expanded(
                              child: TextButton(
                                  style: TextButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white),
                                  onPressed: () {
                                    submit(isPaid: true);
                                    Navigator.pop(context);
                                  },
                                  child: Text('Xác nhận')),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 10,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        });
  }

  String initConfirmPaid() {
    int finalPrice = getFinalPrice().toInt();
    int paid = stringToInt(_formKey.currentState?.value['paid']) ?? 0;
    int result = finalPrice - paid;
    return vnd.format(result < 0 ? 0 : result);
  }

  num getConfirmPaid() {
    int paid = stringToInt(_formKey.currentState?.value['paid']) ?? 0;
    int confirmPaid = stringToInt(_confirmPaidController.text) ?? 0;
    return confirmPaid + paid;
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
      num baseCost = item.baseCost ?? 0;

      dynamic quantityValue = item.quantity.toString();

      num quantity = num.tryParse(quantityValue) ?? 0;
      num total = baseCost * quantity;
      num discountVal = (item.discount ?? 0);
      num discountPrice = item.discountType == DiscountType.percent
          ? total * discountVal / 100
          : discountVal;
      // apply discount
      total = total - discountPrice;
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
}
