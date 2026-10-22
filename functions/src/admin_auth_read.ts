import { getAuth, type UserRecord } from 'firebase-admin/auth';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { administrativeFunctionsRegion } from './config.js';

/**
 * Narrow representation of an Auth account used by the read-only administrative
 * Callables. Keeping this boundary small prevents accidental exposure of Auth
 * fields such as tokens, password hashes, or custom claims.
 */
export interface AdministrativeAuthUser {
  uid: string;
  email?: string;
  emailVerified: boolean;
  disabled: boolean;
  providerIds: readonly string[];
  createdAt?: string;
  lastSignInAt?: string;
}

export interface AdministrativeAuthGateway {
  getUser(uid: string): Promise<AdministrativeAuthUser>;
  getUserByEmail(email: string): Promise<AdministrativeAuthUser>;
  getUsers(uids: readonly string[]): Promise<readonly AdministrativeAuthUser[]>;
}

export interface AdministrativeCallableRequest {
  data: unknown;
  auth?: {
    uid: string;
    token: Record<string, unknown>;
  };
}

export interface AdminUserAuthDetails {
  uid: string;
  email: string | null;
  emailVerified: boolean;
  providerIds: string[];
  createdAt: string | null;
  lastSignInAt: string | null;
  disabled: boolean;
}

export interface AdminUsersAuthStatus {
  items: Array<{
    uid: string;
    disabled: boolean;
  }>;
}

const maxFirebaseAuthUidLength = 128;
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/u;

/** The production deployment must reject invalid App Check attestations. */
export const administrativeCallableOptions = {
  region: administrativeFunctionsRegion,
  enforceAppCheck: true,
} as const;

function requireAdministrator(request: AdministrativeCallableRequest): void {
  if (request.auth === undefined) {
    throw new HttpsError('unauthenticated', 'É necessário autenticar-se para acessar esta operação.');
  }

  if (request.auth.token.admin !== true) {
    throw new HttpsError('permission-denied', 'Esta operação exige uma conta administrativa.');
  }
}

function requirePlainObject(value: unknown): Record<string, unknown> {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw new HttpsError('invalid-argument', 'O payload deve ser um objeto JSON.');
  }

  return value as Record<string, unknown>;
}

function requireOnlyKeys(value: Record<string, unknown>, allowedKeys: readonly string[]): void {
  if (Object.keys(value).some((key) => !allowedKeys.includes(key))) {
    throw new HttpsError('invalid-argument', 'O payload contém campos não permitidos.');
  }
}

function requireUid(value: unknown): string {
  if (typeof value !== 'string' || value.length === 0 || value.length > maxFirebaseAuthUidLength || value.trim() !== value) {
    throw new HttpsError('invalid-argument', 'O UID informado é inválido.');
  }

  return value;
}

function requireEmail(value: unknown): string {
  if (typeof value !== 'string') {
    throw new HttpsError('invalid-argument', 'O e-mail informado é inválido.');
  }

  const normalizedEmail = value.trim().toLowerCase();
  if (!emailPattern.test(normalizedEmail)) {
    throw new HttpsError('invalid-argument', 'O e-mail informado é inválido.');
  }

  return normalizedEmail;
}

function normalizeIsoDate(value: string | undefined): string | null {
  if (value === undefined || value.length === 0) {
    return null;
  }

  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString();
}

function toAdministrativeAuthUser(user: UserRecord): AdministrativeAuthUser {
  return {
    uid: user.uid,
    email: user.email,
    emailVerified: user.emailVerified,
    disabled: user.disabled,
    providerIds: [...new Set(user.providerData.map((provider) => provider.providerId).filter(Boolean))],
    createdAt: user.metadata.creationTime,
    lastSignInAt: user.metadata.lastSignInTime,
  };
}

function createFirebaseAdminAuthGateway(): AdministrativeAuthGateway {
  return {
    getUser: async (uid) => toAdministrativeAuthUser(await getAuth().getUser(uid)),
    getUserByEmail: async (email) => toAdministrativeAuthUser(await getAuth().getUserByEmail(email)),
    getUsers: async (uids) => {
      const result = await getAuth().getUsers(uids.map((uid) => ({ uid })));
      return result.users.map(toAdministrativeAuthUser);
    },
  };
}

function throwSafeAuthLookupError(error: unknown): never {
  if (typeof error === 'object' && error !== null && 'code' in error && error.code === 'auth/user-not-found') {
    throw new HttpsError('not-found', 'A conta de usuário não foi encontrada.');
  }

  throw new HttpsError('internal', 'Não foi possível consultar a conta de usuário.');
}

function toDetails(user: AdministrativeAuthUser): AdminUserAuthDetails {
  return {
    uid: user.uid,
    email: user.email ?? null,
    emailVerified: user.emailVerified,
    providerIds: [...new Set(user.providerIds)],
    createdAt: normalizeIsoDate(user.createdAt),
    lastSignInAt: normalizeIsoDate(user.lastSignInAt),
    disabled: user.disabled,
  };
}

export function createGetAdminUserAuthDetailsHandler(gateway: AdministrativeAuthGateway) {
  return async (request: AdministrativeCallableRequest): Promise<AdminUserAuthDetails> => {
    requireAdministrator(request);

    const data = requirePlainObject(request.data);
    requireOnlyKeys(data, ['uid', 'email']);
    const hasUid = Object.hasOwn(data, 'uid');
    const hasEmail = Object.hasOwn(data, 'email');
    if (hasUid === hasEmail) {
      throw new HttpsError('invalid-argument', 'Informe exatamente um identificador: UID ou e-mail.');
    }

    try {
      const user = hasUid
        ? await gateway.getUser(requireUid(data.uid))
        : await gateway.getUserByEmail(requireEmail(data.email));
      return toDetails(user);
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
      return throwSafeAuthLookupError(error);
    }
  };
}

export function createGetAdminUsersAuthStatusHandler(gateway: AdministrativeAuthGateway) {
  return async (request: AdministrativeCallableRequest): Promise<AdminUsersAuthStatus> => {
    requireAdministrator(request);

    const data = requirePlainObject(request.data);
    requireOnlyKeys(data, ['uids']);
    if (!Array.isArray(data.uids) || data.uids.length < 1 || data.uids.length > 20) {
      throw new HttpsError('invalid-argument', 'Informe entre um e vinte UIDs.');
    }

    const uids = data.uids.map(requireUid);
    if (new Set(uids).size !== uids.length) {
      throw new HttpsError('invalid-argument', 'A lista de UIDs não pode conter duplicatas.');
    }

    try {
      const usersByUid = new Map((await gateway.getUsers(uids)).map((user) => [user.uid, user]));
      return {
        items: uids.flatMap((uid) => {
          const user = usersByUid.get(uid);
          return user === undefined ? [] : [{ uid: user.uid, disabled: user.disabled }];
        }),
      };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError('internal', 'Não foi possível consultar o estado das contas de usuário.');
    }
  };
}

const firebaseAdminAuthGateway = createFirebaseAdminAuthGateway();

export const getAdminUserAuthDetails = onCall(administrativeCallableOptions, (request) =>
  createGetAdminUserAuthDetailsHandler(firebaseAdminAuthGateway)(request),
);

export const getAdminUsersAuthStatus = onCall(administrativeCallableOptions, (request) =>
  createGetAdminUsersAuthStatusHandler(firebaseAdminAuthGateway)(request),
);
