import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_links.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/age_rules.dart';
import '../../../../core/utils/external_links.dart';
import 'auth_text_field.dart';

/// Campo da data de nascimento do cadastro e do aceite (chore/lgpd).
class BirthDateField extends StatelessWidget {
  const BirthDateField({
    required this.controller,
    this.textInputAction = TextInputAction.next,
    this.enforceMinimumAge = true,
    super.key,
  });

  final TextEditingController controller;
  final TextInputAction textInputAction;

  /// `false` quando a conta já existe e a idade é tratada no envio (ver
  /// [AgeRules.validate]).
  final bool enforceMinimumAge;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AuthTextField(
          hint: AppStrings.ageBirthDateHint,
          controller: controller,
          keyboardType: TextInputType.number,
          textInputAction: textInputAction,
          inputFormatters: AgeRules.inputFormatters,
          validator: (String? value) => AgeRules.validate(
            value,
            DateTime.now(),
            enforceMinimum: enforceMinimumAge,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          AppStrings.ageBirthDateHelp,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.onSurfaceMuted,
              ),
        ),
      ],
    );
  }
}

/// Caixa "Li e aceito os Termos de Uso e a Política de Privacidade", com os
/// dois textos abrindo no navegador. Nasce desmarcada: o aceite tem de ser
/// um gesto da pessoa (LGPD art. 8º).
class LegalAcceptanceField extends FormField<bool> {
  LegalAcceptanceField({super.key})
      : super(
          initialValue: false,
          validator: (bool? value) =>
              value == true ? null : AppStrings.legalAcceptRequired,
          builder: (FormFieldState<bool> field) =>
              _LegalAcceptanceView(field: field),
        );
}

class _LegalAcceptanceView extends StatefulWidget {
  const _LegalAcceptanceView({required this.field});

  final FormFieldState<bool> field;

  @override
  State<_LegalAcceptanceView> createState() => _LegalAcceptanceViewState();
}

class _LegalAcceptanceViewState extends State<_LegalAcceptanceView> {
  late final TapGestureRecognizer _terms = TapGestureRecognizer()
    ..onTap = () => openExternalLink(context, AppLinks.terms);
  late final TapGestureRecognizer _privacy = TapGestureRecognizer()
    ..onTap = () => openExternalLink(context, AppLinks.privacyPolicy);

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FormFieldState<bool> field = widget.field;
    final TextStyle? base = Theme.of(context).textTheme.bodyMedium;
    const TextStyle link = TextStyle(
      color: AppColors.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Checkbox(
              value: field.value ?? false,
              onChanged: (bool? value) => field.didChange(value ?? false),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text.rich(
                  TextSpan(
                    style: base,
                    children: <InlineSpan>[
                      const TextSpan(text: '${AppStrings.legalAcceptPrefix} '),
                      TextSpan(
                        text: AppStrings.legalTerms,
                        style: link,
                        recognizer: _terms,
                      ),
                      const TextSpan(text: ' ${AppStrings.legalAcceptJoiner} '),
                      TextSpan(
                        text: AppStrings.legalPrivacyPolicy,
                        style: link,
                        recognizer: _privacy,
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (field.hasError)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Text(
              field.errorText!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.error,
                  ),
            ),
          ),
      ],
    );
  }
}
