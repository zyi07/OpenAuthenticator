import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { connection, mdns, socket } from '@kit.NetworkKit';
import { TokenRecord } from '../model/TokenRecord';

const LAN_SYNC_ACTION: string = 'tool2fa.watch.tokens.replace';
const LAN_SYNC_PROTOCOL_VERSION: number = 1;
const LAN_SYNC_SERVICE_TYPE: string = '_openauth._tcp';
const LAN_SYNC_SERVICE_PREFIX: string = 'OpenAuthenticator-';
const LAN_SYNC_PAIRING_PREFIX: string = 'openauth-sync://watch?v=1';
const LAN_SYNC_AAD_PREFIX: string = 'OpenAuthenticator/watch-sync/v1/';
const LAN_SYNC_SESSION_MS: number = 2 * 60 * 1000;
const LAN_SYNC_DISCOVERY_TIMEOUT_MS: number = 12 * 1000;
const LAN_SYNC_DIRECT_CONNECT_TIMEOUT_MS: number = 4 * 1000;
const LAN_SYNC_RESPONSE_TIMEOUT_MS: number = 10 * 1000;
const LAN_SYNC_RECEIVE_TIMEOUT_MS: number = 10 * 1000;
const LAN_SYNC_MAX_MESSAGE_BYTES: number = 1024 * 1024;
const LAN_SYNC_MAX_TOKEN_COUNT: number = 2000;

interface LanWatchPairingPayload {
  version: number;
  sessionId: string;
  key: Uint8Array;
  expiresAt: number;
  host: string;
  port: number;
}

interface LanWatchEncryptedEnvelope {
  version: number;
  sessionId: string;
  iv: string;
  ciphertext: string;
  authTag: string;
}

interface LanWatchTransferPayload {
  action: string;
  version: number;
  tokens: TokenRecord[];
  sentAt: number;
}

interface LanWatchAckPayload {
  ok: boolean;
  count: number;
}

interface LanWatchLineWaiter {
  result: Promise<string>;
  cancel: () => void;
}

export interface LanWatchPairingInfo {
  qrText: string;
  expiresAt: number;
}

export enum LanWatchReceiverState {
  Waiting,
  Receiving,
  Success,
  InvalidData,
  Expired,
  Failed
}

export function watchTransferRecords(records: TokenRecord[]): TokenRecord[] {
  return records.map((record: TokenRecord): TokenRecord => {
    return {
      id: record.id,
      name: record.name,
      remark: record.remark,
      type: record.type,
      algorithm: record.algorithm,
      secret: record.secret,
      logoUri: '',
      logoLightUri: '',
      logoDarkUri: '',
      logoSource: record.logoSource === 'manual' ? '' : record.logoSource,
      digits: record.digits,
      period: record.period,
      counter: record.counter,
      createdAt: record.createdAt,
      modifiedTime: record.modifiedTime
    };
  });
}

export class LanWatchReceiver {
  private context: common.UIAbilityContext | undefined = undefined;
  private receiveTokensCallback: ((records: TokenRecord[]) => Promise<boolean>) | undefined = undefined;
  private stateChangedCallback: ((state: LanWatchReceiverState) => void) | undefined = undefined;
  private server: socket.TCPSocketServer | undefined = undefined;
  private connection: socket.TCPSocketConnection | undefined = undefined;
  private serviceInfo: mdns.LocalServiceInfo | undefined = undefined;
  private sessionId: string = '';
  private sessionKey: Uint8Array = new Uint8Array(0);
  private expiresAt: number = 0;
  private expiryTimer: number = -1;
  private active: boolean = false;
  private processing: boolean = false;

