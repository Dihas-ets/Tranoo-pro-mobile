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
import 'package:tranoo_pro/utils/page_refresh_registry.dart';
import 'package:tranoo_pro/widgets/page_pull_refresh.dart';
import 'package:tranoo_pro/widgets/skeleton/app_skeleton.dart';

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
  late int _statusPendingTabIndex;
  late int _statusOnlineTabIndex;
  late int _statusRejectedTabIndex;

  final UserService _userService = UserService();
  final SubscriptionAccessService _subscriptionService =
      SubscriptionAccessService();
  SellerAccessStatus? _accessStatus;
  bool _loadingAccessStatus = true;

  @override
  void initState() {
    super.initState();

    // Initialisation des indices des onglets selon le rôle
    final isVendeur = _userService.currentRole == UserRole.vendeur;
    if (isVendeur) {
      // Vendeur: 5 onglets (2 filtres + 3 statuts)
      _marqueTabIndex = 0;
      _modeleTabIndex = 1;
      _statusPendingTabIndex = 2;
      _statusOnlineTabIndex = 3;
      _statusRejectedTabIndex = 4;
      _tabController = TabController(length: 5, vsync: this);
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

    fetchPieces();
    _refreshAccessStatus();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.toLowerCase();
      });
    });
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
    _selectedModel = null;
    _selectedLocation = null;
    _budgetMin = null;
    _budgetMax = null;

    // Recharger les données
    fetchPieces();
    setState(() {});
  }

  Future<void> fetchPieces() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      String url = getBaseUrl() + '/articles?type=piece';
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
        setState(() {
          pieces = data;
          _isVisible = List.generate(data.length, (index) => true);
          isLoading = false;
        });
      } else {
        debugPrint('[PIECES] HTTP ${response.statusCode}: ${response.body}');
        setState(() {
          error = response.statusCode == 401
              ? 'Session expirée. Reconnectez-vous.'
              : 'Erreur lors du chargement des pièces';
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[PIECES] fetchPieces exception: $e');
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
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer cette pièce ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
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
          const SnackBar(content: Text('Pièce supprimée avec succès !')),
        );
        fetchPieces();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la suppression.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur réseau ou serveur.')),
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
              child: const Text('Fermer'),
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
    return source.where((p) {
      if (_selectedBrand != null && _selectedBrand!.isNotEmpty) {
        final marque =
            (p['marque'] ?? p['pieceType'] ?? '').toString().toLowerCase();
        if (!marque.contains(_selectedBrand!.toLowerCase())) {
          return false;
        }
      }
      if (_selectedModel != null && _selectedModel!.isNotEmpty) {
        final modele = (p['modele'] ?? '').toString().toLowerCase();
        if (!modele.contains(_selectedModel!.toLowerCase())) {
          return false;
        }
      }
      if (_selectedLocation != null && _selectedLocation!.isNotEmpty) {
        final loc = ((p['localisation'] ?? '') + ' ' + (p['entreprise'] ?? ''))
            .toLowerCase();
        if (!loc.contains(_selectedLocation!.toLowerCase()) &&
            !((p['titre'] ?? '')
                .toString()
                .toLowerCase()
                .contains(_selectedLocation!.toLowerCase()))) {
          return false;
        }
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
        if (_tabController.index == _statusPendingTabIndex &&
            statut != 'en_attente') {
          return false;
        }
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
    final List<Map<String, String>> marques = [
      {"name": "Toyota", "image": "assets/images/Toyota.png"},
      {"name": "Nissan", "image": "assets/images/nissan.png"},
      {"name": "Ford", "image": "assets/images/ford.png"},
      {"name": "Hyundai", "image": "assets/images/hunydai.png"},
      {"name": "Honda", "image": "assets/images/honda.png"},
      {"name": "Kia", "image": "assets/images/kia.png"},
      {"name": "BMW", "image": "assets/images/bmw.png"},
      {"name": "Mercedes", "image": "assets/images/mercedes.png"},
      {"name": "Audi", "image": "assets/images/Audi.png"},
      {"name": "Volkswagen", "image": "assets/images/vw.png"},
      {"name": "Lexus", "image": "assets/images/lexus.png"},
      {"name": "Mazda", "image": "assets/images/mazda.webp"},
      {"name": "Chevrolet", "image": "assets/images/chevrolet.png"},
      {"name": "Jeep", "image": "assets/images/jeep.png"},
      {"name": "Peugeot", "image": "assets/images/peugeot.png"},
      {"name": "Renault", "image": "assets/images/renault.png"},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SizedBox(
        height: 70 + 16,
        child: GridView.builder(
          scrollDirection: Axis.horizontal,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            mainAxisExtent: 70,
          ),
          itemCount: marques.length,
          itemBuilder: (context, index) {
            final item = marques[index];
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedBrand = item["name"];
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: _selectedBrand == item["name"]
                      ? const Color(0xFFF8BF13)
                      : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _selectedBrand == item["name"]
                        ? const Color(0xFFF8BF13)
                        : const Color(0xFFE0E0E0),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: Image.asset(
                        item["image"] ?? '',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stack) {
                          return CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.grey.shade300,
                            child: Text(
                              (item["name"] ?? '??').substring(0, 1),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildModeleSection() {
    final List<String> modeles = [
      'Land Cruiser',
      'Patrol',
      'Altima',
      'RAV4',
      'Hilux',
      'Wrangler',
      'Civic',
      'Corolla',
      'Camry',
      'Accord',
      'Tucson',
      'Sportage',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SizedBox(
        height: 60 + 16,
        child: GridView.builder(
          scrollDirection: Axis.horizontal,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            mainAxisExtent: 80,
          ),
          itemCount: modeles.length,
          itemBuilder: (context, index) {
            final name = modeles[index];
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedModel = name;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: _selectedModel == name
                      ? const Color(0xFFF8BF13)
                      : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _selectedModel == name
                        ? const Color(0xFFF8BF13)
                        : const Color(0xFFE0E0E0),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    color: _selectedModel == name ? Colors.white : Colors.black,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLocalisationSection() {
    final List<Map<String, dynamic>> zones = [
      {"name": "Bénin", "image": "assets/images/benin.png"},
      {"name": "Mali", "image": "assets/images/mali.png"},
      {"name": "Niger", "image": "assets/images/niger.png"},
      {"name": "Burkina-Faso", "image": "assets/images/burkina.png"},
      {"name": "Côte d'Ivoire", "image": "assets/images/ci.webp"},
      {"name": "Sénégal", "image": "assets/images/senegal.png"},
      {"name": "Togo", "image": "assets/images/togo.webp"},
      {"name": "Ghana", "image": "assets/images/ghana.png"},
      {"name": "Nigéria", "image": "assets/images/nigeria.png"},
      {"name": "Maroc", "image": "assets/images/maroc.png"},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SizedBox(
        height: 106,
        child: GridView.builder(
          scrollDirection: Axis.horizontal,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            mainAxisExtent: 120,
          ),
          itemCount: zones.length,
          itemBuilder: (context, index) {
            final item = zones[index];
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedLocation = item["name"];
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: _selectedLocation == item["name"]
                      ? const Color(0xFFF8BF13)
                      : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _selectedLocation == item["name"]
                        ? const Color(0xFFF8BF13)
                        : const Color(0xFFE0E0E0),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 36,
                      height: 24,
                      child: Image.asset(item["image"], fit: BoxFit.contain),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item["name"],
                      style: TextStyle(
                        fontSize: 12,
                        color: _selectedLocation == item["name"]
                            ? Colors.white
                            : Colors.black,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBudgetSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF8BF13),
            foregroundColor: const Color(0xFF000000),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _openBudgetSheet,
          child: const Text('Filtrer par budget'),
        ),
      ),
    );
  }

  void _openBudgetSheet() {
    final List<double> prixList = pieces
        .map((p) => double.tryParse(
            (p['prix'] ?? '').toString().replaceAll(RegExp(r'[^0-9.]'), '')))
        .whereType<double>()
        .toList()
      ..sort();

    final double minPrice = prixList.isNotEmpty ? prixList.first : 0;
    final double maxPrice = prixList.isNotEmpty ? prixList.last : 200000;
    double currentMin = _budgetMin ?? minPrice;
    double currentMax = _budgetMax ?? maxPrice;

    final minCtl = TextEditingController(text: currentMin.toStringAsFixed(0));
    final maxCtl = TextEditingController(text: currentMax.toStringAsFixed(0));

    int compterDansIntervalle(double a, double b) {
      return pieces.where((p) {
        final prix = double.tryParse(
            (p['prix'] ?? '').toString().replaceAll(RegExp(r'[^0-9.]'), ''));
        if (prix == null) return false;
        return prix >= a && prix <= b;
      }).length;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final disponibles = compterDansIntervalle(currentMin, currentMax);
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'Prix (FCFA)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minCtl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Min.',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onChanged: (val) {
                            final v = double.tryParse(val) ?? currentMin;
                            setModalState(() {
                              currentMin = v.clamp(minPrice, currentMax);
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: maxCtl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Max.',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onChanged: (val) {
                            final v = double.tryParse(val) ?? currentMax;
                            setModalState(() {
                              currentMax = v.clamp(currentMin, maxPrice);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('$disponibles pièce(s) disponible(s)'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _budgetMin = null;
                              _budgetMax = null;
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('Réinitialiser'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF8BF13),
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () {
                            setState(() {
                              _budgetMin = currentMin;
                              _budgetMax = currentMax;
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('Appliquer'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                          hintText: 'Rechercher une pièce...',
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
                            _buildTabButton("Modèles", _modeleTabIndex),
                            if (isVendeur)
                              _buildTabButton(
                                  "En attente", _statusPendingTabIndex,
                                  isWide: true),
                            if (isVendeur)
                              _buildTabButton("En ligne", _statusOnlineTabIndex,
                                  isWide: true),
                            if (isVendeur)
                              _buildTabButton("Rejeté", _statusRejectedTabIndex,
                                  isWide: true),
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
                      _buildModeleSection(),
                    if (!isVendeur &&
                        _tabController.index == _localisationTabIndex)
                      _buildLocalisationSection(),
                    if (!isVendeur && _tabController.index == _budgetTabIndex)
                      _buildBudgetSection(),
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
                                    duration: const Duration(milliseconds: 400),
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
                                                  articleIdFromMap(articleMap));
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
                                                    title: piece['titre'] ?? '',
                                                    year: piece['annee'] ?? '',
                                                    description:
                                                        piece['description'] ??
                                                            '',
                                                    company:
                                                        piece['entreprise'] ??
                                                            '',
                                                    location:
                                                        piece['localisation'] ??
                                                            '',
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
                                                    pieceType:
                                                        piece['pieceType'],
                                                    video: piece['video'],
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
                                                    offset: const Offset(0, 6),
                                                  ),
                                                ],
                                              ),
                                              padding: const EdgeInsets.all(10),
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
                                                                ? Image.network(
                                                                    piece['photos']
                                                                        [0],
                                                                    fit: BoxFit
                                                                        .cover,
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
                                                                      )
                                                                    : Container(
                                                                        color: Colors
                                                                            .grey[200],
                                                                        child:
                                                                            const Icon(
                                                                          Icons
                                                                              .image_not_supported,
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
                                                                    vertical: 4,
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
                                                                      color: fg,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700,
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
                                                                    onPressed:
                                                                        canManagePieces
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
                                                                      width: 6),
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
                                                  Container(
                                                    width: double.infinity,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 5),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFFFFF5E5),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              14),
                                                    ),
                                                    child: Text(
                                                      piece['prix'] != null
                                                          ? "${formatPrice(piece['prix'])} FCFA"
                                                          : 'Prix non communiqué',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: const TextStyle(
                                                        color:
                                                            Color(0xFFB45309),
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ),
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
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black54,
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                                child: const Text(
                                                  'Abonnement expire',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
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
                  ],
                ),
      ),
    );
  }
}
