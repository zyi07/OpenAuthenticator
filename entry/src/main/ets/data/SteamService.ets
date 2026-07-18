import { util } from '@kit.ArkTS';
import { systemDateTime } from '@kit.BasicServicesKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { http } from '@kit.NetworkKit';
import { SteamConfirmation, SteamGuardData } from '../model/SteamGuardData';

export interface SteamNetworkOptions {
  enhancedAccess: boolean;
  gatewayUrl: string;
  gatewayToken: string;
}

interface SteamAccessTokenResponse {
  access_token: string;
}

interface SteamAccessTokenEnvelope {
  response: SteamAccessTokenResponse;
}

interface SteamConfirmationEnvelope {
  success: boolean;
  message: string;
  conf: SteamConfirmation[];
}

export class SteamService {
  private options: SteamNetworkOptions;

  constructor(options: SteamNetworkOptions) {
    this.options = options;
  }

  async approveQrLogin(data: SteamGuardData, challengeUrl: string, persistent: boolean): Promise<void> {
    const match = /^https:\/\/s\.team\/q\/(\d+)\/(\d+)(?:\?|$)/.exec(challengeUrl.trim());
    if (!match || match.length < 3) {
      throw new Error('无效的 Steam 登录二维码');
    }
    const version = match[1];
    const clientId = match[2];
    const signature = this.qrSignature(data.sharedSecret, data.steamId, version, clientId);
    const body = 'steamid=' + encodeURIComponent(data.steamId) + '&confirm=true&persistence=' +
      (persistent ? '1' : '0') + '&version=' + version + '&client_id=' + clientId +
      '&signature=' + encodeURIComponent(signature);
    const token = await this.accessToken(data);
    await this.request(
      'https://api.steampowered.com/IAuthenticationService/UpdateAuthSessionWithMobileConfirmation/v1/' +
      '?access_token=' + encodeURIComponent(token),
      http.RequestMethod.POST,
      body,
      ''
    );
  }

  async confirmations(data: SteamGuardData): Promise<SteamConfirmation[]> {
    if (data.identitySecret.length === 0 || data.deviceId.length === 0) {
      throw new Error('迁移数据缺少 identity_secret 或 device_id');
    }
    const seconds = Math.floor(systemDateTime.getTime(false) / 1000);
    const tag = 'conf';
    const signature = this.confirmationSignature(data.identitySecret, seconds, tag);
    const query = 'p=' + encodeURIComponent(data.deviceId) + '&a=' + data.steamId + '&t=' +
      seconds.toString() + '&m=react&tag=' + tag + '&k=' + encodeURIComponent(signature);
    const token = await this.accessToken(data);
    const body = await this.request(
      'https://steamcommunity.com/mobileconf/getlist?' + query,
      http.RequestMethod.GET,
      '',
      'dob=;steamid=' + data.steamId + ';steamLoginSecure=' + data.steamId + '||' + token
    );
    const envelope: SteamConfirmationEnvelope = JSON.parse(body);
    if (!envelope.success) {
      throw new Error(envelope.message || 'Steam 确认列表获取失败');
    }
    return envelope.conf || [];
  }

  async respond(data: SteamGuardData, confirmations: SteamConfirmation[], allow: boolean): Promise<void> {
    if (confirmations.length === 0) {
      return;
    }
    const seconds = Math.floor(systemDateTime.getTime(false) / 1000);
    const tag = 'conf';
    const signature = this.confirmationSignature(data.identitySecret, seconds, tag);
    let body = 'p=' + encodeURIComponent(data.deviceId) + '&a=' + data.steamId + '&t=' +
      seconds.toString() + '&m=react&tag=' + tag + '&k=' + encodeURIComponent(signature) +
      '&op=' + (allow ? 'allow' : 'cancel');
    for (let index = 0; index < confirmations.length; index++) {
      body += '&cid[]=' + encodeURIComponent(confirmations[index].id) +
        '&ck[]=' + encodeURIComponent(confirmations[index].nonce);
    }
    const token = await this.accessToken(data);
    await this.request(
      'https://steamcommunity.com/mobileconf/multiajaxop',
      http.RequestMethod.POST,
      body,
      'dob=;steamid=' + data.steamId + ';steamLoginSecure=' + data.steamId + '||' + token
    );
  }