  async start(
    context: common.UIAbilityContext,
    receiveTokens: (records: TokenRecord[]) => Promise<boolean>,
    stateChanged: (state: LanWatchReceiverState) => void
  ): Promise<LanWatchPairingInfo> {
    await this.stop();

    this.context = context;
    this.receiveTokensCallback = receiveTokens;
    this.stateChangedCallback = stateChanged;
    this.sessionId = randomHex(24);
    this.sessionKey = cryptoFramework.createRandom().generateRandomSync(32).data;
    this.expiresAt = Date.now() + LAN_SYNC_SESSION_MS;
    this.active = true;
    this.processing = false;

    const server = socket.constructTCPSocketServerInstance();
    this.server = server;
    const activeSessionId = this.sessionId;
    server.on('connect', (connection: socket.TCPSocketConnection): void => {
      if (!this.active || this.sessionId !== activeSessionId) {
        connection.close().catch((): void => {
        });
        return;
      }
      this.handleConnection(connection, activeSessionId);
    });
    server.on('error', (error: BusinessError): void => {
      if (this.active && this.sessionId === activeSessionId) {
        this.notifyState(LanWatchReceiverState.Failed);
        this.stop();
      }
    });

    try {
      await server.listen({
        address: '0.0.0.0',
        family: 1,
        port: 0
      });
      const address = await server.getLocalAddress();
      if (!address.port || address.port <= 0) {
        throw new Error('LAN_SYNC_PORT_UNAVAILABLE');
      }
      const localAddress = await getLocalLanAddress();
      console.info('LAN watch direct endpoint available: ' + (localAddress.length > 0).toString());
      const requestedService: mdns.LocalServiceInfo = {
        serviceType: LAN_SYNC_SERVICE_TYPE,
        serviceName: LAN_SYNC_SERVICE_PREFIX + this.sessionId,
        port: address.port
      };
      this.serviceInfo = await mdns.addLocalService(context, requestedService);
      this.expiryTimer = setTimeout((): void => {
        if (this.active && this.sessionId === activeSessionId) {
          this.notifyState(LanWatchReceiverState.Expired);
          this.stop();
        }
      }, LAN_SYNC_SESSION_MS);
      this.notifyState(LanWatchReceiverState.Waiting);
      return {
        qrText: pairingText(this.sessionId, this.sessionKey, this.expiresAt, localAddress, address.port),
        expiresAt: this.expiresAt
      };
    } catch (error) {
      this.notifyState(LanWatchReceiverState.Failed);
      await this.stop();
      throw new Error('LAN_SYNC_START_FAILED');
    }
  }

  async stop(): Promise<void> {
    this.active = false;
    this.processing = false;
    if (this.expiryTimer >= 0) {
      clearTimeout(this.expiryTimer);
      this.expiryTimer = -1;
    }

    const connection = this.connection;
    this.connection = undefined;
    if (connection) {
      try {
        await connection.close();
      } catch (error) {
      }
    }

    const context = this.context;
    const serviceInfo = this.serviceInfo;
    this.serviceInfo = undefined;
    if (context && serviceInfo) {
      try {
        await mdns.removeLocalService(context, serviceInfo);
      } catch (error) {
      }
    }

    const server = this.server;
    this.server = undefined;
    if (server) {
      try {
        await server.close();
      } catch (error) {
      }
    }

    this.context = undefined;
    this.receiveTokensCallback = undefined;
    this.stateChangedCallback = undefined;
    this.sessionId = '';
    this.sessionKey = new Uint8Array(0);
    this.expiresAt = 0;
  }

