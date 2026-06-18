import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:tranoo_pro/data/screens/cars_info.dart';
import 'package:tranoo_pro/data/screens/voitures.dart';
import 'package:tranoo_pro/data/screens/motos.dart';
import 'package:tranoo_pro/data/screens/moto_info.dart';
import 'package:tranoo_pro/data/screens/piece.dart';
import 'package:tranoo_pro/data/screens/mastervacpage.dart';
import 'package:tranoo_pro/utils/role_redirect.dart';
import 'package:tranoo_pro/services/user_service.dart';
import 'package:tranoo_pro/data/screens/transit.dart';
import 'package:logging/logging.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tranoo_pro/utils/article_list_sort.dart';
import 'package:tranoo_pro/widgets/video_preview_placeholder.dart';
import 'package:tranoo_pro/services/views_service.dart';
import 'package:tranoo_pro/utils/page_refresh_registry.dart';
import 'package:tranoo_pro/widgets/skeleton/app_skeleton.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';
import 'package:tranoo_pro/widgets/catalog_article_grid_card.dart';
import 'package:tranoo_pro/utils/catalog_filter_options.dart';
import 'package:tranoo_pro/widgets/catalog_filter_sections.dart';
import 'package:tranoo_pro/widgets/seller_stats_dashboard.dart';
import 'package:tranoo_pro/data/screens/seller_subscription_page.dart';

// Fonction utilitaire pour formater les prix avec des séparateurs de milliers
String formatPrice(dynamic price) {
  if (price == null) return '0';
  try {
    final priceNum = double.tryParse(price.toString()) ?? 0;
    final priceStr = priceNum.toStringAsFixed(0);
    final reversed = priceStr.split('').reversed.join('');
    final withDots = reversed.replaceAllMapped(
      RegExp(r'(\d{3})(?=\d)'),
      (Match m) => '${m[0]}.',
    );
    return withDots.split('').reversed.join('');
  } catch (e) {
    return price.toString();
  }
}

String _formatCompactCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(2)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(2)}k';
  return '$n';
}

class Article {
  final String id;
  final String title;
  final String year;
  final String description;
  final String company;
  final String location;
  final String price;
  final List<String> images;
  final String? fuelType;
  final String? model;
  final String? pieceType;
  final String? video;
  final String? condition;
  final String? statut;
  final int views;

  Article({
    required this.id,
    required this.title,
    required this.year,
    required this.description,
    required this.company,
    required this.location,
    required this.price,
    required this.images,
    this.fuelType,
    this.model,
    this.pieceType,
    this.video,
    this.condition,
    this.statut,
    this.views = 0,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['_id'] ?? '',
      title: json['titre'] ?? '',
      year: json['annee'] ?? '',
      description: json['description'] ?? '',
      company: json['entreprise'] ?? '',
      location: json['localisation'] ?? '',
      price: json['prix']?.toString() ?? '',
      images:
          (json['photos'] as List?)?.map((e) => e.toString()).toList() ?? [],
      fuelType: json['typeMoteur'],
      model: json['modele']?.toString(),
      pieceType: json['pieceType'],
      video: json['video'],
      condition: json['condition'],
      statut: json['statut'],
      views: (json['views'] as num?)?.toInt() ?? 0,
    );
  }
}

class ArticleVoiture {
  final String id;
  final String titre;
  final String description;
  final String marque;
  final String modele;
  final String annee;
  final String prix;
  final String? condition;
  final String? boiteVitesse;
  final String? carburant;
  final String? climatiseur;
  final String? distance;
  final String? sieges;
  final String? portes;
  final String? cylindre;
  final List<String> images;
  final String? video;
  final String? entreprise;
  final String? statut;
  final int views;
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

