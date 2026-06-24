import 'package:flutter/material.dart';
import 'package:tranoo_pro/services/transitaire_review_service.dart';
import 'package:tranoo_pro/widgets/transitaire_profile_ui.dart';

class TransitaireInteractiveStarRating extends StatelessWidget {
  final int value;
  final ValueChanged<int>? onChanged;
  final double size;

  const TransitaireInteractiveStarRating({
    super.key,
    required this.value,
    this.onChanged,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final star = index + 1;
        final filled = star <= value;
        return IconButton(
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(minWidth: size + 4, minHeight: size + 4),
          onPressed: onChanged == null ? null : () => onChanged!(star),
          icon: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            color: kTransitaireAmber,
            size: size,
          ),
        );
      }),
    );
  }
}

class TransitaireReviewsSection extends StatefulWidget {
  final String transitaireId;
  final bool isOwner;

  const TransitaireReviewsSection({
    super.key,
    required this.transitaireId,
    required this.isOwner,
  });

  @override
  State<TransitaireReviewsSection> createState() =>
      _TransitaireReviewsSectionState();
}

class _TransitaireReviewsSectionState extends State<TransitaireReviewsSection> {
  bool _loading = true;
  TransitaireReviewsPayload? _payload;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final payload = widget.isOwner
          ? await TransitaireReviewService.instance.fetchReceived()
          : await TransitaireReviewService.instance.fetchForTransitaire(
              widget.transitaireId,
            );
      if (!mounted) return;
      setState(() {
        _payload = payload;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildStarsRow(int rating, {double size = 16}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: kTransitaireAmber,
        );
      }),
    );
  }

  Widget _buildReviewTile(TransitaireReviewData review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: kTransitaireAmber.withOpacity(0.25),
                backgroundImage: review.reviewerPhoto != null &&
                        review.reviewerPhoto!.isNotEmpty
                    ? NetworkImage(review.reviewerPhoto!)
                    : null,
                child: review.reviewerPhoto == null ||
                        review.reviewerPhoto!.isEmpty
                    ? Text(
                        review.reviewerName.isNotEmpty
                            ? review.reviewerName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: kTransitaireNavy,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  review.reviewerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: kTransitaireNavy,
                  ),
                ),
              ),
              _buildStarsRow(review.rating),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final payload = _payload;
    final avg = payload?.ratingAverage ?? 0;
    final reviews = payload?.reviews ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Mes avis',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: kTransitaireNavy,
              ),
            ),
            const Spacer(),
            if (avg > 0) TransitaireStarRating(rating: avg, compact: true),
          ],
        ),
        const SizedBox(height: 12),
        if (reviews.isEmpty)
          Text(
            'Vous n\'avez pas encore reçu d\'avis.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          )
        else
          ...reviews.map(_buildReviewTile),
      ],
    );
  }
}
