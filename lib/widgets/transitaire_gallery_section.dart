import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';
import 'package:tranoo_pro/widgets/skeleton/app_skeleton.dart';
import 'package:tranoo_pro/services/user_service.dart';
import 'package:tranoo_pro/utils/cloudinary_upload.dart';
import 'package:tranoo_pro/utils/api_error_message.dart';
import 'package:tranoo_pro/widgets/transitaire_profile_ui.dart';
import 'package:video_player/video_player.dart';

const int kTransitaireGalleryMaxItems = 20;

class TransitaireGalleryItem {
  final String type;
  final String url;

  const TransitaireGalleryItem({required this.type, required this.url});

  Map<String, dynamic> toJson() => {'type': type, 'url': url};

  bool get isVideo => type == 'video';
}

List<TransitaireGalleryItem> parseTransitaireGallery(dynamic raw) {
  if (raw is! List) return [];
  final items = <TransitaireGalleryItem>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final type = (entry['type'] ?? '').toString();
    final url = (entry['url'] ?? '').toString().trim();
    if (url.isEmpty || (type != 'image' && type != 'video')) continue;
    items.add(TransitaireGalleryItem(type: type, url: url));
  }
  return items;
}

Future<void> persistTransitaireGallery(
  List<TransitaireGalleryItem> items,
) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  final idToken = await user.getIdToken();
  final dio = Dio(
    BaseOptions(
      baseUrl: getBaseUrl(),
      headers: {'Authorization': 'Bearer $idToken'},
    ),
  );
  await dio.patch(
    '/users/me',
    data: {'transitaireGallery': items.map((e) => e.toJson()).toList()},
  );
}

