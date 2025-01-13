import 'dart:io';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:openfoodfacts/openfoodfacts.dart';
import 'package:provider/provider.dart';
import 'package:smooth_app/cards/product_cards/smooth_product_image.dart';
import 'package:smooth_app/data_models/preferences/user_preferences.dart';
import 'package:smooth_app/database/transient_file.dart';
import 'package:smooth_app/generic_lib/bottom_sheets/smooth_bottom_sheet.dart';
import 'package:smooth_app/generic_lib/design_constants.dart';
import 'package:smooth_app/helpers/image_field_extension.dart';
import 'package:smooth_app/pages/crop_parameters.dart';
import 'package:smooth_app/pages/image/product_image_helper.dart';
import 'package:smooth_app/pages/product/gallery_view/product_image_gallery_view.dart';
import 'package:smooth_app/pages/product/owner_field_info.dart';
import 'package:smooth_app/pages/product/product_image_server_button.dart';
import 'package:smooth_app/pages/product/product_image_swipeable_view.dart';
import 'package:smooth_app/query/product_query.dart';
import 'package:smooth_app/resources/app_animations.dart';
import 'package:smooth_app/resources/app_icons.dart' as icons;
import 'package:smooth_app/themes/smooth_theme.dart';
import 'package:smooth_app/themes/smooth_theme_colors.dart';
import 'package:smooth_app/themes/theme_provider.dart';

part 'product_image_gallery_details_banner.dart';

class ImageGalleryPhotoRow extends StatefulWidget {
  const ImageGalleryPhotoRow({
    required this.position,
    required this.language,
    required this.imageField,
    super.key,
  });

  static double itemHeight = 55.0;

  final int position;
  final OpenFoodFactsLanguage language;
  final ImageField imageField;

  @override
  State<ImageGalleryPhotoRow> createState() => _ImageGalleryPhotoRowState();
}

class _ImageGalleryPhotoRowState extends State<ImageGalleryPhotoRow> {
  /// Save the initial file
  TransientFile? _initialTransientFile;

  /// A temporary file when the photo is uploading
  File? _temporaryFile;

