import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../services/user_service.dart';
import '../../utils/role_redirect.dart';
import '../../providers/auth_provider.dart' as myauth;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:tranoo_pro/l10n/app_localizations.dart';
import 'package:tranoo_pro/utils/api_error_message.dart';
import 'avant_home.dart';

class SettingsTypeVendeurPage extends StatefulWidget {
  const SettingsTypeVendeurPage({Key? key}) : super(key: key);

  @override
  State<SettingsTypeVendeurPage> createState() => _SettingsTypeVendeurPageState();
}

class _SettingsTypeVendeurPageState extends State<SettingsTypeVendeurPage> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  UserRole? _currentType;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentType();
  }

  Future<void> _loadCurrentType() async {
    try {
      String? vt;
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final idToken = await user.getIdToken();
        final resp = await http.get(
          Uri.parse('${getBaseUrl()}/protected/me'),
          headers: {'Authorization': 'Bearer $idToken'},
        );
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          final userData = body['user'] as Map<String, dynamic>?;
          vt = userData?['vendeurType']?.toString();
        }
      }

      vt = vt?.trim();
      if (vt == null || vt.isEmpty) {
        vt = UserService().vendeurType?.trim();
      }

      // Hydrater le singleton local pour cohérence globale
      UserService().setVendeurType((vt == null || vt.isEmpty) ? null : vt);

      if (vt == 'vehicules') {
        _currentType = UserRole.vendeurVehicules;
      } else if (vt == 'pieces') {
        _currentType = UserRole.vendeurPieces;
      } else if (vt == 'motos') {
        _currentType = UserRole.vendeurMotos;
      } else {
        _currentType = UserRole.vendeur; // mixte + compat null
      }
    } catch (e) {
      print('Erreur lors du chargement du type de vendeur: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Type de vendeur"),
        backgroundColor: const Color(0xFFF8BF13),
        foregroundColor: Colors.black,
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300],
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(l10n.backToSettings),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Carte d'information
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8BF13).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFF8BF13).withOpacity(0.45),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFFB8860B),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Vous pouvez modifier votre type de vendeur à tout moment. Le changement sera appliqué immédiatement.",
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Type actuel
                  Text(
                    "Votre type actuel",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  if (_currentType != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8BF13).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFF8BF13).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getTypeIcon(_currentType!),
                            color: const Color(0xFFF8BF13),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getTypeLabel(_currentType!),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  _getTypeDescription(_currentType!),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 32),
                  
                  // Options de modification
                  Text(
                    "Changer de type",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  ...UserRole.values.where((role) => 
                    role == UserRole.vendeur || 
                    role == UserRole.vendeurVehicules || 
                    role == UserRole.vendeurPieces ||
                    role == UserRole.vendeurMotos
                  ).map((type) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: _isUpdating ? null : () => _showConfirmationDialog(type),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _currentType == type 
                                ? const Color(0xFFF8BF13)
                                : Colors.grey[300]!,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: _currentType == type 
                              ? const Color(0xFFF8BF13).withOpacity(0.1)
                              : Colors.transparent,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getTypeIcon(type),
                              color: _currentType == type 
                                  ? const Color(0xFFF8BF13)
                                  : Colors.grey[600],
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getTypeLabel(type),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _currentType == type 
                                          ? const Color(0xFFF8BF13)
                                          : Colors.black,
                                    ),
                                  ),
                                  Text(
                                    _getTypeDescription(type),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_currentType == type)
                              const Icon(
                                Icons.check_circle,
                                color: Color(0xFFF8BF13),
                                size: 24,
                              ),
                          ],
                        ),
                      ),
                    ),
                  )).toList(),
                  
                ],
              ),
            ),
    );
  }

  IconData _getTypeIcon(UserRole type) {
    switch (type) {
      case UserRole.vendeur:
        return Icons.category;
      case UserRole.vendeurVehicules:
        return Icons.directions_car;
      case UserRole.vendeurPieces:
        return Icons.build;
      case UserRole.vendeurMotos:
        return Icons.motorcycle;
      default:
        return Icons.person;
    }
  }

  String _getTypeLabel(UserRole type) {
    switch (type) {
      case UserRole.vendeur:
        return "Vendeur mixte";
      case UserRole.vendeurVehicules:
        return "Vendeur de véhicules";
      case UserRole.vendeurPieces:
        return "Vendeur de pièces";
      case UserRole.vendeurMotos:
        return "Vendeur de motos";
      default:
        return "Inconnu";
    }
  }

  String _getTypeDescription(UserRole type) {
    switch (type) {
      case UserRole.vendeur:
        return "Je vends des véhicules ET des pièces";
      case UserRole.vendeurVehicules:
        return "Je vends uniquement des véhicules";
      case UserRole.vendeurPieces:
        return "Je vends uniquement des pièces détachées";
      case UserRole.vendeurMotos:
        return "Je vends uniquement des motos";
      default:
        return "Type non défini";
    }
  }

  void _showConfirmationDialog(UserRole newType) {
    if (_currentType == newType) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmer le changement"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Vous allez changer de type de vendeur :"),
            const SizedBox(height: 12),
            Text(
              "De : ${_getTypeLabel(_currentType!)}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              "À : ${_getTypeLabel(newType)}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              "Ce changement sera appliqué immédiatement.",
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _updateTypeVendeur(newType);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF8BF13),
              foregroundColor: Colors.black,
            ),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  Future<void> _updateTypeVendeur(UserRole newType) async {
    setState(() {
      _isUpdating = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final auth = Provider.of<myauth.AuthProvider>(context, listen: false);
        final messenger = ScaffoldMessenger.of(context);
        final navigator = Navigator.of(context);
        final vendeurType = newType == UserRole.vendeurVehicules
            ? 'vehicules'
            : newType == UserRole.vendeurPieces
                ? 'pieces'
                : newType == UserRole.vendeurMotos
                    ? 'motos'
                    : 'mixte';
        final idToken = await user.getIdToken();
        final resp = await http.patch(
          Uri.parse('${getBaseUrl()}/users/me'),
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'vendeurType': vendeurType}),
        );
        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          final decoded = jsonDecode(resp.body);
          if (decoded is Map<String, dynamic>) {
            throw Exception(ApiErrorMessage.fromMap(l10n, decoded));
          }
          throw Exception('Erreur mise à jour (${resp.statusCode})');
        }

        UserService().setVendeurType(vendeurType);

        if (auth.user != null) {
          final updatedUser = Map<String, dynamic>.from(auth.user!);
          updatedUser['vendeurType'] = vendeurType;
          await myauth.AuthProvider.saveUserToPrefs(auth.token, updatedUser);
        }

        if (!mounted) return;

        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.sellerTypeUpdatedSuccess),
            backgroundColor: const Color(0xFFF8BF13),
            behavior: SnackBarBehavior.floating,
          ),
        );

        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;

        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AvantHome()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.updateError(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }
}
