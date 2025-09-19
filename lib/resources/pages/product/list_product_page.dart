import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:draggable_fab/draggable_fab.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/app/models/product.dart';
import 'package:flutter_app/app/models/store.dart';
import 'package:flutter_app/app/models/user.dart';
import 'package:flutter_app/app/networking/branch_api.dart';
import 'package:flutter_app/app/networking/product_api_service.dart';
import 'package:flutter_app/app/utils/formatters.dart';
import 'package:flutter_app/app/utils/getters.dart';
import 'package:flutter_app/app/utils/message.dart';
import 'package:flutter_app/app/utils/permission.dart';
import 'package:flutter_app/bootstrap/helpers.dart';
import 'package:flutter_app/config/storage_keys.dart';
import 'package:flutter_app/resources/pages/category/category_page.dart';
import 'package:flutter_app/resources/pages/category/edit_category_page.dart';
import 'package:flutter_app/resources/pages/custom_toast.dart';
import 'package:flutter_app/resources/pages/brand/brand_page.dart';
import 'package:flutter_app/resources/pages/product/downloading_service.dart';
import 'package:flutter_app/resources/pages/product/create_bulk_product_page.dart';
import 'package:flutter_app/resources/pages/product/detail_product_page.dart';
import 'package:flutter_app/resources/pages/product/edit_product_page.dart';
import 'package:flutter_app/resources/pages/product/edit_product_service_page.dart';
import 'package:flutter_app/resources/pages/supplier/edit_supplier_page.dart';
import 'package:flutter_app/resources/pages/supplier/supplier_page.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:form_builder_file_picker/form_builder_file_picker.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:nylo_framework/nylo_framework.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/utils/text.dart';

class ListProductPage extends NyStatefulWidget {
  static const path = '/list-product';
  bool? onTabbar = false;

  ListProductPage({Key? key, this.onTabbar}) : super(key: key);

  @override
  _ListProductPageState createState() => _ListProductPageState();
}

class _ListProductPageState extends NyState<ListProductPage> {
  final PagingController<int, dynamic> _pagingController =
      PagingController(firstPageKey: 1);

  String searchQuery = '';
  BuildContext? saveDialogLoadingContext;
  int _pageSize = 20;

  dynamic _total;
  int storeId = -1;
  Timer? _debounce;
  bool _isBulkDeleteMode = false;
  List<dynamic> _selectedProductIds = [];
  List<Store> _stores = [];
  Store? selectedStore;
  bool _isLoading = false;
  @override
  void init() async {
    super.init();
    storeId = await Backpack.instance.read(StorageKey.storeId) ?? -1;
    if (storeId == -1) {
      fetchBranches();
    } else {
      getSelectedStoreFrom();
    }
  }

  bool isSameStore() {
    return storeId == (selectedStore?.id ?? -1);
  }

  bool canEdit() {
    if (storeId != -1) {
      return selectedStore?.id == storeId;
    }
    return storeId == -1;
  }

