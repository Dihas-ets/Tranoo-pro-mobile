import 'dart:io';
import 'package:tranoo_pro/l10n/app_localizations.dart';
import 'package:tranoo_pro/widgets/skeleton/app_skeleton.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:tranoo_pro/providers/auth_provider.dart' as myauth;
import 'package:tranoo_pro/services/user_service.dart';
import 'package:tranoo_pro/utils/cloudinary_upload.dart';
import 'package:tranoo_pro/widgets/transitaire_profile_ui.dart';

class Profile2 extends StatefulWidget {
  const Profile2({super.key});

  @override
  State<Profile2> createState() => _Profile2State();
}

class _Profile2State extends State<Profile2> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  File? _image;
  String? selectedCountry = "Bénin";
  static const List<String> _countries = [
    'Bénin',
    'Togo',
    'Côte d\'Ivoire',
    'Sénégal',
    'Mali',
    'Niger',
    'Burkina-Faso',
    'Ghana',
    'Nigéria',
    'Maroc',
    'Gabon',
    'Cameroun',
    'France',
    'Belgique',
    'Canada',
  ];
  Map<String, dynamic>? userData;
  bool loading = true;
  String? errorMsg;
  bool isSaving = false;

  // Controllers pour champs dynamiques
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _prenomsController = TextEditingController();
  final TextEditingController _entrepriseController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telephoneController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Password
  final TextEditingController _newPasswordController = TextEditingController();
  bool _showNewPassword = false;

  @override
  void initState() {
    super.initState();
    fetchUser();
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomsController.dispose();
    _entrepriseController.dispose();
    _emailController.dispose();
    _telephoneController.dispose();
    _descriptionController.dispose();
    _newPasswordController.dispose();
    super.dispose();
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
        _nomController.text = userData?["nom"] ?? "";
        _prenomsController.text = userData?["prenoms"] ?? "";
        _entrepriseController.text = userData?["entreprise"] ?? "";
        _emailController.text = userData?["email"] ?? "";
        _telephoneController.text = userData?["telephone"] ?? "";
        _descriptionController.text =
            (userData?["transitaireDescription"] ?? "").toString();
        final pays = (userData?["pays"] ?? "").toString().trim();
        if (pays.isNotEmpty && _countries.contains(pays)) {
          selectedCountry = pays;
        }
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

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      await _uploadPhoto(_image!);
    }
  }

  Future<void> _uploadPhoto(File image) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final url = await uploadImageToCloudinary(
        image,
        folder: CloudinaryFolders.profiles,
      );
      if (url == null) return;
      final idToken = await user.getIdToken();
      final dio = Dio(
        BaseOptions(
          baseUrl: getBaseUrl(),
          headers: {'Authorization': 'Bearer $idToken'},
        ),
      );
      await dio.patch('/users/me', data: {'photo': url});
      if (mounted) {
        setState(() => userData?['photo'] = url);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (loading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SkeletonPresets.transitaireProfile(),
      );
    }
    if (errorMsg != null) return Center(child: Text(errorMsg!));
    if (userData == null)
      return Center(child: Text(l10n.noUserData));
    if (userData != null && userData?['role'] != 'transitaire') {
      return Center(child: Text(l10n.transitaireAccessOnly));
    }
    final photo = (userData?['photo'] ?? '').toString();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Modifier le profil',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: kTransitaireNavy,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kTransitaireNavy,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: const Color(0xFFE8F1FF),
                      backgroundImage: _image != null
                          ? FileImage(_image!)
                          : (photo.isNotEmpty ? NetworkImage(photo) : null)
                              as ImageProvider?,
                      child: _image == null && photo.isEmpty
                          ? Text(
                              TransitaireProfileHelpers.initials(userData!),
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                color: kTransitaireNavy,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: kTransitaireNavy,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _prenomsController,
              decoration: transitaireFieldDecoration(l10n.firstName),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nomController,
              decoration: transitaireFieldDecoration(l10n.lastName),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _entrepriseController,
              decoration: transitaireFieldDecoration(l10n.company),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: transitaireFieldDecoration(l10n.email),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _telephoneController,
              keyboardType: TextInputType.phone,
              decoration: transitaireFieldDecoration(l10n.phone),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: selectedCountry,
              decoration: transitaireFieldDecoration(l10n.country),
              items: _countries
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => selectedCountry = v),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              maxLength: 500,
              decoration: transitaireFieldDecoration(
                l10n.transitaireDescriptionLabel,
              ).copyWith(
                hintText: l10n.transitaireDescriptionHint,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _newPasswordController,
              obscureText: !_showNewPassword,
              decoration: transitaireFieldDecoration(l10n.newPassword).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _showNewPassword ? Icons.visibility_off : Icons.visibility,
                    color: kTransitaireNavy,
                  ),
                  onPressed: () =>
                      setState(() => _showNewPassword = !_showNewPassword),
                ),
              ),
            ),
            const SizedBox(height: 28),
            _buildUpdateButton(context),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() {
      isSaving = true;
    });
    final idToken = await user.getIdToken();
    final String baseUrl = getBaseUrl();
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        headers: {'Authorization': 'Bearer $idToken'},
      ),
    );

    final Map<String, dynamic> data = {
      'nom': _nomController.text.trim(),
      'prenoms': _prenomsController.text.trim(),
      'entreprise': _entrepriseController.text.trim(),
      'email': _emailController.text.trim(),
      'telephone': _telephoneController.text.trim(),
      if (selectedCountry != null) 'pays': selectedCountry,
      'transitaireDescription': _descriptionController.text.trim(),
    };

    try {
      await dio.patch('/users/me', data: data);
      // Mot de passe si fourni (nouveau seulement) avec validation minimale
      final role = userData?['role']?.toString();
      final int minLen = role == 'admin' ? 11 : 6;
      final newPwd = _newPasswordController.text;
      if (newPwd.isNotEmpty) {
        if (newPwd.length < minLen) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Le mot de passe doit contenir au moins ${minLen.toString()} caractères.',
                ),
              ),
            );
          }
        } else {
          await dio.patch('/users/password', data: {'newPassword': newPwd});
          _newPasswordController.clear();
          setState(() {
            _showNewPassword = false;
          });
        }
      }
      await fetchUser();
      if (mounted) {
        context.read<myauth.AuthProvider>().reloadUser();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.profileUpdated)));
      }
    } on DioException catch (e) {
      if (mounted) {
        final data = e.response?.data;
        final msg = data is Map
            ? (data['message']?.toString() ??
                data['error']?.toString())
            : null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg ?? 'Erreur lors de la mise à jour'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la mise à jour')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Widget _buildUpdateButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isSaving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: kTransitaireNavy,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        child: isSaving
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Enregistrer les modifications',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
      ),
    );
  }
}
