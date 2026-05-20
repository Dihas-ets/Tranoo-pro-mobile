/// Tri des articles : le plus récent en premier.
DateTime? parseArticleJsonDate(Map<String, dynamic> json) {
  for (final key in ['dateCreation', 'createdAt', 'updatedAt']) {
    final raw = json[key];
    if (raw == null) continue;
    final d = DateTime.tryParse(raw.toString());
    if (d != null) return d;
  }
  return null;
}

List<dynamic> sortArticleMapsNewestFirst(List<dynamic> data) {
  final copy = data
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  copy.sort((a, b) {
    final da = parseArticleJsonDate(a);
    final db = parseArticleJsonDate(b);
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return db.compareTo(da);
  });
  return copy;
}