  private async accessToken(data: SteamGuardData): Promise<string> {
    if (data.accessToken.length > 0) {
      return data.accessToken;
    }
    if (data.refreshToken.length === 0) {
      throw new Error('迁移数据缺少 Steam 访问令牌');
    }
    const body = 'refresh_token=' + encodeURIComponent(data.refreshToken) + '&steamid=' +
      encodeURIComponent(data.steamId) + '&renewal_type=0';
    const responseText = await this.request(
      'https://api.steampowered.com/IAuthenticationService/GenerateAccessTokenForApp/v1/',
      http.RequestMethod.POST,
      body,
      ''
    );
    const envelope: SteamAccessTokenEnvelope = JSON.parse(responseText);
    if (!envelope.response || !envelope.response.access_token) {
      throw new Error('Steam 访问令牌刷新失败');
    }
    return envelope.response.access_token;
  }

  private async request(originalUrl: string, method: http.RequestMethod, body: string, cookie: string): Promise<string> {
    const client = http.createHttp();
    let targetUrl = originalUrl;
    const headers: Record<string, string> = { 'Content-Type': 'application/x-www-form-urlencoded' };
    if (cookie.length > 0) {
      headers['Cookie'] = cookie;
    }
    if (this.options.enhancedAccess && this.options.gatewayUrl.trim().length > 0) {
      targetUrl = this.gatewayTarget(originalUrl, this.options.gatewayUrl.trim());
      if (this.options.gatewayToken.length > 0) {
        headers['Proxy-Auth-Token'] = this.options.gatewayToken;
      }
    }
    try {
      const response = await client.request(targetUrl, {
        method: method,
        header: headers,
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 20000
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error('Steam 请求失败（HTTP ' + response.responseCode.toString() + '）');
      }
      return typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
    } finally {
      client.destroy();
    }
  }

  private gatewayTarget(originalUrl: string, gatewayUrl: string): string {
    const schemeIndex = originalUrl.indexOf('://');
    const pathIndex = schemeIndex >= 0 ? originalUrl.indexOf('/', schemeIndex + 3) : -1;
    const path = pathIndex >= 0 ? originalUrl.substring(pathIndex) : '/';
    return gatewayUrl.replace(/\/$/, '') + path;
  }

  private qrSignature(secret: string, steamId: string, version: string, clientId: string): string {
    const helper = new util.Base64Helper();
    const keyData = helper.decodeSync(secret);
    const mac = cryptoFramework.createMac('SHA256');
    const key = cryptoFramework.createSymKeyGenerator('HMAC').convertKeySync({ data: keyData });
    mac.initSync(key);
    mac.updateSync({ data: this.littleEndian(BigInt(version), 2) });
    mac.updateSync({ data: this.littleEndian(BigInt(clientId), 8) });
    mac.updateSync({ data: this.littleEndian(BigInt(steamId), 8) });
    return helper.encodeToStringSync(mac.doFinalSync().data);
  }

  private confirmationSignature(secret: string, seconds: number, tag: string): string {
    const helper = new util.Base64Helper();
    const mac = cryptoFramework.createMac('SHA1');
    const key = cryptoFramework.createSymKeyGenerator('HMAC').convertKeySync({ data: helper.decodeSync(secret) });
    mac.initSync(key);
    mac.updateSync({ data: this.bigEndian(seconds) });
    mac.updateSync({ data: new util.TextEncoder().encodeInto(tag) });
    return helper.encodeToStringSync(mac.doFinalSync().data);
  }

  private littleEndian(value: bigint, length: number): Uint8Array {
    const bytes = new Uint8Array(length);
    let current = value;
    for (let index = 0; index < length; index++) {
      bytes[index] = Number(current % 256n);
      current /= 256n;
    }
    return bytes;
  }

  private bigEndian(value: number): Uint8Array {
    const bytes = new Uint8Array(8);
    let current = Math.floor(value);
    for (let index = 7; index >= 0; index--) {
      bytes[index] = current & 0xff;
      current = Math.floor(current / 256);
    }
    return bytes;
  }
}
