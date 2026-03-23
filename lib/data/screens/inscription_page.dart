import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tranoo_pro/services/user_service.dart';
import 'package:tranoo_pro/widgets/auth_message_popup.dart';

import 'connexion_page.dart'; // Assurez-vous que ce fichier existe

class InscriptionPage extends StatefulWidget {
  const InscriptionPage({super.key});

  @override
  State<InscriptionPage> createState() => _InscriptionPageState();
}

class _InscriptionPageState extends State<InscriptionPage> {
  // Contrôleurs pour les champs du formulaire
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _prenomController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telephoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _maisonController = TextEditingController();
  final TextEditingController _entrepriseProvenanceController =
      TextEditingController();
  final TextEditingController _referralController = TextEditingController();
  // Contrôleurs pour les champs véhicule (livreur/chauffeur)
  final TextEditingController _immatriculationController = TextEditingController();
  final TextEditingController _vehiculeTypeController = TextEditingController();
  final TextEditingController _vehiculeMarqueController = TextEditingController();
  final TextEditingController _vehiculeModeleController = TextEditingController();
  final TextEditingController _vehiculeAnneeController = TextEditingController();
  final TextEditingController _vehiculeCouleurController = TextEditingController();
  final UserService _userService = UserService();

  String? selectedCountry;
  String? selectedCountryCode;
  int selectedDigits = 8;
  String? selectedRole;
  int _currentStep = 0; // 0: infos, 1: rôle, 2: sécurité
  final List<Map<String, dynamic>> countries = [
    {'name': 'Bénin', 'code': '+229', 'flag': '🇧🇯', 'digits': 8},
    {'name': 'Côte d\'Ivoire', 'code': '+225', 'flag': '🇨🇮', 'digits': 10},
    {'name': 'Sénégal', 'code': '+221', 'flag': '🇸🇳', 'digits': 9},
    {'name': 'Togo', 'code': '+228', 'flag': '🇹🇬', 'digits': 8},
    {'name': 'Mali', 'code': '+223', 'flag': '🇲🇱', 'digits': 8},
    {'name': 'Burkina Faso', 'code': '+226', 'flag': '🇧🇫', 'digits': 8},
    {'name': 'Niger', 'code': '+227', 'flag': '🇳🇪', 'digits': 8},
    {'name': 'Ghana', 'code': '+233', 'flag': '🇬🇭', 'digits': 9},
    {'name': 'Nigeria', 'code': '+234', 'flag': '🇳🇬', 'digits': 10},
    {'name': 'Cameroun', 'code': '+237', 'flag': '🇨🇲', 'digits': 9},
    {'name': 'Gabon', 'code': '+241', 'flag': '🇬🇦', 'digits': 8},
    {'name': 'Congo', 'code': '+242', 'flag': '🇨🇬', 'digits': 9},
    {'name': 'RDC', 'code': '+243', 'flag': '🇨🇩', 'digits': 9},
    {'name': 'Tchad', 'code': '+235', 'flag': '🇹🇩', 'digits': 8},
    {'name': 'Centrafrique', 'code': '+236', 'flag': '🇨🇫', 'digits': 8},
    {'name': 'Guinée', 'code': '+224', 'flag': '🇬🇳', 'digits': 9},
    {'name': 'Guinée-Bissau', 'code': '+245', 'flag': '🇬🇼', 'digits': 7},
    {'name': 'Liberia', 'code': '+231', 'flag': '🇱🇷', 'digits': 8},
    {'name': 'Sierra Leone', 'code': '+232', 'flag': '🇸🇱', 'digits': 8},
    {'name': 'Mauritanie', 'code': '+222', 'flag': '🇲🇷', 'digits': 8},
    {'name': 'Gambie', 'code': '+220', 'flag': '🇬🇲', 'digits': 7},
    {'name': 'Cap-Vert', 'code': '+238', 'flag': '🇨🇻', 'digits': 7},
    {'name': 'Maroc', 'code': '+212', 'flag': '🇲🇦', 'digits': 9},
    {'name': 'Algérie', 'code': '+213', 'flag': '🇩🇿', 'digits': 9},
    {'name': 'Tunisie', 'code': '+216', 'flag': '🇹🇳', 'digits': 8},
    {'name': 'Libye', 'code': '+218', 'flag': '🇱🇾', 'digits': 9},
    {'name': 'Égypte', 'code': '+20', 'flag': '🇪🇬', 'digits': 10},
    {'name': 'Soudan', 'code': '+249', 'flag': '🇸🇩', 'digits': 9},
    {'name': 'Éthiopie', 'code': '+251', 'flag': '🇪🇹', 'digits': 9},
    {'name': 'Kenya', 'code': '+254', 'flag': '🇰🇪', 'digits': 9},
    {'name': 'Tanzanie', 'code': '+255', 'flag': '🇹🇿', 'digits': 9},
    {'name': 'Ouganda', 'code': '+256', 'flag': '🇺🇬', 'digits': 9},
    {'name': 'Rwanda', 'code': '+250', 'flag': '🇷🇼', 'digits': 9},
    {'name': 'Burundi', 'code': '+257', 'flag': '🇧🇮', 'digits': 8},
    {'name': 'Afrique du Sud', 'code': '+27', 'flag': '🇿🇦', 'digits': 9},
    {'name': 'Botswana', 'code': '+267', 'flag': '🇧🇼', 'digits': 8},
    {'name': 'Namibie', 'code': '+264', 'flag': '🇳🇦', 'digits': 8},
    {'name': 'Zambie', 'code': '+260', 'flag': '🇿🇲', 'digits': 9},
    {'name': 'Zimbabwe', 'code': '+263', 'flag': '🇿🇼', 'digits': 9},
    {'name': 'Mozambique', 'code': '+258', 'flag': '🇲🇿', 'digits': 9},
    {'name': 'Madagascar', 'code': '+261', 'flag': '🇲🇬', 'digits': 9},
    {'name': 'Maurice', 'code': '+230', 'flag': '🇲🇺', 'digits': 8},
    {'name': 'France', 'code': '+33', 'flag': '🇫🇷', 'digits': 10},
    {'name': 'Belgique', 'code': '+32', 'flag': '🇧🇪', 'digits': 9},
    {'name': 'Allemagne', 'code': '+49', 'flag': '🇩🇪', 'digits': 11},
    {'name': 'Italie', 'code': '+39', 'flag': '🇮🇹', 'digits': 10},
    {'name': 'Espagne', 'code': '+34', 'flag': '🇪🇸', 'digits': 9},
    {'name': 'Portugal', 'code': '+351', 'flag': '🇵🇹', 'digits': 9},
    {'name': 'Suisse', 'code': '+41', 'flag': '🇨🇭', 'digits': 9},
    {'name': 'Pays-Bas', 'code': '+31', 'flag': '🇳🇱', 'digits': 9},
  ];

