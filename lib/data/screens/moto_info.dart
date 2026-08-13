import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:http/http.dart' as http;
import 'movie.dart';
import 'package:tranoo_pro/services/user_service.dart'; // Importer UserService pour gérer les rôles
import 'package:tranoo_pro/utils/role_redirect.dart'; // Importer RoleRedirect pour la redirection basée sur le rôle
import 'package:tranoo_pro/data/screens/succes_vente.dart'; // Importer SuccesVenteScreen
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';

import 'package:confetti/confetti.dart';
import 'une.dart' as pub_page; // Import pour la page de demande de pub avec préfixe
import 'dart:developer';
import 'verification_payment.dart'; // Import pour la page de vérification de paiement
import 'package:tranoo_pro/widgets/video_preview_placeholder.dart';
import 'package:tranoo_pro/utils/auth_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:tranoo_pro/utils/amount_display.dart';
import 'package:tranoo_pro/widgets/spec_info_card.dart';
import 'package:tranoo_pro/utils/article_view_helper.dart';
import 'package:tranoo_pro/utils/whatsapp_helper.dart';
import 'package:tranoo_pro/widgets/cached_media_image.dart';
import 'connexion_page.dart';

class MotoInfo extends StatefulWidget {
  final String? id;
  final String? titre;
  final String? description;
  final String? marque;
  final String? modele;
  final String? annee;
  final String? prix;
  final String? condition;
  final String? boiteVitesse;
  final String? carburant;
  final String? climatiseur;
  final String? distance;
  final String? sieges;
  final String? portes;
  final String? cylindre; // Ajouté
  final String? couleur; // Couleur
  final bool? dedouanement; // Dédouanement
  final String? lieu;
  final Map<String, dynamic>? fournisseur;
  final List<String> images;
  final List<String> videos;
  final String? video;
  final String? videoOptimized;
  final int? selectedImageIndex;
  final String? entreprise;
  final bool fromPub;
  final String? alertNotificationId;
  final String? alertBuyerId;
  final String? alertRequestType;
  // Champs spécifiques moto
  final String? typeMoto;
  final String? typeMoteur;
  final String? puissance;
  final String? transmission;
  final String? demarrage;
  final String? refroidissement;
  final String? capaciteReservoir;
  final String? autonomie;
  final String? disponibilite;
  final bool? garantieConstructeur;
  final String? dureeGarantie;
  final String? kilometrage;
  final List<String> equipements;
  final String? devise;

  const MotoInfo({
    super.key,
    this.id,
    this.titre,
    this.description,
    this.marque,
    this.modele,
    this.annee,
    this.prix,
    this.condition,
    this.boiteVitesse,
    this.carburant,
    this.climatiseur,
    this.distance,
    this.sieges,
    this.portes,
    this.cylindre,
    this.couleur,
    this.dedouanement,
    this.lieu,
    this.fournisseur,
    required this.images,
    this.videos = const [],
    this.video,
    this.videoOptimized,
    this.selectedImageIndex,
    this.entreprise,
    this.fromPub = false,
    this.alertNotificationId,
    this.alertBuyerId,
    this.alertRequestType,
    this.typeMoto,
    this.typeMoteur,
    this.puissance,
    this.transmission,
    this.demarrage,
    this.refroidissement,
    this.capaciteReservoir,
    this.autonomie,
    this.disponibilite,
    this.garantieConstructeur,
    this.dureeGarantie,
    this.kilometrage,
    this.equipements = const [],
    this.devise,
  });

