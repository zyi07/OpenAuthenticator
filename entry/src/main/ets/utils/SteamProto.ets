import { util } from '@kit.ArkTS';

export interface SteamAllowedConfirmation {
  type: number;
  message: string;
}

export interface SteamBeginAuthResponse {
  clientId: string;
  requestId: Uint8Array;
  allowedConfirmations: SteamAllowedConfirmation[];
  steamId: string;
  weakToken: string;
  extendedErrorMessage: string;
}

export interface SteamPollAuthResponse {
  refreshToken: string;
  accessToken: string;
  accountName: string;
}

export interface SteamAddAuthenticatorResponse {
  sharedSecret: string;
  serialNumber: string;
  revocationCode: string;
  uri: string;
  serverTime: number;
  accountName: string;
  tokenGid: string;
  identitySecret: string;
  secret1: string;
  status: number;
  phoneNumberHint: string;
  confirmType: number;
}

export interface SteamFinalizeAuthenticatorResponse {
  success: boolean;
  wantMore: boolean;
  serverTime: number;
  status: number;
}

export interface SteamTimeResponse {
  serverTime: number;
}

export class SteamProto {
  static queryTimeRequest(senderTime: number): Uint8Array {
    const writer = new ProtoWriter();
    writer.uint64(1, BigInt(senderTime));
    return writer.finish();
  }

  static decodeQueryTime(data: Uint8Array): SteamTimeResponse {
    const reader = new ProtoReader(data);
    let serverTime = 0;
    while (!reader.finished()) {
      const tag = reader.tag();
      if (tag.field === 1) {
        serverTime = Number(reader.varint());
      } else {
        reader.skip(tag.wire);
      }
    }
    return { serverTime: serverTime };
  }

  static beginAuthRequest(
    accountName: string,
    encryptedPassword: string,
    encryptionTimestamp: string
  ): Uint8Array {
    const device = new ProtoWriter();
    device.string(1, 'Tool 2FA');
    device.uint64(2, 3n);
    device.int32(3, -500);
    device.uint64(4, 528n);

    const writer = new ProtoWriter();
    writer.string(1, 'Tool 2FA');
    writer.string(2, accountName);
    writer.string(3, encryptedPassword);
    writer.uint64(4, BigInt(encryptionTimestamp));
    writer.uint64(6, 3n);
    writer.uint64(7, 1n);
    writer.message(9, device.finish());
    writer.uint64(11, 0n);
    writer.uint64(12, 2n);
    return writer.finish();
  }

  static decodeBeginAuth(data: Uint8Array): SteamBeginAuthResponse {
    const reader = new ProtoReader(data);
    const confirmations: SteamAllowedConfirmation[] = [];
    let clientId = '';
    let requestId = new Uint8Array();
    let steamId = '';
    let weakToken = '';
    let extendedErrorMessage = '';
    while (!reader.finished()) {
      const tag = reader.tag();
      if (tag.field === 1) {
        clientId = reader.varint().toString();
      } else if (tag.field === 2) {
        requestId = reader.bytes();
      } else if (tag.field === 4) {
        confirmations.push(SteamProto.decodeAllowedConfirmation(reader.bytes()));
      } else if (tag.field === 5) {
        steamId = reader.varint().toString();
      } else if (tag.field === 6) {
        weakToken = reader.string();
      } else if (tag.field === 8) {
        extendedErrorMessage = reader.string();
      } else {
        reader.skip(tag.wire);
      }
    }
    return {
      clientId: clientId,
      requestId: requestId,
      allowedConfirmations: confirmations,
      steamId: steamId,
      weakToken: weakToken,
      extendedErrorMessage: extendedErrorMessage
    };
  }

  static updateGuardCodeRequest(clientId: string, steamId: string, code: string, codeType: number): Uint8Array {
    const writer = new ProtoWriter();
    writer.uint64(1, BigInt(clientId));
    writer.fixed64(2, BigInt(steamId));
    writer.string(3, code);
    writer.uint64(4, BigInt(codeType));
    return writer.finish();
  }

  static pollAuthRequest(clientId: string, requestId: Uint8Array): Uint8Array {
    const writer = new ProtoWriter();
    writer.uint64(1, BigInt(clientId));
    writer.bytes(2, requestId);
    return writer.finish();
  }

