import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tranoo_pro/data/screens/connexion_page.dart';
import 'package:tranoo_pro/data/screens/create_sell.dart';
import 'package:tranoo_pro/data/screens/notifications.dart';
import 'package:tranoo_pro/data/screens/profile.dart';
import 'package:tranoo_pro/data/screens/create_sell_moto.dart';
import 'package:tranoo_pro/data/screens/create_sell2.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:tranoo_pro/services/user_service.dart';
import 'package:tranoo_pro/utils/cloudinary_upload.dart';
import 'package:provider/provider.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';
import 'package:tranoo_pro/languesentreprise.dart';
import 'package:tranoo_pro/providers/auth_provider.dart' as local_auth;
import 'package:tranoo_pro/providers/locale_provider.dart';
import 'package:tranoo_pro/utils/locale_helper.dart';
import 'package:tranoo_pro/utils/local_data_cache.dart';
import 'package:tranoo_pro/utils/pro_image_utils.dart';
import 'package:tranoo_pro/widgets/delayed_loader.dart';
import 'package:tranoo_pro/widgets/skeleton/app_skeleton.dart';
import 'package:tranoo_pro/services/subscription_access_service.dart';
import 'package:tranoo_pro/widgets/profile_location_tile.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const ProfilUtilisateurPage(),
    );
  }
}

class ProfilUtilisateurPage extends StatefulWidget {
  const ProfilUtilisateurPage({super.key});

  @override
  ProfilUtilisateurPageState createState() => ProfilUtilisateurPageState();
}

