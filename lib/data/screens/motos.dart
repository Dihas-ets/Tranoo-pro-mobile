// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'moto_info.dart';
import 'package:tranoo_pro/services/user_service.dart';
import 'package:tranoo_pro/utils/role_redirect.dart';
import 'create_sell_moto.dart';
import 'package:tranoo_pro/utils/article_list_sort.dart';
import 'package:tranoo_pro/utils/article_view_helper.dart';
import 'package:tranoo_pro/widgets/video_preview_placeholder.dart';
import 'package:tranoo_pro/utils/page_refresh_registry.dart';
import 'package:tranoo_pro/widgets/page_pull_refresh.dart';
import 'package:tranoo_pro/widgets/skeleton/app_skeleton.dart';
import 'package:tranoo_pro/utils/catalog_display.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';
import 'package:tranoo_pro/utils/catalog_filter_options.dart';
import 'package:tranoo_pro/widgets/catalog_filter_sections.dart';

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

class MotosPage extends StatefulWidget {
  const MotosPage({super.key});

  @override
  State<MotosPage> createState() => _MotosPageState();
}

class _MotosPageState extends State<MotosPage>
    with SingleTickerProviderStateMixin, RegisterPageRefresh {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  Future<void> onPagePullRefresh() async => fetchMotos();
  List<dynamic> motos = [];
  bool isLoading = true;
  String? error;
  List<bool> _isVisible = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";

  // Filtres
  String? _selectedBrand;
  String? _selectedModel;
  String? _selectedLocation;
  double? _budgetMin;
  double? _budgetMax;

  // TabController pour les filtres
  late TabController _tabController;
  late int _marqueTabIndex;
  late int _modeleTabIndex;
  late int _localisationTabIndex;
  late int _budgetTabIndex;
  late int _statusOnlineTabIndex;
  late int _statusRejectedTabIndex;

  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();

    // Initialisation des indices des onglets selon le rôle
    final isVendeur = _userService.currentRole == UserRole.vendeur;
    if (isVendeur) {
      // Vendeur: 5 onglets (2 filtres + 3 statuts)
      _marqueTabIndex = 0;
      _modeleTabIndex = 1;
      _statusOnlineTabIndex = 2;
      _statusRejectedTabIndex = 3;
      _tabController = TabController(length: 4, vsync: this);
    } else {
      // Autres rôles: tous les filtres
      _marqueTabIndex = 0;
      _modeleTabIndex = 1;
      _localisationTabIndex = 2;
      _budgetTabIndex = 3;
      _tabController = TabController(length: 4, vsync: this);
    }

    _tabController.addListener(() {
      setState(() {});
    });

    fetchMotos();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  double _computeCardAspectRatio(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) return 0.58;
    if (screenWidth < 420) return 0.59;
    if (screenWidth < 520) return 0.7;
    return 0.78;
  }

  void _reloadAll() {
    // Réinitialiser la recherche
    _searchController.clear();
    _searchText = '';

    // Réinitialiser les filtres
    _selectedBrand = null;
    _selectedModel = null;
    _selectedLocation = null;
    _budgetMin = null;
    _budgetMax = null;

    // Recharger les données
    fetchMotos();
    setState(() {});
  }

  Future<void> fetchMotos() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      final userService = UserService();
      final role = userService.currentRole;
      final userId = user?.uid;
      String url = getBaseUrl() + '/articles?type=moto';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final List<dynamic> data = sortArticleMapsNewestFirst(
          jsonDecode(response.body) as List<dynamic>,
        );
        setState(() {
          motos = data;
          _isVisible = List.generate(data.length, (index) => true);
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Erreur lors du chargement des Motos';
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

  Future<void> _deleteMoto(String articleId, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmDeletion),
        content: Text(l10n.confirmDeleteCar,
        ),
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
          SnackBar(content: Text(l10n.carDeletedSuccess)),
        );
        fetchMotos();
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

  // Appliquer les filtres
  List<dynamic> _applyFilters(List<dynamic> source) {
    final isVendeur = _userService.currentRole == UserRole.vendeur;
    return source.where((v) {
      if (_selectedBrand != null && _selectedBrand!.isNotEmpty) {
        final marque = (v['marque'] ?? '').toString();
        if (!catalogValueMatches(_selectedBrand, marque)) return false;
      }
      if (_selectedModel != null && _selectedModel!.isNotEmpty) {
        final typeMoto = (v['typeMoto'] ?? '').toString();
        if (!catalogValueMatches(_selectedModel, typeMoto)) return false;
      }
      if (_selectedLocation != null && _selectedLocation!.isNotEmpty) {
        final loc = [
          v['localisation'],
          v['lieu'],
          v['entreprise'],
          v['description'],
          v['titre'],
        ].map((e) => e?.toString() ?? '').join(' ');
        if (!catalogValueMatches(_selectedLocation, loc)) return false;
      }
      if (_budgetMin != null || _budgetMax != null) {
        final prixStr = (v['prix'] ?? '').toString();
        final price =
            double.tryParse(prixStr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
        if (_budgetMin != null && price < _budgetMin!) return false;
        if (_budgetMax != null && price > _budgetMax!) return false;
      }
      if (isVendeur) {
        final statut = (v['statut'] ?? '').toString().toLowerCase();
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
    if (isLoading && motos.isEmpty) {
      return const CatalogFilterHorizSkeleton();
    }
    final options = buildMarqueFilterOptions(motos, isPiece: false, isMoto: true);
    return CatalogMarqueFilterGrid(
      options: options,
      selected: _selectedBrand,
      onSelected: (v) => setState(() => _selectedBrand = v),
    );
  }

  Widget _buildTypeMotoSection() {
    if (isLoading && motos.isEmpty) {
      return const CatalogFilterHorizSkeleton(itemWidth: 88, height: 60);
    }
    final types = buildMotoTypeFilterOptions();
    return CatalogModeleFilterGrid(
      modeles: types,
      selected: _selectedModel,
      onSelected: (v) => setState(() => _selectedModel = v),
    );
  }

  Widget _buildLocalisationSection() {
    if (isLoading && motos.isEmpty) {
      return const CatalogFilterHorizSkeleton();
    }
    final options = buildLocationFilterOptions(motos);
    return CatalogLocationFilterGrid(
      options: options,
      selected: _selectedLocation,
      onSelected: (v) => setState(() => _selectedLocation = v),
    );
  }

  Widget _buildBudgetSection() {
    return CatalogBudgetFilterPanel(
      articles: motos,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final userService = UserService();
    final isVendeur = userService.currentRole == UserRole.vendeur;

    final filteredMotos = _applyFilters(motos).where((v) {
      final titre = ((v['marque'] ?? '').toString() +
              ' ' +
              (v['modele']?.toString() ?? ''))
          .toLowerCase();
      final alt = (v['titre'] ?? '').toString().toLowerCase();
      if (_searchText.isEmpty) return true;
      return titre.contains(_searchText) || alt.contains(_searchText);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(isVendeur ? 'Mes Motos' : 'Motos en ligne'),
        backgroundColor: Colors.amber,
        actions: [
          if (isVendeur)
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateSellMotoPage(),
                  ),
                );
              },
            ),
        ],
      ),
      body: PagePullRefresh(
        onRefresh: () => fetchMotos(),
        refreshSkeleton: SkeletonPresets.sellerCatalog(),
        child: isLoading && motos.isEmpty
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
                    // Barre de recherche
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: l10n.searchCarHint,
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
                            _buildTabButton("Marque", _marqueTabIndex),
                            _buildTabButton('Type', _modeleTabIndex),
                            if (isVendeur)
                              _buildTabButton("En ligne", _statusOnlineTabIndex, isWide: true),
                            if (isVendeur)
                              _buildTabButton("Rejeté", _statusRejectedTabIndex, isWide: true),
                            if (!isVendeur)
                              _buildTabButton(
                                "Localisation",
                                _localisationTabIndex,
                                isWide: true,
                              ),
                            if (!isVendeur)
                              _buildTabButton("Budget", _budgetTabIndex),
                          ],
                        ),
                      ),
                    ),
                    // Sections de filtres
                    if (_tabController.index == _marqueTabIndex)
                      _buildMarqueSection(),
                    if (_tabController.index == _modeleTabIndex)
                      _buildTypeMotoSection(),
                    if (!isVendeur &&
                        _tabController.index == _localisationTabIndex)
                      _buildLocalisationSection(),
                    // Liste des Motos
                    Expanded(
                      child: filteredMotos.isEmpty
                          ? Center(
                              child: Text(
                                isVendeur
                                    ? "Vous n'avez aucune Moto publiée"
                                    : "Aucune Moto disponible pour le moment.",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 13.0),
                              child: GridView.builder(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio:
                                      _computeCardAspectRatio(context),
                                ),
                                itemCount: filteredMotos.length,
                                itemBuilder: (context, index) {
                                  final moto = filteredMotos[index];
                                  return AnimatedOpacity(
                                    opacity: _isVisible.length > index &&
                                            _isVisible[index]
                                        ? 1.0
                                        : 0.0,
                                    duration: const Duration(milliseconds: 400),
                                    child: Stack(
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            final articleMap =
                                                Map<String, dynamic>.from(moto);
                                            trackArticleView(
                                                articleIdFromMap(articleMap));
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    MotoInfo.fromArticleMap(
                                                  Map<String, dynamic>.from(
                                                      moto),
                                                ),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.grey
                                                      .withOpacity(0.2),
                                                  spreadRadius: 2,
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                ),
                                                BoxShadow(
                                                  color: Colors.grey
                                                      .withOpacity(0.1),
                                                  spreadRadius: 1,
                                                  blurRadius: 5,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // Image avec overlay
                                                Expanded(
                                                  flex: 3,
                                                  child: Stack(
                                                    children: [
                                                      ClipRRect(
                                                        borderRadius:
                                                            const BorderRadius
                                                                .only(
                                                          topLeft:
                                                              Radius.circular(
                                                                  12),
                                                          topRight:
                                                              Radius.circular(
                                                                  12),
                                                        ),
                                                        child: (moto['photos']
                                                                        as List?)
                                                                    ?.isNotEmpty ==
                                                                true
                                                            ? Image.network(
                                                                moto['photos']
                                                                    [0],
                                                                height: double
                                                                    .infinity,
                                                                width: double
                                                                    .infinity,
                                                                fit: BoxFit
                                                                    .cover,
                                                              )
                                                            : (moto['video'] !=
                                                                        null &&
                                                                    (moto['video']
                                                                            ?.toString()
                                                                            .isNotEmpty ??
                                                                        false))
                                                                ? VideoPreviewPlaceholder(
                                                                    videoUrl: moto[
                                                                            'video']
                                                                        ?.toString(),
                                                                    enablePreviewFrame:
                                                                        false,
                                                                  )
                                                                : Container(
                                                                    height: double
                                                                        .infinity,
                                                                    width: double
                                                                        .infinity,
                                                                    color: Colors
                                                                            .grey[
                                                                        300],
                                                                    child:
                                                                        const Icon(
                                                                      Icons
                                                                          .image_not_supported,
                                                                    ),
                                                                  ),
                                                      ),
                                                      // Badge condition
                                                      Positioned(
                                                        top: 8,
                                                        left: 8,
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: ((moto['condition'] ??
                                                                                '')
                                                                            .toString()
                                                                            .toLowerCase() ==
                                                                        'nouveau' ||
                                                                    (moto['condition'] ??
                                                                                '')
                                                                            .toString()
                                                                            .toLowerCase() ==
                                                                        'neuf')
                                                                ? Colors.purple
                                                                : const Color(
                                                                    0xFFF8BF13),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        50),
                                                          ),
                                                          child: Text(
                                                            ((moto['condition'] ??
                                                                                '')
                                                                            .toString()
                                                                            .toLowerCase() ==
                                                                        'nouveau' ||
                                                                    (moto['condition'] ??
                                                                                '')
                                                                            .toString()
                                                                            .toLowerCase() ==
                                                                        'neuf')
                                                                ? 'Nouveau'
                                                                : 'Occasion',
                                                            style:
                                                                const TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      Positioned(
                                                        top: 8,
                                                        right: 8,
                                                        child: Builder(
                                                          builder: (context) {
                                                            final status =
                                                                (moto['statut'] ?? '')
                                                                    .toString()
                                                                    .toLowerCase();
                                                            Color bg;
                                                            Color fg;
                                                            String label;
                                                            if (status == 'en_ligne') {
                                                              bg = const Color(0xFFE8F5E9);
                                                              fg = const Color(0xFF2E7D32);
                                                              label = 'En ligne';
                                                            } else if (status == 'en_attente') {
                                                              bg = const Color(0xFFFFF8E1);
                                                              fg = const Color(0xFFB45309);
                                                              label = 'En attente';
                                                            } else {
                                                              bg = const Color(0xFFFFEBEE);
                                                              fg = const Color(0xFFC62828);
                                                              label = 'Rejeté';
                                                            }
                                                            return Container(
                                                              padding: const EdgeInsets.symmetric(
                                                                  horizontal: 8, vertical: 4),
                                                              decoration: BoxDecoration(
                                                                color: bg,
                                                                borderRadius:
                                                                    BorderRadius.circular(10),
                                                              ),
                                                              child: Text(
                                                                label,
                                                                style: TextStyle(
                                                                  color: fg,
                                                                  fontWeight: FontWeight.w700,
                                                                  fontSize: 10,
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                      Positioned(
                                                        bottom: 8,
                                                        left: 8,
                                                        child: buildArticleViewBadge(
                                                          articleViewsFromMap(
                                                            Map<String, dynamic>.from(moto),
                                                          ),
                                                        ),
                                                      ),
                                                      if (isVendeur)
                                                        Positioned(
                                                          right: 6,
                                                          bottom: 6,
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize.min,
                                                            children: [
                                                              _sellerCardAction(
                                                                icon: Icons.edit,
                                                                color: const Color(
                                                                    0xFF0461B6),
                                                                onPressed: () {
                                                                  final id = (moto['_id'] ??
                                                                          moto['id'] ??
                                                                          moto['articleId'] ??
                                                                          moto['Id'] ??
                                                                          moto['article'])
                                                                      ?.toString();
                                                                  Navigator.push(
                                                                    context,
                                                                    MaterialPageRoute(
                                                                      builder: (context) =>
                                                                          CreateSellMotoPage(
                                                                        editMode: true,
                                                                        editArticleId: id,
                                                                        initialData: Map<String, dynamic>.from(moto),
                                                                      ),
                                                                    ),
                                                                  ).then((_) => fetchMotos());
                                                                },
                                                              ),
                                                              const SizedBox(width: 6),
                                                              _sellerCardAction(
                                                                icon: Icons.close,
                                                                color: Colors.red,
                                                                onPressed: () {
                                                                  _deleteMoto(
                                                                    moto['_id'] ?? '',
                                                                    index,
                                                                  );
                                                                },
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                // Informations de la Moto
                                                Expanded(
                                                  flex: 2,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        catalogVehicleInfoFooter(
                                                          title: vehicleTitleFromMap(
                                                            Map<String, dynamic>.from(moto),
                                                          ),
                                                          prix: moto['prix'],
                                                        ),
                                                        const SizedBox(
                                                            height: 6),
                                                        Expanded(
                                                          child: Column(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .spaceAround,
                                                            children: [
                                                              // Rangée 1: Transmission + Année
                                                              Row(
                                                                children: [
                                                                  Expanded(
                                                                    child:
                                                                        _buildCaracteristic(
                                                                      Icons
                                                                          .settings,
                                                                      moto['transmission']
                                                                              ?.toString() ??
                                                                          '',
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                      width: 4),
                                                                  Expanded(
                                                                    child:
                                                                        _buildCaracteristic(
                                                                      Icons
                                                                          .calendar_today,
                                                                      moto['annee']
                                                                              ?.toString() ??
                                                                          '',
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              // Rangée 2: Type moteur + Cylindrée
                                                              Row(
                                                                children: [
                                                                  Expanded(
                                                                    child:
                                                                        _buildCaracteristic(
                                                                      Icons
                                                                          .local_gas_station,
                                                                      moto['typeMoteur']
                                                                              ?.toString() ??
                                                                          '',
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                      width: 4),
                                                                  Expanded(
                                                                    child:
                                                                        _buildCaracteristic(
                                                                      Icons
                                                                          .speed,
                                                                      moto['cylindre']
                                                                              ?.toString() ??
                                                                          '',
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              // Rangée 3: Type moto + Puissance
                                                              Row(
                                                                children: [
                                                                  Expanded(
                                                                    child:
                                                                        _buildCaracteristic(
                                                                      Icons
                                                                          .two_wheeler,
                                                                      moto['typeMoto']
                                                                              ?.toString() ??
                                                                          '',
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                      width: 4),
                                                                  Expanded(
                                                                    child:
                                                                        _buildCaracteristic(
                                                                      Icons
                                                                          .bolt,
                                                                      moto['puissance']
                                                                              ?.toString() ??
                                                                          '',
                                                                    ),
                                                                  ),
                                                                ],
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
