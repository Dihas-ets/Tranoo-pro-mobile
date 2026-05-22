import 'package:flutter/material.dart';

/// Règles auth partagées (inscription, mot de passe oublié, affichage).
class AuthConfig {
  AuthConfig._();

  static const String appDisplayName = 'Tranoo Pro';

  static const int passwordMinLength = 8;

  static bool isPasswordValid(String password) =>
      password.length >= passwordMinLength;

  static const int otpLength = 6;
  static final RegExp otpPattern = RegExp(r'^\d{6}$');

  static String displayEntreprise(String? entreprise) {
    final v = entreprise?.trim();
    if (v != null && v.isNotEmpty) return v;
    return appDisplayName;
  }

  static Widget whatsAppPhonePrefixIcon() {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 8),
      child: Image.asset(
        'assets/images/whatsapp_icon.png',
        width: 22,
        height: 22,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.chat,
          color: Color(0xFF25D366),
          size: 22,
        ),
      ),
    );
  }
}