  final List<String> roles = [
    'Transitaire',
    'Vendeur',
    'Chauffeur',
    'Livreur',
  ];
  final TextEditingController _entrepriseController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePasswordReg = true;
  bool _obscureConfirmReg = true;
  double _passwordStrength = 0.0;
  String _passwordStrengthLabel = '';
  Color _passwordStrengthColor = Colors.transparent;

  void _updatePasswordStrength(String value) {
    double score = 0;
    if (value.isNotEmpty) {
      if (value.length >= 6) score += 0.3; // minimum
      if (value.length >= 8) score += 0.2; // recommandé
      if (RegExp(r'[A-Z]').hasMatch(value)) score += 0.15;
      if (RegExp(r'[a-z]').hasMatch(value)) score += 0.15;
      if (RegExp(r'\\d').hasMatch(value)) score += 0.1;
      if (RegExp(r'[!@#\\$%^&*(),.?":{}|<>_\\-]').hasMatch(value)) score += 0.1;
      if (score > 1) score = 1;
    }

    String label;
    Color color;
    if (score == 0) {
      label = '';
      color = Colors.transparent;
    } else if (score < 0.4) {
      label = 'Faible';
      color = Colors.red;
    } else if (score < 0.7) {
      label = 'Moyen';
      color = Colors.orange;
    } else if (score < 0.9) {
      label = 'Fort';
      color = Colors.lightGreen;
    } else {
      label = 'Super fort';
      color = Colors.green;
    }

    setState(() {
      _passwordStrength = score;
      _passwordStrengthLabel = label;
      _passwordStrengthColor = color;
    });
  }

