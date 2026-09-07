import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../../config/theme.dart';

class RatingBarWidget extends StatelessWidget {
  final double rating;
  final int? totalRatings;
  final bool interactive;
  final ValueChanged<double>? onRatingUpdate;
  final double itemSize;

  const RatingBarWidget({
    super.key,
    required this.rating,
    this.totalRatings,
    this.interactive = false,
    this.onRatingUpdate,
    this.itemSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RatingBarIndicator(
          rating: rating,
          itemBuilder: (context, index) => const Icon(
            Icons.star,
            color: AppColors.warning,
          ),
          itemCount: 5,
          itemSize: itemSize,
          direction: Axis.horizontal,
        ),
        if (totalRatings != null && totalRatings! > 0) ...[
          const SizedBox(width: 4),
          Text(
            '${rating.toStringAsFixed(1)} ($totalRatings)',
            style: TextStyle(
              fontSize: itemSize * 0.65,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class InteractiveRatingBar extends StatelessWidget {
  final ValueChanged<double> onRatingUpdate;
  final double initialRating;

  const InteractiveRatingBar({
    super.key,
    required this.onRatingUpdate,
    this.initialRating = 0,
  });

  @override
  Widget build(BuildContext context) {
    return RatingBar.builder(
      initialRating: initialRating,
      minRating: 1,
      direction: Axis.horizontal,
      allowHalfRating: false,
      itemCount: 5,
      itemSize: 36,
      itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
      itemBuilder: (context, _) => const Icon(
        Icons.star,
        color: AppColors.warning,
      ),
      onRatingUpdate: onRatingUpdate,
    );
  }
}
