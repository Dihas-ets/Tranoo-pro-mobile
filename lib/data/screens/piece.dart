import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tranoo_pro/services/user_service.dart';
import 'package:tranoo_pro/services/subscription_access_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'mastervacpage.dart';
import 'create_sell2.dart';
import 'seller_subscription_page.dart';
import 'package:tranoo_pro/utils/role_redirect.dart';
import 'package:tranoo_pro/utils/article_list_sort.dart';
import 'package:tranoo_pro/utils/article_view_helper.dart';
import 'package:tranoo_pro/widgets/video_preview_placeholder.dart';
import 'package:tranoo_pro/widgets/cached_media_image.dart';
import 'package:tranoo_pro/utils/page_refresh_registry.dart';
import 'package:tranoo_pro/widgets/page_pull_refresh.dart';
import 'package:tranoo_pro/widgets/skeleton/app_skeleton.dart';
import 'package:tranoo_pro/utils/catalog_display.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';
import 'package:tranoo_pro/utils/catalog_filter_options.dart';
import 'package:tranoo_pro/widgets/catalog_filter_sections.dart';
import 'package:tranoo_pro/utils/local_data_cache.dart';
import 'package:tranoo_pro/utils/pro_image_utils.dart';
import 'package:provider/provider.dart';
import 'package:tranoo_pro/providers/auth_provider.dart' as myauth;

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

class Piece extends StatefulWidget {
  const Piece({super.key});

  @override
  State<Piece> createState() => _PieceState();
}

