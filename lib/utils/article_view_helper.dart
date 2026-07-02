import 'package:flutter/material.dart';
import 'package:tranoo_pro/services/views_service.dart';

final Set<String> _sessionViewedArticleIds = {};

/// Enregistre une vue réelle (clic). Une seule fois par article et par session app.
void trackArticleView(String? articleId) {
  final id = articleId?.trim() ?? '';
  if (id.isEmpty) return;
  if (_sessionViewedArticleIds.contains(id)) return;
  _sessionViewedArticleIds.add(id);
  ViewsService().recordView(id);
}

String articleIdFromMap(Map<String, dynamic> json) {
  final raw = json['_id'] ?? json['id'] ?? json['articleId'] ?? json['article'];
  return raw?.toString() ?? '';
}

/// Identifiant Mongo du vendeur (string ou objet peuplé).
String? sellerIdFromArticleMap(Map<String, dynamic> json) {
  final vendeur = json['vendeur'];
  if (vendeur is Map) {
    final id = vendeur['_id'] ?? vendeur['id'];
    if (id != null && id.toString().trim().isNotEmpty) {
      return id.toString();
    }
  }
  if (vendeur != null && vendeur.toString().trim().isNotEmpty) {
    return vendeur.toString();
  }
  return null;
}

bool articleOwnedBySeller(Map<String, dynamic> json, String? sellerMongoId) {
  final mine = sellerMongoId?.trim() ?? '';
  if (mine.isEmpty) return true;
  final owner = sellerIdFromArticleMap(json);
  if (owner == null || owner.isEmpty) return false;
  return owner == mine;
}

int articleViewsFromMap(Map<String, dynamic> json) {
  final views = json['views'];
  if (views is num) return views.toInt();
  final real = json['viewsReal'];
  final auto = json['viewsAuto'];
  if (real is num || auto is num) {
    return (real is num ? real.toInt() : 0) + (auto is num ? auto.toInt() : 0);
  }
  return int.tryParse('$views') ?? 0;
}

Widget buildArticleViewBadge(int views) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.6),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.remove_red_eye, size: 14, color: Colors.white),
        const SizedBox(width: 4),
        Text(
          views.toString(),
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    ),
  );
}
