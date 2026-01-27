import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:tranoo_pro/providers/auth_provider.dart' as myauth;
import 'package:tranoo_pro/data/screens/connexion_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:tranoo_pro/config/backend_config.dart' as config;

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _selectedLanguage = 'Français';
  String _selectedCurrency = 'XOF';
  bool _notificationsEnabled = true;
  bool _locationTrackingEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      
      if (idToken == null) {
        // Charger depuis les préférences locales si pas de token
        final prefs = await SharedPreferences.getInstance();
        setState(() {
          _selectedLanguage = prefs.getString('language') ?? 'Français';
          _selectedCurrency = prefs.getString('currency') ?? 'XOF';
          _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
          _locationTrackingEnabled = prefs.getBool('location_tracking_enabled') ?? true;
        });
        return;
      }

      final baseUrl = config.getBackendBaseUrl();
      final res = await http.get(
        Uri.parse('$baseUrl/api/settings'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _selectedLanguage = _mapLanguageCode(data['language'] ?? 'fr');
          _selectedCurrency = data['currency'] ?? 'XOF';
          _notificationsEnabled = data['notificationsEnabled'] ?? true;
          _locationTrackingEnabled = data['locationTrackingEnabled'] ?? true;
        });
      } else {
        // Fallback sur les préférences locales
        final prefs = await SharedPreferences.getInstance();
        setState(() {
          _selectedLanguage = prefs.getString('language') ?? 'Français';
          _selectedCurrency = prefs.getString('currency') ?? 'XOF';
          _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
          _locationTrackingEnabled = prefs.getBool('location_tracking_enabled') ?? true;
        });
      }
    } catch (e) {
      print('Erreur chargement paramètres: $e');
      // Fallback sur les préférences locales
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _selectedLanguage = prefs.getString('language') ?? 'Français';
        _selectedCurrency = prefs.getString('currency') ?? 'XOF';
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _locationTrackingEnabled = prefs.getBool('location_tracking_enabled') ?? true;
      });
    }
  }

  Future<void> _saveLanguage(String language) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', language);
      
      if (idToken != null) {
        final baseUrl = config.getBackendBaseUrl();
        await http.patch(
          Uri.parse('$baseUrl/api/settings/language'),
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'language': _mapLanguageToCode(language)}),
        );
      }
      
      setState(() {
        _selectedLanguage = language;
      });
    } catch (e) {
      print('Erreur sauvegarde langue: $e');
    }
  }

  Future<void> _saveCurrency(String currency) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currency', currency);
      
      if (idToken != null) {
        final baseUrl = config.getBackendBaseUrl();
        await http.patch(
          Uri.parse('$baseUrl/api/settings/currency'),
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'currency': currency}),
        );
      }
      
      setState(() {
        _selectedCurrency = currency;
      });
    } catch (e) {
      print('Erreur sauvegarde devise: $e');
    }
  }

  Future<void> _saveNotificationSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    setState(() {
      _notificationsEnabled = value;
    });
  }

  Future<void> _saveLocationTrackingSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('location_tracking_enabled', value);
    setState(() {
      _locationTrackingEnabled = value;
    });
  }

  String _mapLanguageCode(String code) {
    switch (code) {
      case 'fr':
        return 'Français';
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      default:
        return 'Français';
    }
  }

  String _mapLanguageToCode(String language) {
    switch (language) {
      case 'Français':
        return 'fr';
      case 'English':
        return 'en';
      case 'Español':
        return 'es';
      default:
        return 'fr';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Paramètres',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: ListView(
        children: [
          _buildSectionHeader('Préférences'),
          _buildLanguageSetting(),
          _buildCurrencySetting(),
          _buildSectionHeader('Notifications'),
          _buildNotificationSetting(),
          _buildSectionHeader('Géolocalisation'),
          _buildLocationTrackingSetting(),
          _buildSectionHeader('Compte'),
          _buildLogoutButton(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildLanguageSetting() {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: const Icon(Icons.language, color: Color(0xFFF8BF13)),
        title: const Text('Langue'),
        subtitle: Text(_selectedLanguage),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showLanguageDialog(),
      ),
    );
  }

  Widget _buildCurrencySetting() {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: const Icon(Icons.monetization_on, color: Color(0xFFF8BF13)),
        title: const Text('Devise'),
        subtitle: Text(_selectedCurrency),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showCurrencyDialog(),
      ),
    );
  }

  Widget _buildNotificationSetting() {
    return Container(
      color: Colors.white,
      child: SwitchListTile(
        secondary: const Icon(Icons.notifications, color: Color(0xFFF8BF13)),
        title: const Text('Activer les notifications'),
        subtitle: const Text('Recevoir des notifications push'),
        value: _notificationsEnabled,
        onChanged: _saveNotificationSetting,
        activeColor: const Color(0xFFF8BF13),
      ),
    );
  }

  Widget _buildLocationTrackingSetting() {
    return Container(
      color: Colors.white,
      child: SwitchListTile(
        secondary: const Icon(Icons.location_on, color: Color(0xFFF8BF13)),
        title: const Text('Suivi de localisation'),
        subtitle: const Text('Partager votre position en temps réel'),
        value: _locationTrackingEnabled,
        onChanged: _saveLocationTrackingSetting,
        activeColor: const Color(0xFFF8BF13),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Consumer<myauth.AuthProvider>(
        builder: (context, auth, _) {
          return ElevatedButton(
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const ConnexionPage()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Déconnexion',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choisir une langue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption('Français'),
            _buildLanguageOption('English'),
            _buildLanguageOption('Español'),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String language) {
    return ListTile(
      title: Text(language),
      trailing: _selectedLanguage == language
          ? const Icon(Icons.check, color: Color(0xFFF8BF13))
          : null,
      onTap: () {
        _saveLanguage(language);
        Navigator.pop(context);
      },
    );
  }

  void _showCurrencyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choisir une devise'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCurrencyOption('XOF', 'Franc CFA'),
            _buildCurrencyOption('EUR', 'Euro'),
            _buildCurrencyOption('USD', 'Dollar US'),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyOption(String code, String name) {
    return ListTile(
      title: Text('$code - $name'),
      trailing: _selectedCurrency == code
          ? const Icon(Icons.check, color: Color(0xFFF8BF13))
          : null,
      onTap: () {
        _saveCurrency(code);
        Navigator.pop(context);
      },
    );
  }
}

