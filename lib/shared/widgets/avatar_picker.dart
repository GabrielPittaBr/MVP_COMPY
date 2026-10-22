import 'package:cached_network_image/cached_network_image.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/avatar_image.dart';

/// Foto de perfil com os botões de adicionar, trocar e remover.
///
/// Usada no cadastro, na tela pós-Google e em Editar perfil. Não grava
/// nada: entrega o JPEG pronto em [onPicked] e quem usa decide quando
/// enviar.
class AvatarPicker extends StatelessWidget {
  const AvatarPicker({
    required this.name,
    required this.onPicked,
    required this.onRemoved,
    this.photoUrl,
    this.photoBytes,
    this.busy = false,
    super.key,
  });

  /// Nome do usuário, para a inicial quando não há foto.
  final String name;

  /// Foto já gravada: do Storage, do Google ou o placeholder com a inicial.
  final String? photoUrl;

  /// Foto recém-escolhida e ainda não enviada. Ganha de [photoUrl].
  final Uint8List? photoBytes;

  final ValueChanged<Uint8List> onPicked;
  final VoidCallback onRemoved;

  /// Envio em andamento: mostra o progresso e trava os botões.
  final bool busy;

  bool get _hasPhoto =>
      photoBytes != null || !AppAssets.isPlaceholderAvatar(photoUrl);

  @override
  Widget build(BuildContext context) {
    final ImageProvider? image = photoBytes != null
        ? MemoryImage(photoBytes!)
        : _hasPhoto
            ? CachedNetworkImageProvider(photoUrl!)
            : null;
    final String trimmed = name.trim();
    final String label = _hasPhoto ? AppStrings.photoChange : AppStrings.photoAdd;

    return Column(
      children: <Widget>[
        Semantics(
          button: true,
          label: label,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: busy ? null : () => _pick(context),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                CircleAvatar(
                  radius: 56,
                  backgroundColor: AppColors.surfaceMuted,
                  backgroundImage: image,
                  child: image != null
                      ? null
                      : trimmed.isEmpty
                          ? const Icon(
                              Icons.add_a_photo_outlined,
                              size: 36,
                              color: AppColors.onSurfaceMuted,
                            )
                          : Text(
                              trimmed.characters.first.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                ),
                if (busy) const CircularProgressIndicator(),
                const Positioned(
                  right: 0,
                  bottom: 0,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.photo_camera, size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          children: <Widget>[
            TextButton(
              onPressed: busy ? null : () => _pick(context),
              child: Text(label),
            ),
            if (_hasPhoto)
              TextButton(
                onPressed: busy ? null : onRemoved,
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text(AppStrings.photoRemove),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final Uint8List? jpeg = await pickAvatarPhoto(context);
    if (jpeg != null) onPicked(jpeg);
  }
}

/// Fluxo inteiro da escolha: origem, validação, recorte e o JPEG final.
///
/// Devolve `null` quando o usuário desiste ou a imagem é recusada — nesse
/// caso o motivo já foi mostrado em SnackBar.
Future<Uint8List?> pickAvatarPhoto(BuildContext context) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  void warn(String message) =>
      messenger.showSnackBar(SnackBar(content: Text(message)));

  // Câmera só onde o `image_picker` sabe abrir uma: na web e no desktop ele
  // cairia no seletor de arquivos de qualquer jeito.
  final bool hasCamera = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  final ImageSource? source = hasCamera
      ? await showModalBottomSheet<ImageSource>(
          context: context,
          builder: (BuildContext sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text(AppStrings.photoGallery),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text(AppStrings.photoCamera),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(ImageSource.camera),
                ),
              ],
            ),
          ),
        )
      : ImageSource.gallery;
  if (source == null) return null;

  final XFile? file;
  try {
    // O redimensionamento acontece no nativo, antes de a imagem chegar ao
    // Dart: decodificar uma foto de 48 MP inteira estouraria a memória.
    file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 90,
    );
  } on PlatformException catch (e) {
    debugPrint('[AvatarPicker] image_picker falhou: $e');
    warn(AppStrings.photoPickError);
    return null;
  }
  if (file == null) return null;

  if (await file.length() > AvatarImage.maxInputBytes) {
    warn(AppStrings.photoTooLarge(AvatarImage.maxInputBytes ~/ (1024 * 1024)));
    return null;
  }
  final Uint8List bytes = await file.readAsBytes();
  if (!AvatarImage.isSupported(bytes)) {
    warn(AppStrings.photoNotImage);
    return null;
  }
  if (!context.mounted) return null;

  final Uint8List? cropped = await showDialog<Uint8List>(
    context: context,
    builder: (_) => _AvatarCropDialog(image: bytes),
  );
  if (cropped == null) return null;

  try {
    return await compute(AvatarImage.toJpeg, cropped);
  } on FormatException {
    warn(AppStrings.photoNotImage);
    return null;
  }
}

/// Recorte circular com pan e zoom (pinça no celular, roda do mouse na web).
class _AvatarCropDialog extends StatefulWidget {
  const _AvatarCropDialog({required this.image});

  final Uint8List image;

  @override
  State<_AvatarCropDialog> createState() => _AvatarCropDialogState();
}

class _AvatarCropDialogState extends State<_AvatarCropDialog> {
  final CropController _controller = CropController();
  CropStatus _status = CropStatus.nothing;

  void _onCropped(CropResult result) {
    switch (result) {
      case CropSuccess(:final Uint8List croppedImage):
        Navigator.of(context).pop(croppedImage);
      case CropFailure(:final Object cause):
        debugPrint('[AvatarPicker] recorte falhou: $cause');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.photoNotImage)),
        );
        Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool ready = _status == CropStatus.ready;

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text(AppStrings.photoCropTitle),
          leading: CloseButton(onPressed: () => Navigator.of(context).pop()),
          actions: <Widget>[
            TextButton(
              onPressed: ready ? _controller.crop : null,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text(AppStrings.photoUse),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: Crop(
                  image: widget.image,
                  controller: _controller,
                  onCropped: _onCropped,
                  // A biblioteca ainda avisa "pronto" depois de entregar o
                  // recorte, quando o diálogo já fechou.
                  onStatusChanged: (CropStatus status) {
                    if (mounted) setState(() => _status = status);
                  },
                  aspectRatio: 1,
                  withCircleUi: true,
                  interactive: true,
                  fixCropRect: true,
                  initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
                    size: 0.85,
                    aspectRatio: 1,
                  ),
                  baseColor: Colors.black,
                  maskColor: Colors.black.withValues(alpha: 0.6),
                  progressIndicator: const CircularProgressIndicator(),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: Text(
                  AppStrings.photoCropHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
