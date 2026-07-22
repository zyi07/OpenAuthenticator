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

interface SteamActionEnvelope {
  success: boolean;
  message: string;
}

interface SteamQrLoginInfoResponse {
  ip: string;
  geoloc: string;
  city: string;
  state: string;
  country: string;
  device_friendly_name: string;
  requested_persistence: number;
}

interface SteamQrLoginInfoEnvelope {
  response: SteamQrLoginInfoResponse;
}

export interface SteamQrLoginInfo {
  ip: string;
  location: string;
  deviceName: string;
  persistent: boolean;
}

export class SteamService {
  private options: SteamNetworkOptions;

  constructor(options: SteamNetworkOptions) {
    this.options = options;
  }

  async qrLoginInfo(data: SteamGuardData, challengeUrl: string): Promise<SteamQrLoginInfo> {
    const values = this.qrChallengeValues(challengeUrl);
    const token = await this.accessToken(data);
    const body = await this.request(
      'https://api.steampowered.com/IAuthenticationService/GetAuthSessionInfo/v1/' +
      '?access_token=' + encodeURIComponent(token),
      http.RequestMethod.POST,
      'client_id=' + values[1],
      ''
    );
    const envelope: SteamQrLoginInfoEnvelope = JSON.parse(body);
    if (!envelope.response) {
      throw new Error('无法获取 Steam 登录请求详情');
    }
    const response = envelope.response;
    return {
      ip: response.ip || '',
      location: this.qrLocation(response),
      deviceName: response.device_friendly_name || '',
      persistent: response.requested_persistence === 1
    };
  }

  async respondQrLogin(
    data: SteamGuardData,
    challengeUrl: string,
    persistent: boolean,
    confirm: boolean
  ): Promise<void> {
    const values = this.qrChallengeValues(challengeUrl);
    const version = values[0];
    const clientId = values[1];
    const signature = this.qrSignature(data.sharedSecret, data.steamId, version, clientId);
    const body = 'steamid=' + encodeURIComponent(data.steamId) + '&confirm=' + (confirm ? 'true' : 'false') +
      '&persistence=' +
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
      this.communityCookie(data, token)
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
    const tag = allow ? 'accept' : 'reject';
    const signature = this.confirmationSignature(data.identitySecret, seconds, tag);
    let body = 'p=' + encodeURIComponent(data.deviceId) + '&a=' + data.steamId + '&t=' +
      seconds.toString() + '&m=react&tag=' + tag + '&k=' + encodeURIComponent(signature) +
      '&op=' + (allow ? 'allow' : 'cancel');
    for (let index = 0; index < confirmations.length; index++) {
      body += '&cid[]=' + encodeURIComponent(confirmations[index].id) +
        '&ck[]=' + encodeURIComponent(confirmations[index].nonce);
    }
    const token = await this.accessToken(data);
    const responseText = await this.request(
      'https://steamcommunity.com/mobileconf/multiajaxop',
      http.RequestMethod.POST,
      body,
      this.communityCookie(data, token)
    );
    if (responseText.length > 0) {
      const envelope: SteamActionEnvelope = JSON.parse(responseText);
      if (!envelope.success) {
        throw new Error(envelope.message || 'Steam 确认操作失败');
      }
    }
  }

  private async accessToken(data: SteamGuardData): Promise<string> {
    if (data.accessToken.length > 0 && !this.isJwtExpired(data.accessToken)) {
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
    data.accessToken = envelope.response.access_token;
    return data.accessToken;
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
      const eResult = this.responseEResult(response.header);
      if (eResult.length > 0 && eResult !== '1' && eResult.toUpperCase() !== 'OK') {
        throw new Error('Steam 请求失败（EResult ' + eResult + '）');
      }
      return typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
    } catch (error) {
      throw new Error(this.requestErrorMessage(error));
    } finally {
      client.destroy();
    }
  }

  private requestErrorMessage(error: Object): string {
    if (typeof error === 'string') {
      return error;
    }
    try {
      const record = error as Record<string, Object>;
      const message = record['message'];
      const code = record['code'];
      if (typeof message === 'string' && message.length > 0) {
        return typeof code === 'number' || typeof code === 'string' ?
          message + '（' + code.toString() + '）' : message;
      }
      const serialized = JSON.stringify(error);
      if (serialized.length > 2) {
        return serialized;
      }
      return error.toString();
    } catch (ignored) {
      return 'Steam 网络请求失败';
    }
  }

  private gatewayTarget(originalUrl: string, gatewayUrl: string): string {
    const schemeIndex = originalUrl.indexOf('://');
    const pathIndex = schemeIndex >= 0 ? originalUrl.indexOf('/', schemeIndex + 3) : -1;
    const path = pathIndex >= 0 ? originalUrl.substring(pathIndex) : '/';
    return gatewayUrl.replace(/\/$/, '') + path;
  }

  private qrChallengeValues(challengeUrl: string): string[] {
    const match = /^https:\/\/s\.team\/q\/(\d+)\/(\d+)(?:\?|$)/.exec(challengeUrl.trim());
    if (!match || match.length < 3) {
      throw new Error('无效的 Steam 登录二维码');
    }
    return [match[1], match[2]];
  }

  private qrLocation(response: SteamQrLoginInfoResponse): string {
    const values: string[] = [];
    if (response.city) {
      values.push(response.city);
    }
    if (response.state && !values.includes(response.state)) {
      values.push(response.state);
    }
    if (response.country && !values.includes(response.country)) {
      values.push(response.country);
    }
    if (values.length === 0 && response.geoloc) {
      values.push(response.geoloc);
    }
    return values.join(' · ');
  }

  private communityCookie(data: SteamGuardData, accessToken: string): string {
    if (data.sessionId.length === 0) {
      data.sessionId = this.randomHex(32);
    }
    return 'dob=;steamid=' + data.steamId + ';steamLoginSecure=' + data.steamId + '%7C%7C' + accessToken +
      ';sessionid=' + data.sessionId + ';mobileClient=android;mobileClientVersion=777777%203.6.1';
  }

  private randomHex(length: number): string {
    const bytes = cryptoFramework.createRandom().generateRandomSync(Math.ceil(length / 2)).data;
    let value = '';
    for (let index = 0; index < bytes.length; index++) {
      value += bytes[index].toString(16).padStart(2, '0');
    }
    return value.substring(0, length);
  }

  private isJwtExpired(token: string): boolean {
    try {
      const parts = token.split('.');
      if (parts.length < 2) {
        return true;
      }
      const payloadText = util.TextDecoder.create('utf-8').decodeToString(
        new util.Base64Helper().decodeSync(parts[1], util.Type.BASIC_URL_SAFE)
      );
      const payload: Record<string, Object> = JSON.parse(payloadText);
      const expires = payload['exp'];
      return typeof expires !== 'number' || expires <= Math.floor(Date.now() / 1000) + 120;
    } catch (error) {
      return true;
    }
  }

  private responseEResult(headers: Object): string {
    const serialized = JSON.stringify(headers);
    const match = /"x-eresult"\s*:\s*"?([^",}]+)"?/i.exec(serialized);
    return match && match.length > 1 ? match[1].trim() : '';
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
