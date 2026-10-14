import { applicationDefault, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth, type Auth } from 'firebase-admin/auth';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';

export interface TrustedAdminSdk {
  readonly auth: Auth;
  readonly firestore: Firestore;
}

export class TrustedCredentialError extends Error {
  constructor() {
    super(
      'Credenciais Firebase Admin indisponíveis. Configure Application Default '
        + 'Credentials ou GOOGLE_APPLICATION_CREDENTIALS com um arquivo externo ao repositório.',
    );
    this.name = 'TrustedCredentialError';
  }
}

/**
 * Inicializa o Admin SDK somente com credenciais externas. Um caminho de
 * service account, quando usado, é lido pelo mecanismo oficial de ADC; o
 * conteúdo nunca é aceito como argumento, impresso ou persistido pelo tooling.
 */
export async function createTrustedAdminSdk(
  initialize: () => Promise<TrustedAdminSdk> = initializeWithApplicationDefaultCredentials,
): Promise<TrustedAdminSdk> {
  try {
    return await initialize();
  } catch {
    throw new TrustedCredentialError();
  }
}

async function initializeWithApplicationDefaultCredentials(): Promise<TrustedAdminSdk> {
  const app = getApps()[0] ?? initializeApp({ credential: applicationDefault() });
  const credential = app.options.credential;

  if (credential === undefined) {
    throw new Error('Nenhuma credencial configurada.');
  }

  // Força a resolução de ADC agora, para que os scripts falhem antes de
  // executar qualquer mutação. O erro original não é repassado ao terminal.
  await credential.getAccessToken();

  return {
    auth: getAuth(app),
    firestore: getFirestore(app),
  };
}

/** Mantido pequeno para ser substituído por um fake nos testes de comandos. */
export interface BootstrapAuthGateway {
  getUser(uid: string): Promise<BootstrapUserRecord>;
  setCustomUserClaims(uid: string, claims: Record<string, unknown>): Promise<void>;
}

export interface BootstrapUserRecord {
  readonly uid: string;
  readonly email?: string;
  readonly emailVerified: boolean;
  readonly disabled: boolean;
  readonly providerData: ReadonlyArray<{ readonly providerId: string }>;
  readonly customClaims?: Readonly<Record<string, unknown>>;
}

export function createBootstrapAuthGateway(auth: Auth): BootstrapAuthGateway {
  return {
    getUser: async (uid) => auth.getUser(uid),
    setCustomUserClaims: async (uid, claims) => auth.setCustomUserClaims(uid, claims),
  };
}
