import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/theme/venue_theme.dart';
import '../data/demo_venue.dart';
import '../domain/venue.dart';

class VenueState {
  const VenueState({
    this.name = DemoVenue.name,
    this.theme = VenueTheme.areia,
    this.courts = DemoVenue.courts,
    this.prices = DemoVenue.prices,
    this.hours = DemoVenue.hours,
    this.discountLimit = 20,
    this.responseMinutes = 30,
    this.autoConfirm = false,
  });

  final String name;
  final VenueTheme theme;
  final List<Court> courts;
  final List<PriceBand> prices;
  final List<OpeningHours> hours;

  /// Desconto máximo que a equipe pode dar, em % (RF-P41).
  final int discountLimit;
  final int responseMinutes;
  final bool autoConfirm;

  List<Court> get activeCourts =>
      courts.where((c) => c.status == CourtStatus.ativa).toList();

  Court court(int number) => courts.firstWhere((c) => c.number == number);

  OpeningHours hoursOf(int day) {
    final weekday = Demo.date(day).weekday;
    return hours.firstWhere((h) => h.days.contains(weekday));
  }

  /// Preço por hora da tabela, pelo dia da semana e pela faixa de horário.
  double pricePerHour(int day, int hour) {
    final weekday = Demo.date(day).weekday;
    for (final band in prices) {
      if (band.covers(weekday, hour)) return band.price;
    }
    return prices.last.price;
  }

  double price(int day, int start, int end) {
    var total = 0.0;
    for (var m = start; m < end; m += 30) {
      total += pricePerHour(day, m ~/ 60) / 2;
    }
    return total;
  }

  VenueState copyWith({
    String? name,
    VenueTheme? theme,
    List<Court>? courts,
    List<PriceBand>? prices,
    List<OpeningHours>? hours,
    int? discountLimit,
    int? responseMinutes,
    bool? autoConfirm,
  }) => VenueState(
    name: name ?? this.name,
    theme: theme ?? this.theme,
    courts: courts ?? this.courts,
    prices: prices ?? this.prices,
    hours: hours ?? this.hours,
    discountLimit: discountLimit ?? this.discountLimit,
    responseMinutes: responseMinutes ?? this.responseMinutes,
    autoConfirm: autoConfirm ?? this.autoConfirm,
  );
}

final venueProvider = NotifierProvider<VenueController, VenueState>(
  VenueController.new,
);

class VenueController extends Notifier<VenueState> {
  @override
  VenueState build() => const VenueState();

  void update(VenueState Function(VenueState) change) => state = change(state);

  void saveCourt(Court court) {
    final exists = state.courts.any((c) => c.number == court.number);
    state = state.copyWith(
      courts: exists
          ? [for (final c in state.courts) c.number == court.number ? court : c]
          : [...state.courts, court],
    );
  }

  int get nextCourtNumber =>
      state.courts.fold(0, (n, c) => c.number > n ? c.number : n) + 1;
}
