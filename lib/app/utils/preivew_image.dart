import 'package:flutter/material.dart';
import 'package:nylo_framework/nylo_framework.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

void showPreviewImageDialog(
    {required BuildContext context,
    required int initialIndex,
    required List<String> imageList}) {
  showModalBottomSheet(
    isScrollControlled: true,
    context: context,
    builder: (context) {
      return Container(
        height: MediaQuery.of(context).size.height,
        child: PhotoViewGallery.builder(
          itemCount: imageList.length,
          builder: (context, index) {
            return PhotoViewGalleryPageOptions(
              imageProvider: NetworkImage(imageList[index]),
              errorBuilder: (context, error, stackTrace) {
                return Image.asset(getImageAsset('placeholder.png'));
              },
            );
          },
          scrollPhysics: BouncingScrollPhysics(),
          backgroundDecoration: BoxDecoration(
            color: Colors.black,
          ),
          pageController: PageController(initialPage: initialIndex),
        ),
      );
    },
  );
}
