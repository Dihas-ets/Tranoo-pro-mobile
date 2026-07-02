import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tranoo_pro/utils/cloudinary_url.dart';

int cloudinaryWidthPx(
  BuildContext context, {
  double? logicalWidth,
  int min = 120,
  int max = 1600,
}) {
  final w = logicalWidth ?? MediaQuery.sizeOf(context).width;
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return (w * dpr).round().clamp(min, max);
}

ImageProvider proImageProvider(
  String url, {
  int? cloudinaryWidthPx,
}) {
  final optimized = cloudinaryOptimizedUrl(
    url.trim(),
    widthPx: cloudinaryWidthPx != null ? math.max(1, cloudinaryWidthPx) : null,
  );
  return CachedNetworkImageProvider(optimized);
}

Future<void> precacheProImages(
  BuildContext context,
  Iterable<String> urls, {
  int? cloudinaryWidthPx,
  int maxCount = 24,
}) async {
  final tasks = <Future<void>>[];
  var count = 0;
  for (final raw in urls) {
    if (count >= maxCount) break;
    final url = raw.trim();
    if (url.isEmpty || !url.startsWith('http')) continue;
    tasks.add(
      precacheImage(
        proImageProvider(url, cloudinaryWidthPx: cloudinaryWidthPx),
        context,
      ).catchError((_) {}),
    );
    count++;
  }
  if (tasks.isNotEmpty) {
    await Future.wait(tasks);
  }
}

List<String> photoUrlsFromArticles(
  Iterable<Map<String, dynamic>> articles, {
  int maxArticles = 10,
}) {
  final urls = <String>[];
  for (final article in articles.take(maxArticles)) {
    final photos = article['photos'];
    if (photos is List && photos.isNotEmpty) {
      final first = photos.first?.toString().trim();
      if (first != null && first.isNotEmpty) urls.add(first);
    }
  }
  return urls;
}
