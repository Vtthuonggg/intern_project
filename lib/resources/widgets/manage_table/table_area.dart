import 'package:flutter/material.dart';
import 'package:flutter_app/app/models/user.dart';
import 'package:flutter_app/app/networking/room_api_service.dart';
import 'package:flutter_app/app/utils/message.dart';
import 'package:flutter_app/bootstrap/helpers.dart';
import 'package:flutter_app/resources/pages/custom_toast.dart';
import 'package:flutter_app/resources/pages/manage_table/manage_table_page.dart';
import 'package:flutter_app/resources/widgets/manage_table/table_item.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:nylo_framework/nylo_framework.dart';

class TableArea extends StatefulWidget {
  final Area area;
  final bool isMoveTable;
  final Function onTapAddTable;
  final Function onTapEditTable;
  final Function onTapMoveTable;
  final VoidCallback refresh;
  final Function confirmMoveTable;
  final List<dynamic> listService;

  TableArea({
    super.key,
    required this.area,
    required this.onTapAddTable,
    required this.confirmMoveTable,
    required this.onTapEditTable,
    required this.refresh,
    required this.onTapMoveTable,
    required this.listService,
    this.isMoveTable = false,
  });

  @override
  State<TableArea> createState() => _TableAreaState();
}

class _TableAreaState extends State<TableArea> {
  get totalEmptyTable => widget.area.rooms
      .where((element) => element["type"] == "free")
      .toList()
      .length;
  GlobalKey<FormBuilderState> _formState = GlobalKey<FormBuilderState>();

  String searchQuery = "";
  get employees => widget.area.employees;

  dynamic selectedEmployee;
  @override
  void initState() {
    super.initState();
    selectedEmployee = [];
  }

  Future<void> _updateArea() async {
    if (!_formState.currentState!.saveAndValidate()) {
      return Future.value();
    }
    dynamic payload = Map<String, dynamic>.from(_formState.currentState!.value);
    payload["employee_ids"] = selectedEmployee;
    try {
      await api<RoomApiService>(
          (request) => request.updateArea(widget.area.id, payload));
      CustomToast.showToastSuccess(context,
          description: 'Cập nhật khu vực thành công');
      Navigator.pop(context);
      widget.refresh();
    } catch (e) {
      CustomToast.showToastSuccess(context, description: getResponseError(e));
    }
  }

  void _showEditAreaDialog(context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        ScreenUtil.init(context);
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.edit_location_outlined,
                          color: Colors.blue[600],
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Chỉnh sửa khu vực',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[900],
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),

                  // Form
                  FormBuilder(
                    key: _formState,
                    initialValue: {
                      "name": widget.area.name,
                    },
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thông tin khu vực',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: 16),
                          FormBuilderTextField(
                            keyboardType: TextInputType.name,
                            name: "name",
                            cursorColor: Colors.blue[600],
                            onTapOutside: (event) {
                              FocusScope.of(context).unfocus();
                            },
                            decoration: InputDecoration(
                              labelText: "Tên khu vực",
                              labelStyle: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                              prefixIcon: Icon(Icons.location_on_outlined,
                                  color: Colors.grey[500]),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: Colors.blue[500]!, width: 2),
                              ),
                            ),
                            validator: FormBuilderValidators.compose([
                              FormBuilderValidators.required(),
                            ]),
                          ),
                          SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),

                  // Update button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _updateArea();
                      },
                      icon: Icon(Icons.save_outlined,
                          color: Colors.white, size: 18),
                      label: Text(
                        "Cập nhật khu vực",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
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

  Widget buildEmployee(employee, context, setState) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: employee.isSelected ? Colors.blue[50] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: employee.isSelected ? Colors.blue[200]! : Colors.grey[200]!,
        ),
      ),
      child: ListTile(
        onTap: () {
          setState(() {
            if (selectedEmployee.contains(employee.id)) {
              selectedEmployee.remove(employee.id);
              employee.isSelected = false;
            } else {
              selectedEmployee.add(employee.id);
              employee.isSelected = true;
            }
          });
        },
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: employee.isSelected ? Colors.blue[100] : Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.person,
            color: employee.isSelected ? Colors.blue[600] : Colors.grey[600],
            size: 20,
          ),
        ),
        title: Text(
          employee.name.length > 25
              ? employee.name.substring(0, 25) + '...'
              : employee.name,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: employee.isSelected ? Colors.blue[700] : Colors.grey[800],
          ),
        ),
        trailing: Container(
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: employee.isSelected ? Colors.blue[600] : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            employee.isSelected ? Icons.check : Icons.add,
            color: employee.isSelected ? Colors.white : Colors.grey[500],
            size: 18,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[50]!, Colors.blue[100]!],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue[600],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 14,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.area.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[800],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Trống: $totalEmptyTable",
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: 4),
              Container(
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: InkWell(
                  child: Icon(Icons.edit_outlined,
                      color: Colors.blue[600], size: 16),
                  onTap: () {
                    _showEditAreaDialog(context);
                  },
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ...widget.area.rooms
                    .map<Widget>((table) => TableItem(
                          onConfirmMove: () =>
                              widget.confirmMoveTable(table['id']),
                          isMoveTable: widget.isMoveTable,
                          refresh: widget.refresh,
                          status: TableStatusExtension.fromValue(table["type"]),
                          name: table['name'],
                          id: table["id"],
                          areaName: widget.area.name,
                          onTapEditTable: () => widget.onTapEditTable(table),
                          order: table["order"],
                          table: table,
                          listRoomService: widget.listService,
                          onTapMoveTable: () => widget.onTapMoveTable(table),
                        ))
                    .toList(),
                buildAddTableButton()
              ],
            ),
          ),
        ),
      ],
    );
  }

  buildAddTableButton() {
    if (widget.isMoveTable == true) {
      return SizedBox();
    }
    bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    double itemSize = isLandscape
        ? MediaQuery.of(context).size.width / 5
        : MediaQuery.of(context).size.width / 3.4;
    if (Auth.user<User>()?.isPosRoomUser == true) {
      itemSize = MediaQuery.of(context).size.width / 6;
    }
    return GestureDetector(
      onTap: () {
        widget.onTapAddTable();
      },
      child: SizedBox(
        width: itemSize,
        height: itemSize,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue[200]!, width: 1),
            borderRadius: Auth.user<User>()?.isPosRoomUser == true
                ? BorderRadius.circular(20)
                : BorderRadius.all(Radius.circular(15)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: Colors.blue[200], size: 30),
              Text("Thêm bàn", style: TextStyle(fontSize: 12))
            ],
          ),
        ),
      ),
    );
  }
}
