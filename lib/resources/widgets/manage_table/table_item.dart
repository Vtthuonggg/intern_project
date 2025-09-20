import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_app/resources/pages/pos/reservation_pos_page.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_app/app/models/user.dart';
import 'package:flutter_app/app/networking/order_api_service.dart';
import 'package:flutter_app/app/networking/room_api_service.dart';
import 'package:flutter_app/app/utils/formatters.dart';
import 'package:flutter_app/app/utils/message.dart';
import 'package:flutter_app/bootstrap/helpers.dart';
import 'package:flutter_app/resources/pages/custom_toast.dart';
import 'package:flutter_app/resources/pages/manage_table/beverage_reservation_page.dart';
import 'package:flutter_app/resources/pages/manage_table/select_variant_table_page.dart';

import 'package:flutter_app/resources/widgets/manage_table/table_detail.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nylo_framework/nylo_framework.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:gal/gal.dart';

enum TableStatus { free, using, preOrder }

extension TableStatusExtension on TableStatus {
  Color get color {
    switch (this) {
      case TableStatus.free:
        return Colors.blue[100]!;
      case TableStatus.using:
        return Colors.blue[700]!;
      case TableStatus.preOrder:
        return Colors.amber;
      default:
        return Colors.white;
    }
  }

  String toValue() {
    switch (this) {
      case TableStatus.free:
        return "free";
      case TableStatus.using:
        return "using";
      case TableStatus.preOrder:
        return "pre_book";
      default:
        return "free";
    }
  }

  static TableStatus fromValue(String? value) {
    switch (value) {
      case "free":
        return TableStatus.free;
      case "using":
        return TableStatus.using;
      case "pre_book":
        return TableStatus.preOrder;
      default:
        return TableStatus.free;
    }
  }

  List<PopupMenuEntry> get menuItems {
    switch (this) {
      case TableStatus.free:
        return [
          if (Auth.user<User>()!.careerType != CareerType.football)
            PopupMenuItem(
              child: Row(
                children: [
                  Icon(Icons.add_shopping_cart, size: 18, color: Colors.blue),
                  SizedBox(width: 8),
                  Text("Tạo đơn", style: TextStyle(fontSize: 14)),
                ],
              ),
              value: "create_order",
            ),
          PopupMenuItem(
            child: Row(
              children: [
                Icon(Icons.event_seat, size: 18, color: Colors.orange),
                SizedBox(width: 8),
                Text("Đặtv bàn", style: TextStyle(fontSize: 14)),
              ],
            ),
            value: "reserve",
          ),
          PopupMenuItem(
            child: Row(
              children: [
                Icon(Icons.edit, size: 18, color: Colors.green),
                SizedBox(width: 8),
                Text("Sửa bàn", style: TextStyle(fontSize: 14)),
              ],
            ),
            value: "edit",
          ),
          PopupMenuDivider(),
          PopupMenuItem(
            child: Row(
              children: [
                Icon(Icons.delete, size: 18, color: Colors.red),
                SizedBox(width: 8),
                Text("Xoá bàn", style: TextStyle(fontSize: 14)),
              ],
            ),
            value: "delete",
          ),
        ];
      case TableStatus.using:
        return [
          PopupMenuItem(
            child: Row(
              children: [
                Icon(Icons.payment, size: 18, color: Colors.green),
                SizedBox(width: 8),
                Text("Thanh toán", style: TextStyle(fontSize: 14)),
              ],
            ),
            value: "complete",
          ),
          PopupMenuItem(
            child: Row(
              children: [
                Icon(Icons.swap_horiz, size: 18, color: Colors.blue),
                SizedBox(width: 8),
                Text("Chuyển bàn", style: TextStyle(fontSize: 14)),
              ],
            ),
            value: "move",
          ),
        ];
      case TableStatus.preOrder:
        return [
          PopupMenuItem(
            child: Row(
              children: [
                Icon(Icons.add_shopping_cart, size: 18, color: Colors.blue),
                SizedBox(width: 8),
                Text("Tạo đơn", style: TextStyle(fontSize: 14)),
              ],
            ),
            value: "update",
          ),
          PopupMenuItem(
            child: Row(
              children: [
                Icon(Icons.swap_horiz, size: 18, color: Colors.blue),
                SizedBox(width: 8),
                Text("Chuyển bàn", style: TextStyle(fontSize: 14)),
              ],
            ),
            value: "move",
          ),
          PopupMenuItem(
            child: Row(
              children: [
                Icon(Icons.cancel, size: 18, color: Colors.red),
                SizedBox(width: 8),
                Text("Hủy", style: TextStyle(fontSize: 14)),
              ],
            ),
            value: "cancel",
          ),
        ];
      default:
        return [];
    }
  }
}