  @override
  void initState() {
    super.initState();
    // Initialiser le pays par défaut (Bénin)
    selectedCountry = countries[0]['name'] as String?;
    selectedCountryCode = countries[0]['code'] as String?;
    selectedDigits = countries[0]['digits'] as int;
    selectedRole = roles.isNotEmpty ? roles.first : null;
  }

  Widget _buildStepBar() {
    const active = Color(0xFFF8BF13);
    final inactive = Colors.grey.shade300;
    return Column(
      children: [
        Row(
          children: List.generate(3, (i) {
            final isActive = i <= _currentStep;
            return Expanded(
              child: Container(
                height: 6,
                margin: EdgeInsets.only(right: i == 2 ? 0 : 8),
                decoration: BoxDecoration(
                  color: isActive ? active : inactive,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Text(
          _currentStep == 0
              ? 'Informations'
              : _currentStep == 1
                  ? 'Rôle'
                  : 'Sécurité',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Future<void> _openCountryPicker() async {
    final controller = TextEditingController();
    List<Map<String, dynamic>> filtered = List.from(countries);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.72,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: 'Rechercher un indicatif (pays ou +code)',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (v) {
                          final q = v.trim().toLowerCase();
                          setModal(() {
                            filtered = countries.where((c) {
                              final name =
                                  (c['name'] ?? '').toString().toLowerCase();
                              final code =
                                  (c['code'] ?? '').toString().toLowerCase();
                              return name.contains(q) || code.contains(q);
                            }).toList();
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final c = filtered[index];
                          return ListTile(
                            leading: Text(
                              c['flag'] as String? ?? '',
                              style: const TextStyle(fontSize: 18),
                            ),
                            title: Text(c['name'] as String? ?? ''),
                            trailing: Text(
                              c['code'] as String? ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onTap: () {
                              setState(() {
                                selectedCountry = c['name'] as String?;
                                selectedCountryCode = c['code'] as String?;
                                selectedDigits = c['digits'] as int? ?? 8;
                                _telephoneController.clear();
                              });
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Récupération des dimensions de l'écran
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final isPortrait = mediaQuery.orientation == Orientation.portrait;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * (isPortrait ? 0.05 : 0.1),
            vertical: screenHeight * (isPortrait ? 0.02 : 0.05),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: screenHeight * (isPortrait ? 0.02 : 0.05)),
              Center(
                child: Image.asset(
                  "assets/images/logo_connexion.png",
                  width: screenWidth * (isPortrait ? 0.6 : 0.4),
                  height: screenHeight * (isPortrait ? 0.15 : 0.2),
                  fit: BoxFit.contain,
                ),
              ),
              _buildStepBar(),
              SizedBox(height: screenHeight * 0.02),
              Text(
                "Trouvez votre voiture de rêve!",
                style: TextStyle(
                  fontSize: screenWidth * (isPortrait ? 0.04 : 0.03),
                ),
              ),
              SizedBox(height: screenHeight * (isPortrait ? 0.05 : 0.1)),

              if (_currentStep == 0) ...[
                // Step 1: nom, prénoms, mail, code parrainage, téléphone + warning WhatsApp
                buildTextFieldWithController(
                  controller: _nomController,
                  label: "Nom",
                  icon: Icons.person,
                  placeholder: "Jean",
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                  isPortrait: isPortrait,
                ),
                SizedBox(height: screenHeight * 0.02),
                buildTextFieldWithController(
                  controller: _prenomController,
                  label: "Prénom(s)",
                  icon: Icons.person_outline,
                  placeholder: "Dupont",
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                  isPortrait: isPortrait,
                ),
                SizedBox(height: screenHeight * 0.02),
                buildTextFieldWithController(
                  controller: _emailController,
                  label: "Adresse email",
                  icon: Icons.email,
                  placeholder: "jean.dupont@email.com",
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                  isPortrait: isPortrait,
                ),
                SizedBox(height: screenHeight * 0.02),
                buildTextFieldWithController(
                  controller: _referralController,
                  label: "Code de parrainage (optionnel)",
                  icon: Icons.card_giftcard,
                  placeholder: "Ex: TRN-ABCD1234",
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                  isPortrait: isPortrait,
                ),
                SizedBox(height: screenHeight * 0.02),
                Row(
                  children: [
                    InkWell(
                      onTap: _openCountryPicker,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              countries
                                      .firstWhere(
                                        (c) => c['name'] == selectedCountry,
                                        orElse: () => countries[0],
                                      )['flag']
                                      ?.toString() ??
                                  '',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              selectedCountryCode ?? '+229',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_down, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _telephoneController,
                        keyboardType: TextInputType.number,
                        maxLength: selectedDigits,
                        decoration: InputDecoration(
                          labelText: 'Téléphone ($selectedDigits chiffres)',
                          counterText: '',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFC107)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFF8A6D3B),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Utilisez un numéro joignable sur WhatsApp : il servira aux OTP et aux échanges entre notre équipe et les utilisateurs.',
                          style: TextStyle(
                            color: Color(0xFF8A6D3B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: screenHeight * 0.02),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_nomController.text.trim().isEmpty ||
                          _prenomController.text.trim().isEmpty ||
                          _emailController.text.trim().isEmpty ||
                          _telephoneController.text.trim().isEmpty) {
                        AuthMessagePopup.showWarning(
                          context,
                          title: 'Certains champs sont manquants.',
                          subtitle: 'Veuillez compléter les informations requises.',
                        );
                        return;
                      }
                      setState(() => _currentStep = 1);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF8BF13),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Suivant',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],

              if (_currentStep == 1) ...[
                // Step 2: rôles + champs liés
                Focus(
                  onFocusChange: (hasFocus) {
                    setState(() {});
                  },
                  child: Builder(
                    builder: (context) {
                      final focusNode = Focus.of(context);
                      final bool isFocused = focusNode.hasFocus;

                      return DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Rôle',
                          labelStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: screenWidth * (isPortrait ? 0.04 : 0.03),
                          ),
                          prefixIcon: Icon(
                            Icons.person_outline,
                            color: isFocused
                                ? const Color(0xFFF8BF13)
                                : Colors.grey,
                            size: screenWidth * (isPortrait ? 0.06 : 0.04),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: screenHeight * 0.02,
                            horizontal: screenWidth * 0.04,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isFocused
                                  ? const Color(0xFFF8BF13)
                                  : Colors.grey,
                              width: 2,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFF8BF13),
                            ),
                          ),
                        ),
                        value: selectedRole,
                        items: roles.map((role) {
                          return DropdownMenuItem(
                            value: role,
                            child: Text(
                              role,
                              style: TextStyle(
                                fontSize: screenWidth *
                                    (isPortrait ? 0.04 : 0.03),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedRole = value;
                          });
                        },
                      );
                    },
                  ),
                ),
                if (selectedRole == 'Transitaire') ...[
                  SizedBox(height: screenHeight * 0.02),
                  buildTextFieldWithController(
                    controller: _entrepriseController,
                    label: "Entreprise",
                    icon: Icons.business,
                    placeholder: "Nom de l'entreprise",
                    screenWidth: screenWidth,
                    screenHeight: screenHeight,
                    isPortrait: isPortrait,
                  ),
                ],
                if (selectedRole == 'Vendeur') ...[
                  SizedBox(height: screenHeight * 0.02),
                  buildTextFieldWithController(
                    controller: _entrepriseProvenanceController,
                    label: "Entreprise de provenance",
                    icon: Icons.factory,
                    placeholder: "Nom de l'entreprise",
                    screenWidth: screenWidth,
                    screenHeight: screenHeight,
                    isPortrait: isPortrait,
                  ),
                ],
                if (selectedRole == 'Livreur' || selectedRole == 'Chauffeur') ...[
                  SizedBox(height: screenHeight * 0.02),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2196F3)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.info_outline, color: Color(0xFF1976D2)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Informations de votre véhicule (obligatoire pour la sécurité)',
                            style: TextStyle(
                              color: Color(0xFF1976D2),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  buildTextFieldWithController(
                    controller: _immatriculationController,
                    label: "Numéro d'immatriculation",
                    icon: Icons.confirmation_number,
                    placeholder: "Ex: 1234-AB-01",
                    screenWidth: screenWidth,
                    screenHeight: screenHeight,
                    isPortrait: isPortrait,
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  buildTextFieldWithController(
                    controller: _vehiculeTypeController,
                    label: "Type de véhicule",
                    icon: Icons.directions_car,
                    placeholder: "Ex: Moto, Voiture, Camion",
                    screenWidth: screenWidth,
                    screenHeight: screenHeight,
                    isPortrait: isPortrait,
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  Row(
                    children: [
                      Expanded(
                        child: buildTextFieldWithController(
                          controller: _vehiculeMarqueController,
                          label: "Marque",
                          icon: Icons.branding_watermark,
                          placeholder: "Ex: Toyota",
                          screenWidth: screenWidth,
                          screenHeight: screenHeight,
                          isPortrait: isPortrait,
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.02),
                      Expanded(
                        child: buildTextFieldWithController(
                          controller: _vehiculeModeleController,
                          label: "Modèle",
                          icon: Icons.description,
                          placeholder: "Ex: Corolla",
                          screenWidth: screenWidth,
                          screenHeight: screenHeight,
                          isPortrait: isPortrait,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  Row(
                    children: [
                      Expanded(
                        child: buildTextFieldWithController(
                          controller: _vehiculeAnneeController,
                          label: "Année",
                          icon: Icons.calendar_today,
                          placeholder: "Ex: 2020",
                          screenWidth: screenWidth,
                          screenHeight: screenHeight,
                          isPortrait: isPortrait,
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.02),
                      Expanded(
                        child: buildTextFieldWithController(
                          controller: _vehiculeCouleurController,
                          label: "Couleur",
                          icon: Icons.color_lens,
                          placeholder: "Ex: Rouge",
                          screenWidth: screenWidth,
                          screenHeight: screenHeight,
                          isPortrait: isPortrait,
                        ),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: screenHeight * 0.02),
                buildTextFieldWithController(
                  controller: _maisonController,
                  label: "Maison",
                  icon: Icons.home,
                  placeholder: "Rue 123, Cotonou",
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                  isPortrait: isPortrait,
                ),
                SizedBox(height: screenHeight * 0.02),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _currentStep = 0),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: const BorderSide(color: Color(0xFFF8BF13)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Retour'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (selectedRole == null ||
                              _maisonController.text.trim().isEmpty) {
                            AuthMessagePopup.showWarning(
                              context,
                              title: 'Certains champs sont manquants.',
                              subtitle:
                                  'Veuillez compléter les informations requises.',
                            );
                            return;
                          }
                          if (selectedRole == 'Transitaire' &&
                              _entrepriseController.text.trim().isEmpty) {
                            AuthMessagePopup.showWarning(
                              context,
                              title: 'Ce champ est obligatoire.',
                              subtitle: 'Veuillez renseigner votre entreprise.',
                            );
                            return;
                          }
                          if ((selectedRole == 'Livreur' ||
                                  selectedRole == 'Chauffeur') &&
                              (_immatriculationController.text.trim().isEmpty ||
                                  _vehiculeTypeController.text.trim().isEmpty ||
                                  _vehiculeMarqueController.text
                                      .trim()
                                      .isEmpty ||
                                  _vehiculeModeleController.text
                                      .trim()
                                      .isEmpty)) {
                            AuthMessagePopup.showWarning(
                              context,
                              title: 'Informations véhicule manquantes.',
                              subtitle:
                                  'Immatriculation, type, marque et modèle sont requis.',
                            );
                            return;
                          }
                          setState(() => _currentStep = 2);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF8BF13),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Suivant',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              if (_currentStep == 2) ...[
                // Step 3: mot de passe
                Focus(
                  onFocusChange: (hasFocus) {
                    setState(() {});
                  },
                  child: TextField(
                    controller: _passwordController,
                    onChanged: _updatePasswordStrength,
                    obscureText: _obscurePasswordReg,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      hintText: 'Min. 8 caractères',
                      labelStyle: TextStyle(
                        color: Colors.grey,
                        fontSize: screenWidth * (isPortrait ? 0.04 : 0.03),
                      ),
                      prefixIcon: Icon(
                        Icons.lock,
                        color: Colors.grey,
                        size: screenWidth * (isPortrait ? 0.06 : 0.04),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePasswordReg
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePasswordReg = !_obscurePasswordReg;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Color(0xFFF8BF13)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_passwordStrengthLabel.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: _passwordStrength,
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _passwordStrengthColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Force du mot de passe: $_passwordStrengthLabel',
                        style: TextStyle(
                          color: _passwordStrengthColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: screenHeight * 0.02),
                Focus(
                  onFocusChange: (hasFocus) {
                    setState(() {});
                  },
                  child: TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmReg,
                    decoration: InputDecoration(
                      labelText: 'Confirmer le mot de passe',
                      hintText: 'Retapez le mot de passe',
                      labelStyle: TextStyle(
                        color: Colors.grey,
                        fontSize: screenWidth * (isPortrait ? 0.04 : 0.03),
                      ),
                      prefixIcon: Icon(
                        Icons.lock,
                        color: Colors.grey,
                        size: screenWidth * (isPortrait ? 0.06 : 0.04),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmReg
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmReg = !_obscureConfirmReg;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Color(0xFFF8BF13)),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.02),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () => setState(() => _currentStep = 1),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: const BorderSide(color: Color(0xFFF8BF13)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Retour'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () async {
                                if (_nomController.text.trim().isEmpty ||
                                    _prenomController.text.trim().isEmpty ||
                                    _emailController.text.trim().isEmpty ||
                                    _telephoneController.text.trim().isEmpty ||
                                    _passwordController.text.trim().isEmpty ||
                                    _confirmPasswordController.text.trim().isEmpty ||
                                    selectedRole == null ||
                                    selectedCountry == null ||
                                    _maisonController.text.trim().isEmpty) {
                                  AuthMessagePopup.showWarning(
                                    context,
                                    title: 'Certains champs sont manquants.',
                                    subtitle:
                                        'Veuillez compléter les informations requises.',
                                  );
                                  return;
                                }

                                if (selectedRole == 'Transitaire' &&
                                    _entrepriseController.text.trim().isEmpty) {
                                  AuthMessagePopup.showWarning(
                                    context,
                                    title: 'Ce champ est obligatoire.',
                                    subtitle:
                                        'Veuillez renseigner votre entreprise.',
                                  );
                                  return;
                                }

                                if (selectedRole == 'Vendeur' &&
                                    _entrepriseProvenanceController.text
                                        .trim()
                                        .isEmpty) {
                                  AuthMessagePopup.showWarning(
                                    context,
                                    title: 'Ce champ est obligatoire.',
                                    subtitle:
                                        'Veuillez renseigner l’entreprise de provenance.',
                                  );
                                  return;
                                }

                                if ((selectedRole == 'Livreur' ||
                                        selectedRole == 'Chauffeur') &&
                                    (_immatriculationController.text
                                            .trim()
                                            .isEmpty ||
                                        _vehiculeTypeController.text
                                            .trim()
                                            .isEmpty ||
                                        _vehiculeMarqueController.text
                                            .trim()
                                            .isEmpty ||
                                        _vehiculeModeleController.text
                                            .trim()
                                            .isEmpty)) {
                                  AuthMessagePopup.showWarning(
                                    context,
                                    title: 'Informations véhicule manquantes.',
                                    subtitle:
                                        'Immatriculation, type, marque et modèle sont requis.',
                                  );
                                  return;
                                }

                                final email = _emailController.text.trim();
                                final emailRegex =
                                    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                                if (!emailRegex.hasMatch(email)) {
                                  AuthMessagePopup.showError(
                                    context,
                                    title: 'Veuillez entrer une adresse email valide.',
                                  );
                                  return;
                                }

                                if (_passwordController.text.length < 8) {
                                  AuthMessagePopup.showError(
                                    context,
                                    title:
                                        'Le mot de passe doit contenir au moins 8 caractères.',
                                  );
                                  return;
                                }

                                if (_passwordController.text !=
                                    _confirmPasswordController.text) {
                                  AuthMessagePopup.showError(
                                    context,
                                    title: 'Les mots de passe ne correspondent pas.',
                                  );
                                  return;
                                }

                                final phone = _telephoneController.text.trim();
                                final phoneRegex =
                                    RegExp('^\\d{$selectedDigits}\$');
                                if (!phoneRegex.hasMatch(phone)) {
                                  AuthMessagePopup.showError(
                                    context,
                                    title: 'Numéro invalide',
                                    subtitle: 'Entrez $selectedDigits chiffres.',
                                  );
                                  return;
                                }

                                setState(() => _isLoading = true);
                                try {
                                  final fullPhone =
                                      (selectedCountryCode ?? '+229') + phone;

                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  final pendingReferral = _referralController
                                          .text
                                          .trim()
                                          .isNotEmpty
                                      ? _referralController.text.trim()
                                      : prefs.getString('pending_referral');

                                  final response = await _userService.registerUser(
                                    email: email,
                                    password: _passwordController.text.trim(),
                                    nom: _nomController.text.trim(),
                                    prenoms: _prenomController.text.trim(),
                                    telephone: fullPhone,
                                    role: selectedRole!.toLowerCase(),
                                    entreprise: selectedRole == 'Transitaire'
                                        ? _entrepriseController.text.trim()
                                        : null,
                                    // Vendeur: on retire RC + IFU à l'inscription
                                    registreCommerce: null,
                                    numeroIFU: null,
                                    entrepriseProvenance: selectedRole == 'Vendeur'
                                        ? _entrepriseProvenanceController.text
                                            .trim()
                                        : null,
                                    referralCode: pendingReferral,
                                    vehiculeImmatriculation:
                                        (selectedRole == 'Livreur' ||
                                                selectedRole == 'Chauffeur')
                                            ? _immatriculationController.text
                                                .trim()
                                            : null,
                                    vehiculeType: (selectedRole == 'Livreur' ||
                                            selectedRole == 'Chauffeur')
                                        ? _vehiculeTypeController.text.trim()
                                        : null,
                                    vehiculeMarque: (selectedRole == 'Livreur' ||
                                            selectedRole == 'Chauffeur')
                                        ? _vehiculeMarqueController.text.trim()
                                        : null,
                                    vehiculeModele: (selectedRole == 'Livreur' ||
                                            selectedRole == 'Chauffeur')
                                        ? _vehiculeModeleController.text.trim()
                                        : null,
                                    vehiculeAnnee: (selectedRole == 'Livreur' ||
                                            selectedRole == 'Chauffeur')
                                        ? _vehiculeAnneeController.text.trim()
                                        : null,
                                    vehiculeCouleur: (selectedRole == 'Livreur' ||
                                            selectedRole == 'Chauffeur')
                                        ? _vehiculeCouleurController.text.trim()
                                        : null,
                                  );

                                  if (response.data is Map) {
                                    final data = response.data as Map;
                                    final referralError =
                                        data['referralError']?.toString();
                                    final referralInfo = data['referral'];

                                    if (referralError != null &&
                                        referralError.isNotEmpty) {
                                      AuthMessagePopup.showWarning(
                                        context,
                                        title: referralError,
                                      );
                                    } else if (referralInfo is Map &&
                                        referralInfo['status'] != null) {
                                      final status =
                                          referralInfo['status']?.toString();
                                      final amount = referralInfo['rewardAmount']
                                          ?.toString();
                                      final isAgent =
                                          referralInfo['isAgent'] == true;
                                      var message =
                                          'Code de parrainage enregistré (statut: $status)';
                                      if (isAgent && amount != null) {
                                        message =
                                            'Compte créé avec succès, parrainage agent validé.';
                                      }
                                      AuthMessagePopup.showSuccess(
                                        context,
                                        title: message,
                                      );
                                    }
                                  }

                                  if (pendingReferral != null &&
                                      _referralController.text.trim().isEmpty) {
                                    await prefs.remove('pending_referral');
                                  }

                                  if (!mounted) return;
                                  await AuthMessagePopup.showSuccess(
                                    context,
                                    title: 'Compte créé avec succès.',
                                    subtitle: 'Connectez-vous pour continuer.',
                                    buttonText: 'Se connecter',
                                    onPressed: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const ConnexionPage(),
                                        ),
                                      );
                                    },
                                  );
                                } catch (e) {
                                  var title = 'Une erreur est survenue.';
                                  String? subtitle;
                                  if (e.toString().contains(
                                        'email-already-in-use',
                                      )) {
                                    title =
                                        'Un compte existe déjà avec cette adresse email.';
                                    subtitle = 'Essayez de vous connecter.';
                                  } else if (e.toString().contains(
                                        'weak-password',
                                      )) {
                                    title =
                                        'Le mot de passe doit contenir au moins 8 caractères.';
                                  } else if (e.toString().contains('network') ||
                                      e.toString().contains('SocketException') ||
                                      e.toString().contains('Failed host lookup')) {
                                    title = 'Impossible de se connecter au serveur.';
                                    subtitle = 'Vérifiez votre connexion internet.';
                                  } else if (e.toString().contains('server') ||
                                      e.toString().contains('500') ||
                                      e.toString().contains('503')) {
                                    title =
                                        'Notre service rencontre un problème temporaire.';
                                    subtitle = 'Veuillez réessayer plus tard.';
                                  }
                                  if (!mounted) return;
                                  AuthMessagePopup.showError(
                                    context,
                                    title: title,
                                    subtitle: subtitle,
                                    buttonText: 'Réessayer',
                                  );
                                } finally {
                                  if (mounted) {
                                    setState(() => _isLoading = false);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF8BF13),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                "S'inscrire",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ],

              SizedBox(height: screenHeight * 0.03),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Vous avez déjà un compte ? ",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: screenWidth * (isPortrait ? 0.04 : 0.03),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ConnexionPage(),
                        ),
                      );
                    },
                    child: Text(
                      "Se connecter",
                      style: TextStyle(
                        color: const Color(0xFF0461B6),
                        fontWeight: FontWeight.bold,
                        fontSize: screenWidth * (isPortrait ? 0.04 : 0.03),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.03),
            ],
          ),
        ),
      ),
    );
  }

  // Nouveau builder de champ avec contrôleur
  Widget buildTextFieldWithController({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    String? placeholder,
    required double screenWidth,
    required double screenHeight,
    required bool isPortrait,
  }) {
    return Focus(
      onFocusChange: (hasFocus) {
        setState(() {});
      },
      child: Builder(
        builder: (context) {
          final focusNode = Focus.of(context);
          final bool isFocused = focusNode.hasFocus;

          return TextField(
            controller: controller,
            obscureText: isPassword,
            decoration: InputDecoration(
              labelText: label,
              hintText: placeholder,
              labelStyle: TextStyle(
                color: Colors.grey,
                fontSize: screenWidth * (isPortrait ? 0.04 : 0.03),
              ),
              prefixIcon: Icon(
                icon,
                color: isFocused ? const Color(0xFFF8BF13) : Colors.grey,
                size: screenWidth * (isPortrait ? 0.06 : 0.04),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                vertical: screenHeight * 0.02,
                horizontal: screenWidth * 0.04,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isFocused ? const Color(0xFFF8BF13) : Colors.grey,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFF8BF13)),
              ),
            ),
          );
        },
      ),
    );
  }
}
