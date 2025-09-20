import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_app/app/controllers/controller.dart';
import 'package:flutter_app/app/models/storage_item.dart';
import 'package:flutter_app/app/providers/table_notifier.dart';
import 'package:flutter_app/bootstrap/helpers.dart';
import 'package:flutter_app/resources/pages/pos/create_order_pos.dart';
import 'package:flutter_app/resources/pages/pos/select_menu_pos.dart';
import 'package:flutter_app/resources/widgets/manage_table/table_item.dart';
import 'package:nylo_framework/nylo_framework.dart';

class ReservationPosPage extends NyStatefulWidget {
  static const path = '/reservation-pos';
  final Controller controller = Controller();
  ReservationPosPage({Key? key}) : super(key: key);
  @override
  NyState<ReservationPosPage> createState() => _ReservationPosPageState();
}

class _ReservationPosPageState extends NyState<ReservationPosPage> {
  String get roomId => widget.data()['room_id'].toString();
  String? get buttonType => widget.data()['button_type'].toString();
  String? get areaName => widget.data()['area_name'] ?? '';
  String? get roomName => widget.data()['room_name'] ?? '';
  bool get isEditing => widget.data()?['edit_data'] != null;
  String get currentRoomType => widget.data()['current_room_type'].toString();
  dynamic get editData => widget.data()?['edit_data'];
  bool get showPay => widget.data()?['show_pay'] ?? false;
  String? get note => widget.data()?['note'];
  List<StorageItem> selectedItems = [];
  final GlobalKey<CreateOrderPosPageState> createOrderPosKey =
      GlobalKey<CreateOrderPosPageState>();
  late TableNotifier _tableNotifier;

  @override
  init() async {
    _tableNotifier = TableNotifier();
    _tableNotifier.addListener(_onTableNotifierUpdate);
    super.init();
  }

  @override
  void dispose() {
    super.dispose();
    _tableNotifier.removeListener(_onTableNotifierUpdate);
  }

  void _onTableNotifierUpdate() async {
    if (_tableNotifier.shouldOrderPosRefresh &&
        _tableNotifier.targetRoomIdPos == roomId &&
        mounted) {
      createOrderPosKey.currentState?.reloadEditData();
      _tableNotifier.refreshOrderPosCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: SelectMenuPos(
              key: ValueKey(roomId),
              getRoomId: () => roomId,
              getButtonType: () => buttonType,
              getAreaName: () => areaName,
              getRoomName: () => roomName,
              getIsEditing: () => isEditing,
              onSelectItem: (item) {
                createOrderPosKey.currentState?.addItem(item, null);
                setState(() {});
              },
            ),
          ),
          VerticalDivider(
            width: 2,
            thickness: 2,
            color: Colors.grey.shade300,
          ),
          Expanded(
            flex: 2,
            child: CreateOrderPos(
              getRoomId: () => roomId,
              getButtonType: () => buttonType,
              getAreaName: () => areaName ?? '',
              getRoomName: () => roomName ?? '',
              getCurrentRoomType: () => currentRoomType.toString(),
              getIsEditing: () => isEditing,
              getEditData: () => editData,
              getShowPay: () => showPay,
              getNote: () => note,
              getItems: () => selectedItems,
              key: createOrderPosKey,
            ),
          ),
        ],
      ),
    );
  }
}
