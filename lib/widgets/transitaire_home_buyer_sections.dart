import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:tranoo_pro/data/screens/cars_info.dart';
import 'package:tranoo_pro/data/screens/marque.dart' show Pub, ArticleVoiture;
import 'package:tranoo_pro/data/screens/moto_info.dart';
import 'package:tranoo_pro/data/screens/motos.dart';
import 'package:tranoo_pro/data/screens/voitures.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';
import 'package:tranoo_pro/services/user_service.dart';
import 'package:tranoo_pro/utils/article_list_sort.dart';
import 'package:tranoo_pro/widgets/catalog_article_grid_card.dart';
import 'package:tranoo_pro/widgets/skeleton/app_skeleton.dart';
import 'package:url_launcher/url_launcher.dart';

bool _isPubValid(Pub pub) {
  if (pub.statut != 'valide') return false;
  final now = DateTime.now();
  if (pub.dateFin != null) return now.isBefore(pub.dateFin!);
  final dateDebut = pub.dateDebut ?? pub.dateDemande;
  int dureeJours;
  switch (pub.duree.toLowerCase()) {
    case '1 semaine':
      dureeJours = 7;
      break;
    case '2 semaines':
      dureeJours = 14;
      break;
    case '1 mois':
      dureeJours = 30;
      break;
    case '2 mois':
      dureeJours = 60;
      break;
    case '3 mois':
      dureeJours = 90;
      break;
    default:
      dureeJours = 7;
  }
  return now.isBefore(dateDebut.add(Duration(days: dureeJours)));
}

/// Sections marché identiques à l'accueil acheteur (`Marque` dans tranoo).
class TransitaireHomeBuyerSections extends StatefulWidget {
  /// Contenu inséré entre les pubs à la une et les véhicules (galerie, profil…).
  final List<Widget> insertAfterPubs;

  const TransitaireHomeBuyerSections({
    super.key,
    this.insertAfterPubs = const [],
  });

  @override
  State<TransitaireHomeBuyerSections> createState() =>
      TransitaireHomeBuyerSectionsState();
}

