import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/content_item.dart';

/// Resuelve el póster de un contenido: URL remota (cacheada), archivo local
/// o placeholder cinematográfico con degradado e inicial del título.
class PosterImage extends StatelessWidget {
  final ContentItem item;
  final BoxFit fit;
  final double? width;
  final double? height;

  const PosterImage({
    super.key,
    required this.item,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final posterUrl = item.posterUrl;

    if (posterUrl == null || posterUrl.isEmpty) {
      return _PosterPlaceholder(item: item, width: width, height: height);
    }

    if (posterUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: posterUrl,
        fit: fit,
        width: width,
        height: height,
        placeholder: (context, url) => Shimmer.fromColors(
          baseColor: AppColors.surfaceElevated,
          highlightColor: AppColors.border,
          child: Container(color: AppColors.surfaceElevated),
        ),
        errorWidget: (context, url, error) =>
            _PosterPlaceholder(item: item, width: width, height: height),
      );
    }

    return Image.file(
      File(posterUrl),
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) =>
          _PosterPlaceholder(item: item, width: width, height: height),
    );
  }
}

class _PosterPlaceholder extends StatelessWidget {
  final ContentItem item;
  final double? width;
  final double? height;

  const _PosterPlaceholder({required this.item, this.width, this.height});

  static const List<List<Color>> _gradients = [
    [Color(0xFF2C0F12), Color(0xFF5A1218)],
    [Color(0xFF0D2233), Color(0xFF104C63)],
    [Color(0xFF2E2308), Color(0xFF5C4A0E)],
    [Color(0xFF14252A), Color(0xFF1F4B44)],
    [Color(0xFF251232), Color(0xFF3F2160)],
    [Color(0xFF29160B), Color(0xFF54331A)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _gradients[item.title.length % _gradients.length];
    final initial = item.title.isEmpty ? '?' : item.title[0].toUpperCase();

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: -12,
            bottom: -8,
            child: Icon(
              item.type.icon,
              size: 84,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Text(
            initial,
            style: GoogleFonts.poppins(
              fontSize: 42,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}