  @override
  Widget build(BuildContext context) {
    final Product product = context.watch<Product>();

    final TransientFile transientFile = _getTransientFile(
      product,
      widget.imageField,
    );
    _initialTransientFile ??= transientFile;

    if (_temporaryFile != null &&
        _initialTransientFile?.uploadedDate != transientFile.uploadedDate) {
      /// The temporary file is not needed anymore
      _temporaryFile = null;
    }

    final bool expired = transientFile.expired;

    final AppLocalizations appLocalizations = AppLocalizations.of(context);
    final String label =
        widget.imageField.getProductImageTitle(appLocalizations);

    final SmoothColorsThemeExtension extension =
        context.extension<SmoothColorsThemeExtension>();

    return Provider<TransientFile>(
      create: (_) => transientFile,
      child: Semantics(
        image: true,
        button: true,
        label: expired
            ? appLocalizations.product_image_outdated_accessibility_label(label)
            : label,
        excludeSemantics: true,
        child: Material(
          elevation: 1.0,
          type: MaterialType.card,
          shadowColor: Colors.white,
          color: extension.primaryBlack,
          borderRadius: ANGULAR_BORDER_RADIUS,
          child: InkWell(
            borderRadius: ANGULAR_BORDER_RADIUS,
            onTap: () => _onTap(
              context: context,
              product: product,
              transientFile: transientFile,
              initialImageIndex: widget.position,
            ),
            onLongPress: () => _onLongTap(
              context: context,
              product: product,
              transientFile: transientFile,
              language: widget.language,
            ),
            child: ClipRRect(
              borderRadius: ANGULAR_BORDER_RADIUS,
              child: Column(
                children: <Widget>[
                  SizedBox(
                    height: ImageGalleryPhotoRow.itemHeight,
                    child: Row(
                      children: <Widget>[
                        _PhotoRowIndicator(transientFile: transientFile),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: SMALL_SPACE,
                            ),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: AutoSizeText(
                                    label,
                                    maxLines: 2,
                                    minFontSize: 10.0,
                                    style: const TextStyle(
                                      fontSize: 15.0,
                                      height: 1.2,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: SMALL_SPACE),
                                icons.CircledArrow.right(
                                  color: extension.primaryDark,
                                  type: icons.CircledArrowType.normal,
                                  circleColor: Colors.white,
                                  size: 20.0,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: LayoutBuilder(
                            builder:
                                (BuildContext context, BoxConstraints box) {
                              if (_temporaryFile != null) {
                                return Image.file(
                                  _temporaryFile!,
                                  fit: BoxFit.contain,
                                );
                              }

                              return ProductPicture.fromTransientFile(
                                product: product,
                                imageField: widget.imageField,
                                language: widget.language,
                                transientFile: transientFile,
                                size: Size(box.maxWidth, box.maxHeight),
                                onTap: null,
                                errorTextStyle: const TextStyle(
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.w600,
                                ),
                                heroTag: ProductPicture.generateHeroTag(
                                  product.barcode!,
                                  widget.imageField,
                                ),
                                showObsoleteIcon: false,
                                showOwnerIcon: true,
                              );
                            },
                          ),
                        ),
                        // Border
                        const Positioned.fill(
                          child: _PhotoBorder(),
                        ),
                        // Upload animation
                        if (_temporaryFile != null ||
                            transientFile.isImageAvailable() &&
                                !transientFile.isServerImage())
                          const Center(
                            child: CloudUploadAnimation.circle(size: 50.0),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onTap({
    required final BuildContext context,
    required final Product product,
    required final TransientFile transientFile,
    required int initialImageIndex,
  }) async {
    if (transientFile.isImageAvailable()) {
      return _openImage(
        context: context,
        product: product,
        initialImageIndex: initialImageIndex,
      );
    } else {
      await _takePicture(
        context: context,
        product: product,
        pictureSource: UserPictureSource.SELECT,
      );
    }
  }

  Future<void> _onLongTap({
    required final BuildContext context,
    required final Product product,
    required final OpenFoodFactsLanguage language,
    required final TransientFile transientFile,
  }) async {
    final _PhotoRowActions? action = await _showPhotoBanner(
      context: context,
      product: product,
      imageField: widget.imageField,
      language: language,
      transientFile: transientFile,
    );

    if (!context.mounted || action == null) {
      return;
    }

    return switch (action) {
      _PhotoRowActions.takePicture => _takePicture(
          context: context,
          product: product,
          pictureSource: UserPictureSource.CAMERA,
        ),
      _PhotoRowActions.selectFromGallery => _takePicture(
          context: context,
          product: product,
          pictureSource: UserPictureSource.GALLERY,
        ),
      _PhotoRowActions.selectFromProductPhotos =>
        _selectPictureFromProductGallery(
          context: context,
          product: product,
        ),
    };
  }

  Future<void> _takePicture({
    required final BuildContext context,
    required final Product product,
    required final UserPictureSource pictureSource,
  }) async {
    _temporaryFile = await ProductImageGalleryView.takePicture(
      context: context,
      product: product,
      language: widget.language,
      imageField: widget.imageField,
      pictureSource: pictureSource,
    );

    if (_temporaryFile != null) {
      setState(() {});
    }
  }

  Future<void> _openImage({
    required BuildContext context,
    required final Product product,
    required int initialImageIndex,
  }) async =>
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ProductImageSwipeableView(
            initialImageIndex: initialImageIndex,
            product: product,
            isLoggedInMandatory: true,
            initialLanguage: widget.language,
          ),
        ),
      );

  Future<void> _selectPictureFromProductGallery({
    required final BuildContext context,
    required final Product product,
  }) async {
    final CropParameters? parameters =
        await ProductImageServerButton.selectImageFromGallery(
      context: context,
      product: product,
      imageField: widget.imageField,
      language: widget.language,
      isLoggedInMandatory: true,
    );

    if (parameters?.smallCroppedFile != null) {
      setState(() {
        _temporaryFile = parameters!.smallCroppedFile;
      });
    }
  }

  TransientFile _getTransientFile(
    final Product product,
    final ImageField imageField,
  ) =>
      TransientFile.fromProduct(
        product,
        imageField,
        widget.language,
      );
}

class _PhotoRowIndicator extends StatelessWidget {
  const _PhotoRowIndicator({
    required this.transientFile,
  });

  final TransientFile transientFile;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30.0,
      height: double.infinity,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: ANGULAR_RADIUS,
          ),
          color: _getColor(
            context.extension<SmoothColorsThemeExtension>(),
          ),
        ),
        child: Center(
          child: child(),
        ),
      ),
    );
  }

  Widget? child() {
    if (transientFile.isImageAvailable()) {
      if (transientFile.expired) {
        return const icons.Outdated(
          size: 18.0,
          color: Colors.white,
        );
      } else {
        return null;
      }
    } else {
      return const icons.Warning(
        size: 15.0,
        color: Colors.white,
      );
    }
  }

  Color _getColor(SmoothColorsThemeExtension extension) {
    if (transientFile.isImageAvailable()) {
      if (transientFile.expired) {
        return extension.orange;
      } else {
        return extension.green;
      }
    } else {
      return extension.red;
    }
  }
}

class _PhotoBorder extends StatelessWidget {
  const _PhotoBorder();

  @override
  Widget build(BuildContext context) {
    final SmoothColorsThemeExtension extension =
        context.extension<SmoothColorsThemeExtension>();

    final bool lightTheme = context.lightTheme();

    final BorderSide borderSide = BorderSide(
      width: lightTheme ? 1.0 : 0.5,
      color: lightTheme ? extension.primaryMedium : extension.primarySemiDark,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(
          bottom: ANGULAR_RADIUS,
        ),
        border: Border(
          right: borderSide,
          left: borderSide,
          bottom: borderSide,
        ),
      ),
    );
  }
}
