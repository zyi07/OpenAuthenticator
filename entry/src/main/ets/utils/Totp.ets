import cryptoFramework from '@ohos.security.cryptoFramework';

const DEFAULT_TOTP_PERIOD_SECONDS: number = 30;
const DEFAULT_TOTP_DIGITS: number = 6;
const SHA1_BLOCK_SIZE: number = 64;
const BASE32_ALPHABET: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
const BASE64_ALPHABET: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
const STEAM_ALPHABET: string = '23456789BCDFGHJKMNPQRTVWXY';
const STEAM_CODE_LENGTH: number = 5;
const DEFAULT_ALGORITHM: string = 'SHA1';
const SUPPORTED_ALGORITHMS: string[] = ['SHA1', 'SHA3', 'SHA224', 'SHA256', 'SHA384', 'SHA512'];

export class Totp {
  static generate(
    secret: string,
    timeMs: number = Date.now(),
    algorithm: string = DEFAULT_ALGORITHM,
    digits: number = DEFAULT_TOTP_DIGITS,
    periodSeconds: number = DEFAULT_TOTP_PERIOD_SECONDS,
    type: string = 'TOTP',
    counter: number = 0
  ): string {
    const normalizedType = normalizeType(type);
    const normalizedDigits = normalizeDigits(digits, normalizedType);
    const normalizedPeriod = normalizePeriod(periodSeconds);
    const key = decodeSecret(secret, normalizedType);
    if (key.length === 0) {
      if (normalizedType === 'STEAM') {
        return repeatChar('0', STEAM_CODE_LENGTH);
      }
      return repeatChar('0', normalizedDigits);
    }

    const seconds = Math.floor(timeMs / 1000);
    const movingFactor = normalizedType === 'HOTP' ? normalizeCounter(counter) : Math.floor(seconds / normalizedPeriod);
    const digest = hmac(
      key,
      counterToBytes(movingFactor),
      normalizedType === 'STEAM' ? DEFAULT_ALGORITHM : algorithm
    );
    if (digest.length === 0) {
      if (normalizedType === 'STEAM') {
        return repeatChar('0', STEAM_CODE_LENGTH);
      }
      return repeatChar('0', normalizedDigits);
    }

    if (normalizedType === 'STEAM') {
      return steamCode(digest);
    }

    const offset = digest[digest.length - 1] & 0x0f;
    const binary =
      ((digest[offset] & 0x7f) << 24) |
      ((digest[offset + 1] & 0xff) << 16) |
      ((digest[offset + 2] & 0xff) << 8) |
      (digest[offset + 3] & 0xff);
    const code = binary % Math.pow(10, normalizedDigits);

    return leftPad(code.toString(), normalizedDigits, '0');
  }

  static remainingSeconds(timeMs: number = Date.now(), periodSeconds: number = DEFAULT_TOTP_PERIOD_SECONDS): number {
    const normalizedPeriod = normalizePeriod(periodSeconds);
    const seconds = Math.floor(timeMs / 1000);
    const elapsed = seconds % normalizedPeriod;
    return normalizedPeriod - elapsed;
  }

  static formatCode(code: string): string {
    if (code.length <= 4 || !isNumericCode(code)) {
      return code;
    }
    const splitIndex = Math.floor(code.length / 2);
    return `${code.substring(0, splitIndex)} ${code.substring(splitIndex)}`;
  }

  static isValidSecret(secret: string, type: string = 'TOTP'): boolean {
    return decodeSecret(secret, normalizeType(type)).length > 0;
  }

  static normalizeSecret(secret: string, type: string = 'TOTP'): string {
    const normalizedType = normalizeType(type);
    const base32 = normalizeBase32(secret);
    if (isValidBase32(base32)) {
      return base32;
    }
    if (normalizedType === 'STEAM') {
      const base64 = normalizeBase64(secret);
      if (isValidBase64(base64)) {
        return base64;
      }
    }
    return '';
  }
}

function hmac(key: number[], message: number[], algorithm: string): number[] {
  const normalizedAlgorithm = normalizeAlgorithm(algorithm);

  for (const mdName of macDigestCandidates(normalizedAlgorithm)) {
    try {
      const keyGenerator = cryptoFramework.createSymKeyGenerator('HMAC');
      const macSpec: cryptoFramework.HmacSpec = {
        algName: 'HMAC',
        mdName: mdName
      };
      const mac = cryptoFramework.createMac(macSpec);
      const symKey = keyGenerator.convertKeySync(toDataBlob(key));
      mac.initSync(symKey);
      mac.updateSync(toDataBlob(message));
      return Array.from(mac.doFinalSync().data);
    } catch (error) {
    }
  }

  if (normalizedAlgorithm === DEFAULT_ALGORITHM) {
    return hmacSha1(key, message);
  }
  return [];
}