  static decodePollAuth(data: Uint8Array): SteamPollAuthResponse {
    const reader = new ProtoReader(data);
    let refreshToken = '';
    let accessToken = '';
    let accountName = '';
    while (!reader.finished()) {
      const tag = reader.tag();
      if (tag.field === 3) {
        refreshToken = reader.string();
      } else if (tag.field === 4) {
        accessToken = reader.string();
      } else if (tag.field === 6) {
        accountName = reader.string();
      } else {
        reader.skip(tag.wire);
      }
    }
    return { refreshToken: refreshToken, accessToken: accessToken, accountName: accountName };
  }

  static addAuthenticatorRequest(steamId: string, deviceId: string, authenticatorTime: number): Uint8Array {
    const writer = new ProtoWriter();
    writer.fixed64(1, BigInt(steamId));
    writer.uint64(2, BigInt(authenticatorTime));
    writer.uint64(4, 1n);
    writer.string(5, deviceId);
    writer.uint64(8, 1n);
    return writer.finish();
  }

  static decodeAddAuthenticator(data: Uint8Array): SteamAddAuthenticatorResponse {
    const reader = new ProtoReader(data);
    const helper = new util.Base64Helper();
    let sharedSecret = '';
    let serialNumber = '';
    let revocationCode = '';
    let uri = '';
    let serverTime = 0;
    let accountName = '';
    let tokenGid = '';
    let identitySecret = '';
    let secret1 = '';
    let status = 0;
    let phoneNumberHint = '';
    let confirmType = 0;
    while (!reader.finished()) {
      const tag = reader.tag();
      if (tag.field === 1) {
        sharedSecret = helper.encodeToStringSync(reader.bytes());
      } else if (tag.field === 2) {
        serialNumber = reader.fixed64().toString();
      } else if (tag.field === 3) {
        revocationCode = reader.string();
      } else if (tag.field === 4) {
        uri = reader.string();
      } else if (tag.field === 5) {
        serverTime = Number(reader.varint());
      } else if (tag.field === 6) {
        accountName = reader.string();
      } else if (tag.field === 7) {
        tokenGid = reader.string();
      } else if (tag.field === 8) {
        identitySecret = helper.encodeToStringSync(reader.bytes());
      } else if (tag.field === 9) {
        secret1 = helper.encodeToStringSync(reader.bytes());
      } else if (tag.field === 10) {
        status = Number(reader.varint());
      } else if (tag.field === 11) {
        phoneNumberHint = reader.string();
      } else if (tag.field === 12) {
        confirmType = Number(reader.varint());
      } else {
        reader.skip(tag.wire);
      }
    }
    return {
      sharedSecret: sharedSecret,
      serialNumber: serialNumber,
      revocationCode: revocationCode,
      uri: uri,
      serverTime: serverTime,
      accountName: accountName,
      tokenGid: tokenGid,
      identitySecret: identitySecret,
      secret1: secret1,
      status: status,
      phoneNumberHint: phoneNumberHint,
      confirmType: confirmType
    };
  }

  static finalizeAuthenticatorRequest(
    steamId: string,
    authenticatorCode: string,
    authenticatorTime: number,
    activationCode: string
  ): Uint8Array {
    const writer = new ProtoWriter();
    writer.fixed64(1, BigInt(steamId));
    writer.string(2, authenticatorCode);
    writer.uint64(3, BigInt(authenticatorTime));
    writer.string(4, activationCode);
    writer.boolean(6, true);
    return writer.finish();
  }

  static decodeFinalizeAuthenticator(data: Uint8Array): SteamFinalizeAuthenticatorResponse {
    const reader = new ProtoReader(data);
    let success = false;
    let wantMore = false;
    let serverTime = 0;
    let status = 0;
    while (!reader.finished()) {
      const tag = reader.tag();
      if (tag.field === 1) {
        success = reader.varint() !== 0n;
      } else if (tag.field === 2) {
        wantMore = reader.varint() !== 0n;
      } else if (tag.field === 3) {
        serverTime = Number(reader.varint());
      } else if (tag.field === 4) {
        status = Number(reader.varint());
      } else {
        reader.skip(tag.wire);
      }
    }
    return { success: success, wantMore: wantMore, serverTime: serverTime, status: status };
  }