  ArticleVoiture({
    required this.id,
    required this.titre,
    required this.description,
    required this.marque,
    required this.modele,
    required this.annee,
    required this.prix,
    this.condition,
    this.boiteVitesse,
    this.carburant,
    this.climatiseur,
    this.distance,
    this.sieges,
    this.portes,
    this.cylindre,
    required this.images,
    this.video,
    this.entreprise,
    this.statut,
    this.views = 0,
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

  Map<String, dynamic> toArticleMap() => {
        '_id': id,
        'titre': titre,
        'description': description,
        'marque': marque,
        'modele': modele,
        'annee': annee,
        'prix': prix,
        'condition': condition,
        'boiteVitesse': boiteVitesse,
        'carburant': carburant,
        'cylindre': cylindre,
        'distance': distance,
        'portes': portes,
        'photos': images,
        'video': video,
        'entreprise': entreprise,
        'statut': statut,
        'views': views,
        if (typeMoto != null) 'typeMoto': typeMoto,
        if (typeMoteur != null) 'typeMoteur': typeMoteur,
        if (puissance != null) 'puissance': puissance,
        if (transmission != null) 'transmission': transmission,
        if (demarrage != null) 'demarrage': demarrage,
        if (refroidissement != null) 'refroidissement': refroidissement,
        if (capaciteReservoir != null) 'capaciteReservoir': capaciteReservoir,
        if (autonomie != null) 'autonomie': autonomie,
        if (disponibilite != null) 'disponibilite': disponibilite,
        'garantieConstructeur': garantieConstructeur ?? false,
        if (dureeGarantie != null) 'dureeGarantie': dureeGarantie,
        if (kilometrage != null) 'kilometrage': kilometrage,
        if (equipements.isNotEmpty) 'equipements': equipements,
        if (devise != null) 'devise': devise,
      };

  factory ArticleVoiture.fromJson(Map<String, dynamic> json) {
    return ArticleVoiture(
      id: json['_id'] ?? '',
      titre: json['titre'] ?? '',
      description: json['description'] ?? '',
      marque: json['marque'] ?? '',
      modele: json['modele']?.toString() ?? '',
      annee: json['annee'] ?? '',
      prix: json['prix']?.toString() ?? '',
      condition: json['condition'],
      boiteVitesse: json['boiteVitesse'],
      carburant: json['carburant'],
      climatiseur: json['climatiseur'],
      distance: json['distance'],
      sieges: json['sieges'],
      portes: json['portes'],
      cylindre: json['cylindre'],
      images:
          (json['photos'] as List?)?.map((e) => e.toString()).toList() ?? [],
      video: json['video'],
      entreprise: json['entreprise'],
      statut: json['statut'],
      views: (json['views'] as num?)?.toInt() ?? 0,
      typeMoto: json['typeMoto']?.toString(),
      typeMoteur: json['typeMoteur']?.toString(),
      puissance: json['puissance']?.toString(),
      transmission: json['transmission']?.toString(),
      demarrage: json['demarrage']?.toString(),
      refroidissement: json['refroidissement']?.toString(),
      capaciteReservoir: json['capaciteReservoir']?.toString(),
      autonomie: json['autonomie']?.toString(),
      disponibilite: json['disponibilite']?.toString(),
      garantieConstructeur: json['garantieConstructeur'] == true,
      dureeGarantie: json['dureeGarantie']?.toString(),
      kilometrage: (json['kilometrage'] ?? json['distance'])?.toString(),
      equipements: (json['equipements'] as List?)
              ?.map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const [],
      devise: json['devise']?.toString(),
    );
  }
}

List<ArticleVoiture> voituresRecommandees = [];
bool isLoadingVoitures = true;
String? errorVoitures;

List<ArticleVoiture> motosRecommandees = [];
bool isLoadingMotos = true;
String? errorMotos;

// Ajout : modèle Pub pour la récupération des publicités
class Pub {
  final String id;
  final String? articleId;
  final String description;
  final String typePub;
  final String statut;
  final String duree;
  final DateTime dateDemande;
  final DateTime? dateDebut;
  final DateTime? dateFin;
  final List<String> media;
  final String? lien;

  Pub({
    required this.id,
    this.articleId,
    required this.description,
    required this.typePub,
    required this.statut,
    required this.duree,
    required this.dateDemande,
    this.dateDebut,
    this.dateFin,
    required this.media,
    this.lien,
  });

  factory Pub.fromJson(Map<String, dynamic> json) {
    final dynamic rawArticleId = json['articleId'];
    final String? parsedArticleId = rawArticleId is Map<String, dynamic>
        ? rawArticleId['_id']?.toString()
        : rawArticleId?.toString();
    return Pub(
      id: json['_id'] ?? '',
      articleId: parsedArticleId,
      description: json['description'] ?? '',
      typePub: json['typePub'] ?? '',
      statut: json['statut'] ?? '',
      duree: json['duree'] ?? '',
      dateDemande:
          DateTime.tryParse(json['dateDemande'] ?? '') ?? DateTime.now(),
      dateDebut: DateTime.tryParse(json['dateDebut'] ?? ''),
      dateFin: DateTime.tryParse(json['dateFin'] ?? ''),
      media: (json['media'] as List?)?.map((e) => e.toString()).toList() ?? [],
      lien: json['lien'],
    );
  }
}

class Marque extends StatefulWidget {
  const Marque({super.key});

  @override
  State<Marque> createState() => _MarqueState();
}

class _MarqueState extends State<Marque>
    with SingleTickerProviderStateMixin, RegisterPageRefresh {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  bool _pullRefreshing = false;

  @override
  Future<void> onPagePullRefresh() async {
    setState(() => _pullRefreshing = true);
    try {
      await fetchArticlesPieces();
      await fetchVoituresRecommandees();
      await fetchPubs();
      await fetchPubsSponsorisees();
      if (_userService.currentRole == UserRole.vendeur) {
        await _loadSellerMarqueStats();
      }
    } finally {
      if (mounted) setState(() => _pullRefreshing = false);
    }
  }
  int _currentPage = 0;
  late PageController _pageController;
  late TabController _tabController;
  Timer? _carouselTimer;
  final UserService _userService = UserService();
  late int _marqueTabIndex;
  late int _typeTabIndex;
  late int _statusOnlineTabIndex;
  late int _statusRejectedTabIndex;
  late int _enAttenteTabIndex;
  late int _statistiquesTabIndex;
  late int _localisationTabIndex;
  late int _budgetTabIndex;
  List<ArticleVoiture> _voituresEnAttente = [];
  bool _isLoadingEnAttente = true;
  String? _errorEnAttente;
  List<Article> articlesPieces = [];
  bool isLoadingPieces = true;
  String? errorPieces;
  List<Pub> pubsSponsorisees = [];
  List<Pub> pubsALaUne = [];
  bool isLoadingPubs = true;
  String? errorPubs;

  // Ajout d'un contrôleur et d'une variable pour la recherche
  final TextEditingController _searchPieceController = TextEditingController();
  String _searchPieceText = '';

  // Variables pour les filtres
  String? _selectedBrand;
  String? _selectedType;
  String? _selectedModel;
  String? _selectedMotoBrand;
  String? _selectedLocation;
  double? _budgetMin;
  double? _budgetMax;

  // Variables pour les statistiques
  Map<String, int> _vehicleClickCounts = {};
  Map<String, int> _pieceClickCounts = {};

  /// Vues globales par article (`Article.views`, API `/views`).
  Map<String, int> _backendViews = {};
  final ViewsService _viewsService = ViewsService();

  // Stats vendeur (API `/protected/stats/seller-marque`)
  bool _sellerMarqueStatsLoading = false;
  int _statsTotalRevenueFcfa = 0;
  int _statsVenteSuccessCount = 0;
  int _statsVehiclesOnline = 0;
  int _statsPiecesOnline = 0;
  int _statsVehiclesSold = 0;
  int _statsPiecesSold = 0;
  String? _statsVendeurType;
  bool _revenueAmountVisible = false;

  final _logger = Logger('MarquePage');

  // Méthodes pour les statistiques
  Future<void> _loadVehicleClickStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      final response = await http.get(
        Uri.parse('${getBaseUrl()}/stats/vehicle-clicks'),
        headers: {
          'Content-Type': 'application/json',
          if (idToken != null) 'Authorization': 'Bearer $idToken',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          _vehicleClickCounts = Map<String, int>.from(data['clicks'] ?? {});
        });
      }
    } catch (e) {
      _logger.severe('[ERROR] 💥 Erreur _loadVehicleClickStats: $e');
    }
  }

  Future<void> _saveVehicleClickStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      final response = await http.post(
        Uri.parse('${getBaseUrl()}/stats/vehicle-clicks'),
        headers: {
          'Content-Type': 'application/json',
          if (idToken != null) 'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'clicks': _vehicleClickCounts}),
      );
      
      if (response.statusCode != 200) {
        _logger.warning('[STATS] Impossible de sauvegarder les clics: ${response.statusCode}');
      }
    } catch (e) {
      _logger.warning('[STATS] Impossible de sauvegarder les clics: $e');
    }
  }

  Future<void> _loadPieceClickStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      final response = await http.get(
        Uri.parse('${getBaseUrl()}/stats/piece-clicks'),
        headers: {
          'Content-Type': 'application/json',
          if (idToken != null) 'Authorization': 'Bearer $idToken',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          _pieceClickCounts = Map<String, int>.from(data['clicks'] ?? {});
        });
      }
    } catch (e) {
      _logger.severe('[ERROR] 💥 Erreur _loadPieceClickStats: $e');
    }
  }

  Future<void> _recordVehicleClick(String vehicleId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      await http.post(
        Uri.parse('${getBaseUrl()}/stats/record-vehicle-click'),
        headers: {
          'Content-Type': 'application/json',
          if (idToken != null) 'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'vehicleId': vehicleId}),
      );
      
      setState(() {
        _vehicleClickCounts[vehicleId] = (_vehicleClickCounts[vehicleId] ?? 0) + 1;
      });
    } catch (e) {
      _logger.severe('[ERROR] 💥 Erreur _recordVehicleClick: $e');
    }
  }

  Future<void> _recordPieceClick(String pieceId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      await http.post(
        Uri.parse('${getBaseUrl()}/stats/record-piece-click'),
        headers: {
          'Content-Type': 'application/json',
          if (idToken != null) 'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'pieceId': pieceId}),
      );
      
      setState(() {
        _pieceClickCounts[pieceId] = (_pieceClickCounts[pieceId] ?? 0) + 1;
      });
    } catch (e) {
      _logger.severe('[ERROR] 💥 Erreur _recordPieceClick: $e');
    }
  }

  
  
  
  
  
  
  
  
  // Vérifie si une publicité est encore valide selon sa durée
  bool _isPubValid(Pub pub) {
    _logger.info('[DEBUG] 🔍 Vérification pub ${pub.id}: statut=${pub.statut}');

    if (pub.statut != 'valide') {
      _logger.info('[DEBUG] 🔍 Pub ${pub.id} rejetée: statut=${pub.statut}');
      return false;
    }

    final now = DateTime.now();

    // Utiliser dateFin si disponible, sinon calculer à partir de dateDebut ou dateDemande
    if (pub.dateFin != null) {
      final isValid = now.isBefore(pub.dateFin!);
      _logger.info(
        '[DEBUG] 🔍 Pub ${pub.id} avec dateFin: ${pub.dateFin}, maintenant: $now, valide: $isValid',
      );
      return isValid;
    }

    final dateDebut = pub.dateDebut ?? pub.dateDemande;
    _logger.info(
      '[DEBUG] 🔍 Pub ${pub.id} sans dateFin, utilise dateDebut: $dateDebut',
    );

    // Conversion de la durée en jours
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
        dureeJours = 7; // Par défaut 1 semaine
    }

    final dateFin = dateDebut.add(Duration(days: dureeJours));
    final isValid = now.isBefore(dateFin);
    _logger.info(
      '[DEBUG] 🔍 Pub ${pub.id} calculée: dateDebut=$dateDebut, durée=${pub.duree} ($dureeJours jours), dateFin=$dateFin, valide=$isValid',
    );
    return isValid;
  }

  
  @override
  void initState() {
    super.initState();

    // Initialisation des indices des onglets selon le rôle
    final isTransitaire = _userService.currentRole == UserRole.transitaire;
    final isVendeur = _userService.currentRole == UserRole.vendeur;
    if (isVendeur) {
      _marqueTabIndex = isTransitaire ? 1 : 0;
      _statusOnlineTabIndex = isTransitaire ? 2 : 1;
      _statusRejectedTabIndex = isTransitaire ? 3 : 2;
      _statistiquesTabIndex = isTransitaire ? 4 : 3;
      _tabController =
          TabController(length: isTransitaire ? 5 : 4, vsync: this);
    } else {
      _typeTabIndex = isTransitaire ? 1 : 0;
      _marqueTabIndex = isTransitaire ? 2 : 1;
      _localisationTabIndex = isTransitaire ? 3 : 2;
      _budgetTabIndex = isTransitaire ? 4 : 3;
      _tabController =
          TabController(length: isTransitaire ? 5 : 4, vsync: this);
    }

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging &&
          _userService.currentRole == UserRole.vendeur &&
          _tabController.index == _statistiquesTabIndex) {
        _loadSellerMarqueStats();
      }
      setState(() {});
    });

    _pageController = PageController(
      initialPage: 0,
      viewportFraction: 0.85,  // Pour voir les pubs adjacentes
    );

    // Configuration du carrousel automatique
    _startCarouselTimer();
    fetchArticlesPieces();
    fetchVoituresRecommandees();
    fetchMotosRecommandees();
    fetchPubs();
    fetchPubsSponsorisees();
    _loadVehicleClickStats();
    if (_userService.currentRole == UserRole.vendeur) {
      _loadSellerMarqueStats();
    }
  }

  Future<void> _loadSellerMarqueStats() async {
    if (_userService.currentRole != UserRole.vendeur) return;
    setState(() {
      _sellerMarqueStatsLoading = true;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      final uri = Uri.parse('${getBaseUrl()}/protected/stats/seller-marque');
      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              if (idToken != null) 'Authorization': 'Bearer $idToken',
            },
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        _logger.warning(
          '[SELLER_STATS] HTTP ${response.statusCode} body=${response.body}',
        );
        if (!mounted) return;
        setState(() {
          _sellerMarqueStatsLoading = false;
        });
        return;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _statsVendeurType = data['vendeurType']?.toString();
        _statsTotalRevenueFcfa =
            (data['totalRevenueFcfa'] as num?)?.round() ?? 0;
        _statsVenteSuccessCount =
            (data['venteSuccessCount'] as num?)?.round() ?? 0;
        _statsVehiclesOnline =
            (data['vehiclesOnline'] as num?)?.round() ?? 0;
        _statsPiecesOnline = (data['piecesOnline'] as num?)?.round() ?? 0;
        _statsVehiclesSold =
            (data['vehiclesSold'] as num?)?.round() ?? 0;
        _statsPiecesSold = (data['piecesSold'] as num?)?.round() ?? 0;
        _sellerMarqueStatsLoading = false;
      });
    } catch (e) {
      _logger.warning('[SELLER_STATS] $e');
      if (!mounted) return;
      setState(() {
        _sellerMarqueStatsLoading = false;
      });
    }
  }

  void _reloadAll() {
    // Réinitialiser les filtres
    _selectedBrand = null;
    _selectedModel = null;
    _selectedMotoBrand = null;
    _selectedLocation = null;
    _budgetMin = null;
    _budgetMax = null;

    // Recharger les données
    fetchArticlesPieces();
    fetchVoituresRecommandees();
    fetchMotosRecommandees();
    fetchPubs();
    fetchPubsSponsorisees();
    if (_userService.currentRole == UserRole.vendeur) {
      _loadSellerMarqueStats();
    }
    setState(() {});
  }

  Future<void> fetchArticlesPieces() async {
    setState(() {
      isLoadingPieces = true;
      errorPieces = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      final isVendeur = _userService.currentRole == UserRole.vendeur;
      String url = isVendeur
          ? getBaseUrl() + '/articles?type=piece&vendu=false'
          : getBaseUrl() + '/articles?type=piece&statut=en_ligne&vendu=false';
      _logger.info('[DEBUG] URL pièces: $url');
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (idToken != null && idToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $idToken';
      }
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final body = response.body;
        try {
          final List<dynamic> data = sortArticleMapsNewestFirst(
            json.decode(body) as List<dynamic>,
          );
          if (!mounted) return;
          final allPieces = data.map((e) => Article.fromJson(e)).toList();
          final piecesFiltered = allPieces
              .where((p) => (p.statut ?? 'en_ligne') != 'vendu')
              .toList();

          _logger.info('[DEBUG] Total pièces reçues: ${allPieces.length}');
          _logger.info(
            '[DEBUG] Pièces après filtrage vendu: ${piecesFiltered.length}',
          );

          // Log des statuts pour déboguer
          for (var p in allPieces) {
            if ((p.statut ?? 'en_ligne') == 'vendu') {
              _logger.info(
                '[DEBUG] Pièce vendue trouvée: ${p.title} - Statut: ${p.statut}',
              );
            }
          }

          setState(() {
            articlesPieces = piecesFiltered;
            for (final p in piecesFiltered) {
              _backendViews[p.id] = p.views;
            }
            isLoadingPieces = false;
          });
          _loadBackendViews();
        } catch (e) {
          _logger.info('[DEBUG] Erreur de décodage JSON: $e');
          if (!mounted) return;
          setState(() {
            errorPieces = 'Erreur de format de données';
            isLoadingPieces = false;
          });
        }
      } else {
        _logger.info(
          '[DEBUG] HTTP pièces ${response.statusCode}: ${response.body}',
        );
        if (!mounted) return;
        setState(() {
          errorPieces = 'Erreur lors du chargement des pièces';
          isLoadingPieces = false;
        });
      }
    } catch (e) {
      _logger.info('[DEBUG] Exception fetchArticlesPieces: $e');
      if (!mounted) return;
      setState(() {
        errorPieces = 'Erreur réseau';
        isLoadingPieces = false;
      });
    }
  }

  
  void _recordVehicleInteraction(String articleId) async {
    if (articleId.isEmpty) return;

    setState(() {
      _backendViews[articleId] = (_backendViews[articleId] ?? 0) + 1;
    });

    try {
      await _viewsService.recordView(articleId);
      final viewsData = await _viewsService.getArticleViews(articleId);
      if (viewsData != null && viewsData['success'] == true && mounted) {
        setState(() {
          _backendViews[articleId] =
              (viewsData['views'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (e) {
      _logger.warning('[VIEWS] Erreur enregistrement vue backend: $e');
    }
  }

  Future<void> _loadBackendViews() async {
    try {
      final ids = <String>{
        ...voituresRecommandees.map((e) => e.id).where((e) => e.isNotEmpty),
        ...articlesPieces.map((e) => e.id).where((e) => e.isNotEmpty),
      }.toList();
      if (ids.isEmpty) return;

      final nextViews = Map<String, int>.from(_backendViews);
      for (final id in ids) {
        final viewsData = await _viewsService.getArticleViews(id);
        if (viewsData != null && viewsData['success'] == true) {
          nextViews[id] = (viewsData['views'] as num?)?.toInt() ??
              (nextViews[id] ?? 0);
        }
      }
      if (!mounted) return;
      setState(() {
        _backendViews = nextViews;
      });
    } catch (e) {
      _logger.warning('[VIEWS] Erreur chargement vues backend: $e');
    }
  }

  Widget _buildViewBadge(String articleId) {
    final views = _backendViews[articleId] ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.remove_red_eye, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            views.toString(),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _catalogMapsForFilters() {
    final maps = <Map<String, dynamic>>[];
    for (final v in voituresRecommandees) {
      maps.add({
        'marque': v.marque,
        'modele': v.modele,
        'prix': v.prix,
        'titre': v.titre,
        'description': v.description,
        'entreprise': v.entreprise,
      });
    }
    for (final p in articlesPieces) {
      maps.add({
        'marque': p.model,
        'modele': p.model,
        'pieceType': p.pieceType,
        'localisation': p.location,
        'lieu': p.location,
        'titre': p.title,
        'entreprise': p.company,
        'prix': p.price,
      });
    }
    return maps;
  }

  List<ArticleVoiture> _applyFilters(List<ArticleVoiture> source) {
    return source.where((v) {
      if (_selectedBrand != null && _selectedBrand!.isNotEmpty) {
        if (!catalogValueMatches(_selectedBrand, v.marque)) return false;
      }
      if (_selectedModel != null && _selectedModel!.isNotEmpty) {
        if (!catalogValueMatches(_selectedModel, v.modele)) return false;
      }
      if (_selectedLocation != null && _selectedLocation!.isNotEmpty) {
        final loc = [
          v.entreprise,
          v.description,
          v.titre,
        ].map((e) => e?.toString() ?? '').join(' ');
        if (!catalogValueMatches(_selectedLocation, loc)) return false;
      }
      if (_budgetMin != null || _budgetMax != null) {
        final price =
            double.tryParse(v.prix.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
        if (_budgetMin != null && price < _budgetMin!) return false;
        if (_budgetMax != null && price > _budgetMax!) return false;
      }
      return true;
    }).toList();
  }

  List<ArticleVoiture> _applyMotoFilters(List<ArticleVoiture> source) {
    return source.where((m) {
      if (_selectedMotoBrand != null && _selectedMotoBrand!.isNotEmpty) {
        if (!catalogValueMatches(_selectedMotoBrand, m.marque)) return false;
      }
      if (_selectedLocation != null && _selectedLocation!.isNotEmpty) {
        final loc = [
          m.entreprise,
          m.description,
          m.titre,
        ].map((e) => e?.toString() ?? '').join(' ');
        if (!catalogValueMatches(_selectedLocation, loc)) return false;
      }
      if (_budgetMin != null || _budgetMax != null) {
        final price =
            double.tryParse(m.prix.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
        if (_budgetMin != null && price < _budgetMin!) return false;
        if (_budgetMax != null && price > _budgetMax!) return false;
      }
      return true;
    }).toList();
  }

  List<Article> _applyPieceFilters(List<Article> source) {
    return source.where((p) {
      if (_selectedBrand != null && _selectedBrand!.isNotEmpty) {
        if (!catalogValueMatches(_selectedBrand, p.company)) return false;
      }
      if (_selectedType != null && _selectedType!.isNotEmpty) {
        if (!pieceMatchesTypeFilter({
          'categorie': p.pieceType,
          'titre': p.title,
          'title': p.title,
        }, _selectedType)) return false;
      }
      if (_selectedModel != null && _selectedModel!.isNotEmpty) {
        if (!catalogValueMatches(_selectedModel, p.model ?? '')) return false;
      }
      if (_selectedLocation != null && _selectedLocation!.isNotEmpty) {
        final loc = [p.location, p.title, p.description].join(' ');
        if (!catalogValueMatches(_selectedLocation, loc)) return false;
      }
      if (_budgetMin != null || _budgetMax != null) {
        final price =
            double.tryParse(p.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
        if (_budgetMin != null && price < _budgetMin!) return false;
        if (_budgetMax != null && price > _budgetMax!) return false;
      }
      return true;
    }).toList();
  }

  bool _isRejectedStatut(String? statut) {
    final s = (statut ?? '').toLowerCase();
    return s == 'rejeté' || s == 'rejete';
  }

  List<ArticleVoiture> _vehiclesForCurrentTab(List<ArticleVoiture> source) {
    final isVendeur = _userService.currentRole == UserRole.vendeur;
    return source.where((v) {
      if ((v.statut ?? 'en_ligne') == 'vendu') return false;
      if (!isVendeur) {
        return (v.statut ?? 'en_ligne') == 'en_ligne';
      }
      final statut = (v.statut ?? '').toLowerCase();
      if (_tabController.index == _statusOnlineTabIndex) {
        return statut == 'en_ligne';
      }
      if (_tabController.index == _statusRejectedTabIndex) {
        return _isRejectedStatut(v.statut);
      }
      return true;
    }).toList();
  }

  List<Article> _piecesForCurrentTab(List<Article> source) {
    final isVendeur = _userService.currentRole == UserRole.vendeur;
    return source.where((p) {
      if ((p.statut ?? 'en_ligne') == 'vendu') return false;
      if (!isVendeur) {
        return (p.statut ?? 'en_ligne') == 'en_ligne';
      }
      final statut = (p.statut ?? '').toLowerCase();
      if (_tabController.index == _statusOnlineTabIndex) {
        return statut == 'en_ligne';
      }
      if (_tabController.index == _statusRejectedTabIndex) {
        return _isRejectedStatut(p.statut);
      }
      return true;
    }).toList();
  }

  String _emptyCatalogMessage({
    required bool isVendeur,
    required String entityLabel,
  }) {
    if (!isVendeur) {
      return 'Aucun $entityLabel disponible pour le moment.';
    }
    if (_tabController.index == _statusRejectedTabIndex) {
      return 'Vous n\'avez aucun $entityLabel rejeté.';
    }
    if (_tabController.index == _statusOnlineTabIndex) {
      return 'Vous n\'avez aucun $entityLabel en ligne.';
    }
    return 'Vous n\'avez aucun $entityLabel en ligne';
  }

  Future<void> fetchVoituresRecommandees() async {
    setState(() {
      isLoadingVoitures = true;
      errorVoitures = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      final isVendeur = _userService.currentRole == UserRole.vendeur;
      String url = isVendeur
          ? getBaseUrl() + '/articles?type=voiture&vendu=false'
          : getBaseUrl() + '/articles?type=voiture&statut=en_ligne&vendu=false';
      _logger.info('[DEBUG] URL voitures: $url');
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final List<dynamic> data = sortArticleMapsNewestFirst(
          json.decode(response.body) as List<dynamic>,
        );
        if (!mounted) return;
        final allVoitures =
            data.map((e) => ArticleVoiture.fromJson(e)).toList();
        final voituresFiltered = allVoitures
            .where((v) => (v.statut ?? 'en_ligne') != 'vendu')
            .toList();

        _logger.info('[DEBUG] Total voitures reçues: ${allVoitures.length}');
        _logger.info(
          '[DEBUG] Voitures après filtrage vendu: ${voituresFiltered.length}',
        );

        // Log des statuts pour déboguer
        for (var v in allVoitures) {
          if ((v.statut ?? 'en_ligne') == 'vendu') {
            _logger.info(
              '[DEBUG] Voiture vendue trouvée: ${v.titre} - Statut: ${v.statut}',
            );
          }
        }

        setState(() {
          voituresRecommandees = voituresFiltered;
          for (final v in voituresFiltered) {
            _backendViews[v.id] = v.views;
          }
          isLoadingVoitures = false;
        });
        _loadBackendViews();
      } else {
        if (!mounted) return;
        setState(() {
          errorVoitures = 'Erreur lors du chargement des voitures';
          isLoadingVoitures = false;
        });
      }
    } catch (e) {
      _logger.info('[DEBUG] Exception fetchVoituresRecommandees: $e');
      if (!mounted) return;
      setState(() {
        errorVoitures = 'Erreur réseau';
        isLoadingVoitures = false;
      });
    }
  }

  Future<void> fetchMotosRecommandees() async {
    setState(() {
      isLoadingMotos = true;
      errorMotos = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      final isVendeur = _userService.currentRole == UserRole.vendeur;
      final url = isVendeur
          ? getBaseUrl() + '/articles?type=moto&vendu=false'
          : getBaseUrl() + '/articles?type=moto&statut=en_ligne&vendu=false';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          if (idToken != null) 'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final List<dynamic> data = sortArticleMapsNewestFirst(
          json.decode(response.body) as List<dynamic>,
        );
        if (!mounted) return;
        final allMotos = data.map((e) => ArticleVoiture.fromJson(e)).toList();
        final motosFiltered = allMotos
            .where((m) => (m.statut ?? 'en_ligne') != 'vendu')
            .toList();
        setState(() {
          motosRecommandees = motosFiltered;
          for (final m in motosFiltered) {
            _backendViews[m.id] = m.views;
          }
          isLoadingMotos = false;
        });
        _loadBackendViews();
      } else {
        if (!mounted) return;
        setState(() {
          errorMotos = 'Erreur lors du chargement des motos';
          isLoadingMotos = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMotos = 'Erreur réseau';
        isLoadingMotos = false;
      });
    }
  }

  /// Véhicules du vendeur en attente de validation (onglet accueil).
  Future<void> fetchVoituresEnAttente() async {
    if (_userService.currentRole != UserRole.vendeur) return;
    setState(() {
      _isLoadingEnAttente = true;
      _errorEnAttente = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      final url =
          '${getBaseUrl()}/articles?type=voiture&statut=en_attente&vendu=false';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (!mounted) return;
        final list = data.map((e) => ArticleVoiture.fromJson(e)).toList();
        setState(() {
          _voituresEnAttente = list;
          _isLoadingEnAttente = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _errorEnAttente = 'Erreur chargement (code ${response.statusCode})';
          _isLoadingEnAttente = false;
        });
      }
    } catch (e) {
      _logger.warning('[Marque] fetchVoituresEnAttente: $e');
      if (!mounted) return;
      setState(() {
        _errorEnAttente = 'Erreur réseau';
        _isLoadingEnAttente = false;
      });
    }
  }

  Future<void> fetchPubs() async {
    setState(() {
      isLoadingPubs = true;
      errorPubs = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      String url = getBaseUrl() + '/publicites?statut=valide';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final pubs = data.map((e) => Pub.fromJson(e)).toList();
        if (!mounted) return;
        setState(() {
          pubsALaUne = pubs
              .where((p) => p.typePub == 'À la une' && _isPubValid(p))
              .toList();
          _logger.info('[DEBUG] 📺 Total pubs reçues: ${pubs.length}');
          _logger.info(
            '[DEBUG] 📺 Publicités À la une: ${pubsALaUne.length} valides sur ${pubs.where((p) => p.typePub == 'À la une').length} totales',
          );
          for (var pub in pubs.where((p) => p.typePub == 'À la une')) {
            final isValid = _isPubValid(pub);
            _logger.info(
              '[DEBUG] 📺 Pub ${pub.id}: statut=${pub.statut}, dateDebut=${pub.dateDebut}, dateFin=${pub.dateFin}, valide=$isValid',
            );
            if (!isValid && pub.statut == 'valide') {
              _logger.info(
                '[DEBUG] 📺 Pub ${pub.id} rejetée pour expiration - maintenant: ${DateTime.now()}, dateFin: ${pub.dateFin}',
              );
            }
          }
          isLoadingPubs = false;
          // Redémarrer le timer si nécessaire
          if (pubsALaUne.isNotEmpty) {
            _startCarouselTimer();
          }
        });
      } else {
        if (!mounted) return;
        setState(() {
          errorPubs = 'Erreur lors du chargement des publicités';
          isLoadingPubs = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorPubs = 'Erreur réseau';
        isLoadingPubs = false;
      });
    }
  }

  Future<void> fetchPubsSponsorisees() async {
    setState(() {
      isLoadingPubs = true;
      errorPubs = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      String url =
          getBaseUrl() + '/publicites?typePub=Sponsorisée&statut=valide';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final pubs = data.map((e) => Pub.fromJson(e)).toList();
        if (!mounted) return;
        setState(() {
          pubsSponsorisees = pubs.where((p) => _isPubValid(p)).toList();
          _logger.info(
            '[DEBUG] ⭐ Total pubs sponsorisées reçues: ${pubs.length}',
          );
          _logger.info(
            '[DEBUG] ⭐ Publicités Sponsorisées: ${pubsSponsorisees.length} valides sur ${pubs.length} totales',
          );
          for (var pub in pubs) {
            final isValid = _isPubValid(pub);
            _logger.info(
              '[DEBUG] ⭐ Pub ${pub.id}: statut=${pub.statut}, dateDebut=${pub.dateDebut}, dateFin=${pub.dateFin}, valide=$isValid',
            );
            if (!isValid && pub.statut == 'valide') {
              _logger.info(
                '[DEBUG] ⭐ Pub ${pub.id} rejetée pour expiration - maintenant: ${DateTime.now()}, dateFin: ${pub.dateFin}',
              );
            }
          }
          isLoadingPubs = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          errorPubs = 'Erreur lors du chargement des publicités';
          isLoadingPubs = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorPubs = 'Erreur réseau';
        isLoadingPubs = false;
      });
    }
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (!mounted || pubsALaUne.isEmpty) return;
      if (_currentPage < pubsALaUne.length - 1) {
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
    if (uri == null) {
      _logger.warning('[DEBUG] Lien publicité invalide: $normalized');
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _logger.warning('[DEBUG] Impossible d\'ouvrir le lien: $normalized');
    }
  }

  void _openFlyerPreview(String imageUrl) {
    if (imageUrl.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// Filtres Marque / Modèles / En attente / … — même logique sélection que [VoituresPage] (index direct + jaune).
  Widget _buildFilterTabRow(double screenWidth, bool isTransitaire) {
    final isVendeur = _userService.currentRole == UserRole.vendeur;
    final chips = <Widget>[];

    void addChip(String title, int index, {bool wide = false}) {
      const selectedColor = Color(0xFFF8BF13);
      const unselectedBorderColor = Color(0xFF000000);
      final isSelected = _tabController.index == index;
      chips.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _tabController.index = index;
              });
            },
            child: Container(
              height: 40,
              width: wide ? 100 : 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? selectedColor : Colors.transparent,
                border: Border.all(
                  color: isSelected ? selectedColor : unselectedBorderColor,
                  width: 0.8,
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (isVendeur) {
      if (isTransitaire) addChip('Activités', 0);
      addChip('Marque', _marqueTabIndex);
      addChip('En ligne', _statusOnlineTabIndex);
      addChip('Rejeté', _statusRejectedTabIndex, wide: true);
      addChip('Statistiques', _statistiquesTabIndex, wide: true);
    } else {
      if (isTransitaire) addChip('Activités', 0);
      addChip('Type', _typeTabIndex);
      addChip('Marque', _marqueTabIndex);
      addChip('Localisation', _localisationTabIndex, wide: true);
      addChip('Budget', _budgetTabIndex, wide: true);
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenWidth * 0.02),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: chips,
        ),
      ),
    );
  }

  String _vehicleDisplayName(ArticleVoiture v) {
    final t = v.titre.trim();
    if (t.isNotEmpty) return t;
    final mm = '${v.marque} ${v.modele}'.trim();
    return mm.isNotEmpty ? mm : 'Véhicule';
  }

  // Section Recommandé :
  Widget buildVoituresRecommandeesGrid() {
    if (isLoadingVoitures) {
      return SkeletonPresets.articleGrid(count: 2);
    }
    if (errorVoitures != null) {
      return Center(child: Text(errorVoitures!));
    }
    // Filtrer les voitures avec statut 'en_ligne' et non vendues
    final userService = _userService;
    final isVendeur = userService.currentRole == UserRole.vendeur;
    final voituresEnLigne = _vehiclesForCurrentTab(voituresRecommandees);
    if (voituresEnLigne.isEmpty) {
      return Center(
        child: Text(
          _emptyCatalogMessage(
            isVendeur: isVendeur,
            entityLabel: 'véhicule',
          ),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      );
    }
    // Appliquer filtres
    final filtered = _applyFilters(voituresEnLigne);
    final screenWidth = MediaQuery.of(context).size.width;
    final cardAspectRatio = screenWidth < 360
        ? 0.68
        : screenWidth < 420
            ? 0.6
            : 0.55;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: GridView.builder(
        shrinkWrap: true,
        primary: false,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: cardAspectRatio,
        ),
        itemCount: filtered.length > 4 ? 4 : filtered.length,
        itemBuilder: (context, index) {
          final voiture = filtered[index];
          return GestureDetector(
            onTap: () {
              setState(() {
                _recordVehicleInteraction(voiture.id.toString());
              });
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CarsInfo(
                    id: voiture.id.toString(),
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
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image avec overlay pour le prix
                  Expanded(
                    flex: 3,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                          child: voiture.images.isNotEmpty
                              ? Image.network(
                                  voiture.images.first,
                                  height: double.infinity,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                )
                              : (voiture.video?.isNotEmpty ?? false)
                                  ? VideoPreviewPlaceholder(
                                      videoUrl: voiture.video,
                                      enablePreviewFrame: false,
                                    )
                                  : Container(
                                      height: double.infinity,
                                      width: double.infinity,
                                      color: Colors.grey[300],
                                      child: const Icon(
                                        Icons.image_not_supported,
                                      ),
                                    ),
                        ),
                        // Badge de vues
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _buildViewBadge(voiture.id),
                        ),
                        // Badge condition (nouveau/occasion)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (voiture.condition?.toLowerCase() ==
                                          'nouveau' ||
                                      voiture.condition?.toLowerCase() ==
                                          'neuf')
                                  ? Colors.purple
                                  : const Color(0xFFF8BF13),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Text(
                              (voiture.condition?.toLowerCase() == 'nouveau' ||
                                      voiture.condition?.toLowerCase() ==
                                          'neuf')
                                  ? 'Nouveau'
                                  : 'Occasion',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Informations de la voiture
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _vehicleDisplayName(voiture),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${formatPrice(voiture.prix)} FCFA',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Caractéristiques en deux colonnes
                          Flexible(
                            child: SingleChildScrollView(
                              physics: const NeverScrollableScrollPhysics(),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Ligne 1: Boite vitesse + Année
                                  if ((voiture.boiteVitesse?.isNotEmpty ??
                                          false) ||
                                      voiture.annee.trim().isNotEmpty)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildCaracteristic(
                                            Icons.settings,
                                            voiture.boiteVitesse ??
                                                'Automatique',
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _buildCaracteristic(
                                            Icons.calendar_today,
                                            voiture.annee,
                                          ),
                                        ),
                                      ],
                                    ),
                                  // Ligne 2: Carburant + Cylindre
                                  if (voiture.carburant != null ||
                                      voiture.cylindre != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: _buildCaracteristic(
                                              Icons.local_gas_station,
                                              voiture.carburant ?? '',
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _buildCaracteristic(
                                              Icons.speed,
                                              voiture.cylindre ?? '',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (voiture.distance != null &&
                                      voiture.distance!.trim().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: _buildCaracteristic(
                                              Icons.speed,
                                              '${voiture.distance} KM',
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _buildCaracteristic(
                                              Icons.door_front_door,
                                              '${voiture.portes ?? ''} portes',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCaracteristic(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 12, color: Colors.amber[700]),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget buildPiecesGrid() {
    if (isLoadingPieces) {
      return SkeletonPresets.articleGrid(count: 2);
    }
    if (errorPieces != null) {
      return Center(child: Text(errorPieces!));
    }
    final userService = _userService;
    final isVendeur = userService.currentRole == UserRole.vendeur;
    final piecesEnLigne = _applyPieceFilters(
      _piecesForCurrentTab(articlesPieces),
    );
    // Filtrage recherche
    final filteredPieces = piecesEnLigne.where((p) {
      final q1 = _searchPieceText.trim().toLowerCase();
      final hay =
          (p.title + ' ' + p.description + ' ' + p.company + ' ' + p.location)
              .toLowerCase();
      if (q1.isNotEmpty && !hay.contains(q1)) return false;
      return true;
    }).toList();
    if (filteredPieces.isEmpty) {
      return Center(
        child: Text(
          _emptyCatalogMessage(
            isVendeur: isVendeur,
            entityLabel: 'pièce',
          ),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: _searchPieceController,
            decoration: InputDecoration(
              hintText: l10n.searchPartHint,
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (val) {
              _searchPieceText = val;
              // Rafraîchir l'affichage
              (this as dynamic).setState(() {});
            },
          ),
        ),
        Expanded(
          child: GridView.builder(
            shrinkWrap: true,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemCount: filteredPieces.length > 8 ? 8 : filteredPieces.length,
            itemBuilder: (context, index) {
              final piece = filteredPieces[index];
              return GestureDetector(
                onTap: () {
                  _recordVehicleInteraction(piece.id);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MastervacPage(
                        id: piece.id,
                        isAcheteur: false,
                        title: piece.title,
                        year: piece.year,
                        description: piece.description,
                        company: piece.company,
                        location: piece.location,
                        price: piece.price,
                        images: piece.images,
                        fuelType: piece.fuelType,
                        model: piece.model,
                        pieceType: piece.pieceType,
                        video: piece.video,
                      ),
                    ),
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          piece.images.isNotEmpty
                              ? Image.network(
                                  piece.images.first,
                                  height: 40,
                                  width: 40,
                                  fit: BoxFit.cover,
                                )
                              : (piece.video?.isNotEmpty ?? false)
                                  ? VideoPreviewPlaceholder(
                                      videoUrl: piece.video, iconSize: 28)
                                  : Container(
                                      height: 40,
                                      width: 40,
                                      color: Colors.grey[300],
                                      child:
                                          const Icon(Icons.image_not_supported),
                                    ),
                          // Badge condition (aligné au style voitures) pour les pièces
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Builder(
                              builder: (context) {
                                final rawCond =
                                    (piece.condition ?? piece.pieceType ?? '')
                                        .toString()
                                        .toLowerCase();
                                final isNew = rawCond == 'nouveau' ||
                                    rawCond == 'neuf' ||
                                    rawCond == 'new';
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isNew
                                        ? Colors.purple
                                        : const Color(0xFFF8BF13),
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  child: Text(
                                    isNew ? 'Nouveau' : 'Occasion',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          // Favorite toggle
                          Positioned(
                            top: 2,
                            right: 2,
                            child: _buildViewBadge(piece.id),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      piece.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVoituresHorizontalList(List<ArticleVoiture> voitures) {
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
              _recordVehicleInteraction(voiture.id.toString());
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CarsInfo(
                    id: voiture.id.toString(),
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
              _recordVehicleInteraction(moto.id.toString());
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      MotoInfo.fromArticleMap(moto.toArticleMap()),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget buildVoituresRecommandeesSection() {
    final isVendeur = _userService.currentRole == UserRole.vendeur;
    final voituresEnLigne = _vehiclesForCurrentTab(voituresRecommandees);
    final screenWidth = MediaQuery.of(context).size.width;
    final sectionCardAspectRatio = screenWidth < 360
        ? 0.64
        : screenWidth < 420
            ? 0.6
            : 0.58;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

Padding(
  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        _userService.currentRole == UserRole.vendeur ? "Mes voitures" : "Véhicules",
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF040415),
        ),
      ),
      GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const VoituresPage(),
            ),
          );
        },
        child: Text(l10n.seeAll,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    ],
  ),
),


        if (isLoadingVoitures && voituresRecommandees.isEmpty)
          SkeletonPresets.articleGrid(count: 2),
        if (errorVoitures != null) Center(child: Text(errorVoitures!)),
        if (!isLoadingVoitures && errorVoitures == null)
          _applyFilters(voituresEnLigne).isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      _emptyCatalogMessage(
                        isVendeur: isVendeur,
                        entityLabel: 'voiture',
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                )
              : _buildVoituresHorizontalList(_applyFilters(voituresEnLigne)),
      ],
    );
  }

  Widget buildMotosSection() {
    final isVendeur = _userService.currentRole == UserRole.vendeur;
    final motosEnLigne = _applyMotoFilters(
      _vehiclesForCurrentTab(motosRecommandees),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isVendeur ? 'Mes motos' : 'Motos',
                style: const TextStyle(
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
                child: Text(l10n.seeAll,
                    style: const TextStyle(fontSize: 16, color: Colors.grey)),
              ),
            ],
          ),
        ),
        if (isLoadingMotos) const Center(child: CircularProgressIndicator()),
        if (errorMotos != null) Center(child: Text(errorMotos!)),
        if (!isLoadingMotos && errorMotos == null)
          motosEnLigne.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      _emptyCatalogMessage(
                        isVendeur: isVendeur,
                        entityLabel: 'moto',
                      ),
                      style: const TextStyle(
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

  Widget buildPiecesSection() {
    final isVendeur = _userService.currentRole == UserRole.vendeur;
    final piecesEnLigne = _applyPieceFilters(
      _piecesForCurrentTab(articlesPieces),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [


Padding(
  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        _userService.currentRole == UserRole.vendeur ? "Mes pièces" : "Pièces détachées",
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF040415),
        ),
      ),
      if (_userService.currentRole != UserRole.vendeur)
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => Piece()),
            );
          },
          child: const Text(
            "Voir plus",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
    ],
  ),
),


        if (isLoadingPieces && articlesPieces.isEmpty)
          SkeletonPresets.articleGrid(count: 2),
        if (errorPieces != null) Center(child: Text(errorPieces!)),
        if (!isLoadingPieces && errorPieces == null)
          piecesEnLigne.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      _emptyCatalogMessage(
                        isVendeur: isVendeur,
                        entityLabel: 'pièce',
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                )
              : SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: piecesEnLigne.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final piece = piecesEnLigne[index];
                      return GestureDetector(
                        onTap: () {
                          _recordVehicleInteraction(piece.id);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MastervacPage(
                                id: piece.id,
                                isAcheteur: false,
                                title: piece.title,
                                year: piece.year,
                                description: piece.description,
                                company: piece.company,
                                location: piece.location,
                                price: piece.price,
                                images: piece.images,
                                fuelType: piece.fuelType,
                                model: piece.model,
                                pieceType: piece.pieceType,
                                video: piece.video,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 180,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12.withOpacity(0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: piece.images.isNotEmpty
                                            ? Image.network(
                                                piece.images.first,
                                                fit: BoxFit.cover,
                                              )
                                            : (piece.video?.isNotEmpty ?? false)
                                                ? VideoPreviewPlaceholder(
                                                    videoUrl: piece.video,
                                                    iconSize: 32,
                                                  )
                                                : Container(
                                                    color: Colors.grey[200],
                                                    child: const Icon(
                                                      Icons.image_not_supported,
                                                      size: 30,
                                                      color: Colors.black26,
                                                    ),
                                                  ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: (piece.pieceType ?? '')
                                                      .toLowerCase() ==
                                                  'nouveau'
                                              ? Colors.purple
                                              : const Color(0xFFF8BF13),
                                          borderRadius:
                                              BorderRadius.circular(30),
                                        ),
                                        child: Text(
                                          (piece.pieceType ?? '')
                                                      .toLowerCase() ==
                                                  'nouveau'
                                              ? 'Nouveau'
                                              : 'Occasion',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: _buildViewBadge(piece.id),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                piece.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                piece.company,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF5E5),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  piece.price.isNotEmpty
                                      ? "${formatPrice(piece.price)} FCFA"
                                      : 'Prix non communiqué',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFB45309),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      ],
    );
  }

  // SECTION SPONSORISÉE
  Widget buildPubsSponsoriseesSection() {
    final pubsValides = pubsSponsorisees.where(_isPubValid).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(Icons.star, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                "Sponsorisé",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),
        if (isLoadingPubs)
          SkeletonPresets.pubBanner(height: 100)
        else if (errorPubs != null)
          SizedBox(height: 100, child: Center(child: Text(errorPubs!)))
        else if (pubsValides.isEmpty)
          const SizedBox(
            height: 100,
            child: Center(
              child: Text(
                "Aucune voiture sponsorisée.",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          )
        else
          Container(
            height: 190,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: pubsValides.length,
              itemBuilder: (context, index) {
                final pub = pubsValides[index];
                return GestureDetector(
                  onTap: () async {
                    if (pub.id.isEmpty) return;
                    // Afficher un indicateur de chargement
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) =>
                          const Center(child: CircularProgressIndicator()),
                    );
                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      final idToken = await user?.getIdToken();
                      final articleId = pub.articleId;
                      if (articleId == null || articleId.isEmpty) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Article lié introuvable pour cette publicité.'),
                          ),
                        );
                        return;
                      }

                      final articleResponse = await http.get(
                        Uri.parse(getBaseUrl() + '/articles/$articleId'),
                        headers: {
                          'Content-Type': 'application/json',
                          if (idToken != null) 'Authorization': 'Bearer $idToken',
                        },
                      );
                      if (articleResponse.statusCode == 200) {
                        final article = jsonDecode(articleResponse.body);
                        Navigator.pop(context); // Fermer le loader
                        // Navigation selon le type d'article
                      } else {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Impossible de charger les détails de cette publicité.'),
                          ),
                        );
                      }
                    } catch (e) {
                      Navigator.pop(context);
                    }
                  },
                  child: SizedBox(
                    width: 255, // Réduit de 340 à 255 (-1/4)
                    child: Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  topRight: Radius.circular(10),
                                ),
                                child: Container(
                                  height: 170,
                                  width: 255, // Réduit de 340 à 255 (-1/4)
                                  color: Colors.grey[300],
                                  child: pub.media.isNotEmpty
                                      ? Image.network(
                                          pub.media[0],
                                          width: 255, // Réduit de 340 à 255 (-1/4)
                                          height: 170,
                                          fit: BoxFit.cover,
                                          errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            return Icon(
                                              Icons.image_not_supported,
                                              size: 80,
                                              color: Colors.grey[600],
                                            );
                                          },
                                        )
                                      : Icon(
                                          Icons.image_not_supported,
                                          size: 80,
                                          color: Colors.grey[600],
                                        ),
                                ),
                              ),
                              Positioned(
                                left: 8,
                                bottom: 12,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pub.description,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: const [
                                          Icon(
                                            Icons.verified,
                                            color: Color(0xFFF8BF13),
                                            size: 18,
                                          ),
                                          SizedBox(width: 5),
                                          Text(
                                            "Vérifiée",
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFFF8BF13),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // SECTION À LA UNE (carrousel)
Widget buildPubsALaUneCarousel() {
  if (isLoadingPubs) {
    return SkeletonPresets.articleGrid(count: 2);
  }
  if (errorPubs != null) {
    return Center(child: Text(errorPubs!));
  }
  if (pubsALaUne.isEmpty) {
    return const SizedBox.shrink();
  }
  // Affiche le carrousel et l'indicateur uniquement si la liste n'est pas vide
  return Column(
    children: [
      Container(
        height: 200, // Un peu plus haut pour mieux voir les adjacentes
        margin: const EdgeInsets.symmetric(horizontal: 8), // Marge extérieure pour voir les adjacents
        child: PageView.builder(
          controller: _pageController,
          // Afficher une partie des slides adjacents
          padEnds: true,
          itemCount: pubsALaUne.length,
          itemBuilder: (context, index) {
            final pub = pubsALaUne[index];
            final hasLink = (pub.lien ?? '').trim().isNotEmpty;
            final card = Card(
              margin: const EdgeInsets.symmetric(
                horizontal: 8, // Marges pour espacer les cards
                vertical: 8,
              ),
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
                      ? Stack(
                          children: [
                            // Image avec ajustement auto
                            Positioned.fill(
                              child: Image.network(
                                pub.media[0],
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                filterQuality: FilterQuality.high,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.image_not_supported,
                                      size: 60, // Réduit de 80 à 60
                                      color: Colors.black54,
                                    ),
                                  );
                                },
                              ),
                            ),
                            // Overlay pour s'assurer que le contenu reste lisible
                            if (pub.description.isNotEmpty)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Colors.black.withOpacity(0.7),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        )
                      : Container(
                          height: 180,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image, size: 80), // Réduit de 120 à 80
                        ),
                ),
              ),
            );

            return GestureDetector(
              onTap: () {
                if (hasLink) {
                  _openPubLink(pub.lien!.trim());
                } else {
                  _openFlyerPreview(pub.media.isNotEmpty ? pub.media[0] : '');
                }
              },
              onDoubleTap: () {
                if (hasLink) {
                  _openFlyerPreview(pub.media.isNotEmpty ? pub.media[0] : '');
                }
              },
              child: card,
            );
          },
        ),
      ),
      const SizedBox(height: 6), // Espace réduit
      if (pubsALaUne.length > 1)
        SmoothPageIndicator(
          controller: _pageController,
          count: pubsALaUne.length,
          effect: JumpingDotEffect(
            activeDotColor: Color(0xFFF8BF13),
            dotColor: Colors.grey.shade300,
            dotHeight: 8, // Points légèrement plus petits
            dotWidth: 8,
          ),
        ),
    ],
  );
}

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final isPortrait = mediaQuery.orientation == Orientation.portrait;
    final isTransitaire = _userService.currentRole == UserRole.transitaire;

    final showBudgetPanel = _userService.currentRole != UserRole.vendeur &&
        _tabController.index == _budgetTabIndex;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFFFFCC00),
              onRefresh: onPagePullRefresh,
              child: _pullRefreshing
                  ? SkeletonPresets.homeMarque()
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        children: [
                          buildPubsALaUneCarousel(),
                          _buildFilterTabRow(screenWidth, isTransitaire),
                          if (_tabController.index == 0 && isTransitaire)
                            _buildActivitesSection(),
                          if (_tabController.index == _marqueTabIndex)
                            (_userService.currentRole == UserRole.vendeur &&
                                    _userService.peutVendreMotos &&
                                    !_userService.peutVendreVehicules)
                                ? _buildMotosMarqueSection()
                                : (_userService.currentRole ==
                                            UserRole.vendeur &&
                                        _userService.peutVendrePieces &&
                                        !_userService.peutVendreVehicules)
                                    ? _buildPiecesMarqueSection()
                                    : _buildMarqueSection(),
                          if (_userService.currentRole != UserRole.vendeur &&
                              _tabController.index == _typeTabIndex)
                            _buildTypeSection(),
                          if (_userService.currentRole == UserRole.vendeur &&
                              _tabController.index == _statistiquesTabIndex)
                            _buildStatistiquesSection(),
                          if (_userService.currentRole != UserRole.vendeur &&
                              _tabController.index == _localisationTabIndex)
                            _buildLocalisationSection(),
                          buildPubsSponsoriseesSection(),
                          if (_userService.currentRole != UserRole.vendeur ||
                              _userService.peutVendreVehicules)
                            buildVoituresRecommandeesSection(),
                          if (_userService.currentRole != UserRole.vendeur ||
                              _userService.peutVendreMotos)
                            buildMotosSection(),
                          if (_userService.currentRole != UserRole.vendeur ||
                              _userService.peutVendrePieces)
                            buildPiecesSection(),
                        ],
                      ),
                    ),
            ),
          ),
          if (showBudgetPanel) _buildBudgetSection(),
        ],
      ),
    );
  }

  // Helpers inline supprimés (non utilisés)

  Widget _buildActivitesSection() {
    final activites = <Map<String, dynamic>>[
      {
        "name": "Souscrire",
        "icon": "assets/images/souscrire.png",
        "onTap": () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SellerSubscriptionPage(forTransitaire: true),
            ),
          );
        },
      },
      {
        "name": "Soumettre",
        "icon": "assets/images/soumis.png",
        "onTap": () {},
      },
      {
        "name": "En Transit",
        "icon": "assets/images/transit.png",
        "onTap": () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const Transit()),
          );
        },
      },
      {
        "name": "En Consommation",
        "icon": "assets/images/en_consommation.png",
        "onTap": () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const Transit()),
          );
        },
      },
    ];

    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2,
              ),
              itemCount: activites.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: activites[index]["onTap"] as VoidCallback?,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: const Color(0xFFE0E0E0),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          activites[index]["icon"],
                          height: 50,
                          width: 50,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          activites[index]["name"],
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF000000),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarqueSection() {
    if (isLoadingVoitures && voituresRecommandees.isEmpty) {
      return const CatalogFilterHorizSkeleton();
    }
    final maps = _catalogMapsForFilters();
    final options = buildMarqueFilterOptions(maps, isPiece: false);
    return CatalogMarqueFilterGrid(
      options: options,
      selected: _selectedBrand,
      onSelected: (v) => setState(() => _selectedBrand = v),
    );
  }

  List<Map<String, dynamic>> _catalogMotoMapsForFilters() {
    return motosRecommandees
        .map((m) => m.toArticleMap())
        .toList();
  }

  Widget _buildMotosMarqueSection() {
    if (isLoadingMotos && motosRecommandees.isEmpty) {
      return const CatalogFilterHorizSkeleton();
    }
    final options = buildMarqueFilterOptions(
      _catalogMotoMapsForFilters(),
      isPiece: false,
      isMoto: true,
    );
    return CatalogMarqueFilterGrid(
      options: options,
      selected: _selectedMotoBrand,
      onSelected: (v) => setState(() => _selectedMotoBrand = v),
    );
  }

  Widget _buildPiecesMarqueSection() {
    if (isLoadingPieces && articlesPieces.isEmpty) {
      return const CatalogFilterHorizSkeleton();
    }
    final pieceMaps = articlesPieces
        .map((p) => {
              'marque': p.company,
              'pieceType': p.pieceType,
              'condition': p.condition,
              'entreprise': p.company,
            })
        .toList();
    final options = buildMarqueFilterOptions(pieceMaps, isPiece: true);
    return CatalogMarqueFilterGrid(
      options: options,
      selected: _selectedBrand,
      onSelected: (v) => setState(() => _selectedBrand = v),
    );
  }

  Widget _buildTypeSection() {
    if (isLoadingPieces && articlesPieces.isEmpty) {
      return const CatalogFilterHorizSkeleton(itemWidth: 76, height: 86);
    }
    return CatalogPieceTypeFilterGrid(
      selected: _selectedType,
      onSelected: (v) => setState(() => _selectedType = v),
    );
  }

  Widget _buildModeleSection() {
    if (isLoadingVoitures && voituresRecommandees.isEmpty) {
      return const CatalogFilterHorizSkeleton(itemWidth: 88, height: 60);
    }
    final modeles = buildModeleFilterOptions(_catalogMapsForFilters());
    return CatalogModeleFilterGrid(
      modeles: modeles,
      selected: _selectedModel,
      onSelected: (v) => setState(() => _selectedModel = v),
    );
  }

  Widget _buildEnAttenteSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Véhicules en attente',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF040415),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VoituresPage()),
                  );
                },
                child: const Text('Mes voitures'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isLoadingEnAttente)
            SkeletonPresets.articleList(count: 3)
          else if (_errorEnAttente != null)
            Text(
              _errorEnAttente!,
              style: const TextStyle(color: Colors.redAccent),
            )
          else if (_voituresEnAttente.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Aucun véhicule en attente de validation.',
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _voituresEnAttente.length > 8 ? 8 : _voituresEnAttente.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final v = _voituresEnAttente[i];
                final thumb =
                    v.images.isNotEmpty ? v.images.first : '';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: thumb.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            thumb,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.directions_car),
                          ),
                        )
                      : const Icon(Icons.directions_car),
                  title: Text(
                    v.titre.isNotEmpty ? v.titre : '${v.marque} ${v.modele}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${v.marque} ${v.modele} · ${v.prix} FCFA',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _recordVehicleInteraction(v.id.toString());
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CarsInfo(
                          id: v.id.toString(),
                          titre: v.titre,
                          description: v.description,
                          marque: v.marque,
                          modele: v.modele,
                          annee: v.annee,
                          prix: v.prix,
                          condition: v.condition,
                          boiteVitesse: v.boiteVitesse,
                          carburant: v.carburant,
                          climatiseur: v.climatiseur,
                          distance: v.distance,
                          sieges: v.sieges,
                          portes: v.portes,
                          cylindre: v.cylindre,
                          images: v.images,
                          video: v.video,
                          entreprise: v.entreprise,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatistiquesSection() {
    final isVendeur = _userService.currentRole == UserRole.vendeur;
    if (!isVendeur) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFE082)),
          ),
          child: const Text(
            "Les statistiques détaillées sont réservées aux vendeurs.",
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF795548),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final vtRaw = _statsVendeurType ?? _userService.vendeurType ?? 'mixte';
    final vt = vtRaw.toString().toLowerCase().trim();
    final showVehicules =
        vt.isEmpty || vt == 'mixte' || vt == 'vehicules' || vt == 'véhicules';
    final showPieces = vt.isEmpty || vt == 'mixte' || vt == 'pieces';
    final showMotos = vt == 'motos';

    final motosEnLigne = motosRecommandees
        .where(
          (m) =>
              (m.statut ?? 'en_ligne') == 'en_ligne' &&
              (m.statut ?? '') != 'vendu',
        )
        .length;

    final totalViewsVehicles = voituresRecommandees.fold<int>(
      0,
      (sum, v) => sum + (_backendViews[v.id] ?? 0),
    );
    final totalViewsMotos = motosRecommandees.fold<int>(
      0,
      (sum, m) => sum + (_backendViews[m.id] ?? 0),
    );
    final totalViewsPieces = articlesPieces.fold<int>(
      0,
      (sum, p) => sum + (_backendViews[p.id] ?? 0),
    );
    final totalViews = totalViewsVehicles + totalViewsMotos + totalViewsPieces;

    final statsCards = <Map<String, Object?>>[
      if (showVehicules)
        {
          'kind': 'plain',
          'label': 'Véhicules en ligne',
          'value': _statsVehiclesOnline,
          'icon': Icons.directions_car_filled,
          'color': const Color(0xFFF8BF13),
          'description': 'Annonces visibles',
        },
      if (showMotos)
        {
          'kind': 'plain',
          'label': 'Motos en ligne',
          'value': motosEnLigne,
          'icon': Icons.two_wheeler,
          'color': const Color(0xFFF8BF13),
          'description': 'Annonces visibles',
        },
      if (showPieces)
        {
          'kind': 'plain',
          'label': 'Pièces en ligne',
          'value': _statsPiecesOnline,
          'icon': Icons.build_circle_outlined,
          'color': const Color(0xFFF8BF13),
          'description': 'Annonces visibles',
        },
      if (showVehicules)
        {
          'kind': 'plain',
          'label': 'Véhicules vendus',
          'value': _statsVehiclesSold,
          'icon': Icons.sell_outlined,
          'color': const Color(0xFF2E7D32),
          'description': 'Articles marqués vendus',
        },
      if (showPieces)
        {
          'kind': 'plain',
          'label': 'Pièces vendues',
          'value': _statsPiecesSold,
          'icon': Icons.handyman_outlined,
          'color': const Color(0xFF2E7D32),
          'description': 'Articles marqués vendus',
        },
      {
        'kind': 'plain',
        'label': 'Vues enregistrées',
        'value': totalViews,
        'icon': Icons.remove_red_eye,
        'color': const Color(0xFFF8BF13),
        'description': 'Toutes annonces confondues',
      },
    ];

    final topVehicles = voituresRecommandees
        .where((v) => (_backendViews[v.id] ?? 0) > 0)
        .toList()
      ..sort((a, b) {
        final countA = _backendViews[a.id] ?? 0;
        final countB = _backendViews[b.id] ?? 0;
        return countB.compareTo(countA);
      });

    final viewPoints = <double>[
      ...voituresRecommandees.map((v) => (_backendViews[v.id] ?? 0).toDouble()),
      ...motosRecommandees.map((m) => (_backendViews[m.id] ?? 0).toDouble()),
      ...articlesPieces.map((p) => (_backendViews[p.id] ?? 0).toDouble()),
    ]..sort((a, b) => b.compareTo(a));
    while (viewPoints.length < 8) {
      viewPoints.add(0);
    }
    final activityPoints = viewPoints.take(8).toList().reversed.toList();

    final kpiCards = statsCards.take(4);
    final dashboardKpis = kpiCards.map((card) {
      final valueNum = (card['value'] as num?)?.round() ?? 0;
      return SellerStatsKpi(
        label: card['label'] as String,
        value: '$valueNum',
        icon: card['icon'] as IconData,
        color: card['color'] as Color,
      );
    }).toList();

    final donutSlices = <SellerStatsDonutSlice>[
      if (showVehicules && totalViewsVehicles > 0)
        SellerStatsDonutSlice(
          label: 'Véhicules',
          value: totalViewsVehicles.toDouble(),
          color: const Color(0xFFF8BF13),
        ),
      if (showMotos && totalViewsMotos > 0)
        SellerStatsDonutSlice(
          label: 'Motos',
          value: totalViewsMotos.toDouble(),
          color: const Color(0xFF1565C0),
        ),
      if (showPieces && totalViewsPieces > 0)
        SellerStatsDonutSlice(
          label: 'Pièces',
          value: totalViewsPieces.toDouble(),
          color: const Color(0xFF5D4037),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Vos statistiques",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_sellerMarqueStatsLoading) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 3),
          ],
          const SizedBox(height: 12),
          SellerStatsDashboard(
            activityTitle: 'Activité (vues)',
            activitySubtitle: 'Répartition par annonces les plus consultées',
            activityPoints: activityPoints,
            kpis: dashboardKpis,
            donutTitle: 'Répartition des vues',
            donutCenterValue: _formatCompactCount(totalViews),
            donutCenterLabel: 'Vues totales',
            donutSlices: donutSlices.isNotEmpty
                ? donutSlices
                : const [
                    SellerStatsDonutSlice(
                      label: 'Aucune vue',
                      value: 1,
                      color: Color(0xFFE0E0E0),
                    ),
                  ],
          ),
          const SizedBox(height: 16),
          if (topVehicles.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Top véhicules (vues)",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...topVehicles.take(3).map((vehicle) {
                  final clicks = _backendViews[vehicle.id] ?? 0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBF0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFF8BF13).withOpacity(0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: vehicle.images.isNotEmpty
                              ? Image.network(
                                  vehicle.images.first,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 40,
                                  height: 40,
                                  color: const Color(0xFFFFF3C4),
                                  child: const Icon(Icons.directions_car,
                                      size: 20),
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${vehicle.titre} · ${vehicle.marque}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1B2B4B),
                            ),
                          ),
                        ),
                        Text(
                          '$clicks vues',
                          style: const TextStyle(
                            color: Color(0xFF5D4037),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            )
          else
            const Text(
              "Les vues globales apparaîtront ici dès consultation de vos véhicules.",
              style: TextStyle(fontSize: 12, color: Color(0xFF795548)),
            ),
        ],
      ),
    );
  }

  Widget _buildLocalisationSection() {
    if (isLoadingVoitures && voituresRecommandees.isEmpty) {
      return const CatalogFilterHorizSkeleton();
    }
    final options = buildLocationFilterOptions(_catalogMapsForFilters());
    return CatalogLocationFilterGrid(
      options: options,
      selected: _selectedLocation,
      onSelected: (v) => setState(() => _selectedLocation = v),
    );
  }

  Widget _buildBudgetSection() {
    final carMaps = voituresRecommandees
        .map((v) => <String, dynamic>{'prix': v.prix, 'statut': v.statut})
        .toList();
    final pieceMaps = articlesPieces
        .map((p) => <String, dynamic>{'prix': p.price, 'statut': p.statut})
        .toList();
    return CatalogBudgetFilterPanel(
      articles: [...carMaps, ...pieceMaps],
      budgetMin: _budgetMin,
      budgetMax: _budgetMax,
      countLabel: (n) => l10n.vehiclesAvailableCount(n),
      onReset: () => setState(() {
        _budgetMin = null;
        _budgetMax = null;
      }),
      onApply: (min, max) => setState(() {
        _budgetMin = min;
        _budgetMax = max;
      }),
    );
  }
}
