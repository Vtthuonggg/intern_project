import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_app/app/models/product.dart';
import 'package:share_plus/share_plus.dart';

// CareerType getCareerType() {
//   switch(Auth.user()?.businessId ?? 0) {
//     case 1:
//       return CareerType.bia;
//     case 2:
//       return CareerType.cafe
//   }
// }

int alphabetSort(a, b) {
  return a.toLowerCase().compareTo(b.toLowerCase());
}

class PrinterUtils {
  static Future<bool> checkPrintConnected() async {
    return false;
  }

  static void printData(String base64Data) async {}

  static void printBarcode(List<ProductVariant> data) async {}
  static Future<bool> onShareXFileFromAssets(
      String strData, BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    // final data = await rootBundle.load('assets/flutter_logo.png');
    // final dt = utf8.encode(strData);
    // final buffer = data.buffer;
    final shareResult = await Share.shareXFiles(
      [
        XFile.fromData(
          base64.decoder.convert(strData),
          name: 'share.pdf',
          mimeType: 'application/pdf',
        ),
      ],
      sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
    );
    return (shareResult.status == ShareResultStatus.success);
  }

  static Future<bool> onShareXFile(XFile file, BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    // final data = await rootBundle.load('assets/flutter_logo.png');
    // final dt = utf8.encode(strData);
    // final buffer = data.buffer;
    final shareResult = await Share.shareXFiles(
      [file],
      sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
    );
    return (shareResult.status == ShareResultStatus.success);
  }
}

class CustomFloatingActionButtonLocation
    implements FloatingActionButtonLocation {
  final double x;
  final double y;
  const CustomFloatingActionButtonLocation(this.x, this.y);

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    return Offset(x, y);
  }
}
