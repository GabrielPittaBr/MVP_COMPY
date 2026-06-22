/// Nível de habilidade do praticante / exigido por um evento.
///
/// O matchmaking (RN-02) prioriza conexões entre níveis semelhantes.
enum SkillLevel {
  todos('Todos'),
  iniciante('Iniciante'),
  intermediario('Intermediário'),
  avancado('Avançado');

  const SkillLevel(this.label);
  final String label;
}
