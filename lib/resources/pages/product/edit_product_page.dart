import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/app/controllers/controller.dart';
import 'package:flutter_app/app/models/category.dart';
import 'package:flutter_app/app/models/product.dart';
import 'package:flutter_app/app/models/storage_item.dart';
import 'package:flutter_app/app/networking/product_api_service.dart';
import 'package:flutter_app/app/networking/upload_api_service.dart';
import 'package:flutter_app/app/utils/formatters.dart';
import 'package:flutter_app/app/utils/message.dart';
import 'package:flutter_app/app/utils/utils.dart';
import 'package:flutter_app/app/utils/variant.dart';
import 'package:flutter_app/bootstrap/helpers.dart';
import 'package:flutter_app/resources/pages/custom_toast.dart';
import 'package:flutter_app/resources/pages/product/setting_product_page.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nylo_framework/nylo_framework.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../../../app/models/user.dart';

final Map<int?, Color> foodTypeColors = {
  null: Colors.grey,
  2: Colors.orange,
  1: Colors.blue,
};

List<String> defaultAttribute = ['Màu sắc', 'Kích thước', 'Chất liệu'];
Map<String, String> attributePlaceholder = {
  'Màu sắc': 'Đỏ, Xanh, Vàng',
  'Kích thước': 'XL, L, M',
  'Chất liệu': 'Da, Vải, Nhựa',
};

List<String> defaultUnit = [
  'Cái',
  'Con',
  'Chiếc',
  'Chai',
  'Lọ',
  'Hộp',
  'Vỉ',
  'Gói',
  'Thùng',
  'Lốc',
  'Cân',
  'Lạng',
  'Khay',
  'Ống',
  'Can'
];

List<String> defaultConversionUnit = ["Hộp", "Thùng", "Gói"];

class EditProductPage extends NyStatefulWidget {
  final Controller controller = Controller();
  final MobileScannerController mobileScannerController =
      MobileScannerController();

  static const path = '/edit-product';

  @override
  _EditProductPageState createState() => _EditProductPageState();
}

class _EditProductPageState extends NyState<EditProductPage> {
  String _scanningInputName = '';
  final _selectCateMultiKey = GlobalKey<DropdownSearchState<CategoryModel>>();

  bool _isLoading = false;
  bool _isFetching = false;

  List<CategoryModel> selectedCates = [];

  ImagePicker imagePicker = ImagePicker();

  final _formKey = GlobalKey<FormBuilderState>();

  List<CroppedFile> images = [];

  List<String> savedImages = []; // for edit
  Map<String, String> savedImagesVariant = {}; // for edit

  bool isImei = false;

  bool isShowStorage = false;
  bool isShowAttributes = false;
  bool isShowUnit = false;
  bool isBuyAlway = true;
  bool isTopping = false;
  bool isBatchStorage = false;
  bool isSyncConversion = false;
  bool isShowMenu = true;
  bool useVat = true;
  bool isSyncPrice = false;
  String productName = '';
  final FocusNode _baseCostFocusNode = FocusNode();
  final FocusNode _retailCostFocusNode = FocusNode();
  final FocusNode _wholesaleCostFocusNode = FocusNode();
  TextEditingController searchBrandController = TextEditingController();
  final discountController = TextEditingController();
  Map<String, int> variantDiscountTypes = {};
  Map<String, bool> variantCommissionTypes = {};
  Map<String, FoodType?> variantFoodTypes = {};
  Map<int, dynamic> initialPolicyValues = {};
  int? get selectStoreId => widget.data()?['store_id'];
  bool _afterSetting = false;

  List<String> selectedVariantKeys = [];
  List<String> excludedVariantKeys = [];

  Map<String, String> variantInitValue = {}; // for edit
  Map<String, int> variantKeyToId = {}; // for edit

  Map<String, int> unitToQuantity = {};
  bool get isClone => widget.data()?['is_clone'] ?? false;

