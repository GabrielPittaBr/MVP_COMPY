import 'dart:typed_data';

import 'package:mvp_compy/core/utils/avatar_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  group('AvatarImage', () {
    test('foto grande vira JPEG quadrado de 512 px, sem o EXIF da câmera', () {
      // O EXIF pode trazer o GPS de onde a foto foi tirada. O tag usado aqui
      // é só um que o pacote sabe gravar: o que importa é sobrar nenhum.
      final img.Image original = img.Image(width: 2000, height: 1500);
      original.exif.imageIfd['Artist'] = 'camera do celular';
      final Uint8List camera = img.encodeJpg(original);
      expect(img.decodeJpg(camera)!.exif.isEmpty, isFalse);

      final Uint8List jpeg = AvatarImage.toJpeg(camera);

      expect(jpeg.sublist(0, 2), <int>[0xFF, 0xD8]);
      final img.Image saida = img.decodeJpg(jpeg)!;
      expect(saida.width, AvatarImage.size);
      expect(saida.height, AvatarImage.size);
      expect(saida.exif.isEmpty, isTrue);
    });

    test('aceita JPEG, PNG e GIF e recusa o que não é imagem', () {
      final img.Image pixel = img.Image(width: 4, height: 4);
      expect(AvatarImage.isSupported(img.encodeJpg(pixel)), isTrue);
      expect(AvatarImage.isSupported(img.encodePng(pixel)), isTrue);
      expect(AvatarImage.isSupported(img.encodeGif(pixel)), isTrue);

      final Uint8List pdf = Uint8List.fromList('%PDF-1.7 qualquer coisa'.codeUnits);
      expect(AvatarImage.isSupported(pdf), isFalse);
      // TGA não tem assinatura: bytes aleatórios não podem passar por ele.
      expect(AvatarImage.isSupported(Uint8List(64)), isFalse);
      expect(AvatarImage.isSupported(img.encodeTga(pixel)), isFalse);
    });

    test('toJpeg recusa bytes que não decodificam', () {
      expect(
        () => AvatarImage.toJpeg(Uint8List.fromList(<int>[1, 2, 3])),
        throwsFormatException,
      );
    });
  });
}
