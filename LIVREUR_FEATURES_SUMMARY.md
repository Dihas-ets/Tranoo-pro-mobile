# 📦 Résumé des Fonctionnalités - Page Livreur

## 🎯 Vue d'Ensemble

La page d'accueil des livreurs (`livreur_home.dart`) est une interface complète permettant aux livreurs de gérer leurs livraisons, suivre leur position GPS, recevoir des notifications et effectuer toutes les actions nécessaires à leur travail.

---

## ✨ Fonctionnalités Principales

### 1. **Header Personnalisé** 👤
- **Nom de l'utilisateur** : Affiche le nom du livreur connecté au lieu de "Tranoo Livreur"
- **Photo de profil** : Image de profil de l'utilisateur à droite (ou icône par défaut si aucune photo)
- **Badge de notifications** : Compteur de notifications non lues sur la photo de profil
- **Solde principal** : Affichage du solde du portefeuille avec devise (XOF)

### 2. **Statut En Ligne/Hors Ligne** 🟢
- **Bouton flottant** (en bas à droite) : Permet de basculer entre statut "En ligne" et "Hors ligne"
  - **Vert** = En ligne (le livreur peut recevoir des livraisons)
  - **Gris** = Hors ligne (le livreur ne reçoit pas de nouvelles livraisons)
- **Badge de statut** : Affichage visuel dans le header (badge vert/gris)

### 3. **Géolocalisation en Temps Réel** 📍
- **Permission automatique** : Demande la permission de localisation au démarrage
- **Tracking continu** : Suivi GPS en temps réel avec mise à jour automatique tous les 10 mètres
- **Mise à jour serveur** : Envoi automatique de la position au backend
- **Données envoyées** : Latitude, Longitude, Timestamp

### 4. **Notifications Dynamiques** 🔔
- **Badge sur photo de profil** : Compteur de notifications non lues
- **Rechargement automatique** : Mise à jour toutes les 5 secondes
- **Notifications en temps réel** : Pour nouvelles livraisons, messages, etc.

### 5. **Actions Rapides** ⚡
Quatre actions rapides accessibles depuis le header :
- **Scanner QR** : Scanner un code QR pour valider une livraison
- **Mes Livraisons** : Accéder à la liste complète des livraisons
- **Suivi GPS** : Voir la carte avec le suivi en temps réel
- **Historique** : Consulter l'historique des livraisons

