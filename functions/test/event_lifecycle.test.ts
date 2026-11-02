import assert from 'node:assert/strict';
import test from 'node:test';

import {
  autoEndLookbackMs,
  createAutoEndOverdueEventsHandler,
  eventEndToleranceMs,
  type AutoEndGateway,
  type OverdueCandidate,
} from '../src/event_lifecycle.js';

const agora = new Date('2026-10-21T22:00:00.000Z');
const minutos = (n: number) => n * 60 * 1000;
const antesDeAgora = (ms: number) => new Date(agora.getTime() - ms);

interface EventoFalso {
  readonly id: string;
  readonly endsAt?: Date;
  endedAt?: Date;
  endedAutomatically?: boolean;
}

/**
 * Firestore de mentira: aplica a janela (from, to] como a consulta real e,
 * como ela, nunca devolve documento sem `endsAt`.
 */
class GatewayFalso implements AutoEndGateway {
  constructor(readonly eventos: EventoFalso[]) {}

  readonly janelas: Array<{ from: Date; to: Date }> = [];
  readonly tentativas: string[] = [];
  /** Ids que "alguém encerrou" entre a consulta e a transação. */
  readonly encerradosNoCaminho = new Set<string>();

  async listEndsAtBetween(from: Date, to: Date): Promise<OverdueCandidate[]> {
    this.janelas.push({ from, to });
    return this.eventos
      .filter((e) => e.endsAt !== undefined && e.endsAt > from && e.endsAt <= to)
      .sort((a, b) => a.endsAt!.getTime() - b.endsAt!.getTime())
      .map((e) => ({ id: e.id, endsAt: e.endsAt!, hasEndedAt: e.endedAt !== undefined }));
  }

  async endIfStillOpen(eventId: string, endedAt: Date): Promise<boolean> {
    this.tentativas.push(eventId);
    const evento = this.eventos.find((e) => e.id === eventId);
    if (evento === undefined || evento.endedAt !== undefined || this.encerradosNoCaminho.has(eventId)) {
      return false;
    }
    evento.endedAt = endedAt;
    evento.endedAutomatically = true;
    return true;
  }
}

const rodar = (gateway: AutoEndGateway) => createAutoEndOverdueEventsHandler(gateway, () => agora)();

test('só encerra os eventos que passaram 1h do fim previsto', async () => {
  const gateway = new GatewayFalso([
    { id: 'vencido', endsAt: antesDeAgora(minutos(61)) },
    { id: 'na_folga', endsAt: antesDeAgora(minutos(30)) },
    { id: 'futuro', endsAt: new Date(agora.getTime() + minutos(30)) },
  ]);

  assert.equal(await rodar(gateway), 1);
  assert.deepEqual(gateway.tentativas, ['vencido']);
  assert.equal(gateway.eventos.find((e) => e.id === 'na_folga')!.endedAt, undefined);
});

test('grava endedAt = endsAt + 1h e endedAutomatically = true', async () => {
  const endsAt = antesDeAgora(minutos(90));
  const gateway = new GatewayFalso([{ id: 'esquecido', endsAt }]);

  await rodar(gateway);

  const evento = gateway.eventos[0];
  assert.deepEqual(evento.endedAt, new Date(endsAt.getTime() + eventEndToleranceMs));
  assert.equal(evento.endedAutomatically, true);
});

test('evento que já tem endedAt é ignorado, sem abrir transação', async () => {
  const gateway = new GatewayFalso([
    { id: 'encerrado_a_mao', endsAt: antesDeAgora(minutos(120)), endedAt: antesDeAgora(minutos(150)) },
  ]);

  assert.equal(await rodar(gateway), 0);
  assert.deepEqual(gateway.tentativas, []);
});

test('corrida: se a transação acha o evento já encerrado, não conta', async () => {
  const gateway = new GatewayFalso([{ id: 'disputado', endsAt: antesDeAgora(minutos(70)) }]);
  gateway.encerradosNoCaminho.add('disputado');

  assert.equal(await rodar(gateway), 0);
  assert.deepEqual(gateway.tentativas, ['disputado']);
  assert.equal(gateway.eventos[0].endedAutomatically, undefined);
});

test('a janela inclui a borda exata de agora - 1h', async () => {
  const gateway = new GatewayFalso([{ id: 'na_borda', endsAt: antesDeAgora(eventEndToleranceMs) }]);

  assert.equal(await rodar(gateway), 1);
  assert.deepEqual(gateway.janelas, [
    {
      from: antesDeAgora(eventEndToleranceMs + autoEndLookbackMs),
      to: antesDeAgora(eventEndToleranceMs),
    },
  ]);
});

test('olha até 2 dias para trás e deixa de fora o que é mais antigo', async () => {
  const limite = eventEndToleranceMs + autoEndLookbackMs;
  const gateway = new GatewayFalso([
    { id: 'dentro', endsAt: antesDeAgora(limite - 1) },
    { id: 'fora', endsAt: antesDeAgora(limite) },
  ]);

  assert.equal(await rodar(gateway), 1);
  assert.deepEqual(gateway.tentativas, ['dentro']);
});

test('evento legado sem endsAt fica de fora', async () => {
  const gateway = new GatewayFalso([{ id: 'legado' }]);

  assert.equal(await rodar(gateway), 0);
  assert.deepEqual(gateway.tentativas, []);
});

test('encerra vários vencidos na mesma execução', async () => {
  const gateway = new GatewayFalso([
    { id: 'a', endsAt: antesDeAgora(minutos(65)) },
    { id: 'b', endsAt: antesDeAgora(minutos(300)) },
    { id: 'c', endsAt: antesDeAgora(minutos(200)), endedAt: antesDeAgora(minutos(210)) },
  ]);

  assert.equal(await rodar(gateway), 2);
  assert.deepEqual(gateway.tentativas, ['b', 'a']);
});
