import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_links.dart';
import '../constants/app_strings.dart';

/// Abre [url] no navegador do aparelho. Sem navegador (ou sem rede para o
/// sistema resolver o link), avisa num SnackBar em vez de falhar calado.
Future<void> openExternalLink(BuildContext context, String url) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  bool opened = false;
  try {
    opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened) {
    messenger.showSnackBar(const SnackBar(content: Text(AppStrings.legalLinkError)));
  }
}

/// E-mail para o encarregado de dados ([AppLinks.privacyEmail]).
Future<void> openPrivacyEmail(BuildContext context, {String? subject}) {
  final Uri uri = Uri(
    scheme: 'mailto',
    path: AppLinks.privacyEmail,
    query: subject == null ? null : 'subject=${Uri.encodeComponent(subject)}',
  );
  return openExternalLink(context, uri.toString());
}