  _debounceSearch() {
    if (_debounce?.isActive ?? false) {
      _debounce?.cancel();
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _pagingController.refresh();
    });
  }

  Future _deleteSelectedProducts() async {
    try {
      await api<ProductApiService>(
          (request) => request.deleteListProduct(_selectedProductIds));
      CustomToast.showToastSuccess(context,
          description: 'Xóa sản phẩm thành công');
      _pagingController.refresh();
      _isBulkDeleteMode = false;
    } catch (e) {
      CustomToast.showToastError(context, description: "Có lỗi xảy ra");
    }
  }

  @override
  void initState() {
    _pagingController.addPageRequestListener((pageKey) {
      _fetchProducts(pageKey);
    });
    super.initState();
    // IsolateNameServer.registerPortWithName(
    //     _receivePort.sendPort, DownloadingService.downloadingPortName);
    // FlutterDownloader.registerCallback(DownloadingService.downloadingCallBack);
    // _receivePort.listen((message) {
    //   List<dynamic> result = List<dynamic>.from(message as List);
    //   if (result[1] == 3 && result[2] == 100) {
    //     CustomToast.showToastSuccess(context,
    //         description: "Tải file mẫu thành công");
    //   }
    // });
  }

  @override
  void dispose() {
    _pagingController.dispose();
    // _receivePort.close();
    super.dispose();
  }

  _fetchProducts(int pageKey) async {
    _isLoading = true;
    try {
      Map<String, dynamic> newItems = await api<ProductApiService>((request) =>
          request.listProductNew(searchQuery, pageKey, _pageSize, 1,
              storeId: selectedStore?.id));
      setState(() {
        _total = newItems['meta'];
        List<Product> products = [];
        newItems["data"].forEach((category) {
          products.add(Product.fromJson(category));
        });
        // _total = newItems['total'];
        final isLastPage = products.length < _pageSize;
        if (isLastPage) {
          _pagingController.appendLastPage(products);
        } else {
          final nextPageKey = pageKey + 1;
          _pagingController.appendPage(products, nextPageKey);
        }
      });
    } catch (error) {
      _pagingController.error = error;
    } finally {
      _isLoading = false;
    }
  }

  num calculateTotalAvailable(List<ProductVariant> variants) {
    num total = 0;
    for (var variant in variants) {
      total += variant.available ?? 0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);
    return Scaffold(
        appBar: AppBar(
            systemOverlayStyle: SystemUiOverlayStyle(
              systemNavigationBarColor:
                  ThemeColor.get(context).primaryAccent, // Navigation bar
            ),
            title: Text(
              text('list_product_title', 'Quản lý sản phẩm'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              if (_isBulkDeleteMode)
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _isBulkDeleteMode = false;
                        _selectedProductIds.clear();
                      });
                    },
                    child: Text(
                      'Huỷ',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              else ...[
                if (hasAnyPermission(['view_all_supplier']))
                  IconButton(
                    icon: SvgPicture.asset(
                      getImageAsset('svg/supplier.svg'),
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(
                          Theme.of(context).colorScheme.onPrimary,
                          BlendMode.srcIn),
                    ),
                    onPressed: () {
                      routeTo(SupplierPage.path);
                    },
                  ),
                if (hasAnyPermission(['view_all_category']))
                  IconButton(
                    icon: Icon(Icons.category),
                    onPressed: () {
                      routeTo(CategoryPage.path);
                    },
                  ),
                IconButton(
                    onPressed: () {
                      routeTo(BrandPage.path);
                    },
                    icon: Icon(FontAwesomeIcons.tag))
              ]
            ]),
        floatingActionButton: DraggableFab(
          securityBottom: 60,
          child: SpeedDial(
            spacing: 30,
            spaceBetweenChildren: 10,
            icon: Icons.add,
            activeIcon: Icons.close,
            backgroundColor: Colors.white,
            foregroundColor: ThemeColor.get(context).primaryAccent,
            children: [
              if (Auth.user<User>()?.allowCreateBulkProduct == true)
                SpeedDialChild(
                  child: const Icon(FontAwesomeIcons.folderPlus),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  label: 'Thêm nhanh ${text('_product_title', 'sản phẩm')}',
                  onTap: () {
                    routeTo(CreateBulkProductPage.path, onPop: (value) {
                      _pagingController.refresh();
                    });
                  },
                ),
              SpeedDialChild(
                child: const Icon(FontAwesomeIcons.plus),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                label: 'Thêm sản phẩm',
                onTap: () {
                  routeTo(
                    EditProductPage.path,
                    onPop: (value) {
                      _pagingController.refresh();
                    },
                  );
                },
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_stores.length > 1)
              buildSelectSrores()
            else
              SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 15, right: 15),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                    _debounceSearch();
                  });
                },
                decoration: InputDecoration(
                  labelText: "Tìm kiếm ${text('_product_title', 'sản phẩm')}",
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
            buildHeader(),
            Expanded(
              child: RefreshIndicator(
                color: ThemeColor.get(context).primaryAccent,
                onRefresh: () => Future.sync(
                  () => _pagingController.refresh(),
                ),
                child: PagedListView<int, dynamic>(
                  pagingController: _pagingController,
                  builderDelegate: PagedChildBuilderDelegate<dynamic>(
                    firstPageErrorIndicatorBuilder: (context) => Center(
                      child: Text(getResponseError(_pagingController.error)),
                    ),
                    newPageErrorIndicatorBuilder: (context) => Center(
                      child: Text(getResponseError(_pagingController.error)),
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
                        buildItem(item, context),
                    noItemsFoundIndicatorBuilder: (_) => Center(
                        child: const Text("Không tìm thấy sản phẩm nào")),
                  ),
                ),
              ),
            ),
          ],
        ));
  }

  Widget buildSelectSrores() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      height: 35,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.store,
            color: ThemeColor.get(context).primaryAccent,
            size: 22,
          ),
          SizedBox(width: 8),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _stores.length,
              itemBuilder: (context, index) {
                final store = _stores[index];
                final isSelected = selectedStore?.id == store.id;

                return GestureDetector(
                  onTap: () {
                    if (store != selectedStore && !_isLoading) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _isBulkDeleteMode = false;
                        _selectedProductIds.clear();
                        selectedStore = store;
                      });
                      _pagingController.refresh();
                    }
                  },
                  child: Container(
                    margin: EdgeInsets.only(right: 24),
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected
                              ? ThemeColor.get(context).primaryAccent
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      store.name ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? ThemeColor.get(context).primaryAccent
                            : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 16),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _isBulkDeleteMode
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          activeColor: ThemeColor.get(context).primaryAccent,
                          value: _selectedProductIds.length ==
                              _pagingController.itemList?.length,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                _selectedProductIds = _pagingController.itemList
                                        ?.map((item) => item.id)
                                        .toList() ??
                                    [];
                              } else {
                                _selectedProductIds.clear();
                              }
                            });
                          },
                        ),
                        Text(
                          'Chọn tất cả',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () {
                        if (_selectedProductIds.isEmpty) {
                          CustomToast.showToastError(context,
                              description: "Chưa chọn sản phẩm nào");
                          return;
                        }
                        confirmDeleteList();
                      },
                      child: Text(
                        'Xoá đã chọn',
                        style: TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Text.rich(
                      TextSpan(
                        text: 'Tổng số lượng: ',
                        style: TextStyle(fontSize: 16),
                        children: <TextSpan>[
                          TextSpan(
                            text:
                                '${_total != null ? roundQuantity(_total['total']) : 0}',
                            // text: '',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    Spacer(),
                  ],
                ),
        ],
      ),
    );
  }

  Widget buildItem(dynamic item, BuildContext context) {
    return InkWell(
      onLongPress: canEdit()
          ? () {
              setState(() {
                _isBulkDeleteMode = true;
                _selectedProductIds.add(item.id);
              });
            }
          : null,
      child: Stack(children: [
        Column(
          children: [
            InkWell(
              onTap: () {
                routeTo(DetailProductPage.path, data: {
                  'id': item.id,
                  'store_id': selectedStore?.id,
                  'can_edit': canEdit()
                }, onPop: (value) {
                  _pagingController.refresh();
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                    width: double.infinity,
                    height: 0.125.sh,
                    child: Row(
                      children: [
                        if (_isBulkDeleteMode)
                          Checkbox(
                            activeColor: ThemeColor.get(context).primaryAccent,
                            value: _selectedProductIds.contains(item.id),
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  _selectedProductIds.add(item.id);
                                } else {
                                  _selectedProductIds.remove(item.id);
                                }
                              });
                            },
                          ),
                        Container(
                          width: 0.1.sh,
                          height: 0.1.sh,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: FadeInImage(
                              placeholder:
                                  AssetImage(getImageAsset('placeholder.png')),
                              image: NetworkImage(getProductFirstImage(item)),
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
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 20),
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        item.name ?? '',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "${item.code ?? ''}",
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tồn kho:',
                                    style: TextStyle(
                                      fontSize: 12,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 5,
                                  ),
                                  Text(
                                    "${roundQuantity(calculateTotalAvailable(item.variants))}",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.blue[700]),
                                  ),
                                ],
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Giá lẻ:',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                        Text(
                                          item.variants.isEmpty
                                              ? '0 đ'
                                              : (hasAnyPermission([
                                                  "view_retail_cost_product"
                                                ])
                                                  ? '${vnd.format(item.variants?[0].retailCost)} đ'
                                                  : '${hiddenPrice(item.variants?[0].retailCost)} đ'),
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Color(0xff179A6E)),
                                        ),
                                      ]),
                                  Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Giá buôn:',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                        Text(
                                          item.variants.isEmpty
                                              ? '0 đ'
                                              : (hasAnyPermission([
                                                  "view_wholesale_cost_product"
                                                ])
                                                  ? '${vnd.format(item.variants?[0].wholesaleCost)} đ'
                                                  : '${hiddenPrice(item.variants?[0].wholesaleCost)} đ'),
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Colors.blue[700]),
                                        ),
                                      ]),
                                ],
                              ),
                            ],
                          ),
                        )
                      ],
                    )),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                color: Colors.grey[300],
              ),
            ),
          ],
        ),
        if (canEdit())
          Positioned(
            top: 0,
            right: 0,
            child: PopupMenuButton<String>(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              onSelected: (String value) {
                if (value == 'delete') {
                  _deleteProduct(item.id);
                }
                if (value == 'not_show') {
                  _show(item.id, false);
                }
                if (value == 'show') {
                  _show(item.id, true);
                }
                if (value == 'edit') {
                  if (Auth.user<User>()?.careerType != CareerType.other) {
                    if (item?.type == 1) {
                      routeTo(EditProductPage.path, data: {
                        'is_clone': false,
                        'id': item.id,
                        'store_id': selectedStore?.id,
                      }, onPop: (value) {
                        _pagingController.refresh();
                      });
                    } else {
                      routeTo(EditProductServicePage.path, data: item.id,
                          onPop: (value) {
                        _pagingController.refresh();
                      });
                    }
                  } else {
                    routeTo(EditProductPage.path, data: {
                      'is_clone': false,
                      'id': item.id,
                      'store_id': selectedStore?.id,
                    }, onPop: (value) {
                      _pagingController.refresh();
                    });
                  }
                }
                if (value == 'clone') {
                  if (Auth.user<User>()?.careerType != CareerType.other) {
                    if (item?.type == 1) {
                      routeTo(EditProductPage.path, data: {
                        'is_clone': true,
                        'id': item.id,
                      }, onPop: (value) {
                        _pagingController.refresh();
                      });
                    } else {
                      routeTo(EditProductServicePage.path, data: {
                        'is_clone': true,
                        'id': item.id,
                      }, onPop: (value) {
                        _pagingController.refresh();
                      });
                    }
                  } else {
                    routeTo(EditProductPage.path, data: {
                      'is_clone': true,
                      'id': item.id,
                    }, onPop: (value) {
                      _pagingController.refresh();
                    });
                  }
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                if (canEdit())
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          color: Colors.blue[600],
                          size: 20,
                        ),
                        SizedBox(width: 16),
                        Text(
                          'Sửa',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isSameStore())
                  (item.show == true)
                      ? PopupMenuItem<String>(
                          value: 'not_show',
                          child: Row(
                            children: [
                              Icon(
                                Icons.visibility_off_outlined,
                                color: Colors.orange[600],
                                size: 20,
                              ),
                              SizedBox(width: 16),
                              Text(
                                'Dừng bán',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : PopupMenuItem<String>(
                          value: 'show',
                          child: Row(
                            children: [
                              Icon(
                                Icons.visibility_outlined,
                                color: Colors.green[600],
                                size: 20,
                              ),
                              SizedBox(width: 16),
                              Text(
                                'Mở bán',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                if (isSameStore())
                  PopupMenuItem<String>(
                    value: 'clone',
                    child: Row(
                      children: [
                        Icon(
                          Icons.file_copy_outlined,
                          color: Colors.purple[600],
                          size: 20,
                        ),
                        SizedBox(width: 16),
                        Text(
                          'Sao chép',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isSameStore()) PopupMenuDivider(),
                if (isSameStore())
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          color: Colors.red[600],
                          size: 20,
                        ),
                        SizedBox(width: 16),
                        Text(
                          'Xóa',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Colors.red[600],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          )
      ]),
    );
  }

  void _pickExcelFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
    );
    if (result != null) {
      PlatformFile file = result.files.first;
      showLoaderDialog(context);
      final response = await api<ProductApiService>(
          (request) => request.uploadProductsExcel(file));
      if (saveDialogLoadingContext != null) {
        Navigator.pop(saveDialogLoadingContext!);
        saveDialogLoadingContext = null;
      }
      if (response.data["success"] == true) {
        CustomToast.showToastSuccess(context,
            description:
                'Tải file thành công, hệ thống sẽ cập nhật 1-2 phút. Xin cảm ơn!');
      } else {
        CustomToast.showToastError(context,
            description: "Tải file không thành công, vui lòng thử lại sau");
      }
    } else {
      // User canceled the picker
    }
  }

  showLoaderDialog(BuildContext context) {
    //set up the AlertDialog
    AlertDialog alert = AlertDialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      content: Container(
        child: Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      ),
    );
    showDialog(
      //prevent outside touch
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        //prevent Back button press
        saveDialogLoadingContext = context;
        return WillPopScope(onWillPop: () async => false, child: alert);
      },
    );
  }

  void _deleteProduct(int? id) {
    if (id == null) {
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Xác nhận'),
          content: Text('Bạn có chắc chắn muốn xóa sản phẩm này?'),
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
              child: Text(
                'Hủy',
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                  backgroundColor: ThemeColor.get(context).primaryAccent,
                  foregroundColor: Colors.white),
              onPressed: () async {
                // Call api to delete category
                await api<ProductApiService>(
                    (request) => request.deleteProduct(id));
                Navigator.of(context).pop();
                setState(() {});
                _pagingController.refresh();
              },
              child: Text(
                'Xóa',
              ),
            ),
          ],
        );
      },
    );
  }

  void _show(int? id, bool? show) {
    if (id == null) {
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return (show == true)
            ? AlertDialog(
                title: Text('Xác nhận'),
                content: Text('Bạn có chắc chắn muốn mở bán sản phẩm này?'),
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
                    child: Text(
                      'Hủy',
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                        backgroundColor: ThemeColor.get(context).primaryAccent,
                        foregroundColor: Colors.white),
                    onPressed: () async {
                      // Call api to delete category
                      await api<ProductApiService>(
                          (request) => request.show(id, show!));
                      Navigator.of(context).pop();
                      setState(() {});
                      _pagingController.refresh();
                    },
                    child: Text(
                      'Đồng ý',
                    ),
                  ),
                ],
              )
            : AlertDialog(
                title: Text('Xác nhận'),
                content: Text('Bạn có chắc chắn muốn dừng sản phẩm này?'),
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
                    child: Text(
                      'Hủy',
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                        backgroundColor: ThemeColor.get(context).primaryAccent,
                        foregroundColor: Colors.white),
                    onPressed: () async {
                      // Call api to delete category
                      await api<ProductApiService>(
                          (request) => request.show(id, show!));
                      Navigator.of(context).pop();
                      setState(() {});
                      _pagingController.refresh();
                    },
                    child: Text(
                      'Đồng ý',
                    ),
                  ),
                ],
              );
      },
    );
  }

  void confirmDeleteList() {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10))),
            title: Stack(
              children: [
                Center(
                    child: Text(
                  'Xác nhận',
                  style: TextStyle(fontWeight: FontWeight.bold),
                )),
                Positioned(
                  right: 0,
                  top: 0,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    child: Icon(
                      Icons.close,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              'Bạn có chắc chắn muốn xóa những sản phẩm này?',
              style: TextStyle(fontSize: 15),
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 30),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0)),
                        backgroundColor: ThemeColor.get(context)
                            .primaryAccent
                            .withOpacity(0.1),
                        foregroundColor: ThemeColor.get(context).primaryAccent),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _deleteSelectedProducts();
                    },
                    child: Text('Xoá'),
                  ),
                ],
              )
            ],
          );
        });
  }
}