function normalizeAlgorithm(algorithm: string): string {
  const normalized = algorithm.trim().toUpperCase();
  return SUPPORTED_ALGORITHMS.includes(normalized) ? normalized : DEFAULT_ALGORITHM;
}

function normalizeType(type: string): string {
  const normalized = type.trim().toUpperCase();
  if (normalized === 'STEAM') {
    return 'STEAM';
  }
  if (normalized === 'HOTP') {
    return 'HOTP';
  }
  return 'TOTP';
}

function normalizeDigits(digits: number, type: string): number {
  if (type === 'STEAM') {
    return STEAM_CODE_LENGTH;
  }
  if (type === 'HOTP') {
    return digits === 8 ? 8 : DEFAULT_TOTP_DIGITS;
  }
  if (digits === 4 || digits === 8) {
    return digits;
  }
  return DEFAULT_TOTP_DIGITS;
}

function normalizePeriod(periodSeconds: number): number {
  return periodSeconds === 60 ? 60 : DEFAULT_TOTP_PERIOD_SECONDS;
}

function normalizeCounter(counter: number): number {
  return counter > 0 ? Math.floor(counter) : 0;
}

function steamCode(digest: number[]): string {
  const offset = digest[digest.length - 1] & 0x0f;
  let code =
    ((digest[offset] & 0x7f) << 24) |
    ((digest[offset + 1] & 0xff) << 16) |
    ((digest[offset + 2] & 0xff) << 8) |
    (digest[offset + 3] & 0xff);
  let result = '';

  for (let index = 0; index < STEAM_CODE_LENGTH; index++) {
    result += STEAM_ALPHABET.charAt(code % STEAM_ALPHABET.length);
    code = Math.floor(code / STEAM_ALPHABET.length);
  }

  return result;
}

function isNumericCode(code: string): boolean {
  for (let index = 0; index < code.length; index++) {
    const charCode = code.charCodeAt(index);
    if (charCode < 48 || charCode > 57) {
      return false;
    }
  }
  return true;
}

function macDigestCandidates(algorithm: string): string[] {
  switch (algorithm) {
    case 'SHA3':
      return ['SHA3', 'SHA3_256', 'SHA3-256'];
    case 'SHA224':
      return ['SHA224', 'SHA-224'];
    case 'SHA256':
      return ['SHA256', 'SHA-256'];
    case 'SHA384':
      return ['SHA384', 'SHA-384'];
    case 'SHA512':
      return ['SHA512', 'SHA-512'];
    default:
      return [DEFAULT_ALGORITHM, 'SHA-1'];
  }
}

function toDataBlob(bytes: number[]): cryptoFramework.DataBlob {
  return { data: new Uint8Array(bytes) };
}

function decodeSecret(secret: string, type: string): number[] {
  const base32 = normalizeBase32(secret);
  if (isValidBase32(base32)) {
    return decodeBase32(base32);
  }

  if (type === 'STEAM') {
    const base64 = normalizeBase64(secret);
    if (isValidBase64(base64)) {
      return decodeBase64(base64);
    }
  }

  return [];
}

function normalizeBase32(value: string): string {
  return value.trim().replace(/[\s-]/g, '').replace(/=+$/g, '').toUpperCase();
}

function isValidBase32(value: string): boolean {
  if (value.length < 8 || [1, 3, 6].includes(value.length % 8)) {
    return false;
  }
  for (let index = 0; index < value.length; index++) {
    const code = value.charCodeAt(index);
    const isLetter = code >= 65 && code <= 90;
    const isDigit = code >= 50 && code <= 55;
    if (!isLetter && !isDigit) {
      return false;
    }
  }
  return decodeBase32(value).length >= 5;
}

function decodeBase32(value: string): number[] {
  const bytes: number[] = [];
  let buffer = 0;
  let bitsLeft = 0;

  for (let index = 0; index < value.length; index++) {
    const alphabetIndex = BASE32_ALPHABET.indexOf(value.charAt(index));
    if (alphabetIndex < 0) {
      return [];
    }

    buffer = (buffer << 5) | alphabetIndex;
    bitsLeft += 5;

    if (bitsLeft >= 8) {
      bitsLeft -= 8;
      bytes.push((buffer >> bitsLeft) & 0xff);
    }
  }

  return bytes;
}

function normalizeBase64(value: string): string {
  return value.trim().replace(/\s/g, '').replace(/-/g, '+').replace(/_/g, '/');
}

function isValidBase64(value: string): boolean {
  if (value.length < 8 || value.length % 4 === 1) {
    return false;
  }
  let paddingStarted = false;
  let paddingCount = 0;
  for (let index = 0; index < value.length; index++) {
    const character = value.charAt(index);
    if (character === '=') {
      paddingStarted = true;
      paddingCount++;
      if (paddingCount > 2) {
        return false;
      }
    } else if (paddingStarted || BASE64_ALPHABET.indexOf(character) < 0) {
      return false;
    }
  }
  return decodeBase64(value).length >= 10;
}

