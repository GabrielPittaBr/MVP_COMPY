import { FieldPath, type Firestore } from 'firebase-admin/firestore';

const maxProfileNameLength = 60;

const accentMap: Readonly<Record<string, string>> = {
  á: 'a', à: 'a', â: 'a', ã: 'a', ä: 'a',
  é: 'e', è: 'e', ê: 'e', ë: 'e',
  í: 'i', ì: 'i', î: 'i', ï: 'i',
  ó: 'o', ò: 'o', ô: 'o', õ: 'o', ö: 'o',
  ú: 'u', ù: 'u', û: 'u', ü: 'u',
  ç: 'c', ñ: 'n',
};

/** Espelha o `TextNormalizer` pt-BR usado pelo cliente Flutter. */
export function normalizeProfileName(input: string): string {
  return [...input.trim().toLowerCase()]
    .map((character) => accentMap[character] ?? character)
    .join('');
}

export interface ProfileBackfillCandidate {
  readonly id: string;
  readonly name: unknown;
  readonly nameLower: unknown;
}

export interface ProfileNameLowerBackfillGateway {
  listProfiles(): AsyncIterable<ProfileBackfillCandidate>;
  updateNameLower(id: string, nameLower: string): Promise<void>;
}

export interface ProfileNameLowerBackfillResult {
  readonly updated: number;
  readonly unchanged: number;
  readonly invalidProfileIds: readonly string[];
}

/**
 * Completa somente `nameLower`; nunca cria, remove ou inventa nomes de perfil.
 */
export async function backfillProfileNameLower(
  gateway: ProfileNameLowerBackfillGateway,
  { dryRun }: { readonly dryRun: boolean },
): Promise<ProfileNameLowerBackfillResult> {
  let updated = 0;
  let unchanged = 0;
  const invalidProfileIds: string[] = [];

  for await (const profile of gateway.listProfiles()) {
    const nameLower = validNormalizedName(profile.name);
    if (nameLower === undefined) {
      invalidProfileIds.push(profile.id);
      continue;
    }

    if (profile.nameLower === nameLower) {
      unchanged += 1;
      continue;
    }

    if (!dryRun) await gateway.updateNameLower(profile.id, nameLower);
    updated += 1;
  }

  return { updated, unchanged, invalidProfileIds };
}

export function createFirestoreProfileNameLowerBackfillGateway(
  firestore: Firestore,
): ProfileNameLowerBackfillGateway {
  return {
    async *listProfiles() {
      let lastDocument: FirebaseFirestore.QueryDocumentSnapshot | undefined;
      do {
        let query = firestore.collection('users')
          .orderBy(FieldPath.documentId())
          .limit(250);
        if (lastDocument !== undefined) query = query.startAfter(lastDocument);

        const page = await query.get();
        for (const document of page.docs) {
          const data = document.data();
          yield {
            id: document.id,
            name: data.name,
            nameLower: data.nameLower,
          };
        }
        lastDocument = page.docs.at(-1);
      } while (lastDocument !== undefined);
    },
    updateNameLower: async (id, nameLower) => {
      await firestore.collection('users').doc(id).update({ nameLower });
    },
  };
}

function validNormalizedName(value: unknown): string | undefined {
  if (typeof value !== 'string') return undefined;
  const trimmed = value.trim();
  if (trimmed.length === 0 || trimmed.length > maxProfileNameLength) return undefined;
  return normalizeProfileName(trimmed);
}