class TableItem extends StatefulWidget {
  final TableStatus status;
  final String name;
  final String areaName;
  final int id;
  final dynamic table;
  final Function onTapEditTable;
  final Function onTapMoveTable;
  final VoidCallback refresh;
  final VoidCallback cancelTable;
  final dynamic order;
  final bool isMoveTable;
  final Function onConfirmMove;
  final List<dynamic> listRoomService;

  const TableItem(
      {super.key,
      this.status = TableStatus.free,
      this.isMoveTable = false,
      this.areaName = "",
      required this.cancelTable,
      required this.onConfirmMove,
      required this.name,
      required this.id,
      required this.onTapEditTable,
      required this.refresh,
      required this.onTapMoveTable,
      required this.table,
      required this.listRoomService,
      this.order});

  @override
  State<TableItem> createState() => _TableItemState();
}

class _TableItemState extends State<TableItem> {
  bool _loading = false;

  Future<void> _completeTable() async {
    if (widget.order == null) {
      return;
    }
    if (_loading) {
      return;
    }

    setState(() {
      _loading = true;
    });
    try {
      // await api<RoomApiService>(
      //         (request) => request.completeTable(widget.order['id']));
      CustomToast.showToastSuccess(context, description: 'Thành công');
      widget.refresh();
    } catch (e) {
      CustomToast.showToastError(context, description: getResponseError(e));
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _downloadQRImage(GlobalKey qrKey) async {
    try {
      if (Platform.isAndroid) {
        final permission = await Permission.storage.request();
        if (!permission.isGranted) {
          CustomToast.showToastWarning(context,
              description: 'Cần cấp quyền truy cập bộ nhớ để tải ảnh');
          return;
        }
      }

      RenderRepaintBoundary boundary =
          qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'QR_${widget.name.replaceAll(' ', '_')}_$timestamp.png';

      if (Platform.isAndroid || Platform.isIOS) {
        await Gal.putImageBytes(pngBytes);

        CustomToast.showToastSuccess(context,
            description: 'Lưu ảnh thành công');
      } else {
        final directory = await getDownloadsDirectory();
        if (directory != null) {
          final file = File('${directory.path}/$fileName');
          await file.writeAsBytes(pngBytes);

          CustomToast.showToastSuccess(context,
              description: 'Lưu ảnh thành công');
        }
      }
    } catch (e) {
      CustomToast.showToastError(context, description: 'Lỗi khi lưu ảnh');
    }
  }

  Future<void> _cancelTable() async {
    if (widget.order == null) {
      return;
    }
    if (_loading) {
      return;
    }
    setState(() {
      _loading = true;
    });
    try {
      await api<RoomApiService>(
          (request) => request.cancelTable(widget.order['id']));
      widget.cancelTable();
      CustomToast.showToastSuccess(context, description: 'Hủy thành công');
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

  Future _removeTable() async {
    try {
      await api<RoomApiService>((request) => request.deleteRoom(widget.id));
      CustomToast.showToastSuccess(context, description: 'Xoá thành công');
      widget.refresh();
      Navigator.pop(context);
    } catch (e) {
      CustomToast.showToastError(context, description: 'Xoá thất bại');
    }
  }

  Future _fetchOrderDetail() async {
    final id = widget.order['id'];
    return api<OrderApiService>((request) => request.detailOrder(id));
  }

  String getTimeDifference(String createdAt) {
    DateTime createdTime = DateTime.parse(createdAt);
    DateTime now = DateTime.now();
    Duration difference = now.difference(createdTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} phút';
    } else if (difference.inHours < 24) {
      int hours = difference.inHours;
      int minutes = difference.inMinutes % 60;
      return '$hours giờ $minutes phút';
    } else {
      int days = difference.inDays;
      int hours = difference.inHours % 24;
      int minutes = difference.inMinutes % 60;
      return '$days ngày $hours giờ $minutes phút';
    }
  }

  num getFinalPrice(dynamic order) {
    num retailCost = order['order_retail_cost'] ?? 0;
    num otherFee = order['order_service_fee'] ?? 0;
    num serviceFee = getServiceFee(order);
    return retailCost + otherFee + serviceFee;
  }

  num getServiceFee(dynamic order) {
    return 0;
  }

  String getCustomerName(dynamic order) {
    if (order['name'] == null && order['phone'] == null) {
      return "---";
    } else if (order['name'] != null && order['name'] != '') {
      return order['name'];
    } else if (order['phone'] != null && order['phone'] != '') {
      return order['phone'];
    } else {
      return "---";
    }
  }

  IconData getCustomerIcon(dynamic order) {
    if (order['name'] == null && order['phone'] == null) {
      return Icons.person_2_outlined;
    } else if (order['name'] != null && order['name'] != '') {
      return Icons.person_2_outlined;
    } else if (order['phone'] != null && order['phone'] != '') {
      return Icons.phone;
    } else {
      return Icons.person_2_outlined;
    }
  }

  @override
  dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    bool isPosRoomUser = Auth.user<User>()?.isPosRoomUser == true;

    if (isPosRoomUser) {
      double itemSize = MediaQuery.of(context).size.width / 8;
      return Container(
        width: itemSize,
        height: itemSize,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () {
                if (widget.isMoveTable == true) {
                  showConfirmMove(widget.name);
                } else if (widget.status == TableStatus.free) {
                  if (isPosRoomUser) {
                    routeTo(
                      ReservationPosPage.path,
                      data: {
                        "room_id": widget.id,
                        "room_type": TableStatus.free.toValue(),
                        "button_type": "create_order",
                        "room_name": widget.name,
                        "area_name": widget.areaName,
                      },
                      onPop: (value) {
                        widget.refresh();
                      },
                    );
                  } else {
                    routeTo(
                      SelectVariantTablePage.path,
                      data: {
                        "room_id": widget.id,
                        "room_type": TableStatus.free.toValue(),
                        "button_type": "create_order",
                        "room_name": widget.name,
                        "area_name": widget.areaName,
                      },
                      onPop: (value) {
                        widget.refresh();
                      },
                    );
                  }
                } else {
                  if (widget.status == TableStatus.using) {
                    goToUpdateOrder(TableStatus.free, true);
                  } else {
                    showDetailModal();
                  }
                }
              },
              child: Container(
                width: itemSize,
                height: itemSize,
                decoration: BoxDecoration(
                  color: widget.status.color.withOpacity(0.07),
                  border: Border.all(color: widget.status.color, width: 1),
                  borderRadius: isPosRoomUser
                      ? BorderRadius.all(Radius.circular(20))
                      : BorderRadius.all(Radius.circular(15)),
                ),
                child: _loading
                    ? Center(
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: widget.status.color,
                              strokeWidth: 2,
                            )),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 6),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  SizedBox(
                                    width: 3,
                                  ),
                                  Flexible(
                                    child: Text(
                                      "${widget.name}",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.status == TableStatus.free) ...[
                                SizedBox(
                                    height:
                                        MediaQuery.of(context).size.width / 18),
                                Align(
                                  alignment: Alignment.center,
                                  child: Text(
                                    "Bàn trống",
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 17,
                                        color: Colors.blue[100]),
                                  ),
                                )
                              ] else ...[
                                if (widget.status == TableStatus.using &&
                                    widget.order != null &&
                                    widget.order['date'] != null &&
                                    widget.order['hour'] != null)
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 2,
                                      ),
                                      Icon(FontAwesomeIcons.hourglassHalf,
                                          size: 10, color: Colors.grey[700]),
                                      SizedBox(width: 3),
                                      Expanded(
                                        child: Text(
                                          getTimeDifference(
                                              "${widget.order['date']} ${widget.order['hour']}"),
                                          style: TextStyle(
                                              color: Colors.grey[900],
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                if (widget.status != TableStatus.free)
                                  Row(
                                    children: [
                                      Icon(
                                        getCustomerIcon(widget.order),
                                        size: 14,
                                        color: Colors.grey[700],
                                      ),
                                      SizedBox(width: 3),
                                      Expanded(
                                        child: Text(
                                          getCustomerName(widget.order),
                                          style: TextStyle(
                                              color: Colors.grey[900],
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                Row(
                                  children: [
                                    Icon(Icons.monetization_on,
                                        color: Colors.grey, size: 14),
                                    SizedBox(
                                      width: 3,
                                    ),
                                    Expanded(
                                      child: Text(
                                        getFinalPrice(widget.order) > 0
                                            ? vnd.format(
                                                getFinalPrice(widget.order))
                                            : '---',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue[700]),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                if (widget.status == TableStatus.preOrder) ...[
                                  Spacer(),
                                  Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Text(
                                      "Đặt trước",
                                      style: TextStyle(
                                          color: Colors.amber[300],
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ]),
                      ),
              ),
            ),
            // option menu
            if (widget.isMoveTable != true)
              Positioned(
                  top: 0,
                  right: 0,
                  child: SizedBox(
                    width: 40,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.status.color,
                        borderRadius: BorderRadius.only(
                            topRight: isPosRoomUser
                                ? Radius.circular(20)
                                : Radius.circular(15),
                            bottomLeft: Radius.circular(10)),
                      ),
                      child: buildPopupMenuButton(),
                    ),
                  )),
          ],
        ),
      );
    }
    double itemSize = isLandscape
        ? MediaQuery.of(context).size.width / 5
        : MediaQuery.of(context).size.width / 3.4;
    return Container(
      width: itemSize,
      height: itemSize,
      child: Stack(
        children: [
          GestureDetector(
            onTap: () {
              if (widget.isMoveTable == true) {
                showConfirmMove(widget.name);
              } else if (widget.status == TableStatus.free) {
                if (isPosRoomUser) {
                  routeTo(
                    ReservationPosPage.path,
                    data: {
                      "room_id": widget.id,
                      "room_type": TableStatus.free.toValue(),
                      "button_type": "create_order",
                      "room_name": widget.name,
                      "area_name": widget.areaName,
                    },
                    onPop: (value) {
                      widget.refresh();
                    },
                  );
                } else {
                  routeTo(
                    SelectVariantTablePage.path,
                    data: {
                      "room_id": widget.id,
                      "room_type": TableStatus.free.toValue(),
                      "button_type": "create_order",
                      "room_name": widget.name,
                      "area_name": widget.areaName,
                    },
                    onPop: (value) {
                      widget.refresh();
                    },
                  );
                }
              } else {
                if (widget.status == TableStatus.using) {
                  goToUpdateOrder(TableStatus.free, true);
                } else {
                  showDetailModal();
                }
              }
            },
            child: Container(
              width: itemSize,
              height: itemSize,
              decoration: BoxDecoration(
                color: widget.status.color.withOpacity(0.07),
                border: Border.all(color: widget.status.color, width: 1),
                borderRadius: BorderRadius.all(Radius.circular(15)),
              ),
              child: _loading
                  ? Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: widget.status.color,
                            strokeWidth: 2,
                          )),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 6),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 3,
                                ),
                                Flexible(
                                  child: Text(
                                    "${widget.name}",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                            if (widget.status == TableStatus.free) ...[
                              SizedBox(
                                  height:
                                      MediaQuery.of(context).size.width / 18),
                              Align(
                                alignment: Alignment.center,
                                child: Text(
                                  "Bàn trống",
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 17,
                                      color: Colors.blue[100]),
                                ),
                              )
                            ] else ...[
                              if (widget.status == TableStatus.using &&
                                  widget.order != null &&
                                  widget.order['date'] != null &&
                                  widget.order['hour'] != null)
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 2,
                                    ),
                                    Icon(FontAwesomeIcons.hourglassHalf,
                                        size: 10, color: Colors.grey[700]),
                                    SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        getTimeDifference(
                                            "${widget.order['date']} ${widget.order['hour']}"),
                                        style: TextStyle(
                                            color: Colors.grey[900],
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              if (widget.status != TableStatus.free)
                                Row(
                                  children: [
                                    Icon(
                                      getCustomerIcon(widget.order),
                                      size: 14,
                                      color: Colors.grey[700],
                                    ),
                                    SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        getCustomerName(widget.order),
                                        style: TextStyle(
                                            color: Colors.grey[900],
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              Row(
                                children: [
                                  Icon(Icons.monetization_on,
                                      color: Colors.grey, size: 14),
                                  SizedBox(
                                    width: 3,
                                  ),
                                  Expanded(
                                    child: Text(
                                      getFinalPrice(widget.order) > 0
                                          ? vnd.format(
                                              getFinalPrice(widget.order))
                                          : '---',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue[700]),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.status == TableStatus.preOrder) ...[
                                Spacer(),
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Text(
                                    "Đặt trước",
                                    style: TextStyle(
                                        color: Colors.amber[300],
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ]),
                    ),
            ),
          ),
          // option menu
          if (widget.isMoveTable != true)
            Positioned(
                top: 0,
                right: isPosRoomUser ? 3 : 0,
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.status.color,
                      borderRadius: BorderRadius.only(
                          topRight: Radius.circular(10),
                          bottomLeft: Radius.circular(10)),
                    ),
                    child: buildPopupMenuButton(),
                  ),
                )),
        ],
      ),
    );
  }

  Widget buildPopupMenuButton() {
    return Center(
      child: PopupMenuButton(
        iconSize: 18,
        icon: Icon(Icons.more_vert, color: Colors.white),
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 8,
        itemBuilder: (context) => [
          ...widget.status.menuItems,
        ],
        onSelected: (value) {
          switch (value) {
            case "edit":
              widget.onTapEditTable();
              break;
            case "reserve":
              if (Auth.user<User>()?.isPosRoomUser == true) {
                routeTo(ReservationPosPage.path, data: {
                  "room_id": widget.id,
                  "room_type": "using",
                  "button_type": "reserve",
                  "room_name": widget.name,
                  "area_name": widget.areaName,
                }, onPop: (value) {
                  widget.refresh();
                });
              } else {
                routeTo(BeverageReservationPage.path, data: {
                  "room_id": widget.id,
                  "room_type": "using",
                  "button_type": "reserve",
                  "room_name": widget.name,
                  "area_name": widget.areaName,
                }, onPop: (value) {
                  widget.refresh();
                });
              }
              break;
            case "create_order":
              if (Auth.user<User>()?.isPosRoomUser == true) {
                routeTo(ReservationPosPage.path, data: {
                  "room_id": widget.id,
                  "room_type": "using",
                  "button_type": "create_order",
                  "room_name": widget.name,
                  "area_name": widget.areaName,
                }, onPop: (value) {
                  widget.refresh();
                });
              } else {
                routeTo(SelectVariantTablePage.path, data: {
                  "room_id": widget.id,
                  "room_type": "using",
                  "button_type": "create_order",
                  "room_name": widget.name,
                  "area_name": widget.areaName,
                }, onPop: (value) {
                  widget.refresh();
                });
              }

              break;
            case "complete":
              goToUpdateOrder(TableStatus.free, true);
              break;
            case "cancel":
              showCancelDialog();
              break;
            case "update":
              goToUpdateOrder(TableStatus.using, false);
              break;
            case "delete":
              showRemoveDialog();
              break;
            case "move":
              widget.onTapMoveTable();
              break;
            case "qr_code":
              showQRCodeDialog();
              break;
            default:
          }
        },
      ),
    );
  }

  String generateQRCodeUrl() {
    final storeId = Auth.user<User>()?.storeId ?? -1;
    final userApiKey = Auth.user<User>()?.apiKey ?? '';
    final roomName = Uri.encodeComponent(widget.name);
    final roomIdBytes = utf8.encode(widget.id.toString());
    final roomIdBase64 = base64.encode(roomIdBytes);
    final baseUrl = getEnv('ORDER_TABLE_URL');

    String url =
        "$baseUrl?roomName=$roomName&apiKey=$userApiKey&roomId=$roomIdBase64";

    if (storeId != -1) {
      final storeIdBytes = utf8.encode(storeId.toString());
      final storeIdBase64 = base64.encode(storeIdBytes);
      url += "&storeId=$storeIdBase64";
    }

    return url;
  }

  void showQRCodeDialog() {
    final qrUrl = generateQRCodeUrl();
    final GlobalKey qrKey = GlobalKey();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isTablet = screenWidth >= 600;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isTablet ? 400 : double.infinity,
            ),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  ThemeColor.get(context).primaryAccent.withOpacity(0.1),
                  Colors.blue.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ThemeColor.get(context).primaryAccent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.qr_code,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mã QR - ${widget.name}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'Khu vực: ${widget.areaName}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                RepaintBoundary(
                  key: qrKey,
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'QUÉT MÃ QR ĐỂ GỌI MÓN',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 12),
                        QrImageView(
                          data: qrUrl,
                          version: QrVersions.auto,
                          size: 200.0,
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          errorStateBuilder: (cxt, err) {
                            return Container(
                              child: Center(
                                child: Text(
                                  "Lỗi tạo mã QR",
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 12),
                        Text(
                          '${widget.name} - ${widget.areaName}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _downloadQRImage(qrKey),
                        icon: Icon(Icons.download, size: 16),
                        label: Text(
                          'Tải QR',
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              ThemeColor.get(context).primaryAccent,
                          side: BorderSide(
                              color: ThemeColor.get(context).primaryAccent),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        icon: Icon(Icons.close, size: 16),
                        label: Text('Đóng'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              ThemeColor.get(context).primaryAccent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void showConfirmMove(table) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(
              "Xác nhận",
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Divider(),
                Text("Bạn có chắc chắn muốn chuyển đến $table?"),
              ],
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
                  child: Text("Hủy")),
              TextButton(
                  style: TextButton.styleFrom(
                      backgroundColor: ThemeColor.get(context).primaryAccent,
                      foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onConfirmMove();
                  },
                  child: Text("Đồng ý")),
            ],
          );
        });
  }

  void showCompleteDialog() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text("Thanh toán"),
              content: Text("Bạn có chắc chắn muốn thanh toán đơn hàng này?"),
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
                    child: Text("Hủy")),
                TextButton(
                    style: TextButton.styleFrom(
                        backgroundColor: ThemeColor.get(context).primaryAccent,
                        foregroundColor: Colors.white),
                    onPressed: () async {
                      Navigator.pop(context);
                      await _completeTable();
                    },
                    child: _loading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ))
                        : Text("Đồng ý")),
              ],
            ));
  }

  void showCancelDialog() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text("Hủy bàn"),
              content: Text("Bạn có chắc chắn muốn hủy đặt bàn này?"),
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
                    child: Text("Bỏ qua")),
                TextButton(
                    style: TextButton.styleFrom(
                        backgroundColor: ThemeColor.get(context).primaryAccent,
                        foregroundColor: Colors.white),
                    onPressed: () {
                      _cancelTable();
                    },
                    child: _loading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ))
                        : Text("Đồng ý")),
              ],
            ));
  }

  void showRemoveDialog() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text("Xoá bàn"),
              content: Text("Bạn có chắc chắn muốn Xoá bàn này?"),
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
                    child: Text("Bỏ qua")),
                TextButton(
                    style: TextButton.styleFrom(
                        backgroundColor: ThemeColor.get(context).primaryAccent,
                        foregroundColor: Colors.white),
                    onPressed: () {
                      _removeTable();
                    },
                    child: Text("Đồng ý")),
              ],
            ));
  }

  void goToUpdateOrder(TableStatus status, [bool showPay = false]) async {
    setState(() {
      _loading = true;
    });

    final orderDetail = await _fetchOrderDetail();
    setState(() {
      _loading = false;
    });

    if (Auth.user<User>()?.isPosRoomUser == true) {
      routeTo(
        ReservationPosPage.path,
        data: {
          "note": orderDetail['note'],
          "room_id": widget.id,
          "edit_data": orderDetail,
          "room_type": status.toValue(),
          "current_room_type": widget.status.toValue(),
          "show_pay": showPay,
          "room_name": widget.name,
          "area_name": widget.areaName,
        },
        onPop: (value) {
          widget.refresh();
        },
      );
    } else {
      routeTo(BeverageReservationPage.path, data: {
        "note": orderDetail['note'],
        "room_id": widget.id,
        "edit_data": orderDetail,
        "room_type": status.toValue(),
        "current_room_type": widget.status.toValue(),
        "show_pay": showPay,
        "room_name": widget.name,
        "area_name": widget.areaName,
      }, onPop: (value) {
        widget.refresh();
      });
    }
  }

  void showDetailModal() async {
    await showModalBottomSheet(
        useSafeArea: true,
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10.0),
                  topRight: Radius.circular(10.0),
                )),
            padding: MediaQuery.of(context).viewInsets,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: TableDetail(
                table: widget,
                refresh: widget.refresh,
              ),
            ),
          );
        });
  }
}
