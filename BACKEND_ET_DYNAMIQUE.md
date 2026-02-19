# Backend & dynamique – Tranoo Pro (livraison & portefeuille)

## Tout est dynamique et relié au back

Les écrans livraison et portefeuille utilisent **uniquement** des données venant du backend (aucune valeur en dur pour les données métier).

---

## 1. Portefeuille (Mon portefeuille)

| Donnée affichée | Source API | Endpoint |
|-----------------|------------|----------|
| Photo, nom, prénoms, rôle, véhicule | Profil utilisateur | `GET /api/protected/me` |
| Solde, devise | Wallet | `GET /api/wallet/me` |
| Transactions | Wallet | `GET /api/wallet/me/transactions` |
| Stats livreur (commandes, km, hebdo) | Stats | `GET /api/wallet/me/stats` |

Tout est chargé au montage et au rafraîchissement ; pas de texte statique pour le profil ou les stats.

---

## 2. Livraisons (côté livreur)

| Action / écran | API utilisée |
|----------------|--------------|
| Liste des livraisons en attente | `GET /api/livreurs/deliveries/pending` |
| Liste des livraisons actives | `GET /api/livreurs/deliveries/active` |
| Accepter une livraison (bannière) | `POST /api/deliveries/:id/accept` |
| Accepter (mes livraisons) | `POST /api/livreurs/deliveries/:id/accept` |
| Mise à jour position GPS | `POST /api/livreurs/location` |
| Toggle en ligne / hors ligne | `POST /api/livreurs/toggle-status` |
| Historique | `GET /api/livreurs/deliveries/history` |

Les écrans (carte, overlay, validation, en route, arrivé acheteur, terminé) reçoivent l’objet **delivery** renvoyé par ces APIs (lieuDepart, lieuDestination, fournisseur, acheteur, pieces, etc.) et affichent uniquement ces champs.

---

## 3. Workflow livraison (étapes 1 → 6)

| Étape | Événement | API |
|-------|-----------|-----|
| 1 → 2 | Swipe « Sur place » (fournisseur) | Aucune (navigation vers validation) |
| 2 → 3 | Clic « Valider » | Aucune |
| 3 → 4 | Clic « Colis pris en charge » | `POST /api/deliveries/:id/pickup` |
| 4 → 5 | Clic « Je suis arrivé » | Aucune |
| 5 | Swipe « Sur place » (acheteur) | Aucune (affichage du bouton « Colis livré ») |
| 5 → 6 | Swipe « Colis livré » | `POST /api/deliveries/:id/deliver` |

Données des overlays (adresses, noms, téléphones, colis, paiement, exigences) : tout vient de l’objet **delivery** fourni par le back.

---

## 4. Résumé

- **Portefeuille** : profil, solde, transactions et stats 100 % issus du backend.
- **Livraisons** : listes, acceptation, pickup, deliver et contenu des écrans 100 % issus du backend.
- Aucune donnée métier en dur ; seuls les libellés d’UI (titres, boutons) sont fixes.
