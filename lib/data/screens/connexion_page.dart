// import 'package:flutter/material.dart';
// import 'package:tranoo_pro/data/screens/avant_home.dart';

// import 'inscription_page.dart';

// class ConnexionPage extends StatefulWidget {
//   const ConnexionPage({super.key});

//   @override
//   State<ConnexionPage> createState() => _ConnexionPageState();
// }

// class _ConnexionPageState extends State<ConnexionPage> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

//   bool isEmailFocused = false;
//   bool isPasswordFocused = false;

//   @override
//   Widget build(BuildContext context) {
//     // Récupération des dimensions de l'écran
//     final mediaQuery = MediaQuery.of(context);
//     final screenWidth = mediaQuery.size.width;
//     final screenHeight = mediaQuery.size.height;
//     final isPortrait = mediaQuery.orientation == Orientation.portrait;

//     return Scaffold(
//       backgroundColor: const Color(0xFFF9FAFB),
//       body: SingleChildScrollView(
//         child: Padding(
//           padding: EdgeInsets.symmetric(
//             horizontal: screenWidth * (isPortrait ? 0.05 : 0.1),
//             vertical: screenHeight * (isPortrait ? 0.02 : 0.05),
//           ),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.start,
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               SizedBox(height: screenHeight * (isPortrait ? 0.1 : 0.05)),
//               Center(
//                 child: Image.asset(
//                   "assets/images/logo_connexion.png",
//                   width: screenWidth * (isPortrait ? 0.6 : 0.4),
//                   height: screenHeight * (isPortrait ? 0.15 : 0.2),
//                   fit: BoxFit.contain,
//                 ),
//               ),
//               SizedBox(height: screenHeight * (isPortrait ? 0.05 : 0.1)),
//               Text(
//                 "Se connecter",
//                 style: TextStyle(
//                   fontWeight: FontWeight.bold,
//                   fontSize: screenWidth * (isPortrait ? 0.06 : 0.04),
//                 ),
//               ),
//               SizedBox(height: screenHeight * 0.02),
//               Text(
//                 "Bienvenue sur Tranoo Pro",
//                 style: TextStyle(
//                   fontSize: screenWidth * (isPortrait ? 0.04 : 0.03),
//                 ),
//               ),
//               SizedBox(height: screenHeight * (isPortrait ? 0.05 : 0.1)),

//               // Champ Email
//               Focus(
//                 onFocusChange: (focused) {
//                   setState(() => isEmailFocused = focused);
//                 },
//                 child: TextField(
//                   decoration: InputDecoration(
//                     labelText: l10n.email,
//                     labelStyle: TextStyle(
//                       color: Colors.grey,
//                       fontSize: screenWidth * (isPortrait ? 0.04 : 0.03),
//                     ),
//                     prefixIcon: Icon(
//                       Icons.email_outlined,
//                       color: isEmailFocused ? Colors.amber : Colors.grey,
//                       size: screenWidth * (isPortrait ? 0.06 : 0.04),
//                     ),
//                     hintText: l10n.emailExample,
//                     filled: true,
//                     fillColor: Colors.white,
//                     contentPadding: EdgeInsets.symmetric(
//                       vertical: screenHeight * 0.02,
//                       horizontal: screenWidth * 0.04,
//                     ),
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(12),
//                       borderSide: const BorderSide(
//                         color: Colors.grey,
//                         width: 2,
//                       ),
//                     ),
//                     enabledBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(12),
//                       borderSide: const BorderSide(color: Colors.grey),
//                     ),
//                     focusedBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(12),
//                       borderSide: const BorderSide(color: Colors.amber),
//                     ),
//                   ),
//                 ),
//               ),

//               SizedBox(height: screenHeight * 0.02),

//               // Champ Mot de passe
//               Focus(
//                 onFocusChange: (focused) {
//                   setState(() => isPasswordFocused = focused);
//                 },
//                 child: TextField(
//                   obscureText: true,
//                   decoration: InputDecoration(
//                     labelText: l10n.password,
//                     labelStyle: TextStyle(
//                       color: Colors.grey,
//                       fontSize: screenWidth * (isPortrait ? 0.04 : 0.03),
//                     ),
//                     prefixIcon: Icon(
//                       Icons.lock_outline,
//                       color: isPasswordFocused ? Colors.amber : Colors.grey,
//                       size: screenWidth * (isPortrait ? 0.06 : 0.04),
//                     ),
//                     hintText: l10n.passwordDotsHint,
//                     filled: true,
//                     fillColor: Colors.white,
//                     contentPadding: EdgeInsets.symmetric(
//                       vertical: screenHeight * 0.02,
//                       horizontal: screenWidth * 0.04,
//                     ),
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(12),
//                       borderSide: const BorderSide(color: Colors.grey),
//                     ),
//                     enabledBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(12),
//                       borderSide: const BorderSide(color: Colors.grey),
//                     ),
//                     focusedBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(12),
//                       borderSide: const BorderSide(
//                         color: Colors.amber,
//                         width: 2,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),

