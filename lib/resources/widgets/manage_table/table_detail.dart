import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_app/app/models/user.dart';
import 'package:flutter_app/app/networking/order_api_service.dart';
import 'package:flutter_app/app/networking/room_api_service.dart';
import 'package:flutter_app/app/utils/message.dart';
import 'package:flutter_app/bootstrap/helpers.dart';
import 'package:flutter_app/resources/pages/custom_toast.dart';
import 'package:flutter_app/resources/pages/manage_table/beverage_reservation_page.dart';
import 'package:flutter_app/resources/pages/pos/reservation_pos_page.dart';
import 'package:flutter_app/resources/widgets/manage_table/table_item.dart';
import 'package:nylo_framework/nylo_framework.dart';

class TableDetail extends StatefulWidget {
  dynamic table;
  final VoidCallback refresh;

  TableDetail({
    super.key,
    required this.table,
    required this.refresh,
  });

  @override
  State<TableDetail> createState() => _TableDetailState();
}

class _TableDetailState extends State<TableDetail> {
  final _noteController = TextEditingController();

  bool _loading = false;

  get orderDetailFuture => _fetchOrderDetail();
  Future _fetchOrderDetail() async {
    var res = api<OrderApiService>(
        (request) => request.detailOrder(widget.table.order['id']));

    return res;
  }

  Future<void> _viewAndPay() async {
    setState(() {
      _loading = true;
    });

    final orderDetail = await orderDetailFuture;
    if (Auth.user<User>()?.isPosRoomUser == true) {
      routeTo(ReservationPosPage.path, data: {
        "room_id": widget.table.id,
        "edit_data": orderDetail,
        "room_type": TableStatus.using.toValue(),
        "current_room_type": TableStatus.using.toValue(),
        "show_pay": true,
        "note": _noteController.text,
      }, onPop: (value) {
        widget.refresh();
      });
    } else {
      routeTo(BeverageReservationPage.path, data: {
        "room_id": widget.table.id,
        "edit_data": orderDetail,
        "room_type": TableStatus.using.toValue(),
        "current_room_type": TableStatus.using.toValue(),
        "show_pay": true,
        "note": _noteController.text,
      }, onPop: (value) {
        widget.refresh();
      });
    }

    setState(() {
      _loading = false;
    });

    Navigator.pop(context);
  }

  Future<void> _cancelTable() async {
    if (_loading) {
      return;
    }
    setState(() {
      _loading = true;
    });
    try {
      await api<RoomApiService>((request) => request
          .cancelTable(widget.table.order['id'], note: _noteController.text));
      CustomToast.showToastSuccess(context, description: 'Hủy bàn thành công');
      widget.refresh();
      Navigator.pop(context);
    } catch (e) {
      CustomToast.showToastError(context, description: getResponseError(e));
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void createOrder() async {
    setState(() {
      _loading = true;
    });
    final orderDetail = await orderDetailFuture;
    if (Auth.user<User>()?.isPosRoomUser == true) {
      routeTo(ReservationPosPage.path, data: {
        "room_id": widget.table.id,
        "edit_data": orderDetail,
        "room_type": TableStatus.using.toValue(),
        "current_room_type": TableStatus.preOrder.toValue(),
        "show_pay": false,
        "note": _noteController.text,
        "area_name": widget.table.areaName ?? '',
        "room_name": widget.table.name ?? '',
      }, onPop: (value) {
        Navigator.pop(context);
        widget.refresh();
      });
    } else {
      routeTo(BeverageReservationPage.path, data: {
        "room_id": widget.table.id,
        "edit_data": orderDetail,
        "room_type": TableStatus.using.toValue(),
        "current_room_type": TableStatus.preOrder.toValue(),
        "show_pay": false,
        "area_name": widget.table.areaName ?? '',
        "room_name": widget.table.name ?? '',
        "note": _noteController.text,
      }, onPop: (value) {
        Navigator.pop(context);
        widget.refresh();
      });
    }
    setState(() {
      _loading = false;
    });
  }

  get modalTitle => widget.table.status == TableStatus.using
      ? 'Chi tiết bàn ${widget.table.name}'
      : 'Chi tiết đặt bàn ${widget.table.name}';

  @override
  void initState() {
    super.initState();
    _noteController.text = widget.table.order['note'] ?? '';
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              modalTitle,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Divider(),
            OrderDetail(
              orderDetailFuture: orderDetailFuture,
              table: widget.table,
            ),
            SizedBox(
              height: 20,
            ),
            buildNote(),
            SizedBox(
              height: 20,
            ),
            buildActions(),
          ],
        ),
      ),
    );
  }

  Widget buildNote() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Ghi chú:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(
            height: 10,
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '',
                    hintText: '',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildActions() {
    if (widget.table.status == TableStatus.using) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                backgroundColor: Colors.blue,
              ),
              onPressed: () {
                _viewAndPay();
              },
              child: _loading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Thanh toán',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ),
        ],
      );
    }

    if (widget.table.status == TableStatus.preOrder) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                _cancelTable();
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                backgroundColor: Colors.red,
              ),
              child: _loading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Khách huỷ',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ),
          SizedBox(
            width: 10,
          ),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                createOrder();
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                backgroundColor: Colors.blue,
              ),
              child: _loading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Tạo đơn',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ),
        ],
      );
    }

    return Container();
  }
}

class OrderDetail extends StatelessWidget {
  OrderDetail({
    super.key,
    required this.orderDetailFuture,
    required this.table,
  });

  Future orderDetailFuture;
  dynamic table;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
        future: orderDetailFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(getResponseError(snapshot.error)));
          }
          if (!snapshot.hasData) {
            return Center(
                child: CircularProgressIndicator(
              color: Colors.blue,
            ));
          }

          final order = snapshot.data;

          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Số điện thoại:',
                  ),
                  Text(
                    order['phone'] ?? '',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(
                height: 10,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Khách hàng:',
                  ),
                  Text(
                    order['name'] ?? '',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(
                height: 10,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    table.status == TableStatus.preOrder
                        ? 'Số người dự kiến:'
                        : 'Số người:',
                  ),
                  Text(
                    order['number_customer'] != null
                        ? "${order['number_customer']}"
                        : '',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(
                height: 10,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Thời gian dự kiến:'),
                  Text(
                    order['time_intend'] != null
                        ? "${order['time_intend']} phút"
                        : '',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          );
        });
  }
}
