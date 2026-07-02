import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tranoo_pro/data/screens/cars_info.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';
import 'package:tranoo_pro/services/transit_mission_service.dart';
import 'package:tranoo_pro/services/user_service.dart';
import 'package:tranoo_pro/widgets/transitaire_profile_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tranoo_pro/widgets/cached_media_image.dart';

class Transit extends StatefulWidget {
  const Transit({super.key});

  @override
  State<Transit> createState() => _TransitState();
}

class _TransitState extends State<Transit> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TransitMissionService _missionService = TransitMissionService.instance;
  String? currentUserId;

  List<Map<String, dynamic>> enCours = [];
  List<Map<String, dynamic>> transferer = [];
  List<Map<String, dynamic>> traite = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _getCurrentUserId();
    _loadMissions();
  }

  Future<void> _getCurrentUserId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final response = await UserService().dio.get(
        '/protected/me',
        options: Options(
          headers: {'Authorization': 'Bearer ${await user.getIdToken()}'},
        ),
      );
      if (response.statusCode == 200 && mounted) {
        setState(() {
          currentUserId = response.data['user']['_id']?.toString();
        });
      }
    } catch (_) {
      if (mounted) setState(() => currentUserId = user.uid);
    }
  }

  Future<void> _loadMissions() async {
    setState(() => isLoading = true);
    try {
      final results = await Future.wait([
        _missionService.listMissions('en_cours'),
        _missionService.listMissions('transferer'),
        _missionService.listMissions('traite'),
        _missionService.listMissions('annule'),
      ]);
      if (mounted) {
        setState(() {
          enCours = [...results[0], ...results[3]];
          transferer = results[1];
          traite = results[2];
          isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Map<String, dynamic> _mapMission(Map<String, dynamic> mission) {
    final article = mission['article'];
    final acheteur = mission['acheteur'];
    final photos = article is Map ? (article['photos'] as List?) : null;
    final image = photos != null && photos.isNotEmpty
        ? photos.first?.toString()
        : null;
    final titre = article is Map ? (article['titre'] ?? '') : '';
    final marque = article is Map ? (article['marque'] ?? '') : '';
    final modele = article is Map ? (article['modele'] ?? '') : '';
    final annee = article is Map ? (article['annee'] ?? '') : '';
    final prix = article is Map ? article['prix'] : null;
    final acheteurNom = acheteur is Map
        ? '${acheteur['prenoms'] ?? ''} ${acheteur['nom'] ?? ''}'.trim()
        : '';
    final acheteurPhone =
        acheteur is Map ? (acheteur['telephone'] ?? '').toString().trim() : '';

    return {
      'mission': mission,
      'missionId': mission['_id'],
      'article': article,
      'title': titre.toString().isNotEmpty ? titre : '$marque $modele'.trim(),
      'description': [annee, marque, modele]
          .where((e) => e.toString().trim().isNotEmpty)
          .join(' · '),
      'price': prix != null ? '$prix f' : '',
      'image': image,
      'client': acheteurNom,
      'clientPhone': acheteurPhone,
    };
  }

  Future<void> _rejeterMission(Map<String, dynamic> item) async {
    final missionId = item['missionId']?.toString();
    if (missionId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refuser cette mission ?'),
        content: const Text(
          'L\'acheteur sera notifié et pourra choisir un autre transitaire.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Refuser'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final result = await withTranooLoading(
      context,
      () => _missionService.rejeterAttribution(missionId),
    );
    if (!mounted) return;

    if (result.ok) {
      showTranooToast(context, message: 'Mission refusée — acheteur notifié');
      _loadMissions();
    } else {
      showTranooToast(
        context,
        message: result.error ?? 'Impossible de refuser la mission',
        isError: true,
      );
    }
  }

  Future<void> _openDetails(Map<String, dynamic> item) async {
    final mission = item['mission'];
    if (mission is! Map) return;
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CarsInfo.fromTransitMission(
          Map<String, dynamic>.from(mission),
        ),
      ),
    );
    if (updated == true) _loadMissions();
  }

  Future<void> _callBuyer(Map<String, dynamic> item) async {
    final phone = (item['clientPhone'] ?? '').toString().trim();
    if (phone.isEmpty) {
      showTranooToast(
        context,
        message: 'Numéro de l\'acheteur indisponible',
        isError: true,
      );
      return;
    }

    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  item['client']?.toString().isNotEmpty == true
                      ? item['client'].toString()
                      : 'Contacter l\'acheteur',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: kTransitaireNavy,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.phone_rounded, color: kTransitaireNavy),
                  title: const Text('Appeler'),
                  subtitle: Text(phone),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final uri = Uri.parse('tel:$digits');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
                  title: const Text('WhatsApp'),
                  subtitle: Text(phone),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final waDigits = digits.replaceAll(RegExp(r'[^0-9]'), '');
                    final uri = Uri.parse('https://wa.me/$waDigits');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _marquerTraite(Map<String, dynamic> item) async {
    final missionId = item['missionId']?.toString();
    if (missionId == null) return;
    final ok = await _missionService.marquerTraite(missionId);
    if (!mounted) return;
    if (ok) {
      showTranooToast(context, message: 'Mission marquée comme traitée');
      _loadMissions();
    } else {
      showTranooToast(
        context,
        message: 'Impossible de marquer la mission',
        isError: true,
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: kTransitaireAmber,
              indicatorWeight: 3,
              labelColor: kTransitaireNavy,
              unselectedLabelColor: Colors.grey.shade500,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              tabs: const [
                Tab(text: 'En cours'),
                Tab(text: 'Transférer'),
                Tab(text: 'Traité'),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: kTransitaireAmber,
              onRefresh: _loadMissions,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMissionList(enCours, 'en_cours'),
                  _buildMissionList(transferer, 'transferer'),
                  _buildMissionList(traite, 'traite'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionList(List<Map<String, dynamic>> list, String statut) {
    final l10n = AppLocalizations.of(context)!;
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (list.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Center(child: Text(l10n.noArticlesInCategory)),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = _mapMission(list[index]);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          elevation: 2,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildThumb(item['image']?.toString()),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(item['description'] ?? ''),
                          if ((item['client'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('Client : ${item['client']}'),
                          ],
                          if ((item['price'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item['price'].toString(),
                              style: const TextStyle(
                                color: kTransitaireAmber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildActions(item, statut),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThumb(String? image) {
    if (image != null && image.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedMediaImage(
          url: image,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          cloudinaryWidthPx: 144,
          errorWidget: _thumbPlaceholder(),
        ),
      );
    }
    return _thumbPlaceholder();
  }

  Widget _thumbPlaceholder() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.directions_car, color: Colors.grey),
    );
  }

  Widget _actionBtn({
    required String label,
    required VoidCallback onPressed,
    bool primary = false,
    bool outline = false,
  }) {
    if (outline) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: kTransitaireNavy,
          side: const BorderSide(color: kTransitaireAmber),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        child: Text(label),
      );
    }
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: primary ? kTransitaireAmber : kTransitaireNavy,
        foregroundColor: primary ? kTransitaireNavy : Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      child: Text(label),
    );
  }

  Widget _buildActions(Map<String, dynamic> item, String statut) {
    final mission = item['mission'];
    final missionStatut = mission is Map
        ? (mission['statut'] ?? statut).toString()
        : statut;
    if (missionStatut == 'annule') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFB3261E).withOpacity(0.3)),
            ),
            child: Text(
              AppLocalizations.of(context)!.transitMissionPurchaseCancelled,
              style: const TextStyle(
                color: Color(0xFFB3261E),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _actionBtn(
            label: 'Voir détails',
            onPressed: () => _openDetails(item),
            outline: true,
          ),
        ],
      );
    }
    if (statut == 'en_cours') {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _actionBtn(
                  label: 'Voir détails',
                  onPressed: () => _openDetails(item),
                  outline: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionBtn(
                  label: 'Appeler l\'acheteur',
                  onPressed: () => _callBuyer(item),
                  primary: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _rejeterMission(item),
              style: OutlinedButton.styleFrom(
                foregroundColor: kTransitaireNavy,
                side: const BorderSide(color: kTransitaireAmber),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('Refuser la mission'),
            ),
          ),
        ],
      );
    }

    if (statut == 'transferer') {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _actionBtn(
                  label: 'Voir détails',
                  onPressed: () => _openDetails(item),
                  outline: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionBtn(
                  label: 'Appeler l\'acheteur',
                  onPressed: () => _callBuyer(item),
                  primary: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: _actionBtn(
              label: 'Marquer traité',
              onPressed: () => _marquerTraite(item),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: _actionBtn(
        label: 'Voir détails',
        onPressed: () => _openDetails(item),
        outline: true,
      ),
    );
  }
}
