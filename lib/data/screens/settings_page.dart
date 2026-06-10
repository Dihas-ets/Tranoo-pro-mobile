import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';
import 'package:tranoo_pro/languesentreprise.dart';
import 'package:tranoo_pro/providers/auth_provider.dart' as myauth;
import 'package:tranoo_pro/providers/locale_provider.dart';
import 'package:tranoo_pro/utils/locale_helper.dart';
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
  AppLocalizations get l10n => AppLocalizations.of(context)!;

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
        final languageCode = data['language'] ?? 'fr';
        if (LocaleHelper.supportedLanguageCodes.contains(languageCode)) {
          await context.read<LocaleProvider>().setLocale(Locale(languageCode));
        }
        setState(() {
          _selectedCurrency = data['currency'] ?? 'XOF';
          _notificationsEnabled = data['notificationsEnabled'] ?? true;
          _locationTrackingEnabled = data['locationTrackingEnabled'] ?? true;
        });
      } else {
        // Fallback sur les préférences locales
        final prefs = await SharedPreferences.getInstance();
        setState(() {
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
        _selectedCurrency = prefs.getString('currency') ?? 'XOF';
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _locationTrackingEnabled = prefs.getBool('location_tracking_enabled') ?? true;
      });
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.settings,
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
          _buildSectionHeader(l10n.preferences),
          _buildLanguageSetting(),
          _buildCurrencySetting(l10n),
          _buildSectionHeader(l10n.notifications),
          _buildNotificationSetting(l10n),
          _buildSectionHeader(l10n.geolocation),
          _buildLocationTrackingSetting(l10n),
          _buildSectionHeader(l10n.account),
          _buildLogoutButton(l10n),
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
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, _) {
        final l10n = AppLocalizations.of(context)!;
        return Container(
          color: Colors.white,
          child: ListTile(
            leading: const Icon(Icons.language, color: Color(0xFFF8BF13)),
            title: Text(l10n.language),
            subtitle: Text(
              LocaleHelper.languageLabel(localeProvider.languageCode, l10n),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
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
    );
  }

  Widget _buildCurrencySetting(AppLocalizations l10n) {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: const Icon(Icons.monetization_on, color: Color(0xFFF8BF13)),
        title: Text(l10n.currency),
        subtitle: Text(_selectedCurrency),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showCurrencyDialog(l10n),
      ),
    );
  }

  Widget _buildNotificationSetting(AppLocalizations l10n) {
    return Container(
      color: Colors.white,
      child: SwitchListTile(
        secondary: const Icon(Icons.notifications, color: Color(0xFFF8BF13)),
        title: Text(l10n.enableNotifications),
        subtitle: Text(l10n.pushNotificationsSubtitle),
        value: _notificationsEnabled,
        onChanged: _saveNotificationSetting,
        activeColor: const Color(0xFFF8BF13),
      ),
    );
  }

  Widget _buildLocationTrackingSetting(AppLocalizations l10n) {
    return Container(
      color: Colors.white,
      child: SwitchListTile(
        secondary: const Icon(Icons.location_on, color: Color(0xFFF8BF13)),
        title: Text(l10n.locationTracking),
        subtitle: Text(l10n.shareRealtimeLocation),
        value: _locationTrackingEnabled,
        onChanged: _saveLocationTrackingSetting,
        activeColor: const Color(0xFFF8BF13),
      ),
    );
  }

  Widget _buildLogoutButton(AppLocalizations l10n) {
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
            child: Text(
              l10n.logout,
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

  void _showCurrencyDialog(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.chooseCurrency),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCurrencyOption('XOF', l10n.cfaFranc),
            _buildCurrencyOption('EUR', l10n.currencyEuro),
            _buildCurrencyOption('USD', l10n.usDollar),
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

