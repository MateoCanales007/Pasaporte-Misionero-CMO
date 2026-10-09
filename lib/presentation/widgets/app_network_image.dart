import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Imagen remota con caché en disco (Android) y respaldo con elemento HTML en
/// web cuando el servidor no permite CORS.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.image_outlined,
    this.semanticLabel,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData fallbackIcon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _placeholder();
    final Widget image = kIsWeb
        ? Image.network(
            url,
            width: width,
            height: height,
            fit: fit,
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            errorBuilder: (_, _, _) => _placeholder(),
            loadingBuilder: (context, child, progress) => progress == null ? child : _placeholder(loading: true),
          )
        : CachedNetworkImage(
            imageUrl: url,
            width: width,
            height: height,
            fit: fit,
            placeholder: (_, _) => _placeholder(loading: true),
            errorWidget: (_, _, _) => _placeholder(),
          );
    return semanticLabel == null ? image : Semantics(label: semanticLabel, image: true, child: image);
  }

  Widget _placeholder({bool loading = false}) {
    return Container(
      width: width,
      height: height,
      color: AppColors.surfaceTint,
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3))
          : Icon(fallbackIcon, size: 36, color: AppColors.navy),
    );
  }
}
