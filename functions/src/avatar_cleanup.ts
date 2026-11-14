import { getStorage } from 'firebase-admin/storage';
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';

import { administrativeFunctionsRegion } from './config.js';

/**
 * Fotos de perfil substituídas (chore/lgpd; LGPD art. 6º, III).
 *
 * Cada troca de foto cria um arquivo novo em `users/{uid}/avatar_<millis>.jpg`
 * (ver `storage.rules`), e o antigo ficava no bucket para sempre. Quando
 * `avatarUrl` muda, este gatilho apaga as fotos anteriores à atual. Os eventos
 * e as conversas que ainda apontam para a foto antiga mostram a inicial do
 * nome, como já acontece depois de excluir a conta.
 */

/** Caminho no bucket a partir da URL de download (`.../o/users%2F...?alt=media`). */
export function storagePathFromUrl(url: unknown): string | null {
  if (typeof url !== 'string') return null;
  const match = /\/o\/([^?#]+)/u.exec(url);
  if (match === null) return null;
  try {
    return decodeURIComponent(match[1]);
  } catch {
    return null;
  }
}

/** Os `<millis>` de `avatar_<millis>.jpg`, ou `null` em outro nome. */
export function avatarMillis(path: string): number | null {
  const match = /\/avatar_(\d+)\.jpg$/u.exec(path);
  return match === null ? null : Number(match[1]);
}

/**
 * Fotos a apagar depois que [beforeUrl] virou [afterUrl]. Só saem as mais
 * antigas que a foto atual (ou que a própria troca, quando a foto nova não é
 * do bucket): duas trocas seguidas não apagam a foto que acabou de subir.
 */
export function staleAvatarPaths(
  uid: string,
  beforeUrl: unknown,
  afterUrl: unknown,
  existingPaths: readonly string[],
  changedAtMs: number,
): string[] {
  if (beforeUrl === afterUrl) return [];
  const prefix = `users/${uid}/`;
  const keep = storagePathFromUrl(afterUrl);
  const keepMillis = keep?.startsWith(prefix) ? avatarMillis(keep) : null;
  const cutoff = keepMillis ?? changedAtMs;
  return existingPaths.filter((path) => {
    if (!path.startsWith(prefix) || path === keep) return false;
    const millis = avatarMillis(path);
    return millis !== null && millis < cutoff;
  });
}

export interface AvatarStorageGateway {
  list(uid: string): Promise<string[]>;
  remove(paths: readonly string[]): Promise<void>;
}

export function createAvatarCleanupHandler(gateway: AvatarStorageGateway) {
  return async (
    uid: string,
    before: Record<string, unknown> | undefined,
    after: Record<string, unknown> | undefined,
    changedAtMs: number,
  ): Promise<number> => {
    if (before === undefined || after === undefined || before.avatarUrl === after.avatarUrl) return 0;
    const stale = staleAvatarPaths(uid, before.avatarUrl, after.avatarUrl, await gateway.list(uid), changedAtMs);
    if (stale.length > 0) await gateway.remove(stale);
    return stale.length;
  };
}

export function createStorageAvatarGateway(): AvatarStorageGateway {
  const bucket = getStorage().bucket();
  return {
    list: async (uid) => (await bucket.getFiles({ prefix: `users/${uid}/` }))[0].map((file) => file.name),
    remove: async (paths) => {
      await Promise.all(paths.map((path) => bucket.file(path).delete({ ignoreNotFound: true })));
    },
  };
}

export const onProfileAvatarChanged = onDocumentUpdated(
  { document: 'users/{uid}', region: administrativeFunctionsRegion },
  async (event) => {
    const change = event.data;
    if (change === undefined) return;
    await createAvatarCleanupHandler(createStorageAvatarGateway())(
      event.params.uid,
      change.before.data(),
      change.after.data(),
      Date.parse(event.time),
    );
  },
);
