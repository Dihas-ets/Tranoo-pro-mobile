library;

String cloudinaryOptimizedUrl(
  String url, {
  int? widthPx,
  bool formatAuto = true,
  String quality = 'auto',
}) {
  final raw = url.trim();
  if (raw.isEmpty) return raw;

  const marker = '/image/upload/';
  final idx = raw.indexOf(marker);
  if (idx < 0) return raw;

  final prefix = raw.substring(0, idx + marker.length);
  final suffix = raw.substring(idx + marker.length);

  final firstSlash = suffix.indexOf('/');
  final firstSegment = firstSlash >= 0 ? suffix.substring(0, firstSlash) : suffix;
  final hasTransformLike = firstSegment.contains('w_') ||
      firstSegment.contains('q_') ||
      firstSegment.contains('f_') ||
      firstSegment.contains('c_');
  if (hasTransformLike) return raw;

  final parts = <String>[];
  if (widthPx != null && widthPx > 0) {
    parts.add('w_$widthPx');
    parts.add('c_limit');
  }
  if (quality.trim().isNotEmpty) parts.add('q_$quality');
  if (formatAuto) parts.add('f_auto');

  if (parts.isEmpty) return raw;
  return '$prefix${parts.join(',')}/$suffix';
}

String? cloudinaryVideoThumbUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  final uploadIndex = url.indexOf('/upload/');
  if (uploadIndex == -1) return null;
  final prefix = url.substring(0, uploadIndex + '/upload/'.length);
  final suffix = url.substring(uploadIndex + '/upload/'.length);
  final noExt =
      suffix.contains('.') ? suffix.substring(0, suffix.lastIndexOf('.')) : suffix;
  return '${prefix}so_1/$noExt.jpg';
}