### 6. **Cartes de Statistiques** 📊
- **Livraisons en attente** : Compteur avec icône orange
- **Livraisons actives** : Compteur avec icône jaune/orange (couleur de l'app)
- **Mise à jour dynamique** : Rechargement automatique des données

### 7. **Grille de Services** 🎯
Neuf services accessibles via des icônes colorées :

| Service | Icône | Couleur | Fonction |
|---------|-------|---------|----------|
| **Notifications** | 🔔 | Rouge | Gérer les notifications |
| **Valider** | ✅ | Vert | Valider des actions/livraisons |
| **Géolocalisation** | 📍 | Bleu | Voir la position actuelle |
| **Suivi** | 🎯 | Jaune/Orange | Suivre les livraisons en cours |
| **Livraisons** | 📦 | Orange | Gérer toutes les livraisons |
| **Historique** | 📜 | Violet | Consulter l'historique |
| **Scanner** | 📷 | Turquoise | Scanner des codes QR |
| **Portefeuille** | 💰 | Indigo | Accéder au portefeuille |
| **Paramètres** | ⚙️ | Gris | Configurer l'application |

### 8. **Gestion des Livraisons** 📦

#### **Livraisons en Attente**
- Liste des livraisons disponibles à accepter
- Informations affichées :
  - ID de la livraison
  - Destination
  - Montant
  - Statut "En attente"
- **Action** : Bouton "Accepter" pour prendre en charge une livraison

#### **Livraisons Actives**
- Liste des livraisons en cours
- Informations affichées :
  - ID de la livraison
  - Destination
  - Montant
  - Statut "Active"
- **Action** : Bouton "Compléter" pour finaliser une livraison

### 9. **Portefeuille Intégré** 💰
- **Solde principal** : Affichage dans le header avec devise (XOF par défaut)
- **Chargement dynamique** : Récupération depuis l'API
- **Format** : Affichage formaté avec séparateurs de milliers

### 10. **Pull to Refresh** 🔄
- **Rafraîchissement** : Glisser vers le bas pour recharger toutes les données
- **Indicateur** : Spinner de chargement pendant le rafraîchissement

---

## 🎨 Design et UI

### **Couleurs de l'Application**
- **Jaune/Orange principal** : `Color(0xFFF8BF13)` - Utilisé pour les éléments principaux
- **Header** : Dégradé bleu foncé (`Color(0xFF0A1F44)` vers `Color(0xFF1a3a6a)`)
- **Fond** : Gris clair (`Color(0xFFF5F5F5)`)
- **Cartes** : Blanc avec ombres légères

### **Responsive Design**
- Adaptation automatique selon l'orientation (portrait/paysage)
- Tailles d'icônes et espacements adaptatifs
- Grille de services responsive (3 colonnes)

---

## 🔧 APIs Backend Requises

### **Endpoints à Implémenter :**

1. **GET /api/wallet/me** - Retourne le solde et la devise
2. **GET /api/livreurs/deliveries/pending** - Liste des livraisons en attente
3. **GET /api/livreurs/deliveries/active** - Liste des livraisons actives
4. **POST /api/livreurs/toggle-status** - Change le statut en ligne/hors ligne
5. **POST /api/livreurs/location** - Met à jour la position GPS
6. **POST /api/livreurs/deliveries/{id}/accept** - Accepte une livraison
7. **POST /api/livreurs/deliveries/{id}/complete** - Complète une livraison
8. **GET /api/notifications/livreur** - Retourne les notifications

---

## 📱 Navigation

- La page est automatiquement chargée pour les utilisateurs avec le rôle `livreur`
- Les livreurs ont leur propre liste de pages dans `avant_home.dart`
- La première page est `LivreurHomePage()`

---

## 🚀 Prochaines Étapes (À Implémenter)

1. **Scanner QR Code** : Intégration d'un scanner QR pour valider les livraisons
2. **Carte Interactive** : Affichage de la carte avec suivi GPS en temps réel
3. **Chat avec Clients** : Communication directe avec les clients
4. **Historique Détaillé** : Page dédiée avec filtres et recherche
5. **Paramètres Avancés** : Configuration des préférences
6. **Statistiques** : Graphiques et métriques de performance
7. **Notifications Push** : Intégration Firebase Cloud Messaging
8. **Mode Hors Ligne** : Cache local pour fonctionner sans connexion

---

## 💡 Explication du Bouton Flottant

Le **bouton flottant en bas à droite** permet de basculer le statut en ligne/hors ligne :

- **🟢 Vert avec icône check** = Le livreur est **EN LIGNE** et peut recevoir de nouvelles livraisons
- **⚫ Gris avec icône power** = Le livreur est **HORS LIGNE** et ne reçoit pas de nouvelles livraisons

**Pourquoi c'est important ?**
- Permet au livreur de contrôler quand il est disponible pour travailler
- Les clients ne peuvent assigner des livraisons qu'aux livreurs en ligne
- Le système peut optimiser la distribution des livraisons selon la disponibilité

---

## 📝 Note sur l'Écran de Démarrage

Lors d'un **hot restart**, l'écran "Tranoo Pro" avec l'animation de voiture s'affiche car c'est l'écran de démarrage (`AppInitializer`) qui se charge avant la navigation vers la page principale. C'est normal et permet de :
- Vérifier le statut de l'utilisateur
- Charger les données initiales
- Gérer la navigation selon l'état de connexion

