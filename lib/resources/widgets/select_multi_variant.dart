import 'dart:async';
import 'dart:developer';

import 'package:collection/collection.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/app/models/category.dart';
import 'package:flutter_app/app/models/storage_item.dart';
import 'package:flutter_app/app/networking/product_api_service.dart';
import 'package:flutter_app/app/utils/formatters.dart';
import 'package:flutter_app/app/utils/getters.dart';
import 'package:flutter_app/bootstrap/helpers.dart';
import 'package:flutter_app/resources/pages/custom_toast.dart';
import 'package:flutter_app/resources/widgets/single_tap_detector.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:nylo_framework/nylo_framework.dart';

import '../../app/utils/message.dart';

class SelectMultiVariant extends NyStatefulWidget {
  bool? isEditOrderPage;
  final void Function(List<StorageItem>? variant) onSelect;
  List<StorageItem> selectedItems;
  GlobalKey<DropdownSearchState<StorageItem>> multiKey;
  String confirmText = 'Tiếp tục đơn hàng';
  int? type;
  bool? isImei;
  String costField;
  bool hideSwitchView;
  SelectMultiVariant(
      {Key? key,
      this.isEditOrderPage,
      this.isImei,
      required this.multiKey,
      required this.onSelect,
      required this.selectedItems,
      this.confirmText = 'Tiếp tục đơn hàng',
      this.type,
      this.hideSwitchView = false,
      this.costField = 'retailCost'})
      : super(key: key);

  @override
  State<SelectMultiVariant> createState() => SelectMultiVariantState();
}

class SelectMultiVariantState extends NyState<SelectMultiVariant> {
  TextEditingController searchBoxController = TextEditingController();
  List<StorageItem> listItemsSelectedTmp = [];
  Timer? _debounce;
  CategoryModel? selectedCate;
  bool isList = true;
  @override
  init() async {
    super.init();
  }

  static const _pageSize = 10;
  final PagingController<int, StorageItem> _pagingController =
      PagingController(firstPageKey: 1);
  String keyword = '';

