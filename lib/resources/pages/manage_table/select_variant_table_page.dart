import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/app/controllers/controller.dart';
import 'package:flutter_app/app/models/category.dart';
import 'package:flutter_app/app/models/storage_item.dart';
import 'package:flutter_app/app/networking/category_api_service.dart';
import 'package:flutter_app/app/networking/product_api_service.dart';
import 'package:flutter_app/app/utils/formatters.dart';
import 'package:flutter_app/app/utils/getters.dart';
import 'package:flutter_app/app/utils/message.dart';
import 'package:flutter_app/app/utils/text.dart';
import 'package:flutter_app/bootstrap/helpers.dart';
import 'package:flutter_app/resources/pages/manage_table/beverage_reservation_page.dart';
import 'package:flutter_app/resources/pages/manage_table/table_reservation_page.dart';
import 'package:flutter_app/resources/pages/manage_table/take_away_table_page.dart';
import 'package:flutter_app/resources/pages/product/edit_product_service_page.dart';
import 'package:flutter_app/resources/widgets/single_tap_detector.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:nylo_framework/nylo_framework.dart';

class SelectVariantTablePage extends NyStatefulWidget {
  final Controller controller = Controller();

  static const path = '/select-variant-table';
  SelectVariantTablePage({Key? key}) : super(key: key);

  @override
  NyState<SelectVariantTablePage> createState() =>
      _SelectVariantTablePageState();
}

class _SelectVariantTablePageState extends NyState<SelectVariantTablePage> {
  String get roomId => widget.data()['room_id'].toString();
  String? get buttonType => widget.data()['button_type'].toString();
  String? get areaName => widget.data()['area_name'] ?? '';
  String? get roomName => widget.data()['room_name'] ?? '';
  Timer? _debounce;
  List<StorageItem> originalSelectedItems = [];
  static const _pageSize = 10;
  final PagingController<int, StorageItem> _pagingController =
      PagingController(firstPageKey: 1);
  String keyword = '';
  CategoryModel? selectedCate;
  List<CategoryModel> lstCate = [];
  bool isAnimating = false;
  Offset startPosition = Offset.zero;
  Offset endPosition = Offset.zero;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  List<StorageItem> selectedItems = [];
  bool isSearchMode = false;
  final TextEditingController searchController = TextEditingController();
  final GlobalKey<FormBuilderState> _formKey = GlobalKey<FormBuilderState>();
  List<StorageItem> initItems = [];
  Map<int, num> initialQuantities = {};

  bool get isEditing => widget.data()?['items'] != null;

  bool isTakeAway = false;

