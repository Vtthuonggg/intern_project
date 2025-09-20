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
import 'package:flutter_app/resources/pages/product/edit_product_service_page.dart';
import 'package:flutter_app/resources/widgets/single_tap_detector.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:nylo_framework/nylo_framework.dart';

class SelectMenuPos extends NyStatefulWidget {
  final String Function()? getRoomId;
  final String? Function()? getButtonType;
  final String? Function()? getAreaName;
  final String? Function()? getRoomName;
  final bool Function()? getIsEditing;
  final Function(StorageItem)? onSelectItem;
  SelectMenuPos({
    Key? key,
    this.getRoomId,
    this.getButtonType,
    this.getAreaName,
    this.getRoomName,
    this.getIsEditing,
    this.onSelectItem,
  }) : super(key: key);

  @override
  NyState<SelectMenuPos> createState() => _SelectMenuPosPageState();
}

class _SelectMenuPosPageState extends NyState<SelectMenuPos> {
  String get roomId => widget.getRoomId?.call() ?? '';
  String? get buttonType => widget.getButtonType?.call();
  String? get areaName => widget.getAreaName?.call();
  String? get roomName => widget.getRoomName?.call();

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
  bool isSearchMode = false;
  final TextEditingController searchController = TextEditingController();
  final GlobalKey<FormBuilderState> _formKey = GlobalKey<FormBuilderState>();
  List<StorageItem> initItems = [];
  Map<int, num> initialQuantities = {};
  final Map<int, GlobalKey> imageKeys = {};
  @override
  void initState() {
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });
    _fetchCate(1);
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
      screenSize.width / 3 * 2,
      screenSize.height / 2 - imageSize.height / 2,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        toolbarHeight: 40,
        title: isSearchMode
            ? SizedBox(
                height: 35,
                child: TextFormField(
                  controller: searchController,
                  autofocus: true,
                  onChanged: (value) {
                    keyword = value;
                    _debounceSearch();
                  },
                  onTapOutside: (event) {
                    FocusScope.of(context).unfocus();
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
                    fillColor: Colors.white,
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
                ),
              )
            : IntrinsicWidth(
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.only(
                      left: 16, right: 20, top: 10, bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      topLeft: Radius.circular(12),
                    ),
                  ),
                  child: Text.rich(TextSpan(
                    children: [
                      TextSpan(
                        text: areaName ?? '',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black),
                      ),
                      TextSpan(
                        text: roomName != '' ? ': $roomName' : '',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  )),
                ),
              ),
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
              Navigator.of(context).pop();
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
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: PagedGridView<int, dynamic>(
                        pagingController: _pagingController,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1,
                        ),
                        builderDelegate: PagedChildBuilderDelegate<dynamic>(
                          firstPageErrorIndicatorBuilder: (context) => Center(
                            child:
                                Text(getResponseError(_pagingController.error)),
                          ),
                          newPageErrorIndicatorBuilder: (context) => Center(
                            child:
                                Text(getResponseError(_pagingController.error)),
                          ),
                          firstPageProgressIndicatorBuilder: (context) =>
                              Center(
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
    final imageKey = imageKeys.putIfAbsent(item.id!, () => GlobalKey());
    return GestureDetector(
      onTap: () {
        widget.onSelectItem?.call(item);

        Future.delayed(Duration(milliseconds: 50), () {
          runAddToCartAnimation(
            imageKeys[item.id!]!,
            getVariantFirstImage(item),
          );
        });
        setState(() {});
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey.shade300,
          ),
          color: Colors.white,
        ),
        child: Column(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                  child: AspectRatio(
                    aspectRatio: 1.4,
                    child: FadeInImage(
                      key: imageKey,
                      placeholder: AssetImage(getImageAsset('placeholder.png')),
                      image: NetworkImage(getVariantFirstImage(item)),
                      fit: BoxFit.cover,
                      imageErrorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          getImageAsset('placeholder.png'),
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 5,
                  child: Center(
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        vnd.format(item.retailCost),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: ThemeColor.get(context).primaryAccent,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Center(
                child: Text(
                  item.name ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildHeader() {
    ScreenUtil.init(context);
    return Container(
        width: 1.sw,
        margin: EdgeInsets.only(right: 16, left: 16, top: 6, bottom: 6),
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
        if (!isSelected) {
          HapticFeedback.lightImpact();
          selectedCate = cate;
          handleSearch();
          setState(() {});
        }
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 220),
        curve: Curves.easeOut,
        margin: EdgeInsets.symmetric(horizontal: 3),
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
