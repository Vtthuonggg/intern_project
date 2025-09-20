import 'package:collection/collection.dart';
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/app/models/category.dart';
import 'package:flutter_app/app/models/storage_item.dart';
import 'package:flutter_app/app/utils/formatters.dart';
import 'package:flutter_app/bootstrap/helpers.dart';
import 'package:flutter_app/resources/dashed_divider.dart';
import 'package:flutter_app/resources/pages/custom_toast.dart';
import 'package:flutter_app/resources/widgets/single_tap_detector.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:intl/intl.dart';

enum CostType {
  retail,
  wholesale,
  base,
  another,
}

extension CostTypeExtension on CostType {
  static num getCost(StorageItem item, CostType costType) {
    switch (costType) {
      case CostType.retail:
        return item.retailCost ?? 0;
      case CostType.wholesale:
        return item.wholesaleCost ?? 0;
      case CostType.base:
        return item.baseCost ?? 0;
      case CostType.another:
        return 1;
      default:
        return 0;
    }
  }
}

class OrderStorageItem extends StatelessWidget {
  final StorageItem item;
  final bool isImei;
  final int index;
  int? currentPolicy;
  final CostType costType;
  final List<dynamic>? listBatch;
  final List<dynamic>? selectedBatch;
  final Function() updatePaid;
  final Function(int type)? filterBatch;
  final Function(String?)? updateQuantity;
  final Function(StorageItem) removeItem;
  final Function() onMinusQuantity;
  final Function() getPrice;
  final Function(String?) onChangeQuantity;
  final Function() onIncreaseQuantity;
  final Function(String?) onChangePrice;
  final Function(String?) onChangeDiscount;
  final Function(DiscountType?) onChangeDiscountType;
  final Function(List<String>) onChangeImei;
  void Function(String)? onSizeChange = null;
  void Function(String)? onVATChange = null;
  void Function(int)? onCategoryChange = null;
  dynamic selectedSalePromotion;
  List<CategoryModel>? categories = [];
  Map<String, bool> featuresConfig = {};
  OrderStorageItem({
    super.key,
    required this.item,
    required this.index,
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
    required this.onChangeImei,
    required this.isImei,
    this.onSizeChange,
    this.onVATChange,
    this.onCategoryChange,
    this.categories,
    this.featuresConfig = const {},
    this.updateQuantity,
    this.filterBatch,
    this.listBatch,
    this.selectedBatch,
    this.currentPolicy,
    this.selectedSalePromotion,
  });

  List<dynamic> batchs = [];
  num quantityBatch() {
    num total = 0;
    for (var item in selectedBatch!) {
      total += item['quantity'] ?? 0;
    }
    return total;
  }