  private handleConnection(connection: socket.TCPSocketConnection, activeSessionId: string): void {
    if (this.processing) {
      connection.close().catch((): void => {
      });
      return;
    }
    this.processing = true;
    this.connection = connection;
    this.notifyState(LanWatchReceiverState.Receiving);
    let received = '';
    let handled = false;
    const receiveTimer = setTimeout((): void => {
      if (!handled && this.active && this.sessionId === activeSessionId) {
        handled = true;
        this.rejectConnection(connection);
      }
    }, LAN_SYNC_RECEIVE_TIMEOUT_MS);

    connection.on('message', (info: socket.SocketMessageInfo): void => {
      if (handled || !this.active || this.sessionId !== activeSessionId) {
        return;
      }
      received += util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(info.message));
      if (received.length > LAN_SYNC_MAX_MESSAGE_BYTES) {
        handled = true;
        clearTimeout(receiveTimer);
        this.rejectConnection(connection);
        return;
      }
      const lineEnd = received.indexOf('\n');
      if (lineEnd < 0) {
        return;
      }
      handled = true;
      clearTimeout(receiveTimer);
      const line = received.substring(0, lineEnd);
      this.processMessage(connection, line, activeSessionId);
    });
    connection.on('close', (): void => {
      clearTimeout(receiveTimer);
      if (!handled && this.active && this.sessionId === activeSessionId) {
        this.processing = false;
        this.connection = undefined;
        this.notifyState(LanWatchReceiverState.Waiting);
      }
    });
    connection.on('error', (error: BusinessError): void => {
      clearTimeout(receiveTimer);
      if (!handled && this.active && this.sessionId === activeSessionId) {
        handled = true;
        this.rejectConnection(connection);
      }
    });
  }

  private async processMessage(
    connection: socket.TCPSocketConnection,
    line: string,
    activeSessionId: string
  ): Promise<void> {
    try {
      if (!this.active || this.sessionId !== activeSessionId || Date.now() > this.expiresAt) {
        throw new Error('LAN_SYNC_SESSION_EXPIRED');
      }
      const plaintext = decryptEnvelope(line, this.sessionId, this.sessionKey);
      const payload: LanWatchTransferPayload = JSON.parse(plaintext);
      if (payload.action !== LAN_SYNC_ACTION || payload.version !== LAN_SYNC_PROTOCOL_VERSION ||
        !Array.isArray(payload.tokens) || payload.tokens.length === 0 ||
        payload.tokens.length > LAN_SYNC_MAX_TOKEN_COUNT) {
        throw new Error('LAN_SYNC_INVALID_PAYLOAD');
      }
      const receiveTokens = this.receiveTokensCallback;
      if (!receiveTokens || !await receiveTokens(payload.tokens)) {
        throw new Error('LAN_SYNC_PERSIST_FAILED');
      }

      const ack: LanWatchAckPayload = {
        ok: true,
        count: payload.tokens.length
      };
      const ackLine = encryptEnvelope(JSON.stringify(ack), this.sessionId, this.sessionKey) + '\n';
      await connection.send({ data: ackLine, encoding: 'utf-8' });
      this.notifyState(LanWatchReceiverState.Success);
      try {
        await connection.close();
      } catch (error) {
      }
      this.connection = undefined;
      await this.stop();
    } catch (error) {
      if (this.active && this.sessionId === activeSessionId) {
        this.rejectConnection(connection);
      }
    }
  }

  private rejectConnection(connection: socket.TCPSocketConnection): void {
    this.notifyState(LanWatchReceiverState.InvalidData);
    this.processing = false;
    if (this.connection === connection) {
      this.connection = undefined;
    }
    connection.close().catch((): void => {
    });
  }

  private notifyState(state: LanWatchReceiverState): void {
    const callback = this.stateChangedCallback;
    if (callback) {
      callback(state);
    }
  }
}

export class LanWatchSender {
  static async push(
    context: common.UIAbilityContext,
    scannedText: string,
    records: TokenRecord[]
  ): Promise<number> {
    const pairing = parsePairingText(scannedText);
    if (Date.now() > pairing.expiresAt) {
      throw new Error('LAN_SYNC_SESSION_EXPIRED');
    }
    if (records.length === 0 || records.length > LAN_SYNC_MAX_TOKEN_COUNT) {
      throw new Error('LAN_SYNC_INVALID_TOKEN_COUNT');
    }

    const directAddress = pairingAddress(pairing);
    if (directAddress !== undefined) {
      try {
        return await LanWatchSender.pushToAddress(
          directAddress,
          pairing,
          records,
          LAN_SYNC_DIRECT_CONNECT_TIMEOUT_MS
        );
      } catch (error) {
      }
    }

    const service = await discoverService(context, pairing.sessionId);
    if (!service.host || !service.host.address || !service.port) {
      throw new Error('LAN_SYNC_SERVICE_UNAVAILABLE');
    }
    const discoveredAddress: socket.NetAddress = {
      address: service.host.address,
      family: service.host.family,
      port: service.port
    };
    return await LanWatchSender.pushToAddress(
      discoveredAddress,
      pairing,
      records,
      LAN_SYNC_RESPONSE_TIMEOUT_MS
    );
  }