function decodeBase64(value: string): number[] {
  const normalized = value.replace(/=+$/g, '');
  const bytes: number[] = [];
  let buffer = 0;
  let bitsLeft = 0;
  for (let index = 0; index < normalized.length; index++) {
    const alphabetIndex = BASE64_ALPHABET.indexOf(normalized.charAt(index));
    if (alphabetIndex < 0) {
      return [];
    }
    buffer = (buffer << 6) | alphabetIndex;
    bitsLeft += 6;
    if (bitsLeft >= 8) {
      bitsLeft -= 8;
      bytes.push((buffer >> bitsLeft) & 0xff);
    }
  }
  return bytes;
}

function counterToBytes(counter: number): number[] {
  const bytes: number[] = new Array<number>(8).fill(0);
  let value = counter;

  for (let index = 7; index >= 0; index--) {
    bytes[index] = value % 256;
    value = Math.floor(value / 256);
  }

  return bytes;
}

function hmacSha1(key: number[], message: number[]): number[] {
  let normalizedKey = key.slice();
  if (normalizedKey.length > SHA1_BLOCK_SIZE) {
    normalizedKey = sha1(normalizedKey);
  }

  while (normalizedKey.length < SHA1_BLOCK_SIZE) {
    normalizedKey.push(0);
  }

  const outerKeyPad: number[] = [];
  const innerKeyPad: number[] = [];

  for (let index = 0; index < SHA1_BLOCK_SIZE; index++) {
    outerKeyPad.push(normalizedKey[index] ^ 0x5c);
    innerKeyPad.push(normalizedKey[index] ^ 0x36);
  }

  return sha1(outerKeyPad.concat(sha1(innerKeyPad.concat(message))));
}

function sha1(input: number[]): number[] {
  const bytes = input.slice();
  const bitLength = bytes.length * 8;

  bytes.push(0x80);
  while (bytes.length % 64 !== 56) {
    bytes.push(0);
  }

  appendUInt32(bytes, Math.floor(bitLength / 0x100000000));
  appendUInt32(bytes, bitLength & 0xffffffff);

  let h0 = 0x67452301;
  let h1 = 0xefcdab89;
  let h2 = 0x98badcfe;
  let h3 = 0x10325476;
  let h4 = 0xc3d2e1f0;

  for (let blockStart = 0; blockStart < bytes.length; blockStart += 64) {
    const words: number[] = new Array<number>(80).fill(0);

    for (let index = 0; index < 16; index++) {
      const offset = blockStart + index * 4;
      words[index] =
        ((bytes[offset] & 0xff) << 24) |
        ((bytes[offset + 1] & 0xff) << 16) |
        ((bytes[offset + 2] & 0xff) << 8) |
        (bytes[offset + 3] & 0xff);
    }

    for (let index = 16; index < 80; index++) {
      words[index] = rotateLeft(words[index - 3] ^ words[index - 8] ^ words[index - 14] ^ words[index - 16], 1);
    }

    let a = h0;
    let b = h1;
    let c = h2;
    let d = h3;
    let e = h4;

    for (let index = 0; index < 80; index++) {
      let f = 0;
      let k = 0;

      if (index < 20) {
        f = (b & c) | (~b & d);
        k = 0x5a827999;
      } else if (index < 40) {
        f = b ^ c ^ d;
        k = 0x6ed9eba1;
      } else if (index < 60) {
        f = (b & c) | (b & d) | (c & d);
        k = 0x8f1bbcdc;
      } else {
        f = b ^ c ^ d;
        k = 0xca62c1d6;
      }

      const temp = (rotateLeft(a, 5) + f + e + k + words[index]) >>> 0;
      e = d;
      d = c;
      c = rotateLeft(b, 30);
      b = a;
      a = temp;
    }

    h0 = (h0 + a) >>> 0;
    h1 = (h1 + b) >>> 0;
    h2 = (h2 + c) >>> 0;
    h3 = (h3 + d) >>> 0;
    h4 = (h4 + e) >>> 0;
  }

  const digest: number[] = [];
  appendUInt32(digest, h0);
  appendUInt32(digest, h1);
  appendUInt32(digest, h2);
  appendUInt32(digest, h3);
  appendUInt32(digest, h4);
  return digest;
}

function appendUInt32(bytes: number[], value: number): void {
  bytes.push((value >>> 24) & 0xff);
  bytes.push((value >>> 16) & 0xff);
  bytes.push((value >>> 8) & 0xff);
  bytes.push(value & 0xff);
}

function rotateLeft(value: number, bits: number): number {
  return ((value << bits) | (value >>> (32 - bits))) >>> 0;
}

function leftPad(value: string, length: number, pad: string): string {
  if (value.length >= length) {
    return value;
  }
  return `${repeatChar(pad, length - value.length)}${value}`;
}

function repeatChar(value: string, count: number): string {
  let result = '';
  for (let index = 0; index < count; index++) {
    result += value;
  }
  return result;
}
