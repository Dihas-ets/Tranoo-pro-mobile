import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';

class FirstLaunchLocationDialog extends StatelessWidget {
  final VoidCallback onDismissed;

  const FirstLaunchLocationDialog({
    super.key,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Use MediaQuery to compute sensible max dimensions for the dialog
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.8; // allow up to 80% of screen height
    final maxWidth = media.size.width * 0.95; // up to 95% of screen width

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          // Provide both maxWidth and maxHeight to avoid overflow on small screens
          maxHeight: maxHeight,
          maxWidth: maxWidth.clamp(280.0, double.infinity),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header avec icône
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withAlpha((0.1 * 255).round()),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.blue,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.welcomeTranooProExclaim,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(l10n.locationAuthorization,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Message principal
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.locationUsageIntro,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._getUsagePoints().map((point) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.check_circle,
                                size: 20,
                                color: Colors.green[600],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                point,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Avertissement arrière-plan
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha((0.1 * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withAlpha((0.3 * 255).round())),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange[700],
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'La localisation peut être utilisée même lorsque l\'application est en arrière-plan pour assurer un suivi continu des services.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.orange[700],
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Boutons
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                          child: Center(
                            child: ElevatedButton(
                              onPressed: () async {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setBool(
                                  'tranoo_pro_has_seen_welcome',
                                  true,
                                );
                                await prefs.setBool('is_first_launch', false);
                                if (!context.mounted) return;
                                Navigator.of(context).pop();
                                await _requestPermissions();
                                onDismissed();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(l10n.continueAction),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Texte informatif
                Center(
                  child: Text(l10n.changeDecisionLaterInSettings,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<String> _getUsagePoints() {
    return [
      'Suivi en temps réel des livraisons et transports',
      'Optimisation des trajets pour les livreurs et chauffeurs',
      'Coordination des services avec les clients',
      'Amélioration de la précision des services locaux',
    ];
  }

  Future<void> _requestPermissions() async {
    try {
      // Demander d'abord la permission de localisation fine
      var status = await Permission.location.request();
      
      // Si accordée, vérifier si on a besoin de la permission d'arrière-plan
      if (status.isGranted) {
        // Pour les rôles qui nécessitent le suivi en arrière-plan
        bool needsBackground = await _needsBackgroundPermission();
        
        if (needsBackground) {
          // Demander la permission d'arrière-plan
          await Permission.locationAlways.request();
        }
      }
    } catch (e) {
      print('Erreur lors de la demande de permission: $e');
    }
  }

  Future<bool> _needsBackgroundPermission() async {
    // Pour l'instant, on suppose que l'utilisateur pourrait avoir un rôle
    // nécessitant la localisation en arrière-plan
    // Cette logique pourra être affinée plus tard selon le rôle réel
    return true;
  }
}
