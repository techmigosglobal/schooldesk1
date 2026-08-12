import 'dart:io';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:schooldesk1/core/app_export.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/utils/media_url.dart';

extension ImageTypeExtension on String {
  ImageType get imageType {
    if (startsWith('http') || startsWith('https')) {
      return ImageType.network;
    } else if (endsWith('.svg')) {
      return ImageType.svg;
    } else if (startsWith('file: //')) {
      return ImageType.file;
    } else {
      return ImageType.png;
    }
  }
}

enum ImageType { svg, png, network, file, unknown }

// ignore_for_file: must_be_immutable
class CustomImageWidget extends StatelessWidget {
  const CustomImageWidget({
    super.key,
    this.imageUrl,
    this.height,
    this.width,
    this.color,
    this.fit,
    this.alignment,
    this.onTap,
    this.radius,
    this.margin,
    this.border,
    this.placeHolder = 'assets/images/no-image.jpg',
    this.errorWidget,
    this.semanticLabel,
  });

  ///[imageUrl] is required parameter for showing image
  final String? imageUrl;

  final double? height;

  final double? width;

  final BoxFit? fit;

  final String placeHolder;

  final Color? color;

  final Alignment? alignment;

  final VoidCallback? onTap;

  final BorderRadius? radius;

  final EdgeInsetsGeometry? margin;

  final BoxBorder? border;

  /// Optional widget to show when the image fails to load.
  /// If null, a default asset image is shown.
  final Widget? errorWidget;

  /// Semantic label for the image to improve accessibility
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return alignment != null
        ? Align(alignment: alignment!, child: _buildWidget(context))
        : _buildWidget(context);
  }

  Widget _buildWidget(BuildContext context) {
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: InkWell(onTap: onTap, child: _buildCircleImage(context)),
    );
  }

  ///build the image with border radius
  Widget _buildCircleImage(BuildContext context) {
    if (radius != null) {
      return ClipRRect(
        borderRadius: radius ?? BorderRadius.zero,
        child: _buildImageWithBorder(context),
      );
    } else {
      return _buildImageWithBorder(context);
    }
  }

  ///build the image with border and border radius style
  Widget _buildImageWithBorder(BuildContext context) {
    if (border != null) {
      return Container(
        decoration: BoxDecoration(border: border, borderRadius: radius),
        child: _buildImageView(context),
      );
    } else {
      return _buildImageView(context);
    }
  }

  int? _decodeDimension(BuildContext context, double? logicalDimension) {
    if (logicalDimension == null ||
        !logicalDimension.isFinite ||
        logicalDimension <= 0) {
      return null;
    }
    // Decode only the pixels the rendered image needs. The cap avoids an
    // unexpectedly large source image consuming excessive memory on tablets.
    return (logicalDimension * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(1, 2048);
  }

  Widget _buildImageView(BuildContext context) {
    final decodeWidth = _decodeDimension(context, width);
    final decodeHeight = _decodeDimension(context, height);
    if (imageUrl != null) {
      switch (imageUrl!.imageType) {
        case ImageType.svg:
          return SizedBox(
            height: height,
            width: width,
            child: SvgPicture.asset(
              imageUrl!,
              height: height,
              width: width,
              fit: fit ?? BoxFit.contain,
              colorFilter: color != null
                  ? ColorFilter.mode(
                      color ?? Colors.transparent,
                      BlendMode.srcIn,
                    )
                  : null,
              semanticsLabel: semanticLabel,
            ),
          );
        case ImageType.file:
          return Image.file(
            File(imageUrl!),
            height: height,
            width: width,
            cacheWidth: decodeWidth,
            cacheHeight: decodeHeight,
            fit: fit ?? BoxFit.cover,
            color: color,
            semanticLabel: semanticLabel,
          );
        case ImageType.network:
          final optimizedUrl = optimizedImageUrl(
            imageUrl!,
            width: decodeWidth ?? 900,
            height: decodeHeight ?? 900,
          );
          return CachedNetworkImage(
            height: height,
            width: width,
            fit: fit,
            imageUrl: optimizedUrl,
            color: color,
            memCacheWidth: decodeWidth,
            memCacheHeight: decodeHeight,
            maxWidthDiskCache: decodeWidth,
            maxHeightDiskCache: decodeHeight,
            placeholder: (context, url) => SizedBox(
              height: 30,
              width: 30,
              child: LinearProgressIndicator(
                color: context.appTheme.muted,
                backgroundColor: context.appTheme.muted,
              ),
            ),
            errorWidget: (context, url, error) =>
                errorWidget ??
                Image.asset(
                  placeHolder,
                  height: height,
                  width: width,
                  fit: fit ?? BoxFit.cover,
                  semanticLabel: semanticLabel,
                ),
          );
        case ImageType.png:
        default:
          return Image.asset(
            imageUrl!,
            height: height,
            width: width,
            fit: fit ?? BoxFit.cover,
            color: color,
            semanticLabel: semanticLabel,
          );
      }
    }
    return const SizedBox();
  }
}