  @override
  void initState() {
    if (isEditing) {
      final tempItems = widget.data()?['items'] as List<StorageItem>;
      List<StorageItem> item = tempItems.map((item) {
        item.isSelected = true;
        return item;
      }).toList();
      selectedItems.addAll(item);
      originalSelectedItems = List.from(selectedItems);
      initItems = tempItems;
      initItems.forEach((item) {
        initialQuantities[item.id!] = item.quantity;
        item.txtQuantity.text = roundQuantity(item.quantity);
      });
      selectedItems.forEach((item) {
        item.txtQuantity.text = roundQuantity(item.quantity);
        _formKey.currentState?.fields['${item.id}.quantity']
            ?.didChange(roundQuantity(item.quantity));
      });
    }
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });
    _fetchCate(1);
    isTakeAway = widget.data()['take_away'] ?? false;
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  _fetchPage(int pageKey) async {
    try {
      List<StorageItem> result = await api<ProductApiService>((request) =>
          request.listVariantTable(keyword,
              size: _pageSize,
              page: pageKey,
              type: null,
              cate: selectedCate?.id));
      final selectedItemsMap = {for (var item in selectedItems) item.id: item};
      for (var item in result) {
        final selectedItem = selectedItemsMap[item.id];
        if (selectedItem != null) {
          item.isSelected = true;
          item.txtQuantity.text = roundQuantity(selectedItem.quantity);
          item.quantity = selectedItem.quantity;
          item.retailCost = selectedItem.retailCost;
        }
      }
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

  Future<void> _fetchCate(int pageKey) async {
    try {
      List<CategoryModel> newItems = await api<CategoryApiService>(
          (request) => request.listCategoryPaginate(pageKey, 100, ''));
      lstCate = [];
      var highlightCate = CategoryModel();
      highlightCate.name = 'Nổi bật';
      highlightCate.id = null;
      lstCate.add(highlightCate);
      lstCate.addAll(newItems);
      setState(() {});
    } catch (error) {
      showToastWarning(description: error.toString());
    }
  }

  void _syncSelectedItems(StorageItem item) {
    final index = selectedItems.indexWhere((element) => element.id == item.id);
    if (index != -1) {
      selectedItems[index].quantity = item.quantity;
    } else if (item.isSelected) {
      selectedItems.add(item);
    }
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

  void runAddToCartAnimation(GlobalKey imageKey, String imageUrl) async {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }

    final renderBox = imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return;
    }

    final startPosition = renderBox.localToGlobal(Offset.zero);
    final imageSize = renderBox.size;
    final screenSize = MediaQuery.of(context).size;
    final endPosition = Offset(
      screenSize.width - 60,
      screenSize.height - 70,
    );
    final overlay = Overlay.of(context);

    final animImage = Stack(
      children: [
        AnimatedAddToCartImage(
          imageUrl: imageUrl,
          startPosition: startPosition,
          endPosition: endPosition,
          size: imageSize,
          onCompleted: () {
            _overlayEntry?.remove();
            _overlayEntry = null;
          },
        ),
      ],
    );

    _overlayEntry = OverlayEntry(builder: (context) => animImage);
    overlay.insert(_overlayEntry!);
    setState(() {});
  }

  num totalQuantity() {
    num total = 0;
    for (var item in selectedItems) {
      total += item.quantity;
    }
    return total;
  }

  removeItem(StorageItem item) {
    item.isSelected = false;
    item.quantity = 1;
    _formKey.currentState?.fields['${item.id}.quantity']
        ?.didChange(roundQuantity(item.quantity));
    if (item.toppings.isNotEmpty) {
      for (var topping in item.toppings) {
        topping.quantity = 1;
      }
      item.toppings.clear();
    }
    if (item.productNotes != null) {
      item.productNotes!.clear();
    }
    selectedItems.removeWhere((element) => element.id == item.id);

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: isSearchMode
            ? TextFormField(
                controller: searchController,
                autofocus: true,
                onChanged: (value) {
                  keyword = value;
                  _debounceSearch();
                },
                cursorColor: ThemeColor.get(context).primaryAccent,
                decoration: InputDecoration(
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 5, horizontal: 15),
                  hintText: 'Tìm kiếm...',
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  fillColor: Colors.grey[100],
                  filled: true,
                  suffixIcon: keyword.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            setState(() {
                              searchController.clear();
                              keyword = '';
                            });
                            _debounceSearch();
                          },
                        )
                      : null,
                ),
                style: TextStyle(color: Colors.black),
              )
            : Text.rich(TextSpan(
                children: [
                  TextSpan(
                    text: areaName ?? '',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: roomName != '' ? ': $roomName' : '',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )),
        leading: IconButton(
          icon: Icon(isSearchMode ? Icons.arrow_back_ios_new : Icons.close),
          onPressed: () {
            if (isSearchMode) {
              setState(() {
                isSearchMode = false;
                keyword = '';
                _pagingController.refresh();
              });
            } else {
              if (isEditing) {
                selectedItems = List.from(originalSelectedItems);
                for (var item in selectedItems) {
                  if (initialQuantities.containsKey(item.id)) {
                    item.quantity = initialQuantities[item.id]!;
                    item.txtQuantity.text = roundQuantity(item.quantity);
                  }
                }
                Navigator.of(context).pop(selectedItems);
              } else {
                Navigator.of(context).pop();
              }
            }
          },
        ),
        actions: [
          if (!isSearchMode)
            InkWell(
                child: Icon(Icons.search),
                onTap: () {
                  setState(() {
                    isSearchMode = true;
                  });
                }),
          if (!isSearchMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: InkWell(
                  child: Icon(Icons.add),
                  onTap: () {
                    routeTo(
                      EditProductServicePage.path,
                      onPop: (value) {
                        value != null ? _pagingController.refresh() : null;
                      },
                    );
                  }),
            ),
          if (isSearchMode)
            Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child:
                  InkWell(child: Icon(FontAwesomeIcons.barcode), onTap: () {}),
            ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            FormBuilder(
              key: _formKey,
              child: Column(
                children: [
                  buildHeader(),
                  Expanded(
                    child: PagedListView<int, dynamic>(
                      pagingController: _pagingController,
                      builderDelegate: PagedChildBuilderDelegate<dynamic>(
                        firstPageErrorIndicatorBuilder: (context) => Center(
                          child:
                              Text(getResponseError(_pagingController.error)),
                        ),
                        newPageErrorIndicatorBuilder: (context) => Center(
                          child:
                              Text(getResponseError(_pagingController.error)),
                        ),
                        firstPageProgressIndicatorBuilder: (context) => Center(
                          child: CircularProgressIndicator(
                            color: ThemeColor.get(context).primaryAccent,
                          ),
                        ),
                        newPageProgressIndicatorBuilder: (context) => Center(
                          child: CircularProgressIndicator(
                            color: ThemeColor.get(context).primaryAccent,
                          ),
                        ),
                        itemBuilder: (context, item, index) =>
                            buildPopupItem(context, item),
                        noItemsFoundIndicatorBuilder: (_) => Center(
                            child: Text(
                                "Không tìm thấy ${text('_product_title', 'sản phẩm')} nào")),
                      ),
                    ),
                  ),
                  if (selectedItems.isNotEmpty)
                    Container(
                      margin: EdgeInsets.only(
                          top: 5, bottom: 10, left: 16, right: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                if (isEditing) {
                                  selectedItems =
                                      List.from(originalSelectedItems);

                                  final itemList =
                                      _pagingController.itemList ?? [];
                                  for (var item in itemList) {
                                    final isSelected = selectedItems.any(
                                        (selectedItem) =>
                                            selectedItem.id == item.id);
                                    item.isSelected = isSelected;

                                    if (isSelected) {
                                      final selectedItem = selectedItems
                                          .firstWhere((selectedItem) =>
                                              selectedItem.id == item.id);
                                      item.quantity = selectedItem.quantity;
                                      item.txtQuantity.text =
                                          selectedItem.txtQuantity.text;
                                    } else {
                                      item.quantity = 1;
                                      item.txtQuantity.text = '1';
                                    }
                                  }
                                } else {
                                  List<StorageItem> itemsToRemove =
                                      List.from(selectedItems);
                                  itemsToRemove.forEach((item) {
                                    removeItem(item);
                                  });
                                  for (var item
                                      in _pagingController.itemList ?? []) {
                                    item.isSelected = false;
                                    item.quantity = 1;
                                    item.txtQuantity.text =
                                        roundQuantity(item.quantity);
                                  }
                                }
                                setState(() {});
                              },
                              style: TextButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  backgroundColor: Colors.grey[100],
                                  foregroundColor: Colors.black),
                              child: Text(
                                'Chọn lại',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 8,
                          ),
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                if (isEditing) {
                                  Navigator.of(context).pop(selectedItems);
                                } else {
                                  if (isTakeAway == true) {
                                    routeTo(TakeAwayTablePage.path, data: {
                                      'room_id': 0,
                                      'button_type': "create_order",
                                      'items': selectedItems,
                                      'area_name': 'Bàn',
                                      'room_name': 'Mang đi',
                                    });
                                  } else {
                                    routeTo(
                                      BeverageReservationPage.path,
                                      data: {
                                        'room_id': roomId,
                                        'button_type': buttonType,
                                        'items': selectedItems,
                                        'area_name': areaName,
                                        'room_name': roomName,
                                      },
                                      onPop: (value) {
                                        if (value != null) {
                                          selectedItems =
                                              value as List<StorageItem>;
                                          for (var item in selectedItems) {
                                            item.txtQuantity.text =
                                                roundQuantity(item.quantity);
                                          }
                                        }
                                        _pagingController.refresh();
                                        setState(() {});
                                      },
                                    );
                                  }
                                }
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                backgroundColor:
                                    ThemeColor.get(context).primaryAccent,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Thêm vào đơn',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Container(
                                    constraints: BoxConstraints(
                                      maxWidth: 60,
                                    ),
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: Color.alphaBlend(
                                          Colors.black.withOpacity(0.2),
                                          ThemeColor.get(context)
                                              .primaryAccent),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    child: Text(
                                      roundQuantity(totalQuantity()),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildPopupItem(BuildContext context, StorageItem item) {
    final GlobalKey imageKey = GlobalKey();
    return SingleTapDetector(
        onTap: () {
          if (item.isSelected != true) {
            selectedItems.add(item);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              runAddToCartAnimation(
                imageKey,
                getVariantFirstImage(item),
              );
            });
          }
          item.isSelected = true;
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 0.09.sh,
                    height: 0.09.sh,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: FadeInImage(
                        key: imageKey,
                        placeholder:
                            AssetImage(getImageAsset('placeholder.png')),
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
                  SizedBox(
                    width: 8,
                  ),
                  Expanded(
                    child: Container(
                      height: 0.09.sh,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name ?? '',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                vnd.format(item.retailCost),
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              item.isSelected
                                  ? buildSelectQuantity(
                                      item,
                                      context,
                                      imageKey,
                                    )
                                  : SizedBox(
                                      height: 40,
                                    ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Divider(
                  color: Colors.grey[300],
                ),
              ),
            ],
          ),
        ));
  }

  Widget buildSelectQuantity(
      StorageItem item, BuildContext context, GlobalKey imageKey) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (item.quantity > 1) {
                item.quantity--;
                item.txtQuantity.text = roundQuantity(item.quantity);
              } else {
                removeItem(item);
              }
              _syncSelectedItems(item);
              setState(() {});
            },
            icon: Icon(Icons.remove),
          ),
          Container(
            width: 0.12.sw,
            height: 40,
            alignment: Alignment.center,
            child: FormBuilderTextField(
              key: Key('${item.id}'),
              name: '${item.id}.quantity',
              textAlign: TextAlign.center,
              controller: item.txtQuantity,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: '0',
                contentPadding: EdgeInsets.only(bottom: 10),
                border: InputBorder.none,
              ),
              onChanged: (value) {
                item.quantity = stringToDouble(value) ?? 0;
                _syncSelectedItems(item);
                setState(() {});
              },
              keyboardType: TextInputType.number,
              onTapOutside: (event) {
                if (item.quantity == 0) {
                  removeItem(item);
                  item.txtQuantity.text = roundQuantity(item.quantity);
                }
                FocusScope.of(context).unfocus();
              },
              onEditingComplete: () {
                if (item.quantity == 0) {
                  removeItem(item);
                  item.txtQuantity.text = roundQuantity(item.quantity);
                }
                FocusScope.of(context).unfocus();
              },
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d+\.?\d{0,3}'),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              item.quantity++;
              item.txtQuantity.text = roundQuantity(item.quantity);
              _syncSelectedItems(item);
              setState(() {});
            },
            icon: Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget buildHeader() {
    ScreenUtil.init(context);
    return Container(
        width: 1.sw,
        margin: EdgeInsets.only(right: 16, left: 16, top: 6),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...lstCate.map((e) => buildCateItem(e, context)).toList(),
            ],
          ),
        ));
  }

  Widget buildCateItem(CategoryModel cate, BuildContext context) {
    final bool isSelected = cate.id == selectedCate?.id;
    return SingleTapDetector(
      onTap: () {
        selectedCate = cate;
        handleSearch();
        setState(() {});
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 220),
        curve: Curves.easeOut,
        margin: EdgeInsets.only(right: 3),
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected
              ? ThemeColor.get(context).primaryAccent.withOpacity(0.1)
              : Colors.grey[100],
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color:
                        ThemeColor.get(context).primaryAccent.withOpacity(0.18),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : [],
        ),
        transform: Matrix4.identity()..scale(isSelected ? 1.08 : 1.0),
        child: Center(
          child: Text(
            cate.name ?? '',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? ThemeColor.get(context).primaryAccent
                      : Colors.grey[700],
                ),
          ),
        ),
      ),
    );
  }
}

class AnimatedAddToCartImage extends StatefulWidget {
  final String imageUrl;
  final Offset startPosition;
  final Offset endPosition;
  final Size size;
  final VoidCallback onCompleted;

  const AnimatedAddToCartImage({
    required this.imageUrl,
    required this.startPosition,
    required this.endPosition,
    required this.size,
    required this.onCompleted,
    Key? key,
  }) : super(key: key);

  @override
  _AnimatedAddToCartImageState createState() => _AnimatedAddToCartImageState();
}

class _AnimatedAddToCartImageState extends State<AnimatedAddToCartImage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _position;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);

    _position = Tween<Offset>(
      begin: widget.startPosition,
      end: widget.endPosition,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _scale = Tween<double>(begin: 1.0, end: 0.3)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward().whenComplete(() {
      if (mounted) {
        widget.onCompleted();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Positioned(
        left: _position.value.dx,
        top: _position.value.dy,
        child: Transform.scale(
          scale: _scale.value,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: SizedBox(
              width: widget.size.width,
              height: widget.size.height,
              child: Image.network(
                widget.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (BuildContext context, Object error,
                    StackTrace? stackTrace) {
                  return Image.asset(
                    getImageAsset('placeholder.png'),
                    fit: BoxFit.cover,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
