export interface TokenRecord {
  id: string;
  name: string;
  remark: string;
  type: string;
  algorithm: string;
  secret: string;
  logoUri?: string;
  logoLightUri?: string;
  logoDarkUri?: string;
  logoSource?: string;
  digits?: number;
  period?: number;
  counter?: number;
  steamData?: string;
  createdAt: number;
  modifiedTime?: number;
}

const SUPPORTED_ALGORITHMS: string[] = ['SHA1', 'SHA3', 'SHA224', 'SHA256', 'SHA384', 'SHA512'];
const SUPPORTED_TYPES: string[] = ['TOTP', 'Steam', 'HOTP'];

export function sanitizeTokenRecord(record: TokenRecord): TokenRecord {
  const type = normalizeType(record.type || 'TOTP');
  return {
    id: record.id || '',
    name: record.name || '',
    remark: record.remark || '',
    type: type,
    algorithm: normalizeAlgorithm(type, record.algorithm || 'SHA1'),
    secret: record.secret || '',
    logoUri: record.logoUri || '',
    logoLightUri: record.logoLightUri || '',
    logoDarkUri: record.logoDarkUri || '',
    logoSource: record.logoSource || '',
    digits: normalizeDigits(type, record.digits),
    period: normalizePeriod(type, record.period),
    counter: normalizeCounter(record.counter),
    steamData: record.steamData || '',
    createdAt: record.createdAt || Date.now(),
    modifiedTime: record.modifiedTime || record.createdAt || Date.now()
  };
}

function normalizeType(type: string): string {
  const normalized = type.trim().toUpperCase();
  if (normalized === 'STEAM') {
    return 'Steam';
  }
  if (SUPPORTED_TYPES.includes(normalized)) {
    return normalized;
  }
  return 'TOTP';
}

function normalizeAlgorithm(type: string, algorithm: string): string {
  if (type !== 'TOTP') {
    return 'SHA1';
  }
  const normalized = algorithm.trim().toUpperCase();
  return SUPPORTED_ALGORITHMS.includes(normalized) ? normalized : 'SHA1';
}

function normalizeDigits(type: string, digits?: number): number {
  if (type === 'Steam') {
    return 5;
  }
  if (type === 'HOTP') {
    return digits === 8 ? 8 : 6;
  }
  if (digits === 4 || digits === 8) {
    return digits;
  }
  return 6;
}

function normalizePeriod(type: string, period?: number): number {
  if (type !== 'TOTP') {
    return 30;
  }
  return period === 60 ? 60 : 30;
}

function normalizeCounter(counter?: number): number {
  return counter && counter > 0 ? Math.floor(counter) : 0;
}
