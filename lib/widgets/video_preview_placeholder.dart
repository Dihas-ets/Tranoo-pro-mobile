import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';
import 'package:tranoo_pro/utils/cloudinary_url.dart';

/// Aperçu vidéo léger : miniature Cloudinary + bouton lecture (pas de loader bloquant).
class VideoPreviewPlaceholder extends StatelessWidget {
  final String? videoUrl;
  final double iconSize;
  final String label;
  final Color backgroundColor;
  final Color iconColor;
  final Color textColor;
  final VoidCallback? onTap;
  /// Conservé pour compatibilité — l'aperçu frame vidéo n'est plus initialisé ici.
  final bool enablePreviewFrame;

  const VideoPreviewPlaceholder({
    super.key,
    this.videoUrl,
    this.iconSize = 40,
    this.label = 'Vidéo disponible',
    this.backgroundColor = const Color(0xFF1A1A1A),
    this.iconColor = Colors.white,
    this.textColor = Colors.white,
    this.onTap,
    this.enablePreviewFrame = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final thumbUrl = cloudinaryVideoThumbUrl(videoUrl);

    Widget content = Container(
      width: double.infinity,
      height: double.infinity,
      color: backgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumbUrl != null)
            CachedNetworkImage(
              imageUrl: thumbUrl,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 120),
              placeholder: (_, __) => ColoredBox(color: backgroundColor),
              errorWidget: (_, __, ___) => ColoredBox(color: backgroundColor),
            ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_circle_fill,
                    color: iconColor == Colors.white
                        ? Colors.grey.shade900
                        : iconColor,
                    size: iconSize,
                  ),
                ),
                if (label.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    label == 'Vidéo disponible' ? l10n.videoAvailable : label,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      content = GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}
