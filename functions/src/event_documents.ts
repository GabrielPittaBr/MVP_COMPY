/**
 * Leitura dos documentos `events/{eventId}` compartilhada pelas Functions do
 * ciclo de vida (tarefa 14).
 */

/** Strings de uma lista; descarta o que não for texto. */
export function toStringList(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item): item is string => typeof item === 'string') : [];
}

/**
 * Ids dos participantes, sem repetição. Documentos anteriores à tarefa 12
 * não têm `participantIds`; neles os ids saem dos mapas de `participants`.
 */
export function participantIdsOf(data: Record<string, unknown>): string[] {
  if (Array.isArray(data.participantIds)) return [...new Set(toStringList(data.participantIds))];
  const participants = Array.isArray(data.participants) ? data.participants : [];
  const ids = participants
    .map((p: unknown) => (p !== null && typeof p === 'object' ? (p as Record<string, unknown>).id : undefined))
    .filter((id): id is string => typeof id === 'string');
  return [...new Set(ids)];
}

/** Id do criador, gravado em `creator.id`. */
export function creatorIdOf(data: Record<string, unknown>): string {
  const creator = data.creator as Record<string, unknown> | undefined;
  return typeof creator?.id === 'string' ? creator.id : '';
}