class ProfilUtilisateurPageState extends State<ProfilUtilisateurPage>
    with SingleTickerProviderStateMixin {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  File? _image;
  String selectedCurrencyValue = "XOF";
  Map<String, dynamic>? userData;
  bool loading = true;
  String? errorMsg;
  double? _walletBalance;
  String _walletCurrency = "XOF";
  bool _walletLoading = true;
  final SubscriptionAccessService _subscriptionService =
      SubscriptionAccessService();
  SellerAccessStatus? _subscriptionStatus;
  List<Map<String, dynamic>> _subscriptionHistory = [];
  bool _subscriptionLoading = true;
  bool _subscriptionHistoryLoading = false;
  
  // Animation pour alerte photo manquante
  late AnimationController _alertController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    
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

  Future<void> _loadProfileData() async {
    final cached = await LocalDataCache.readJsonMapStale('profile_me');
    if (cached != null && mounted) {
      setState(() {
        userData = cached;
        loading = false;
      });
      final photo = cached['photo']?.toString();
      if (photo != null && photo.isNotEmpty && mounted) {
        precacheProImages(
          context,
          [photo],
          cloudinaryWidthPx: 200,
        );
      }
    }
    await Future.wait<void>([fetchUser(), _loadWallet()]);
  }

  Future<void> _loadSubscriptionData() async {
    setState(() {
      _subscriptionLoading = true;
    });
    try {
      final dynamic rawDate =
          userData?['dateInscription'] ?? userData?['createdAt'];
      final inscriptionDate =
          rawDate != null ? DateTime.tryParse(rawDate.toString()) : null;
      final status = await _subscriptionService.getSellerAccessStatus(
        inscriptionDateOverride: inscriptionDate,
      );
      if (!mounted) return;
      setState(() {
        _subscriptionStatus = status;
      });
      _loadSubscriptionHistory();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _subscriptionStatus = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _subscriptionLoading = false;
        });
      }
    }
  }

  Future<void> _loadSubscriptionHistory() async {
    if (_subscriptionHistoryLoading) return;
    setState(() {
      _subscriptionHistoryLoading = true;
    });
    try {
      final history = await _subscriptionService.getSubscriptionHistory(limit: 50);
      if (!mounted) return;
      setState(() {
        _subscriptionHistory = history;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _subscriptionHistory = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _subscriptionHistoryLoading = false;
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
      final profile = response.data['user'] as Map<String, dynamic>?;
      if (profile != null) {
        await LocalDataCache.writeJsonMap('profile_me', profile);
      }
      setState(() {
        userData = profile;
        loading = false;
        errorMsg = null;
      });
      if (userData?['role'] == 'vendeur') {
        _loadSubscriptionData();
      }
    } catch (e) {
      setState(() {
        loading = false;
        userData = null;
        errorMsg =
            "Impossible de charger le profil. Vérifiez votre connexion ou vos droits.";
      });
    }
  }

  Future<void> _loadWallet() async {
    setState(() {
      _walletLoading = true;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _walletLoading = false;
          _walletBalance = null;
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
      final res = await dio.get('/wallet/me');
      setState(() {
        _walletBalance = (res.data['balance'] ?? 0).toDouble();
        _walletCurrency = (res.data['currency'] ?? 'XOF').toString();
        selectedCurrencyValue = _walletCurrency;
        _walletLoading = false;
      });
    } catch (e) {
      setState(() {
        _walletLoading = false;
      });
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Expanded(child: Text('Suppression du compte')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.accountDeletionIrreversible,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Votre compte, votre acces a l\'application et vos donnees liees seront supprimes.',
            ),
            const SizedBox(height: 12),
            Text(l10n.accountDeletionConfirmWarning,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: SizedBox(
          height: 40,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      debugPrint('[delete-account][profil-vendeur] currentUser=${user?.uid}');
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        debugPrint('[delete-account][profil-vendeur] idToken null');
        if (context.mounted) Navigator.of(context).pop(); // close progress
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.invalidSessionReconnect),
            ),
          );
        }
        return;
      }

      final dio = Dio(
        BaseOptions(
          baseUrl: getBaseUrl(),
          headers: {'Authorization': 'Bearer $idToken'},
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );

      debugPrint(
        '[delete-account][profil-vendeur] DELETE ${getBaseUrl()}/users/me',
      );
      final response = await dio.delete('/users/me');
      debugPrint(
        '[delete-account][profil-vendeur] success status=${response.statusCode} data=${response.data}',
      );

      if (context.mounted) Navigator.of(context).pop(); // close progress
      await Provider.of<local_auth.AuthProvider>(context, listen: false)
          .logout();

      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const ConnexionPage()),
        (route) => false,
      );
    } on DioException catch (e) {
      debugPrint(
        '[delete-account][profil-vendeur] DioException type=${e.type} status=${e.response?.statusCode} data=${e.response?.data}',
      );
      if (context.mounted) Navigator.of(context).pop(); // close progress
      final message = e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.sendTimeout
          ? 'Le serveur met trop de temps a repondre. Reessaie dans un instant.'
          : e.type == DioExceptionType.connectionError
              ? 'Impossible de joindre le serveur. Verifie ta connexion et l\'URL du backend.'
              : (e.response?.data is Map &&
                      (e.response?.data as Map)['message'] != null)
                  ? (e.response?.data as Map)['message'].toString()
                  : 'La suppression du compte a echoue. Reessaie plus tard.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      debugPrint('[delete-account][profil-vendeur] unexpected error=$e');
      if (context.mounted) Navigator.of(context).pop(); // close progress
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.unexpectedDeletionError),
        ),
      );
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
      // Upload vers Cloudinary avec le dossier profiles
      final url = await uploadImageToCloudinary(
        image,
        folder: CloudinaryFolders.profiles,
      );

      if (url != null) {
        // Mettre à jour via PATCH /users/me
        final idToken = await user.getIdToken();
        final String baseUrl = getBaseUrl();
        final dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            headers: {'Authorization': 'Bearer $idToken'},
          ),
        );
        await dio.patch('/users/me', data: {"photo": url});
        // Resynchronise avec le backend pour propager partout
        final me = await dio.get('/protected/me');
        final refreshedUser = me.data['user'];
        await local_auth.AuthProvider.saveUserToPrefs(idToken, refreshedUser);
        if (mounted) {
          context.read<local_auth.AuthProvider>().reloadUser();
          await fetchUser();
        }
      }
    } catch (e) {
      print('Erreur upload photo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading && userData == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SkeletonPresets.proSellerProfile(),
      );
    }
    if (errorMsg != null) return Center(child: Text(errorMsg!));
    if (userData == null) {
      return Center(child: Text(l10n.noUserData));
    }
    if (userData != null && userData?['role'] != 'vendeur') {
      return Center(child: Text(l10n.sellerAccessOnly));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Profil utilisateur",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            10,
            10,
            10,
            MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 15),
              ProfileLocationTile(userData: userData, onUpdated: fetchUser),
            // Profile card dynamique
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8BF13),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Stack(
                          clipBehavior: Clip.none,
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
                                  radius: 30,
                                  backgroundColor: Colors.grey[300],
                                  backgroundImage: _image != null
                                      ? FileImage(_image!) as ImageProvider
                                      : (userData != null &&
                                              userData!["photo"] != null &&
                                              userData!["photo"].toString().isNotEmpty)
                                          ? NetworkImage(userData!["photo"].toString())
                                              as ImageProvider
                                          : null,
                                  child: (_image == null &&
                                          (userData == null ||
                                              userData!["photo"] == null ||
                                              userData!["photo"].toString().isEmpty))
                                      ? Icon(Icons.person,
                                          size: 30, color: Colors.grey[600])
                                      : null,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: -5,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.black,
                                  size: 20,
                                ),
                              ),
                            ),
                            // Badge d'alerte si photo manquante (livreur/chauffeur)
                            if (_needsPhotoAlert)
                              Positioned(
                                top: -5,
                                right: -5,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.warning,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [
                          (userData?["prenoms"] ?? "").toString().trim(),
                          (userData?["nom"] ?? "").toString().trim(),
                        ].where((s) => s.isNotEmpty).join(' '),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        userData?["email"] ?? "",
                        style: const TextStyle(color: Colors.black),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Message d'alerte si photo manquante (livreur/chauffeur)
            if (_needsPhotoAlert) ...[
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
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
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 50),
            _buildAccountOptions(),
            const SizedBox(height: 20),
            _buildSubscriptionSection(),
            const SizedBox(height: 20),
            Text(l10n.more,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildMoreOptions(),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildSubscriptionHistoryTile(Map<String, dynamic> tx) {
    final amount = tx['amount']?.toString() ?? '--';
    final status = tx['status']?.toString() ?? '--';
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
              '$amount FCFA - $status',
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
  }

  void _showFullSubscriptionHistory() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Historique des abonnements'),
        content: SizedBox(
          width: double.maxFinite,
          child: _subscriptionHistory.isEmpty
              ? const Text(
                  'Aucun paiement d\'abonnement pour le moment.',
                  style: TextStyle(color: Colors.grey),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _subscriptionHistory.length,
                  itemBuilder: (context, index) =>
                      _buildSubscriptionHistoryTile(_subscriptionHistory[index]),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionSection() {
    if (_subscriptionLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SkeletonBox(
          width: double.infinity,
          height: 100,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      );
    }
    final status = _subscriptionStatus;
    final warning = status?.showExpiryWarning == true;
    final warningText = status?.paidPlanActive == true
        ? 'Votre abonnement expire dans ${status?.paidPlanRemainingDays ?? 0} jour(s).'
        : 'Votre periode gratuite se termine dans ${status?.freeTrialRemainingDays ?? 0} jour(s).';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.sellerSubscription,
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
          const SizedBox(height: 12),
          const Text(
            'Historique (5 derniers)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (_subscriptionHistoryLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_subscriptionHistory.isEmpty)
            const Text(
              'Aucun paiement d\'abonnement pour le moment.',
              style: TextStyle(color: Colors.grey),
            )
          else ...[
            ..._subscriptionHistory.take(5).map(_buildSubscriptionHistoryTile),
            if (_subscriptionHistory.length > 5)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _showFullSubscriptionHistory,
                  child: const Text('Voir plus'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildListTile({
    required String title,
    String? subtitle,
    required IconData icon,
    Widget? trailing,
    Color? color,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Color(0xFFFFCE31)),
      title: Text(title, style: const TextStyle()),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            )
          : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildAccountOptions() {
    final vendeurType = (userData?['vendeurType'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final canSellVehicles =
        vendeurType.isEmpty || vendeurType == 'mixte' || vendeurType == 'vehicules';
    final canSellPieces =
        vendeurType.isEmpty || vendeurType == 'mixte' || vendeurType == 'pieces';
    final canSellMotos = vendeurType == 'motos';

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildListTile(
            title: l10n.myAccount,
            subtitle: l10n.editAccountSubtitle,
            icon: Icons.person,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Profile()),
              );
              await fetchUser();
            },
          ),
          if (canSellVehicles)
            _buildListTile(
              title: l10n.sellMyCar,
              subtitle: l10n.becomeSellerSubtitle,
              icon: Icons.car_rental,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CreateSellPage()),
                );
              },
            ),
          if (canSellMotos)
            _buildListTile(
              title: 'Vendre ma moto',
              subtitle: l10n.becomeSellerSubtitle,
              icon: Icons.motorcycle,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreateSellMotoPage()),
                );
              },
            ),
          if (canSellPieces)
            _buildListTile(
              title: l10n.sellMyPart,
              subtitle: l10n.becomeSellerSubtitle,
              icon: Icons.build,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CreateSellPage2()),
                );
              },
            ),
          _buildListTile(
            title: l10n.accountDeletion,
            icon: Icons.delete_forever,
            color: Colors.red,
            onTap: () => _deleteAccount(),
          ),
          _buildListTile(
            title: l10n.logout,
            icon: Icons.logout,
            color: Color(0xFFFFCE31),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ConnexionPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMoreOptions() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          _buildOption(
            l10n.notifications,
            "",
            Icons.notifications,
            badge: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Notifications()),
              );
            },
          ),
          Consumer<LocaleProvider>(
            builder: (context, localeProvider, _) {
              final l10n = AppLocalizations.of(context)!;
              return _buildOption(
                l10n.language,
                LocaleHelper.languageLabel(
                  localeProvider.languageCode,
                  l10n,
                ),
                Icons.language,
                trailing: IconButton(
                  icon: const Icon(Icons.arrow_forward_ios),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LanguesEntreprise(),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          _buildOption(
            l10n.currency,
            selectedCurrencyValue,
            Icons.monetization_on,
            trailing: IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              onPressed: () => _showCurrencyDialog(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
    String title,
    String value,
    IconData icon, {
    bool badge = false,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Color(0xFFFFCE31)),
      title: Row(
        children: [
          Text(title, style: const TextStyle()),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      trailing: trailing ??
          (badge
              ? const Icon(Icons.circle, size: 12, color: Colors.red)
              : const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.black,
                )),
      onTap: onTap,
    );
  }

  void _showCurrencyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.chooseCurrency),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(l10n.currencyXof),
                onTap: () {
                  Navigator.pop(context, 'XOF');
                },
              ),
              ListTile(
                title: Text(l10n.currencyEuro),
                onTap: () {
                  Navigator.pop(context, 'Euro');
                },
              ),
              ListTile(
                title: Text(l10n.currencyDollars),
                onTap: () {
                  Navigator.pop(context, 'Dollars');
                },
              ),
            ],
          ),
        );
      },
    ).then((selectedCurrency) {
      if (selectedCurrency != null) {
        setState(() {
          selectedCurrencyValue = selectedCurrency;
        });
      }
    });
  }
}
