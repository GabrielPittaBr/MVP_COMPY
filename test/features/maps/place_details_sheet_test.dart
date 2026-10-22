import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mvp_compy/features/maps/presentation/widgets/place_details_sheet.dart';
import 'package:mvp_compy/shared/models/sport.dart';
import 'package:mvp_compy/shared/models/sport_place.dart';

void main() {
  testWidgets('carousel swaps the individual image credit when swiped', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaceDetailsSheet(
            place: _place(
              images: const <SportPlaceImage>[
                SportPlaceImage(
                  url: 'https://example.com/cover.jpg',
                  source: 'Foto: Prefeitura de Taquara',
                ),
                SportPlaceImage(
                  url: 'https://example.com/court.jpg',
                  source: 'Imagem via Google',
                ),
              ],
            ),
            onCreateEvent: () {},
            onShare: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('Foto: Prefeitura de Taquara'), findsOneWidget);
    expect(find.text('Imagem via Google'), findsNothing);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Imagem via Google'), findsOneWidget);
    expect(find.text('Foto: Prefeitura de Taquara'), findsNothing);
  });

  testWidgets('private phone is formatted and a missing source stays hidden', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaceDetailsSheet(
            place: _place(
              accessType: PlaceAccessType.private,
              contactPhone: '51999999999',
              images: const <SportPlaceImage>[
                SportPlaceImage(url: 'https://example.com/cover.jpg'),
              ],
            ),
            onCreateEvent: () {},
            onShare: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Privado'), findsOneWidget);
    expect(find.text('(51) 99999-9999'), findsOneWidget);
    expect(find.text('Foto: Prefeitura de Taquara'), findsNothing);
    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('legacy places stay unclassified and keep the imageUrl cover', (
    tester,
  ) async {
    final place = _place(accessType: null);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaceDetailsSheet(
            place: place,
            onCreateEvent: () {},
            onShare: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Tipo não informado'), findsOneWidget);
    expect(find.text('Público'), findsNothing);
    expect(find.byType(PageView), findsOneWidget);
    expect(place.gallery.single.url, place.imageUrl);
  });
}

SportPlace _place({
  PlaceAccessType? accessType = PlaceAccessType.public,
  String? contactPhone,
  List<SportPlaceImage> images = const <SportPlaceImage>[
    SportPlaceImage(url: 'https://example.com/cover.jpg'),
  ],
}) =>
    SportPlace(
      id: 'place-1',
      name: 'Quadra Central',
      nameLower: 'quadra central',
      description: 'Espaço esportivo da comunidade de Taquara.',
      address: const PlaceAddress(
        street: 'Rua Central',
        city: 'Taquara',
        cityLower: 'taquara',
        state: 'RS',
      ),
      coordinates: const LatLng(-29.65, -50.78),
      sports: const <Sport>[Sport.futebol],
      primarySport: Sport.futebol,
      status: PlaceStatus.active,
      imageUrl: images.first.url,
      images: images,
      accessType: accessType,
      contactPhone: contactPhone,
    );
