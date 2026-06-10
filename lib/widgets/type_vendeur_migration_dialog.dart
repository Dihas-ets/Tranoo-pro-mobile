import 'package:flutter/material.dart';
import 'package:tranoo_pro/data/screens/settings_type_vendeur_page.dart';
import 'package:tranoo_pro/services/user_service.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';

class TypeVendeurMigrationDialog extends StatelessWidget {
  final Function(String) onTypeSelected;

  const TypeVendeurMigrationDialog({
    Key? key,
    required this.onTypeSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8BF13).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.storefront,
                    color: Color(0xFFF8BF13),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(l10n.sellerUpdateTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: 'Fermer',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l10n.sellerTypeChoiceIntro,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[800],
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 8),
            Text(l10n.sellerTypeChoiceHint,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  await navigator.push(
                    MaterialPageRoute(
                      builder: (_) => const SettingsTypeVendeurPage(),
                    ),
                  );
                  final selectedType = UserService().vendeurType?.trim();
                  if (selectedType != null && selectedType.isNotEmpty) {
                    onTypeSelected(selectedType);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF8BF13),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(l10n.makeChoice),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
