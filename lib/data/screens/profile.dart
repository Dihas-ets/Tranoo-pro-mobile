// ignore_for_file: unused_local_variable

import 'dart:io'; // Pour manipuler les fichiers images
import 'package:tranoo_pro/l10n/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Importer la bibliothèque pour la sélection d'image
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:tranoo_pro/services/user_service.dart';
import 'package:tranoo_pro/utils/cloudinary_upload.dart'; // Importer le composant d'upload Cloudinary
import 'package:provider/provider.dart';
import 'package:tranoo_pro/providers/auth_provider.dart' as local_auth;

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> with SingleTickerProviderStateMixin {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  String? selectedGender;
  String? selectedCountry;
  File? _image; // Pour stocker l'image sélectionnée
  Map<String, dynamic>? userData;
  bool loading = true;
  String? errorMsg;

  // Édition compte
  bool isEditingName = false;
  bool isEditingPassword = false;
  String? newPassword;
  bool isSaving = false;

  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _prenomsController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telephoneController = TextEditingController();
  
  // Animation pour alerte photo manquante
  late AnimationController _alertController;
  late Animation<double> _pulseAnimation;

  final List<Map<String, String>> countries = [
    {"name": "Bénin", "flag": "assets/flags/benin.svg"},
    {"name": "France", "flag": "assets/flags/france.svg"},
    {"name": "USA", "flag": "assets/flags/usa.svg"},
    {"name": "Canada", "flag": "assets/flags/canada.svg"},
  ];

  @override
  void initState() {
    super.initState();
    fetchUser();
    
    // Initialiser l'animation d'alerte
    _alertController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _alertController,
        curve: Curves.easeInOut,
      ),
    );
  }
  
  @override
  void dispose() {
    _alertController.dispose();
    _nomController.dispose();
    _prenomsController.dispose();
    _emailController.dispose();
    _telephoneController.dispose();
    super.dispose();
  }

  String get _fullDisplayName {
    final p = (userData?['prenoms'] ?? '').toString().trim();
    final n = (userData?['nom'] ?? '').toString().trim();
    return [p, n].where((s) => s.isNotEmpty).join(' ');
  }

  void _syncControllersFromUserData() {
    _nomController.text = userData?['nom']?.toString() ?? '';
    _prenomsController.text = userData?['prenoms']?.toString() ?? '';
    _emailController.text = userData?['email']?.toString() ?? '';
    _telephoneController.text = userData?['telephone']?.toString() ?? '';
  }
  
  bool get _needsPhotoAlert {
    if (userData == null) return false;
    final role = userData!['role']?.toString();
    final hasPhoto = userData!['photo'] != null && 
                     userData!['photo'].toString().isNotEmpty;
    return (role == 'livreur' || role == 'chauffeur') && !hasPhoto;
  }

  Future<void> fetchUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          loading = false;
          userData = null;
          errorMsg = "Utilisateur non connecté.";
        });
        return;
      }
      final idToken = await user.getIdToken();
      final String baseUrl = getBaseUrl();
      final dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          headers: {'Authorization': 'Bearer $idToken'},
        ),
      );
      final response = await dio.get('/protected/me');
      setState(() {
        userData = response.data['user'];
        loading = false;
        errorMsg = null;
        _syncControllersFromUserData();
      });
    } catch (e) {
      setState(() {
        loading = false;
        userData = null;
        errorMsg =
            "Impossible de charger le profil. Vérifiez votre connexion ou vos droits.";
      });
    }
  }

  // Fonction pour choisir une image depuis la galerie et upload Cloudinary
  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      // Upload Cloudinary
      final url = await uploadImageToCloudinary(
        _image!,
        folder: CloudinaryFolders.profiles,
      );
      if (url != null) {
        await _uploadPhotoUrl(url);
      }
    }
  }

  // Met à jour la photo de profil avec l'URL Cloudinary
  Future<void> _uploadPhotoUrl(String url) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final idToken = await user.getIdToken();
    final String baseUrl = getBaseUrl();
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        headers: {'Authorization': 'Bearer $idToken'},
      ),
    );
    await dio.patch('/users/me', data: {"photo": url});
    final me = await dio.get('/protected/me');
    final refreshedUser = me.data['user'];
    await local_auth.AuthProvider.saveUserToPrefs(idToken, refreshedUser);
    if (mounted) {
      context.read<local_auth.AuthProvider>().reloadUser();
      setState(() {
        userData?['photo'] = url;
      });
    }
  }

  Future<void> _saveProfile() async {
    final nom = _nomController.text.trim();
    final prenoms = _prenomsController.text.trim();
    final email = _emailController.text.trim();
    final telephone = _telephoneController.text.trim();

    if (nom.isEmpty || prenoms.isEmpty || email.isEmpty || telephone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.fillAllFields)),
      );
      return;
    }

    setState(() => isSaving = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => isSaving = false);
      return;
    }

    try {
      final idToken = await user.getIdToken();
      final dio = Dio(
        BaseOptions(
          baseUrl: getBaseUrl(),
          headers: {'Authorization': 'Bearer $idToken'},
        ),
      );
      await dio.patch('/users/me', data: {
        'nom': nom,
        'prenoms': prenoms,
        'email': email,
        'telephone': telephone,
      });
      final me = await dio.get('/protected/me');
      final refreshedUser = me.data['user'];
      await local_auth.AuthProvider.saveUserToPrefs(idToken, refreshedUser);
      if (mounted) {
        await context.read<local_auth.AuthProvider>().reloadUser();
      }
      await fetchUser();
      if (mounted) {
        setState(() {
          isSaving = false;
          isEditingName = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileUpdated)),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.response?.data?['message']?.toString() ??
                  'Erreur lors de la mise à jour.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.saveProfileError)),
        );
      }
    } finally {
      if (mounted && isSaving) {
        setState(() => isSaving = false);
      }
    }
  }

  // Edition du mot de passe
  Future<void> _savePassword() async {
    if (newPassword == null || newPassword!.length < 6) return;
    setState(() {
      isSaving = true;
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final idToken = await user.getIdToken();
    final String baseUrl = getBaseUrl();
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        headers: {'Authorization': 'Bearer $idToken'},
      ),
    );
    final role = userData?['role']?.toString();
    final int minLen = role == 'admin' ? 11 : 6;
    if (newPassword == null || newPassword!.length < minLen) {
      setState(() {
        isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Le mot de passe doit contenir au moins ${minLen.toString()} caractères.',
          ),
        ),
      );
      return;
    }
    await dio.patch('/users/password', data: {"newPassword": newPassword});
    setState(() {
      isEditingPassword = false;
      isSaving = false;
      newPassword = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.passwordChangedSuccess)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final isPortrait = mediaQuery.orientation == Orientation.portrait;
    final spacing = screenHeight * (isPortrait ? 0.02 : 0.03);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(l10n.account,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body:
          loading
              ? _buildProfileSkeleton(context)
              : errorMsg != null
              ? Center(child: Text(errorMsg!))
              : userData == null
              ? Center(child: Text(l10n.noUserData))
              : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Stack(
                              children: [
                                Transform.scale(
                                  scale: _needsPhotoAlert ? _pulseAnimation.value : 1.0,
                                  child: Container(
                                    decoration: _needsPhotoAlert
                                        ? BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.red,
                                              width: 3,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.red.withOpacity(0.5),
                                                blurRadius: 15,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          )
                                        : null,
                                    child: CircleAvatar(
                                      radius: 60,
                                      backgroundColor: Colors.grey[300],
                                      backgroundImage:
                                          _image != null
                                              ? FileImage(_image!) as ImageProvider
                                              : (userData != null &&
                                                  userData!["photo"] != null &&
                                                  userData!["photo"]
                                                      .toString()
                                                      .isNotEmpty)
                                              ? NetworkImage(userData!["photo"].toString()) as ImageProvider
                                              : null,
                                      child: (_image == null && 
                                              (userData == null || 
                                               userData!["photo"] == null || 
                                               userData!["photo"].toString().isEmpty))
                                          ? Icon(Icons.person, size: 60, color: Colors.grey[600])
                                          : null,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      border: Border.all(
                                        color: Colors.grey,
                                        width: 1,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 24,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                // Badge d'alerte si photo manquante (livreur/chauffeur)
                                if (_needsPhotoAlert)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.warning,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                      // Message d'alerte si photo manquante
                      if (_needsPhotoAlert) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade300, width: 2),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '⚠️ Photo de profil obligatoire pour ${userData!['role'] == 'livreur' ? 'les livreurs' : 'les chauffeurs'}. Veuillez uploader une photo claire.',
                                  style: TextStyle(
                                    color: Colors.red.shade900,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      // Nom / Email / Téléphone (mode lecture ou édition groupée)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                isEditingName
                                    ? Column(
                                        children: [
                                          TextField(
                                            controller: _prenomsController,
                                            autofocus: true,
                                            decoration: InputDecoration(
                                              labelText: l10n.firstName,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextField(
                                            controller: _nomController,
                                            decoration: InputDecoration(
                                              labelText: l10n.lastName,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        _fullDisplayName.isNotEmpty
                                            ? _fullDisplayName
                                            : (userData?["nom"] ?? ""),
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                const SizedBox(height: 4),
                                isEditingName
                                    ? TextField(
                                        controller: _emailController,
                                        keyboardType: TextInputType.emailAddress,
                                        decoration: InputDecoration(
                                          labelText: l10n.email,
                                        ),
                                      )
                                    : Text(
                                        userData?["email"] ?? "",
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 16,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                const SizedBox(height: 4),
                                isEditingName
                                    ? TextField(
                                        controller: _telephoneController,
                                        keyboardType: TextInputType.phone,
                                        decoration: InputDecoration(
                                          labelText: l10n.phone,
                                        ),
                                      )
                                    : Text(
                                        userData?["telephone"] ?? "",
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 16,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              isEditingName ? Icons.close : Icons.edit,
                            ),
                            onPressed: () {
                              setState(() {
                                if (isEditingName) {
                                  isEditingName = false;
                                  _syncControllersFromUserData();
                                } else {
                                  isEditingName = true;
                                  _syncControllersFromUserData();
                                }
                              });
                            },
                          ),
                          if (isEditingName)
                            IconButton(
                              icon: isSaving
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFF8BF13),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.check,
                                      color: Color(0xFFF8BF13),
                                    ),
                              onPressed: isSaving ? null : _saveProfile,
                            ),
                        ],
                      ),
                      SizedBox(height: spacing * 2),
                      // Section informations personnelles (readonly)
                      _buildProfileSection(
                        context,
                        title: l10n.personalInfo,
                        items: [
                          _buildProfileItem(
                            context,
                            icon: Icons.person,
                            label: "Prénom(s)",
                            value: userData?['prenoms']?.toString() ?? '—',
                          ),
                          _buildProfileItem(
                            context,
                            icon: Icons.person_outline,
                            label: "Nom",
                            value: userData?['nom']?.toString() ?? '—',
                          ),
                          _buildProfileItem(
                            context,
                            icon: Icons.email,
                            label: "Email",
                            value: userData?['email']?.toString() ?? '—',
                          ),
                          _buildProfileItem(
                            context,
                            icon: Icons.phone,
                            label: "Téléphone",
                            value: userData?['telephone']?.toString() ?? '—',
                          ),
                        ],
                      ),
                      SizedBox(height: spacing * 2),
                      _buildProfileSection(
                        context,
                        title: l10n.security,
                        items: [
                          _buildProfileItem(
                            context,
                            icon: Icons.lock,
                            label: "Mot de passe",
                            value: "********",
                            showEdit: false,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildProfileSkeleton(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final isPortrait = mediaQuery.orientation == Orientation.portrait;
    final spacing = screenHeight * (isPortrait ? 0.02 : 0.03);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(radius: 60, backgroundColor: Colors.grey[300]),
          const SizedBox(height: 20),
          Container(height: 24, width: 120, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Container(height: 18, width: 180, color: Colors.grey[200]),
          const SizedBox(height: 10),
          Container(height: 18, width: 140, color: Colors.grey[200]),
          SizedBox(height: spacing * 2),
          Container(height: 18, width: 200, color: Colors.grey[200]),
          SizedBox(height: spacing * 2),
          Container(height: 18, width: 200, color: Colors.grey[200]),
        ],
      ),
    );
  }

  Widget _buildProfileSection(
    BuildContext context, {
    required String title,
    required List<Widget> items,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final fontSize = screenWidth * (isPortrait ? 0.04 : 0.03);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: fontSize * 1.1,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: screenWidth * 0.03),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 25),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildProfileItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool showEdit = false,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final fontSize = screenWidth * (isPortrait ? 0.04 : 0.03);
    final iconSize = screenWidth * (isPortrait ? 0.06 : 0.04);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: screenWidth * 0.03,
      ),
      child: Row(
        children: [
          Icon(icon, size: iconSize, color: Colors.grey[700]),
          SizedBox(width: screenWidth * 0.04),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: fontSize * 0.9,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}
