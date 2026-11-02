import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Validação e preparo da foto de perfil antes do envio.
///
/// O limite de tamanho tem três camadas: [maxInputBytes] na entrada, a saída
/// sempre em JPEG [size]×[size] (~50-100 KB) e, no servidor, o
/// `storage.rules`, que recusa acima de 1 MB ou fora de `image/jpeg`.
abstract final class AvatarImage {
  /// Arquivo escolhido maior que isto é recusado antes de ser decodificado.
  static const int maxInputBytes = 10 * 1024 * 1024;

  /// Lado, em pixels, da foto gravada no Storage.
  static const int size = 512;

  static const Set<img.ImageFormat> _accepted = <img.ImageFormat>{
    img.ImageFormat.jpg,
    img.ImageFormat.png,
    img.ImageFormat.webp,
    img.ImageFormat.gif,
  };

  /// `true` quando os bytes são de um formato de imagem aceito.
  ///
  /// Só lê o cabeçalho. A lista é fechada nos formatos com assinatura
  /// própria: o detector do pacote `image` também reconhece TGA, que não tem
  /// assinatura nenhuma, e qualquer arquivo aleatório passaria por ele.
  static bool isSupported(Uint8List bytes) =>
      _accepted.contains(img.findFormatForData(bytes));

  /// Recorte já feito → JPEG quadrado de [size] px, sem EXIF.
  ///
  /// A rotação da câmera já sai aplicada pelo próprio decode do pacote
  /// `image`. O EXIF é zerado porque o redimensionamento o copia inteiro, e
  /// ele pode trazer a localização GPS de onde a foto foi tirada — numa
  /// imagem que qualquer usuário logado consegue baixar.
  ///
  /// Pesado para a thread de UI; chamar via `compute`.
  static Uint8List toJpeg(Uint8List bytes) {
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Arquivo não é uma imagem válida.');
    }
    final img.Image square = img.copyResizeCropSquare(
      decoded,
      size: size,
      interpolation: img.Interpolation.average,
    )..exif = img.ExifData();
    return img.encodeJpg(square, quality: 85);
  }
}
