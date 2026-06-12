export interface TokenRecord {
  id: string;
  name: string;
  remark: string;
  type: string;
  algorithm: string;
  secret: string;
  createdAt: number;
}

const SUPPORTED_ALGORITHMS: string[] = ['SHA1', 'SHA3', 'SHA224', 'SHA256', 'SHA384', 'SHA512'];

export function sanitizeTokenRecord(record: TokenRecord): TokenRecord {
  return {
    id: record.id || '',
    name: record.name || '',
    remark: record.remark || '',
    type: record.type || 'TOTP',
    algorithm: normalizeAlgorithm(record.algorithm || 'SHA1'),
    secret: record.secret || '',
    createdAt: record.createdAt || Date.now()
  };
}

function normalizeAlgorithm(algorithm: string): string {
  const normalized = algorithm.trim().toUpperCase();
  return SUPPORTED_ALGORITHMS.includes(normalized) ? normalized : 'SHA1';
}
