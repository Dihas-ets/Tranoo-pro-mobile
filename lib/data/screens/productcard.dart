import 'package:flutter/material.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';
import 'package:tranoo_pro/widgets/cached_media_image.dart';

class ProductCard extends StatelessWidget {
  final String imagePath;
  final String productName;
  final double imageHeight;
  final double imageWidth;

  const ProductCard({
    super.key,
    required this.imagePath,
    required this.productName,
    required this.imageHeight,
    required this.imageWidth,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Container(
        width: 300,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedMediaImage(
                url: imagePath,
                height: imageHeight,
                width: imageWidth,
                fit: BoxFit.cover,
                cloudinaryWidthPx:
                    MediaQuery.sizeOf(context).width.toInt(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: List.generate(
                4,
                (index) => Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blueAccent),
                  ),
                  child: CachedMediaImage(
                    url: imagePath,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    cloudinaryWidthPx: 80,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  productName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Row(
                  children: [
                    Text("0 / 5", style: TextStyle(color: Colors.blue)),
                    Icon(Icons.star_border, color: Colors.blue),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              "10,000 ₣",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Composant essentiel du système de freinage, le mastervac amplifie la force exercée sur la pédale de frein pour faciliter le freinage.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.precision_manufacturing),
                        const SizedBox(height: 4),
                        Text(l10n.model),
                        const Text(
                          "124-CFDS",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.label_important),
                        const SizedBox(height: 4),
                        Text(l10n.typeLabel),
                        const Text(
                          "Rare",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Badge(text: "New"),
                SizedBox(width: 6),
                Badge(text: "2023"),
                SizedBox(width: 6),
                Badge(text: "Bénin"),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(l10n.sellYourPart),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Badge extends StatelessWidget {
  final String text;

  const Badge({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
