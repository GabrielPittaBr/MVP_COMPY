import { getFirestore } from 'firebase-admin/firestore';
import { onDocumentDeleted } from 'firebase-functions/v2/firestore';
import { administrativeFunctionsRegion } from './config.js';

export interface FriendshipsCleanupGateway {
  profileExists(uid: string): Promise<boolean>;
  list(uid: string, limit: number): Promise<string[]>;
  remove(ids: readonly string[]): Promise<void>;
}

/** Idempotente, em lotes pequenos, para exclusões pelo app e pelo painel. */
export function createFriendshipsCleanupHandler(gateway: FriendshipsCleanupGateway) {
  return async (uid: string): Promise<number> => {
    let removed = 0;
    for (;;) {
      // Não apaga relações de um UID cujo perfil foi recriado antes do evento.
      if (await gateway.profileExists(uid)) return removed;
      const ids = await gateway.list(uid, 200);
      if (ids.length === 0) return removed;
      await gateway.remove(ids);
      removed += ids.length;
    }
  };
}

export const onProfileDeletedFriendships = onDocumentDeleted(
  { document: 'users/{uid}', region: administrativeFunctionsRegion, retry: true },
  async (event) => {
    const firestore = getFirestore();
    await createFriendshipsCleanupHandler({
      profileExists: async (uid) => (await firestore.collection('users').doc(uid).get()).exists,
      list: async (uid, limit) => (await firestore.collection('friendships')
        .where('members', 'array-contains', uid).limit(limit).get()).docs.map((doc) => doc.id),
      remove: async (ids) => {
        const batch = firestore.batch();
        for (const id of ids) batch.delete(firestore.collection('friendships').doc(id));
        await batch.commit();
      },
    })(event.params.uid);
  },
);