Future<void> showTransitaireGalleryUploadSheet(
  BuildContext context, {
  required List<TransitaireGalleryItem> items,
  required ValueChanged<List<TransitaireGalleryItem>> onUpdated,
}) async {
  final l10n = AppLocalizations.of(context)!;
  if (items.length >= kTransitaireGalleryMaxItems) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.transitaireGalleryMaxItems(kTransitaireGalleryMaxItems),
        ),
      ),
    );
    return;
  }

  final choice = await showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.transitaireGalleryAddTitle,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: kTransitaireNavy,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading:
                  const Icon(Icons.photo_library_outlined, color: kTransitaireNavy),
              title: Text(l10n.transitaireGalleryPhotosMulti),
              onTap: () => Navigator.pop(ctx, 'images'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.videocam_outlined, color: kTransitaireNavy),
              title: Text(l10n.transitaireGalleryVideo),
              onTap: () => Navigator.pop(ctx, 'video'),
            ),
          ],
        ),
      ),
    ),
  );
  if (choice == null || !context.mounted) return;

  final updated = List<TransitaireGalleryItem>.from(items);
  var loadingShown = false;
  try {
    if (choice == 'images') {
      final picked = await ImagePicker().pickMultiImage();
      if (picked.isEmpty) return;
      if (context.mounted) {
        loadingShown = true;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black45,
          builder: (dlgCtx) => Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(strokeWidth: 2),
                    const SizedBox(height: 14),
                    Text(l10n.transitaireGalleryUploadingPhotos),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      for (final file in picked) {
        if (updated.length >= kTransitaireGalleryMaxItems) break;
        final url = await uploadImageToCloudinary(
          File(file.path),
          folder: CloudinaryFolders.transitaireGalleryImages,
        );
        if (url != null) {
          updated.add(TransitaireGalleryItem(type: 'image', url: url));
        }
      }
    } else {
      final picked =
          await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (picked == null) return;
      if (context.mounted) {
        loadingShown = true;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black45,
          builder: (dlgCtx) => Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(strokeWidth: 2),
                    const SizedBox(height: 14),
                    Text(l10n.transitaireGalleryUploadingVideo),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      final url = await uploadVideoToCloudinary(
        File(picked.path),
        folder: CloudinaryFolders.transitaireGalleryVideos,
      );
      if (url != null) {
        updated.add(TransitaireGalleryItem(type: 'video', url: url));
      }
    }

    if (updated.length == items.length) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.transitaireGalleryUploadFailed)),
        );
      }
      return;
    }

    await persistTransitaireGallery(updated);
    if (context.mounted) onUpdated(updated);
  } on DioException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ApiErrorMessage.fromDio(l10n, e),
        ),
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.transitaireGalleryUploadError)),
    );
  } finally {
    if (loadingShown && context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

class TransitaireGalleryGrid extends StatelessWidget {
  final List<TransitaireGalleryItem> items;
  final Map<String, dynamic> user;
  final bool isOwner;
  final ValueChanged<List<TransitaireGalleryItem>>? onItemsChanged;
  final String emptyMessage;
  final double bottomPadding;

  const TransitaireGalleryGrid({
    super.key,
    required this.items,
    required this.user,
    this.isOwner = false,
    this.onItemsChanged,
    this.emptyMessage = '',
    this.bottomPadding = 100,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fallbackEmpty = emptyMessage.isNotEmpty
        ? emptyMessage
        : l10n.transitaireGalleryEmpty;
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_library_outlined,
                  size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                isOwner
                    ? l10n.transitaireGalleryEmptyOwner
                    : fallbackEmpty,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        bottomPadding + MediaQuery.paddingOf(context).bottom,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: item.isVideo
                  ? _GalleryVideoThumb(
                      url: item.url,
                      onTap: () => _showVideo(context, item.url),
                    )
                  : GestureDetector(
                      onTap: () => _showImage(context, item.url),
                      child: Image.network(item.url, fit: BoxFit.cover),
                    ),
            ),
            if (isOwner && onItemsChanged != null)
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () => _confirmDelete(context, index),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dlgL10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(dlgL10n.transitaireGalleryDeleteTitle),
          content: Text(dlgL10n.transitaireGalleryDeleteConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(dlgL10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(dlgL10n.delete),
            ),
          ],
        );
      },
    );
    if (ok != true || onItemsChanged == null) return;
    final updated = List<TransitaireGalleryItem>.from(items)..removeAt(index);
    try {
      await persistTransitaireGallery(updated);
      onItemsChanged!(updated);
    } on DioException catch (e) {
      if (!context.mounted) return;
      final dlgL10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiErrorMessage.fromDio(dlgL10n, e)),
        ),
      );
    }
  }

  void _showImage(BuildContext context, String url) {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.88),
      pageBuilder: (ctx, _, __) => SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVideo(BuildContext context, String url) {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      pageBuilder: (ctx, _, __) => _TransitaireVideoViewer(url: url),
    );
  }
}

class _GalleryVideoThumb extends StatelessWidget {
  final String url;
  final VoidCallback? onTap;

  const _GalleryVideoThumb({required this.url, this.onTap});

  @override
  Widget build(BuildContext context) {
    final thumb = _cloudinaryThumb(url);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.black87,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (thumb != null)
              Positioned.fill(
                child: Image.network(thumb, fit: BoxFit.cover),
              ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, size: 32),
            ),
          ],
        ),
      ),
    );
  }

  String? _cloudinaryThumb(String? url) {
    if (url == null || url.isEmpty) return null;
    final uploadIndex = url.indexOf('/upload/');
    if (uploadIndex == -1) return null;
    final prefix = url.substring(0, uploadIndex + '/upload/'.length);
    final suffix = url.substring(uploadIndex + '/upload/'.length);
    final noExt = suffix.contains('.')
        ? suffix.substring(0, suffix.lastIndexOf('.'))
        : suffix;
    return '${prefix}so_1/$noExt.jpg';
  }
}

class _TransitaireVideoViewer extends StatefulWidget {
  final String url;

  const _TransitaireVideoViewer({required this.url});

  @override
  State<_TransitaireVideoViewer> createState() => _TransitaireVideoViewerState();
}

class _TransitaireVideoViewerState extends State<_TransitaireVideoViewer> {
  late VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_ready)
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            )
          else
            SkeletonPresets.wrap(const SkeletonCircle(size: 48)),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
