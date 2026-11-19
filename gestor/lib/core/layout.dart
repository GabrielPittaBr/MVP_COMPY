import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A partir de 840 px, menu lateral e formulários num painel ao lado.
bool isDesktop(BuildContext context) => MediaQuery.sizeOf(context).width >= 840;

/// Formulário aberto no painel lateral do computador.
final panelProvider = NotifierProvider<PanelController, Widget?>(
  PanelController.new,
);

class PanelController extends Notifier<Widget?> {
  @override
  Widget? build() => null;

  void show(Widget form) => state = KeyedSubtree(key: UniqueKey(), child: form);

  void close() => state = null;
}

/// Diz ao formulário se ele está no painel lateral ou numa tela cheia.
class PanelScope extends InheritedWidget {
  const PanelScope({required super.child, super.key});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PanelScope>() != null;

  @override
  bool updateShouldNotify(PanelScope oldWidget) => false;
}

/// Abre um formulário: ao lado da agenda no computador, em tela cheia no
/// celular.
void openForm(BuildContext context, WidgetRef ref, Widget form) {
  if (isDesktop(context)) {
    ref.read(panelProvider.notifier).show(form);
    return;
  }
  Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => form));
}

/// Troca o formulário aberto por outro, sem empilhar telas.
void replaceForm(BuildContext context, WidgetRef ref, Widget form) {
  if (PanelScope.of(context)) {
    ref.read(panelProvider.notifier).show(form);
    return;
  }
  Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => form),
  );
}

/// Fecha o formulário aberto por [openForm].
void closeForm(BuildContext context, WidgetRef ref) {
  if (PanelScope.of(context)) {
    ref.read(panelProvider.notifier).close();
  } else {
    Navigator.of(context).pop();
  }
}

/// Aviso curto no rodapé, usado depois de cada ação.
void showDone(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), width: isDesktop(context) ? 440 : null),
    );
}
