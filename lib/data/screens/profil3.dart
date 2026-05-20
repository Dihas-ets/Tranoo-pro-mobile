import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tranoo_pro/data/screens/connexion_page.dart';
import 'package:tranoo_pro/data/screens/notifications.dart';
import 'package:tranoo_pro/data/screens/profile.dart';
import 'package:tranoo_pro/data/screens/parrainage_page.dart';
import 'package:tranoo_pro/data/screens/seller_subscription_page.dart';
import 'package:provider/provider.dart';
import 'package:tranoo_pro/providers/auth_provider.dart' as myauth;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:tranoo_pro/services/user_service.dart';
import 'package:tranoo_pro/services/subscription_access_service.dart';
import 'package:tranoo_pro/utils/cloudinary_upload.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const Profil3(),
    );
  }
}

class Profil3 extends StatefulWidget {
  const Profil3({super.key});

  @override
  Profil3State createState() => Profil3State();
}

class Profil3State extends State<Profil3> {
  File? _image;
  String selectedLanguage = "Français";
  String selectedCurrencyValue = "XOF";
  double? _walletBalance;
  String _walletCurrency = "XOF";
  bool _walletLoading = true;
  final SubscriptionAccessService _subscriptionService =
      SubscriptionAccessService();
  SellerAccessStatus? _subscriptionStatus;
  List<Map<String, dynamic>> _subscriptionHistory = [];
  bool _subscriptionLoading = true;
  // SUPPRIME : Map<String, dynamic>? userData;
  // SUPPRIME : bool loading = true;
  // SUPPRIME : String? errorMsg;

  @override
  void initState() {
    super.initState();
    _loadWallet();
    _loadSubscriptionData();
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
        _walletBalance = 0.0;
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
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cette action est irreversible.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'Votre compte, votre acces a l\'application et vos donnees liees seront supprimes.',
            ),
            SizedBox(height: 12),
            Text(
              'Assurez-vous de ne plus avoir besoin de ce compte avant de confirmer.',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
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
      debugPrint('[delete-account][profil3] currentUser=${user?.uid}');
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        debugPrint('[delete-account][profil3] idToken null');
        if (context.mounted) Navigator.of(context).pop(); // close progress
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session invalide. Reconnectez-vous.'),
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

      debugPrint('[delete-account][profil3] DELETE ${getBaseUrl()}/users/me');
      final response = await dio.delete('/users/me');
      debugPrint(
        '[delete-account][profil3] success status=${response.statusCode} data=${response.data}',
      );

      if (context.mounted) Navigator.of(context).pop(); // close progress
      await Provider.of<myauth.AuthProvider>(context, listen: false).logout();

      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const ConnexionPage()),
        (route) => false,
      );
    } on DioException catch (e) {
      debugPrint(
        '[delete-account][profil3] DioException type=${e.type} status=${e.response?.statusCode} data=${e.response?.data}',
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
      debugPrint('[delete-account][profil3] unexpected error=$e');
      if (context.mounted) Navigator.of(context).pop(); // close progress
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Une erreur inattendue est survenue pendant la suppression.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<myauth.AuthProvider>(context);
    final userData = authProvider.user;
    final loading = authProvider.loading;
    final errorMsg =
        userData == null && !loading ? "Utilisateur non connecté." : null;

    if (loading) return Center(child: CircularProgressIndicator());
    if (errorMsg != null) return Center(child: Text(errorMsg));
    if (userData == null) {
      return Center(child: Text("Aucune donnée utilisateur"));
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text(
          "Compte",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.black,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 15),
            _buildProfileCard(userData),
            const SizedBox(height: 50),
            _buildAccountOptions(),
            const SizedBox(height: 20),
            if ((userData["role"] ?? "").toString().toLowerCase() == "vendeur")
              _buildSubscriptionSection(),
            if ((userData["role"] ?? "").toString().toLowerCase() == "vendeur")
              const SizedBox(height: 20),
            const Text(
              "Plus",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildMoreOptions(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> userData) {
    final hasPhoto =
        userData["photo"] != null && userData["photo"].toString().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: _image != null
                      ? FileImage(_image!)
                      : hasPhoto
                          ? NetworkImage(userData["photo"]) as ImageProvider
                          : const AssetImage("assets/images/jenifer.jpg"),
                  child: (!hasPhoto && _image == null)
                      ? Icon(Icons.person, size: 32, color: Colors.grey[500])
                      : null,
                ),
                Positioned(
                  bottom: -2,
                  right: -4,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.edit,
                        size: 16,
                        color: Color(0xFFF8BF13),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userData["nom"] ?? "",
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  userData["email"] ?? "",
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _syncProfileAfterUpdate() async {
    if (!mounted) return;
    await Provider.of<myauth.AuthProvider>(context, listen: false).reloadUser();
    await _loadSubscriptionData();
    if (mounted) setState(() {});
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    setState(() => _image = File(pickedFile.path));
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final url = await uploadImageToCloudinary(
        _image!,
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
      await _syncProfileAfterUpdate();
    } catch (e) {
      debugPrint('Erreur upload photo profil3: $e');
    }
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
      subtitle:
          subtitle != null
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
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildListTile(
            title: "Mon compte",
            subtitle: "Apporter des modifications à votre compte",
            icon: Icons.person,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Profile()),
              );
              await _syncProfileAfterUpdate();
            },
          ),

          // _buildListTile(
          //   title: "Mes achats",
          //   subtitle: "Voir l'historique de vos commandes",
          //   icon: Icons.history,
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (context) => MesAchatsPage()),
          //     );
          //   },
          // ),
          // _buildListTile(
          //   title: "Mes avis",
          //   subtitle: "Consulter ou modifier vos commentaires",
          //   icon: Icons.reviews,
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (context) => MesAvisPage()),
          //     );
          //     // Rediriger vers une page des avis
          //   },
          // ),
          // _buildListTile(
          //   title: "Mes factures",
          //   subtitle: "Télécharger vos justificatifs d'achats",
          //   icon: Icons.receipt_long,
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (context) => MesFacturesPage()),
          //     );
          //   },
          // ),
          _buildListTile(
            title: "Parrainage",
            subtitle: "Gagnez en parrainant vos amis",
            icon: Icons.people,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ParrainagePage()),
              );
            },
          ),
          _buildListTile(
            title: "Suppression de compte",
            icon: Icons.delete_forever,
            color: Colors.red,
            onTap: () => _deleteAccount(),
          ),
          _buildListTile(
            title: "Déconnexion",
            icon: Icons.logout,
            color: Color(0xFFFFCE31),
            onTap: () async {
              await Provider.of<myauth.AuthProvider>(
                context,
                listen: false,
              ).logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => ConnexionPage()),
                (route) => false,
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
            "Notifications",
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
          _buildOption(
            "Langue",
            selectedLanguage,
            Icons.language,
            trailing: IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              onPressed: () => _showLanguageDialog(context),
            ),
          ),
          _buildOption(
            "Devise",
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
      trailing:
          trailing ??
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

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choisir une langue'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var lang in [
                "Français",
                "Anglais",
                "Espagnol",
                "Allemand",
                "Italien",
              ])
                ListTile(
                  title: Text(lang),
                  onTap: () {
                    setState(() {
                      selectedLanguage = lang;
                    });
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showCurrencyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choisir une devise'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('XOF'),
                onTap: () {
                  Navigator.pop(context, 'XOF');
                },
              ),
              ListTile(
                title: const Text('Euro'),
                onTap: () {
                  Navigator.pop(context, 'Euro');
                },
              ),
              ListTile(
                title: const Text('Dollars'),
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