  private static async pushToAddress(
    targetAddress: socket.NetAddress,
    pairing: LanWatchPairingPayload,
    records: TokenRecord[],
    connectTimeoutMs: number
  ): Promise<number> {
    const client = socket.constructTCPSocketInstance();
    let responseWaiter: LanWatchLineWaiter | undefined = undefined;
    try {
      const connectOptions: socket.TCPConnectOptions = {
        address: targetAddress,
        timeout: connectTimeoutMs
      };
      await client.connect(connectOptions);
      responseWaiter = createLineWaiter(client);
      const payload: LanWatchTransferPayload = {
        action: LAN_SYNC_ACTION,
        version: LAN_SYNC_PROTOCOL_VERSION,
        tokens: watchTransferRecords(records),
        sentAt: Date.now()
      };
      const line = encryptEnvelope(JSON.stringify(payload), pairing.sessionId, pairing.key) + '\n';
      if (line.length > LAN_SYNC_MAX_MESSAGE_BYTES) {
        throw new Error('LAN_SYNC_MESSAGE_TOO_LARGE');
      }
      await client.send({ data: line, encoding: 'utf-8' });
      const responseLine = await responseWaiter.result;
      const responseText = decryptEnvelope(responseLine, pairing.sessionId, pairing.key);
      const ack: LanWatchAckPayload = JSON.parse(responseText);
      if (!ack.ok || ack.count !== records.length) {
        throw new Error('LAN_SYNC_REJECTED');
      }
      return ack.count;
    } finally {
      if (responseWaiter) {
        responseWaiter.cancel();
        responseWaiter.result.catch((): void => {
        });
      }
      try {
        await client.close();
      } catch (error) {
      }
    }
  }
}

function pairingText(sessionId: string, key: Uint8Array, expiresAt: number, host: string, port: number): string {
  let text = LAN_SYNC_PAIRING_PREFIX + '&s=' + sessionId +
    '&k=' + base64UrlEncode(key) + '&e=' + expiresAt.toString();
  if (isPrivateIpv4(host) && isValidPort(port)) {
    text += '&h=' + host + '&p=' + port.toString();
  }
  return text;
}

function parsePairingText(scannedText: string): LanWatchPairingPayload {
  const trimmed = scannedText.trim();
  if (!trimmed.startsWith(LAN_SYNC_PAIRING_PREFIX + '&')) {
    throw new Error('LAN_SYNC_INVALID_PAIRING_CODE');
  }
  const parts = trimmed.substring(LAN_SYNC_PAIRING_PREFIX.length + 1).split('&');
  let sessionId = '';
  let keyText = '';
  let expiresText = '';
  let host = '';
  let portText = '';
  for (let index = 0; index < parts.length; index++) {
    const separator = parts[index].indexOf('=');
    if (separator <= 0) {
      continue;
    }
    const name = parts[index].substring(0, separator);
    const value = parts[index].substring(separator + 1);
    if (name === 's') {
      sessionId = value;
    } else if (name === 'k') {
      keyText = value;
    } else if (name === 'e') {
      expiresText = value;
    } else if (name === 'h') {
      host = value;
    } else if (name === 'p') {
      portText = value;
    }
  }
  const key = base64UrlDecode(keyText);
  const expiresAt = Number(expiresText);
  const port = Number(portText);
  if (!/^[a-f0-9]{24}$/.test(sessionId) || key.length !== 32 ||
    !Number.isFinite(expiresAt) || expiresAt <= 0) {
    throw new Error('LAN_SYNC_INVALID_PAIRING_CODE');
  }
  if ((host.length > 0 || portText.length > 0) && (!isPrivateIpv4(host) || !isValidPort(port))) {
    throw new Error('LAN_SYNC_INVALID_PAIRING_CODE');
  }
  return {
    version: LAN_SYNC_PROTOCOL_VERSION,
    sessionId: sessionId,
    key: key,
    expiresAt: expiresAt,
    host: host,
    port: isValidPort(port) ? port : 0
  };
}

function pairingAddress(pairing: LanWatchPairingPayload): socket.NetAddress | undefined {
  if (!isPrivateIpv4(pairing.host) || !isValidPort(pairing.port)) {
    return undefined;
  }
  const address: socket.NetAddress = {
    address: pairing.host,
    family: 1,
    port: pairing.port
  };
  return address;
}