//               SizedBox(height: screenHeight * 0.02),

//               // Lien "Mot de passe oublié"
//               TextButton(
//                 onPressed: () {
//                   // Ajoute ici la logique pour réinitialiser le mot de passe
//                 },
//                 child: Text(
//                   "Mot de passe oublié ?",
//                   style: TextStyle(
//                     fontSize: screenWidth * (isPortrait ? 0.04 : 0.03),
//                     color: Colors.black,
//                   ),
//                 ),
//               ),

//               SizedBox(height: screenHeight * 0.02),

//               // Bouton Se connecter
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: () {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (context) => const AvantHome(),
//                       ),
//                     );
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: const Color(0xFFF8BF13),
//                     foregroundColor: Colors.black,
//                     padding: EdgeInsets.symmetric(
//                       vertical: screenHeight * 0.02,
//                     ),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                   ),
//                   child: Text(
//                     'Se connecter',
//                     style: TextStyle(
//                       fontWeight: FontWeight.bold,
//                       fontSize: screenWidth * (isPortrait ? 0.045 : 0.035),
//                     ),
//                   ),
//                 ),
//               ),

//               SizedBox(height: screenHeight * 0.03),

//               // Lien vers l'inscription
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Text(
//                     "Vous n'avez pas de compte ? ",
//                     style: TextStyle(
//                       color: Colors.grey,
//                       fontSize: screenWidth * (isPortrait ? 0.04 : 0.03),
//                     ),
//                   ),
//                   GestureDetector(
//                     onTap: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => const InscriptionPage(),
//                         ),
//                       );
//                     },
//                     child: Text(
//                       "S'inscrire",
//                       style: TextStyle(
//                         color: const Color(0xFF0461B6),
//                         fontWeight: FontWeight.bold,
//                         fontSize: screenWidth * (isPortrait ? 0.04 : 0.03),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// ... existing code ...

import 'package:flutter/material.dart';
import 'package:tranoo_pro/data/screens/avant_home.dart';
import 'package:tranoo_pro/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:tranoo_pro/providers/auth_provider.dart' as myauth;
import 'package:tranoo_pro/widgets/auth_message_popup.dart';
import 'package:tranoo_pro/utils/phone_country_config.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';

import 'inscription_page.dart';

class ConnexionPage extends StatefulWidget {
  const ConnexionPage({super.key});

  @override
  State<ConnexionPage> createState() => _ConnexionPageState();
}

class _ConnexionPageState extends State<ConnexionPage> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  bool isPhoneFocused = false;
  bool isPasswordFocused = false;
  final userService = UserService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? selectedCountry;
  String? selectedCountryCode;
  bool _isLoading = false;
  final _logger = Logger('ConnexionPage');
  bool _obscurePasswordLogin = true;
  bool _useLegacyEmail = false;

  PhoneCountryConfig get _phoneCountry =>
      phoneCountryByName(selectedCountry);

  @override
  void initState() {
    super.initState();
    selectedCountry = kPhoneCountries.first.name;
    selectedCountryCode = kPhoneCountries.first.code;
  }

  Future<void> _openCountryPicker() async {
    final controller = TextEditingController();
    var filtered = List<PhoneCountryConfig>.from(kPhoneCountries);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final pickerL10n = AppLocalizations.of(ctx)!;
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
                          hintText: pickerL10n.searchCountryOrCode,
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
                            filtered = kPhoneCountries.where((c) {
                              return c.name.toLowerCase().contains(q) ||
                                  c.code.toLowerCase().contains(q);
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
                              c.flag,
                              style: const TextStyle(fontSize: 18),
                            ),
                            title: Text(c.name),
                            trailing: Text(
                              c.code,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onTap: () {
                              setState(() {
                                selectedCountry = c.name;
                                selectedCountryCode = c.code;
                                _phoneController.clear();
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

  Future<String?> fetchUserRole() async {
    // Récupère le token Firebase de l'utilisateur connecté
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final idToken = await user.getIdToken();
    // Appel backend pour récupérer le profil utilisateur (exemple)
    final response = await userService.dio.get(
      '/protected/me',
      options: Options(headers: {'Authorization': 'Bearer $idToken'}),
    );
    return response.data['user']['role'];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: screenHeight * (isPortrait ? 0.1 : 0.05)),
              Center(
                child: Image.asset(
                  "assets/images/logo_connexion.png",
                  width: screenWidth * (isPortrait ? 0.6 : 0.4),
                  height: screenHeight * (isPortrait ? 0.15 : 0.2),
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: screenHeight * (isPortrait ? 0.05 : 0.1)),
              Text(l10n.signInTitle,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: screenWidth * (isPortrait ? 0.06 : 0.04),
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
              Text(l10n.welcomeTranooPro,
                style: TextStyle(
                  fontSize: screenWidth * (isPortrait ? 0.04 : 0.03),
                ),
              ),
              SizedBox(height: screenHeight * (isPortrait ? 0.05 : 0.1)),

              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text(l10n.phoneTab)),
                  ButtonSegment(
                    value: true,
                    label: Text(l10n.legacyEmailTab),
                  ),
                ],
                selected: {_useLegacyEmail},
                onSelectionChanged: (s) {
                  setState(() {
                    _useLegacyEmail = s.first;
                    _phoneController.clear();
                  });
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              SizedBox(height: screenHeight * 0.02),

              if (_useLegacyEmail)
                Focus(
                  onFocusChange: (focused) {
                    setState(() => isPhoneFocused = focused);
                  },
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: l10n.emailAddress,
                      hintText: l10n.emailExample,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: screenHeight * 0.02,
                        horizontal: screenWidth * 0.04,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.amber),
                      ),
                    ),
                  ),
                )
              else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: _openCountryPicker,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 14,
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
                            _phoneCountry.flag,
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
                          const Icon(Icons.keyboard_arrow_down, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Focus(
                      onFocusChange: (focused) {
                        setState(() => isPhoneFocused = focused);
                      },
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: l10n.phoneNumber,
                          hintText: _phoneCountry.digitHint,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: screenHeight * 0.02,
                            horizontal: screenWidth * 0.04,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.amber),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: screenHeight * 0.02),

              // Champ Mot de passe
              Focus(
                onFocusChange: (focused) {
                  setState(() => isPasswordFocused = focused);
                },
                child: TextField(
                  controller: _passwordController,
                  obscureText: _obscurePasswordLogin,
                  decoration: InputDecoration(
                    labelText: l10n.password,
                    labelStyle: TextStyle(
                      color: Colors.grey,
                      fontSize: screenWidth * (isPortrait ? 0.04 : 0.03),
                    ),
                    prefixIcon: Icon(
                      Icons.lock_outline,
                      color: isPasswordFocused ? Colors.amber : Colors.grey,
                      size: screenWidth * (isPortrait ? 0.06 : 0.04),
                    ),
                    hintText: l10n.passwordDotsHint,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePasswordLogin
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePasswordLogin = !_obscurePasswordLogin;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: screenHeight * 0.02,
                      horizontal: screenWidth * 0.04,
                    ),
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
                      borderSide: const BorderSide(
                        color: Colors.amber,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: screenHeight * 0.02),

              // Lien "Mot de passe oublié"
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/auth/forgot-password');
                },
                child: Text(l10n.forgotPassword,
                  style: TextStyle(
                    fontSize: screenWidth * (isPortrait ? 0.04 : 0.03),
                    color: Colors.black,
                  ),
                ),
              ),

              SizedBox(height: screenHeight * 0.02),

              // Bouton Se connecter
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          // Vérification des champs obligatoires
                          final identifier = _phoneController.text.trim();
                          final password = _passwordController.text.trim();
                          if (identifier.isEmpty || password.isEmpty) {
                            AuthMessagePopup.showWarning(
                              context,
                              title: l10n.missingFieldsTitle,
                              subtitle: l10n.completeRequiredInfo,
                            );
                            return;
                          }
                          setState(() {
                            _isLoading = true;
                          });
                          try {
                            if (_useLegacyEmail) {
                              if (!identifier.contains('@')) {
                                AuthMessagePopup.showWarning(
                                  context,
                                  title: l10n.invalidEmailTitle,
                                  subtitle: l10n.legacyEmailSubtitle,
                                );
                                setState(() => _isLoading = false);
                                return;
                              }
                              _logger.info(
                                'Connexion legacy email: $identifier',
                              );
                              await userService.loginUser(
                                email: identifier,
                                password: password,
                              );
                            } else {
                              if (!_phoneCountry
                                  .isValidNationalNumber(identifier)) {
                                AuthMessagePopup.showWarning(
                                  context,
                                  title: l10n.invalidPhoneTitle,
                                  subtitle: l10n.invalidPhoneSubtitle(
                                    _phoneCountry.digitHint,
                                    selectedCountry ?? l10n.thisCountry,
                                  ),
                                );
                                setState(() => _isLoading = false);
                                return;
                              }
                              final cc = selectedCountryCode ?? '+229';
                              _logger.info('Connexion téléphone Pro: $cc$identifier');
                              await userService.loginWithPhone(
                                countryCode: cc,
                                nationalNumber: identifier,
                                password: password,
                                app: TranooAuthApp.pro,
                              );
                            }

                            // Charger l'utilisateur et le rôle via AuthProvider puis naviguer
                            final auth = context.read<myauth.AuthProvider>();
                            await auth.reloadUser();

                            // Attendre brièvement que l'état soit bien propagé
                            final startWait = DateTime.now();
                            while (auth.user == null &&
                                DateTime.now().difference(startWait) <
                                    const Duration(seconds: 5)) {
                              await Future.delayed(
                                const Duration(milliseconds: 100),
                              );
                            }

                            if (auth.user == null) {
                              throw Exception(l10n.sessionInitFailed);
                            }
                            final userRole =
                                auth.user?['role']?.toString().toLowerCase();
                            if (isTranooBuyerAppRole(userRole)) {
                              await FirebaseAuth.instance.signOut();
                              if (!mounted) return;
                              AuthMessagePopup.showError(
                                context,
                                title: l10n.proBuyerBlockedTitle,
                                subtitle: l10n.proBuyerBlockedSubtitle,
                                buttonText: l10n.understood,
                              );
                              return;
                            }

                            // Mettre à jour le timestamp de dernière connexion
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setInt(
                              'lastLoginTime',
                              DateTime.now().millisecondsSinceEpoch,
                            );

                            if (!mounted) return;

                            // Vérifier si livreur/chauffeur sans photo de profil
                            final userRoleRaw = auth.user?['role']?.toString();
                            final userPhoto = auth.user?['photo']?.toString();
                            final needsPhotoUpload =
                                (userRoleRaw == 'livreur' ||
                                        userRoleRaw == 'chauffeur') &&
                                    (userPhoto == null || userPhoto.isEmpty);

                            if (needsPhotoUpload) {
                              // Rediriger vers le profil pour upload photo obligatoire
                              AuthMessagePopup.showInfo(
                                context,
                                title: l10n.actionRequired,
                                subtitle: l10n.uploadProfilePhotoRequired,
                              );
                              if (!mounted) return;
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AvantHome(),
                                ),
                                (route) => false,
                              );
                              // Naviguer vers l'onglet profil après un court délai
                              Future.delayed(const Duration(milliseconds: 500),
                                  () {
                                if (mounted) {
                                  // Le profil sera affiché avec l'animation d'alerte
                                }
                              });
                            } else {
                              AuthMessagePopup.showSuccess(
                                context,
                                title: l10n.loginSuccessTitle,
                              );
                              if (!mounted) return;
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AvantHome(),
                                ),
                                (route) => false,
                              );
                            }
                          } catch (e) {
                            _logger.warning(
                              'Erreur lors de la connexion Firebase: ${e.toString()}',
                            );
                            String title = l10n.cannotLoginTitle;
                            String? subtitle;
                            if (e.toString().contains('user-not-found')) {
                              title = l10n.noSellerAccount;
                              subtitle = l10n.createAccountToContinue;
                            } else if (e.toString().contains('wrong-password')) {
                              title = l10n.wrongPassword;
                              subtitle = l10n.verifyAndRetry;
                            } else if (e.toString().contains('invalid-credential')) {
                              title = l10n.wrongCredentials;
                              subtitle = l10n.verifyAndRetry;
                            } else if (e.toString().contains('user-disabled')) {
                              title = l10n.accountBlocked;
                              subtitle = l10n.contactSupport;
                            } else if (e.toString().contains('too-many-requests')) {
                              title = l10n.tooManyAttempts;
                              subtitle = l10n.retryInMinutes;
                            } else if (e.toString().contains('network') ||
                                e.toString().contains('SocketException') ||
                                e.toString().contains('Failed host lookup')) {
                              title = l10n.cannotReachServer;
                              subtitle = l10n.checkInternet;
                            } else if (e.toString().contains('server') ||
                                e.toString().contains('500') ||
                                e.toString().contains('503')) {
                              title = l10n.serviceTemporaryIssue;
                              subtitle = l10n.tryAgainLater;
                            }
                            if (!mounted) return;
                            AuthMessagePopup.showError(
                              context,
                              title: title,
                              subtitle: subtitle,
                              buttonText: l10n.retry,
                            );
                          } finally {
                            setState(() {
                              _isLoading = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF8BF13),
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(
                      vertical: screenHeight * 0.02,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : Text(l10n.signInTitle,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize:
                                screenWidth * (isPortrait ? 0.045 : 0.035),
                          ),
                        ),
                ),
              ),

              SizedBox(height: screenHeight * 0.03),

              // Lien vers l'inscription
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.noAccount,
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
                          builder: (context) => const InscriptionPage(),
                        ),
                      );
                    },
                    child: Text(
                      l10n.signUp,
                      style: TextStyle(
                        color: const Color(0xFF0461B6),
                        fontWeight: FontWeight.bold,
                        fontSize: screenWidth * (isPortrait ? 0.04 : 0.03),
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
  }

  // (supprimé) _getUserRoleFromString : non utilisé
}