class TransitaireHomeBuyerSectionsState
    extends State<TransitaireHomeBuyerSections> {
  Future<void> reload() => _loadAll();
  late final PageController _pageController;
  Timer? _carouselTimer;
  int _currentPage = 0;

  List<Pub> _pubsALaUne = [];
  List<ArticleVoiture> _voitures = [];
  List<ArticleVoiture> _motos = [];
  bool _loadingPubs = true;
  bool _loadingVoitures = true;
  bool _loadingMotos = true;
  String? _errorPubs;
  String? _errorVoitures;
  String? _errorMotos;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: 0,
      viewportFraction: 0.85,
    );
    _loadAll();
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_fetchPubs(), _fetchVoitures(), _fetchMotos()]);
  }

  Future<void> _fetchPubs() async {
    setState(() {
      _loadingPubs = true;
      _errorPubs = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (idToken != null) headers['Authorization'] = 'Bearer $idToken';

      final response = await http.get(
        Uri.parse('${getBaseUrl()}/public/publicites?statut=valide'),
        headers: headers,
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        final pubs = data.map((e) => Pub.fromJson(e)).toList();
        setState(() {
          _pubsALaUne = pubs
              .where((p) => p.typePub == 'À la une' && _isPubValid(p))
              .toList();
          _loadingPubs = false;
        });
        if (_pubsALaUne.isNotEmpty) _startCarouselTimer();
      } else {
        setState(() {
          _errorPubs = 'Erreur lors du chargement des publicités';
          _loadingPubs = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorPubs = 'Erreur réseau';
        _loadingPubs = false;
      });
    }
  }

  Future<void> _fetchVoitures() async {
    setState(() {
      _loadingVoitures = true;
      _errorVoitures = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      final response = await http.get(
        Uri.parse(
          '${getBaseUrl()}/articles?type=voiture&statut=en_ligne&vendu=false',
        ),
        headers: {
          if (idToken != null) 'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = sortArticleMapsNewestFirst(
          json.decode(response.body) as List<dynamic>,
        );
        setState(() {
          _voitures = data
              .map((e) => ArticleVoiture.fromJson(e))
              .where((v) => (v.statut ?? 'en_ligne') != 'vendu')
              .toList();
          _loadingVoitures = false;
        });
      } else {
        setState(() {
          _errorVoitures = 'Erreur lors du chargement des voitures';
          _loadingVoitures = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorVoitures = 'Erreur réseau';
        _loadingVoitures = false;
      });
    }
  }

  Future<void> _fetchMotos() async {
    setState(() {
      _loadingMotos = true;
      _errorMotos = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      final response = await http.get(
        Uri.parse(
          '${getBaseUrl()}/articles?type=moto&statut=en_ligne&vendu=false',
        ),
        headers: {
          if (idToken != null) 'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = sortArticleMapsNewestFirst(
          json.decode(response.body) as List<dynamic>,
        );
        setState(() {
          _motos = data
              .map((e) => ArticleVoiture.fromJson(e))
              .where((m) => (m.statut ?? 'en_ligne') != 'vendu')
              .toList();
          _loadingMotos = false;
        });
      } else {
        setState(() {
          _errorMotos = 'Erreur lors du chargement des motos';
          _loadingMotos = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMotos = 'Erreur réseau';
        _loadingMotos = false;
      });
    }
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _pubsALaUne.isEmpty) return;
      if (_currentPage < _pubsALaUne.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _openPubLink(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    final normalized =
        trimmed.startsWith('http://') || trimmed.startsWith('https://')
            ? trimmed
            : 'https://$trimmed';
    final uri = Uri.tryParse(normalized);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openFlyerPreview(String imageUrl) {
    if (imageUrl.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPubsALaUneCarousel() {
    if (_loadingPubs) {
      return SkeletonPresets.articleGrid(count: 2);
    }
    if (_errorPubs != null) {
      return Center(child: Text(_errorPubs!));
    }
    if (_pubsALaUne.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        Container(
          height: 200,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: PageView.builder(
            controller: _pageController,
            padEnds: true,
            itemCount: _pubsALaUne.length,
            itemBuilder: (context, index) {
              final pub = _pubsALaUne[index];
              final hasLink = (pub.lien ?? '').trim().isNotEmpty;
              final card = Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    height: 180,
                    color: Colors.black,
                    child: pub.media.isNotEmpty
                        ? Image.network(
                            pub.media[0],
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.image_not_supported,
                                size: 60,
                                color: Colors.black54,
                              ),
                            ),
                          )
                        : Container(
                            height: 180,
                            color: Colors.grey[300],
                            child: const Icon(Icons.image, size: 80),
                          ),
                  ),
                ),
              );
              return GestureDetector(
                onTap: () {
                  if (hasLink) {
                    _openPubLink(pub.lien!.trim());
                  } else {
                    _openFlyerPreview(
                      pub.media.isNotEmpty ? pub.media[0] : '',
                    );
                  }
                },
                onDoubleTap: () {
                  if (hasLink) {
                    _openFlyerPreview(
                      pub.media.isNotEmpty ? pub.media[0] : '',
                    );
                  }
                },
                child: card,
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        if (_pubsALaUne.length > 1)
          SmoothPageIndicator(
            controller: _pageController,
            count: _pubsALaUne.length,
            effect: JumpingDotEffect(
              activeDotColor: Color(0xFFF8BF13),
              dotColor: Colors.grey.shade300,
              dotHeight: 8,
              dotWidth: 8,
            ),
          ),
      ],
    );
  }

  Widget _buildVoituresHorizontalList(List<ArticleVoiture> voitures) {
    final l10n = AppLocalizations.of(context)!;
    final cardWidth = MediaQuery.of(context).size.width * 0.44;
    final cardHeight =
        cardWidth / CatalogArticleGridCard.aspectRatioForWidth(cardWidth * 2.2);
    return SizedBox(
      height: cardHeight + 4,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: voitures.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final voiture = voitures[index];
          return CatalogArticleGridCard(
            article: voiture.toArticleMap(),
            isMoto: false,
            width: cardWidth,
            conditionNewLabel: l10n.conditionNew,
            conditionUsedLabel: l10n.usedCondition,
            defaultTransmission: l10n.automaticTransmission,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CarsInfo(
                    id: voiture.id,
                    titre: voiture.titre,
                    description: voiture.description,
                    marque: voiture.marque,
                    modele: voiture.modele,
                    annee: voiture.annee,
                    prix: voiture.prix,
                    condition: voiture.condition,
                    boiteVitesse: voiture.boiteVitesse,
                    carburant: voiture.carburant,
                    climatiseur: voiture.climatiseur,
                    distance: voiture.distance,
                    sieges: voiture.sieges,
                    portes: voiture.portes,
                    cylindre: voiture.cylindre,
                    images: voiture.images,
                    video: voiture.video,
                    entreprise: voiture.entreprise,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMotosHorizontalList(List<ArticleVoiture> motos) {
    final l10n = AppLocalizations.of(context)!;
    final cardWidth = MediaQuery.of(context).size.width * 0.44;
    final cardHeight =
        cardWidth / CatalogArticleGridCard.aspectRatioForWidth(cardWidth * 2.2);
    return SizedBox(
      height: cardHeight + 4,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: motos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final moto = motos[index];
          return CatalogArticleGridCard(
            article: moto.toArticleMap(),
            isMoto: true,
            width: cardWidth,
            conditionNewLabel: l10n.conditionNew,
            conditionUsedLabel: l10n.usedCondition,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MotoInfo.fromArticleMap(moto.toArticleMap()),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildVoituresSection() {
    final l10n = AppLocalizations.of(context)!;
    final voituresEnLigne = _voitures
        .where(
          (v) =>
              (v.statut ?? 'en_ligne') == 'en_ligne' &&
              (v.statut ?? '') != 'vendu',
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Véhicules',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF040415),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VoituresPage()),
                  );
                },
                child: Text(
                  l10n.seeAll,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
        if (_loadingVoitures && _voitures.isEmpty)
          SkeletonPresets.articleGrid(count: 2),
        if (_errorVoitures != null) Center(child: Text(_errorVoitures!)),
        if (!_loadingVoitures && _errorVoitures == null)
          voituresEnLigne.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Aucune voiture disponible pour le moment.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                )
              : _buildVoituresHorizontalList(voituresEnLigne),
      ],
    );
  }

  Widget _buildMotosSection() {
    final l10n = AppLocalizations.of(context)!;
    final motosEnLigne = _motos
        .where(
          (m) =>
              (m.statut ?? 'en_ligne') == 'en_ligne' &&
              (m.statut ?? '') != 'vendu',
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Motos',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF040415),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MotosPage()),
                  );
                },
                child: Text(
                  l10n.seeAll,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
        if (_loadingMotos && _motos.isEmpty)
          SkeletonPresets.articleGrid(count: 2),
        if (_errorMotos != null) Center(child: Text(_errorMotos!)),
        if (!_loadingMotos && _errorMotos == null)
          motosEnLigne.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Aucune moto disponible pour le moment.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                )
              : _buildMotosHorizontalList(motosEnLigne),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildPubsALaUneCarousel(),
        ...widget.insertAfterPubs,
        _buildVoituresSection(),
        _buildMotosSection(),
      ],
    );
  }
}