  @override
  void initState() {
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });
    loadConfig();
    super.initState();
  }

  Future<void> loadConfig() async {
    final storedIsList = await NyStorage.read('isList');
    if (storedIsList != null) {
      setState(() {
        isList = storedIsList == 'true';
      });
    }
  }

  Future<void> saveConfig() async {
    await NyStorage.store('isList', isList);
  }

  _debounceSearch() {
    if (_debounce?.isActive ?? false) {
      _debounce?.cancel();
    }
    _debounce = Timer(const Duration(milliseconds: 1500), () {
      handleSearch();
    });
  }

  handleSearch() {
    if (_debounce?.isActive ?? false) {
      _debounce?.cancel();
    }
    _pagingController.refresh();
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);
    var shortestSide = MediaQuery.of(context).size.shortestSide;
    return DropdownSearch<StorageItem>.multiSelection(
      key: widget.multiKey,
      onBeforePopupOpening: (value) async {
        searchBoxController.text = '';
        keyword = '';
        _pagingController.refresh();
        FocusManager.instance.primaryFocus?.unfocus();
        return true;
      },
      selectedItems: [],
      popupProps: PopupPropsMultiSelection.modalBottomSheet(
          constraints:
              BoxConstraints(maxHeight: shortestSide < 600 ? 0.85.sh : 0.95.sh),
          containerBuilder: (context, popupWidget) {
            return Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                      topLeft: shortestSide < 600
                          ? Radius.circular(20.w)
                          : Radius.circular(10.w),
                      topRight: shortestSide < 600
                          ? Radius.circular(20.w)
                          : Radius.circular(10.w)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.09),
                        offset: const Offset(0, -13),
                        blurRadius: 31)
                  ]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    children: [
                      Align(
                          alignment: Alignment.center,
                          child: Container(
                            margin: shortestSide < 600
                                ? EdgeInsets.all(16.w)
                                : EdgeInsets.all(8.w),
                            child: Text(
                              'Chọn sản phẩm',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          )),
                      Positioned(
                        right: 0.w,
                        top: shortestSide < 600 ? 0.h : 6.h,
                        child: Row(
                          children: [
                            if (widget.hideSwitchView == false)
                              InkWell(
                                onTap: () {
                                  isList = !isList;
                                  saveConfig();
                                  setState(() {});
                                },
                                child: Icon(
                                  (isList && widget.hideSwitchView == false)
                                      ? Icons.grid_view_rounded
                                      : Icons.list,
                                  size: shortestSide < 600 ? 30.w : 12.w,
                                ),
                              ),
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                size: shortestSide < 600 ? 30.w : 12.w,
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                  Container(
                    margin: EdgeInsets.only(left: 16, right: 16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10.0)),
                    child: FormBuilderTextField(
                      keyboardType: TextInputType.name,
                      onTapOutside: (value) {
                        FocusScope.of(context).unfocus();
                      },
                      name: 'search',
                      initialValue: keyword,
                      decoration: InputDecoration(
                          labelText: 'Tìm kiếm sản phẩm',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          floatingLabelBehavior: FloatingLabelBehavior.never,
                          prefixIcon: Icon(Icons.search)),
                      onSubmitted: (value) {
                        if (value != null) {
                          keyword = value;
                          handleSearch();
                        }
                      },
                      onChanged: (value) {
                        if (value != null) {
                          keyword = value;
                          _debounceSearch();
                        }
                      },
                    ),
                  ),
                  (!isList && widget.hideSwitchView == false)
                      ? Expanded(
                          child: Container(
                          // height: 40,
                          margin: EdgeInsets.only(left: 12, right: 12, top: 12),
                          child: PagedGridView<int, dynamic>(
                            pagingController: _pagingController,
                            builderDelegate: PagedChildBuilderDelegate<dynamic>(
                              firstPageErrorIndicatorBuilder: (context) =>
                                  Center(
                                child: Text(
                                    getResponseError(_pagingController.error)),
                              ),
                              newPageErrorIndicatorBuilder: (context) => Center(
                                child: Text(
                                    getResponseError(_pagingController.error)),
                              ),
                              firstPageProgressIndicatorBuilder: (context) =>
                                  Center(
                                child: CircularProgressIndicator(
                                  color: ThemeColor.get(context).primaryAccent,
                                ),
                              ),
                              newPageProgressIndicatorBuilder: (context) =>
                                  Center(
                                child: CircularProgressIndicator(
                                  color: ThemeColor.get(context).primaryAccent,
                                ),
                              ),
                              itemBuilder: (context, item, index) =>
                                  buildNewPopupItem(context, item),
                              noItemsFoundIndicatorBuilder: (_) =>
                                  Center(child: const Text("Không tìm thấy")),
                            ),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio:
                                        shortestSide < 600 ? 0.75 : 1.1,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8),
                          ),
                        ))
                      : Expanded(
                          child: PagedListView<int, dynamic>(
                            pagingController: _pagingController,
                            builderDelegate: PagedChildBuilderDelegate<dynamic>(
                              firstPageErrorIndicatorBuilder: (context) =>
                                  Center(
                                child: Text(
                                    getResponseError(_pagingController.error)),
                              ),
                              newPageErrorIndicatorBuilder: (context) => Center(
                                child: Text(
                                    getResponseError(_pagingController.error)),
                              ),
                              firstPageProgressIndicatorBuilder: (context) =>
                                  Center(
                                child: CircularProgressIndicator(
                                  color: ThemeColor.get(context).primaryAccent,
                                ),
                              ),
                              newPageProgressIndicatorBuilder: (context) =>
                                  Center(
                                child: CircularProgressIndicator(
                                  color: ThemeColor.get(context).primaryAccent,
                                ),
                              ),
                              itemBuilder: (context, item, index) =>
                                  buildPopupItem(context, item),
                              noItemsFoundIndicatorBuilder: (_) => Center(
                                  child: Text("Không tìm thấy sản phẩm nào")),
                            ),
                          ),
                        ),
                  buildPopupSelect(context)
                ],
              ),
            );
          },
          onDismissed: () {
            listItemsSelectedTmp = [];
            _handleClosePopup();
          },
          // validationWidgetBuilder: buildPopupSelect,
          // itemBuilder: buildPopupItem,
          modalBottomSheetProps: ModalBottomSheetProps(
            enableDrag: true,
            backgroundColor: Colors.transparent,
          ),
          emptyBuilder: (BuildContext context, String search) => SizedBox(
                height: 0,
              )),
      dropdownDecoratorProps: DropDownDecoratorProps(
        dropdownSearchDecoration: InputDecoration(
          labelText: "Chọn sản phẩm",
          labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          floatingLabelBehavior: FloatingLabelBehavior.never,
        ),
      ),
      // items: listItems,
      // asyncItems: (String filter) => _fetchVariantItems(filter),
      itemAsString: (StorageItem u) => u.asString(),
      onChanged: (List<StorageItem>? data) {
        if (data != null) {
          addMultiItems(data);
          // addItem(data);
        }
      },
    );
  }

  Widget buildCateItem(CategoryModel cate, BuildContext context) {
    return SingleTapDetector(
      onTap: () {
        widget.multiKey.currentState?.setState(() {});
        setState(() {
          selectedCate = cate;
          handleSearch();
        });
      },
      child: Container(
        margin: EdgeInsets.only(right: 3),
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          color: cate.id == selectedCate?.id
              ? ThemeColor.get(context).primaryAccent
              : Colors.grey[200],
        ),
        child: Center(
          child: Text(
            textAlign: TextAlign.center,
            cate.name ?? '',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cate.id == selectedCate?.id
                    ? Colors.white
                    : Colors.grey[700]),
          ),
        ),
      ),
    );
  }

  Widget buildNewPopupItem(BuildContext context, StorageItem item) {
    var shortestSide = MediaQuery.of(context).size.shortestSide;

    return SingleTapDetector(
        onTap: () {
          setState(() {
            item.isSelected = !item.isSelected;
            if (item.isSelected) {
              listItemsSelectedTmp.add(item);
            } else {
              listItemsSelectedTmp
                  .removeWhere((element) => element.id == item.id);
            }
          });
          _pagingController.notifyListeners();
        },
        child: Card(
          child: Column(
            children: [
              SizedBox(
                height: shortestSide < 600 ? (0.6.sw - 100) : 0.13.sw,
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8)),
                        child: FadeInImage(
                          placeholder:
                              AssetImage(getImageAsset('placeholder.png')),
                          fit: BoxFit.cover,
                          height:
                              shortestSide < 600 ? 0.6.sw - 100 : 0.2.sw - 50,
                          image: NetworkImage(getVariantFirstImage(item)),
                          imageErrorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              fit: BoxFit.cover,
                              height: shortestSide < 600
                                  ? 0.6.sw - 100
                                  : 0.2.sw - 50,
                              getImageAsset('placeholder.png'),
                            );
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: item.isSelected
                          ? Icon(
                              Icons.check_box_rounded,
                              color: ThemeColor.get(context).primaryAccent,
                            )
                          : Icon(Icons.check_box_outline_blank),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      right: 8,
                      child: Opacity(
                        opacity: 0.7,
                        child: Container(
                          height: 40,
                          // width: 110,
                          decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10.0)),
                              color: !(widget.isImei ?? false)
                                  ? ThemeColor.get(context).primaryAccent
                                  : Colors.grey.shade400),
                          child: Row(
                            children: [
                              GestureDetector(
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
                                    setState(() {});
                                    if (newQuantity == newQuantity.floor()) {
                                      item.quantity = newQuantity.toInt();
                                    } else {
                                      item.quantity = newQuantity.toDouble();
                                    }
                                    item.txtQuantity.text =
                                        roundQuantity(item.quantity);
                                    if (item.quantity == 0) {
                                      if (item.isSelected) {
                                        selectedItem(item);
                                      }
                                    }
                                    setState(() {});
                                  }
                                },
                                child: Container(
                                  width: 30,
                                  height: 40,
                                  decoration: BoxDecoration(
                                      color:
                                          ThemeColor.get(context).primaryAccent,
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(10.0),
                                        bottomLeft: Radius.circular(10.0),
                                      )),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    FontAwesomeIcons.minus,
                                    size: 15.0,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  width: 55,
                                  height: 40,
                                  decoration: BoxDecoration(
                                      // border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(10.0)),
                                      color: Colors.white),
                                  // height: 36,
                                  child: TextField(
                                    onTapOutside: (value) {
                                      FocusScope.of(context).unfocus();
                                    },
                                    key: item.quantityKey,
                                    controller: item.txtQuantity,
                                    onChanged: (value) {
                                      item.quantity =
                                          stringToDouble(value) ?? 0;
                                      if (!item.isSelected &&
                                          item.quantity > 0) {
                                        selectedItem(item);
                                      }
                                      setState(() {});
                                    },
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold),
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                            signed: true, decimal: true),
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
                              GestureDetector(
                                onTap: () {
                                  String newQuantityStr =
                                      (item.quantity + 1).toStringAsFixed(3);
                                  num newQuantity =
                                      stringToDouble(newQuantityStr) ?? 0;
                                  if (newQuantity == newQuantity.floor()) {
                                    item.quantity = newQuantity.toInt();
                                  } else {
                                    item.quantity = newQuantity;
                                  }
                                  item.txtQuantity.text =
                                      roundQuantity(item.quantity);
                                  if (!item.isSelected) {
                                    selectedItem(item);
                                  }
                                  setState(() {});
                                },
                                child: Container(
                                  width: 30,
                                  height: 40,
                                  decoration: BoxDecoration(
                                      color:
                                          ThemeColor.get(context).primaryAccent,
                                      borderRadius: BorderRadius.only(
                                        topRight: Radius.circular(10.0),
                                        bottomRight: Radius.circular(10.0),
                                      )),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    FontAwesomeIcons.plus,
                                    size: 15.0,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              Expanded(
                  child: Container(
                      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: Column(
                        children: [
                          Text(
                            '${item.name ?? item.product?.name ?? ' '}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                  widget.costField == 'retailCost'
                                      ? vndCurrency
                                          .format(item.retailCost)
                                          .replaceAll('vnđ', 'đ')
                                      : widget.costField == 'wholesaleCost'
                                          ? vndCurrency
                                              .format(item.wholesaleCost)
                                              .replaceAll('vnđ', 'đ')
                                          : vndCurrency
                                              .format(item.baseCost)
                                              .replaceAll('vnđ', 'đ'),
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold)),
                              // buildSL(item)
                            ],
                          )
                        ],
                      ))),
            ],
          ),
        ));
  }

  Widget buildPopupSelect(BuildContext context) {
    var shortestSide = MediaQuery.of(context).size.shortestSide;
    return Container(
        padding: shortestSide < 600
            ? EdgeInsets.all(16.w)
            : EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.w),
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
                          minimumSize: Size(80, 40)),
                      onPressed: () {
                        Navigator.pop(context);
                        addMultiItems(listItemsSelectedTmp);
                      },
                      child: Text(
                        widget.confirmText,
                        style: TextStyle(color: Colors.white),
                      )),
                )
              ],
            ),
          ],
        ));
  }

  _handleClosePopup() {
    for (var item in _pagingController.itemList ?? []) {
      if (widget.selectedItems.indexWhere((element) => element.id == item.id) ==
          -1) {
        item.isSelected = false;
      } else {
        item.isSelected = true;
      }
    }
  }

  Future _fetchVariantItems(String search) async {
    try {
      final items = await api<ProductApiService>(
          (request) => request.listVariant(search, cate: selectedCate?.id));
      // filter out items that already exists
      return items
          .where((element) =>
              widget.selectedItems
                  .indexWhere((item) => item.id == element.id) ==
              -1)
          .toList();
    } catch (e) {
      String errorMessage = getResponseError(e);
      CustomToast.showToastError(context, description: errorMessage);
      return [];
    }
  }

  _fetchPage(int pageKey) async {
    try {
      List<StorageItem> result = await api<ProductApiService>((request) =>
          request.listVariant(keyword,
              size: _pageSize,
              page: pageKey,
              type: widget.type,
              cate: selectedCate?.id));
      for (var item in result) {
        if (listItemsSelectedTmp
                .indexWhere((element) => element.id == item.id) !=
            -1) {
          item.isSelected = true;
        }
      }
      result.removeWhere((element) =>
          widget.selectedItems.indexWhere((item) => item.id == element.id) !=
          -1);
      final isLastPage = result.length < _pageSize;
      if (isLastPage) {
        _pagingController.appendLastPage(result);
      } else {
        final nextPageKey = pageKey + 1;
        _pagingController.appendPage(result, nextPageKey);
      }
    } catch (error) {
      _pagingController.error = error;
    }
  }

  selectedItem(StorageItem item) {
    setState(() {
      item.isSelected = !item.isSelected;
      if (item.isSelected) {
        listItemsSelectedTmp.add(item);
      } else {
        listItemsSelectedTmp.removeWhere((element) => element.id == item.id);
      }
    });
    _pagingController.notifyListeners();
  }

  Widget buildPopupItem(BuildContext context, StorageItem item) {
    return Column(
      children: [
        SingleTapDetector(
            onTap: () {
              setState(() {
                item.isSelected = !item.isSelected;
                if (item.isSelected) {
                  listItemsSelectedTmp.add(item);
                } else {
                  listItemsSelectedTmp
                      .removeWhere((element) => element.id == item.id);
                }
              });
              _pagingController.notifyListeners();
            },
            child: Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    title: Text(
                      (item.name ?? item.product?.name ?? '') +
                          (item.conversionUnit.isNotEmpty
                              ? ' - ' + item.conversionUnit[0]['unit']
                              : ''),
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item.sku ?? item.product?.code ?? '',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600]),
                          ),
                          buildSL(item),
                          Text(
                              widget.costField == 'retailCost'
                                  ? vnd.format(item.retailCost)
                                  : widget.costField == 'wholesaleCost'
                                      ? vnd.format(item.wholesaleCost)
                                      : vnd.format(item.baseCost),
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color.fromARGB(255, 255, 82, 8))),
                        ],
                      ),
                    ),
                  ),
                ),
                item.isSelected
                    ? Icon(
                        Icons.check_box_rounded,
                        color: ThemeColor.get(context).primaryAccent,
                      )
                    : Icon(Icons.check_box_outline_blank),
                SizedBox(
                  width: 16,
                )
              ],
            )),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Divider(
            color: Colors.grey[300],
          ),
        )
      ],
    );
  }

  buildStatusItem(StorageItem item) {
    String itemText = "SP Thường: ";
    Color colors = Colors.blue;

    if (item.product?.isImei == true) {
      itemText = 'SP IMEI: ';
      colors = Colors.red;
    }
    if (item.product?.isBatch == true) {
      itemText = 'SP Lô: ';
      colors = Colors.green;
    }
    return Row(
      children: [
        Text(
          itemText,
          style: TextStyle(fontSize: 12),
        ),
        Icon(
          Icons.check_rounded,
          size: 16,
          color: colors,
        ),
        SizedBox(
          width: 5,
        ),
        if (itemText == "SP Thường: ")
          Row(
            children: [
              Text(
                'Bán âm: ',
                style: TextStyle(fontSize: 12),
              ),
              item.isBuyAlways
                  ? Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.blue,
                    )
                  : Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Colors.red,
                    ),
            ],
          ),
      ],
    );
  }

  void addMultiItems(List<StorageItem> items) {
    List<String> saveItemName = [];
    if (items.isEmpty) {
      // for (var i in widget.selectedItems) {
      //   widget.selectedItems.remove(i);
      // }
      widget.selectedItems = [];
      return;
    }

    for (var item in items) {
      if (widget.selectedItems.indexWhere((element) => element.id == item.id) ==
          -1) {
        if (widget.isEditOrderPage == true) {
          if (item.isBuyAlways == false &&
              item.product?.isImei != true &&
              item.product?.isBatch != true &&
              (item.temporality ?? 0) <= 0) {
            saveItemName.add(item.name ?? ''); // Thêm tên vào list
            continue;
          }
        }
        setState(() {
          if (widget.costField == 'baseCost') {
            item.discountType = DiscountType.price;
            item.discount = 0;
          } else {
            if (item.discountType == DiscountType.price) {
              num price = (widget.costField == 'wholesaleCost'
                      ? item.wholesaleCost
                      : item.retailCost) ??
                  0;
              (item.discount ?? 0) > price
                  ? item.discount = price
                  : item.discount = item.discount;
            }
          }
          widget.selectedItems.insert(0, item);
        });
      } else {
        widget.selectedItems.removeWhere((i) =>
            (items.firstWhereOrNull((element) => element.id == i.id) == null));
      }
    }

    // Hiển thị toast với danh sách tên được ngăn cách bằng dấu phẩy
    if (saveItemName.isNotEmpty) {
      Future.microtask(() {
        CustomToast.showToastError(context,
            description: "Sản phẩm ${saveItemName.join(', ')} không khả dụng");
      });
    }
    // for (var i in widget.selectedItems) {
    //   widget.selectedItems.remove(i);
    // }

    widget.onSelect(widget.selectedItems);
  }

  buildSL(StorageItem item) {
    // if ((item.temporality ?? 0) > 0)
    //   return Text(
    //     "${item.temporality ?? 0}",
    //     style: TextStyle(
    //       fontSize: 14,
    //     ),
    //   );

    // if (item.isBuyAlways) {
    //   return Text(
    //     "Còn hàng",
    //     style: TextStyle(
    //       fontSize: 14,
    //     ),
    //   );
    // }

    // return Text(
    //   "Hết hàng",
    //   style: TextStyle(
    //     fontSize: 14,
    //   ),
    // );
    return Text(
      'Kho: ${roundQuantity(item.temporality ?? 0)}',
      style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600]),
    );
  }
}