class _PieceState extends State<Piece>
    with SingleTickerProviderStateMixin, RegisterPageRefresh {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  Future<void> onPagePullRefresh() async => fetchPieces();
  List<dynamic> pieces = [];
  bool isLoading = true;
  String? error;
  List<bool> _isVisible = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";

  // Filtres
  String? _selectedBrand;
  String? _selectedType;
  String? _selectedLocation;
  double? _budgetMin;
  double? _budgetMax;

  // TabController pour les filtres
  late TabController _tabController;
  late int _typeTabIndex;
  late int _marqueTabIndex;
  late int _localisationTabIndex;
  late int _budgetTabIndex;
  late int _statusOnlineTabIndex;
  late int _statusRejectedTabIndex;

  final UserService _userService = UserService();
  final SubscriptionAccessService _subscriptionService =
      SubscriptionAccessService();
  SellerAccessStatus? _accessStatus;
  bool _loadingAccessStatus = true;

  String? _sellerMongoId() {
    return Provider.of<myauth.AuthProvider>(context, listen: false)
        .user?['_id']
        ?.toString();
  }

  String _catalogCacheKey() {
    if (_userService.currentRole != UserRole.vendeur) {
      return 'catalog_pieces_public';
    }
    return 'catalog_pieces_${_sellerMongoId() ?? 'vendeur'}';
  }

  @override
  void initState() {
    super.initState();

    // Initialisation des indices des onglets selon le rôle
    final isVendeur = _userService.currentRole == UserRole.vendeur;
    if (isVendeur) {
      _typeTabIndex = 0;
      _marqueTabIndex = 1;
      _statusOnlineTabIndex = 2;
      _statusRejectedTabIndex = 3;
      _tabController = TabController(length: 4, vsync: this);
    } else {
      _typeTabIndex = 0;
      _marqueTabIndex = 1;
      _localisationTabIndex = 2;
      _budgetTabIndex = 3;
      _tabController = TabController(length: 4, vsync: this);
    }

    _tabController.addListener(() {
      setState(() {});
    });

    fetchPieces();
    _refreshAccessStatus();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.toLowerCase();
      });
    });
  }

  String _pieceDisplayLocation(dynamic piece) {
    final a = piece['localisation']?.toString().trim();
    if (a != null && a.isNotEmpty) return a;
    final b = piece['lieu']?.toString().trim();
    if (b != null && b.isNotEmpty) return b;
    return '';
  }

  Map<String, dynamic>? _contactMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  Future<void> _refreshAccessStatus() async {
    setState(() {
      _loadingAccessStatus = true;
    });
    try {
      final status = await _subscriptionService.getSellerAccessStatus();
      if (!mounted) return;
      setState(() {
        _accessStatus = status;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _accessStatus = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingAccessStatus = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _reloadAll() {
    // Réinitialiser la recherche
    _searchController.clear();
    _searchText = '';

    // Réinitialiser les filtres
    _selectedBrand = null;
    _selectedType = null;
    _selectedLocation = null;
    _budgetMin = null;
    _budgetMax = null;

    // Recharger les données
    fetchPieces();
    setState(() {});
  }

  Future<void> fetchPieces({bool silent = false}) async {
    final cacheKey = _catalogCacheKey();
    if (!silent) {
      final stale = await LocalDataCache.readJsonListStale(cacheKey);
      if (stale != null && mounted) {
        setState(() {
          pieces = stale;
          _isVisible = List.generate(stale.length, (index) => true);
          isLoading = false;
        });
        precacheProImages(
          context,
          photoUrlsFromArticles(stale.cast<Map<String, dynamic>>()),
          cloudinaryWidthPx: cloudinaryWidthPx(context, logicalWidth: 180),
        );
      } else {
        setState(() {
          isLoading = true;
          error = null;
        });
      }
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      final isVendeur = _userService.currentRole == UserRole.vendeur;
      if (isVendeur && (idToken == null || idToken.isEmpty)) {
        if (!mounted) return;
        setState(() {
          error = 'Session expirée. Reconnectez-vous.';
          isLoading = false;
        });
        return;
      }
      final String url = isVendeur
          ? '${getBaseUrl()}/articles?type=piece'
          : '${getBaseUrl()}/public/articles?type=piece';
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (idToken != null && idToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $idToken';
      }
      final response = await http
          .get(
            Uri.parse(url),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final List<dynamic> data = sortArticleMapsNewestFirst(
          jsonDecode(response.body) as List<dynamic>,
        );
        await LocalDataCache.writeJsonList(cacheKey, data);
        if (!mounted) return;
        setState(() {
          pieces = data;
          _isVisible = List.generate(data.length, (index) => true);
          isLoading = false;
        });
        precacheProImages(
          context,
          photoUrlsFromArticles(data.cast<Map<String, dynamic>>()),
          cloudinaryWidthPx: cloudinaryWidthPx(context, logicalWidth: 180),
        );
      } else {
        setState(() {
          error = response.statusCode == 401
              ? 'Session expirée. Reconnectez-vous.'
              : 'Erreur lors du chargement des pièces';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Erreur réseau';
        isLoading = false;
      });
    }
  }

  Future<void> _deletePiece(String articleId, int index) async {
    if (_accessStatus?.canCreateArticle == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Abonnement inactif: suppression des pieces desactivee.',
          ),
        ),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmDeletion),
        content: Text(l10n.confirmDeletePart),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() {
      _isVisible[index] = false;
    });
    await Future.delayed(const Duration(milliseconds: 400));
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      final response = await http.delete(
        Uri.parse(getBaseUrl() + '/articles/$articleId'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.partDeletedSuccess)),
        );
        fetchPieces();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.deletionError)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.networkOrServerError)),
      );
    }
  }

  Widget _sellerCardAction({
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '--';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _openSubscriptionPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SellerSubscriptionPage(),
      ),
    );
    await _refreshAccessStatus();
    if (mounted) fetchPieces();
  }

  Future<void> _handleAddPieceWithSubscription() async {
    SellerAccessStatus status;
    try {
      status = await _subscriptionService.getSellerAccessStatus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de verifier le plan d\'abonnement.'),
        ),
      );
      return;
    }

    if (!mounted) return;

    // Plan actif : aller directement à la création d'annonce.
    if (status.canCreateArticle) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const CreateSellPage2(),
        ),
      );
      if (mounted) fetchPieces();
      return;
    }

    // Pas de plan actif : popup puis page abonnement si l'utilisateur accepte.
    final String subtitle = status.freeTrialActive && !status.paidPlanActive
        ? 'Vous etes dans le ${status.currentPlanLabel}. Fin de l\'essai: ${_formatDate(status.freeTrialEndsAt)}.'
        : 'Votre essai gratuit est termine. Activez un abonnement pour publier des pieces.';

    final goSubscribe = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Row(
            children: [
              Icon(Icons.workspace_premium, color: Color(0xFFF8BF13)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Abonnement requis',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Plan actuel: ${status.currentPlanLabel}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(subtitle),
              const SizedBox(height: 10),
              Text(
                'Tarif Plan Pro: ${status.monthlyPriceFcfa} FCFA / mois',
                style: const TextStyle(color: Color(0xFFB45309)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.close),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF8BF13),
                foregroundColor: Colors.black,
              ),
              child: const Text('Voir abonnement'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (goSubscribe == true) {
      await _openSubscriptionPage();
    }
  }

  // Appliquer les filtres
  List<dynamic> _applyFilters(List<dynamic> source) {
    final isVendeur = _userService.currentRole == UserRole.vendeur;
    final sellerId = isVendeur ? _sellerMongoId() : null;
    return source.where((p) {
      if (isVendeur &&
          !articleOwnedBySeller(
            Map<String, dynamic>.from(p as Map),
            sellerId,
          )) {
        return false;
      }
      if (_selectedBrand != null && _selectedBrand!.isNotEmpty) {
        final marque =
            (p['marque'] ?? p['pieceType'] ?? p['condition'] ?? '').toString();
        if (!catalogValueMatches(_selectedBrand, marque)) return false;
      }
      if (_selectedType != null && _selectedType!.isNotEmpty) {
        if (!pieceMatchesTypeFilter(p, _selectedType)) return false;
      }
      if (_selectedLocation != null && _selectedLocation!.isNotEmpty) {
        final loc = [
          p['localisation'],
          p['lieu'],
          p['entreprise'],
          p['titre'],
          p['description'],
        ].map((e) => e?.toString() ?? '').join(' ');
        if (!catalogValueMatches(_selectedLocation, loc)) return false;
      }
      if (_budgetMin != null || _budgetMax != null) {
        final prixStr = (p['prix'] ?? '').toString();
        final price =
            double.tryParse(prixStr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
        if (_budgetMin != null && price < _budgetMin!) return false;
        if (_budgetMax != null && price > _budgetMax!) return false;
      }
      if (isVendeur) {
        final statut = (p['statut'] ?? '').toString().toLowerCase();
        if (_tabController.index == _statusOnlineTabIndex &&
            statut != 'en_ligne') {
          return false;
        }
        if (_tabController.index == _statusRejectedTabIndex &&
            statut != 'rejeté' &&
            statut != 'rejete') {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Widget _buildTabButton(String title, int index, {bool isWide = false}) {
    bool isSelected = _tabController.index == index;
    const selectedColor = Color(0xFFF8BF13);
    const unselectedBorderColor = Color(0xFF000000);
    return GestureDetector(
      onTap: () {
        setState(() {
          _tabController.index = index;
        });
      },
      child: Container(
        width: isWide ? 100 : 70,
        height: 40,
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
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildMarqueSection() {
    if (isLoading && pieces.isEmpty) {
      return const CatalogFilterHorizSkeleton();
    }
    final options = buildMarqueFilterOptions(pieces, isPiece: true);
    return CatalogMarqueFilterGrid(
      options: options,
      selected: _selectedBrand,
      onSelected: (v) => setState(() => _selectedBrand = v),
    );
  }

  Widget _buildTypeSection() {
    if (isLoading && pieces.isEmpty) {
      return const CatalogFilterHorizSkeleton(itemWidth: 76, height: 86);
    }
    return CatalogPieceTypeFilterGrid(
      selected: _selectedType,
      onSelected: (v) => setState(() => _selectedType = v),
    );
  }

  Widget _buildLocalisationSection() {
    if (isLoading && pieces.isEmpty) {
      return const CatalogFilterHorizSkeleton(itemWidth: 100, height: 90);
    }
    final options = buildLocationFilterOptions(pieces);
    return CatalogLocationFilterGrid(
      options: options,
      selected: _selectedLocation,
      onSelected: (v) => setState(() => _selectedLocation = v),
    );
  }

  Widget _buildBudgetSection() {
    return CatalogBudgetFilterPanel(
      articles: pieces,
      budgetMin: _budgetMin,
      budgetMax: _budgetMax,
      countLabel: (n) => l10n.partsAvailableCount(n),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final userService = UserService();
    final isVendeur = userService.currentRole == UserRole.vendeur;
    final isChauffeur = userService.currentRole == UserRole.chauffeur ||
        userService.currentRole == UserRole.livreur;

    final filteredPieces = _applyFilters(pieces).where((p) {
      final title = (p['titre'] ?? '').toString().toLowerCase();
      return _searchText.isEmpty || title.contains(_searchText);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(isVendeur ? 'Ajouter une pièce' : 'Pièces détachées'),
        backgroundColor: Colors.amber,
        actions: [
          if (isVendeur && !_loadingAccessStatus)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openSubscriptionPage,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: (_accessStatus?.canCreateArticle ?? false)
                          ? Colors.green.shade100
                          : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.workspace_premium,
                          size: 14,
                          color: (_accessStatus?.canCreateArticle ?? false)
                              ? Colors.green.shade800
                              : Colors.blue.shade800,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _accessStatus?.currentPlanLabel ?? 'Plan inconnu',
                          style: TextStyle(
                            color: (_accessStatus?.canCreateArticle ?? false)
                                ? Colors.green.shade800
                                : Colors.blue.shade800,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (isVendeur)
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.white),
              onPressed: _handleAddPieceWithSubscription,
              tooltip: 'Ajouter une pièce',
            ),
        ],
      ),
      body: PagePullRefresh(
        onRefresh: () => fetchPieces(),
        refreshSkeleton: SkeletonPresets.sellerCatalog(),
        child: isLoading && pieces.isEmpty
            ? SkeletonPresets.sellerCatalog()
            : error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.35,
                        child: Center(child: Text(error!)),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      if (isVendeur &&
                          !_loadingAccessStatus &&
                          (_accessStatus?.showExpiryWarning ?? false))
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4CC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFF8BF13)),
                          ),
                          child: Text(
                            _accessStatus?.paidPlanActive == true
                                ? 'Attention: votre Plan Pro expire dans ${_accessStatus?.paidPlanRemainingDays ?? 0} jour(s).'
                                : 'Votre Plan Decouverte se termine dans ${_accessStatus?.freeTrialRemainingDays ?? 0} jour(s).',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8A6D3B),
                            ),
                          ),
                        ),
                      // Barre de recherche
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: l10n.searchPartHint,
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.refresh,
                                  color: Color(0xFF8C9199)),
                              onPressed: _reloadAll,
                            ),
                            filled: true,
                            fillColor: Colors.grey[200],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      // Filtres TabBar
                      Container(
                        padding: const EdgeInsets.all(8),
                        child: Center(
                          child: TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            tabAlignment: TabAlignment.center,
                            indicator: const BoxDecoration(),
                            padding: EdgeInsets.zero,
                            labelPadding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            tabs: [
                              _buildTabButton(
                                l10n.filterTypeTab,
                                _typeTabIndex,
                                isWide: true,
                              ),
                              _buildTabButton(
                                l10n.filterBrandTab,
                                _marqueTabIndex,
                              ),
                              if (isVendeur)
                                _buildTabButton(
                                    "En ligne", _statusOnlineTabIndex,
                                    isWide: true),
                              if (isVendeur)
                                _buildTabButton(
                                    "Rejeté", _statusRejectedTabIndex,
                                    isWide: true),
                              if (!isVendeur)
                                _buildTabButton(
                                  l10n.filterLocationTab,
                                  _localisationTabIndex,
                                  isWide: true,
                                ),
                              if (!isVendeur)
                                _buildTabButton(
                                  l10n.budgetLabel,
                                  _budgetTabIndex,
                                ),
                            ],
                          ),
                        ),
                      ),
                      // Sections de filtres
                      if (_tabController.index == _typeTabIndex)
                        _buildTypeSection(),
                      if (_tabController.index == _marqueTabIndex)
                        _buildMarqueSection(),
                      if (!isVendeur &&
                          _tabController.index == _localisationTabIndex)
                        _buildLocalisationSection(),
                      // Liste des pièces
                      Expanded(
                        child: filteredPieces.isEmpty
                            ? Center(
                                child: Text(
                                  isVendeur
                                      ? "Vous n'avez aucune pièce en ligne actuellement"
                                      : "Aucune pièce en ligne actuellement",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                            : Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                child: GridView.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 0.78,
                                  ),
                                  itemCount: filteredPieces.length,
                                  itemBuilder: (context, index) {
                                    final piece = filteredPieces[index];
                                    final pieceId = piece['_id'] ?? '';
                                    final canManagePieces =
                                        _accessStatus?.canCreateArticle ?? true;
                                    return AnimatedOpacity(
                                      opacity: _isVisible.length > index &&
                                              _isVisible[index]
                                          ? 1.0
                                          : 0.0,
                                      duration:
                                          const Duration(milliseconds: 400),
                                      child: Stack(
                                        children: [
                                          ColorFiltered(
                                            colorFilter:
                                                isVendeur && !canManagePieces
                                                    ? const ColorFilter
                                                        .matrix(<double>[
                                                        0.2126,
                                                        0.7152,
                                                        0.0722,
                                                        0,
                                                        0,
                                                        0.2126,
                                                        0.7152,
                                                        0.0722,
                                                        0,
                                                        0,
                                                        0.2126,
                                                        0.7152,
                                                        0.0722,
                                                        0,
                                                        0,
                                                        0,
                                                        0,
                                                        0,
                                                        1,
                                                        0,
                                                      ])
                                                    : const ColorFilter.mode(
                                                        Colors.transparent,
                                                        BlendMode.dst,
                                                      ),
                                            child: GestureDetector(
                                              onTap: () {
                                                final articleMap =
                                                    Map<String, dynamic>.from(
                                                        piece);
                                                trackArticleView(
                                                    articleIdFromMap(
                                                        articleMap));
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        MastervacPage(
                                                      id: (piece['_id'] ??
                                                              piece['id'] ??
                                                              piece[
                                                                  'articleId'] ??
                                                              piece['Id'] ??
                                                              piece['article'])
                                                          ?.toString(),
                                                      isAcheteur: isChauffeur,
                                                      title:
                                                          piece['titre'] ?? '',
                                                      year:
                                                          piece['annee'] ?? '',
                                                      description: piece[
                                                              'description'] ??
                                                          '',
                                                      company:
                                                          piece['entreprise'] ??
                                                              '',
                                                      location:
                                                          _pieceDisplayLocation(
                                                              piece),
                                                      price: piece['prix']
                                                              ?.toString() ??
                                                          '',
                                                      images: (piece['photos']
                                                                  as List?)
                                                              ?.map((e) =>
                                                                  e.toString())
                                                              .toList() ??
                                                          [],
                                                      fuelType:
                                                          piece['typeMoteur'],
                                                      model: piece['modele']
                                                          ?.toString(),
                                                      pieceType: piece[
                                                              'condition'] ??
                                                          piece['pieceType'],
                                                      categorie:
                                                          piece['categorie']
                                                              ?.toString(),
                                                      marque: piece['marque']
                                                          ?.toString(),
                                                      video: piece['video'],
                                                      fournisseur: _contactMap(
                                                          piece['fournisseur']),
                                                      vendeur: _contactMap(
                                                          piece['vendeur']),
                                                    ),
                                                  ),
                                                ).then((_) => fetchPieces());
                                              },
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black12
                                                          .withOpacity(0.08),
                                                      blurRadius: 12,
                                                      offset:
                                                          const Offset(0, 6),
                                                    ),
                                                  ],
                                                ),
                                                padding:
                                                    const EdgeInsets.all(10),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              16),
                                                      child: SizedBox(
                                                        height: 100,
                                                        width: double.infinity,
                                                        child: Stack(
                                                          children: [
                                                            Positioned.fill(
                                                              child: (piece['photos']
                                                                              as List?)
                                                                          ?.isNotEmpty ==
                                                                      true
                                                                  ? CachedMediaImage(
                                                                      url: piece[
                                                                              'photos']
                                                                          [0],
                                                                      fit: BoxFit
                                                                          .cover,
                                                                      width: double
                                                                          .infinity,
                                                                      height: 100,
                                                                      cloudinaryWidthPx: MediaQuery
                                                                              .sizeOf(
                                                                                  context)
                                                                          .width
                                                                          .toInt(),
                                                                    )
                                                                  : (piece['video'] !=
                                                                              null &&
                                                                          (piece['video']?.toString().isNotEmpty ??
                                                                              false))
                                                                      ? VideoPreviewPlaceholder(
                                                                          videoUrl:
                                                                              piece['video']?.toString(),
                                                                          iconSize:
                                                                              36,
                                                                          enablePreviewFrame:
                                                                              false,
                                                                        )
                                                                      : Container(
                                                                          color:
                                                                              Colors.grey[200],
                                                                          child:
                                                                              const Icon(
                                                                            Icons.image_not_supported,
                                                                            size:
                                                                                30,
                                                                            color:
                                                                                Colors.black26,
                                                                          ),
                                                                        ),
                                                            ),
                                                            Positioned(
                                                              top: 6,
                                                              right: 6,
                                                              child: Builder(
                                                                builder:
                                                                    (context) {
                                                                  final status =
                                                                      (piece['statut'] ??
                                                                              '')
                                                                          .toString()
                                                                          .toLowerCase();
                                                                  Color bg;
                                                                  Color fg;
                                                                  String label;
                                                                  if (status ==
                                                                      'en_ligne') {
                                                                    bg = const Color(
                                                                        0xFFE8F5E9);
                                                                    fg = const Color(
                                                                        0xFF2E7D32);
                                                                    label =
                                                                        'En ligne';
                                                                  } else if (status ==
                                                                      'en_attente') {
                                                                    bg = const Color(
                                                                        0xFFFFF8E1);
                                                                    fg = const Color(
                                                                        0xFFB45309);
                                                                    label =
                                                                        'En attente';
                                                                  } else {
                                                                    bg = const Color(
                                                                        0xFFFFEBEE);
                                                                    fg = const Color(
                                                                        0xFFC62828);
                                                                    label =
                                                                        'Rejeté';
                                                                  }
                                                                  return Container(
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .symmetric(
                                                                      horizontal:
                                                                          8,
                                                                      vertical:
                                                                          4,
                                                                    ),
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      color: bg,
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              10),
                                                                    ),
                                                                    child: Text(
                                                                      label,
                                                                      style:
                                                                          TextStyle(
                                                                        color:
                                                                            fg,
                                                                        fontWeight:
                                                                            FontWeight.w700,
                                                                        fontSize:
                                                                            10,
                                                                      ),
                                                                    ),
                                                                  );
                                                                },
                                                              ),
                                                            ),
                                                            Positioned(
                                                              bottom: 6,
                                                              left: 6,
                                                              child:
                                                                  buildArticleViewBadge(
                                                                articleViewsFromMap(
                                                                  Map<String,
                                                                          dynamic>.from(
                                                                      piece),
                                                                ),
                                                              ),
                                                            ),
                                                            if (isVendeur)
                                                              Positioned(
                                                                right: 6,
                                                                bottom: 6,
                                                                child: Row(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    _sellerCardAction(
                                                                      icon: Icons
                                                                          .edit,
                                                                      color: const Color(
                                                                          0xFF0461B6),
                                                                      onPressed: canManagePieces
                                                                          ? () {
                                                                              final id = (piece['_id'] ?? piece['id'] ?? piece['articleId'] ?? piece['Id'] ?? piece['article'])?.toString();
                                                                              Navigator.push(
                                                                                context,
                                                                                MaterialPageRoute(
                                                                                  builder: (context) => CreateSellPage2(
                                                                                    editMode: true,
                                                                                    editArticleId: id,
                                                                                    initialData: Map<String, dynamic>.from(piece),
                                                                                  ),
                                                                                ),
                                                                              ).then((_) => fetchPieces());
                                                                            }
                                                                          : null,
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            6),
                                                                    _sellerCardAction(
                                                                      icon: Icons
                                                                          .close,
                                                                      color: Colors
                                                                          .red,
                                                                      onPressed: canManagePieces
                                                                          ? () => _deletePiece(
                                                                                pieceId,
                                                                                index,
                                                                              )
                                                                          : null,
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      piece['titre'] ??
                                                          'Sans titre',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      piece['entreprise'] ??
                                                          'Entreprise inconnue',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: Colors.black54,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 10),
                                                    catalogPiecePricePill(
                                                        piece['prix']),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (isVendeur && !canManagePieces)
                                            Positioned.fill(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(0.45),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                alignment: Alignment.center,
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black54,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            14),
                                                  ),
                                                  child: const Text(
                                                    'Abonnement expire',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),
                      if (!isVendeur && _tabController.index == _budgetTabIndex)
                        _buildBudgetSection(),
                    ],
                  ),
      ),
    );
  }
}
