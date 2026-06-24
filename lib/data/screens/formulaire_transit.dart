import 'package:flutter/material.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';
import 'package:tranoo_pro/services/transit_mission_service.dart';
import 'package:tranoo_pro/widgets/transitaire_profile_ui.dart';

class FormulaireTransitPage extends StatefulWidget {
  final Map<String, dynamic>? mission;

  const FormulaireTransitPage({super.key, this.mission});

  @override
  State<FormulaireTransitPage> createState() => _FormulaireTransitPageState();
}

class _FormulaireTransitPageState extends State<FormulaireTransitPage> {
  final TransitMissionService _missionService = TransitMissionService.instance;
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _missions = [];
  Map<String, dynamic>? _selectedMission;
  bool _loadingMissions = true;
  bool _submitting = false;

  late final TextEditingController _portDepartController;
  late final TextEditingController _portArriveeController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _portDepartController = TextEditingController();
    _portArriveeController = TextEditingController();
    _notesController = TextEditingController();
    _selectedMission = widget.mission;
    _loadMissions();
  }

  @override
  void dispose() {
    _portDepartController.dispose();
    _portArriveeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadMissions() async {
    final missions = await _missionService.listAllMissions();
    if (!mounted) return;
    setState(() {
      _missions = missions
          .where((m) => m['statut'] != 'traite')
          .toList();
      _loadingMissions = false;
      if (_selectedMission == null && _missions.isNotEmpty) {
        _selectedMission = _missions.first;
      }
      _fillFromMission(_selectedMission);
    });
  }

  void _fillFromMission(Map<String, dynamic>? mission) {
    if (mission == null) {
      _portDepartController.clear();
      _portArriveeController.clear();
      _notesController.clear();
      return;
    }
    final article = mission['article'];
    final lieu = article is Map ? (article['lieu'] ?? '').toString() : '';
    _portDepartController.text = lieu;
    _portArriveeController.text =
        (mission['paysDestination'] ?? '').toString();
    _notesController.text =
        (mission['detailsSupplementaires'] ?? '').toString();
  }

  String _missionTitle(Map<String, dynamic> mission) {
    final article = mission['article'];
    if (article is! Map) return 'Mission';
    final titre = (article['titre'] ?? '').toString().trim();
    if (titre.isNotEmpty) return titre;
    final marque = (article['marque'] ?? '').toString().trim();
    final modele = (article['modele'] ?? '').toString().trim();
    return '$marque $modele'.trim();
  }

  String _clientName(Map<String, dynamic> mission) {
    final acheteur = mission['acheteur'];
    if (acheteur is! Map) return '';
    return '${acheteur['prenoms'] ?? ''} ${acheteur['nom'] ?? ''}'.trim();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    final mission = _selectedMission;
    if (mission == null) {
      showTranooToast(
        context,
        message: 'Sélectionnez une mission à renseigner',
        isError: true,
      );
      return;
    }

    final missionId = mission['_id']?.toString();
    if (missionId == null) return;

    setState(() => _submitting = true);
    final result = await _missionService.updateMissionDetails(
      missionId: missionId,
      paysDestination: _portArriveeController.text.trim(),
      detailsSupplementaires: _notesController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result != null) {
      showTranooToast(context, message: 'Informations de transit enregistrées');
      Navigator.pop(context, true);
    } else {
      showTranooToast(
        context,
        message: 'Impossible d\'enregistrer les informations',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mission = _selectedMission;
    final article = mission?['article'];
    final voiture = mission != null ? _missionTitle(mission) : '';
    final client = mission != null ? _clientName(mission) : '';

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
          'Renseigner un transit',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: kTransitaireNavy,
          ),
        ),
      ),
      body: _loadingMissions
          ? const Center(child: CircularProgressIndicator(color: kTransitaireAmber))
          : _missions.isEmpty && widget.mission == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 56, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'Aucune mission active',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Les transits sont créés lorsqu\'un acheteur vous sélectionne sur l\'application.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.mission == null) ...[
                          _buildSectionTitle('Mission'),
                          const SizedBox(height: 8),
                          _buildMissionDropdown(),
                          const SizedBox(height: 20),
                        ],
                        _buildSectionTitle('Véhicule & client'),
                        const SizedBox(height: 8),
                        _buildReadOnlyField('Véhicule', voiture),
                        const SizedBox(height: 12),
                        _buildReadOnlyField('Client', client),
                        const SizedBox(height: 20),
                        _buildSectionTitle('Itinéraire'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _portDepartController,
                          label: 'Lieu de départ',
                          hint: 'Anvers, Belgique',
                          readOnly: true,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _portArriveeController,
                          label: 'Pays / port d\'arrivée',
                          hint: 'Cotonou, Bénin',
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Champ requis'
                                  : null,
                        ),
                        const SizedBox(height: 20),
                        _buildSectionTitle('Notes & documents'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _notesController,
                          label: 'Détails supplémentaires',
                          hint: 'Connaissement, certificat, remarques…',
                          maxLines: 4,
                        ),
                        if (article is Map &&
                            (article['photos'] as List?)?.isNotEmpty == true) ...[
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              article['photos'][0].toString(),
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _submitting ? null : _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kTransitaireNavy,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  kTransitaireNavy.withOpacity(0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    l10n.submit,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: kTransitaireNavy,
      ),
    );
  }

  Widget _buildMissionDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          isExpanded: true,
          value: _selectedMission,
          hint: const Text('Choisir une mission'),
          items: _missions
              .map(
                (m) => DropdownMenuItem(
                  value: m,
                  child: Text(
                    '${_missionTitle(m)} — ${_clientName(m)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (m) {
            setState(() {
              _selectedMission = m;
              _fillFromMission(m);
            });
          },
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isNotEmpty ? value : '—',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: kTransitaireNavy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool readOnly = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: kTransitaireNavy,
                fontSize: 13,
              ),
            ),
            if (validator != null)
              const Text(' *', style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kTransitaireAmber, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
