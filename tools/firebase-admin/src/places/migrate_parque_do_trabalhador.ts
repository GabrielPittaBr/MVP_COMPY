import type { Firestore } from 'firebase-admin/firestore';
import { FieldValue, GeoPoint, Timestamp } from 'firebase-admin/firestore';

import {
  parqueDoTrabalhadorSeed,
  type PlaceSeed,
  validatePlaceSeed,
} from './place_contract.js';

export const parqueDoTrabalhadorId = 'parque_do_trabalhador';

export interface PlaceMigrationGateway {
  getPlace(id: string): Promise<PlaceSeed | undefined>;
  createPlace(id: string, place: PlaceSeed): Promise<void>;
  verifyPlace(id: string, place: PlaceSeed): Promise<void>;
}

export type PlaceMigrationOutcome = 'would-create' | 'created' | 'already-equivalent';

export interface PlaceMigrationResult {
  readonly outcome: PlaceMigrationOutcome;
  readonly changed: boolean;
}

export class PlaceMigrationConflictError extends Error {
  constructor(readonly differences: readonly string[]) {
    super(`O Local Esportivo existente diverge do seed aprovado: ${differences.join(', ')}.`);
    this.name = 'PlaceMigrationConflictError';
  }
}

export async function migrateParqueDoTrabalhador(
  gateway: PlaceMigrationGateway,
  { dryRun }: { readonly dryRun: boolean },
): Promise<PlaceMigrationResult> {
  validatePlaceSeed(parqueDoTrabalhadorSeed);
  const existing = await gateway.getPlace(parqueDoTrabalhadorId);

  if (existing === undefined) {
    if (dryRun) return { outcome: 'would-create', changed: false };

    await gateway.createPlace(parqueDoTrabalhadorId, parqueDoTrabalhadorSeed);
    await gateway.verifyPlace(parqueDoTrabalhadorId, parqueDoTrabalhadorSeed);
    return { outcome: 'created', changed: true };
  }

  const differences = findDifferences(parqueDoTrabalhadorSeed, existing);
  if (differences.length > 0) {
    throw new PlaceMigrationConflictError(differences);
  }

  await gateway.verifyPlace(parqueDoTrabalhadorId, parqueDoTrabalhadorSeed);
  return { outcome: 'already-equivalent', changed: false };
}

export function createFirestorePlaceMigrationGateway(firestore: Firestore): PlaceMigrationGateway {
  return {
    getPlace: async (id) => {
      const snapshot = await firestore.collection('places').doc(id).get();
      if (!snapshot.exists) return undefined;
      return mapStoredPlace(snapshot.data());
    },
    createPlace: async (id, place) => {
      await firestore.collection('places').doc(id).create({
        ...place,
        coordinates: new GeoPoint(place.coordinates.latitude, place.coordinates.longitude),
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    },
    verifyPlace: async (id, place) => {
      const direct = await firestore.collection('places').doc(id).get();
      if (!direct.exists || !hasServerTimestamps(direct.data())) {
        throw new Error('A verificação pós-migração não encontrou timestamps de servidor válidos.');
      }
      const directPlace = mapStoredPlace(direct.data());
      const differences = findDifferences(place, directPlace);
      if (differences.length > 0) throw new PlaceMigrationConflictError(differences);

      const activeOrdered = await firestore.collection('places')
        .where('status', '==', 'active')
        .orderBy('nameLower')
        .get();
      if (!activeOrdered.docs.some((document) => document.id === id)) {
        throw new Error('A verificação pós-migração não encontrou o local na consulta de ativos.');
      }

      for (const sport of place.sports) {
        const matchingSport = await firestore.collection('places')
          .where('status', '==', 'active')
          .where('sports', 'array-contains', sport)
          .orderBy('nameLower')
          .get();
        if (!matchingSport.docs.some((document) => document.id === id)) {
          throw new Error(`A verificação pós-migração não encontrou o local para ${sport}.`);
        }
      }
    },
  };
}

function mapStoredPlace(data: FirebaseFirestore.DocumentData | undefined): PlaceSeed {
  if (data === undefined || !isRecord(data) || !isRecord(data.address) || !isRecord(data.coordinates)) {
    throw new Error('O documento existente de Local Esportivo possui formato inválido.');
  }
  const place: PlaceSeed = {
    name: requiredString(data.name, 'name'),
    nameLower: requiredString(data.nameLower, 'nameLower'),
    description: requiredString(data.description, 'description'),
    address: {
      street: requiredString(data.address.street, 'address.street'),
      city: requiredString(data.address.city, 'address.city'),
      cityLower: requiredString(data.address.cityLower, 'address.cityLower'),
      state: requiredString(data.address.state, 'address.state'),
      ...optionalString(data.address.number, 'address.number'),
      ...optionalString(data.address.complement, 'address.complement'),
      ...optionalString(data.address.neighborhood, 'address.neighborhood'),
      ...optionalString(data.address.postalCode, 'address.postalCode'),
    },
    sports: requiredSports(data.sports),
    primarySport: requiredSport(data.primarySport),
    coordinates: {
      latitude: requiredNumber(data.coordinates.latitude, 'coordinates.latitude'),
      longitude: requiredNumber(data.coordinates.longitude, 'coordinates.longitude'),
    },
    imageUrl: requiredString(data.imageUrl, 'imageUrl'),
    status: requiredStatus(data.status),
  };
  validatePlaceSeed(place);
  return place;
}

function hasServerTimestamps(data: FirebaseFirestore.DocumentData | undefined): boolean {
  return data?.createdAt instanceof Timestamp && data.updatedAt instanceof Timestamp;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function requiredString(value: unknown, field: string): string {
  if (typeof value !== 'string') throw new Error(`${field} deve ser string.`);
  return value;
}

function optionalString(value: unknown, field: string): Record<string, string> {
  if (value === undefined) return {};
  return { [field.split('.').at(-1) ?? field]: requiredString(value, field) };
}

function requiredNumber(value: unknown, field: string): number {
  if (typeof value !== 'number') throw new Error(`${field} deve ser número.`);
  return value;
}

function requiredSports(value: unknown): PlaceSeed['sports'] {
  if (!Array.isArray(value)) throw new Error('sports deve ser lista.');
  return value.map((sport) => requiredSport(sport));
}

function requiredSport(value: unknown): PlaceSeed['primarySport'] {
  if (typeof value !== 'string') throw new Error('modalidade deve ser string.');
  return value as PlaceSeed['primarySport'];
}

function requiredStatus(value: unknown): PlaceSeed['status'] {
  if (value !== 'active' && value !== 'inactive') throw new Error('status inválido.');
  return value;
}

function findDifferences(expected: PlaceSeed, actual: PlaceSeed): string[] {
  const differences: string[] = [];
  compareValues(expected, actual, '', differences);
  return differences;
}

function compareValues(expected: unknown, actual: unknown, path: string, differences: string[]): void {
  if (Array.isArray(expected) && Array.isArray(actual)) {
    if (expected.length !== actual.length || expected.some((value, index) => value !== actual[index])) {
      differences.push(path);
    }
    return;
  }
  if (isRecord(expected) && isRecord(actual)) {
    const keys = new Set([...Object.keys(expected), ...Object.keys(actual)]);
    for (const key of [...keys].sort()) {
      compareValues(expected[key], actual[key], path.length === 0 ? key : `${path}.${key}`, differences);
    }
    return;
  }
  if (expected !== actual) differences.push(path);
}
