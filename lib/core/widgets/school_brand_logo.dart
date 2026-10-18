import 'package:flutter/material.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/utils/media_url.dart';

class SchoolBrandLogo extends StatelessWidget {
  const SchoolBrandLogo({
    super.key,
    required this.imageUrl,
    required this.size,
  });

  final String imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    const fallback = Icon(
      Icons.account_balance_rounded,
      color: Color(0xFF587043),
      size: 31,
    );
    final url = resolveOriginalImageUrl(imageUrl.trim());
    return Semantics(
      label: 'School logo',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: context.appTheme.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: url.isEmpty
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}