  private static decodeAllowedConfirmation(data: Uint8Array): SteamAllowedConfirmation {
    const reader = new ProtoReader(data);
    let type = 0;
    let message = '';
    while (!reader.finished()) {
      const tag = reader.tag();
      if (tag.field === 1) {
        type = Number(reader.varint());
      } else if (tag.field === 2) {
        message = reader.string();
      } else {
        reader.skip(tag.wire);
      }
    }
    return { type: type, message: message };
  }
}

interface ProtoTag {
  field: number;
  wire: number;
}

class ProtoWriter {
  private data: number[] = [];

  string(field: number, value: string): void {
    if (value.length === 0) {
      return;
    }
    this.bytes(field, new util.TextEncoder().encodeInto(value));
  }

  bytes(field: number, value: Uint8Array): void {
    this.writeTag(field, 2);
    this.writeVarint(BigInt(value.length));
    for (let index = 0; index < value.length; index++) {
      this.data.push(value[index]);
    }
  }

  message(field: number, value: Uint8Array): void {
    this.bytes(field, value);
  }

  uint64(field: number, value: bigint): void {
    this.writeTag(field, 0);
    this.writeVarint(value);
  }

  int32(field: number, value: number): void {
    this.writeTag(field, 0);
    const encoded = value < 0 ? (1n << 64n) + BigInt(value) : BigInt(value);
    this.writeVarint(encoded);
  }

  fixed64(field: number, value: bigint): void {
    this.writeTag(field, 1);
    let current = value;
    for (let index = 0; index < 8; index++) {
      this.data.push(Number(current & 255n));
      current >>= 8n;
    }
  }

  boolean(field: number, value: boolean): void {
    this.uint64(field, value ? 1n : 0n);
  }

  finish(): Uint8Array {
    return new Uint8Array(this.data);
  }

  private writeTag(field: number, wire: number): void {
    this.writeVarint(BigInt(field * 8 + wire));
  }

  private writeVarint(value: bigint): void {
    let current = value;
    while (current >= 128n) {
      this.data.push(Number(current & 127n) | 128);
      current >>= 7n;
    }
    this.data.push(Number(current));
  }
}

class ProtoReader {
  private data: Uint8Array;
  private position: number = 0;

  constructor(data: Uint8Array) {
    this.data = data;
  }

  finished(): boolean {
    return this.position >= this.data.length;
  }

  tag(): ProtoTag {
    const value = Number(this.varint());
    return { field: Math.floor(value / 8), wire: value % 8 };
  }

  varint(): bigint {
    let result = 0n;
    let shift = 0n;
    while (this.position < this.data.length) {
      const value = this.data[this.position++];
      result |= BigInt(value & 127) << shift;
      if ((value & 128) === 0) {
        return result;
      }
      shift += 7n;
      if (shift > 70n) {
        throw new Error('Steam protobuf varint 无效');
      }
    }
    throw new Error('Steam protobuf 数据不完整');
  }

  fixed64(): bigint {
    this.require(8);
    let result = 0n;
    for (let index = 0; index < 8; index++) {
      result |= BigInt(this.data[this.position++]) << BigInt(index * 8);
    }
    return result;
  }

  bytes(): Uint8Array {
    const length = Number(this.varint());
    this.require(length);
    const value = this.data.slice(this.position, this.position + length);
    this.position += length;
    return value;
  }

  string(): string {
    return util.TextDecoder.create('utf-8').decodeToString(this.bytes());
  }

  skip(wire: number): void {
    if (wire === 0) {
      this.varint();
    } else if (wire === 1) {
      this.require(8);
      this.position += 8;
    } else if (wire === 2) {
      const length = Number(this.varint());
      this.require(length);
      this.position += length;
    } else if (wire === 5) {
      this.require(4);
      this.position += 4;
    } else {
      throw new Error('Steam protobuf wire type 不受支持');
    }
  }

  private require(length: number): void {
    if (length < 0 || this.position + length > this.data.length) {
      throw new Error('Steam protobuf 数据不完整');
    }
  }
}