  String itemPromotionPrice() {
    if (item.selectedSalePromotion == null) return '';
    int price = stringToInt(item.txtPrice.text) ?? 0;
    final discount = item.discount ?? 0;
    final discountType = item.discountType.getValueRequest();
    if (discountType == 1) {
      return '${vndCurrency.format(price * item.quantity * discount / 100)}';
    } else {
      return '${vndCurrency.format(discount)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    String? productType = item.sku != null
        ? (item.sku!.contains('-') ? item.sku?.split('-').last : null)
        : null;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  productType != null
                      ? "${index + 1}. ${item.name ?? ''} - $productType"
                      : "${index + 1}. ${item.name ?? ''} ",
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
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(10.0)),
                      color: (!isImei && item.product?.isBatch != true)
                          ? ThemeColor.get(context).primaryAccent
                          : Colors.grey.shade400),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 30,
                          height: 40,
                          child: SingleTapDetector(
                            onTap: () {
                              if (isImei || item.product?.isBatch == true) {
                                return;
                              }
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
                      Expanded(
                        child: Container(
                          width: 55,
                          decoration: BoxDecoration(
                              // border: Border.all(color: Colors.grey),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10.0)),
                              color: Colors.white),
                          // height: 36,
                          child: FormBuilderTextField(
                            onTapOutside: (value) {
                              FocusScope.of(context).unfocus();
                            },
                            readOnly: item.product?.isBatch ?? false,
                            enabled: !isImei,
                            key: item.quantityKey,
                            name: '${item.id}.quantity',
                            initialValue: (item.product?.isBatch == true
                                ? roundQuantity(quantityBatch())
                                : roundQuantity(item.quantity)),
                            onChanged: (value) {
                              if (isImei) {
                                return;
                              }
                              onChangeQuantity(value);
                            },
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
                            keyboardType: TextInputType.numberWithOptions(
                                signed: true, decimal: true),
                            validator: FormBuilderValidators.compose([]),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,3}'),
                              ),
                            ],
                            decoration: InputDecoration(
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.never,
                              hintText: '0',
                              suffixText: '',
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                          width: 30,
                          height: 40,
                          child: SingleTapDetector(
                            onTap: () {
                              if (isImei || item.product?.isBatch == true) {
                                return;
                              }
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
              ),
              8.horizontalSpace,
              Expanded(
                child: Container(
                  height: 40,
                  // height: 36,
                  child: FormBuilderTextField(
                    onTapOutside: (value) {
                      FocusScope.of(context).unfocus();
                    },
                    readOnly: costType == CostType.base,
                    key: item.priceKey,
                    name: '${item.id}.price',
                    controller: item.txtPrice,
                    onChanged: (value) {
                      onChangePrice(value);
                    },
                    onTap: () {
                      item.isUserTyping = true;
                    },
                    onEditingComplete: () {
                      item.isUserTyping = false;
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
                        borderRadius: BorderRadius.circular(10),
                      ),
                      floatingLabelBehavior: FloatingLabelBehavior.never,
                      suffixText: 'đ',
                      hintText: '0',
                    ),
                  ),
                ),
              ),
              8.horizontalSpace,
              if (costType == CostType.base ||
                  featuresConfig['product_discount'] == true)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                          child: SizedBox(
                        height: 40,
                        child: FormBuilderTextField(
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          onTapOutside: (value) {
                            FocusScope.of(context).unfocus();
                          },
                          key: item.discountKey,
                          textAlign: TextAlign.right,
                          initialValue: (item.discount ?? 0) != 0
                              ? (item.discountType == DiscountType.percent
                                  ? roundQuantity(item.discount ?? 0)
                                  : vnd.format(
                                      (item.discount ?? 0) / item.quantity))
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
                                          fontWeight: FontWeight.bold,
                                          color: item.discountType ==
                                                  DiscountType.percent
                                              ? Colors.white
                                              : Colors.black)),
                                ),
                                DiscountType.price: Container(
                                  child: Text('đ',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
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
                            suffixText:
                                item.discountType == DiscountType.percent
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
          4.verticalSpace,
          Row(
            children: [
              if (item.product?.unit != null &&
                  item.product!.unit!.isNotEmpty &&
                  (costType == CostType.base ||
                      featuresConfig['sub_unit_quantity'] == true)) ...[
                buildSubUnit(context),
                SizedBox(width: 10),
              ],
              if (costType == CostType.base && item.product?.useVat != false)
                buildVAT(context)
            ],
          ),
          if (featuresConfig['select_category'] == true ||
              featuresConfig['input_size'] == true ||
              (featuresConfig['vat'] == true &&
                  item.product?.useVat != false)) ...[
            8.verticalSpace,
            SizedBox(
              height: 40,
              width: double.infinity,
              child: Row(
                children: [
                  if (featuresConfig['vat'] == true &&
                      item.product?.useVat != false)
                    buildVAT(context),
                ],
              ),
            ),
            8.verticalSpace,
          ],
          if (item.product?.isBatch == true) buildBatch(context),
          if (featuresConfig['order_form'] == true) buildNoteProduct(context),
          8.verticalSpace,
          if (item.selectedSalePromotion != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('${item.selectedSalePromotion['name']}: ',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: Colors.grey[700])),
                Text(itemPromotionPrice(),
                    style: TextStyle(
                        color: Colors.pink[500], fontWeight: FontWeight.bold)),
              ],
            )
          ],
          Row(
            children: [
              Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 3, horizontal: 8),
                    decoration: BoxDecoration(
                      color: ThemeColor.get(context)
                          .primaryAccent
                          .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.payments,
                      color: ThemeColor.get(context).primaryAccent,
                      size: 16,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text.rich(
                    TextSpan(
                      text: 'Tổng tiền: ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                      children: <TextSpan>[
                        TextSpan(
                          text: costType == CostType.base
                              ? '${vndCurrency.format(getPrice())}'
                              : vndCurrency.format(getPrice()),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: ThemeColor.get(context).primaryAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          4.verticalSpace,
          Divider(),
          4.verticalSpace,
        ],
      ),
    );
  }

  Widget buildNoteProduct(context) {
    return FormBuilderTextField(
      name: '${item.id}.note',
      initialValue: (item.productNotes != null && item.productNotes!.isNotEmpty)
          ? item.productNotes![0]['name']
          : '',
      cursorColor: ThemeColor.get(context).primaryAccent,
      onChanged: (value) {
        if (value == null || value.isEmpty) {
          if (item.productNotes != null) {
            item.productNotes!.clear();
          }
          return;
        }

        if (item.productNotes == null) {
          item.productNotes = [
            {'name': value}
          ];
        } else if (item.productNotes!.isEmpty) {
          item.productNotes!.add({'name': value});
        } else {
          item.productNotes![0]['name'] = value;
        }
      },
      keyboardType: TextInputType.streetAddress,
      decoration: InputDecoration(
        labelText: 'Nhập ghi chú',
        labelStyle: TextStyle(color: Colors.grey[700]),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: ThemeColor.get(context).primaryAccent,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  buildBatch(context) {
    batchs = listBatch ??
        []
            .where((element) =>
                element.containsKey('quantity') && element.containsKey('name'))
            .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (costType == CostType.base)
              TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                  ),
                  icon: Icon(
                    Icons.add,
                    size: 16,
                  ),
                  onPressed: () {
                    showAddBatchStorage(item.name ?? '', item, context);
                  },
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Tạo lô mới',
                      style: TextStyle(fontSize: 12),
                    ),
                  )),
            TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                ),
                icon: Icon(
                  Icons.list,
                  size: 15,
                ),
                onPressed: () {
                  showHistoryBatch(context, item.name ?? '');
                },
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Chọn lô sản phẩm',
                    style: TextStyle(fontSize: 12),
                  ),
                )),
          ],
        ),
        ...selectedBatch!.map((batch) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: Colors.blue,
                  ),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '${batch['name'].length > 12 ? batch['name'].substring(0, 12) + '...' : batch['name']} - ${DateFormat('dd/MM/yyyy').format(DateTime.parse(batch['end']))} - SL: ${roundQuantity(batch['quantity'])}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 10),
                  InkWell(
                    onTap: () {
                      showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: Text('Xác nhận xóa'),
                              content: Text(
                                  "Bạn có chắc chắn muốn xóa lô sản phẩm mã '${batch['name']}' không?"),
                              actions: [
                                TextButton(
                                    style: TextButton.styleFrom(
                                        side: BorderSide(
                                          color: ThemeColor.get(context)
                                              .primaryAccent,
                                        ),
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: ThemeColor.get(context)
                                            .primaryAccent),
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    child: Text('Hủy')),
                                TextButton(
                                    style: TextButton.styleFrom(
                                        backgroundColor: ThemeColor.get(context)
                                            .primaryAccent,
                                        foregroundColor: Colors.white),
                                    onPressed: () {
                                      selectedBatch!.remove(batch);
                                      for (var item in listBatch ?? []) {
                                        if (item['id'] ==
                                            batch['variant_batch_id']) {
                                          item['hide'] = false;
                                        }
                                      }
                                      updateQuantity!(
                                          roundQuantity(quantityBatch()));
                                      Navigator.pop(context);
                                    },
                                    child: Text('Xác nhận')),
                              ],
                            );
                          });
                    },
                    child: Icon(
                      Icons.close,
                      color: Colors.red,
                      size: 17,
                    ),
                  ),
                ],
              ),
            )),
        DashedDivider(),
        SizedBox(height: 10),
      ],
    );
  }

  showAddBatchStorage(
    String productName,
    StorageItem item,
    BuildContext context,
  ) {
    String batchCode = '';
    num quantity = 0;
    DateTime? firstDate;

    DateTime? lastDate;
    return showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Thêm lô SP $productName',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Icon(Icons.close),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Divider(),
                  SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          initialValue: batchCode,
                          // keyboardType: TextInputType.visiblePassword,
                          cursorColor: ThemeColor.get(context).primaryAccent,
                          decoration: InputDecoration(
                            hintText: 'Nhập mã lô',
                            labelText: 'Mã lô',
                            labelStyle: TextStyle(color: Colors.grey[700]),
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: ThemeColor.get(context).primaryAccent,
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            batchCode = value;
                          },
                        ),
                      ),
                      SizedBox(width: 5),
                      Expanded(
                        flex: 2,
                        child: FormBuilderTextField(
                          name: 'batch_quantity',
                          initialValue:
                              quantity != 0 ? roundQuantity(quantity) : '',
                          cursorColor: ThemeColor.get(context).primaryAccent,
                          decoration: InputDecoration(
                            hintText: '0',
                            labelText: 'Số lượng',
                            labelStyle: TextStyle(color: Colors.grey[700]),
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: ThemeColor.get(context).primaryAccent,
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            quantity = (value!.isEmpty) ? 0 : num.parse(value);
                          },
                          keyboardType: TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 18),
                  FormBuilderDateTimePicker(
                    initialValue: firstDate,
                    name: 'start',
                    decoration: InputDecoration(
                      labelText: 'Ngày sản xuất',
                      labelStyle: TextStyle(color: Colors.grey[700]),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      hintText: 'Chọn ngày sản xuất',
                      prefixIcon: Icon(
                        Icons.date_range,
                        color: ThemeColor.get(context).primaryAccent,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: ThemeColor.get(context).primaryAccent,
                        ),
                      ),
                    ),
                    inputType: InputType.date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    format: DateFormat('dd-MM-yyyy'),
                    onChanged: (DateTime? dateTime) {
                      firstDate = dateTime;
                    },
                  ),
                  SizedBox(height: 18),
                  FormBuilderDateTimePicker(
                    initialValue: lastDate,
                    name: 'end',
                    decoration: InputDecoration(
                      labelText: 'Ngày hết hạn',
                      labelStyle: TextStyle(color: Colors.grey[700]),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      hintText: 'Chọn ngày hết hạn',
                      prefixIcon: Icon(
                        Icons.date_range,
                        color: ThemeColor.get(context).primaryAccent,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: ThemeColor.get(context).primaryAccent,
                        ),
                      ),
                    ),
                    inputType: InputType.date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    format: DateFormat('dd-MM-yyyy'),
                    onChanged: (DateTime? dateTime) {
                      lastDate = dateTime;
                    },
                  ),
                  SizedBox(height: 15),
                  Divider()
                ],
              ),
            ),
            actions: [
              TextButton(
                  style: TextButton.styleFrom(
                      side: BorderSide(
                        color: ThemeColor.get(context).primaryAccent,
                      ),
                      backgroundColor: Colors.transparent,
                      foregroundColor: ThemeColor.get(context).primaryAccent),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Hủy')),
              TextButton(
                  style: TextButton.styleFrom(
                      backgroundColor: ThemeColor.get(context).primaryAccent,
                      foregroundColor: Colors.white),
                  onPressed: () async {
                    if (batchCode.isEmpty) {
                      CustomToast.showToastError(context,
                          description: 'Vui lòng nhập mã lô');
                      return;
                    }
                    if (lastDate == null) {
                      CustomToast.showToastError(context,
                          description: 'Vui lòng chọn ngày hết hạn');
                      return;
                    }
                    for (var batch in listBatch!) {
                      if (batch['name'] == batchCode) {
                        CustomToast.showToastError(context,
                            description: 'Mã lô đã tồn tại');
                        return;
                      }
                    }
                    listBatch!.add({
                      'name': batchCode,
                      'quantity': quantity,
                      'start': firstDate != null
                          ? firstDate!.toIso8601String()
                          : null,
                      'end': lastDate!.toIso8601String(),
                    });
                    await filterBatch!(1);
                    Navigator.pop(context);
                    updateQuantity!(roundQuantity(quantityBatch()));
                  },
                  child: Text('Lưu')),
            ],
          );
        });
  }

  void showHistoryBatch(BuildContext context, String productName) {
    List<dynamic> listHistoryBatch =
        listBatch ?? [].where((element) => element['hide'] != true).toList();
    List<dynamic> cloneListHistoryBatch = listHistoryBatch
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    List<bool> isSelected =
        List<bool>.filled(cloneListHistoryBatch.length, false);
    bool canSubmit = true;
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              height: 0.8.sh,
              padding: EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Align(
                      alignment: Alignment.center,
                      child: Container(
                        margin: EdgeInsets.all(16.w),
                        child: Text(
                          'Danh sách lô SP $productName',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                  Divider(),
                  Expanded(
                    child: ListView.builder(
                        itemCount: cloneListHistoryBatch.length,
                        itemBuilder: (context, index) {
                          final batch = cloneListHistoryBatch[index];
                          return Column(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    isSelected[index] = !isSelected[index];
                                  });
                                },
                                child: Row(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${batch['name'].length > 12 ? batch['name'].substring(0, 12) + '...' : batch['name']}',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: Color(0xff179A6E)),
                                          ),
                                          SizedBox(
                                            height: 5,
                                          ),
                                          Text(
                                            batch['in_stock'] == null
                                                ? 'Tồn kho: 0 - ${DateFormat('dd/MM/yyyy').format(DateTime.parse(batch['end']))}'
                                                : 'Tồn kho: ${roundQuantity(batch['in_stock'])} - ${DateFormat('dd/MM/yyyy').format(DateTime.parse(batch['end']))}',
                                            style: TextStyle(
                                                color: Colors.grey[700]),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Spacer(),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 80,
                                            height: 40,
                                            child: FormBuilderTextField(
                                              name: 'batch_qty',
                                              keyboardType: TextInputType
                                                  .numberWithOptions(
                                                      decimal: true,
                                                      signed: true),
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .allow(
                                                  RegExp(r'^\d+\.?\d{0,2}'),
                                                ),
                                              ],
                                              onChanged: (value) {
                                                num qty = value!.isNotEmpty
                                                    ? num.parse(value)
                                                    : 0;
                                                num inStock =
                                                    batch['in_stock'] ?? 0;
                                                if (costType !=
                                                        CostType
                                                            .base && //check is'nt add storage order
                                                    qty > inStock) {
                                                  CustomToast.showToastError(
                                                      context,
                                                      description:
                                                          'Không được bán nhiều hơn số tồn kho');
                                                  canSubmit = false;
                                                  setState(() {});
                                                  return;
                                                }
                                                setState(() {
                                                  canSubmit = true;
                                                  batch['quantity'] = qty;
                                                });
                                              },
                                              cursorColor:
                                                  ThemeColor.get(context)
                                                      .primaryAccent,
                                              decoration: InputDecoration(
                                                labelText: 'Số lượng',
                                                labelStyle: TextStyle(
                                                    color: Colors.grey[700]),
                                                floatingLabelBehavior:
                                                    FloatingLabelBehavior
                                                        .always,
                                                hintText: '0',
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                  borderSide: BorderSide(
                                                      color: ThemeColor.get(
                                                              context)
                                                          .primaryAccent),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 10,
                                          ),
                                          isSelected[index]
                                              ? Icon(
                                                  Icons.check_box_rounded,
                                                  color: ThemeColor.get(context)
                                                      .primaryAccent,
                                                )
                                              : Icon(
                                                  Icons.check_box_outline_blank)
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DashedDivider(),
                            ],
                          );
                        }),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                          style: TextButton.styleFrom(
                              side: BorderSide(
                                color: ThemeColor.get(context).primaryAccent,
                              ),
                              backgroundColor: Colors.white,
                              foregroundColor:
                                  ThemeColor.get(context).primaryAccent),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text('Đóng')),
                      SizedBox(width: 15),
                      ElevatedButton(
                          style: TextButton.styleFrom(
                              backgroundColor:
                                  ThemeColor.get(context).primaryAccent,
                              foregroundColor: Colors.white),
                          onPressed: () {
                            if (canSubmit == false) {
                              CustomToast.showToastError(context,
                                  description:
                                      'Không được bán nhiều hơn số tồn kho');
                              return;
                            }

                            for (int i = 0;
                                i < cloneListHistoryBatch.length;
                                i++) {
                              if (isSelected[i]) {
                                if (cloneListHistoryBatch[i]['quantity'] ==
                                        null ||
                                    cloneListHistoryBatch[i]['quantity'] == 0) {
                                  CustomToast.showToastError(context,
                                      description:
                                          'Vui lòng nhập số lượng lô sản phẩm');
                                  return;
                                } else {
                                  bool found = false;
                                  for (var batch in selectedBatch!) {
                                    if (batch['variant_batch_id'] ==
                                        cloneListHistoryBatch[i]['id']) {
                                      batch['quantity'] =
                                          cloneListHistoryBatch[i]['quantity'];
                                      found = true;
                                      break;
                                    }
                                  }
                                  if (!found) {
                                    selectedBatch!.add({
                                      'quantity': cloneListHistoryBatch[i]
                                          ['quantity'],
                                      'variant_batch_id':
                                          cloneListHistoryBatch[i]['id'],
                                      'name': cloneListHistoryBatch[i]['name'],
                                      'end': cloneListHistoryBatch[i]['end'],
                                      'start': cloneListHistoryBatch[i]
                                          ['start'],
                                    });
                                  }
                                  for (var selected in selectedBatch!) {
                                    for (var batch in listBatch!) {
                                      if (batch['id'] ==
                                          selected['variant_batch_id']) {
                                        batch['hide'] = true;
                                      }
                                    }
                                  }
                                }
                              }
                            }
                            updateQuantity!(roundQuantity(quantityBatch()));
                            Navigator.pop(context);
                          },
                          child: Text('Xác nhận')),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  // String getInitPrice() {
  //   if (currentPolicy == null) {
  //     final value = CostTypeExtension.getCost(item, costType);
  //     if (value == 0) {
  //       return hasPermission('view_base_cost_product') ? '' : '*';
  //     }
  //     return costType == CostType.base
  //         ? (hasPermission('view_base_cost_product')
  //             ? vnd.format(value)
  //             : hiddenPrice(value))
  //         : vnd.format(value);
  //   } else {
  //     final priceValue = (item.policies ?? [])
  //         .indexWhere((element) => element['policy_id'] == currentPolicy);
  //     if (priceValue == -1) {
  //       return costType == CostType.wholesale
  //           ? vnd.format(item.wholesaleCost)
  //           : vnd.format(item.retailCost);
  //     }
  //     final dynamic policyValue;
  //     if (item.policies != null) {
  //       policyValue = item.policies![priceValue]['policy_value'];
  //     } else {
  //       policyValue = null;
  //     }

  //     num price = 0;
  //     if (policyValue != null) {
  //       if (policyValue is String) {
  //         price = num.tryParse(policyValue.replaceAll('.', '')) ?? 0;
  //       } else if (policyValue is num) {
  //         price = policyValue;
  //       }
  //     }
  //     return vnd.format(price);
  //   }
  // }

  buildSubUnit(context) {
    return Row(
      children: [
        Text.rich(
          TextSpan(
            text: 'Đơn vị: ',
            style: TextStyle(fontSize: 16),
            children: <TextSpan>[
              TextSpan(
                text: item.product?.unit ?? '',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
        SizedBox(width: 10),
        Text('-'),
        SizedBox(width: 10),
        Text(
          'SL:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: FormBuilderTextField(
              name: '${item.id}.sub_unit_quantity',
              initialValue: item.subUnitQuantity != null
                  ? roundQuantity(item.subUnitQuantity!)
                  : '',
              onChanged: (value) {
                item.subUnitQuantity = stringToDouble(value);
              },
              onTapOutside: (event) {
                FocusScope.of(context).unfocus();
              },
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d+\.?\d{0,3}'),
                ),
              ],
              decoration: InputDecoration(
                floatingLabelBehavior: FloatingLabelBehavior.never,
                hintText: '0',
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
              )),
        ),
      ],
    );
  }

  buildSize(BuildContext context) {
    if (featuresConfig['input_size'] != true) {
      return Container();
    }
    return Expanded(
      child: FormBuilderTextField(
        onTapOutside: (value) {
          FocusScope.of(context).unfocus();
        },
        key: item.sizeKey,
        name: '${item.id}.size',
        initialValue: item.size,
        onChanged: (value) {
          if (value != null) {
            onSizeChange!(value);
          }
        },
        decoration: InputDecoration(
          labelText: 'Kích thước',
          labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget buildVAT(BuildContext context) {
    return Expanded(
      child: FormBuilderTextField(
        name: '${item.id}.vat',
        controller: item.txtVAT,
        onTapOutside: (value) {
          FocusScope.of(context).unfocus();
        },
        enabled: false,
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
            double? parsedValue = double.tryParse(value);
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
          labelText: 'VAT',
          labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget buildCateContainer(ctx, popupWidget) {
    return Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.09),
                  offset: const Offset(0, -13),
                  blurRadius: 31)
            ]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Stack(
              children: [
                Align(
                    alignment: Alignment.center,
                    child: Container(
                      margin: EdgeInsets.all(16),
                      child: Text(
                        'Chọn danh mục',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    )),
                Positioned(
                  right: 0,
                  child: IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 30,
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                    },
                  ),
                )
              ],
            ),
            Flexible(
              child: Container(
                child: popupWidget,
              ),
            ),
            SizedBox(
              height: 16,
            )
          ],
        ));
  }

  Widget buildPopupCategory(
      BuildContext context, CategoryModel cate, bool isSelected) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      leading: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Icon(
            FontAwesomeIcons.shapes,
            size: 30,
            color: ThemeColor.get(context).primaryAccent,
          ),
        ],
      ),
      title: Text("${cate.name}"),
    );
  }

  CategoryModel? getSelectedCategory() {
    if (categories == null) {
      return null;
    }

    final found = categories!
        .firstWhereOrNull((element) => element.id == item.categoryId);

    return found;
  }
}
