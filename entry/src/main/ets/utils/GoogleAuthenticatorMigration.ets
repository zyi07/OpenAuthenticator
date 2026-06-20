import { util } from '@kit.ArkTS';

export interface GoogleOtpParameter {
  secret: string;
  name: string;
  issuer: string;
  algorithm: string;
  digits: number;
  type: string;
  counter: number;
}

class ProtoReader {
  private offset: number = 0;
  private bytes: Uint8Array;

  constructor(bytes: Uint8Array) {
    this.bytes = bytes;
  }

  hasRemaining(): boolean {
    return this.offset < this.bytes.length;
  }

  readVarint(): number {
    let value = 0;
    let multiplier = 1;
    for (let index = 0; index < 10 && this.offset < this.bytes.length; index++) {
      const byte = this.bytes[this.offset++];
      value += (byte & 0x7F) * multiplier;
      if ((byte & 0x80) === 0) {
        return value;
      }
      multiplier *= 128;
    }
    return value;
  }

  readBytes(): Uint8Array {
    const length = this.readVarint();
    const end = Math.min(this.offset + length, this.bytes.length);
    const value = this.bytes.slice(this.offset, end);
    this.offset = end;
    return value;
  }

  skip(wireType: number): void {
    if (wireType === 0) {
      this.readVarint();
    } else if (wireType === 1) {
      this.offset = Math.min(this.offset + 8, this.bytes.length);
    } else if (wireType === 2) {
      this.readBytes();
    } else if (wireType === 5) {
      this.offset = Math.min(this.offset + 4, this.bytes.length);
    } else {
      this.offset = this.bytes.length;
    }
  }
}

export class GoogleAuthenticatorMigration {
  static parse(uri: string): GoogleOtpParameter[] {
    const prefix = 'otpauth-migration://offline?';
    if (!uri.toLowerCase().startsWith(prefix)) {
      return [];
    }
    const data = GoogleAuthenticatorMigration.queryValue(uri.substring(prefix.length), 'data');
    if (data.length === 0) {
      return [];
    }
    try {
      const payload = GoogleAuthenticatorMigration.decodePayload(data);
      return GoogleAuthenticatorMigration.parsePayload(payload);
    } catch (error) {
      console.error(`Failed to decode Google Authenticator migration: ${JSON.stringify(error)}`);
      return [];
    }
  }

  private static decodePayload(data: string): Uint8Array {
    let normalized = data.replace(/ /g, '+').replace(/-/g, '+').replace(/_/g, '/');
    while (normalized.length % 4 !== 0) {
      normalized += '=';
    }
    return new util.Base64Helper().decodeSync(normalized, util.Type.BASIC);
  }

  private static parsePayload(payload: Uint8Array): GoogleOtpParameter[] {
    const records: GoogleOtpParameter[] = [];
    const reader = new ProtoReader(payload);
    while (reader.hasRemaining()) {
      const tag = reader.readVarint();
      const field = Math.floor(tag / 8);
      const wireType = tag & 7;
      if (field === 1 && wireType === 2) {
        const record = GoogleAuthenticatorMigration.parseParameter(reader.readBytes());
        if (record.secret.length > 0 && record.algorithm.length > 0) {
          records.push(record);
        }
      } else {
        reader.skip(wireType);
      }
    }
    return records;
  }

  private static parseParameter(payload: Uint8Array): GoogleOtpParameter {
    let secret = '';
    let name = '';
    let issuer = '';
    let algorithm = 'SHA1';
    let digits = 6;
    let type = 'TOTP';
    let counter = 0;
    const reader = new ProtoReader(payload);
    while (reader.hasRemaining()) {
      const tag = reader.readVarint();
      const field = Math.floor(tag / 8);
      const wireType = tag & 7;
      if (field === 1 && wireType === 2) {
        secret = GoogleAuthenticatorMigration.base32(reader.readBytes());
      } else if (field === 2 && wireType === 2) {
        name = GoogleAuthenticatorMigration.text(reader.readBytes());
      } else if (field === 3 && wireType === 2) {
        issuer = GoogleAuthenticatorMigration.text(reader.readBytes());
      } else if (field === 4 && wireType === 0) {
        algorithm = GoogleAuthenticatorMigration.algorithm(reader.readVarint());
      } else if (field === 5 && wireType === 0) {
        digits = reader.readVarint() === 2 ? 8 : 6;
      } else if (field === 6 && wireType === 0) {
        type = reader.readVarint() === 1 ? 'HOTP' : 'TOTP';
      } else if (field === 7 && wireType === 0) {
        counter = reader.readVarint();
      } else {
        reader.skip(wireType);
      }
    }
    return { secret, name, issuer, algorithm, digits, type, counter };
  }

  private static queryValue(query: string, key: string): string {
    for (const pair of query.split('&')) {
      const equalIndex = pair.indexOf('=');
      const rawKey = equalIndex >= 0 ? pair.substring(0, equalIndex) : pair;
      if (GoogleAuthenticatorMigration.decode(rawKey) === key) {
        return GoogleAuthenticatorMigration.decode(equalIndex >= 0 ? pair.substring(equalIndex + 1) : '');
      }
    }
    return '';
  }

  private static decode(value: string): string {
    try {
      return decodeURIComponent(value);
    } catch (error) {
      return value;
    }
  }

  private static text(bytes: Uint8Array): string {
    return new util.TextDecoder('utf-8').decodeToString(bytes);
  }

  private static algorithm(value: number): string {
    if (value === 2) {
      return 'SHA256';
    }
    if (value === 3) {
      return 'SHA512';
    }
    if (value === 4) {
      return '';
    }
    return 'SHA1';
  }

  private static base32(bytes: Uint8Array): string {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    let result = '';
    let buffer = 0;
    let bits = 0;
    for (let index = 0; index < bytes.length; index++) {
      buffer = (buffer << 8) | bytes[index];
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        result += alphabet.charAt((buffer >> bits) & 31);
      }
      if (bits > 0) {
        buffer &= (1 << bits) - 1;
      } else {
        buffer = 0;
      }
    }
    if (bits > 0) {
      result += alphabet.charAt((buffer << (5 - bits)) & 31);
    }
    return result;
  }
}
