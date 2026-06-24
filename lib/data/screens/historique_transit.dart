import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tranoo_pro/data/screens/formulaire_transit.dart';
import 'package:tranoo_pro/services/transit_mission_service.dart';
import 'package:tranoo_pro/widgets/transitaire_profile_ui.dart';

class HistoriqueTransitPage extends StatefulWidget {
  const HistoriqueTransitPage({super.key});

  @override
  State<HistoriqueTransitPage> createState() => _HistoriqueTransitPageState();
}

class _HistoriqueTransitPageState extends State<HistoriqueTransitPage> {
  final TransitMissionService _missionService = TransitMissionService.instance;
  List<Map<String, dynamic>> _missions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final missions = await _missionService.listAllMissions();
    if (!mounted) return;
    setState(() {
      _missions = missions;
      _loading = false;
    });
  }

  String _missionTitle(Map<String, dynamic> mission) {
    final article = mission['article'];
    if (article is! Map) return 'Véhicule';
    final titre = (article['titre'] ?? '').toString().trim();
    if (titre.isNotEmpty) return titre;
    final marque = (article['marque'] ?? '').toString().trim();
    final modele = (article['modele'] ?? '').toString().trim();
    final annee = (article['annee'] ?? '').toString().trim();
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
        title: const Text(
          'Historique des transits',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: kTransitaireNavy,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Renseigner un transit',
            icon: const Icon(Icons.add_rounded, color: kTransitaireAmber, size: 28),
            onPressed: () => _openForm(),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: kTransitaireAmber,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: kTransitaireAmber))
            : _missions.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                      Icon(Icons.local_shipping_outlined,
                          size: 56, color: Colors.grey.shade400),
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
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _missions.length,
                    itemBuilder: (context, index) {
                      final mission = _missions[index];
                      final statut = _statutInfo(mission['statut']?.toString());
                      final article = mission['article'];
                      final lieuDepart = article is Map
                          ? (article['lieu'] ?? '').toString()
                          : '';
                      final paysArrivee =
                          (mission['paysDestination'] ?? '').toString();

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
                                _infoRow(Icons.person_outline_rounded,
                                    'Client', _clientName(mission)),
                                if (lieuDepart.isNotEmpty)
                                  _infoRow(Icons.flight_takeoff_rounded,
                                      'Départ', lieuDepart),
                                if (paysArrivee.isNotEmpty)
                                  _infoRow(Icons.flight_land_rounded,
                                      'Destination', paysArrivee),
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
                  ),
      ),
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
