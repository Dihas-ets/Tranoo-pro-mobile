import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tranoo_pro/data/screens/formulaire_transit.dart';
import 'package:tranoo_pro/services/chat_service.dart';
import 'package:tranoo_pro/services/transit_mission_service.dart';
import 'package:tranoo_pro/widgets/transitaire_profile_ui.dart';

// ─── Durée du polling périodique ─────────────────────────────────────────────
const _kPollInterval = Duration(seconds: 30);

// ─── Seuil de scroll pour déclencher le refresh bas de page ─────────────────
const _kScrollRefreshThreshold = 80.0;

class HistoriqueTransitPage extends StatefulWidget {
  const HistoriqueTransitPage({super.key});

  @override
  State<HistoriqueTransitPage> createState() => _HistoriqueTransitPageState();
}

class _HistoriqueTransitPageState extends State<HistoriqueTransitPage> {
  final TransitMissionService _missionService = TransitMissionService.instance;
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _missions = [];

  /// `true` uniquement au premier chargement (affiche les skeletons).
  bool _initialLoading = true;

  /// `true` lors d'un refresh silencieux (polling / socket / pull-to-refresh).
  bool _refreshing = false;

  /// `true` quand l'utilisateur a tiré le scroll vers le bas pour recharger.
  bool _bottomRefreshing = false;

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
    _startPolling();
    _listenToSocket();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    // Retirer le listener socket proprement
    ChatService().offTransitUpdate(_onSocketTransitUpdate);
    super.dispose();
  }

  // ─── Chargement ──────────────────────────────────────────────────────────

  Future<void> _load({bool initial = false, bool silent = false}) async {
    if (!mounted) return;
    if (initial) {
      setState(() => _initialLoading = true);
    } else if (!silent) {
      setState(() => _refreshing = true);
    }

    final missions = await _missionService.listAllMissions();

    if (!mounted) return;
    setState(() {
      _missions = missions;
      _initialLoading = false;
      _refreshing = false;
      _bottomRefreshing = false;
    });
  }

  // ─── Polling périodique ───────────────────────────────────────────────────

  void _startPolling() {
    _pollTimer = Timer.periodic(_kPollInterval, (_) {
      if (mounted) _load(silent: true);
    });
  }

  // ─── WebSocket ────────────────────────────────────────────────────────────

  void _listenToSocket() {
    ChatService().onTransitUpdate = _onSocketTransitUpdate;
  }

  void _onSocketTransitUpdate(Map<String, dynamic> data) {
    // Recharge la liste dès qu'une mise à jour de mission arrive
    if (mounted) _load(silent: true);
  }

  // ─── Scroll vers le bas → refresh ────────────────────────────────────────

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    // Ne déclencher que si la liste est assez grande pour scroller
    if (pos.maxScrollExtent <= 0) return;
    final distanceFromBottom = pos.maxScrollExtent - pos.pixels;
    if (distanceFromBottom < _kScrollRefreshThreshold &&
        !_bottomRefreshing &&
        !_initialLoading) {
      setState(() => _bottomRefreshing = true);
      _load(silent: true);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _missionTitle(Map<String, dynamic> mission) {
    final article = mission['article'];
    if (article is! Map) return 'Véhicule';
    final titre = (article['titre'] ?? '').toString().trim();
    if (titre.isNotEmpty) return titre;
    final marque = (article['marque'] ?? '').toString().trim();
    final modele = (article['modele'] ?? '').toString().trim();
    final annee  = (article['annee']  ?? '').toString().trim();
    return [annee, marque, modele].where((e) => e.isNotEmpty).join(' ');
  }

  String _clientName(Map<String, dynamic> mission) {
    final acheteur = mission['acheteur'];
    if (acheteur is! Map) return '';
    return '${acheteur['prenoms'] ?? ''} ${acheteur['nom'] ?? ''}'.trim();
  }

  String _formatDate(dynamic value) {
    if (value == null) return '—';
    final dt = DateTime.tryParse(value.toString());
    if (dt == null) return value.toString();
    return DateFormat('d MMM yyyy', 'fr_FR').format(dt.toLocal());
  }

  ({String label, Color color}) _statutInfo(String? statut) {
    switch (statut) {
      case 'traite':
        return (label: 'Traité', color: Colors.green.shade700);
      case 'transferer':
        return (label: 'Transféré', color: Colors.blue.shade700);
      case 'en_cours':
        return (label: 'En cours', color: kTransitaireAmber);
      default:
        return (label: statut ?? '—', color: Colors.grey.shade700);
    }
  }

  Future<void> _openForm({Map<String, dynamic>? mission}) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FormulaireTransitPage(mission: mission),
      ),
    );
    if (updated == true) _load();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: kTransitaireNavy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: kTransitaireNavy),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Text(
              'Historique des transits',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: kTransitaireNavy,
              ),
            ),
            if (_refreshing) ...[
              const SizedBox(width: 10),
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: kTransitaireAmber,
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Renseigner un transit',
            icon: const Icon(Icons.add_rounded, color: kTransitaireAmber, size: 28),
            onPressed: () => _openForm(),
          ),
        ],
      ),
      body: _initialLoading
          ? _buildSkeletons()
          : RefreshIndicator(
              color: kTransitaireAmber,
              onRefresh: () => _load(),
              child: _missions.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
            ),
    );
  }

  // ─── Skeletons ────────────────────────────────────────────────────────────

  Widget _buildSkeletons() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: 5,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _SkeletonCard(),
      ),
    );
  }

  // ─── Liste vide ───────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Icon(Icons.local_shipping_outlined, size: 56, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Text(
          'Aucun transit pour le moment',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Les missions apparaîtront ici lorsqu\'un acheteur vous aura choisi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      ],
    );
  }

  // ─── Liste des missions ───────────────────────────────────────────────────

  Widget _buildList() {
    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _missions.length + 1, // +1 pour le footer de refresh bas
      itemBuilder: (context, index) {
        // Footer : indicateur de chargement en bas ou fin de liste
        if (index == _missions.length) {
          return _bottomRefreshing
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kTransitaireAmber,
                      ),
                    ),
                  ),
                )
              : const SizedBox(height: 8);
        }

        final mission = _missions[index];
        final statut = _statutInfo(mission['statut']?.toString());
        final article = mission['article'];
        final lieuDepart =
            article is Map ? (article['lieu'] ?? '').toString() : '';
        final paysArrivee = (mission['paysDestination'] ?? '').toString();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openForm(mission: mission),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _missionTitle(mission),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: kTransitaireNavy,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statut.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statut.label,
                          style: TextStyle(
                            color: statut.color,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _infoRow(Icons.person_outline_rounded, 'Client', _clientName(mission)),
                  if (lieuDepart.isNotEmpty)
                    _infoRow(Icons.flight_takeoff_rounded, 'Départ', lieuDepart),
                  if (paysArrivee.isNotEmpty)
                    _infoRow(Icons.flight_land_rounded, 'Destination', paysArrivee),
                  _infoRow(
                    Icons.calendar_today_outlined,
                    'Mis à jour',
                    _formatDate(mission['updatedAt']),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Voir / modifier',
                        style: TextStyle(
                          color: kTransitaireNavy.withOpacity(0.7),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: kTransitaireNavy.withOpacity(0.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Text(
            '$label : ',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Skeleton card ────────────────────────────────────────────────────────────

class _SkeletonCard extends StatefulWidget {
  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _bone(height: 18, width: double.infinity)),
                const SizedBox(width: 12),
                _bone(height: 22, width: 72),
              ],
            ),
            const SizedBox(height: 14),
            _bone(height: 12, width: 180),
            const SizedBox(height: 8),
            _bone(height: 12, width: 140),
            const SizedBox(height: 8),
            _bone(height: 12, width: 100),
          ],
        ),
      ),
    );
  }

  Widget _bone({required double height, required double width}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
