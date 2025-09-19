import 'dart:developer';

import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/app/models/user.dart';
import 'package:flutter_app/app/networking/order_api_service.dart';
import 'package:flutter_app/app/utils/formatters.dart';
import 'package:flutter_app/app/utils/message.dart';
import 'package:flutter_app/app/utils/permission.dart';
import 'package:flutter_app/app/utils/socket_manager.dart';
import 'package:flutter_app/app/utils/text.dart';
import 'package:flutter_app/bootstrap/helpers.dart';
import 'package:flutter_app/resources/dashed_divider.dart';
import 'package:flutter_app/resources/pages/add_storage_page.dart';
import 'package:flutter_app/resources/pages/custom_toast.dart';
import 'package:flutter_app/resources/pages/order_invoice_page.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:intl/intl.dart';
import 'package:nylo_framework/nylo_framework.dart';
import '/app/controllers/controller.dart';
import 'order/list_order_page.dart';
import 'order/return_order_page.dart';

class DetailAddStorageOrderPage extends NyStatefulWidget {
  final Controller controller = Controller();

  static const path = '/detail-add-storage-order';

  DetailAddStorageOrderPage({Key? key}) : super(key: key);

  @override
  _DetailAddStorageOrderPageState createState() =>
      _DetailAddStorageOrderPageState();
}

