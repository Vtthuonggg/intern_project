import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/app/networking/cash_book_api_service.dart';
import 'package:flutter_app/app/utils/message.dart';
import 'package:flutter_app/resources/dashed_divider.dart';
import 'package:flutter_app/resources/pages/add_storage_page.dart';
import 'package:flutter_app/resources/pages/custom_toast.dart';
import 'package:flutter_app/resources/pages/manage_table/manage_table_page.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:nylo_framework/nylo_framework.dart';
import 'package:thermal_printer/thermal_printer.dart';
import '../../app/models/user.dart';
import '../../app/networking/order_api_service.dart';
import '../../app/utils/formatters.dart';
import '../../bootstrap/helpers.dart';
import '../widgets/single_tap_detector.dart';
import '/app/controllers/controller.dart';
import 'detail_add_storage_order_page.dart';
import 'order/detail_order_page.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

enum DateFilterType { today, weekAgo, monthAgo, threeMonthAgo, yearAgo, custom }

enum FilterOrderStatus {
  waitingConfirm,
  waitingPack,
  complete,
  shipping,
  cancel,
  orderReturn,
  deposting,
}

enum FilterPaymentStatus { haftPayment, completed }

extension FilterPaymentStatusExtension on FilterPaymentStatus {
  int getValue() {
    switch (this) {
      case FilterPaymentStatus.haftPayment:
        return 2;
      case FilterPaymentStatus.completed:
        return 3;
    }
  }

  String getTitle() {
    switch (this) {
      case FilterPaymentStatus.haftPayment:
        return 'Còn nợ';
      case FilterPaymentStatus.completed:
        return 'Đã thanh toán';
    }
  }
}

extension FilterOrderStatusExtension on FilterOrderStatus {
  int getValue() {
    switch (this) {
      case FilterOrderStatus.waitingConfirm:
        return 1;
      case FilterOrderStatus.waitingPack:
        return 2;
      case FilterOrderStatus.complete:
        return 4;
      case FilterOrderStatus.shipping:
        return 3;
      case FilterOrderStatus.cancel:
        return 5;
      case FilterOrderStatus.orderReturn:
        return 6;
      case FilterOrderStatus.deposting:
        return 8;
    }
  }

  String getTitle() {
    switch (this) {
      case FilterOrderStatus.waitingConfirm:
        return 'Chờ xác nhận';
      case FilterOrderStatus.waitingPack:
        return 'Chờ đóng gói';
      case FilterOrderStatus.complete:
        return 'Hoàn thành';
      case FilterOrderStatus.shipping:
        return 'Đang giao hàng';
      case FilterOrderStatus.cancel:
        return 'Đã hủy';
      case FilterOrderStatus.orderReturn:
        return 'Trả hàng';
      case FilterOrderStatus.deposting:
        return 'Đặt cọc';
    }
  }
}

enum FilterStatusType { orderStatus, paymentStatus }

extension DateFilterTypeExtension on DateFilterType {
  String getTitle() {
    switch (this) {
      case DateFilterType.today:
        return 'Hôm nay';
      case DateFilterType.weekAgo:
        return '7 ngày qua';
      case DateFilterType.monthAgo:
        return '30 ngày qua';
      case DateFilterType.threeMonthAgo:
        return '90 ngày qua';
      case DateFilterType.yearAgo:
        return '12 tháng qua';
      case DateFilterType.custom:
        return 'Tùy chỉnh ngày';
    }
  }

  DateTimeRange? getRangeTime() {
    switch (this) {
      case DateFilterType.today:
        return DateTimeRange(start: DateTime.now(), end: DateTime.now());
      case DateFilterType.weekAgo:
        var now = DateTime.now();
        return DateTimeRange(
            start: DateTime(now.year, now.month, now.day - 7), end: now);
      case DateFilterType.monthAgo:
        var now = DateTime.now();
        return DateTimeRange(
            start: DateTime(now.year, now.month, now.day - 30), end: now);
      case DateFilterType.threeMonthAgo:
        var now = DateTime.now();
        return DateTimeRange(
            start: DateTime(now.year, now.month, now.day - 90), end: now);
      case DateFilterType.yearAgo:
        var now = DateTime.now();
        return DateTimeRange(
            start: DateTime(now.year - 1, now.month, now.day), end: now);
      case DateFilterType.custom:
        return null;
    }
  }
}

final Map<int, String> orderStatus = {
  1: 'Chờ xác nhận',
  2: 'Chờ đóng gói',
  3: 'Đang giao hàng',
  4: 'Hoàn thành',
  5: 'Đã hủy',
  6: 'Trả hàng',
  7: 'Đã hủy',
  8: 'Đặt cọc'
};

final Map<int, Color> orderStatusColor = {
  1: Colors.orange,
  2: Colors.deepPurple,
  3: Colors.cyan,
  4: Colors.green,
  5: Colors.grey,
  6: Colors.grey[600]!,
  7: Colors.grey,
  8: Colors.pink
};

class OrderListAllPage extends NyStatefulWidget {
  final Controller controller = Controller();
  bool? onTabbar = false;
  static const path = '/order-list-all';

  OrderListAllPage({Key? key, this.onTabbar}) : super(key: key);

  @override
  _OrderListAllPageState createState() => _OrderListAllPageState();
}

class _OrderListAllPageState extends NyState<OrderListAllPage> with RouteAware {
  final SlidableController slidableController = SlidableController();

  List<dynamic> _selectedOrderIds = [];