async function getLocalLanAddress(): Promise<string> {
  try {
    const netHandle = await connection.getDefaultNet();
    const properties = await connection.getConnectionProperties(netHandle);
    for (let index = 0; index < properties.linkAddresses.length; index++) {
      const candidate = properties.linkAddresses[index].address.address;
      if (isPrivateIpv4(candidate)) {
        return candidate;
      }
    }
  } catch (error) {
  }
  return '';
}

function isValidPort(port: number): boolean {
  return Number.isInteger(port) && port > 0 && port <= 65535;
}

function isPrivateIpv4(address: string): boolean {
  const parts = address.split('.');
  if (parts.length !== 4) {
    return false;
  }
  const octets: number[] = [];
  for (let index = 0; index < parts.length; index++) {
    const octet = Number(parts[index]);
    if (!Number.isInteger(octet) || octet < 0 || octet > 255) {
      return false;
    }
    octets.push(octet);
  }
  if (octets[0] === 10 || (octets[0] === 192 && octets[1] === 168)) {
    return true;
  }
  if (octets[0] === 172 && octets[1] >= 16 && octets[1] <= 31) {
    return true;
  }
  return octets[0] === 169 && octets[1] === 254;
}

function encryptEnvelope(plaintext: string, sessionId: string, keyData: Uint8Array): string {
  const iv = cryptoFramework.createRandom().generateRandomSync(12).data;
  const aad = util.TextEncoder.create('utf-8').encodeInto(LAN_SYNC_AAD_PREFIX + sessionId);
  const params: cryptoFramework.GcmParamsSpec = {
    algName: 'GcmParamsSpec',
    iv: { data: iv },
    aad: { data: aad },
    authTag: { data: new Uint8Array(16) }
  };
  const key = cryptoFramework.createSymKeyGenerator('AES256').convertKeySync({ data: keyData });
  const cipher = cryptoFramework.createCipher('AES256|GCM|PKCS7');
  cipher.initSync(cryptoFramework.CryptoMode.ENCRYPT_MODE, key, params);
  const ciphertext = cipher.updateSync({
    data: util.TextEncoder.create('utf-8').encodeInto(plaintext)
  }).data;
  const authTag = cipher.doFinalSync(null).data;
  const envelope: LanWatchEncryptedEnvelope = {
    version: LAN_SYNC_PROTOCOL_VERSION,
    sessionId: sessionId,
    iv: base64UrlEncode(iv),
    ciphertext: base64UrlEncode(ciphertext),
    authTag: base64UrlEncode(authTag)
  };
  return JSON.stringify(envelope);
}

function decryptEnvelope(serialized: string, sessionId: string, keyData: Uint8Array): string {
  const envelope: LanWatchEncryptedEnvelope = JSON.parse(serialized);
  if (envelope.version !== LAN_SYNC_PROTOCOL_VERSION || envelope.sessionId !== sessionId) {
    throw new Error('LAN_SYNC_INVALID_ENVELOPE');
  }
  const iv = base64UrlDecode(envelope.iv);
  const ciphertext = base64UrlDecode(envelope.ciphertext);
  const authTag = base64UrlDecode(envelope.authTag);
  if (iv.length !== 12 || authTag.length !== 16 || ciphertext.length === 0) {
    throw new Error('LAN_SYNC_INVALID_ENVELOPE');
  }
  const aad = util.TextEncoder.create('utf-8').encodeInto(LAN_SYNC_AAD_PREFIX + sessionId);
  const params: cryptoFramework.GcmParamsSpec = {
    algName: 'GcmParamsSpec',
    iv: { data: iv },
    aad: { data: aad },
    authTag: { data: authTag }
  };
  const key = cryptoFramework.createSymKeyGenerator('AES256').convertKeySync({ data: keyData });
  const cipher = cryptoFramework.createCipher('AES256|GCM|PKCS7');
  cipher.initSync(cryptoFramework.CryptoMode.DECRYPT_MODE, key, params);
  const plaintext = cipher.updateSync({ data: ciphertext }).data;
  cipher.doFinalSync(null);
  return util.TextDecoder.create('utf-8').decodeToString(plaintext);
}