  Product? product;
  Map<String, Key> variantToExpandKey = {};
  final GlobalKey<FormBuilderState> _dropdownKey =
      GlobalKey<FormBuilderState>();
  Map<String, GlobalKey<FormBuilderState>> variantDropdownKeys = {};
  String? _selectedWeightUnit = null;
  List<dynamic> batchProducts = [];
  Map<String, bool> featuresConfig = {};
  Map<String, CroppedFile?> variantImages = {};
  int discountType = 1;
  FoodType? foodType;
  bool isContinue = false;
  @override
  init() async {
    super.init();
    setState(() {
      _isFetching = true;
    });
    final config = await getProductConfig();
    setState(() {
      featuresConfig = config;
    });
    if (_afterSetting == false) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _patchDataForEdit(context));
    }

    _baseCostFocusNode.addListener(() {
      if (!_baseCostFocusNode.hasFocus) {
        _updateFieldIfEmpty('base_cost');
      }
      _retailCostFocusNode.addListener(() {
        if (!_retailCostFocusNode.hasFocus) {
          _updateFieldIfEmpty('retail_cost');
        }
      });
      _wholesaleCostFocusNode.addListener(() {
        if (!_wholesaleCostFocusNode.hasFocus) {
          _updateFieldIfEmpty('wholesale_cost');
        }
      });
    });
    setState(() {
      _isFetching = false;
    });
  }

  void _updateFieldIfEmpty(String fieldName) {
    if (_formKey.currentState!.fields[fieldName]!.value == null ||
        _formKey.currentState!.fields[fieldName]!.value.isEmpty) {
      setState(() {
        _formKey.currentState!.fields[fieldName]!.didChange('0');
      });
    }
  }

  bool isEdit() {
    return widget.data()?['id'] != null;
  }

  Future _patchDataForEdit(BuildContext context) async {
    var productId = widget.data()?['id'];
    if (productId == null) {
      return;
    }
    dynamic product = await _fetchProduct();
    this.product = Product.fromJson(product);
    if (product == null) {
      return;
    }

    List<dynamic> variants = product['variants'];

    dynamic defaultVariant;

    for (int i = 0; i < variants.length; i++) {
      final variant = variants[i];
      if (variant['conversion_unit'] == null ||
          variant['conversion_unit'].length == 0) {
        defaultVariant = variant;
        break;
      }
    }

    if (defaultVariant == null) {
      defaultVariant = variants.first;
    }
    discountType = defaultVariant['discount_type'] ?? 1;
    foodType = defaultVariant['food_type'] != null
        ? FoodType.fromJson(defaultVariant['food_type'])
        : null;
    _formKey.currentState!.patchValue({
      'name': product['name'],
      "code": product['code'],
      "sku": isClone == true ? null : product['code'],
      "note": product['note'],
      "unit": product['unit'],
      "weight_unit": product['weight_unit'],
      "is_imei": product['is_imei'],
      "weight": defaultVariant['weight'],
      "bar_code": defaultVariant['bar_code'] ?? '',
      "is_buy_alway": product['variants'][0]['is_buy_alway'],
      "is_show_menu": product['variants'][0]['is_show_menu'],
      "brand": product['brand'],
      "base_cost": vnd.format(defaultVariant['base_cost']),
      "retail_cost": vnd.format(defaultVariant['retail_cost']),
      "wholesale_cost": vnd.format(defaultVariant['wholesale_cost']),
      "vat": product['vat'].toString(),
      "discount": discountType == 1
          ? defaultVariant['discount'].toString()
          : vnd.format(defaultVariant['discount']),
    });

    List<String> images = [];
    try {
      images = List<String>.from(jsonDecode(product['image']));
    } catch (e) {
      images = [];
    }

    setState(() {
      savedImages = images;
      isImei = product['is_imei'];
      useVat = product['use_vat'];
      isSyncConversion = product['is_sync_conversion'];
      isBuyAlway = product['variants'][0]['is_buy_alway'];
      isSyncPrice = product['variants'][0]['is_apply_price_all'];
      isShowMenu = product['is_show_menu'];
      isTopping = product['is_topping'];
      isBatchStorage = product['is_batch'];
    });

    // patch variant
    if (variants.length > 1 ||
        (variants.firstOrNull?['attribute_values']?.length ?? 0) != 0) {
      // set default variant values to use as initial values
      for (int index = 0; index < variants.length; index++) {
        final variant = variants[index];
        String variantKey = getVariantKey(variant);

        variantDiscountTypes[variantKey] =
            variant['discount_type'] != null ? variant['discount_type'] : 1;
        variantFoodTypes[variantKey] = variant['food_type'] != null
            ? FoodType.fromJson(variant['food_type'])
            : null;
        num? variantWeight =
            variant['weight'] != null ? num.parse(variant['weight']) : null;

        setState(() {
          variantInitValue['$variantKey.sku'] = variant['sku'];
          variantInitValue['$variantKey.bar_code'] = variant['bar_code'] ?? '';
          variantInitValue['$variantKey.base_cost'] =
              vnd.format(variant['base_cost']);
          variantInitValue['$variantKey.retail_cost'] =
              vnd.format(variant['retail_cost']);
          variantInitValue['$variantKey.wholesale_cost'] =
              vnd.format(variant['wholesale_cost']);

          if (variant['policies'] != null && variant['policies'].isNotEmpty) {
            for (var policy in variant['policies']) {
              final policyId = policy['policy_id'];
              final policyValue = policy['policy_value'];

              if (policyId != null) {
                try {
                  variantInitValue['$variantKey.policies_$policyId'] =
                      policyValue != null
                          ? vnd.format(stringToInt(policyValue ?? '0'))
                          : '';
                } catch (e) {}
              }
            }
          }

          variantInitValue['$variantKey.weight'] =
              variantWeight != null ? variantWeight.toString() : '';
          variantInitValue['$variantKey.weight_unit'] =
              variant['weight_unit'] != null
                  ? variant['weight_unit'].toString()
                  : 'g';
          variantInitValue['$variantKey.entry_cost'] =
              vnd.format(variant['entry_cost']);
          variantInitValue['$variantKey.in_stock'] =
              variant['in_stock'].toString();
          variantInitValue['$variantKey.discount'] =
              variantDiscountTypes[variantKey] == 1
                  ? variant['discount'].toString()
                  : vnd.format(variant['discount']);
          // set variant id for edit
          variantKeyToId[variantKey] = variant['id'];

          List<String> imagesVariant = [];
          try {
            imagesVariant = List<String>.from(jsonDecode(variant['image']));
          } catch (e) {
            imagesVariant = [];
          }
          if (imagesVariant.isNotEmpty) {
            savedImagesVariant[variantKey] = imagesVariant[0];
          }
        });
      }

      // units
      List<dynamic> allUnits = getAllUnits(variants);

      // attributes

      setState(() {});
    } else {
      setState(() {
        variantKeyToId['/'] = defaultVariant['id'];
      });
    }
  }

  Future<dynamic> _fetchProduct() async {
    try {
      final item = await api<ProductApiService>((request) =>
          request.getProduct(widget.data()?['id'], storeId: selectStoreId));
      return item;
    } catch (e) {
      String errorMessage = getResponseError(e);
      CustomToast.showToastError(context, description: errorMessage);
      return [];
    } finally {}
  }

  Future pickVariantImage(String variantKey) async {
    XFile? file = await imagePicker.pickImage(source: ImageSource.gallery);

    if (file != null) {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: file.path,
        aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
      );
      if (croppedFile != null) {
        setState(() {
          variantImages[variantKey] = croppedFile;
        });
      }
    }
  }

  Future takeVariantPicture(String variantKey) async {
    XFile? file = await imagePicker.pickImage(source: ImageSource.camera);

    if (file != null) {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: file.path,
        aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
      );
      if (croppedFile != null) {
        setState(() {
          variantImages[variantKey] = croppedFile;
        });
      }
    }
  }

  Widget buildVariantImagePicker(String variantKey) {
    return Column(
      children: [
        variantImages[variantKey] != null
            ? Stack(children: [
                Image.file(
                  File(variantImages[variantKey]!.path),
                  height: 100,
                  width: 100,
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        variantImages.remove(variantKey);
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ])
            : savedImagesVariant.containsKey(variantKey) &&
                    savedImagesVariant[variantKey]!.isNotEmpty
                ? Stack(
                    children: [
                      Image.network(
                        savedImagesVariant[variantKey] ?? '',
                        width: 100,
                        height: 100,
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              savedImagesVariant.remove(variantKey);
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Container(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () => pickVariantImage(variantKey),
              label: Text(
                'Chọn ảnh',
                style: TextStyle(color: ThemeColor.get(context).primaryAccent),
              ),
              icon: Icon(
                Icons.image,
                color: ThemeColor.get(context).primaryAccent,
              ),
            ),
            SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: () => takeVariantPicture(variantKey),
              label: Text(
                'Chụp ảnh',
                style: TextStyle(color: ThemeColor.get(context).primaryAccent),
              ),
              icon: Icon(
                Icons.camera_alt,
                color: ThemeColor.get(context).primaryAccent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _baseCostFocusNode.dispose();
    _retailCostFocusNode.dispose();
    _wholesaleCostFocusNode.dispose();
    super.dispose();
  }

  Future<dynamic> saveProduct() async {
    var product = getProductFromForm();
    if (product == null) {
      return;
    }
    if (_isLoading) {
      return;
    }
    if (product['variants'].isEmpty) {
      CustomToast.showToastError(context,
          description: "Số lượng phiên bản không được bằng 0");
      return;
    } else {
      int deleteCount = product['variants']
          .where((variant) => variant['is_delete'] == true)
          .length;

      if (deleteCount == product['variants'].length) {
        CustomToast.showToastError(context,
            description: "Số lượng phiên bản không được bằng 0");
        return;
      }
    }
    setState(() {
      _isLoading = true;
    });

    try {
      // upload images
      if (images.isNotEmpty) {
        List<String> image = await api<UploadApiService>((request) =>
            request.uploadFiles(images.map((e) => e.path).toList()));
        product['image'] = image;
      }

      if (savedImages.isNotEmpty) {
        product['image'] = [...product['image'], ...savedImages];
      }

      product['variants'] = product['variants'].reversed.toList();
      if (isEdit() && isClone == false) {
        dynamic createdProduct = await api<ProductApiService>((request) =>
            request.updateProduct(widget.data()['id'], product,
                storeId: selectStoreId));
        CustomToast.showToastSuccess(context,
            description: "Cập nhật sản phẩm thành công");
        Navigator.of(context).pop(createdProduct);
      } else {
        await api<ProductApiService>(
            (request) => request.createProduct(product));
        CustomToast.showToastSuccess(context,
            description: "Tạo sản phẩm thành công");

        if (isContinue) {
          clearAllData();
          Navigator.of(context).pop();
          routeTo(EditProductPage.path);
        } else {
          clearAllData();
          Navigator.of(context).pop();
        }
        // Navigator.of(context).pop(createdProduct);
        // routeTo(ListProductPage.path);
      }
    } catch (e) {
      String error = getResponseError(e);
      if (e.toString().contains('413')) {
        error = 'Dung lượng ảnh quá lớn';
      }
      CustomToast.showToastError(context, description: error);
    } finally {
      setState(() {
        _isLoading = false;
      });
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

  // use for default variant if user not input variant
  dynamic getDefaultVariantFromForm() {
    Map<String, dynamic> formValue = _formKey.currentState!.value;
    num discount = discountType == 1
        ? stringToDouble(formValue['discount']) ?? 0
        : stringToInt(formValue['discount']) ?? 0;

    dynamic payload = {
      'name': formValue['name'],
      'unit': formValue['unit'] ?? '',
      'weight_unit': formValue['weight_unit'] ?? '',
      'sku': formValue['sku'],
      'bar_code': formValue['bar_code'] ?? '',
      'weight': formValue['weight'],
      "base_cost": formValue['base_cost'] == '0'
          ? '0'
          : stringToInt(formValue['base_cost']) ?? '0',
      "retail_cost": stringToInt(formValue['retail_cost']) ?? 0,
      "wholesale_cost": stringToInt(formValue['wholesale_cost']) ?? 0,
      "entry_cost": stringToInt(formValue['entry_cost']) ?? 0,
      "attribute_values": [],
      "attribute": [],
      "conversion_unit": [],
      "discount": isTopping ? 0 : discount,
      "discount_type": discountType,
      'in_stock': formValue['in_stock'] ?? 0,
      "id": isEdit() && isClone == false ? variantKeyToId['/'] : null,
      "is_buy_alway": isBuyAlway,
      "is_apply_price_all": isSyncPrice,
      "food_type": foodType?.value,
    };

    // 'available': formValue['available'] ?? 0,
    if (formValue['available'] != null) {
      payload['available'] = formValue['available'];
    } else {
      payload['available'] = 0;
    }
    return payload;
  }

  dynamic getProductFromForm() {
    Map<String, dynamic> formValue = _formKey.currentState!.value;
    bool hasVariant = isShowAttributes || isShowUnit;
    return {
      "name": formValue['name'],
      "code": formValue['sku'],
      "bar_code": formValue['bar_code'] ?? '',
      "unit": formValue['unit'],
      'weight_unit': _selectedWeightUnit,
      "is_imei": isImei,
      "is_buy_alway": isBuyAlway,
      "is_topping": isTopping,
      "is_show_menu": isShowMenu,
      "variants": [getDefaultVariantFromForm()],
      "image": [],
      "is_batch": isBatchStorage,
      "note": formValue['note'],
      "is_sync_conversion": isSyncConversion,
      "vat": stringToDouble(formValue['vat']) ?? 0,
      "use_vat": useVat,
      "is_apply_price_all": isSyncPrice,
    };
  }

  // each attribute row has tags, example:
  // attribute 1: color: red, blue
  // attribute 2: size: XL, M, S

  // result: red-XL, red-M, red-S, blue-XL, blue-M, blue-S
  List<String> getCombinesNameFromAttributes(List<List<String>> attributes) {
    List<String> combines = [];

    // Recursive helper function to generate variants
    void generateVariants(List<String> currentVariant, int attributeIndex) {
      if (attributeIndex >= attributes.length) {
        // Base case: Reached the end of attributes, add the variant to the list
        combines.add(currentVariant.join('-'));
        return;
      }

      for (int i = 0; i < attributes[attributeIndex].length; i++) {
        String attributeValue = attributes[attributeIndex][i];
        List<String> combine = List.from(currentVariant); // Create a copy
        combine.add(attributeValue);
        generateVariants(combine, attributeIndex + 1);
      }
    }

    generateVariants(
        [], 0); // Start with an empty variant and attribute index 0
    combines.sort(alphabetSort);
    return combines;
  }

  void excludeSelectedVariant() {
    List<String> _excluded = excludedVariantKeys;
    selectedVariantKeys.forEach((element) {
      _excluded.add(element);
    });
    setState(() {
      selectedVariantKeys = [];
      excludedVariantKeys = _excluded;
    });
  }

  String getVariantDefaultValue(String key) {
    if (_formKey.currentState == null) {
      return '';
    }
    Map<String, dynamic> formValue = _formKey.currentState!.value;
    dynamic value = formValue['${key}'];

    if (value == null || value == '') {
      return '';
    }
    return value.toString();
  }

  String getVariantInitialValue(String fieldName) {
    String variantKey = fieldName.split('.')[0];
    String field = fieldName.split('.')[1];

    String unit = '';
    if (variantKey.contains('/')) {
      unit = variantKey.split('/')[1];
    }

    if (unit.isEmpty) {
      return getVariantDefaultValue(field);
    }

    if ([
      'retail_cost',
      'wholesale_cost',
      'base_cost',
      'entry_cost',
    ].contains(field)) {
      int conversion = unitToQuantity[unit] ?? 0;
      num cost = stringToInt(getVariantDefaultValue(field)) ?? 0;
      String formatted = vnd.format(cost * conversion);

      // ✅ Sử dụng addPostFrameCallback để tránh lỗi
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_formKey.currentState?.fields.containsKey(fieldName) ?? false) {
          _formKey.currentState?.patchValue({fieldName: formatted});
        }
      });
      return formatted;
    }
    return variantInitValue[fieldName] ?? '';
  }

  Future<String> getVariantInitialValueAsync(String fieldName) async {
    String variantKey = fieldName.split('.')[0];

    // if (!isEdit()) {
    String unit = variantKey.split('/')[1];
    if (unit.isEmpty) {
      return await getVariantDefaultValue(fieldName.split('.')[1]);
    }

    // if is cost field
    if (['retail_cost', 'wholesale_cost', 'base_cost', 'entry_cost']
        .contains(fieldName.split('.')[1])) {
      int conversion = unitToQuantity[unit] ?? 0;
      num cost =
          stringToInt(getVariantDefaultValue(fieldName.split('.')[1])) ?? 0;
      return await vnd.format(cost * conversion);
    }

    return await variantInitValue[fieldName] ?? '';
  }

  bool isScanningBarcode() {
    return _scanningInputName != '';
  }

  void checkDiscountProduct() {
    if (_isLoading) return;
    num discount = discountType == 2
        ? stringToInt(_formKey.currentState?.value['discount']) ?? 0
        : stringToDouble(_formKey.currentState?.value['discount']) ?? 0;

    if (discountType == 1 && discount > 100) {
      Future.delayed(Duration(milliseconds: 100), () {
        discountController.text = '100';
        discountController.selection = TextSelection.fromPosition(
            TextPosition(offset: discountController.text.length));
      });
      return;
    }
    if (mounted) {
      setState(() {});
    }
  }

  void checkDiscountVariant(String variantKey) {
    if (_isLoading) return;
    num discount = variantDiscountTypes[variantKey] == 2
        ? stringToInt(_formKey.currentState?.value['${variantKey}.discount']) ??
            0
        : stringToDouble(
                _formKey.currentState?.value['${variantKey}.discount']) ??
            0;

    if (variantDiscountTypes[variantKey] == 1 && discount > 100) {
      Future.delayed(Duration(milliseconds: 100), () {
        _formKey.currentState!.patchValue({
          '${variantKey}.discount': '100',
        });
      });
      return;
    }
    if (mounted) {
      setState(() {});
    }
  }

  void checkCommissionVariant(String variantKey) {
    if (_isLoading) return;
    num commission = variantCommissionTypes[variantKey] == false
        ? stringToInt(
                _formKey.currentState?.value['${variantKey}.commission']) ??
            0
        : stringToDouble(
                _formKey.currentState?.value['${variantKey}.commission']) ??
            0;

    if (variantCommissionTypes[variantKey] == true && commission > 100) {
      Future.delayed(Duration(milliseconds: 100), () {
        _formKey.currentState!.patchValue({
          '${variantKey}.commission': '100',
        });
      });
      return;
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: !isEdit() || isClone == true
              ? Text(
                  'Thêm sản phẩm',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                )
              : Text(
                  'Sửa sản phẩm',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.settings,
                color: Colors.white,
                size: 25,
              ),
              onPressed: () {
                // clearAllData();
                routeTo(SettingProductPage.path, onPop: (value) {
                  _afterSetting = true;
                  init();
                });
              },
            )
          ]),
      body: SafeArea(
          child: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FormBuilder(
                key: _formKey,
                onChanged: () {
                  _formKey.currentState!.save();
                },
                autovalidateMode: AutovalidateMode.disabled,
                child: Column(
                  children: [
                    if (isScanningBarcode()) SizedBox(height: 250),
                    buildStepDetail(),
                    buildStepPrices(),
                    buildFoodType(),
                    buildStepImages(),
                    buildStepNote(),
                    if (![1, 2, 3, 4, 5, 12]
                        .contains(Auth.user<User>()?.businessId))
                      if (Auth.user<User>()!.showImei ||
                          ![1, 2, 3, 4, 5, 12]
                              .contains(Auth.user<User>()?.businessId))
                        buildStepStorage(),
                    if ([2, 12].contains(Auth.user<User>()?.businessId))
                      buildTopping(),
                    if ([2, 12].contains(Auth.user<User>()?.businessId))
                      buildShowMenu(),
                    buildBuyAlway(),
                    if (isShowAttributes && isShowUnit) Divider(height: 20),
                    Container(
                      width: double.infinity,
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                      child: Row(
                        children: [
                          Expanded(
                            flex: (!isEdit() || isClone == true) ? 3 : 1,
                            child: Container(
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor:
                                      ThemeColor.get(context).primaryAccent,
                                  elevation: 2,
                                  shadowColor: Colors.black26,
                                ),
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        if (_formKey.currentState!
                                            .saveAndValidate()) {
                                          saveProduct();
                                        }
                                      },
                                child: _isLoading
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            (isEdit() && isClone == false)
                                                ? Icons.done
                                                : Icons.add,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              (isEdit() && isClone == false)
                                                  ? 'Cập nhật'
                                                  : 'Tạo SP',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                          if (!isEdit() || isClone == true) ...[
                            SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Container(
                                height: 48,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    side: BorderSide(
                                      color:
                                          ThemeColor.get(context).primaryAccent,
                                      width: 1.5,
                                    ),
                                    backgroundColor: Colors.transparent,
                                  ),
                                  onPressed: _isLoading
                                      ? null
                                      : () {
                                          isContinue = true;
                                          if (_formKey.currentState!
                                              .saveAndValidate()) {
                                            saveProduct();
                                          }
                                        },
                                  child: _isLoading
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            color: ThemeColor.get(context)
                                                .primaryAccent,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.add_circle_outline,
                                              color: ThemeColor.get(context)
                                                  .primaryAccent,
                                            ),
                                            SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                'Tạo tiếp',
                                                style: TextStyle(
                                                  color: ThemeColor.get(context)
                                                      .primaryAccent,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
          if (isScanningBarcode())
            Column(
              children: [
                SizedBox(
                  height: 210,
                  child: MobileScanner(
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;

                      Barcode barcode = barcodes[0];

                      if (_formKey.currentState!.fields[_scanningInputName] ==
                          null) {
                        return;
                      }

                      // set form
                      _formKey.currentState!.fields[_scanningInputName]!
                          .didChange(barcode.rawValue ?? '');

                      setState(() {
                        _scanningInputName = '';
                      });
                    },
                  ),
                ),
                // close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _scanningInputName = '';
                        });
                      },
                      icon: Icon(Icons.close, color: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          if (_isFetching)
            // show loading when fetching data full screen
            Container(
              width: double.infinity,
              height: double.infinity,
              child: Center(
                child: CircularProgressIndicator(
                    color: ThemeColor.get(context).primaryAccent),
              ),
            ),
        ],
      )),
    );
  }

  void clearAllData() {
    _formKey.currentState?.reset();
    setState(() {
      images.clear();
      savedImages.clear();
      savedImagesVariant.clear();
      variantImages.clear();
      productName = '';
      isShowAttributes = false;
      isShowUnit = false;
      isBuyAlway = true;
      isTopping = false;
      isBatchStorage = false;
      isSyncConversion = false;
      isShowMenu = true;
      useVat = true;
      _selectedWeightUnit = null;
      discountType = 1;
      foodType = null;
      variantDiscountTypes.clear();
      variantCommissionTypes.clear();
      variantFoodTypes.clear();
      variantInitValue.clear();
      variantKeyToId.clear();
      unitToQuantity.clear();
      selectedVariantKeys.clear();
      excludedVariantKeys.clear();
      isContinue = false;
    });
  }

  Widget buildStepDetail() {
    return Column(
      children: [
        FormBuilderTextField(
          name: 'name',
          keyboardType: TextInputType.streetAddress,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          onChanged: (value) {
            setState(() {
              productName = value ?? '';
            });
          },
          onTapOutside: (value) {
            FocusScope.of(context).unfocus();
          },
          decoration: InputDecoration(
            labelText: 'Tên sản phẩm',
          ),
          validator: FormBuilderValidators.compose([
            FormBuilderValidators.required(),
          ]),
          textInputAction: TextInputAction.next,
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
        SizedBox(height: 12),
        buildCodeAndBarcode(),
        buildWeightUnit()
      ],
    );
  }

  Widget buildCodeAndBarcode() {
    if (featuresConfig['product_code'] != true &&
        featuresConfig['product_barcode'] != true) {
      return Container();
    }
    if (featuresConfig['product_code'] == true &&
        featuresConfig['product_barcode'] != true) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FormBuilderTextField(
                  name: 'sku',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Mã sản phẩm/SKU',
                  ),
                  onTapOutside: (value) {
                    FocusScope.of(context).unfocus();
                  },
                  textInputAction: TextInputAction.next,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
        ],
      );
    }
    if (featuresConfig['product_barcode'] == true &&
        featuresConfig['product_code'] != true) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FormBuilderTextField(
                  name: 'bar_code',
                  // validator: FormBuilderValidators.compose([barcodeValidator]),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  onTapOutside: (value) {
                    FocusScope.of(context).unfocus();
                  },
                  decoration: InputDecoration(
                    labelText: 'Mã vạch/Barcode',
                    suffixIcon: IconButton(
                      icon: Icon(FontAwesomeIcons.barcode, size: 30),
                      onPressed: () {
                        setState(() {
                          _scanningInputName = 'bar_code';
                        });
                      },
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
        ],
      );
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FormBuilderTextField(
                name: 'sku',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Mã sản phẩm/SKU',
                ),
                onTapOutside: (value) {
                  FocusScope.of(context).unfocus();
                },
                textInputAction: TextInputAction.next,
              ),
            ),
            SizedBox(
              width: 12,
            ),
            Expanded(
              child: FormBuilderTextField(
                name: 'bar_code',
                // validator: FormBuilderValidators.compose([barcodeValidator]),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                onTapOutside: (value) {
                  FocusScope.of(context).unfocus();
                },
                decoration: InputDecoration(
                  labelText: 'Mã vạch/Barcode',
                  suffixIcon: IconButton(
                    icon: Icon(FontAwesomeIcons.barcode, size: 30),
                    onPressed: () {
                      setState(() {
                        _scanningInputName = 'bar_code';
                      });
                    },
                  ),
                ),
                textInputAction: TextInputAction.next,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
      ],
    );
  }

  Widget buildWeightUnit() {
    return Column(
      children: [
        Row(
          children: [
            if (featuresConfig['product_weight'] == true)
              Expanded(
                child: _buildWeightField(),
              ),
            if (featuresConfig['product_weight'] == true &&
                (featuresConfig['product_weight_unit'] == true ||
                    featuresConfig['product_unit'] == true))
              SizedBox(width: 12),
            if (featuresConfig['product_weight_unit'] == true)
              SizedBox(
                width: 80,
                child: _buildWeightUnitDropdown(),
              ),
            if (featuresConfig['product_weight_unit'] == true &&
                (featuresConfig['product_unit'] == true))
              SizedBox(width: 12),
            if (featuresConfig['product_unit'] == true)
              Expanded(
                child: _buildUnitField(),
              ),
            if (featuresConfig['product_unit'] == true) SizedBox(width: 12),
          ],
        ),
      ],
    );
  }

  Widget _buildWeightField() {
    return FormBuilderTextField(
      name: 'weight',
      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      decoration: InputDecoration(
        labelText: 'Trọng lượng SP',
      ),
      onTapOutside: (value) {
        FocusScope.of(context).unfocus();
      },
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(r'^[1-9]\d*'),
        ),
      ],
    );
  }

  Widget _buildWeightUnitDropdown() {
    return FormBuilderDropdown(
      key: _dropdownKey,
      name: 'weight_unit',
      decoration: InputDecoration(),
      onChanged: (value) {
        setState(() {
          _selectedWeightUnit = value;
        });
      },
      items: [
        DropdownMenuItem(
          value: 'kg',
          child: Text(
            'kg',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        DropdownMenuItem(
          value: 'g',
          child: Text(
            'g',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        DropdownMenuItem(
          value: 'l',
          child: Text(
            'l',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        DropdownMenuItem(
          value: 'ml',
          child: Text(
            'ml',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildUnitField() {
    return FormBuilderField(
        name: 'unit',
        builder: (FormFieldState<dynamic> field) {
          return Autocomplete(
              optionsBuilder: (TextEditingValue textEditingValue) {
            return defaultUnit;
          }, onSelected: (String selection) {
            field.didChange(selection);
          }, fieldViewBuilder: (BuildContext context,
                  TextEditingController textEditingController,
                  FocusNode focusNode,
                  VoidCallback onFieldSubmitted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              textEditingController.text = field.value ?? '';
            });
            return TextFormField(
              keyboardType: TextInputType.streetAddress,
              controller: textEditingController,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              focusNode: focusNode,
              onTapOutside: (e) {
                FocusScope.of(context).unfocus();
              },
              decoration: InputDecoration(
                labelText: 'Đơn vị tính',
              ),
              textInputAction: TextInputAction.next,
              onChanged: (value) {
                field.didChange(value);
              },
            );
          });
        });
  }

  String? barcodeValidator(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    final regex = RegExp(r'^[0-9]{11,12}$');
    if (!regex.hasMatch(value)) {
      return 'Mã vạch không hợp lệ';
    }

    return null;
  }

  // Hiển thị giá nhập
  Widget buildBaseCost() {
    if (featuresConfig['product_base_cost'] != true) return SizedBox();
    return Expanded(
      child: FormBuilderTextField(
        name: 'base_cost',
        onChanged: (value) {},
        initialValue: '0',
        focusNode: _baseCostFocusNode,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        decoration: InputDecoration(labelText: 'Giá nhập'),
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        inputFormatters: [
          CurrencyTextInputFormatter(locale: 'vi', symbol: ''),
        ],
      ),
    );
  }

  // Hiển thị giá bán lẻ
  Widget buildRetailCost() {
    if (featuresConfig['product_retail_cost'] != true) return SizedBox();
    return Expanded(
      child: FormBuilderTextField(
        name: 'retail_cost',
        initialValue: '0',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        decoration: InputDecoration(labelText: 'Giá bán lẻ'),
        focusNode: _retailCostFocusNode,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        inputFormatters: [
          CurrencyTextInputFormatter(locale: 'vi', symbol: ''),
        ],
      ),
    );
  }

  // Hiển thị giá buôn
  Widget buildWholesaleCost() {
    if (featuresConfig['product_whoolsale_cost'] != true) return SizedBox();
    return Expanded(
      child: FormBuilderTextField(
        name: 'wholesale_cost',
        initialValue: '0',
        focusNode: _wholesaleCostFocusNode,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        decoration: InputDecoration(labelText: 'Giá buôn'),
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        inputFormatters: [
          CurrencyTextInputFormatter(locale: 'vi', symbol: ''),
        ],
      ),
    );
  }

  // Widget chiết khấu (luôn hiển thị nếu !isTopping)
  Widget buildDiscountField() {
    if (isTopping) return SizedBox();
    return Expanded(
      child: FormBuilderTextField(
        controller: discountController,
        name: 'discount',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        onChanged: (value) {
          checkDiscountProduct();
        },
        onTapOutside: (event) {
          FocusScope.of(context).unfocus();
        },
        cursorColor: ThemeColor.get(context).primaryAccent,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          labelText: 'Chiết khấu',
          labelStyle: TextStyle(color: Colors.grey[700]),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: ThemeColor.get(context).primaryAccent,
            ),
          ),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: SizedBox(
                child: CupertinoSlidingSegmentedControl<int>(
              thumbColor: ThemeColor.get(context).primaryAccent,
              onValueChanged: (int? value) {
                // update format
                if (value == 1) {
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
                  discountType = value!;
                });
              },
              children: {
                1: Container(
                  child: Text(
                    '%',
                    style: TextStyle(
                        color: discountType == 1 ? Colors.white : Colors.black),
                  ),
                ),
                2: Container(
                  child: Text(
                    'đ',
                    style: TextStyle(
                        color: discountType == 2 ? Colors.white : Colors.black),
                  ),
                )
              },
              groupValue: discountType,
            )),
          ),
          hintText: '0',
          suffixText: discountType == DiscountType.percent ? '' : '',
        ),
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        inputFormatters: discountType == 1
            ? [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ]
            : [
                CurrencyTextInputFormatter(locale: 'vi', symbol: ''),
                FilteringTextInputFormatter.deny(RegExp(r'-')),
              ],
      ),
    );
  }

  // Sử dụng trong buildStepPrices:
  Widget buildStepPrices() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 15),
        Text('Giá sản phẩm (VNĐ)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 12),
        Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            initiallyExpanded: true,
            title: Row(
              children: [
                if (featuresConfig['product_base_cost'] == true)
                  buildBaseCost(),
                if (featuresConfig['product_base_cost'] == true &&
                    (featuresConfig['product_retail_cost'] == true ||
                        featuresConfig['product_whoolsale_cost'] == true))
                  SizedBox(width: 5),
                if (featuresConfig['product_retail_cost'] == true)
                  buildRetailCost(),
                if (featuresConfig['product_retail_cost'] == true &&
                    featuresConfig['product_whoolsale_cost'] == true)
                  SizedBox(width: 5),
                if (featuresConfig['product_whoolsale_cost'] == true &&
                    Auth.user<User>()!.showWholeSale)
                  buildWholesaleCost(),
              ],
            ),
            children: [
              Column(
                children: [
                  SizedBox(
                    height: 5,
                  ),
                  buildListPrice(),
                  SizedBox(
                    height: 5,
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            buildDiscountField(),
            if (featuresConfig['product_vat'] == true) SizedBox(width: 5),
            buildVATField(),
          ],
        ),
      ],
    );
  }

  Widget buildListPrice() {
    return Row(
      children: [
        Expanded(
          child: FormBuilderTextField(
            name: 'base_cost',
            onChanged: (value) {},
            initialValue: '0',
            focusNode: _baseCostFocusNode,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Giá nhập',
            ),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              CurrencyTextInputFormatter(
                locale: 'vi',
                symbol: '',
              )
            ],
          ),
        ),
        SizedBox(
          width: 12,
        ),
        Expanded(
          child: FormBuilderTextField(
            name: 'retail_cost',
            initialValue: '0',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Giá bán lẻ',
            ),
            focusNode: _retailCostFocusNode,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              CurrencyTextInputFormatter(
                locale: 'vi',
                symbol: '',
              )
            ],
          ),
        ),
        Visibility(
          visible: Auth.user<User>()!.showWholeSale,
          child: SizedBox(
            width: 12,
          ),
        ),
        Visibility(
          visible: Auth.user<User>()!.showWholeSale,
          child: Expanded(
            child: FormBuilderTextField(
              name: 'wholesale_cost',
              initialValue: '0',
              focusNode: _wholesaleCostFocusNode,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Giá buôn',
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                CurrencyTextInputFormatter(
                  locale: 'vi',
                  symbol: '',
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget buildVATField() {
    if (featuresConfig['product_vat'] != true) return SizedBox();
    return Expanded(
      child: FormBuilderTextField(
        name: 'vat',
        onTapOutside: (event) => FocusScope.of(context).unfocus(),
        textAlign: TextAlign.right,
        cursorColor: ThemeColor.get(context).primaryAccent,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        decoration: InputDecoration(
          labelText: 'VAT',
          hintText: '0',
          suffixText: '%',
          labelStyle: TextStyle(color: Colors.grey[700]),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: ThemeColor.get(context).primaryAccent,
            ),
          ),
        ),
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
        ],
      ),
    );
  }

  Widget buildFoodType() {
    if (featuresConfig['food_type'] != true) {
      return Container();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 15),
        Row(
          children: [
            Text('Loại sản phẩm',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    title: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: ThemeColor.get(context)
                                .primaryAccent
                                .withOpacity(0.1),
                          ),
                          child: Icon(Icons.info_outline,
                              color: ThemeColor.get(context).primaryAccent),
                        ),
                        SizedBox(width: 8),
                        Text('Hướng dẫn',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    content: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 16, color: Colors.black),
                        children: [
                          TextSpan(
                            text: 'Phân loại để tự động in báo chế biến:\n',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          WidgetSpan(
                            child: Icon(Icons.local_drink,
                                size: 16, color: foodTypeColors[1]),
                          ),
                          TextSpan(text: ' Đồ uống → In tại quầy (máy in 1)\n'),
                          WidgetSpan(
                            child: Icon(Icons.restaurant,
                                size: 16, color: foodTypeColors[2]),
                          ),
                          TextSpan(text: ' Đồ ăn → In trong bếp (máy in 2)\n'),
                          WidgetSpan(
                            child: Icon(Icons.block,
                                size: 16, color: foodTypeColors[null]),
                          ),
                          TextSpan(text: ' Không → In mặc định (máy in 1)'),
                        ],
                      ),
                    ),
                    actions: [
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Đã hiểu',
                              style: TextStyle(
                                  color:
                                      ThemeColor.get(context).primaryAccent)),
                        ),
                      ),
                    ],
                  ),
                );
              },
              child: Icon(Icons.help_outline,
                  size: 20, color: ThemeColor.get(context).primaryAccent),
            ),
          ],
        ),
        SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: SegmentedButton<int?>(
            segments: [
              ButtonSegment<int?>(
                value: null,
                label: Text('Không',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                icon: Icon(Icons.block),
              ),
              ButtonSegment<int?>(
                value: 2,
                label: Text(FoodType.fromValueRequest(2).name ?? '',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                icon: Icon(Icons.restaurant, color: foodTypeColors[2]),
              ),
              ButtonSegment<int?>(
                value: 1,
                label: Text(FoodType.fromValueRequest(1).name ?? '',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                icon: Icon(Icons.local_drink, color: foodTypeColors[1]),
              ),
            ],
            selected: {foodType?.value},
            onSelectionChanged: (Set<int?> newSelection) {
              setState(() {
                int? selectedValue = newSelection.first;
                foodType = selectedValue != null
                    ? FoodType.fromValueRequest(selectedValue)
                    : null;
              });
            },
            style: SegmentedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              backgroundColor: Colors.white,
              foregroundColor: Colors.grey.shade700,
              selectedForegroundColor: Colors.white,
              selectedBackgroundColor: ThemeColor.get(context).primaryAccent,
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildStepImages() {
    if (featuresConfig['product_image'] != true) {
      return Container();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 15),
        Text('Ảnh sản phẩm',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        (savedImages?.length ?? 0) + (images?.length ?? 0) >= 3
            ? Container()
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: pickImage,
                    label: Text(
                      'Chọn ảnh',
                      style: TextStyle(
                          color: ThemeColor.get(context).primaryAccent),
                    ),
                    icon: Icon(
                      Icons.image,
                      color: ThemeColor.get(context).primaryAccent,
                    ),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: takePicture,
                    label: Text(
                      'Chụp ảnh',
                      style: TextStyle(
                          color: ThemeColor.get(context).primaryAccent),
                    ),
                    icon: Icon(
                      Icons.camera_alt,
                      color: ThemeColor.get(context).primaryAccent,
                    ),
                  ),
                ],
              ),
        SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(images.length, (index) {
            return Stack(
              children: [
                Image.file(
                  File(images[index].path),
                  width: 100,
                  height: 100,
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        images.removeAt(index);
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
        SizedBox(height: 10),
        Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(savedImages.length, (index) {
              return Stack(
                children: [
                  Image.network(
                    savedImages[index],
                    width: 100,
                    height: 100,
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          savedImages.removeAt(index);
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }))
      ],
    );
  }

  Widget buildStepNote() {
    if (featuresConfig['product_note'] != true) {
      return Container();
    }

    return Column(
      children: [
        Divider(height: 20),
        Row(
          children: [
            Text('Mô tả sản phẩm',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        FormBuilderTextField(
            name: 'note',
            keyboardType: TextInputType.streetAddress,
            onTapOutside: (event) {
              FocusScope.of(context).unfocus();
            },
            onChanged: (vale) {
              setState(() {});
            },
            cursorColor: ThemeColor.get(context).primaryAccent,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(vertical: 10),
              prefixIcon: Icon(
                Icons.edit_note_rounded,
                color: Colors.grey[500],
                size: 30,
              ),
              hintText: "Nhập mô tả cho sản phẩm",
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[500]!)),
              focusedBorder: UnderlineInputBorder(
                  borderSide:
                      BorderSide(color: ThemeColor.get(context).primaryAccent)),
            )),
        SizedBox(height: 10),
      ],
    );
  }

  Widget buildTopping() {
    return Column(children: [
      Row(
        children: [
          Text('Là món thêm',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Spacer(),
          Switch(
              inactiveThumbColor: Colors.white,
              activeColor: ThemeColor.get(context).primaryAccent,
              value: isTopping,
              onChanged: (value) {
                setState(() {
                  isTopping = value;
                });
              })
        ],
      )
    ]);
  }

  Widget buildShowMenu() {
    return Column(children: [
      Divider(height: 20),
      Row(
        children: [
          Text('Hiển thị trong menu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Spacer(),
          Switch(
              inactiveThumbColor: Colors.white,
              activeColor: ThemeColor.get(context).primaryAccent,
              value: isShowMenu,
              onChanged: (value) {
                setState(() {
                  isShowMenu = value;
                });
              })
        ],
      )
    ]);
  }

  Widget buildBuyAlway() {
    if (featuresConfig['product_buy_alway'] != true) {
      return Container();
    }
    return Column(children: [
      Divider(height: 20),
      Row(
        children: [
          Text('Cho phép bán âm',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Spacer(),
          Switch(
              inactiveThumbColor:
                  (isBatchStorage || isImei) ? Colors.grey[400] : Colors.white,
              activeColor: ThemeColor.get(context).primaryAccent,
              value: isBuyAlway,
              onChanged: (value) {
                setState(() {
                  (isBatchStorage || isImei) ? null : isBuyAlway = value;
                });
              })
        ],
      )
    ]);
  }

  Widget buildStepStorage() {
    if (featuresConfig['product_storage'] != true) {
      return Container();
    }

    if (!isEdit() || isClone) {
      return Column(
        children: [
          Divider(height: 20),
          Row(
            children: [
              Text('Khởi tạo kho hàng',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Spacer(),
              Switch(
                inactiveThumbColor:
                    isBatchStorage ? Colors.grey[400] : Colors.white,
                activeColor: ThemeColor.get(context).primaryAccent,
                value: isShowStorage,
                onChanged: (value) {
                  isBatchStorage
                      ? null
                      : setState(() {
                          isShowStorage = value;
                        });
                },
              ),
            ],
          ),
          if (isShowStorage)
            Row(
              children: [
                Expanded(
                  child: FormBuilderTextField(
                    name: 'in_stock',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    // enabled: !isEdit(),
                    decoration: InputDecoration(
                      helperText: '',
                      labelText: 'Tồn kho ban đầu',
                    ),
                    onChanged: (value) {
                      setState(() {
                        // _formKey.currentState?.patchValue({
                        //   '${getVariantKeys().last}.in_stock': value,
                        // });
                      });
                    },
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,3}')),
                    ],
                    validator: (value) {
                      if ((value == null || value.isEmpty) &&
                          (_formKey.currentState?.fields['entry_cost']?.value !=
                                  null &&
                              _formKey.currentState?.fields['entry_cost']?.value
                                  .isNotEmpty)) {
                        return 'Vui lòng nhập số lượng tồn kho';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(
                  width: 12,
                ),
                Expanded(
                  child: FormBuilderTextField(
                      name: 'entry_cost',
                      initialValue:
                          _formKey.currentState?.fields['base_cost']?.value ??
                              '',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      decoration: InputDecoration(
                        helperText: '',
                        labelText: 'Giá nhập',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        CurrencyTextInputFormatter(
                          locale: 'vi',
                          symbol: '',
                        )
                      ],
                      validator: (value) {
                        if ((value == null || value.isEmpty) &&
                            (_formKey.currentState?.fields['in_stock']?.value !=
                                    null &&
                                _formKey.currentState?.fields['in_stock']?.value
                                    .isNotEmpty)) {
                          return 'Vui lòng điền giá nhập hàng';
                        }
                        return null;
                      }),
                ),
              ],
            ),
        ],
      );
    } else {
      return Column(
        children: [
          Divider(height: 20),
          Row(
            children: [
              Text('Khởi tạo kho hàng',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Spacer(),
              Switch(
                  value: isShowStorage,
                  onChanged: null,
                  inactiveThumbColor: Colors.grey[400],
                  inactiveTrackColor: Colors.grey[300]),
            ],
          ),
          Container(
            alignment: Alignment.centerLeft,
            child: Text(
              'Bạn vui lòng vào tạo phiếu kiểm kho nếu cần sửa kho',
              style: TextStyle(color: Colors.red, fontSize: 12.0),
            ),
          ),
        ],
      );
    }
  }

  FormBuilderTextField buildFormPriceBuilder(
      BuildContext context, data, variantKey, text) {
    var builderTextController = TextEditingController();
    builderTextController.text = variantInitValue[variantKey] ?? data ?? '';

    return FormBuilderTextField(
      name: variantKey,
      controller: builderTextController,
      // initialValue: variantInitValue[variantKey] ?? data,
      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      decoration: InputDecoration(
        labelText: text,
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [
        CurrencyTextInputFormatter(
          locale: 'vi',
          symbol: '',
        )
      ],
    );
  }
}

class TruncatedLabelText extends StatelessWidget {
  final String text1;
  final String text2;
  final double maxWidth;
  final TextStyle style;

  const TruncatedLabelText({
    super.key,
    required this.text1,
    required this.text2,
    required this.maxWidth,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final TextPainter painter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );

    painter.text = TextSpan(text: text2, style: style);
    painter.layout();
    final text2Width = painter.width;

    final allowedWidth = maxWidth - text2Width;

    String truncated = text1;
    painter.text = TextSpan(text: text1, style: style);
    painter.layout(maxWidth: allowedWidth);

    if (painter.didExceedMaxLines) {
      for (int i = text1.length - 1; i >= 0; i--) {
        String attempt = text1.substring(0, i) + '...';
        painter.text = TextSpan(text: attempt, style: style);
        painter.layout(maxWidth: allowedWidth);
        if (!painter.didExceedMaxLines) {
          truncated = attempt;
          break;
        }
      }
    }

    return RichText(
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: truncated),
          TextSpan(text: text2),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.clip,
    );
  }
}