  List<int>? pendingTask = [];
  bool isConnectedPrinter = false;
  var printerManager = PrinterManager.instance;
  int invoiceId = 0;
  String imageBase64Decode = '';
  bool _isLoadingPrinter = false;
  dynamic orderData;
  bool _isStoreLoading = false;
  _deleteItem(dynamic item, int type) async {
    final confirm = await showDialog(
        barrierDismissible: false,
        context: context,
        builder: (context) => AlertDialog(
              title: Text('Xác nhận'),
              content: Text('Bạn có chắc chắn muốn xóa đơn hàng này không?'),
              actions: <Widget>[
                TextButton(
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.red[700],
                      side: BorderSide(color: Colors.red[700]!),
                      backgroundColor: Colors.transparent),
                  child: Text('Không'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.red[700]),
                  child: Text('Có'),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            ));
    if (confirm) {
      await api<CashBookApiService>(
          (request) => request.deleteCashBook(item['id']));
      if (type == 1) {
        removeItemAndRefresh(_pagingStorageController, item);
      } else if (type == 2) {
        removeItemAndRefresh(_pagingOrderController, item);
      }
      setState(() {});
    }
  }

  void removeItemAndRefresh(PagingController controller, dynamic item) {
    controller.itemList?.remove(item);
    if (item['status_order'] == 6) {
      controller.refresh();
    }
  }

  Future<void> getSelectedInvoiceId() async {
    try {
      int? selectedInvoiceId = await NyStorage.read('selectedInvoiceId');
      if (selectedInvoiceId != null) {
        invoiceId = selectedInvoiceId;
      }
    } catch (e) {}
  }

  double getSlidableActionRatio(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 600) {
      return 0.18;
    }
    return 0.35;
  }