function discoverService(
  context: common.UIAbilityContext,
  sessionId: string
): Promise<mdns.LocalServiceInfo> {
  return new Promise<mdns.LocalServiceInfo>((resolve, reject): void => {
    const discovery = mdns.createDiscoveryService(context, LAN_SYNC_SERVICE_TYPE);
    const expectedName = LAN_SYNC_SERVICE_PREFIX + sessionId;
    let completed = false;
    const timer = setTimeout((): void => {
      if (completed) {
        return;
      }
      completed = true;
      cleanup();
      reject(new Error('LAN_SYNC_DISCOVERY_TIMEOUT'));
    }, LAN_SYNC_DISCOVERY_TIMEOUT_MS);

    const cleanup = (): void => {
      clearTimeout(timer);
      try {
        discovery.stopSearchingMDNS();
      } catch (error) {
      }
      discovery.off('serviceFound', serviceFound);
    };
    const serviceFound = (service: mdns.LocalServiceInfo): void => {
      if (completed || service.serviceName !== expectedName) {
        return;
      }
      mdns.resolveLocalService(context, service).then((resolved: mdns.LocalServiceInfo): void => {
        if (completed) {
          return;
        }
        completed = true;
        cleanup();
        resolve(resolved);
      }).catch((error: BusinessError): void => {
      });
    };

    discovery.on('serviceFound', serviceFound);
    try {
      discovery.startSearchingMDNS();
    } catch (error) {
      completed = true;
      cleanup();
      reject(error);
    }
  });
}

function createLineWaiter(client: socket.TCPSocket): LanWatchLineWaiter {
  let cancelWait = (): void => {
  };
  const result = new Promise<string>((resolve, reject): void => {
    let received = '';
    let completed = false;
    const timer = setTimeout((): void => {
      finishWithError(new Error('LAN_SYNC_RESPONSE_TIMEOUT'));
    }, LAN_SYNC_RESPONSE_TIMEOUT_MS);

    const cleanup = (): void => {
      clearTimeout(timer);
      client.off('message', messageReceived);
      client.off('error', socketError);
      client.off('close', socketClosed);
    };
    const finishWithError = (error: Error): void => {
      if (completed) {
        return;
      }
      completed = true;
      cleanup();
      reject(error);
    };
    cancelWait = (): void => {
      finishWithError(new Error('LAN_SYNC_WAIT_CANCELED'));
    };
    const messageReceived = (info: socket.SocketMessageInfo): void => {
      if (completed) {
        return;
      }
      received += util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(info.message));
      if (received.length > LAN_SYNC_MAX_MESSAGE_BYTES) {
        finishWithError(new Error('LAN_SYNC_MESSAGE_TOO_LARGE'));
        return;
      }
      const lineEnd = received.indexOf('\n');
      if (lineEnd >= 0) {
        completed = true;
        const line = received.substring(0, lineEnd);
        cleanup();
        resolve(line);
      }
    };
    const socketError = (error: BusinessError): void => {
      finishWithError(new Error('LAN_SYNC_CONNECTION_FAILED'));
    };
    const socketClosed = (): void => {
      finishWithError(new Error('LAN_SYNC_CONNECTION_CLOSED'));
    };

    client.on('message', messageReceived);
    client.on('error', socketError);
    client.on('close', socketClosed);
  });
  return {
    result: result,
    cancel: cancelWait
  };
}

function base64UrlEncode(data: Uint8Array): string {
  return new util.Base64Helper().encodeToStringSync(data, util.Type.BASIC_URL_SAFE);
}

function base64UrlDecode(value: string): Uint8Array {
  try {
    return new util.Base64Helper().decodeSync(value, util.Type.BASIC_URL_SAFE);
  } catch (error) {
    return new Uint8Array(0);
  }
}

function randomHex(length: number): string {
  const bytes = cryptoFramework.createRandom().generateRandomSync(Math.ceil(length / 2)).data;
  let value = '';
  for (let index = 0; index < bytes.length; index++) {
    value += bytes[index].toString(16).padStart(2, '0');
  }
  return value.substring(0, length);
}
