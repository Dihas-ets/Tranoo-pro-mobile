import 'package:flutter/material.dart';
import 'package:tranoo_pro/data/screens/connexion_page.dart';
import 'package:tranoo_pro/data/screens/notifications.dart';
import 'package:tranoo_pro/data/screens/profile2.dart';
import 'package:tranoo_pro/data/screens/historique_transit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:tranoo_pro/services/user_service.dart';
import 'package:provider/provider.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';
import 'package:tranoo_pro/languesentreprise.dart';
import 'package:tranoo_pro/providers/auth_provider.dart' as local_auth;
import 'package:tranoo_pro/widgets/skeleton/app_skeleton.dart';
import 'package:tranoo_pro/widgets/transitaire_profile_ui.dart';
import 'package:tranoo_pro/data/screens/seller_subscription_page.dart';

class ProfilUtilisateur2 extends StatefulWidget {
  const ProfilUtilisateur2({super.key});

  @override
  State<ProfilUtilisateur2> createState() => _ProfilUtilisateur2State();
}

class _ProfilUtilisateur2State extends State<ProfilUtilisateur2> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  String selectedCurrencyValue = "XOF";
  Map<String, dynamic>? userData;
  bool loading = true;
  String? errorMsg;
  double? _walletBalance;
  String _walletCurrency = "XOF";
  bool _walletLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUser();
    _loadWallet();
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
      debugPrint('[delete-account][profil-transitaire] currentUser=${user?.uid}');
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        debugPrint('[delete-account][profil-transitaire] idToken null');
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
        '[delete-account][profil-transitaire] DELETE ${getBaseUrl()}/users/me',
      );
      final response = await dio.delete('/users/me');
      debugPrint(
        '[delete-account][profil-transitaire] success status=${response.statusCode} data=${response.data}',
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
        '[delete-account][profil-transitaire] DioException type=${e.type} status=${e.response?.statusCode} data=${e.response?.data}',
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
      debugPrint('[delete-account][profil-transitaire] unexpected error=$e');
      if (context.mounted) Navigator.of(context).pop(); // close progress
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.unexpectedDeletionError),
        ),
      );
    }
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
      });
    } catch (e) {
      setState(() {
        loading = false;
        userData = null;
        errorMsg = AppLocalizations.of(context)!.profileLoadError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SkeletonPresets.transitaireProfile(),
      );
    }
    if (errorMsg != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text(errorMsg!)),
      );
    }
    if (userData == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text(l10n.noUserData)),
      );
    }
    if (userData != null && userData?['role'] != 'transitaire') {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text(l10n.transitaireAccessOnly)),
      );
    }
    final profileMap = Map<String, dynamic>.from(userData!);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          l10n.myProfile,
          style: const TextStyle(
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
      body: TransitaireProfileView(
        user: profileMap,
        isOwner: true,
        embeddedInMainNav: true,
        onGalleryChanged: (_) => fetchUser(),
        onEditProfile: () async {
              await Navigator.push(
                context,
            MaterialPageRoute(builder: (_) => const Profile2()),
              );
              await fetchUser();
            },
        onOpenHistory: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HistoriqueTransitPage()),
          );
        },
        onOpenSubscription: () {
              Navigator.push(
                context,
                MaterialPageRoute(
              builder: (_) => const SellerSubscriptionPage(forTransitaire: true),
                ),
              );
            },
        onOpenNotifications: () {
              Navigator.push(
                context,
            MaterialPageRoute(builder: (_) => Notifications()),
          );
        },
        onOpenLanguage: () {
              Navigator.push(
                context,
            MaterialPageRoute(builder: (_) => const LanguesEntreprise()),
          );
        },
        onLogout: () async {
          await Provider.of<local_auth.AuthProvider>(context, listen: false)
              .logout();
          if (!context.mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const ConnexionPage()),
            (route) => false,
          );
        },
        onDeleteAccount: _deleteAccount,
        settingsExtra: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Portefeuille',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: kTransitaireNavy,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _walletLoading
                    ? 'Solde : chargement...'
                    : 'Solde : ${_walletBalance?.toStringAsFixed(0) ?? '0'} $_walletCurrency',
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: () => _showCurrencyDialog(context),
                child: Text(
                  'Devise : $selectedCurrencyValue',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                ),
            ],
          ),
        ),
      ),
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
