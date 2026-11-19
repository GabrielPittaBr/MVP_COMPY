import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../venue/data/demo_venue.dart';
import '../../venue/domain/venue.dart';

final teamProvider = NotifierProvider<TeamController, List<Member>>(
  TeamController.new,
);

class TeamController extends Notifier<List<Member>> {
  @override
  List<Member> build() => DemoVenue.team;

  /// Convite de uso único, válido por 7 dias (RF-P02).
  void invite(Role role) => state = [
    ...state,
    Member(
      name: 'Convite de ${role.label}',
      role: role,
      detail: 'Gerado agora · vale até qui., 26/11',
      pending: true,
    ),
  ];

  void remove(Member member) => state = [
    for (final m in state)
      if (m != member) m,
  ];

  void changeRole(Member member, Role role) =>
      state = [for (final m in state) m == member ? m.copyWith(role: role) : m];
}
