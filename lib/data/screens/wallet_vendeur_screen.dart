import 'package:flutter/material.dart';
import 'package:tranoo_pro/data/screens/wallet_screen.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';

/// Portefeuille vendeur : même écran que les livreurs, métriques vendeur.
class WalletVendeurScreen extends StatelessWidget {
  const WalletVendeurScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const WalletScreen(vendorMode: true);
  }
}