class _DetailAddStorageOrderPageState
    extends NyState<DetailAddStorageOrderPage> {
  int selectedOrderStatus = 1;
  int tempSelectStatus = 1;
  int invoiceId = 0;
  final Map<int, String> paymentStatus = {
    1: 'Chờ thanh toán',
    2: 'Thanh toán một phần',
    3: 'Đã thanh toán',
  };

  final Map<int, Color> paymentStatusColor = {
    1: Colors.orange,
    2: Colors.deepPurple,
    3: Colors.green,
  };
  bool _isLoading = false;
  late Future _future;
  late dynamic orderData = {};
  SocketManager _socketManager = SocketManager();
  bool get isSameStore => widget.data()?['is_same_store'] ?? true;

  @override
  init() async {
    super.init();
  }

  @override
  initState() {
    _future = fetchDetail();
    super.initState();
    getSelectedInvoiceId();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future _updateStatus() async {
    try {
      final response = await api<OrderApiService>((request) =>
          request.updateStatusOrder(widget.data()?['id'], selectedOrderStatus));
      CustomToast.showToastSuccess(context,
          description:
              'Cập nhật trạng thái ${text('_sale_order_detail_title', 'đơn hàng')} thành công');
      if (selectedOrderStatus == 4) {
        _socketManager.sendEvent('user', {'user_id': Auth.user<User>()!.id});
      }
      setState(() {
        _future = fetchDetail();
      });
    } catch (e) {
      CustomToast.showToastError(context,
          description:
              'Cập nhật trạng thái ${text('_sale_order_detail_title', 'đơn hàng')} thất bại');
    }
  }

  Future fetchDetail() async {
    final res = await api<OrderApiService>((request) => request.detailOrder(
        widget.data()?['id'],
        storeId: widget.data()?['store_id']));
    orderData = res;
    selectedOrderStatus = res['status_order'];
    tempSelectStatus = selectedOrderStatus;
    setState(() {});
    return res;
  }

  Future _shareOrder() async {
    routeTo(OrderInvoicePage.path, data: {
      'id': widget.data()?['id'],
      'order_type': widget.data()['type'],
      'invoice_id': invoiceId,
      'count_item': orderData['order_detail'].length,
      'payment_type': orderData['order_payment'][0]['type'],
      'order_service_fee': orderData['order_service_fee'],
    });
  }

  Future<void> getSelectedInvoiceId() async {
    try {
      int? selectedInvoiceId = await NyStorage.read('selectedInvoiceId');
      if (selectedInvoiceId != null) {
        invoiceId = selectedInvoiceId;
      }
    } catch (e) {}
  }

  void _showPay(BuildContext context, dynamic order) {
    showModalBottomSheet(
        isScrollControlled: true,
        context: context,
        builder: (BuildContext context) {
          return Container(
            height: 0.6 * MediaQuery.of(context).size.height,
            padding: EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Thanh toán', style: TextStyle(fontSize: 20)),
                  SizedBox(height: 16.0),
                  AddPayment(
                    orderId: widget.data()?['id'],
                    max: getDebt(order),
                    onFailed: (message) {
                      CustomToast.showToastError(context, description: message);
                    },
                    onSuccessful: (message) {
                      _socketManager.sendEvent(
                          'user', {'user_id': Auth.user<User>()!.id});
                      CustomToast.showToastSuccess(context,
                          description: 'Thanh toán thành công');
                      Navigator.pop(context);
                      setState(() {
                        _future = fetchDetail();
                      });
                    },
                  ),
                  buildOrderInfo()
                ],
              ),
            ),
          );
        });
  }

  bool canEdit() {
    return orderData['status_order'] != 4 &&
        orderData['status_order'] != 5 &&
        orderData['status_order'] != 6 &&
        orderData['status_order'] != 7;
  }

  bool isSuccessful() {
    return orderData['status_order'] == 4;
  }

  bool needPay(orderData) {
    return orderData['status'] != 3 &&
        orderData['status_order'] != 5 &&
        orderData['status_order'] != 7;
  }

  bool isReturn(orderData) {
    return orderData['status_order'] == 6;
  }

  bool canReturnOrder() {
    bool isSuccess = orderData['status_order'] == 4;
    bool remain = getRemainNum(orderData) > 0;

    return isSuccess && remain;
  }

  double getRemainNum(dynamic order) {
    double totalNum = 0;
    double returnedNum = 0;

    order['order_detail']?.forEach((orderDetail) {
      double quantity = (orderDetail['quantity'] as num).toDouble();
      totalNum += quantity;
    });

    order['order_refund']?.forEach((orderReturn) {
      double quantity = (orderReturn['quantity'] as num).toDouble();
      returnedNum += quantity;
    });

    return totalNum - returnedNum;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (orderData['status_order'] != 6)
              Text(
                text("purchase_order_detail_title_room", 'Phiếu nhập hàng'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  // fontSize: 16.0,
                ),
              ),
            if (orderData['status_order'] == 6)
              Text(
                "Chi tiết trả hàng",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  // fontSize: 16.0,
                ),
              ),
          ],
        ),
        actions: [
          if (buildOrderMenu() != null) buildOrderMenu()!,
        ],
      ),
      body: SafeArea(
        child: Container(
          padding: EdgeInsets.all(16.0),
          child: FutureBuilder(
              future: _future,
              builder: (context, snapshot) {
                switch (snapshot.connectionState) {
                  case ConnectionState.none:
                  case ConnectionState.waiting:
                    return const Center(child: CircularProgressIndicator());
                  case ConnectionState.active:
                  case ConnectionState.done:
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Đã có lỗi xảy ra'),
                      );
                    } else if (snapshot.hasData) {
                      dynamic orderData = snapshot.data;

                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text.rich(
                                        TextSpan(
                                          text: 'Mã ',
                                          style: TextStyle(
                                              fontSize: 16.0,
                                              fontWeight: FontWeight.bold),
                                          children: [
                                            TextSpan(
                                              text:
                                                  '${text('_sale_order_detail_title', 'đơn hàng')}:',
                                              style: TextStyle(
                                                  fontSize: 16.0,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            TextSpan(
                                              text:
                                                  ' ${orderData?['code'] ?? ''}',
                                              style: TextStyle(
                                                fontSize: 16.0,
                                                fontWeight: FontWeight.w500,
                                                color: ThemeColor.get(context)
                                                    .primaryAccent,
                                              ),
                                            ),
                                          ],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      if (isSuccessful() && isSameStore)
                                        InkWell(
                                          onTap: () {
                                            showEditOrderCode(orderData);
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                                left: 6.0),
                                            child: Icon(
                                              Icons.edit,
                                              color: ThemeColor.get(context)
                                                  .primaryAccent,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (isReturn(orderData))
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(width: 10),
                                        Text(
                                          "Trả hàng từ đơn",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.black),
                                        ),
                                        SizedBox(width: 5),
                                        InkWell(
                                          onTap: isSameStore
                                              ? () async {
                                                  final sourceOrder = await api<
                                                          OrderApiService>(
                                                      (request) =>
                                                          request.detailOrder(
                                                              orderData['order']
                                                                  ['id'],
                                                              storeId: widget
                                                                      .data()?[
                                                                  'store_id']));
                                                  routeTo(
                                                      DetailAddStorageOrderPage
                                                          .path,
                                                      data: sourceOrder);
                                                }
                                              : null,
                                          child: Text(
                                            orderData['order']?['code'] != null
                                                ? orderData['order']['code']
                                                : '',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.blue),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            Divider(height: 30),
                            buildOrderStatus(),
                            Divider(height: 30),
                            buildOrderGeneralInfo(),
                            Divider(height: 30),
                            buildOrderInfo(),
                            // buildListPayment(context, orderData),
                            if (orderData['note'] != null) ...[
                              Divider(height: 30),
                              Text(
                                'Ghi chú:',
                                style: TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(orderData['note']),
                            ],
                            // Text(
                            //   'Thông tin nhà cung cấp:',
                            //   style: TextStyle(
                            //       fontSize: 16.0, fontWeight: FontWeight.bold),
                            // ),
                            // SizedBox(height: 8.0),
                            // Text('Tên: ${orderData['name'] ?? ''}'),
                            // SizedBox(height: 8.0),
                            // Text('Số điện thoại: ${orderData['phone']}'),
                            // SizedBox(height: 8.0),
                            // Text('Địa chỉ: ${orderData['address'] ?? ''}'),
                            // Divider(height: 30.0),
                            if (orderData['order_service_fee'].isNotEmpty)
                              buildOtherFee(),
                            Divider(height: 30.0),
                            buildDetail(),
                            SizedBox(height: 8.0),
                            if (isSuccessful() &&
                                (orderData['order_refund'] != null &&
                                    orderData['order_refund'].isEmpty) &&
                                (Auth.user()?.type == 2 || hasManagerRole()) &&
                                isSameStore)
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          backgroundColor:
                                              ThemeColor.get(context)
                                                  .primaryAccent),
                                      onPressed: () async {
                                        await cancelOrder();
                                      },
                                      child: Text(
                                        "Huỷ đơn hàng",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                          ],
                        ),
                      );
                    }
                }

                return Center(
                    child: CircularProgressIndicator(
                  color: ThemeColor.get(context).primaryAccent,
                ));
              }),
        ),
      ),
    );
  }

  Widget buildDetail() {
    final accent = ThemeColor.get(context).primaryAccent;
    num totalQuantity = orderData['order_detail']
        .fold(0, (sum, item) => sum + (item['quantity'] as num));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chi tiết ${text('_product_title', 'sản phẩm')}:',
              style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                    children: [
                      TextSpan(text: 'Tổng SL: '),
                      TextSpan(
                        text: '$totalQuantity',
                        style: TextStyle(color: accent),
                      ),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                    children: [
                      TextSpan(text: 'Tổng tiền: '),
                      TextSpan(
                        text: hasPermission('view_base_cost_product')
                            ? vndCurrency.format(orderData['base_cost'])
                            : hiddenPrice(orderData['base_cost']),
                        style: TextStyle(color: accent),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 8.0),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: orderData['order_detail'].length,
          itemBuilder: (context, index) {
            final orderDetail = orderData['order_detail'][index];
            final product = orderDetail['product'];
            final variant = orderDetail['variant'];
            final List<dynamic> listBatchs = orderDetail['batch'] ?? [];
            final orderStatus = orderData['status_order'];
            num base_cost_base = orderDetail['base_cost_base'];
            num base_cost = orderDetail['base_cost'];
            num user_cost = orderDetail['user_cost'];
            if (orderStatus == 6) {
              base_cost_base =
                  (orderDetail['base_cost_base'] as num).toDouble() * -1;
              base_cost = (orderDetail['base_cost'] as num).toDouble() * -1;
            }
            String listImage = getImages(variant);

            return Card(
              elevation: 0.2,
              margin: EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              color: Colors.grey[50],
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 50,
                          height: 50,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: FadeInImage(
                              placeholder:
                                  AssetImage(getImageAsset('placeholder.png')),
                              image: NetworkImage(
                                  listImage.isNotEmpty ? listImage : ''),
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
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: variant?['name'] ??
                                          product?['name'] ??
                                          '',
                                      style: TextStyle(
                                        fontSize: 15.0,
                                        fontWeight: FontWeight.bold,
                                        color: accent,
                                      ),
                                    ),
                                    if (orderDetail['is_promoted_product'] ==
                                        true) ...[
                                      WidgetSpan(child: SizedBox(width: 8)),
                                      WidgetSpan(
                                        child: ShaderMask(
                                          shaderCallback: (bounds) =>
                                              LinearGradient(
                                            colors: [
                                              Color(0xFFED2874),
                                              Color(0xffFF724A)
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ).createShader(bounds),
                                          child: Text(
                                            'Tặng',
                                            style: TextStyle(
                                              fontSize: 12.0,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text('${variant['sku']}',
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.grey[700])),
                              Text(
                                orderDetail['discount_type'] ==
                                        DiscountType.percent.getValueRequest()
                                    ? 'Chiết khấu: ${roundQuantity(orderDetail['discount'])}%'
                                    : 'Chiết khấu: ${vnd.format(orderDetail['discount'] / orderDetail['quantity'])}đ',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey[700]),
                              ),
                              if (orderDetail['size'] != null)
                                Text('Kích thước: ${orderDetail['size']}',
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.grey[700])),
                            ],
                          ),
                        ),
                        SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                                'Số lượng: ${roundQuantity(orderDetail['quantity'])}',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: accent)),
                            Text(
                                'Đơn giá: ${hasPermission('view_base_cost_product') ? vndCurrency.format(user_cost) : hiddenPrice(user_cost)}',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold)),
                            Text(
                                'Thành tiền: ${hasPermission('view_base_cost_product') ? vndCurrency.format(base_cost) : hiddenPrice(base_cost)}',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                    if (product?['unit'] != null &&
                        product?['unit'].isNotEmpty &&
                        orderDetail['sub_unit_quantity'] != null)
                      Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Text('Đơn vị: ', style: TextStyle(fontSize: 13)),
                            Text(product?['unit'] ?? '',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                            SizedBox(width: 10),
                            Text('-'),
                            SizedBox(width: 10),
                            Text('SL:',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                            SizedBox(width: 10),
                            Text(
                                roundQuantity(orderDetail['sub_unit_quantity']),
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    if (listBatchs.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            DashedDivider(),
                            ...listBatchs.map((batch) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 3),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.circle,
                                              size: 10, color: accent),
                                          SizedBox(width: 5),
                                          Text('Mã: ${batch['name']}',
                                              style: TextStyle(fontSize: 13)),
                                        ],
                                      ),
                                      Text(
                                          'SL: ${roundQuantity(batch['quantity'])}',
                                          style: TextStyle(fontSize: 13)),
                                      Text(
                                          'HSD: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(batch['end']))}',
                                          style: TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                    if (orderDetail['imei'] != null &&
                        orderDetail['imei'].isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text('IMEI:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13)),
                            ),
                            ...orderDetail['imei'].map<Widget>((item) {
                              return Text('- ${item['imei']}',
                                  style: TextStyle(fontSize: 13));
                            }).toList(),
                          ],
                        ),
                      ),
                    if (orderDetail['topping'] != null &&
                        orderDetail['topping'].isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Topping:',
                                style: TextStyle(
                                    fontWeight: FontWeight.w500, fontSize: 13)),
                            ...orderDetail['topping'].map<Widget>((topping) {
                              return Row(
                                children: [
                                  Icon(Icons.circle_rounded,
                                      size: 6, color: Colors.grey[500]),
                                  SizedBox(width: 5),
                                  Text(
                                    '${topping['name'] ?? ''} - SL: ${roundQuantity(topping['quantity'])}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[700],
                                        fontSize: 13),
                                  ),
                                  Spacer(),
                                  Text(
                                    vndCurrency.format(
                                        (topping['retail_cost'] ?? 0) *
                                            topping['quantity']),
                                    style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[700],
                                        fontSize: 13),
                                  ),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    if (orderDetail['order_detail_note'] != null &&
                        orderDetail['order_detail_note'].isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Ghi chú:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13)),
                            ),
                            ...orderDetail['order_detail_note']
                                .map<Widget>((note) {
                              return Text('- ${note['name']}',
                                  style: TextStyle(fontSize: 13));
                            }).toList(),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void showEditOrderCode(dynamic orderData) {
    String code = orderData['code'];
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10))),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sửa mã đơn hàng',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    child: Icon(
                      Icons.close,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              content: FormBuilderTextField(
                  name: 'order_code',
                  initialValue: code,
                  onChanged: (value) {
                    if (value != null && value.isNotEmpty) {
                      code = value;
                    }
                  },
                  cursorColor: ThemeColor.get(context).primaryAccent,
                  decoration: InputDecoration(
                    labelText: 'Mã đơn hàng',
                    floatingLabelStyle: TextStyle(
                      color: Colors.black,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: ThemeColor.get(context).primaryAccent),
                    ),
                  )),
              actions: [
                Center(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      backgroundColor: ThemeColor.get(context)
                          .primaryAccent
                          .withOpacity(0.2),
                      foregroundColor: ThemeColor.get(context).primaryAccent,
                    ),
                    onPressed: () {
                      updateOrderCode(
                        orderData['id'],
                        code,
                      );
                    },
                    child: _isLoading
                        ? CircularProgressIndicator(
                            color: ThemeColor.get(context).primaryAccent,
                          )
                        : Text('Xác nhận'),
                  ),
                ),
              ]);
        });
  }

  updateOrderCode(int id, String code) async {
    if (_isLoading) return;

    if (code.isEmpty) {
      CustomToast.showToastError(context, description: 'Không được để trống');
      return;
    }
    if (code.length > 20) {
      CustomToast.showToastError(context,
          description: 'Mã đơn hàng không được quá 20 ký tự');
      return;
    }
    Map<String, dynamic> payload = {
      'id': id,
      'order_code': code,
    };
    setState(() {
      _isLoading = true;
    });
    try {
      await api<OrderApiService>(
          (request) => request.updateOrderCode(id, payload));
      Navigator.of(context).pop();
      CustomToast.showToastSuccess(context, description: 'Cập nhật thành công');
      setState(() {
        orderData['code'] = code;
      });
    } catch (e) {
      CustomToast.showToastError(context, description: 'Cập nhật thất bại');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  cancelOrder() {
    return showDialog(
        context: context,
        builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            backgroundColor: Colors.white,
            child: StatefulBuilder(builder: (context, setState) {
              return Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Xác nhận",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            )),
                        Divider(),
                        SizedBox(
                          height: 10,
                        ),
                        Text(
                          'Bạn có muốn hủy đơn và trả lại ${text('_product_title', 'hàng hóa')} cho nhà cung cấp không?',
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
                                      await api<OrderApiService>(
                                        (request) => request.cancelOrder(
                                            orderData['id'],
                                            isReturn: false),
                                      );
                                      _socketManager.sendEvent('user',
                                          {'user_id': Auth.user<User>()!.id});

                                      Navigator.of(context).pop();
                                      CustomToast.showToastSuccess(context,
                                          description:
                                              'Hủy đơn hàng thành công');
                                      Navigator.of(context).pop();
                                    } catch (e) {
                                      CustomToast.showToastError(context,
                                          description: 'Hủy đơn hàng thất bại');
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
                                      : Text('Không trả lại hàng'),
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
                                      await api<OrderApiService>(
                                        (request) => request.cancelOrder(
                                            orderData['id'],
                                            isReturn: true),
                                      );
                                      Navigator.of(context).pop();
                                      _socketManager.sendEvent('user',
                                          {'user_id': Auth.user<User>()!.id});
                                      CustomToast.showToastSuccess(context,
                                          description:
                                              'Hủy đơn hàng thành công');
                                      Navigator.of(context).pop();
                                    } catch (e) {
                                      CustomToast.showToastError(context,
                                          description: 'Hủy đơn hàng thất bại');
                                    } finally {
                                      setState(() {
                                        _isLoading = false;
                                      });
                                    }
                                  },
                                  child: _isLoading
                                      ? CircularProgressIndicator(
                                          color: Colors.white)
                                      : Text('Có trả lại hàng'),
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
                ],
              );
            })));
  }

  void _deleteOrder() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Xác nhận'),
          content: Text(
              'Bạn có chắc chắn muốn huỷ ${text('_sale_order_detail_title', 'đơn hàng')} này'),
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
              child: Text('Bỏ qua'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                  backgroundColor: ThemeColor.get(context).primaryAccent,
                  foregroundColor: Colors.white),
              onPressed: () async {
                // Call api to delete category
                await api<OrderApiService>((request) =>
                    request.updateStatusOrder(widget.data()?['id'], 5));
                // close dialog
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: Text('Đồng ý'),
            ),
          ],
        );
      },
    );
  }

  Widget buildOrderStatus() {
    final accent = ThemeColor.get(context).primaryAccent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trạng thái',
          style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12.0),
        Row(
          children: [
            Icon(Icons.assignment_turned_in, color: Colors.teal, size: 20),
            SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Text('Trạng thái đơn:', style: TextStyle(fontSize: 16)),
            ),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Expanded(
                    child: FormBuilderDropdown<int>(
                      name: 'order_status',
                      enabled: canEdit() && isSameStore,
                      initialValue: selectedOrderStatus,
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      style: TextStyle(fontSize: 16.0, color: accent),
                      items: getListStatus()
                          .map<DropdownMenuItem<int>>(
                            (int value) => DropdownMenuItem<int>(
                              value: value,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  orderStatus[value] ?? '',
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.w600,
                                    color: orderStatusColor[value],
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (int? newValue) {
                        if (newValue != null) {
                          setState(() {
                            tempSelectStatus = newValue;
                          });
                        }
                      },
                    ),
                  ),
                  if ((selectedOrderStatus != tempSelectStatus) &&
                      canEdit() &&
                      isSameStore)
                    InkWell(
                      onTap: () async {
                        setState(() {});
                        selectedOrderStatus = tempSelectStatus;
                        await _updateStatus();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Icon(Icons.save, color: accent, size: 22),
                      ),
                    )
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.payments, color: Colors.blueAccent, size: 20),
            SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Text('Thanh toán:', style: TextStyle(fontSize: 16)),
            ),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      paymentStatus[orderData['status']] ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color:
                            paymentStatusColor[orderData['status']] ?? accent,
                      ),
                    ),
                  ),
                  if (needPay(orderData) && isSameStore) ...[
                    SizedBox(width: 8),
                    InkWell(
                      child: Icon(Icons.edit, color: accent, size: 18),
                      onTap: () => _showPay(context, orderData),
                    ),
                  ]
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildOrderInfo() {
    final accent = ThemeColor.get(context).primaryAccent;
    List<dynamic> listPayment = orderData['order_payment'] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tổng tiền & thanh toán',
          style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12.0),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.attach_money, color: Colors.teal, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child:
                        Text('Tổng cần trả:', style: TextStyle(fontSize: 16)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      hasPermission('view_base_cost_product')
                          ? vndCurrency.format(orderData['base_cost'])
                          : hiddenPrice(orderData['base_cost']),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.payments, color: Colors.blueAccent, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child:
                        Text('Đã thanh toán:', style: TextStyle(fontSize: 16)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      hasPermission('view_base_cost_product')
                          ? vndCurrency.format(getPaid(orderData))
                          : hiddenPrice(getPaid(orderData)),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.percent, color: Colors.deepPurpleAccent, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text('Chiết khấu:', style: TextStyle(fontSize: 16)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      getTotalDiscount(orderData),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.receipt_long,
                      color: Colors.orangeAccent, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text('Phí VAT:', style: TextStyle(fontSize: 16)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${vndCurrency.format(getVat(orderData))}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.money_off, color: Colors.redAccent, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text('Nợ:', style: TextStyle(fontSize: 16)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      vndCurrency.format(getDebt(orderData)),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 16.0),
        ...listPayment.map((payment) => ListTile(
              leading: Icon(Icons.circle_rounded, size: 12, color: Colors.teal),
              minLeadingWidth: 1,
              horizontalTitleGap: 10,
              dense: true,
              visualDensity: VisualDensity(vertical: -4),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 0, vertical: 0.0),
              title: Text.rich(
                TextSpan(
                  text: '${getPaymentTypeLabel(payment['type'])}: ',
                  children: <TextSpan>[
                    TextSpan(
                      text: hasPermission('view_base_cost_product')
                          ? '${vndCurrency.format(payment['price'])}'
                          : hiddenPrice(payment['price']),
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              trailing: Text(
                formatDate(payment['created_at']) ?? '',
                style: TextStyle(fontSize: 12.0, color: Colors.grey),
              ),
            )),
      ],
    );
  }

  Widget buildOrderGeneralInfo() {
    final accent = ThemeColor.get(context).primaryAccent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thông tin đơn hàng:',
          style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8.0),
        Row(
          children: [
            Icon(
              Icons.store,
              size: 20,
              color: Color(0xFF607D8B),
            ),
            SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Text('Đại lý:', style: TextStyle(fontSize: 16)),
            ),
            Expanded(
              flex: 3,
              child: Text(
                (orderData['supplier']?['name']?.toString().isNotEmpty == true)
                    ? orderData['supplier']['name']
                    : (orderData['supplier']?['phone']?.toString().isNotEmpty ==
                            true
                        ? orderData['supplier']['phone']
                        : '[Không có]'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: ((orderData['supplier']?['name']?.toString().isEmpty ??
                              true) &&
                          (orderData['supplier']?['phone']
                                  ?.toString()
                                  .isEmpty ??
                              true))
                      ? Colors.grey
                      : accent,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.0),
        Row(
          children: [
            Icon(Icons.person_outline, size: 20, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Text('Nhân viên:', style: TextStyle(fontSize: 16)),
            ),
            Expanded(
              flex: 3,
              child: Text(
                (orderData['user']?['name']?.toString().isNotEmpty == true)
                    ? orderData['user']['name']
                    : (orderData['user']?['phone']?.toString().isNotEmpty ==
                            true
                        ? orderData['user']['phone']
                        : '[Không có]'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: ((orderData['user']?['name']?.toString().isEmpty ??
                              true) &&
                          (orderData['user']?['phone']?.toString().isEmpty ??
                              true))
                      ? Colors.grey
                      : accent,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildOtherFee() {
    List<dynamic> orderServiceFee = orderData['order_service_fee'];
    return Column(
      children: [
        Divider(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text('Chi phí khác:',
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                )),
          ],
        ),
        SizedBox(height: 12.0),
        ...orderServiceFee.map((serviceFee) {
          return Row(
            children: [
              Icon(Icons.circle_rounded, size: 12, color: Colors.teal),
              SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Text(
                  serviceFee['name'],
                  style: TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    vndCurrency.format(serviceFee['price']),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget? buildOrderMenu() {
    if (!isSameStore) return null;

    List<PopupMenuEntry<String>> items = [];

    // Thêm option In hóa đơn
    items.add(
      PopupMenuItem<String>(
        value: 'print',
        child: ListTile(
          leading: Icon(Icons.print, color: Colors.deepPurple),
          title: Text('In hóa đơn'),
        ),
      ),
    );

    if (canReturnOrder()) {
      items.add(
        PopupMenuItem<String>(
          value: 'return',
          child: ListTile(
            leading: Icon(Icons.refresh, color: Colors.orange),
            title: Text('Trả hàng'),
          ),
        ),
      );
      items.add(
        PopupMenuItem<String>(
          value: 'clone',
          child: ListTile(
            leading: Icon(Icons.copy, color: Colors.blue),
            title: Text('Sao chép đơn'),
          ),
        ),
      );
    } else if (![4, 5, 6, 7].contains(orderData['status_order'])) {
      items.addAll([
        PopupMenuItem<String>(
          value: 'edit',
          child: ListTile(
            leading: Icon(Icons.edit_note, color: Colors.green),
            title: Text('Sửa đơn'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'clone',
          child: ListTile(
            leading: Icon(Icons.copy, color: Colors.blue),
            title: Text('Sao chép đơn'),
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_forever, color: Colors.red),
            title: Text('Hủy đơn'),
          ),
        ),
      ]);
    } else {
      items.add(
        PopupMenuItem<String>(
          value: 'clone',
          child: ListTile(
            leading: Icon(Icons.file_copy_sharp, color: Colors.blue),
            title: Text('Sao chép đơn'),
          ),
        ),
      );
    }

    if (items.isEmpty) return null;

    return PopupMenuButton<String>(
      tooltip: 'Tùy chọn',
      color: Colors.white,
      icon: Icon(Icons.more_vert),
      onSelected: (String value) {
        if (value == 'print') {
          _shareOrder();
        }
        if (value == 'return') {
          routeTo(ReturnOrderPage.path, data: {
            "order": widget.data()['order'] ?? widget.data(),
            "priceField": "base_cost_base",
          }, onPop: (data) {
            if (data != null) setState(() {});
          });
        }
        if (value == 'clone') {
          orderData['is_clone'] = true;
          routeTo(AddStoragePage.path, data: orderData, onPop: (data) {
            _future = fetchDetail();
          });
        }
        if (value == 'edit') {
          routeTo(AddStoragePage.path, data: orderData, onPop: (data) {
            _future = fetchDetail();
          });
        }
        if (value == 'delete') {
          _deleteOrder();
        }
      },
      itemBuilder: (BuildContext context) => items,
    );
  }

  num getPaid(dynamic order) {
    List<dynamic> listPayment = order['order_payment'] ?? [];
    num paid = 0;
    listPayment.forEach((payment) {
      paid += payment['price'];
    });
    if (order['status_order'] == 6) {
      paid = paid * -1;
    }

    return paid;
  }

  String getTotalDiscount(dynamic order) {
    return order['discount_type'] == DiscountType.price.getValueRequest()
        ? '${vnd.format(order['discount'])}đ'
        : '${roundQuantity(order['discount'])}%';
  }

  num getVat(dynamic order) {
    num vat = 0;
    for (var item in order['order_detail']) {
      final itemVat = item['vat'] ?? 0;
      num userCost = item['user_cost'] ?? 0;
      num quantity = item['quantity'] ?? 0;
      num discount = item['discount'] ?? 0;
      int discountType = item['discount_type'] ?? 0;

      num costAfterDiscount;
      if (discountType == 1) {
        costAfterDiscount = userCost * (1 - discount / 100);
      } else if (discountType == 2) {
        costAfterDiscount = userCost - (discount / quantity);
      } else {
        costAfterDiscount = userCost;
      }

      vat += itemVat / 100 * costAfterDiscount * quantity;
    }
    return roundMoney(vat);
  }

  double getDebt(dynamic order) {
    num debt = order['base_cost'] - getPaid(order);
    if (debt < 50) return 0;

    return double.parse(debt.toStringAsFixed(2));
  }

  getListStatus() {
    // Chờ xác nhận
    if (orderData['status_order'] == 1) {
      return [1, 4, 5]; // ẩn trả hàng
    }
    if (orderData['status_order'] == 8) {
      return [4, 8];
    }
    return [1, 4, 5, 6, 7, 8];
  }
}

class AddPayment extends StatefulWidget {
  AddPayment(
      {super.key,
      required this.orderId,
      required this.onSuccessful,
      required this.onFailed,
      this.max = double.infinity});

  int orderId;
  final Function(dynamic) onSuccessful;
  final Function(dynamic) onFailed;
  double max;

  @override
  State<AddPayment> createState() => _AddPaymentState();
}

class _AddPaymentState extends State<AddPayment> {
  final GlobalKey<FormBuilderState> _formKey = GlobalKey<FormBuilderState>();

  bool _isLoading = false;

  Future addPayment() async {
    if (_isLoading) {
      return;
    }

    if (!_formKey.currentState!.saveAndValidate()) {
      return;
    }

    dynamic payload = {
      'price': stringToInt(_formKey.currentState!.value['price']),
      'type': _formKey.currentState!.value['type'],
    };

    if (payload['price'] > widget.max) {
      widget.onFailed(
          'Số tiền không được lớn hơn ${vndCurrency.format(widget.max)}');
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      await api<OrderApiService>(
          (request) => request.addPayment(widget.orderId, payload));

      widget.onSuccessful("Thêm thành công");
      setState(() {});
    } catch (e) {
      widget.onFailed(getResponseError(e));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormBuilder(
      key: _formKey,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                child: FormBuilderTextField(
                    keyboardType: TextInputType.number,
                    name: 'price',
                    style: TextStyle(fontSize: 14),
                    onTapOutside: (event) {
                      FocusScope.of(context).unfocus();
                    },
                    textAlign: TextAlign.right,
                    inputFormatters: [
                      CurrencyTextInputFormatter(
                        locale: 'vi',
                        symbol: '',
                      )
                    ],
                    decoration: InputDecoration(
                      suffixText: 'đ',
                      label: Text('Số tiền'),
                    ),
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(),
                      FormBuilderValidators.min(1),
                    ])),
              ),
              SizedBox(width: 10),
              Expanded(
                child: FormBuilderDropdown(
                  name: 'type',
                  initialValue: 1,
                  decoration: InputDecoration(
                    labelText: 'Phương thức',
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 1,
                      child: Text('Tiền mặt', style: TextStyle(fontSize: 14)),
                    ),
                    DropdownMenuItem(
                      value: 2,
                      child:
                          Text('Chuyển khoản', style: TextStyle(fontSize: 14)),
                    ),
                    DropdownMenuItem(
                      value: 3,
                      child: Text('Quẹt thẻ', style: TextStyle(fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeColor.get(context).primaryAccent),
                onPressed: () {
                  addPayment();
                },
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Thanh toán',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
