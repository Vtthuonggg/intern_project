// result:
// 1. blue-xl/
// 2. blue-xl/thung
// 3. blue-xl/hop
// 4. blue-m/
// 5. blue-m/thung
import 'package:flutter_app/app/utils/utils.dart';

int compareVariantByKey(dynamic variantA, dynamic variantB) {
  String a = getVariantKey(variantA);
  String b = getVariantKey(variantB);
  // Extract the color and suffix from each element
  String colorA = a.split('/')[0];
  String colorB = b.split('/')[0];
  String suffixA = a.split('/')[1];
  String suffixB = b.split('/')[1];

  // Sort by color first
  int colorComparison = colorA.compareTo(colorB);
  if (colorComparison != 0) {
    return colorComparison;
  }

  // Sort by suffix if colors are the same
  return suffixA.compareTo(suffixB);
}

// result: blue-xl/thung
String getVariantKey(dynamic variant) {
  List<dynamic> attributeValues = variant['attribute_values'];
  List<dynamic> attributeValueNames =
      attributeValues.map((e) => e['attribute_value_name']).toList();

  // sort by alphabet
  // attributeValueNames.sort(alphabetSort);

  dynamic conversionUnit = variant['conversion_unit'];
  String unit = conversionUnit != null && conversionUnit.isNotEmpty
      ? (conversionUnit.first['unit'] ?? '')
      : '';

  return attributeValueNames.join('-') + '/' + unit;
}

isVariantHaveUnit(dynamic variant) {
  List<dynamic> units = variant['conversion_unit'];
  return units != null && units.isNotEmpty;
}

String getVariantDisplayName(dynamic variant) {
  List<dynamic> attributeValues = variant['attribute_values'];
  List<dynamic> attributeValueNames =
      attributeValues.map((e) => e['attribute_value_name']).toList();
  if (attributeValueNames.isEmpty) {
    return variant['name'] ?? '';
  }
  attributeValueNames.sort(alphabetSort);

  return attributeValueNames.join(' - ');
}

List<dynamic> getAllUnits(List<dynamic> variants) {
  dynamic units = [];
  Set<String> unitNames = {};

  variants.forEach((variant) {
    List<dynamic> conversionUnits = variant['conversion_unit'];
    if (conversionUnits != null && conversionUnits.isNotEmpty) {
      if (unitNames.contains(conversionUnits.first['unit'])) {
        return;
      }
      units.add({
        'unit': conversionUnits.first['unit'],
        'conversion': conversionUnits.first['conversion'],
      });

      unitNames.add(conversionUnits.first['unit']);
    }
  });

  // remove unit duplicate name
  units = units.toSet().toList();

  return units;
}

List<dynamic> groupAllAttributes(List<dynamic> variants) {
  List<dynamic> attributes = [];

  variants.forEach((variant) {
    List<dynamic> attributeValues = variant['attribute_values'];
    attributeValues.forEach((attributeValue) {
      String attribute = attributeValue['attribute'] ?? '';
      String attributeValueName = attributeValue['attribute_value_name'];

      // check if attribute is exist
      int index =
          attributes.indexWhere((element) => element['attribute'] == attribute);
      if (index == -1) {
        attributes.add({
          'attribute': attribute,
          'attribute_values': [attributeValueName],
        });
      } else {
        attributes[index]['attribute_values'].add(attributeValueName);
      }
    });
  });

  // remove attribute duplicate value
  attributes.forEach((attribute) {
    attribute['attribute_values'] =
        attribute['attribute_values'].toSet().toList();
  });

  return attributes;
}