  factory MotoInfo.fromArticleMap(
    Map<String, dynamic> m, {
    bool fromPub = false,
  }) {
    final photos =
        (m['photos'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final equips = (m['equipements'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];
    return MotoInfo(
      id: (m['_id'] ?? m['id'] ?? m['articleId'] ?? '').toString(),
      titre: m['titre']?.toString(),
      description: m['description']?.toString(),
      marque: m['marque']?.toString(),
      modele: m['modele']?.toString(),
      annee: m['annee']?.toString(),
      prix: m['prix']?.toString(),
      condition: m['condition']?.toString(),
      cylindre: m['cylindre']?.toString(),
      lieu: (m['localisation'] ?? m['lieu'])?.toString(),
      fournisseur: m['fournisseur'] is Map
          ? Map<String, dynamic>.from(m['fournisseur'] as Map)
          : null,
      images: photos,
      video: m['video']?.toString(),
      videoOptimized: m['videoOptimized']?.toString(),
      entreprise: m['entreprise']?.toString(),
      fromPub: fromPub,
      typeMoto: m['typeMoto']?.toString(),
      typeMoteur: m['typeMoteur']?.toString(),
      puissance: m['puissance']?.toString(),
      transmission: m['transmission']?.toString(),
      demarrage: m['demarrage']?.toString(),
      refroidissement: m['refroidissement']?.toString(),
      capaciteReservoir: m['capaciteReservoir']?.toString(),
      autonomie: m['autonomie']?.toString(),
      disponibilite: m['disponibilite']?.toString(),
      garantieConstructeur: m['garantieConstructeur'] == true,
      dureeGarantie: m['dureeGarantie']?.toString(),
      kilometrage: (m['kilometrage'] ?? m['distance'])?.toString(),
      equipements: equips,
      devise: m['devise']?.toString(),
    );
  }

  @override
  State<MotoInfo> createState() => _MotoInfoState();
}

class _MotoInfoState extends State<MotoInfo> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  late int _currentImageIndex; // Gère l'image actuelle affichée
  late PageController _pageController;
  late List<String> _videos; // Vidéos associées
  Set<String> _favoriteIds = <String>{};
  String? _selectedCountry;
  int get _imagesCount => widget.images.length;
  int get _videosCount => _videos.length;
  int get _totalMediaCount => _imagesCount + _videosCount;
  String? get _primaryVideo =>
      _videos.isNotEmpty ? _videos.first : (widget.videoOptimized ?? widget.video);
  final List<String> africanCountries = [
    'Bénin',
    'Burkina Faso',
    'Côte d\'Ivoire',
    'Mali',
    'Niger',
    'Sénégal',
    'Togo',
    'Cameroun',
    'Gabon',
    'Guinée',
    'Congo',
    'RDC',
    'Maroc',
    'Algérie',
    'Tunisie',
    'Afrique du Sud',
    'Nigeria',
    'Ghana',
    'Kenya',
    'Éthiopie',
  ];
  late ConfettiController _confettiController;
  bool _isOnline = false;
  bool _isPublishing = false;
  bool _isSpecsExpanded = false;
  int _verificationPrice = 20000;
  String _formatFcfa(int value) {
    final priceStr = value.toString();
    final reversed = priceStr.split('').reversed.join('');
    final withDots = reversed.replaceAllMapped(
      RegExp(r'(\d{3})(?=\d)'),
      (Match m) => '${m[0]}.',
    );
    return withDots.split('').reversed.join('');
  }

  String get _verificationPriceLabel => '${_formatFcfa(_verificationPrice)} FCFA';

  Future<void> _loadVerificationPrice() async {
    try {
      final url =
          '${UserService().dio.options.baseUrl}/admin/verification-pricing';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final raw = data['prixVerification'] ??
            (data['pricing'] is Map
                ? data['pricing']['prixVerification']
                : null);
        final parsed = int.tryParse('$raw');
        if (parsed != null && parsed >= 0 && mounted) {
          setState(() => _verificationPrice = parsed);
        }
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    trackArticleView(widget.id);
    _loadVerificationPrice();
    // Log toutes les valeurs reçues
    log('[MotoInfo] titre: ${widget.titre}');
    log('[MotoInfo] description: ${widget.description}');
    log('[MotoInfo] marque: ${widget.marque}');
    log('[MotoInfo] modele: ${widget.modele}');
    log('[MotoInfo] annee: ${widget.annee}');
    log('[MotoInfo] prix: ${widget.prix}');
    log('[MotoInfo] condition: ${widget.condition}');
    log('[MotoInfo] boiteVitesse: ${widget.boiteVitesse}');
    log('[MotoInfo] carburant: ${widget.carburant}');
    log('[MotoInfo] climatiseur: ${widget.climatiseur}');
    log('[MotoInfo] distance: ${widget.distance}');
    log('[MotoInfo] sieges: ${widget.sieges}');
    log('[MotoInfo] portes: ${widget.portes}');
    log('[MotoInfo] cylindre: ${widget.cylindre}');
    log('[MotoInfo] images: ${widget.images}');
    log('[MotoInfo] video: ${widget.video}');
    _videos = widget.videos.isNotEmpty
        ? widget.videos.where((v) => v.isNotEmpty).toList()
        : (widget.video != null && widget.video!.isNotEmpty
            ? [widget.video!]
            : <String>[]);
    log('[MotoInfo] videos: $_videos');
    log('[MotoInfo] selectedImageIndex: ${widget.selectedImageIndex}');
    final totalMediaCount = widget.images.length + _videos.length;
    // Correction RangeError : si la liste est vide, index = 0
    if (totalMediaCount == 0) {
      _currentImageIndex = 0;
    } else if (widget.selectedImageIndex != null &&
        widget.selectedImageIndex! >= 0 &&
        widget.selectedImageIndex! < widget.images.length) {
      _currentImageIndex = widget.selectedImageIndex!;
    } else {
      _currentImageIndex = 0;
    }
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    _pageController = PageController(
      initialPage: _currentImageIndex.clamp(
        0,
        totalMediaCount > 0 ? totalMediaCount - 1 : 0,
      ),
    );
    if ((widget.id ?? '').trim().isNotEmpty) {
      _isOnline = true;
    }
    _loadArticleStatut();
  }

  bool _articlePublishedStatut(String statut) {
    return statut == 'en_ligne' ||
        statut == 'en_attente' ||
        statut == 'vendu' ||
        statut == 'non_vendu';
  }

  Future<void> _loadArticleStatut() async {
    try {
      final id = widget.id;
      if (id == null || id.isEmpty) return;
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      final res = await http.get(
        Uri.parse('${UserService().dio.options.baseUrl}/articles/$id'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final statut = (data['statut'] ?? '').toString().toLowerCase();
        if (!mounted) return;
        setState(() {
          _isOnline = _articlePublishedStatut(statut);
        });
      }
    } catch (_) {}
  }

  String get _whatsAppPhone =>
      WhatsappHelper.phoneFromArticleSupplier(fournisseur: widget.fournisseur) ??
      WhatsappHelper.supportDigits;

  String _buyWhatsAppMessage(AppLocalizations l10n) {
    final label = WhatsappHelper.articleListingLabel(
      titre: widget.titre,
      marque: widget.marque,
      modele: widget.modele,
      fallback: l10n.defaultMotoTitle,
    );
    final id = (widget.id ?? '').trim();
    if (id.isNotEmpty) {
      return l10n.whatsappMotoInterestWithRef(label, id);
    }
    return l10n.whatsappMotoInterestNoRef(label);
  }

  Future<void> _openWhatsApp({String? message}) async {
    await WhatsappHelper.openChat(
      context,
      phone: _whatsAppPhone,
      message: message,
      unavailableMessage: l10n.sellerPhoneUnavailable,
      cannotOpenMessage: l10n.cannotOpenWhatsApp,
    );
  }

  void _precacheAdjacentImages(int index) {
    if (!mounted || widget.images.isEmpty) return;
    final w = MediaQuery.sizeOf(context).width *
        MediaQuery.devicePixelRatioOf(context);
    final urls = <String>[];
    for (final delta in [-1, 0, 1]) {
      final i = index + delta;
      if (i < 0 || i >= widget.images.length) continue;
      final url = widget.images[i].trim();
      if (url.startsWith('http')) urls.add(url);
    }
    precacheMediaImages(
      context,
      urls,
      cloudinaryWidthPx: w.round().clamp(120, 1600),
      maxCount: 3,
    );
  }

  void _openImageViewer(int startIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.95),
      builder: (ctx) {
        final controller = PageController(initialPage: startIndex);
        return GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: Stack(
            children: [
              PageView.builder(
                controller: controller,
                itemCount: widget.images.length,
                itemBuilder: (context, index) {
                  return Center(
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 5,
                      child: CachedMediaImage(
                        url: widget.images[index],
                        fit: BoxFit.contain,
                        placeholderColor: Colors.black,
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: SmoothPageIndicator(
                    controller: controller,
                    count: widget.images.length,
                    effect: WormEffect(
                      activeDotColor: Colors.white,
                      dotColor: Colors.white24,
                      dotHeight: 8,
                      dotWidth: 8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final userService = UserService(); // Instance du service utilisateur
    final isChauffeur =
        userService.currentRole == UserRole.chauffeur || userService.currentRole == UserRole.livreur;

    // Récupération des dimensions de l'écran pour la responsivité
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    // LOGS DEBUG
    log('[MotoInfo][build] widget.images.length = ${widget.images.length}');
    log('[MotoInfo][build] _currentImageIndex = $_currentImageIndex');
    if (widget.images.isNotEmpty) {
      log('[MotoInfo][build] Première image = ${widget.images[0]}');
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: _buildAppBar(),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          _buildImageSection(screenWidth, screenHeight),
          _buildContentSection(screenWidth, isChauffeur),
        ],
      ),
    );
  }

  // Barre d'application avec bouton de retour et partage
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  // Affiche l'image principale sélectionnée
  Widget _buildImageSection(double screenWidth, double screenHeight) {
    log(
      '[MotoInfo][_buildImageSection] widget.images.length = ${widget.images.length}',
    );
    log(
      '[MotoInfo][_buildImageSection] _currentImageIndex = $_currentImageIndex',
    );
    if (widget.images.isNotEmpty && _currentImageIndex < widget.images.length) {
      log(
        '[MotoInfo][_buildImageSection] Image affichée = ${widget.images[_currentImageIndex]}',
      );
    }

    return Stack(
      children: [
        SizedBox(
          height: screenHeight * 0.4,
          width: double.infinity,
          child: _totalMediaCount > 0
              ? PageView.builder(
                  controller: _pageController,
                  itemCount: _totalMediaCount,
                  onPageChanged: (i) {
                    setState(() => _currentImageIndex = i);
                    _precacheAdjacentImages(i);
                  },
                  itemBuilder: (context, index) {
                    if (index < _imagesCount) {
                      final hasImage =
                          index < widget.images.length && widget.images[index].isNotEmpty;
                      if (!hasImage) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: Icon(Icons.image_not_supported, size: 80),
                          ),
                        );
                      }
                      return GestureDetector(
                        onTap: () => _openImageViewer(index),
                        child: ClipRect(
                          child: InteractiveViewer(
                            minScale: 1,
                            maxScale: 4,
                            child: CachedMediaImage(
                              url: widget.images[index],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              cloudinaryWidthPx:
                                  MediaQuery.sizeOf(context).width.toInt(),
                            ),
                          ),
                        ),
                      );
                    } else {
                      final videoIndex = index - _imagesCount;
                      final videoUrl = videoIndex < _videos.length
                          ? _videos[videoIndex]
                          : _primaryVideo;
                      return VideoPreviewPlaceholder(
                        videoUrl: videoUrl,
                        iconSize: 60,
                        onTap: () {
                          final article = {
                            'id': widget.id,
                            'titre': widget.titre,
                            'description': widget.description,
                            'marque': widget.marque,
                            'modele': widget.modele,
                            'annee': widget.annee,
                            'prix': widget.prix,
                            'photos': widget.images,
                            'video': videoUrl,
                            'entreprise': widget.entreprise,
                            'type': 'moto',
                          };
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  Movie(videoUrl: videoUrl, article: article),
                            ),
                          );
                        },
                      );
                    }
                  },
                )
              : Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(Icons.image_not_supported, size: 80),
                  ),
                ),
        ),
        // Badge condition (gauche)
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: ((widget.condition ?? '').toLowerCase() == 'nouveau' ||
                      (widget.condition ?? '').toLowerCase() == 'neuf')
                  ? Colors.purple
                  : const Color(0xFFF8BF13),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              ((widget.condition ?? '').toLowerCase() == 'nouveau' ||
                      (widget.condition ?? '').toLowerCase() == 'neuf')
                  ? 'Nouveau'
                  : 'Occasion',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),

        // Icônes verticales (droite)
        Positioned(
          right: 16,
          top: 16,
          child: Column(
            children: [
              // Vue (remplacement du favori pour cohérence avec les cards)
              GestureDetector(
                onTap: () => _toggleFavorite(widget.id ?? ''),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.remove_red_eye_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Icône play vidéo
              GestureDetector(
                onTap: () {
                  final videoUrl = _primaryVideo;
                  if (videoUrl != null && videoUrl.isNotEmpty) {
                    final article = {
                      'titre': widget.titre,
                      'description': widget.description,
                      'marque': widget.marque,
                      'modele': widget.modele,
                      'annee': widget.annee,
                      'prix': widget.prix,
                      'condition': widget.condition,
                      'boiteVitesse': widget.boiteVitesse,
                      'carburant': widget.carburant,
                      'climatiseur': widget.climatiseur,
                      'distance': widget.distance,
                      'sieges': widget.sieges,
                      'portes': widget.portes,
                      'cylindre': widget.cylindre,
                      'couleur': widget.couleur,
                      'dedouanement': widget.dedouanement,
                      'photos': widget.images,
                      'video': videoUrl,
                      'entreprise': widget.entreprise,
                      'type': 'moto',
                    };
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            Movie(videoUrl: videoUrl, article: article),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.noVideoAvailable)),
                    );
                  }
                },
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: _primaryVideo != null
                      ? Colors.white
                      : Colors.grey[300],
                  child: Icon(
                    Icons.play_circle_fill,
                    color:
                        _primaryVideo != null ? Colors.red : Colors.grey,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // WhatsApp
              GestureDetector(
                onTap: _openWhatsApp,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  child: Image.asset(
                    'assets/images/whatsapp_icon.png',
                    width: 22,
                    height: 22,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.chat_bubble_outline,
                      color: Color(0xFF25D366),
                      size: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Appel téléphonique
              GestureDetector(
                onTap: () async {
                  final url = 'tel:+2290141839801';
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.cannotMakeCall)),
                    );
                  }
                },
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  child: const Icon(
                    Icons.phone,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Dots indicator
        if (_totalMediaCount > 1)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Center(
              child: SmoothPageIndicator(
                controller: _pageController,
                count: _totalMediaCount,
                effect: JumpingDotEffect(
                  activeDotColor: Colors.white,
                  dotColor: Colors.white70,
                  dotHeight: 8,
                  dotWidth: 8,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _toggleFavorite(String articleId) async {
    if (articleId.isEmpty) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return;
      final isFav = _favoriteIds.contains(articleId);
      final uri = Uri.parse(
        '${UserService().dio.options.baseUrl}/users/me/favoris',
      );
      final response = await (isFav
          ? http.delete(
              uri,
              headers: {
                'Authorization': 'Bearer $idToken',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({'articleId': articleId}),
            )
          : http.post(
              uri,
              headers: {
                'Authorization': 'Bearer $idToken',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({'articleId': articleId}),
            ));
      if (response.statusCode == 200) {
        setState(() {
          if (isFav) {
            _favoriteIds.remove(articleId);
          } else {
            _favoriteIds.add(articleId);
          }
        });
      }
    } catch (_) {}
  }

  // Section des détails et spécifications
  Widget _buildContentSection(double screenWidth, bool isChauffeur) {
    final bool shouldShowDeliveryOptions =
        isChauffeur || (widget.fromPub == true);
    return Padding(
      padding: EdgeInsets.all(screenWidth * 0.04), // Espacement ajusté
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(screenWidth), // En-tête avec le modèle et le prix
          const SizedBox(height: 16),
          _buildDescription(screenWidth), // Description de la voiture
          const SizedBox(height: 24),
          _buildSpecifications(screenWidth), // Liste des spécifications
          const SizedBox(height: 24),
          _buildCheckboxes(
            screenWidth,
            shouldShowDeliveryOptions,
          ), // Cases à cocher (si applicable)
          const SizedBox(height: 24),
          _buildActionButton(isChauffeur), // Bouton d'action dynamique
        ],
      ),
    );
  }

  // En-tête avec le nom de la voiture et le prix
  Widget _buildHeader(double screenWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          (widget.titre != null && widget.titre!.isNotEmpty)
              ? widget.titre!
              : 'Non renseigné',
          style: TextStyle(
            fontSize: screenWidth * 0.06,
            fontWeight: FontWeight.bold,
          ),
        ),
        //Nom de l'entreprise
        Text(
          AuthConfig.displayEntreprise(widget.entreprise),
          style: TextStyle(
            fontSize: screenWidth * 0.05,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),

        const SizedBox(height: 8),
        Text(
          (widget.prix != null && widget.prix!.isNotEmpty)
              ? '${formatFcfaDots(widget.prix!)} FCFA'
              : 'Non renseigné',
          style: TextStyle(
            fontSize: screenWidth * 0.05,
            fontWeight: FontWeight.bold,
            color: Colors.amber,
          ),
        ),
      ],
    );
  }

  // Description de la voiture
  Widget _buildDescription(double screenWidth) {
    return Text(
      widget.description ??
          'La Tesla Model 3 est une berline électrique de taille moyenne, reconnue pour ses performances impressionnantes, son accélération et son autonomie.',
      style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
    );
  }

  List<Widget> _buildAllSpecCards() {
    String val(String? v) =>
        (v != null && v.trim().isNotEmpty) ? v.trim() : 'Non renseigné';

    final cards = <Widget>[
      _buildSpecCard('Type de moto', val(widget.typeMoto), Icons.motorcycle),
      _buildSpecCard('Cylindrée', val(widget.cylindre), Icons.speed),
      _buildSpecCard('Type moteur', val(widget.typeMoteur), Icons.local_gas_station),
      _buildSpecCard('Puissance', val(widget.puissance), Icons.bolt),
      _buildSpecCard('Transmission', val(widget.transmission ?? widget.boiteVitesse), Icons.settings),
      _buildSpecCard('Démarrage', val(widget.demarrage), Icons.power_settings_new),
      _buildSpecCard('Refroidissement', val(widget.refroidissement), Icons.ac_unit),
      _buildSpecCard('Réservoir', val(widget.capaciteReservoir), Icons.local_drink),
      if ((widget.typeMoteur ?? '').toLowerCase() == 'électrique')
        _buildSpecCard('Autonomie', val(widget.autonomie), Icons.battery_charging_full),
      _buildSpecCard('Disponibilité', val(widget.disponibilite), Icons.inventory_2),
      _buildSpecCard(
        'Garantie',
        widget.garantieConstructeur == true
            ? (widget.dureeGarantie?.isNotEmpty == true
                ? widget.dureeGarantie!
                : 'Oui')
            : 'Non',
        Icons.verified,
      ),
      _buildSpecCard('Kilométrage', val(widget.kilometrage ?? widget.distance), Icons.speed),
      _buildSpecCard(
        'Localisation',
        () {
          final raw = concatLocationParts(
            location: widget.lieu,
            company: widget.entreprise,
          );
          if (raw.isEmpty) return 'Non renseigné';
          return truncateWithEllipsis(raw);
        }(),
        Icons.location_on,
      ),
    ];

    if (widget.equipements.isNotEmpty) {
      cards.add(
        _buildSpecCard(
          'Équipements',
          widget.equipements.join(', '),
          Icons.checklist,
        ),
      );
    }

    return cards;
  }

  Map<String, dynamic> _motoArticlePayload() {
    return {
      'type': 'moto',
      'titre': widget.titre,
      'description': widget.description,
      'marque': widget.marque,
      'modele': widget.modele,
      'annee': widget.annee,
      'prix': widget.prix,
      'condition': widget.condition ?? 'Nouveau',
      'cylindre': widget.cylindre,
      'lieu': widget.lieu,
      'localisation': widget.lieu,
      if (widget.fournisseur != null) 'fournisseur': widget.fournisseur,
      'photos': widget.images,
      'video': _primaryVideo,
      'entreprise': widget.entreprise,
      if (widget.typeMoto != null) 'typeMoto': widget.typeMoto,
      if (widget.typeMoteur != null) 'typeMoteur': widget.typeMoteur,
      if (widget.puissance != null && widget.puissance!.isNotEmpty)
        'puissance': widget.puissance,
      if (widget.transmission != null) 'transmission': widget.transmission,
      if (widget.demarrage != null) 'demarrage': widget.demarrage,
      if (widget.refroidissement != null) 'refroidissement': widget.refroidissement,
      if (widget.capaciteReservoir != null && widget.capaciteReservoir!.isNotEmpty)
        'capaciteReservoir': widget.capaciteReservoir,
      if (widget.autonomie != null && widget.autonomie!.isNotEmpty)
        'autonomie': widget.autonomie,
      if (widget.disponibilite != null) 'disponibilite': widget.disponibilite,
      'garantieConstructeur': widget.garantieConstructeur ?? false,
      if (widget.dureeGarantie != null && widget.dureeGarantie!.isNotEmpty)
        'dureeGarantie': widget.dureeGarantie,
      if (widget.kilometrage != null && widget.kilometrage!.isNotEmpty)
        'kilometrage': widget.kilometrage,
      if (widget.equipements.isNotEmpty) 'equipements': widget.equipements,
      if (widget.devise != null) 'devise': widget.devise,
      if ((widget.alertBuyerId ?? '').isNotEmpty)
        'alertContext': {
          'sourceNotificationId': widget.alertNotificationId,
          'buyerId': widget.alertBuyerId,
          'requestType': widget.alertRequestType ?? 'moto_search',
        },
    };
  }

  Widget _buildSpecGrid(List<Widget> cards) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: cards,
    );
  }

  Widget _buildSpecifications(double screenWidth) {
    final allCards = _buildAllSpecCards();
    final hasMore = allCards.length > 4;
    final visibleCards = (_isSpecsExpanded || !hasMore)
        ? allCards
        : allCards.take(4).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildSpecGrid(visibleCards),
        if (hasMore) ...[
          const SizedBox(height: 8),
          Center(
            child: InkWell(
              onTap: () {
                setState(() {
                  _isSpecsExpanded = !_isSpecsExpanded;
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isSpecsExpanded ? 'Voir moins' : 'Voir plus',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1B2B4B),
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _isSpecsExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: Color(0xFF1B2B4B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Map des couleurs
  final Map<String, Color> _couleurs = {
    'Blanc': Colors.white,
    'Noir': Colors.black,
    'Gris': Colors.grey,
    'Argenté': const Color(0xFFC0C0C0),
    'Rouge': Colors.red,
    'Bleu': Colors.blue,
    'Vert': Colors.green,
    'Jaune': Colors.yellow,
    'Orange': Colors.orange,
    'Violet': Colors.purple,
    'Rose': Colors.pink,
    'Marron': Colors.brown,
    'Beige': const Color(0xFFF5F5DC),
    'Bordeaux': const Color(0xFF800020),
    'Bleu marine': const Color(0xFF000080),
    'Vert foncé': const Color(0xFF006400),
    'Gris foncé': const Color(0xFF696969),
    'Gris clair': const Color(0xFFD3D3D3),
    'Rouge foncé': const Color(0xFF8B0000),
    'Bleu clair': const Color(0xFFADD8E6),
    'Vert clair': const Color(0xFF90EE90),
    'Jaune clair': const Color(0xFFFFFFE0),
    'Orange foncé': const Color(0xFFFF8C00),
    'Violet foncé': const Color(0xFF4B0082),
    'Rose foncé': const Color(0xFFC71585),
    'Marron clair': const Color(0xFFD2B48C),
    'Crème': const Color(0xFFFFFDD0),
    'Ivoire': const Color(0xFFFFFFF0),
    'Champagne': const Color(0xFFF7E7CE),
    'Bronze': const Color(0xFFCD7F32),
    'Doré': const Color(0xFFFFD700),
    'Cuivre': const Color(0xFFB87333),
    'Turquoise': const Color(0xFF40E0D0),
    'Cyan': const Color(0xFF00FFFF),
    'Magenta': const Color(0xFFFF00FF),
    'Lime': const Color(0xFF00FF00),
    'Indigo': const Color(0xFF4B0082),
    'Olive': const Color(0xFF808000),
    'Saumon': const Color(0xFFFA8072),
    'Corail': const Color(0xFFFF7F50),
    'Pêche': const Color(0xFFFFDAB9),
    'Lavande': const Color(0xFFE6E6FA),
    'Menthe': const Color(0xFF98FB98),
    'Bleu pétrole': const Color(0xFF008B8B),
    'Vert olive': const Color(0xFF6B8E23),
    'Rouge brique': const Color(0xFFB22222),
    'Bleu acier': const Color(0xFF4682B4),
    'Vert forêt': const Color(0xFF228B22),
    'Prune': const Color(0xFFDDA0DD),
    'Kaki': const Color(0xFFF0E68C),
    'Anthracite': const Color(0xFF36454F),
    'Perle': const Color(0xFFEAE0C8),
  };

  // Carte d'information générique pour les spécifications
  Widget _buildSpecCard(String title, String value, IconData icon) {
    return SpecInfoCard(title: title, value: value, icon: icon);
  }

  Widget _buildSpecCardWithColor(
    String title,
    String value,
    IconData icon,
    String? couleur,
  ) {
    Widget? swatch;
    if (couleur != null && _couleurs.containsKey(couleur)) {
      swatch = Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: _couleurs[couleur],
          border: Border.all(
            color: _couleurs[couleur] == Colors.white
                ? Colors.grey
                : Colors.transparent,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
      );
    }
    return SpecInfoCard(
      title: title,
      value: value,
      icon: icon,
      valueTrailing: swatch,
    );
  }

  // Cases à cocher et champs de livraison (ramenés ici)
  bool _isEnConsommationChecked = false;
  bool _isEnTransitChecked = false;
  final TextEditingController _detailsController = TextEditingController();

  Widget _buildCheckboxes(double screenWidth, bool shouldShowDeliveryOptions) {
    if (!shouldShowDeliveryOptions) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: _isEnConsommationChecked,
              onChanged: (v) {
                setState(() {
                  _isEnConsommationChecked = v ?? false;
                  if (_isEnConsommationChecked) _isEnTransitChecked = false;
                });
              },
              activeColor: Colors.black,
            ),
            Text(l10n.inConsumption),
            const SizedBox(width: 16),
            Checkbox(
              value: _isEnTransitChecked,
              onChanged: (v) {
                setState(() {
                  _isEnTransitChecked = v ?? false;
                  if (_isEnTransitChecked) _isEnConsommationChecked = false;
                });
              },
              activeColor: Colors.black,
            ),
            Text(l10n.inTransit),
          ],
        ),
        const SizedBox(height: 12),
        Text(l10n.placeLabel, style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCountry,
              hint: const Text(
                'Choisissez un pays',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              isExpanded: true,
              items: africanCountries
                  .map(
                    (c) => DropdownMenuItem<String>(value: c, child: Text(c)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedCountry = value),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Détails supplémentaires',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _detailsController,
          decoration: InputDecoration(
            hintText: l10n.enterDestinationDetails,
            filled: true,
            fillColor: const Color(0xFFF2F2F2),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  // Bouton d'action dynamique
  Widget _buildActionButton(bool isChauffeur) {
    final userService = UserService();
    final isVendeur = userService.currentRole == UserRole.vendeur;

    if (widget.fromPub == true) {
      // Toujours afficher uniquement le bouton Acheter
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            if (!_isEnConsommationChecked && !_isEnTransitChecked) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Veuillez choisir un mode de livraison (En Consommation ou En Transit).',
                  ),
                ),
              );
              return;
            }
            if (_selectedCountry == null || _selectedCountry!.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.selectLocationPlease)),
              );
              return;
            }
            // Créer l'objet article à partir des propriétés du widget
            final article = {
              '_id': widget.id, // Doit être l'ID Mongo réel
              'titre': widget.titre,
              'description': widget.description,
              'marque': widget.marque,
              'modele': widget.modele,
              'annee': widget.annee,
              'prix': widget.prix,
              'condition': widget.condition,
              'boiteVitesse': widget.boiteVitesse,
              'carburant': widget.carburant,
              'climatiseur': widget.climatiseur,
              'distance': widget.distance,
              'sieges': widget.sieges,
              'portes': widget.portes,
              'cylindre': widget.cylindre,
              'couleur': widget.couleur,
              'dedouanement': widget.dedouanement,
              'photos': widget.images,
              'video': _primaryVideo,
              'entreprise': widget.entreprise,
              'type': 'moto',
              // Pré-sélections pour payement
              'modeLivraison': _isEnTransitChecked ? 'transit' : 'consommation',
              'paysDestination': _selectedCountry,
              'detailsSupplementaires': _detailsController.text.trim(),
            };
            log('[PUB][fromPub] Article payload: $article');
            showDialog(
              context: context,
              builder: (ctx) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  contentPadding: const EdgeInsets.all(20),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/smiley.png',
                        height: 80,
                        width: 80,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Contrôle en cours',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      RichText(
                        textAlign: TextAlign.center,
                        text: const TextSpan(
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            height: 1.5,
                          ),
                          children: [
                            TextSpan(
                              text:
                                  'Les vérifications seront effectuées et vous seront envoyées sous ',
                            ),
                            TextSpan(
                              text: '10 jours',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFFA000),
                              ),
                            ),
                            TextSpan(
                              text: '. Pour démarrer, veuillez payer les ',
                            ),
                            TextSpan(
                              text: 'frais de vérification',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00A86B),
                              ),
                            ),
                            TextSpan(text: '.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _verificationPriceLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00A86B),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VerificationPaymentScreen(
                                  articleId: widget.id.toString(),
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFCC00),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(l10n.payVerificationFees),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Acheter cette moto',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
      );
    }
    if (!isVendeur) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () async {
            final firebaseUser = FirebaseAuth.instance.currentUser;
            if (firebaseUser == null) {
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ConnexionPage(),
                ),
              );
              return;
            }
            await _openWhatsApp(message: _buyWhatsAppMessage(l10n));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Acheter cette moto',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
        children: [
          // Bouton principal "Vendre ma voiture"
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_isOnline || _isPublishing)
                  ? null
                  : () async {
                      setState(() => _isPublishing = true);
                      // Vendeur : enregistre l'article dans la BDD puis redirige vers la page de succès
                      final articleData = _motoArticlePayload();
                      log('[DEBUG] Données envoyées à l\'API :');
                      log(articleData.toString());
                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        final token = await user?.getIdToken();
                        final response = await http.post(
                          Uri.parse(
                            '${UserService().dio.options.baseUrl}/articles/',
                          ),
                          headers: {
                            'Content-Type': 'application/json',
                            if (token != null) 'Authorization': 'Bearer $token',
                          },
                          body: jsonEncode(articleData),
                        );
                        log(
                          '[DEBUG] Status code réponse API : ${response.statusCode}',
                        );
                        log('[DEBUG] Body réponse API : ${response.body}');
                        if (response.statusCode == 201 ||
                            response.statusCode == 200) {
                          if (mounted) setState(() => _isOnline = true);
                          _confettiController.play();
                          await Future.delayed(const Duration(seconds: 2));
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SuccesVenteScreen(),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Erreur lors de l\'enregistrement en BDD',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        log('[DEBUG] Exception lors de l\'appel API : $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.networkOrServerError)),
                        );
                      } finally {
                        if (mounted) {
                          setState(() => _isPublishing = false);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _isOnline ? Colors.grey[300] : Colors.amber,
                foregroundColor: _isOnline ? Colors.grey[600] : Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isPublishing
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      'Vendre ma moto',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          // Bouton "Faire une pub" pour les vendeurs
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                log('[DEBUG] Bouton Faire une pub cliqué');
                _trackDemoEvent('campaign_initiated', page: 'cars_info.dart');
                // Ouvrir la page de demande de pub avec les infos de l'article
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => pub_page.Une(
                      articleId: widget.id, // Utiliser l'ID réel de l'article
                      articleType: 'voiture',
                      isStandalone: false,
                      articleTitle: widget.titre,
                      articleYear: widget.annee,
                      articleLocation: widget.lieu,
                      articlePrice: widget.prix,
                      articleDescription: widget.description,
                      articleCompany: widget.entreprise,
                      articleModel: widget.modele,
                      articleFuelType: widget.carburant,
                      articlePieceType: widget.condition,
                      articleImages: widget.images,
                      articleVideo: _primaryVideo,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Boostez vos ventes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            emissionFrequency: 0.05,
            numberOfParticles: 30,
            maxBlastForce: 20,
            minBlastForce: 8,
            gravity: 0.3,
          ),
        ],
      );
  }
}

Future<void> _trackDemoEvent(String eventType, {String? page}) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final token = await user.getIdToken();
    log('[DEMO_EVENT] send $eventType page=$page');
    final dio = Dio(
      BaseOptions(
        baseUrl: UserService().dio.options.baseUrl,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );
    final resp = await dio.post('/demo-events/track', data: {
      'eventType': eventType,
      'page': page,
      'client': 'mobile',
    });
    log('[DEMO_EVENT] resp status=${resp.statusCode} data=${resp.data}');
  } catch (_) {
    // best-effort tracking
  }
}
