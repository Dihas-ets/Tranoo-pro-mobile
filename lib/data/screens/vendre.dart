import 'package:flutter/material.dart';
import 'package:tranoo_pro/data/screens/create_sell.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';

class Vendre extends StatefulWidget {
  const Vendre({super.key});

  @override
  State<Vendre> createState() => _VendreState();
}

class _VendreState extends State<Vendre> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  Widget build(BuildContext context) {
    return CreateSellPage();
  }
}
