import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/star_rating.dart';
import '../../domain/entities/rating_draft.dart';
import '../../domain/rating_validation.dart';

/// Nota de um alvo: estrelas com rótulo, comentário travado até a nota e o
/// motivo obrigatório abaixo de 3 (tarefa 14).
///
/// O widget guarda só o controller do texto; a nota em si vem de [draft] e
/// volta por [onChanged], para o passo saber se pode seguir.
class RatingInput extends StatefulWidget {
  const RatingInput({
    required this.draft,
    required this.onChanged,
    super.key,
  });

  final RatingDraft draft;
  final ValueChanged<RatingDraft> onChanged;

  @override
  State<RatingInput> createState() => _RatingInputState();
}

class _RatingInputState extends State<RatingInput> {
  late final TextEditingController _comment =
      TextEditingController(text: widget.draft.comment);

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final stars = draft.stars;
    final locked = stars == null;
    final low = stars != null && stars < kRatingReasonRequiredBelow;
    final reasonMissing = RatingValidation.check(draft, required: false) ==
        RatingIssue.reasonRequired;
    final hint = locked
        ? AppStrings.ratingCommentLocked
        : low
            ? AppStrings.ratingCommentReasonHint
            : AppStrings.ratingCommentHint;

    OutlineInputBorder border(Color? color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: color == null
              ? BorderSide.none
              : BorderSide(color: color, width: 1.5),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: StarRating(
            value: stars,
            size: 40,
            onChanged: (value) => widget.onChanged(draft.withStars(value)),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 22,
          child: Text(
            stars == null ? '' : AppStrings.ratingStarLabels[stars - 1],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _comment,
          enabled: !locked,
          minLines: 5,
          maxLines: 5,
          maxLength: kRatingCommentMaxLength,
          buildCounter: (_,
                  {required currentLength, required isFocused, maxLength}) =>
              null,
          onChanged: (text) => widget.onChanged(draft.withComment(text)),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: locked ? AppColors.surfaceCard : AppColors.surfaceMuted,
            contentPadding: const EdgeInsets.all(16),
            border: border(null),
            enabledBorder: border(reasonMissing ? AppColors.error : null),
            focusedBorder:
                border(reasonMissing ? AppColors.error : AppColors.primary),
            disabledBorder: border(null),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: reasonMissing
                  ? Semantics(
                      liveRegion: true,
                      child: const Row(
                        children: <Widget>[
                          Icon(
                            Icons.error_outline,
                            size: 16,
                            color: AppColors.error,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              AppStrings.ratingReasonRequired,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Text(
              '${_comment.text.length}/$kRatingCommentMaxLength',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.onSurfaceMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Row(
          children: <Widget>[
            Icon(Icons.lock_outline, size: 16, color: AppColors.onSurfaceMuted),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                AppStrings.ratingCommentPrivate,
                style: TextStyle(fontSize: 13, color: AppColors.onSurfaceMuted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
