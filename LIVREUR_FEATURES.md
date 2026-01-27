# 📦 Page d'Accueil Livreur - Documentation des Fonctionnalités

## 🎯 Vue d'ensemble

La page d'accueil pour les livreurs (`livreur_home.dart`) est une interface complète et dynamique qui permet aux livreurs de gérer leurs livraisons, suivre leur position, recevoir des notifications et effectuer toutes les actions nécessaires à leur travail.

## ✨ Fonctionnalités Implémentées

### 1. **Gestion du Statut en Ligne/Hors Ligne**
- **Bouton flottant** : Permet de basculer entre statut "En ligne" et "Hors ligne"
- **Affichage visuel** : Badge de statut dans le header avec couleur verte (en ligne) ou grise (hors ligne)
- **API** : `POST /api/livreurs/toggle-status` pour mettre à jour le statut

### 2. **Géolocalisation en Temps Réel**
- **Permission** : Demande automatique de permission de localisation au démarrage
- **Tracking continu** : Suivi GPS en temps réel avec mise à jour automatique tous les 10 mètres
- **Mise à jour serveur** : Envoi automatique de la position au backend via `POST /api/livreurs/location`
- **Données envoyées** :
  - Latitude
  - Longitude
  - Timestamp

### 3. **Notifications en Temps Réel**
- **Badge de notification** : Affichage du nombre de notifications non lues dans le header
- **Chargement dynamique** : Récupération des notifications via `GET /api/notifications/livreur`
- **Écoute continue** : Rechargement automatique toutes les 5 secondes
- **Icône dédiée** : Bouton de notification dans le header avec compteur

### 4. **Gestion des Livraisons**

#### Livraisons en Attente
- **Affichage** : Liste des livraisons disponibles à accepter
- **Informations affichées** :
  - ID de la livraison
  - Destination
  - Montant
  - Statut "En attente"
- **Action** : Bouton "Accepter" pour prendre en charge une livraison
- **API** : `POST /api/livreurs/deliveries/{id}/accept`

#### Livraisons Actives
- **Affichage** : Liste des livraisons en cours
- **Informations affichées** :
  - ID de la livraison
  - Destination
  - Montant
  - Statut "Active"
- **Action** : Bouton "Compléter" pour finaliser une livraison
- **API** : `POST /api/livreurs/deliveries/{id}/complete`

### 5. **Portefeuille Intégré**
- **Solde principal** : Affichage du solde dans le header avec devise (XOF par défaut)
- **Chargement dynamique** : Récupération via `GET /api/wallet/me`
- **Format** : Affichage formaté avec séparateurs de milliers

### 6. **Actions Rapides (Quick Actions)**
Quatre actions rapides accessibles depuis le header :
- **Scanner QR** : Scanner un code QR pour valider une livraison
- **Mes Livraisons** : Accéder à la liste complète des livraisons
- **Suivi GPS** : Voir la carte avec le suivi en temps réel
- **Historique** : Consulter l'historique des livraisons

### 7. **Cartes de Statistiques**
- **Livraisons en attente** : Compteur avec icône orange
- **Livraisons actives** : Compteur avec icône jaune/orange (couleur de l'app)
- **Mise à jour dynamique** : Rechargement automatique des données

### 8. **Grille de Services (Mes Services)**
Neuf services accessibles via des icônes colorées :

1. **Notifications** (Rouge) : Gérer les notifications
2. **Valider** (Vert) : Valider des actions/livraisons
3. **Géolocalisation** (Bleu) : Voir la position actuelle
4. **Suivi** (Jaune/Orange) : Suivre les livraisons en cours
5. **Livraisons** (Orange) : Gérer toutes les livraisons
6. **Historique** (Violet) : Consulter l'historique
7. **Scanner** (Turquoise) : Scanner des codes QR
8. **Portefeuille** (Indigo) : Accéder au portefeuille
9. **Paramètres** (Gris) : Configurer l'application

### 9. **Design et UI**

#### Couleurs de l'Application
- **Jaune/Orange principal** : `Color(0xFFF8BF13)` - Utilisé pour les éléments principaux
- **Header** : Dégradé bleu foncé (`Color(0xFF0A1F44)` vers `Color(0xFF1a3a6a)`)
- **Fond** : Gris clair (`Color(0xFFF5F5F5)`)
- **Cartes** : Blanc avec ombres légères

#### Responsive Design
- Adaptation automatique selon l'orientation (portrait/paysage)
- Tailles d'icônes et espacements adaptatifs
- Grille de services responsive (3 colonnes)

### 10. **Pull to Refresh**
- **Rafraîchissement** : Glisser vers le bas pour recharger toutes les données
- **Indicateur** : Spinner de chargement pendant le rafraîchissement

## 🔧 APIs Backend Requises

### Endpoints à Implémenter :

1. **GET /api/wallet/me**
   - Retourne le solde et la devise du livreur

2. **GET /api/livreurs/deliveries/pending**
   - Retourne la liste des livraisons en attente
   - Format : `{ "deliveries": [...] }`

3. **GET /api/livreurs/deliveries/active**
   - Retourne la liste des livraisons actives
   - Format : `{ "deliveries": [...] }`

4. **POST /api/livreurs/toggle-status**
   - Change le statut en ligne/hors ligne
   - Body : `{ "isOnline": true/false }`

5. **POST /api/livreurs/location**
   - Met à jour la position GPS du livreur
   - Body : `{ "latitude": double, "longitude": double, "timestamp": string }`

6. **POST /api/livreurs/deliveries/{id}/accept**
   - Accepte une livraison en attente

7. **POST /api/livreurs/deliveries/{id}/complete**
   - Complète une livraison active

8. **GET /api/notifications/livreur**
   - Retourne les notifications du livreur
   - Format : `{ "notifications": [...] }`

## 📱 Navigation

La page est automatiquement chargée pour les utilisateurs avec le rôle `livreur` dans `avant_home.dart` :
- Les livreurs ont leur propre liste de pages (`_pagesLivreur`)
- La première page est `LivreurHomePage()`
- Les autres onglets restent disponibles (Voitures, Pièces, Profil)

## 🚀 Prochaines Étapes (À Implémenter)

1. **Scanner QR Code** : Intégration d'un scanner QR pour valider les livraisons
2. **Carte Interactive** : Affichage de la carte avec suivi GPS en temps réel
3. **Chat avec Clients** : Communication directe avec les clients
4. **Historique Détaillé** : Page dédiée avec filtres et recherche
5. **Paramètres Avancés** : Configuration des préférences de notification, GPS, etc.
6. **Statistiques** : Graphiques et métriques de performance
7. **Notifications Push** : Intégration Firebase Cloud Messaging pour notifications temps réel
8. **Mode Hors Ligne** : Cache local pour fonctionner sans connexion

## 🎨 Icônes Utilisées

Toutes les icônes respectent le style Material Design et utilisent les couleurs de l'application :
- Icônes principales : Jaune/Orange (`Color(0xFFF8BF13)`)
- Icônes secondaires : Couleurs spécifiques selon le contexte
- Taille standard : 28-32px pour les actions rapides, 32px pour les services

## 📝 Notes Techniques

- **État** : Géré avec `setState()` pour la réactivité
- **Permissions** : Utilise `permission_handler` pour la géolocalisation
- **Géolocalisation** : Utilise `geolocator` pour le tracking GPS
- **HTTP** : Utilise `http` package pour les appels API
- **Formatage** : Utilise `intl` pour le formatage des montants et dates

