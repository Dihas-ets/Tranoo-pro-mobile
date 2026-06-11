import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';

class LocationPermissionDialog extends StatelessWidget {
  final String userRole;
  final VoidCallback onPermissionGranted;
  final VoidCallback onPermissionDenied;

  const LocationPermissionDialog({
    super.key,
    required this.userRole,
    required this.onPermissionGranted,
    required this.onPermissionDenied,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icône et titre
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.blue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.locationRequired,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                      ),
                      Text(l10n.authorizationRequired,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Message explicatif selon le rôle
            Text(
              _getRoleSpecificMessage(),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.black87,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 16),

            // Points clés
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.whatWeUse,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ..._getUsagePoints().map((point) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Colors.green[600],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                point,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Colors.black87,
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

            // Avertissement sur l'arrière-plan
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'La localisation est utilisée même lorsque l\'application est en arrière-plan pour assurer un suivi continu.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.orange[700],
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
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _requestPermissions(context, onPermissionGranted);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    // Neutral button label before the system permission prompt.
                    child: Text(l10n.continueAction),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getRoleSpecificMessage() {
    switch (userRole.toLowerCase()) {
      case 'livreur':
        return 'Tranoo Pro utilise votre position en temps réel pour assurer le suivi de vos livraisons et permettre aux clients de suivre leur commande en direct.';
      case 'chauffeur':
        return 'Tranoo Pro utilise votre position pour optimiser vos trajets, coordonner les missions et permettre aux clients de suivre votre progression.';
      case 'vendeur':
        return 'Tranoo Pro utilise votre position pour proposer des services locaux et optimiser la logistique de vos ventes.';
      case 'agent commercial':
        return 'Tranoo Pro utilise votre position pour coordonner vos missions commerciales et optimiser vos déplacements.';
      case 'transitaire':
        return 'Tranoo Pro utilise votre position pour suivre les expéditions et coordonner les opérations logistiques.';
      default:
        return 'Tranoo Pro utilise votre position pour fournir des services de localisation et optimiser votre expérience.';
    }
  }

  List<String> _getUsagePoints() {
    switch (userRole.toLowerCase()) {
      case 'livreur':
        return [
          'Suivi en temps réel des livraisons',
          'Mise à jour automatique de votre position',
          'Optimisation des trajets de livraison',
          'Information aux clients sur votre progression'
        ];
      case 'chauffeur':
        return [
          'Suivi des missions de transport',
          'Optimisation des itinéraires',
          'Coordination avec les clients',
          'Mise à jour de votre disponibilité'
        ];
      case 'vendeur':
        return [
          'Propositions de services locaux',
          'Optimisation de la logistique',
          'Coordination des livraisons',
          'Amélioration de l\'expérience utilisateur'
        ];
      case 'agent commercial':
        return [
          'Coordination des missions commerciales',
          'Optimisation des déplacements',
          'Suivi des rendez-vous clients',
          'Mise à jour de votre disponibilité'
        ];
      case 'transitaire':
        return [
          'Suivi des expéditions',
          'Coordination logistique',
          'Optimisation des entrepôts',
          'Mise à jour des statuts de livraison'
        ];
      default:
        return [
          'Amélioration des services',
          'Optimisation de l\'expérience',
          'Coordination des missions',
          'Suivi des activités'
        ];
    }
  }

  Future<void> _requestPermissions(
      BuildContext context, VoidCallback onGranted) async {
    try {
      // Demander d'abord la permission de localisation fine
      var status = await Permission.location.request();

      if (status.isGranted) {
        // Vérifier si on a besoin de la permission d'arrière-plan
        bool needsBackground = await _needsBackgroundPermission();

        if (needsBackground) {
          // Demander la permission d'arrière-plan
          var backgroundStatus = await Permission.locationAlways.request();

          if (backgroundStatus.isGranted) {
            onGranted();
          } else {
            _showBackgroundPermissionDialog(context, onGranted);
          }
        } else {
          onGranted();
        }
      } else {
        _showPermissionDeniedDialog(context);
      }
    } catch (e) {
      _showErrorDialog(context, e.toString());
    }
  }

  Future<bool> _needsBackgroundPermission() async {
    // Vérifier si l'app a besoin de la permission d'arrière-plan
    // selon le rôle de l'utilisateur
    return ['livreur', 'chauffeur'].contains(userRole.toLowerCase());
  }

  void _showBackgroundPermissionDialog(
      BuildContext context, VoidCallback onGranted) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.backgroundLocationTitle),
        content: const Text(
          'Pour assurer un suivi continu de vos missions, nous avons besoin d\'accéder à votre localisation même lorsque l\'application est en arrière-plan.\n\nVous pouvez activer cette permission dans les paramètres de votre appareil.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onPermissionDenied();
            },
            child: Text(l10n.later),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Ouvrir les paramètres de l'application
              await openAppSettings();
            },
            child: Text(l10n.deviceSettings),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.permissionDenied),
        content: Text(
          'La localisation est nécessaire pour utiliser les fonctionnalités de ${_getRoleDisplayName()}. Certaines fonctionnalités pourraient être limitées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.understood),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String error) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erreur'),
        content: Text(
            'Une erreur est survenue lors de la demande de permission: $error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  String _getRoleDisplayName() {
    switch (userRole.toLowerCase()) {
      case 'livreur':
        return 'livreur';
      case 'chauffeur':
        return 'chauffeur';
      case 'vendeur':
        return 'vendeur';
      case 'agent commercial':
        return 'agent commercial';
      case 'transitaire':
        return 'transitaire';
      default:
        return 'professionnel';
    }
  }
}
