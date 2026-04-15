// ignore_for_file: unused_local_variable

import 'dart:io'; // Pour manipuler les fichiers images

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Importer la bibliothèque pour la sélection d'image
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:tranoo_pro/services/user_service.dart';
import 'package:tranoo_pro/utils/cloudinary_upload.dart'; // Importer le composant d'upload Cloudinary
import 'package:provider/provider.dart';
import 'package:tranoo_pro/providers/auth_provider.dart' as local_auth;
import 'package:tranoo_pro/services/subscription_access_service.dart';
import 'package:tranoo_pro/data/screens/seller_subscription_page.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> with SingleTickerProviderStateMixin {
  String? selectedGender;
  String? selectedCountry;
  File? _image; // Pour stocker l'image sélectionnée
  Map<String, dynamic>? userData;
  bool loading = true;
  String? errorMsg;

  // Ajout pour édition dynamique
  bool isEditingName = false;
  bool isEditingEmail = false;
  bool isEditingPhone = false;
  bool isEditingPassword = false;
  String? editedName;
  String? editedEmail;
  String? editedPhone;
  String? newPassword;
  bool isSaving = false;
  final SubscriptionAccessService _subscriptionService =
      SubscriptionAccessService();
  SellerAccessStatus? _subscriptionStatus;
  List<Map<String, dynamic>> _subscriptionHistory = [];
  bool _subscriptionLoading = true;
  
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
    _loadSubscriptionData();
    
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

  Future<void> _loadSubscriptionData() async {
    setState(() {
      _subscriptionLoading = true;
    });
    try {
      final status = await _subscriptionService.getSellerAccessStatus();
      final history = await _subscriptionService.getSubscriptionHistory(limit: 10);
      if (!mounted) return;
      setState(() {
        _subscriptionStatus = status;
        _subscriptionHistory = history;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _subscriptionStatus = null;
        _subscriptionHistory = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _subscriptionLoading = false;
        });
      }
    }
  }

  String _formatDateShort(dynamic raw) {
    if (raw == null) return '--';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return '--';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
  
  @override
  void dispose() {
    _alertController.dispose();
    super.dispose();
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
        editedName = userData?["nom"] ?? "";
        editedEmail = userData?["email"] ?? "";
        editedPhone = userData?["telephone"] ?? "";
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

  // Edition des infos utilisateur
  Future<void> _saveProfileField(String field, String value) async {
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
    await dio.patch('/users/me', data: {field: value});
    // Après modification, on resynchronise toutes les données
    await fetchUser();
    setState(() {
      isSaving = false;
      isEditingName = false;
      isEditingEmail = false;
      isEditingPhone = false;
    });
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
      const SnackBar(content: Text('Mot de passe modifié avec succès.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final isPortrait = mediaQuery.orientation == Orientation.portrait;
    final spacing = screenHeight * (isPortrait ? 0.02 : 0.03);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          "Compte",
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
              ? Center(child: Text("Aucune donnée utilisateur"))
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
                                    ? TextField(
                                        autofocus: true,
                                        onChanged: (v) => editedName = v,
                                        controller: TextEditingController(
                                          text: editedName,
                                        ),
                                        decoration: const InputDecoration(
                                          labelText: "Nom complet",
                                        ),
                                      )
                                    : Text(
                                        userData?["nom"] ?? "",
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                const SizedBox(height: 4),
                                isEditingName
                                    ? TextField(
                                        onChanged: (v) => editedEmail = v,
                                        controller: TextEditingController(
                                          text: editedEmail,
                                        ),
                                        decoration: const InputDecoration(
                                          labelText: "Email",
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
                                        onChanged: (v) => editedPhone = v,
                                        controller: TextEditingController(
                                          text: editedPhone,
                                        ),
                                        decoration: const InputDecoration(
                                          labelText: "Téléphone",
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
                                  editedName = userData?["nom"] ?? "";
                                  editedEmail = userData?["email"] ?? "";
                                  editedPhone = userData?["telephone"] ?? "";
                                } else {
                                  isEditingName = true;
                                  editedName = userData?["nom"] ?? "";
                                  editedEmail = userData?["email"] ?? "";
                                  editedPhone = userData?["telephone"] ?? "";
                                }
                              });
                            },
                          ),
                          if (isEditingName)
                            IconButton(
                              icon: const Icon(
                                Icons.check,
                                color: Color(0xFFF8BF13),
                              ),
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      if ((editedName ?? '').trim().isEmpty ||
                                          (editedEmail ?? '').trim().isEmpty ||
                                          (editedPhone ?? '').trim().isEmpty) {
                                        return;
                                      }
                                      setState(() => isSaving = true);
                                      await _saveProfileField(
                                        "nom",
                                        editedName!.trim(),
                                      );
                                      await _saveProfileField(
                                        "email",
                                        editedEmail!.trim(),
                                      );
                                      await _saveProfileField(
                                        "telephone",
                                        editedPhone!.trim(),
                                      );
                                      setState(() {
                                        isSaving = false;
                                        isEditingName = false;
                                      });
                                    },
                            ),
                        ],
                      ),
                      SizedBox(height: spacing * 2),
                      // Section informations personnelles (readonly)
                      _buildProfileSection(
                        context,
                        title: "Informations personnelles",
                        items: [
                          _buildProfileItem(
                            context,
                            icon: Icons.person,
                            label: "Nom complet",
                            value: "********",
                          ),
                          _buildProfileItem(
                            context,
                            icon: Icons.email,
                            label: "Email",
                            value: "********",
                          ),
                          _buildProfileItem(
                            context,
                            icon: Icons.phone,
                            label: "Téléphone",
                            value: "********",
                          ),
                        ],
                      ),
                      SizedBox(height: spacing * 2),
                      _buildProfileSection(
                        context,
                        title: "Sécurité",
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
                      if ((userData?['role'] ?? '').toString().toLowerCase() ==
                          'vendeur') ...[
                        SizedBox(height: spacing * 2),
                        _buildSubscriptionSection(),
                      ],
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildSubscriptionSection() {
    if (_subscriptionLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final status = _subscriptionStatus;
    final warning = status?.showExpiryWarning == true;
    final warningText = status?.paidPlanActive == true
        ? 'Votre abonnement expire dans ${status?.paidPlanRemainingDays ?? 0} jour(s).'
        : 'Votre periode gratuite se termine dans ${status?.freeTrialRemainingDays ?? 0} jour(s).';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Abonnement vendeur',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Plan actuel: ${status?.currentPlanLabel ?? 'Inconnu'}',
            style: const TextStyle(
              color: Color(0xFF0461B6),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (warning) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4CC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF8BF13)),
              ),
              child: Text(
                warningText,
                style: const TextStyle(
                  color: Color(0xFF8A6D3B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SellerSubscriptionPage(),
                  ),
                ).then((_) => _loadSubscriptionData());
              },
              child: const Text('Gerer mon abonnement'),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Historique (10 derniers)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (_subscriptionHistory.isEmpty)
            const Text(
              'Aucun paiement d\'abonnement pour le moment.',
              style: TextStyle(color: Colors.grey),
            )
          else
            ..._subscriptionHistory.map((tx) {
              final amount = tx['amount']?.toString() ?? '--';
              final txStatus = tx['status']?.toString() ?? '--';
              final createdAt = _formatDateShort(tx['createdAt']);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEDEDED)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long, color: Color(0xFFF8BF13)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$amount FCFA - $txStatus',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      createdAt,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }),
        ],
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
