import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tranoo_pro/providers/auth_provider.dart' as myauth;
import 'package:tranoo_pro/services/user_service.dart';
import 'package:tranoo_pro/widgets/auth_message_popup.dart';
import 'package:tranoo_pro/utils/phone_country_config.dart';
import 'package:tranoo_pro/utils/auth_config.dart';
import 'package:tranoo_pro/widgets/registration_location_section.dart';
import 'avant_home.dart';
import 'package:dio/dio.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';
import 'package:tranoo_pro/utils/api_error_message.dart';
// CAPTCHA mobile désactivé — web uniquement pour l'instant.
// import 'package:tranoo_pro/config/turnstile_config.dart';
// import 'package:tranoo_pro/utils/turnstile_captcha.dart';

import 'connexion_page.dart'; // Assurez-vous que ce fichier existe

class InscriptionPage extends StatefulWidget {
  const InscriptionPage({super.key});

  @override
  State<InscriptionPage> createState() => _InscriptionPageState();
}

class _InscriptionPageState extends State<InscriptionPage> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  // Contrôleurs pour les champs du formulaire
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _prenomController = TextEditingController();
  final TextEditingController _telephoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _referralController = TextEditingController();
  CapturedProfileLocation? _profileLocation;
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
  String? selectedRole;
  String? _typeVendeur; // Pour la sélection du type de vendeur
  int _currentStep = 0; // 0: infos, 1: rôle, 2: sécurité

  PhoneCountryConfig get _phoneCountry => kPhoneCountries.firstWhere(
        (c) => c.name == selectedCountry,
        orElse: () => kPhoneCountries.first,
      );

  List<Map<String, dynamic>> get countries => kPhoneCountries
      .map(
        (c) => <String, dynamic>{
          'name': c.name,
          'code': c.code,
          'flag': c.flag,
          'minDigits': c.minDigits,
          'maxDigits': c.maxDigits,
        },
      )
      .toList();

  Map<String, dynamic> get _selectedCountryMap {
    if (selectedCountry == null) return countries.first;
    for (final c in countries) {
      if (c['name'] == selectedCountry) return c;
    }
    return countries.first;
  }

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
    selectedCountry = kPhoneCountries.first.name;
    selectedCountryCode = kPhoneCountries.first.code;
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
                          hintText: l10n.searchCountryCode,
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
    final l10n = AppLocalizations.of(context)!;
    // Récupération des dimensions de l'écran
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final isPortrait = mediaQuery.orientation == Orientation.portrait;
    final bottomInset = mediaQuery.viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            screenWidth * (isPortrait ? 0.05 : 0.1),
            screenHeight * (isPortrait ? 0.02 : 0.05),
            screenWidth * (isPortrait ? 0.05 : 0.1),
            screenHeight * (isPortrait ? 0.02 : 0.05) + bottomInset,
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
              Text(l10n.findDreamCar,
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
                              _selectedCountryMap['flag']?.toString() ?? '',
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
                        maxLength: _phoneCountry.maxDigits,
                        decoration: InputDecoration(
                          labelText: l10n.whatsappNumber,
                          hintText:
                              'WhatsApp · ${_phoneCountry.digitHint}',
                          prefixIcon: AuthConfig.whatsAppPhonePrefixIcon(),
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
                          _telephoneController.text.trim().isEmpty) {
                        AuthMessagePopup.showWarning(
                          context,
                          title: 'Certains champs sont manquants.',
                          subtitle: 'Veuillez compléter les informations requises.',
                        );
                        return;
                      }
                      final phone = _telephoneController.text.trim();
                      if (!_phoneCountry.isValidNationalNumber(phone)) {
                        AuthMessagePopup.showWarning(
                          context,
                          title: 'Numéro invalide',
                          subtitle:
                              'Entrez ${_phoneCountry.digitHint} (ex. Bénin : 8 ou 10 chiffres).',
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
                    child: Text(l10n.nextStep,
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
                          labelText: l10n.roleLabel,
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
                  _buildTypeVendeurSelector(screenWidth, screenHeight, isPortrait),
                ],
                if (selectedRole == 'Vendeur' || selectedRole == 'Transitaire') ...[
                  SizedBox(height: screenHeight * 0.02),
                  RegistrationLocationSection(
                    userRole: selectedRole == 'Vendeur' ? 'vendeur' : 'transitaire',
                    onChanged: (loc) {
                      setState(() => _profileLocation = loc);
                    },
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
                        child: Text(l10n.back),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (selectedRole == null) {
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
                          if ((selectedRole == 'Vendeur' ||
                                  selectedRole == 'Transitaire') &&
                              _profileLocation == null) {
                            AuthMessagePopup.showWarning(
                              context,
                              title: 'Position requise',
                              subtitle:
                                  'Enregistrez votre position actuelle pour continuer.',
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
                        child: Text(l10n.nextStep,
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
                      labelText: l10n.password,
                      hintText: l10n.passwordMin8,
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
                      labelText: l10n.confirmPassword,
                      hintText: l10n.retypePassword,
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
                        child: Text(l10n.back),
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
                                    _telephoneController.text.trim().isEmpty ||
                                    _passwordController.text.trim().isEmpty ||
                                    _confirmPasswordController.text.trim().isEmpty ||
                                    selectedRole == null ||
                                    selectedCountry == null) {
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

                                if ((selectedRole == 'Vendeur' ||
                                        selectedRole == 'Transitaire') &&
                                    _profileLocation == null) {
                                  AuthMessagePopup.showWarning(
                                    context,
                                    title: 'Position requise',
                                    subtitle:
                                        'Enregistrez votre position actuelle.',
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

                                final phone = _telephoneController.text.trim();
                                if (!_phoneCountry.isValidNationalNumber(phone)) {
                                  AuthMessagePopup.showError(
                                    context,
                                    title: 'Numéro invalide',
                                    subtitle:
                                        'Entrez ${_phoneCountry.digitHint}.',
                                  );
                                  return;
                                }

                                final cc = selectedCountryCode ?? '+229';
                                final email = syntheticEmailFromPhone(
                                  cc,
                                  phone,
                                  app: TranooAuthApp.pro,
                                );

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

                                setState(() => _isLoading = true);
                                try {
                                  // --- CAPTCHA mobile (désactivé, web uniquement) ---
                                  // final captchaToken =
                                  //     await TurnstileCaptcha.requestToken(
                                  //   context,
                                  // );
                                  // if (isTurnstileConfigured &&
                                  //     (captchaToken == null ||
                                  //         captchaToken.isEmpty)) {
                                  //   AuthMessagePopup.showError(
                                  //     context,
                                  //     title: 'Contrôle de sécurité requis',
                                  //     subtitle:
                                  //         'Veuillez valider le contrôle de sécurité pour continuer.',
                                  //   );
                                  //   return;
                                  // }

                                  final fullPhone =
                                      (selectedCountryCode ?? '+229') + phone;
                                  final loc = _profileLocation;
                                  Map<String, dynamic>? fournisseurProfil;
                                  if (loc != null &&
                                      (selectedRole == 'Vendeur' ||
                                          selectedRole == 'Transitaire')) {
                                    fournisseurProfil = {
                                      'telephone': fullPhone,
                                      'adresseTexte': loc.address,
                                      'ville': loc.city,
                                      'latitude': loc.latitude,
                                      'longitude': loc.longitude,
                                    };
                                  }

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
                                    authApp: 'tranoo_pro',
                                    // Le backend accepte role='vendeur' uniquement.
                                    // Le type vendeur est porté par vendeurType.
                                    role: selectedRole == 'Vendeur'
                                        ? 'vendeur'
                                        : selectedRole!.toLowerCase(),
                                    vendeurType: selectedRole == 'Vendeur'
                                        ? (_typeVendeur == 'vendeurVehicules'
                                            ? 'vehicules'
                                            : _typeVendeur == 'vendeurPieces'
                                                ? 'pieces'
                                                : _typeVendeur == 'vendeurMotos'
                                                    ? 'motos'
                                                    : 'mixte')
                                        : null,
                                    entreprise: selectedRole == 'Transitaire'
                                        ? _entrepriseController.text.trim()
                                        : null,
                                    // Vendeur: on retire RC + IFU à l'inscription
                                    registreCommerce: null,
                                    numeroIFU: null,
                                    latitude: loc?.latitude,
                                    longitude: loc?.longitude,
                                    adresse: loc?.address,
                                    ville: loc?.city,
                                    fournisseurProfil: fournisseurProfil,
                                    referralCode: pendingReferral,
                                    // captchaToken: captchaToken,
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
                                  // L'utilisateur est déjà connecté via Firebase après registerUser.
                                  // On recharge son profil backend puis on l'envoie directement à l'accueil.
                                  final auth = context.read<myauth.AuthProvider>();
                                  await auth.reloadUser();

                                  final startWait = DateTime.now();
                                  while (auth.user == null &&
                                      DateTime.now().difference(startWait) <
                                          const Duration(seconds: 5)) {
                                    await Future.delayed(
                                      const Duration(milliseconds: 100),
                                    );
                                  }

                                  if (!mounted) return;
                                  await AuthMessagePopup.showSuccess(
                                    context,
                                    title: 'Compte créé avec succès.',
                                    subtitle: 'Bienvenue sur Tranoo Pro !',
                                  );

                                  if (!mounted) return;
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const AvantHome(),
                                    ),
                                    (route) => false,
                                  );
                                } catch (e) {
                                  var title = 'Une erreur est survenue.';
                                  String? subtitle;
                                  if (e is DioException &&
                                      e.response?.data is Map) {
                                    final data = Map<String, dynamic>.from(
                                      e.response!.data as Map,
                                    );
                                    title = ApiErrorMessage.fromMap(l10n, data);
                                  } else if (e.toString().contains(
                                        'email-already-in-use',
                                      )) {
                                    title =
                                        'Un compte existe déjà avec ce numéro.';
                                    subtitle =
                                        'Connectez-vous ou utilisez un autre numéro.';
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
                                    buttonText: l10n.retry,
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

              SizedBox(height: isPortrait ? 12 : 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.alreadyHaveAccount,
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
                    child: Text(l10n.signInTitle,
                      style: TextStyle(
                        color: const Color(0xFF0461B6),
                        fontWeight: FontWeight.bold,
                        fontSize: screenWidth * (isPortrait ? 0.04 : 0.03),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isPortrait ? 12 : 10),
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

  // Widget pour la sélection du type de vendeur
  Widget _buildTypeVendeurSelector(double screenWidth, double screenHeight, bool isPortrait) {
    // Initialiser par défaut à "vendeur" (mixte) pour la compatibilité
    if (_typeVendeur == null) {
      _typeVendeur = 'vendeur';
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: const Color(0xFFF8BF13).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF8BF13).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.category,
                color: const Color(0xFFF8BF13),
                size: screenWidth * 0.05,
              ),
              SizedBox(width: screenWidth * 0.02),
              Text(
                "Type de vendeur",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: screenWidth * (isPortrait ? 0.04 : 0.03),
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.01),
          Text(
            "Sélectionnez ce que vous vendez principalement",
            style: TextStyle(
              fontSize: screenWidth * (isPortrait ? 0.03 : 0.025),
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: screenHeight * 0.02),
          
          // Options radio
          _buildRadioOption(
            'vendeur',
            'Vendeur mixte',
            'Je vends des véhicules ET des pièces',
            Icons.category,
            screenWidth,
            screenHeight,
            isPortrait,
          ),
          
          _buildRadioOption(
            'vendeurVehicules',
            'Vendeur de véhicules',
            'Je vends uniquement des véhicules',
            Icons.directions_car,
            screenWidth,
            screenHeight,
            isPortrait,
          ),
          
          _buildRadioOption(
            'vendeurMotos',
            'Vendeur de motos',
            'Je vends uniquement des motos',
            Icons.motorcycle,
            screenWidth,
            screenHeight,
            isPortrait,
          ),
          
          _buildRadioOption(
            'vendeurPieces',
            'Vendeur de pièces',
            'Je vends uniquement des pièces détachées',
            Icons.build,
            screenWidth,
            screenHeight,
            isPortrait,
          ),
        ],
      ),
    );
  }

  Widget _buildRadioOption(
    String value,
    String title,
    String description,
    IconData icon,
    double screenWidth,
    double screenHeight,
    bool isPortrait,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: screenHeight * 0.01),
      child: RadioListTile<String>(
        value: value,
        groupValue: _typeVendeur,
        onChanged: (newValue) {
          setState(() {
            _typeVendeur = newValue;
          });
        },
        title: Row(
          children: [
            Icon(
              icon,
              color: _typeVendeur == value ? const Color(0xFFF8BF13) : Colors.grey[600],
              size: screenWidth * 0.04,
            ),
            SizedBox(width: screenWidth * 0.02),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: screenWidth * (isPortrait ? 0.035 : 0.025),
                  color: _typeVendeur == value ? const Color(0xFFF8BF13) : Colors.black,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(left: screenWidth * 0.06),
          child: Text(
            description,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: screenWidth * (isPortrait ? 0.03 : 0.02),
            ),
          ),
        ),
        activeColor: const Color(0xFFF8BF13),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
