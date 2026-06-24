import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tranoo_pro/data/screens/profil_utilisateur2.dart';
import 'package:tranoo_pro/services/user_service.dart';
import 'package:tranoo_pro/widgets/skeleton/app_skeleton.dart';
import 'package:tranoo_pro/widgets/transitaire_gallery_section.dart';
import 'package:tranoo_pro/widgets/transitaire_home_buyer_sections.dart';
import 'package:tranoo_pro/widgets/transitaire_profile_ui.dart';
import 'package:tranoo_pro/widgets/video_preview_placeholder.dart';

/// Accueil transitaire — pubs à la une, galerie, profil, voitures, motos.
class TransitaireHome extends StatefulWidget {
  const TransitaireHome({super.key});

  @override
  State<TransitaireHome> createState() => _TransitaireHomeState();
}

class _TransitaireHomeState extends State<TransitaireHome> {
  final GlobalKey<TransitaireHomeBuyerSectionsState> _buyerSectionsKey =
      GlobalKey<TransitaireHomeBuyerSectionsState>();
  Map<String, dynamic>? _userData;
  bool _loadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      _loadUser(),
      _buyerSectionsKey.currentState?.reload() ?? Future.value(),
    ]);
  }

  Future<void> _loadUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      if (token == null) return;
      final resp = await UserService().dio.get(
            '/protected/me',
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          );
      if (!mounted) return;
      final data = resp.data;
      if (data is Map && data['user'] is Map) {
        setState(() {
          _userData = Map<String, dynamic>.from(data['user'] as Map);
          _loadingUser = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingUser = false);
    }
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfilUtilisateur2()),
    );
  }

  void _openFullGallery() {
    if (_userData == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _TransitaireGalleryFullPage(user: _userData!),
      ),
    );
  }

  Widget _sectionHeader(
    String title, {
    VoidCallback? onSeeMore,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 10),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: kTransitaireNavy,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
          const Spacer(),
          if (onSeeMore != null)
            IconButton(
              onPressed: onSeeMore,
              icon: const Icon(
                Icons.chevron_right_rounded,
                color: kTransitaireNavy,
                size: 28,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGalleryPreview(
    List<TransitaireGalleryItem> items,
    int totalCount,
  ) {
    if (_loadingUser) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SkeletonPresets.transitaireGalleryGrid(),
      );
    }
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          height: 120,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6F8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'Ajoutez des photos ou vidéos à votre galerie depuis votre profil.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.78,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: item.isVideo
                    ? VideoPreviewPlaceholder(
                        videoUrl: item.url,
                        iconSize: 32,
                        onTap: _openFullGallery,
                      )
                    : Image.network(
                        item.url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
              if (index == 0 && totalCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _GalleryCountBadge(count: totalCount),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: kTransitaireAmber,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: _openProfile,
          borderRadius: BorderRadius.circular(28),
          splashColor: kTransitaireNavy.withOpacity(0.08),
          highlightColor: kTransitaireNavy.withOpacity(0.05),
          child: const SizedBox(
            width: double.infinity,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_outline, color: kTransitaireNavy, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Voir mon profil',
                    style: TextStyle(
                      color: kTransitaireNavy,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
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

  @override
  Widget build(BuildContext context) {
    final galleryItems = parseTransitaireGallery(
      _userData?['transitaireGallery'],
    );
    final previewItems = galleryItems.take(4).toList();

    return RefreshIndicator(
      color: kTransitaireAmber,
      onRefresh: _bootstrap,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          0,
          8,
          0,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          TransitaireHomeBuyerSections(
            key: _buyerSectionsKey,
            insertAfterPubs: [
              const SizedBox(height: 20),
              _sectionHeader(
                'Ma galerie',
                trailing: galleryItems.isNotEmpty
                    ? _GalleryCountBadge(count: galleryItems.length)
                    : null,
                onSeeMore: galleryItems.isNotEmpty ? _openFullGallery : null,
              ),
              _buildGalleryPreview(previewItems, galleryItems.length),
              const SizedBox(height: 20),
              _buildProfileButton(),
              const SizedBox(height: 8),
            ],
          ),
        ],
      ),
    );
  }
}

class _GalleryCountBadge extends StatelessWidget {
  final int count;

  const _GalleryCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.collections, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransitaireGalleryFullPage extends StatelessWidget {
  final Map<String, dynamic> user;

  const _TransitaireGalleryFullPage({required this.user});

  @override
  Widget build(BuildContext context) {
    final items = parseTransitaireGallery(user['transitaireGallery']);
    final name = TransitaireProfileHelpers.displayName(user);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Galerie — $name',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: kTransitaireNavy,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kTransitaireNavy,
        elevation: 0,
        centerTitle: true,
      ),
      body: TransitaireGalleryGrid(
        items: items,
        user: user,
      ),
    );
  }
}
