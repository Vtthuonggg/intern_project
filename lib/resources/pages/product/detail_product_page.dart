import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_app/app/models/user.dart';
import 'package:flutter_app/app/networking/product_api_service.dart';
import 'package:flutter_app/app/utils/formatters.dart';
import 'package:flutter_app/app/utils/message.dart';
import 'package:flutter_app/app/utils/preivew_image.dart';
import 'package:flutter_app/app/utils/variant.dart';
import 'package:flutter_app/bootstrap/helpers.dart';
import 'package:flutter_app/resources/pages/custom_toast.dart';
import 'package:flutter_app/resources/pages/product/edit_product_page.dart';
import 'package:flutter_app/resources/pages/product/setting_product_page.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nylo_framework/nylo_framework.dart';
import '/app/controllers/controller.dart';

class DetailProductPage extends NyStatefulWidget {
  final Controller controller = Controller();

  static const path = '/detail-product';

  DetailProductPage({Key? key}) : super(key: key);

  @override
  _DetailProductPageState createState() => _DetailProductPageState();
}

class _DetailProductPageState extends NyState<DetailProductPage> {
  Future<dynamic> _future = Future.value({});

  dynamic item = {};
  Map<String, bool> featuresConfig = {};
  int? get storeId => widget.data()?['store_id'] ?? null;
  @override
  init() async {
    super.init();
    _future = _fetchProduct();

    final config = await getProductConfig();
    setState(() {
      featuresConfig = config;
    });

    item = await _future;
    setState(() {});
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<dynamic> _fetchProduct() async {
    final item = await api<ProductApiService>((request) =>
        request.getProduct(widget.data()?['id'], storeId: storeId));
    return item;
  }

  String _pageTitle() {
    if (item?['id'] == null) {
      return '';
    }
    if (item?['type'] == 1) {
      return 'Chi tiết sản phẩm';
    }
    return 'Chi tiết dịch vụ';
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _pageTitle(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (widget.data()['can_edit'] != false)
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () {
                routeTo(EditProductPage.path, data: {
                  'id': widget.data()?['id'],
                  'store_id': storeId,
                }, onPop: (value) async {
                  _future = _fetchProduct();
                  featuresConfig = await getProductConfig();
                  setState(() {});
                });
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Container(
          child: FutureBuilder(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                if (snapshot.data['id'] == null) {
                  return Container();
                }
                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: buildDetailProduct(snapshot.data),
                  ),
                );
              } else if (snapshot.hasError) {
                String errorMessage = getResponseError(snapshot.error);
                return Text(errorMessage);
              }
              return Center(child: CircularProgressIndicator());
            },
          ),
        ),
      ),
    );
  }

  Widget buildDetailProduct(dynamic data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data['name'],
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            SizedBox(
              width: 0.5.sw - 16,
              child: Column(
                children: [
                  if (featuresConfig['product_code'] == true)
                    buildGridItem("SKU", data['code']),
                  if (featuresConfig['product_barcode'] == true)
                    buildGridItem(
                        "Barcode", data['variants'][0]['bar_code'] ?? ''),
                ],
              ),
            ),
            SizedBox(width: 10),
            SizedBox(
              width: 0.5.sw - 16,
              child: Column(
                children: [
                  if (featuresConfig['product_unit'] == true)
                    buildGridItem("Đơn vị tính", data['unit'] ?? ''),
                  if (featuresConfig['product_weight'] == true)
                    buildGridItem("Trọng lượng",
                        "${data['variants'][0]['weight'] ?? ''}${data['weight_unit'] ?? ''}"),
                ],
              ),
            ),
          ],
        ),
        10.verticalSpace,
        if (data['variants'].length == 1) buildPriceItem(data['variants'][0]),
        10.verticalSpace,
        builDetailItem(data),
        10.verticalSpace,
        if (featuresConfig['product_note'] == true) buildDescription(data),
        10.verticalSpace,
        if (featuresConfig['product_image'] == true) buildImg(data),
        10.verticalSpace,
        if (data['variants'].length > 1) buildVariants(data),
      ],
    );
  }

  Widget buildPriceItem(dynamic item) {
    return Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            'Giá',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
          ),
        ],
      ),
      UnderlineRow(),
      8.verticalSpace,
      if (featuresConfig['product_base_cost'] == true)
        buildDetailRow('Giá nhập', vndCurrency.format(item['base_cost'])),
      if (!(featuresConfig['product_whoolsale_cost'] != true &&
          featuresConfig['product_retail_cost'] != true))
        buildDetailRow('Giá bán', getSettingCost(item)),
      if (featuresConfig['product_whoolsale_cost'] == true &&
          featuresConfig['product_retail_cost'] == true)
        buildDetailRow('Chiết khấu bán hàng',
            vnd.format(item['discount']) + getDiscountType(item)),
      if (featuresConfig['product_base_cost'] == true)
        buildDetailRow(
            'Giá vốn trung bình', vndCurrency.format(item['entry_cost'])),
    ]);
  }

  String getDiscountType(dynamic item) {
    if (item['discount_type'] == 1) {
      return '%';
    } else if (item['discount_type'] == 2) {
      return ' đ';
    } else {
      return '';
    }
  }

  String getSettingCost(dynamic item) {
    if (featuresConfig['product_whoolsale_cost'] == true &&
        featuresConfig['product_retail_cost'] == true) {
      return '${vndCurrency.format(item['wholesale_cost'])} -  ${vndCurrency.format(item['retail_cost'])} ';
    }
    if (featuresConfig['product_whoolsale_cost'] != true) {
      return vndCurrency.format(item['retail_cost']);
    }
    if (featuresConfig['product_whoolsale_cost'] != true) {
      return vndCurrency.format(item['wholesale_cost']);
    } else {
      return vndCurrency.format(item['retail_cost']);
    }
  }

  Widget buildDescription(dynamic item) {
    return Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            'Mô tả',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
          ),
        ],
      ),
      UnderlineRow(),
      8.verticalSpace,
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          item['note'] ?? '',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
        ),
      ),
    ]);
  }

  Widget buildImg(dynamic item) {
    dynamic image = item['image'];
    List<String> imageList = [];

    if (image != null) {
      try {
        imageList = List<String>.from(jsonDecode(image));
      } catch (e) {
        imageList = [];
      }
    }

    if (imageList.isEmpty) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                'Ảnh',
                style:
                    TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          UnderlineRow(),
          8.verticalSpace,
          Container(
            child: Text('Không có hình ảnh'),
          ),
        ],
      );
    }
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              'Ảnh',
              style:
                  TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        UnderlineRow(),
        8.verticalSpace,
        Wrap(
          children: List.generate(
            imageList.length,
            (index) => Padding(
              padding: const EdgeInsets.all(4.0),
              child: GestureDetector(
                onTap: () {
                  showPreviewImageDialog(
                    context: context,
                    imageList: imageList,
                    initialIndex: index,
                  );
                },
                child: FadeInImage(
                  width: 100,
                  height: 100,
                  placeholder: AssetImage(
                    getImageAsset(
                      'placeholder.png',
                    ),
                  ),
                  image: NetworkImage(
                    imageList[index],
                  ),
                  fit: BoxFit.cover,
                  imageErrorBuilder: (context, error, stackTrace) {
                    return Image.asset(
                      width: 100,
                      height: 100,
                      getImageAsset('placeholder.png'),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget builDetailItem(dynamic item) {
    return Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            'Chi tiết',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
          ),
        ],
      ),
      UnderlineRow(),
      8.verticalSpace,
      if (featuresConfig['product_category'] == true)
        buildDetailRow(
            'Danh mục',
            (item['categories'] ?? item['category'] ?? [])
                .map((e) => e['name'])
                .toList()
                .join(', ')),
      if (featuresConfig['product_branch'] == true)
        buildDetailRow('Nhãn hiệu',
            item['brands'].map((e) => e['name']).toList().join(', ')),
      buildDetailRow(
          'Kho', calculateTotalAvailable(item['variants']).toString()),
      buildDetailRow('Tạo lúc', formatDate(item['created_at']) ?? ''),
      buildDetailRow('Cập nhật', formatDate(item['updated_at']) ?? ''),
    ]);
  }

  num calculateTotalAvailable(List<dynamic> variants) {
    num total = 0;
    for (var variant in variants) {
      total += variant['available'] ?? 0;
    }
    return total;
  }

  Widget buildGridItem(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[600]),
        ),
        Text(
          value,
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

// Helper method to build a detail item with a label and value
  Widget buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildVariant(dynamic variant, dynamic productData) {
    List<dynamic> units = variant['conversion_unit'];

    String unit = '';
    dynamic conversion;

    if (units.isNotEmpty) {
      unit = units.first['unit'] ?? '';
      conversion = units.first['conversion'];
    } else if (productData['unit'] != null) {
      unit = productData['unit'];
    }
    return Column(
      children: [
        buildDetailRow('Tên phiên bản', variant['name'] ?? ''),
        if (featuresConfig['product_code'] == true)
          buildDetailRow('SKU', variant['sku']),
        if (featuresConfig['product_barcode'] == true)
          buildDetailRow('Barcode', variant['bar_code'] ?? ''),
        if (featuresConfig['product_weight'] == true)
          buildDetailRow(
            'Trọng lượng SP',
            (variant['weight'] != null ? variant['weight'].toString() : '0') +
                (productData['weight_unit'] != null
                    ? productData['weight_unit']
                    : ''),
          ),
        if (unit.isNotEmpty && featuresConfig['product_unit'] == true)
          buildDetailRow('Đơn vị tính', unit),
        if (conversion != null)
          buildDetailRow('Số lượng quy đổi', conversion.toString()),
        if (featuresConfig['product_base_cost'] == true)
          buildDetailRow('Giá nhập', vndCurrency.format(variant['base_cost'])),
        if (featuresConfig['product_base_cost'] == true)
          buildDetailRow(
              'Giá vốn trung bình', vndCurrency.format(variant['entry_cost'])),
        if (featuresConfig['product_retail_cost'] == true)
          buildDetailRow(
              'Giá bán lẻ', vndCurrency.format(variant['retail_cost'])),
        if (Auth.user<User>()?.showWholeSale == true &&
            featuresConfig['product_whoolsale_cost'] == true)
          buildDetailRow(
              'Giá bán buôn', vndCurrency.format(variant['wholesale_cost'])),
        // Row(
        //   mainAxisAlignment: MainAxisAlignment.end,
        //   children: [
        //     TextButton(
        //         onPressed: () {
        //           routeTo(DetailStoragePage.path, data: variant);
        //         },
        //         child: Text(
        //           'Tồn kho',
        //           style: TextStyle(color: Colors.blue),
        //         )),
        //     SizedBox(width: 10.0),
        //   ],
        // ),
      ],
    );
  }

  Widget buildVariants(dynamic productData) {
    List<dynamic> variants = productData['variants'] ?? [];

    if (variants.isEmpty) {
      return Container();
    }

    // Sort variants by key
    variants.sort(compareVariantByKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Phiên bản',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 18),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: variants.length,
          itemBuilder: (context, index) {
            String unit = variants[index]['conversion_unit'] != null &&
                    variants[index]['conversion_unit'].isNotEmpty
                ? (variants[index]['conversion_unit'][0]['unit'] ?? '')
                : '';

            return ListTileTheme(
              contentPadding: EdgeInsets.all(0),
              child: ExpansionTile(
                initiallyExpanded: true,
                title: isVariantHaveUnit(variants[index])
                    ? Text(unit)
                    : Text(getVariantDisplayName(variants[index])),
                subtitle: Text(variants[index]['sku']),
                // leading: Icon(Icons.list),
                leading: isVariantHaveUnit(variants[index])
                    ? RotatedBox(quarterTurns: 2, child: Icon(Icons.turn_left))
                    : null,
                children: [
                  buildVariant(variants[index], productData),
                  SizedBox(height: 10.0),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
