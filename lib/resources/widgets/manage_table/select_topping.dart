import 'dart:async';
import 'dart:developer';

import 'package:collection/collection.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../app/models/category.dart';
import '../../../app/utils/message.dart';

class SelectTopping extends NyStatefulWidget {
  final void Function(List<StorageItem>? variant) onSelect;
  // GlobalKey<DropdownSearchState<StorageItem>> multiKey;
  List<StorageItem> selectedItems;
  String confirmText = 'Tiếp tục';

  SelectTopping({
    Key? key,
    // required this.multiKey,
    required this.onSelect,
    required this.selectedItems,
  });

  @override
  State<SelectTopping> createState() => _SelectToppingState();
}

class _SelectToppingState extends NyState<SelectTopping> {
  TextEditingController searchBoxController = TextEditingController();
  List<StorageItem> listItemsSelectedTmp = [];
  Timer? _debounce;

  @override
  init() async {
    super.init();
  }

  static const _pageSize = 10;
  final PagingController<int, StorageItem> _pagingController =
      PagingController(firstPageKey: 1);
  String keyword = '';
  CategoryModel? selectedCate;
  List<CategoryModel> lstCate = [];
  @override
  void initState() {
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey, null);
    });
    super.initState();
  }

  _debounceSearch() {
    if (_debounce?.isActive ?? false) {
      _debounce?.cancel();
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
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
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
          onTap: () {
            _pagingController.refresh();
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (context) {
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
                                  "Chọn topping",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              )),
                          Positioned(
                            right: 0.w,
                            top: shortestSide < 600 ? 0.h : 6.h,
                            child: IconButton(
                              icon: Icon(
                                Icons.close,
                                size: shortestSide < 600 ? 30.w : 12.w,
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                              },
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
                              labelText: 'Tìm kiếm',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.never,
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
                      Expanded(
                          child: Container(
                        margin: EdgeInsets.only(left: 12, right: 12, top: 12),
                        child: PagedListView<int, dynamic>(
                          pagingController: _pagingController,
                          builderDelegate: PagedChildBuilderDelegate<dynamic>(
                            firstPageErrorIndicatorBuilder: (context) => Center(
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
                                child: Text("Không tìm thấy topping nào")),
                          ),
                        ),
                      )),
                      buildPopupSelect(context)
                    ],
                  ),
                );
              },
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle,
                  size: 20, color: ThemeColor.get(context).primaryAccent),
              Text(
                "Thêm topping",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ThemeColor.get(context).primaryAccent,
                ),
              ),
            ],
          )),
    );
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
                          backgroundColor: Colors.blue,
                          minimumSize: Size(80, 40)),
                      onPressed: () {
                        keyword = '';
                        Navigator.pop(context);
                        addMultiItems(listItemsSelectedTmp);
                        setState(() {
                          for (var item in listItemsSelectedTmp) {
                            item.isSelected = false;
                          }
                          listItemsSelectedTmp.clear();
                        });
                      },
                      child: Text(
                        widget.confirmText,
                        style: TextStyle(color: Colors.white),
                      )),
                ),
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

  _fetchPage(int pageKey, int? type) async {
    try {
      List<StorageItem> result = await api<ProductApiService>((request) =>
          request.listVariantTable(keyword,
              size: _pageSize,
              page: pageKey,
              type: type,
              cate: selectedCate?.id,
              isTopping: true));
      listItemsSelectedTmp = [...widget.selectedItems];
      for (var item in result) {
        var i = listItemsSelectedTmp
            .firstWhereOrNull((element) => element.id == item.id);
        if (i != null) {
          item.isSelected = true;
          item.txtQuantity.text = roundQuantity(i.quantity);
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
                        children: [
                          Text(vndCurrency.format(item.retailCost),
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

  void addMultiItems(List<StorageItem> items) {
    if (items.isEmpty) {
      widget.selectedItems = [];
      return;
    }
    for (var item in items) {
      if (widget.selectedItems.indexWhere((element) => element.id == item.id) ==
          -1) {
        setState(() {
          widget.selectedItems.insert(0, item);
        });
      } else {
        widget.selectedItems.removeWhere((i) =>
            (items.firstWhereOrNull((element) => element.id == i.id) == null));
      }
    }
    widget.onSelect(widget.selectedItems);
  }
}
