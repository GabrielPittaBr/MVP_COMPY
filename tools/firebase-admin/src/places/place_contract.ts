export const supportedSports = [
  'futebol',
  'basquete',
  'volei',
  'tenisDeMesa',
  'futsal',
  'corrida',
  'ciclismo',
  'caminhada',
] as const;

export type SupportedSport = (typeof supportedSports)[number];

export interface PlaceAddress {
  readonly street: string;
  readonly city: string;
  readonly cityLower: string;
  readonly state: string;
  readonly number?: string;
  readonly complement?: string;
  readonly neighborhood?: string;
  readonly postalCode?: string;
}

export interface PlaceCoordinates {
  readonly latitude: number;
  readonly longitude: number;
}

/** Contrato persistido de `places/{placeId}`, exceto timestamps do servidor. */
export interface PlaceSeed {
  readonly name: string;
  readonly nameLower: string;
  readonly description: string;
  readonly address: PlaceAddress;
  readonly sports: readonly SupportedSport[];
  readonly primarySport: SupportedSport;
  readonly coordinates: PlaceCoordinates;
  readonly imageUrl: string;
  readonly status: 'active' | 'inactive';
}

export class PlaceValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'PlaceValidationError';
  }
}

const brazilianStates = new Set([
  'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS',
  'MG', 'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC',
  'SP', 'SE', 'TO',
]);

const accentMap: Readonly<Record<string, string>> = {
  á: 'a', à: 'a', â: 'a', ã: 'a', ä: 'a',
  é: 'e', è: 'e', ê: 'e', ë: 'e',
  í: 'i', ì: 'i', î: 'i', ï: 'i',
  ó: 'o', ò: 'o', ô: 'o', õ: 'o', ö: 'o',
  ú: 'u', ù: 'u', û: 'u', ü: 'u',
  ç: 'c', ñ: 'n',
};

/** Espelha o algoritmo pt-BR do `TextNormalizer` Dart existente no mobile. */
export function normalizePtBr(input: string): string {
  return [...input.trim().toLowerCase()].map((character) => accentMap[character] ?? character).join('');
}

export function validatePlaceSeed(place: PlaceSeed): void {
  requireTrimmedString(place.name, 'name', 3, 120);
  requireTrimmedString(place.nameLower, 'nameLower', 3, 120);
  requireTrimmedString(place.description, 'description', 20, 1500);
  requireExactlyNormalized(place.name, place.nameLower, 'nameLower');
  validateAddress(place.address);
  validateSports(place.sports, place.primarySport);
  validateCoordinates(place.coordinates);
  validateHttpsUrl(place.imageUrl);
  if (place.status !== 'active' && place.status !== 'inactive') {
    throw new PlaceValidationError('status deve ser active ou inactive.');
  }
}

function validateAddress(address: PlaceAddress): void {
  requireTrimmedString(address.street, 'address.street', 1, 160);
  requireTrimmedString(address.city, 'address.city', 1, 100);
  requireTrimmedString(address.cityLower, 'address.cityLower', 1, 100);
  requireExactlyNormalized(address.city, address.cityLower, 'address.cityLower');

  if (!brazilianStates.has(address.state)) {
    throw new PlaceValidationError('address.state deve ser uma UF brasileira em maiúsculas.');
  }

  validateOptionalTrimmedString(address.number, 'address.number', 1, 20);
  validateOptionalTrimmedString(address.complement, 'address.complement', 1, 120);
  validateOptionalTrimmedString(address.neighborhood, 'address.neighborhood', 1, 100);
  if (address.postalCode !== undefined && !/^\d{8}$/.test(address.postalCode)) {
    throw new PlaceValidationError('address.postalCode deve conter exatamente 8 dígitos.');
  }
}

function validateSports(sports: readonly SupportedSport[], primarySport: SupportedSport): void {
  if (sports.length < 1 || sports.length > supportedSports.length) {
    throw new PlaceValidationError('sports deve conter de uma a oito modalidades.');
  }
  if (new Set(sports).size !== sports.length || !sports.every((sport) => supportedSports.includes(sport))) {
    throw new PlaceValidationError('sports contém modalidade inválida ou duplicada.');
  }
  if (!sports.includes(primarySport)) {
    throw new PlaceValidationError('primarySport deve estar presente em sports.');
  }
}

function validateCoordinates(coordinates: PlaceCoordinates): void {
  if (!Number.isFinite(coordinates.latitude) || coordinates.latitude < -90 || coordinates.latitude > 90) {
    throw new PlaceValidationError('coordinates.latitude deve estar entre -90 e 90.');
  }
  if (!Number.isFinite(coordinates.longitude) || coordinates.longitude < -180 || coordinates.longitude > 180) {
    throw new PlaceValidationError('coordinates.longitude deve estar entre -180 e 180.');
  }
}

function validateHttpsUrl(value: string): void {
  if (value.length === 0 || value.length > 2048) {
    throw new PlaceValidationError('imageUrl possui tamanho inválido.');
  }
  try {
    if (new URL(value).protocol !== 'https:') {
      throw new PlaceValidationError('imageUrl deve usar HTTPS.');
    }
  } catch (error) {
    if (error instanceof PlaceValidationError) throw error;
    throw new PlaceValidationError('imageUrl deve ser uma URL HTTPS válida.');
  }
}

function requireTrimmedString(value: string, field: string, minimum: number, maximum: number): void {
  if (value !== value.trim() || value.length < minimum || value.length > maximum) {
    throw new PlaceValidationError(`${field} deve ter de ${minimum} a ${maximum} caracteres, sem espaços externos.`);
  }
}

function validateOptionalTrimmedString(
  value: string | undefined,
  field: string,
  minimum: number,
  maximum: number,
): void {
  if (value !== undefined) requireTrimmedString(value, field, minimum, maximum);
}

function requireExactlyNormalized(source: string, normalized: string, field: string): void {
  if (normalizePtBr(source) !== normalized) {
    throw new PlaceValidationError(`${field} deve usar o normalizador pt-BR aprovado.`);
  }
}

export const parqueDoTrabalhadorSeed: PlaceSeed = {
  name: 'Parque do Trabalhador',
  nameLower: 'parque do trabalhador',
  description: 'Parque público de Taquara, com campo de futebol, quadras e pista usada para corrida, ciclismo e caminhada.',
  address: {
    street: 'Rua Ernesto Alves',
    neighborhood: 'Recreio',
    city: 'Taquara',
    cityLower: 'taquara',
    state: 'RS',
    postalCode: '95600354',
  },
  sports: ['futebol', 'basquete', 'futsal', 'volei', 'corrida', 'ciclismo', 'caminhada'],
  primarySport: 'futebol',
  coordinates: {
    latitude: -29.656276729317323,
    longitude: -50.787726691670045,
  },
  imageUrl: 'https://compy-tcc-admin.web.app/places/parque_do_trabalhador.jpg',
  status: 'active',
};
