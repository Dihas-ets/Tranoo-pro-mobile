# Carte gratuite (OpenStreetMap) – Tranoo Pro

## Ce qui a été fait

- **Affichage carte** : Google Maps a été remplacé par **Flutter Map + OpenStreetMap** (tuiles gratuites).
- **Navigation voix** : Bouton **« Naviguer »** sur la carte qui ouvre **Google Maps** (ou Waze) en externe pour la navigation au guidage.
- Tout le code lié à **Google Maps** dans l’app a été **commenté** (pas supprimé), pour pouvoir le réactiver plus tard si tu prends une clé API.

## À installer

Dans le projet **tranoo_pro**, exécuter une seule fois :

```bash
cd tranoo_pro
flutter pub get
```

Dépendances ajoutées dans `pubspec.yaml` :

- `flutter_map: ^6.0.0` – carte (tuiles OSM)
- `latlong2: ^0.9.1` – coordonnées (lat/lng)

**Aucune clé API**, **aucun compte Google Maps** à configurer pour l’affichage de la carte.

## Fichiers modifiés

| Fichier | Modification |
|--------|---------------|
| `pubspec.yaml` | Ajout de `flutter_map` et `latlong2` ; `google_maps_flutter` commenté |
| `lib/data/screens/osm_map_widget.dart` | **Nouveau** – widget carte OSM + bouton « Naviguer » |
| `lib/data/screens/delivery_map_screen.dart` | Carte remplacée par `OsmMapWidget` ; ancien code Google Maps commenté |
| `lib/data/screens/delivery_flow_screens.dart` | Idem pour les écrans « En route » et « Arrivé acheteur » |
| `lib/data/screens/suivi_gps_page.dart` | Idem pour le suivi GPS |

## Comportement

1. **Dans l’app** : carte OSM, marqueurs (fournisseur, acheteur, ma position), tracé (suivi GPS).
2. **Bouton « Naviguer »** : ouvre l’app Google Maps (ou Waze) avec la destination pour le guidage voix.
3. Le livreur revient dans Tranoo Pro pour valider les étapes (Sur place, Colis pris, Colis livré).

## Réactiver Google Maps plus tard

1. Dans `pubspec.yaml`, décommenter `google_maps_flutter` et commenter (ou retirer) `flutter_map` et `latlong2` si tu ne veux plus OSM.
2. Dans les écrans concernés, décommenter le code qui utilise `GoogleMap` et commenter l’usage de `OsmMapWidget`.
3. Configurer une clé API Google Maps (Android/iOS) dans les projets natifs.

## Coût

- **0 €** pour l’affichage carte (OSM) et le bouton « Naviguer » (ouverture de l’app Maps déjà installée).
