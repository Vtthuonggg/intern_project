import 'package:flutter/material.dart';
import 'package:flutter_app/app/controllers/controller.dart';
import 'package:flutter_app/app/networking/post_ingredients_api.dart';
import 'package:flutter_app/app/utils/formatters.dart';
import 'package:flutter_app/bootstrap/helpers.dart';
import 'package:flutter_app/resources/pages/custom_toast.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nylo_framework/nylo_framework.dart';

class ListIngredients extends NyStatefulWidget {
  final Controller controller = Controller();
  int? orderId;
  String? roomName;
  String? areaName;
  String? orderCode;
  List<dynamic> selectedItems;
  Function? onBack;

  ListIngredients({
    Key? key,
    required this.selectedItems,
    required this.orderId,
    this.onBack,
    this.roomName,
    this.areaName,
    this.orderCode,
  }) : super(key: key);
  @override
  State<ListIngredients> createState() => _ListIngredientsState();
}

class _ListIngredientsState extends NyState<ListIngredients> {
  List<dynamic> listIngredients = [];
  bool loading = false;
  IngredientApi apiIngre = IngredientApi();
  bool isCheck = false;
  List<Map<String, dynamic>> items = [];
  int? orderId = 0;
  List<dynamic> itemQuantity = [];
  dynamic tempData = {};
  @override
  init() async {
    super.init();
  }

  @override
  void initState() {
    super.initState();
    orderId = widget.orderId;
    listIngredients = widget.selectedItems;
    if (widget.orderCode != null) {
      tempData['code'] = widget.orderCode;
    }
    tempData['items'] = listIngredients.map((item) {
      return {
        'name': item['name'],
        'quantity': item['quantity'],
        'toppings': (item['topping'] ?? [])
            .map((t) => {
                  'name': t['name'],
                  'quantity': t['quantity'],
                })
            .toList(),
        'notes': (item['notes'] ?? []).map((n) => n['name']).toList(),
      };
    }).toList();
    for (var item in listIngredients) {
      items.add({
        'name': item['name'],
        'isIngredient': item['isIngredient'] ?? false,
        'ingredient': item['ingredient'] ?? [],
        'id': item['id'],
        'quantity': item['quantity'],
        'notes': (item['notes'] != null && item['notes']!.isNotEmpty)
            ? item['notes'].map((e) => e['name']).toList()
            : [],
        'topping': item['topping'] ?? [],
      });
    }
  }

  Future<void> _getInvoiceImage() async {
    try {
      Map<String, dynamic> data = {
        'order_id': orderId,
        'variant': items
            .map((e) => {
                  'id': e['id'],
                  'quantity': e['quantity'],
                  'notes': e['notes'] ?? [],
                })
            .toList(),
      };
      await apiIngre.postIngredients(data);
    } catch (e) {
      CustomToast.showToastError(context, description: e.toString());
    }
  }

  Future _submit() async {
    if (items.isEmpty) {
      CustomToast.showToastError(context, description: 'Vui lòng chọn món');
      return;
    }
    setState(() {
      loading = true;
    });

    try {
      await widget.onBack!();
      Navigator.pop(context);
    } catch (e) {
    } finally {
      await _getInvoiceImage();
      for (var item in items) {
        listIngredients.removeWhere((e) => e['id'] == item['id']);
      }
      setState(() {
        loading = false;
      });
    }
  }

  @override
  void dispose() {
    // if (selectedPrinter != null) {
    //   printerManager.disconnect(type: selectedPrinter!.typePrinter!);
    // }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);
    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        FontAwesomeIcons.utensils,
                        color: Colors.orangeAccent,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Xác nhận chế biến',
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
                SizedBox(height: 16),
                Expanded(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.5,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: listIngredients.isEmpty
                          ? Center(
                              child: Text(
                                'Không có món nào cần chế biến',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: listIngredients.length <= 4
                                  ? NeverScrollableScrollPhysics()
                                  : AlwaysScrollableScrollPhysics(),
                              itemCount: listIngredients.length,
                              itemBuilder: (context, index) {
                                var item = listIngredients[index];
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          var existingItem = items.firstWhere(
                                              (element) =>
                                                  element['id'] == item['id'],
                                              orElse: () => {});
                                          if (existingItem.isNotEmpty) {
                                            items.remove(existingItem);
                                          } else {
                                            items.add({
                                              'id': item['id'],
                                              'quantity': item['quantity'],
                                              'notes': (item['notes'] != null &&
                                                      item['notes']!.isNotEmpty)
                                                  ? item['notes']
                                                      .map((e) => e['name'])
                                                      .toList()
                                                  : [],
                                            });
                                          }
                                        });
                                      },
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          '${item['name'] ?? ''}  [ ${roundQuantity(item['quantity'])} ]',
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: item["notes"].isNotEmpty
                                            ? Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  ...item["notes"].map(
                                                    (note) => Text(
                                                      "- ${note["name"]}",
                                                      style: TextStyle(
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : null,
                                        trailing: Checkbox(
                                          activeColor: ThemeColor.get(context)
                                              .primaryAccent,
                                          value: items.any((element) =>
                                              element['id'] == item['id']),
                                          onChanged: (bool? value) {
                                            setState(() {
                                              var existingItem =
                                                  items.firstWhere(
                                                      (element) =>
                                                          element['id'] ==
                                                          item['id'],
                                                      orElse: () => {});
                                              if (value == true &&
                                                  existingItem.isEmpty) {
                                                items.add({
                                                  'id': item['id'],
                                                  'quantity': item['quantity']
                                                });
                                              } else if (value == false &&
                                                  existingItem.isNotEmpty) {
                                                items.remove(existingItem);
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    if (item['topping'] != null &&
                                        item['topping'].isNotEmpty)
                                      ListView.builder(
                                        shrinkWrap: true,
                                        physics: NeverScrollableScrollPhysics(),
                                        itemCount: item['topping']?.length,
                                        padding: EdgeInsets.all(0),
                                        itemBuilder: (context, i) {
                                          var ingre = item['topping']?[i];
                                          return Text(
                                            ingre['quantity'] > 1
                                                ? '+ ${ingre['name'] ?? ''}  (${roundQuantity(ingre['quantity'])})'
                                                : '+ ${ingre['name'] ?? ''}',
                                            style: TextStyle(fontSize: 14),
                                          );
                                        },
                                      ),
                                    SizedBox(height: 10),
                                    if (index != listIngredients.length - 1)
                                      Divider(
                                        color: Colors.grey[300],
                                        thickness: 1,
                                        height: 1,
                                      ),
                                    SizedBox(height: 10),
                                  ],
                                );
                              },
                            ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 16),
                          elevation: 2,
                        ),
                        onPressed: () {
                          _submit();
                        },
                        icon: Icon(Icons.check_circle_outline,
                            color: Colors.white),
                        label: loading
                            ? SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                'Báo chế biến',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