  _deleteItemReturn(dynamic item, int type) {
    return showDialog(
        context: context,
        builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            backgroundColor: Colors.white,
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return Stack(children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Xác nhận",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            )),
                        Divider(),
                        SizedBox(
                          height: 10,
                        ),
                        Text(
                          type == 1
                              ? 'Bạn có muốn xóa đơn và trả lại hàng hóa cho nhà cung cấp không?'
                              : 'Bạn có muốn xóa đơn hàng và hoàn lại hàng hóa vào kho sau khi xóa không?',
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(
                          height: 20,
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  style: TextButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      side: BorderSide(
                                        color: ThemeColor.get(context)
                                            .primaryAccent,
                                      ),
                                      backgroundColor: Colors.white,
                                      foregroundColor: ThemeColor.get(context)
                                          .primaryAccent),
                                  onPressed: () async {
                                    setState(() {
                                      _isLoading = true;
                                    });
                                    try {
                                      await api<CashBookApiService>((request) =>
                                          request.deleteCashBook(item['id'],
                                              isReturn: false));

                                      if (type == 1) {
                                        _pagingStorageController.refresh();
                                      } else if (type == 2) {
                                        _pagingOrderController.refresh();
                                      }
                                      setState(() {});

                                      CustomToast.showToastSuccess(context,
                                          description: "Xóa đơn thành công");
                                      Navigator.pop(context);
                                    } catch (e) {
                                      CustomToast.showToastError(context,
                                          description: "Xóa đơn thất bại");
                                    } finally {
                                      setState(() {
                                        _isLoading = false;
                                      });
                                    }
                                  },
                                  child: _isLoading
                                      ? CircularProgressIndicator(
                                          color: ThemeColor.get(context)
                                              .primaryAccent,
                                        )
                                      : Text(type == 1
                                          ? 'Không trả lại hàng'
                                          : 'Xóa và không hoàn kho'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 5,
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  style: TextButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      backgroundColor:
                                          ThemeColor.get(context).primaryAccent,
                                      foregroundColor: Colors.white),
                                  onPressed: () async {
                                    setState(() {
                                      _isLoading = true;
                                    });
                                    try {
                                      await api<CashBookApiService>((request) =>
                                          request.deleteCashBook(item['id'],
                                              isReturn: true));

                                      if (type == 1) {
                                        _pagingStorageController.refresh();
                                      } else if (type == 2) {
                                        _pagingOrderController.refresh();
                                      }
                                      setState(() {});

                                      CustomToast.showToastSuccess(context,
                                          description: "Xóa đơn thành công");
                                      Navigator.pop(context);
                                    } catch (e) {
                                      CustomToast.showToastError(context,
                                          description: "Xóa đơn thất bại");
                                    } finally {
                                      setState(() {
                                        _isLoading = false;
                                      });
                                    }
                                  },
                                  child: _isLoading
                                      ? CircularProgressIndicator(
                                          color: Colors.white,
                                        )
                                      : Text(type == 1
                                          ? 'Có trả lại hàng'
                                          : 'Xóa và hoàn kho'),
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  Positioned(
                    right: 5,
                    top: 0,
                    child: IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  )
                ]);
              },
            )));
  }

  bool haveOrderList() {
    return (widget.onTabbar ?? false)
        ? (Auth.user()?.permissions ?? []).contains('list_order')
        : widget.data()['is_order'] ?? false;
  }

  bool haveStorageList() {
    return (widget.onTabbar ?? false)
        ? (Auth.user()?.permissions ?? []).contains('list_ordesbuy')
        : !(widget.data()['is_order'] ?? false);
  }

  dynamic total = {
    "total": 0,
    "retail_cost": 0,
  };
  List<Map<String, dynamic>> sortData = [
    {
      'id': 1,
      'name': 'Mã đơn hàng giảm dần',
      'sort': 'code',
      'is_check_order_type': false
    },
    {
      'id': 2,
      'name': 'Mã đơn hàng tăng dần',
      'sort': '-code',
      'is_check_order_type': false
    },
    {
      'id': 3,
      'name': 'Ngày (cũ nhất trước)',
      'sort': '-created_at',
      'is_check_order_type': false
    },
    {
      'id': 4,
      'name': 'Ngày (mới nhất trước)',
      'sort': 'created_at',
      'is_check_order_type': false
    },
    {
      'id': 5,
      'name': 'Tổng tiền đơn hàng (cao đến thấp)',
      'sort_order': 'retail_cost',
      'sort_storage': 'base_cost',
      'is_check_order_type': true
    },
    {
      'id': 6,
      'name': 'Tổng tiền đơn hàng (thấp đến cao)',
      'sort_order': '-retail_cost',
      'sort_storage': '-base_cost',
      'is_check_order_type': true
    },
  ];
  List<DateFilterType> dateFilterData = DateFilterType.values;
  List<FilterOrderStatus> dataStatus = FilterOrderStatus.values;
  List<FilterPaymentStatus> dataPaymentStatus = FilterPaymentStatus.values;
  Timer? _debounce;
  int selectedTabIndex = 0;
  static const _pageSize = 20;
  final PageController pageController =
      PageController(initialPage: 0, keepPage: true);
  final PagingController<int, dynamic> _pagingOrderController =
      PagingController(firstPageKey: 1);
  final PagingController<int, dynamic> _pagingStorageController =
      PagingController(firstPageKey: 1);

  // final RefreshController _refreshOrderController = RefreshController();
  // final RefreshController _refreshStorageController = RefreshController();

  DateTime fromDateStorage = DateTime.now();
  DateTime toDateStorage = DateTime.now();
  DateTime fromDateOrder = DateTime.now();
  DateTime toDateOrder = DateTime.now();
  DateFilterType? selectedDateTypeStorage;
  DateFilterType? selectedDateTypeOrder;

  String? selectedDateTypeStorageValue = 'created_at';
  String? selectedDateTypeOrderValue = 'created_at';
  List<FilterOrderStatus> selectedStatusStorage = [];
  List<FilterPaymentStatus> selectedPaymentStatusStorage = [];
  List<FilterOrderStatus> selectedStatusOrder = [];
  List<FilterPaymentStatus> selectedPaymentStatusOrder = [];
  String? searchStorage = '';
  String? searchOrder = '';
  Map<String, dynamic>? currentSortStorage;
  Map<String, dynamic>? currentSortOrder;
  bool isLoadPrinting = false;

  TextEditingController searchController = TextEditingController();
  bool _isLoading = false;

  int storeId = -1;
  bool isPrintWithAccent = false;

  DateTime getFromDate() {
    return _isStoragePage() ? fromDateStorage : fromDateOrder;
  }

  DateTime getToDate() {
    return _isStoragePage() ? toDateStorage : toDateOrder;
  }

  setFromDate(DateTime dateTime) {
    _isStoragePage() ? fromDateStorage = dateTime : fromDateOrder = dateTime;
  }

  setToDate(DateTime dateTime) {
    _isStoragePage() ? toDateStorage = dateTime : toDateOrder = dateTime;
  }

  bool _isStoragePage() {
    return (haveStorageList() && selectedTabIndex == 0);
  }

  bool _isOrderPage() {
    if (haveOrderList() && haveStorageList()) {
      return selectedTabIndex == 1;
    } else if (!haveStorageList() && haveOrderList()) {
      return selectedTabIndex == 0;
    }
    return false;
  }

  String getPageTitle() {
    if (haveOrderList() && haveStorageList()) {
      return 'Quản lý đơn hàng';
    } else if (haveStorageList() && !haveOrderList()) {
      return 'Đơn nhập hàng';
    }
    return 'Đơn bán hàng';
  }

  @override
  init() async {
    super.init();
  }

  didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void didPush() {
    super.didPush();
    reloadData();
  }

  @override
  void initState() {
    if (haveOrderList()) {
      _pagingOrderController.addPageRequestListener((pageKey) {
        _fetchOrderPage(pageKey);
      });
    }
    if (haveStorageList()) {
      _pagingStorageController.addPageRequestListener((pageKey) {
        _fetchStoragePage(pageKey);
      });
    }

    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  reloadData() {
    if (_isOrderPage()) {
      _pagingOrderController.refresh();
    } else if (_isStoragePage()) {
      _pagingStorageController.refresh();
    }
  }

  Future<void> _fetchOrderPage(int pageKey) async {
    _isStoreLoading = true;
    try {
      var search = _isStoragePage() ? searchStorage : searchOrder;
      var currentSort =
          _isStoragePage() ? currentSortStorage : currentSortOrder;
      var selectedDateType =
          _isStoragePage() ? selectedDateTypeStorage : selectedDateTypeOrder;
      var selectedStatus =
          _isStoragePage() ? selectedStatusStorage : selectedStatusOrder;
      var selectedPaymentStatus = _isStoragePage()
          ? selectedPaymentStatusStorage
          : selectedPaymentStatusOrder;
      var sort = currentSort?['sort'];
      if ((currentSort?['is_check_order_type'] ?? false)) {
        if (_isOrderPage()) {
          sort = currentSort?['sort_order'];
        } else if (_isStoragePage()) {
          sort = currentSort?['sort_storage'];
        }
      }
      DateTimeRange? newDateRange;

      String dateType = _isStoragePage()
          ? selectedDateTypeStorageValue ?? 'created_at'
          : selectedDateTypeOrderValue ?? 'created_at';

      if (selectedDateType != DateFilterType.custom) {
        newDateRange = selectedDateType?.getRangeTime();
      } else {
        newDateRange = DateTimeRange(start: getFromDate(), end: getToDate());
      }
      dynamic result = await api<OrderApiService>((request) =>
          request.listOrderV3(
              pageKey,
              _pageSize,
              newDateRange,
              search,
              sort,
              selectedStatus.map((e) => e.getValue()).toList(),
              selectedPaymentStatus.map((e) => e.getValue()).toList(),
              dateType: dateType));
      List<dynamic> newItems = result['data'];
      final isLastPage = newItems.length < _pageSize;
      if (isLastPage) {
        _pagingOrderController.appendLastPage(newItems);
      } else {
        final nextPageKey = pageKey + 1;
        _pagingOrderController.appendPage(newItems, nextPageKey);
      }

      setState(() {
        total = result['total'];
      });
    } catch (error) {
      _pagingOrderController.error = error;
    } finally {
      _isStoreLoading = false;
      // _refreshOrderController.refreshCompleted();
    }
  }

  num getTotal(dynamic order) {
    num serviceFee =
        order['service_fee'] + (order['service_fee'] * order['vat'] / 100);
    return order['retail_cost'] + serviceFee;
  }

  Future<void> _fetchStoragePage(int pageKey) async {
    _isStoreLoading = true;
    try {
      var search = _isStoragePage() ? searchStorage : searchOrder;
      var currentSort =
          _isStoragePage() ? currentSortStorage : currentSortOrder;
      var selectedDateType =
          _isStoragePage() ? selectedDateTypeStorage : selectedDateTypeOrder;
      var selectedStatus =
          _isStoragePage() ? selectedStatusStorage : selectedStatusOrder;
      var selectedPaymentStatus = _isStoragePage()
          ? selectedPaymentStatusStorage
          : selectedPaymentStatusOrder;
      var sort = currentSort?['sort'];
      if ((currentSort?['is_check_order_type'] ?? false)) {
        if (_isOrderPage()) {
          sort = currentSort?['sort_order'];
        } else if (_isStoragePage()) {
          sort = currentSort?['sort_storage'];
        }
      }
      DateTimeRange? newDateRange;

      String dateType = _isStoragePage()
          ? selectedDateTypeStorageValue ?? 'created_at'
          : selectedDateTypeOrderValue ?? 'created_at';

      if (selectedDateType != DateFilterType.custom) {
        newDateRange = selectedDateType?.getRangeTime();
      } else {
        newDateRange = DateTimeRange(start: getFromDate(), end: getToDate());
      }
      dynamic result = await api<OrderApiService>((request) =>
          request.listAddStorageOrderV3(
              pageKey,
              _pageSize,
              newDateRange,
              search,
              sort,
              selectedStatus.map((e) => e.getValue()).toList(),
              selectedPaymentStatus.map((e) => e.getValue()).toList(),
              dateType: dateType));
      List<dynamic> newItems = result['data'];
      final isLastPage = newItems.length < _pageSize;
      if (isLastPage) {
        _pagingStorageController.appendLastPage(newItems);
      } else {
        final nextPageKey = pageKey + 1;
        _pagingStorageController.appendPage(newItems, nextPageKey);
      }

      setState(() {
        total = result['total'];
      });
    } catch (error) {
      _pagingStorageController.error = error;
    } finally {
      _isStoreLoading = false;
    }
  }

  void _jumpToPage(int index) {
    // use this to animate to the page
    pageController.animateToPage(index,
        duration: Duration(milliseconds: 50), curve: Curves.linear);
    searchController.text =
        (_isStoragePage() ? searchStorage : searchOrder) ?? '';
    // or this to jump to it without animating
  }

  int getFilterParam() {
    var num = 0;
    if ((_isStoragePage() ? selectedDateTypeStorage : selectedDateTypeOrder) !=
        null) {
      num += 1;
    }
    if ((_isStoragePage() ? selectedStatusStorage : selectedStatusOrder)
            .length >
        0) {
      num += 1;
    }
    if ((_isStoragePage()
                ? selectedPaymentStatusStorage
                : selectedPaymentStatusOrder)
            .length >
        0) {
      num += 1;
    }
    return num;
  }

  _debounceSearch() {
    if (_debounce?.isActive ?? false) {
      _debounce?.cancel();
    }
    _debounce = Timer(const Duration(milliseconds: 1500), () {
      handleSearch();
    });
  }

  _resetData() {
    // currentSort = null;
    if (_isStoragePage()) {
      selectedPaymentStatusStorage = [];
      selectedStatusStorage = [];
      selectedDateTypeStorage = null;
      selectedDateTypeStorageValue = 'created_at';
      fromDateStorage = DateTime.now();
      toDateStorage = DateTime.now();
      _pagingStorageController.refresh();
    } else {
      selectedPaymentStatusOrder = [];
      selectedStatusOrder = [];
      selectedDateTypeOrder = null;
      selectedDateTypeStorageValue = 'created_at';
      fromDateOrder = DateTime.now();
      toDateOrder = DateTime.now();
      _pagingOrderController.refresh();
    }
  }

  _resetSort() {
    _isStoragePage() ? currentSortStorage = null : currentSortOrder = null;
    _isStoragePage()
        ? _pagingStorageController.refresh()
        : _pagingOrderController.refresh();
  }

  handleSearch() {
    if (_debounce?.isActive ?? false) {
      _debounce?.cancel();
    }
    if (haveOrderList() && _isOrderPage()) {
      _pagingOrderController.refresh();
    }
    if (haveStorageList() && _isStoragePage()) {
      _pagingStorageController.refresh();
    }
  }

  bool canEdit(item, int type) {
    // Loại phòng, bàn ko được sửa status
    if (type == 2) {
      if (Auth.user<User>()?.careerType != CareerType.other) {
        return false;
      }
      return item['status_order'] != 4 &&
          item['status_order'] != 5 &&
          item['status_order'] != 7 &&
          item['status_order'] != 6;
    } else {
      return item['status_order'] != 4 &&
          item['status_order'] != 5 &&
          item['status_order'] != 6 &&
          item['status_order'] != 7;
    }
  }

  getListStatus(item, int type) {
    // Chờ xác nhận
    if (type == 2) {
      if (item['status_order'] == 1 ||
          item['status_order'] == 3 ||
          item['status_order'] == 2) {
        return [1, 2, 3, 4, 5]; // ẩn trả hàng
      }
      if (item['status_order'] == 8) {
        return [4, 8];
      }
      return [1, 3, 4, 5, 6, 7, 8];
    } else {
      if (item['status_order'] == 1) {
        return [1, 4, 5]; // ẩn trả hàng
      }
      if (item['status_order'] == 8) {
        return [4, 8];
      }
      return [1, 4, 5, 6, 7, 8];
    }
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);
    return Scaffold(
      appBar: AppBar(
        actions: [buildAddAction()],
        title:
            Text(getPageTitle(), style: TextStyle(fontWeight: FontWeight.bold)),
        shadowColor: null,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            if (_isLoadingPrinter)
              Container(
                color: Colors.grey.withOpacity(0.5),
                height: double.infinity,
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text("Đang in đơn"),
                    SizedBox(
                      height: 10,
                    ),
                    CircularProgressIndicator(
                      color: ThemeColor.get(context).primaryAccent,
                    ),
                  ],
                ),
              ),
            Column(
              children: [
                if (haveOrderList() && haveStorageList())
                  Row(
                    children: [
                      Expanded(
                          child: SingleTapDetector(
                        onTap: () {
                          setState(() {
                            selectedTabIndex = 0;
                            _jumpToPage(0);
                          });
                        },
                        child: Container(
                            height: 45,
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: ThemeColor.get(context).primaryAccent),
                              color: selectedTabIndex == 0
                                  ? Colors.white
                                  : ThemeColor.get(context).primaryAccent,
                            ),
                            child: Center(
                              child: Text(
                                'Nhập',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 14,
                                    color: selectedTabIndex == 0
                                        ? Colors.black
                                        : Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            )),
                      )),
                      Expanded(
                          child: SingleTapDetector(
                        onTap: () {
                          setState(() {
                            selectedTabIndex = 1;
                            _jumpToPage(1);
                          });
                        },
                        child: Container(
                            height: 45,
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: ThemeColor.get(context).primaryAccent),
                              color: selectedTabIndex == 1
                                  ? Colors.white
                                  : ThemeColor.get(context).primaryAccent,
                            ),
                            child: Center(
                              child: Text(
                                'Bán',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 14,
                                    color: selectedTabIndex == 1
                                        ? Colors.black
                                        : Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            )),
                      )),
                    ],
                  ),
                SizedBox(height: 16),
                _buildSearchBar(context),
                SizedBox(
                  height: 12,
                ),
                Expanded(
                    child: PageView(
                  controller: pageController,
                  physics: NeverScrollableScrollPhysics(),
                  children: [
                    if (haveStorageList())
                      RefreshIndicator(
                        color: ThemeColor.get(context).primaryAccent,
                        onRefresh: () => Future.sync(
                          () => _pagingStorageController.refresh(),
                        ),
                        child: PagedListView<int, dynamic>(
                          pagingController: _pagingStorageController,
                          builderDelegate: PagedChildBuilderDelegate<dynamic>(
                            firstPageErrorIndicatorBuilder: (context) => Center(
                              child: Text(getResponseError(
                                  _pagingOrderController.error)),
                            ),
                            newPageErrorIndicatorBuilder: (context) => Center(
                              child: Text(getResponseError(
                                  _pagingOrderController.error)),
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
                                  color: ThemeColor.get(context).primaryAccent),
                            ),
                            itemBuilder: (context, item, index) =>
                                buildStorageItem(item, context),
                            noItemsFoundIndicatorBuilder: (_) => Center(
                                child: const Text("Không tìm thấy đơn nào")),
                          ),
                        ),
                      ),
                    if (haveOrderList())
                      RefreshIndicator(
                        color: ThemeColor.get(context).primaryAccent,
                        onRefresh: () => Future.sync(
                          () => _pagingOrderController.refresh(),
                        ),
                        child: PagedListView<int, dynamic>(
                          pagingController: _pagingOrderController,
                          builderDelegate: PagedChildBuilderDelegate<dynamic>(
                            firstPageErrorIndicatorBuilder: (context) => Center(
                              child: Text(getResponseError(
                                  _pagingOrderController.error)),
                            ),
                            newPageErrorIndicatorBuilder: (context) => Center(
                              child: Text(getResponseError(
                                  _pagingOrderController.error)),
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
                                  color: ThemeColor.get(context).primaryAccent),
                            ),
                            itemBuilder: (context, item, index) =>
                                buildOrderItem(item, context),
                            noItemsFoundIndicatorBuilder: (_) => Center(
                                child: const Text("Không tìm thấy đơn nào")),
                          ),
                        ),
                      ),
                  ],
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildAddAction() {
    if (Auth.user<User>()?.careerType == CareerType.other) {
      return IconButton(
        icon: Icon(
          Icons.add_circle,
          size: 30,
        ),
        onPressed: () {
          if (_isOrderPage()) {
            routeTo(ManageTablePage.path, onPop: (value) {
              reloadData();
            });
          } else if (_isStoragePage()) {
            routeTo(AddStoragePage.path, onPop: (value) {
              reloadData();
            });
          }
        },
      );
    }
    return PopupMenuButton(
      icon: Icon(
        Icons.add_circle,
        size: 30,
      ),
      itemBuilder: (BuildContext context) {
        return [
          PopupMenuItem(
            child: Text("Tạo đơn nhập hàng"),
            value: 1,
          ),
          PopupMenuItem(
            child: Text(
              'Tạo đơn bán hàng',
            ),
            value: 2,
          ),
        ];
      },
      onSelected: (value) {
        if (value == 1) {
          routeTo(AddStoragePage.path, onPop: (value) {
            reloadData();
          });
        } else if (value == 2) {
          routeTo(ManageTablePage.path, onPop: (value) {
            reloadData();
          });
        }
      },
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        keyboardType: TextInputType.text,
        controller: searchController,
        onChanged: (value) {
          if (_isStoragePage()) {
            searchStorage = value;
          } else {
            searchOrder = value;
          }
          _debounceSearch();
        },
        onSubmitted: (value) {
          if (_isStoragePage()) {
            searchStorage = value;
          } else {
            searchOrder = value;
          }
          handleSearch();
        },
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        textAlign: TextAlign.left,
        cursorColor: ThemeColor.get(context).primaryAccent,
        decoration: InputDecoration(
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide:
                  BorderSide(color: ThemeColor.get(context).primaryAccent),
            ),
            suffixIcon: Container(
              width: 100,
              padding: EdgeInsets.all(0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SingleTapDetector(
                      onTap: () {
                        _showShortBottomSheet(context);
                      },
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                          color: ThemeColor.get(context).primaryAccent,
                        ),
                        child: Icon(
                          Icons.swap_vert,
                          color: Colors.white,
                        ),
                      )),
                  SizedBox(
                    width: 8,
                  ),
                ],
              ),
            ),
            prefixIcon: Container(
              width: 30,
              height: 30,
              child: Center(
                child: Icon(
                  Icons.search,
                  color: Colors.grey,
                ),
              ),
            ),
            // icon: Icon(Icons.contact_page),
            // border: UnderlineInputBorder(),
            floatingLabelBehavior: FloatingLabelBehavior.never,
            hintText: 'Lọc đơn hàng'),
      ),
    );
  }

  Widget buildOrderItem(dynamic item, BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Slidable(
                controller: slidableController,
                key: ValueKey(item),
                actionPane: SlidableDrawerActionPane(),
                actionExtentRatio: getSlidableActionRatio(context),
                secondaryActions: <Widget>[
                  Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: ((item['status_order'] == 1 ||
                              item['status_order'] == 5 ||
                              item['status_order'] == 6 ||
                              item['status_order'] == 7 ||
                              item['status_order'] == 8 ||
                              (item['status_order'] == 4) &&
                                  (Auth.user()?.type == 2)))
                          ? Container(
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              child: IconSlideAction(
                                caption: 'Xóa',
                                foregroundColor: Colors.red,
                                color: Colors.transparent,
                                icon: Icons.delete,
                                onTap: () async {
                                  if (item['status_order'] == 4) {
                                    await _deleteItemReturn(item, 2);
                                    if (item['order_refund'] != null &&
                                        item['order_refund'].isNotEmpty) {
                                      _pagingOrderController.refresh();
                                    }
                                  } else {
                                    _deleteItem(item, 2);
                                  }
                                },
                                closeOnTap: false,
                              ),
                            )
                          : Container()),
                ],
                child: Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(
                    right: 15.0,
                    left: 15.0,
                  ),
                  child: InkWell(
                    onTap: () {
                      routeTo(DetailOrderPage.path, data: item, onPop: (data) {
                        _pagingOrderController.refresh();
                      });
                    },
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (item['name'] != null)
                                        ? item['name']
                                        : "Khách lẻ",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  (item['shipping_code'] == null)
                                      ? Text(
                                          "Mã: ${item['code']}",
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 14,
                                          ),
                                        )
                                      : Text(
                                          "Mã: ${item['code']} / ${item['shipping_code']}",
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 14,
                                          ),
                                        ),
                                  if (Auth.user<User>()?.careerType !=
                                          CareerType.other &&
                                      (item['room'] != null &&
                                          item['room'].isNotEmpty &&
                                          item['room']['area'] != null &&
                                          item['room']['area'].isNotEmpty))
                                    Text(
                                      "Bàn: ${item['room']?['area']['name'] ?? ''} - ${item['room']['name'] ?? ''}",
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                    ),
                                  Text(
                                    "Ngày bán: ${formatDate(item['created_at'])}",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                  (item['user']?['name'] == null)
                                      ? Text(
                                          "Nhân viên: ${item['user']?['phone']}",
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 14,
                                          ),
                                        )
                                      : Text(
                                          "Nhân viên: ${item['user']?['name']}",
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 14,
                                          ),
                                        ),
                                ],
                              ),
                            ),
                            SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (canEdit(item, 2))
                                  Builder(
                                    builder: (BuildContext buttonContext) {
                                      return InkWell(
                                        onTap: () => _showOrderMenu(
                                            buttonContext, item, 2),
                                        borderRadius: BorderRadius.circular(20),
                                        child: Padding(
                                          padding: EdgeInsets.only(bottom: 8),
                                          child: Icon(
                                            Icons.more_vert,
                                            size: 20,
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                else
                                  SizedBox(
                                    height: 20,
                                  ),
                                buildStatus(item['status_order']),
                                SizedBox(height: 2),
                                Text(
                                  vndCurrency.format(getTotal(item)),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.black,
                                  ),
                                ),
                                if (item['debt'] > 0)
                                  Text.rich(
                                    TextSpan(
                                      text: 'Nợ: ',
                                      children: <TextSpan>[
                                        TextSpan(
                                          text:
                                              vndCurrency.format(item['debt']),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12.0,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.0,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        buildRefundList(item),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: Divider(
            color: Colors.grey[300],
          ),
        )
      ],
    );
  }

  Widget buildStorageItem(dynamic item, BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Slidable(
                controller: slidableController,
                key: ValueKey(item),
                actionPane: SlidableDrawerActionPane(),
                actionExtentRatio: getSlidableActionRatio(context),
                secondaryActions: <Widget>[
                  Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: ((item['status_order'] == 1 ||
                                  item['status_order'] == 5 ||
                                  item['status_order'] == 6 ||
                                  item['status_order'] == 7 ||
                                  item['status_order'] == 4) &&
                              (Auth.user()?.type == 2))
                          ? Container(
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              child: IconSlideAction(
                                closeOnTap: false,
                                caption: 'Xoá',
                                foregroundColor: Colors.red,
                                color: Colors.transparent,
                                icon: Icons.delete,
                                onTap: () async {
                                  if (item['status_order'] == 4) {
                                    await _deleteItemReturn(item, 1);
                                    if (item['order_refund'] != null &&
                                        item['order_refund'].isNotEmpty) {
                                      _pagingStorageController.refresh();
                                    }
                                  } else {
                                    _deleteItem(item, 1);
                                  }
                                },
                              ),
                            )
                          : Container()),
                ],
                child: Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(
                    right: 15.0,
                    left: 15.0,
                  ),
                  child: InkWell(
                    onTap: () {
                      routeTo(DetailAddStorageOrderPage.path, data: item,
                          onPop: (data) {
                        _pagingStorageController.refresh();
                      });
                    },
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (item['supplier'] != null)
                                        ? item['supplier']['name']
                                        : "Đại lý",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    item['code'] == null
                                        ? 'Mã:'
                                        : "Mã: ${item['code']}",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    "Ngày nhập: ${formatDate(item['created_at'])}",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (canEdit(item, 1))
                                  Builder(
                                    builder: (BuildContext buttonContext) {
                                      return InkWell(
                                        onTap: () => _showOrderMenu(
                                            buttonContext, item, 1),
                                        borderRadius: BorderRadius.circular(20),
                                        child: Padding(
                                          padding: EdgeInsets.only(bottom: 8),
                                          child: Icon(
                                            Icons.more_vert,
                                            size: 20,
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                else
                                  SizedBox(height: 20),
                                buildStatus(item['status_order']),
                                Text(
                                  vndCurrency.format(item['base_cost']),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                if (item['debt'] > 0)
                                  Text.rich(
                                    TextSpan(
                                      text: 'Nợ: ',
                                      children: <TextSpan>[
                                        TextSpan(
                                          text:
                                              vndCurrency.format(item['debt']),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12.0,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.0,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        buildRefundList(item),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: Divider(
            color: Colors.grey[300],
          ),
        ),
      ],
    );
  }

  Align buildTotal() {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "Tổng tiền: ${vndCurrency.format(total['retail_cost'])}",
                  style: TextStyle(),
                ),
                SizedBox(height: 5.0),
                Text(
                  "Tổng SL Đơn: ${total['total']}",
                  style: TextStyle(),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildStatus(int status) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: orderStatusColor[status],
        borderRadius: BorderRadius.circular(5.0),
      ),
      child: Text(
        orderStatus[status] ?? "",
        style: TextStyle(
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  _showShortBottomSheet(BuildContext context) {
    showModalBottomSheet(
        isScrollControlled: true,
        context: context,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setStateModal) {
            return Container(
              height: 0.6.sh,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10.0),
                    topRight: Radius.circular(10.0)),
                color: Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Stack(children: [
                    Align(
                        alignment: Alignment.center,
                        child: Container(
                          margin: EdgeInsets.only(top: 16, bottom: 10),
                          child: Text(
                            'Sắp xếp theo',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        )),
                    Positioned(
                      left: 0,
                      // top: 8.h,
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          size: 30,
                        ),
                        onPressed: () {
                          // widget.multiKey.currentState?.closeDropDownSearch();
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    if (_isStoragePage()
                        ? (currentSortStorage != null)
                        : (currentSortOrder != null))
                      Positioned(
                        right: 0,
                        // top: 8.h,
                        child: TextButton.icon(
                          onPressed: () {
                            _resetSort();
                            // widget.multiKey.currentState?.closeDropDownSearch();
                            Navigator.pop(context);
                          },
                          icon: Icon(
                            Icons.refresh,
                            color: ThemeColor.get(context).primaryAccent,
                          ),
                          label: Text(
                            'Đặt lại',
                            style: TextStyle(
                                color: ThemeColor.get(context).primaryAccent),
                          ),
                        ),
                      ),
                  ]),
                  Divider(color: Colors.grey),
                  Expanded(
                      child: ListView(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    children: sortData.map((e) {
                      return SingleTapDetector(
                          onTap: () {
                            if (_isStoragePage()) {
                              if (currentSortStorage?['id'] != e['id']) {
                                currentSortStorage = e;
                                setStateModal(() {});
                              }
                            } else {
                              if (currentSortOrder?['id'] != e['id']) {
                                currentSortOrder = e;
                                setStateModal(() {});
                              }
                            }
                            _debounceSearch();
                          },
                          child: Container(
                            // padding: EdgeInsets.symmetric(horizontal: 4.0),
                            height: 45,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    // 16.horizontalSpace,
                                    e['id'] ==
                                            (_isStoragePage()
                                                ? (currentSortStorage?['id'])
                                                : (currentSortOrder?['id']))
                                        ? Icon(
                                            Icons.radio_button_on,
                                            color: ThemeColor.get(context)
                                                .primaryAccent,
                                          )
                                        : Icon(Icons.radio_button_off),
                                    8.horizontalSpace,
                                    Text(
                                      e['name'] ?? '',
                                    ),
                                  ],
                                ),
                                2.verticalSpace,
                                Divider(color: Colors.grey),
                              ],
                            ),
                          ));
                    }).toList(),
                  )),
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          backgroundColor:
                              ThemeColor.get(context).primaryAccent,
                          foregroundColor: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text('Xác nhận'),
                    ),
                  ),
                  SizedBox(
                    height: 20,
                  )
                ],
              ),
            );
          });
        });
  }

  Widget buildRefundList(dynamic order) {
    List<dynamic> refundList = order['order_refund_show'].runtimeType == List
        ? order['order_refund_show']
        : [];

    if (refundList.length == 0) {
      return Container();
    }

    return Column(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5.0),
              child: DashedDivider(
                dashColor: Colors.grey[300]!,
              ),
            ),
            ...refundList.map((e) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.refresh, color: Colors.red, size: 16),
                        SizedBox(
                          width: 6,
                        ),
                        InkWell(
                          onTap: () {
                            if (order['type'] == 2) {
                              routeTo(DetailAddStorageOrderPage.path, data: {
                                'id': e['order_id'],
                                'type': order['type'],
                              }, onPop: (data) {
                                _pagingOrderController.refresh();
                              });
                            } else {
                              routeTo(DetailOrderPage.path, data: {
                                'id': e['order_id'],
                                'type': order['type'],
                              }, onPop: (data) {
                                _pagingOrderController.refresh();
                              });
                            }
                          },
                          child: Text(
                              e['code'] != null ? 'Mã: ${e['code']}' : 'Mã:',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                    Text('SL: ${roundQuantity(e['quantity'])}',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12)),
                    Text('Tiền: ${vndCurrency.format((e['price'].abs()))}',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 12)),
                  ],
                ))
          ],
        ),
      ],
    );
  }

  void _showOrderMenu(BuildContext buttonContext, dynamic item, int type) {
    final RenderBox renderBox = buttonContext.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);

    showMenu(
      context: context, // Sử dụng context chính của widget
      position: RelativeRect.fromLTRB(
        position.dx - 100, // Điều chỉnh vị trí x
        position.dy + renderBox.size.height,
        0,
        0,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'edit_status_order',
          child: Row(
            children: [
              Icon(Icons.edit, size: 20),
              SizedBox(width: 12),
              Text('Đổi trạng thái'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'edit_status_order') {
        showEditStatus(item, type);
      }
    });
  }

  void showEditStatus(dynamic item, int type) {
    int selectedStatus = item['status_order'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateModal) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10.0),
                  topRight: Radius.circular(10.0),
                ),
                color: Colors.white,
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.all(16),
                    child: Stack(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Đổi trạng thái',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Positioned(
                          right: 0,
                          top: -5,
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).pop();
                            },
                            child: Icon(
                              Icons.close,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1),

                  // Content
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: double.infinity,
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<int>(
                            value: selectedStatus,
                            isExpanded: true,
                            underline: SizedBox.shrink(),
                            onChanged: canEdit(item, type)
                                ? (int? newValue) {
                                    setStateModal(() {
                                      selectedStatus = newValue!;
                                    });
                                  }
                                : null,
                            items: getListStatus(item, type)
                                .map<DropdownMenuItem<int>>((int value) {
                              return DropdownMenuItem<int>(
                                value: value,
                                child: Text(
                                  orderStatus[value] ?? '',
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    color: orderStatusColor[value],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[300],
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: Text('Hủy'),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      ThemeColor.get(context).primaryAccent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () async {
                                  try {
                                    await api<OrderApiService>((request) =>
                                        request.updateStatusOrder(
                                            item['id'], selectedStatus));
                                    Navigator.pop(context);
                                    CustomToast.showToastSuccess(context,
                                        description:
                                            "Cập nhật trạng thái thành công");
                                    setState(() {
                                      item['status_order'] = selectedStatus;
                                    });
                                  } catch (e) {
                                    CustomToast.showToastError(context,
                                        description:
                                            "Cập nhật trạng thái thất bại");
                                  }
                                },
                                child: Text('Xác nhận'),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
