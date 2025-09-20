import 'package:flutter/material.dart';
import 'package:flutter_app/bootstrap/helpers.dart';

class Breadcrumb extends StatelessWidget {
  final List<String> items;
  final Function(int)? onItemTap;

  const Breadcrumb({
    Key? key,
    required this.items,
    this.onItemTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 12),
      child: Column(
        children: [
          Row(
            children: List.generate(items.length, (index) {
              return InkWell(
                onTap: () {
                  if (onItemTap != null) {
                    onItemTap!(index);
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      items[index],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (index !=
                        items.length - 1) // Add separator between items
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Icon(
                          Icons.arrow_forward_ios_sharp,
                          size: 14, // Change the size of the separator icon
                          color: ThemeColor.get(context).primaryAccent,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          Divider(),
        ],
      ),
    );
  }
}
