import { util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { http } from '@kit.NetworkKit';
import { SteamGuardData } from '../model/SteamGuardData';
import { Totp } from '../utils/Totp';
import {
  SteamAddAuthenticatorResponse,
  SteamAllowedConfirmation,
  SteamBeginAuthResponse,
  SteamFinalizeAuthenticatorResponse,
  SteamPollAuthResponse,
  SteamProto,
  SteamTimeResponse
} from '../utils/SteamProto';

interface SteamRsaKeyResponse {
  publickey_mod: string;
  publickey_exp: string;
  timestamp: string;
}

interface SteamRsaKeyEnvelope {
  response: SteamRsaKeyResponse;
}

interface SteamAccessTokenResponse {
  access_token: string;
}

interface SteamAccessTokenEnvelope {
  response: SteamAccessTokenResponse;
}

export interface SteamLoginChallenge {
  clientId: string;
  requestId: Uint8Array;
  steamId: string;
  confirmations: SteamAllowedConfirmation[];
}

export interface SteamLoginSession {
  steamId: string;
  accountName: string;
  accessToken: string;
  refreshToken: string;
}

export interface SteamAuthenticatorDraft {
  data: SteamGuardData;
  confirmType: number;
  phoneNumberHint: string;
  serverTimeReceivedAt: number;
}

export class SteamEnrollmentService {
  async beginLogin(accountName: string, password: string): Promise<SteamLoginChallenge> {
    const keyText = await this.requestText(
      'https://api.steampowered.com/IAuthenticationService/GetPasswordRSAPublicKey/v1/?account_name=' +
      encodeURIComponent(accountName),
      http.RequestMethod.GET,
      ''
    );
    const envelope: SteamRsaKeyEnvelope = JSON.parse(keyText);
    if (!envelope.response || !envelope.response.publickey_mod || !envelope.response.publickey_exp ||
      !envelope.response.timestamp) {
      throw new Error('Steam 未返回可用的登录公钥');
    }
    const encryptedPassword = this.encryptPassword(password, envelope.response);
    const responseData = await this.requestProtobuf(
      'https://api.steampowered.com/IAuthenticationService/BeginAuthSessionViaCredentials/v1/',
      SteamProto.beginAuthRequest(accountName, encryptedPassword, envelope.response.timestamp)
    );
    const response: SteamBeginAuthResponse = SteamProto.decodeBeginAuth(responseData);
    if (response.clientId.length === 0 || response.requestId.length === 0 || response.steamId.length === 0) {
      throw new Error(response.extendedErrorMessage || 'Steam 登录凭据校验失败');
    }
    return {
      clientId: response.clientId,
      requestId: response.requestId,
      steamId: response.steamId,
      confirmations: response.allowedConfirmations
    };
  }

  async submitGuardCode(challenge: SteamLoginChallenge, type: number, code: string): Promise<void> {
    await this.requestProtobuf(
      'https://api.steampowered.com/IAuthenticationService/UpdateAuthSessionWithSteamGuardCode/v1/',
      SteamProto.updateGuardCodeRequest(challenge.clientId, challenge.steamId, code, type)
    );
  }

  async pollLogin(challenge: SteamLoginChallenge): Promise<SteamLoginSession | undefined> {
    const responseData = await this.requestProtobuf(
      'https://api.steampowered.com/IAuthenticationService/PollAuthSessionStatus/v1/',
      SteamProto.pollAuthRequest(challenge.clientId, challenge.requestId)
    );
    const response: SteamPollAuthResponse = SteamProto.decodePollAuth(responseData);
    if (response.refreshToken.length === 0 || response.accessToken.length === 0) {
      return undefined;
    }
    return {
      steamId: challenge.steamId,
      accountName: response.accountName,
      accessToken: response.accessToken,
      refreshToken: response.refreshToken
    };
  }

  async addAuthenticator(session: SteamLoginSession, deviceId: string): Promise<SteamAuthenticatorDraft> {
    const accessToken = await this.generateAccessToken(session);
    const timeResponse: SteamTimeResponse = SteamProto.decodeQueryTime(await this.requestProtobuf(
      'https://api.steampowered.com/ITwoFactorService/QueryTime/v1/',
      SteamProto.queryTimeRequest(Math.floor(Date.now() / 1000))
    ));
    const authenticatorTime = timeResponse.serverTime > 0 ?
      timeResponse.serverTime : Math.floor(Date.now() / 1000);
    const responseData = await this.requestProtobuf(
      'https://api.steampowered.com/ITwoFactorService/AddAuthenticator/v1/?access_token=' +
      encodeURIComponent(accessToken),
      SteamProto.addAuthenticatorRequest(session.steamId, deviceId, authenticatorTime)
    );
    const response: SteamAddAuthenticatorResponse = SteamProto.decodeAddAuthenticator(responseData);
    if (response.status === 29) {
      throw new Error('该账号已启用 Steam 令牌。本功能不会迁移或替换现有验证器，请改用 maFile 导入。');
    }
    if (response.status !== 1 || response.sharedSecret.length === 0 || response.revocationCode.length === 0) {
      throw new Error('Steam 添加验证器失败（状态 ' + response.status.toString() + '）');
    }
    const data: SteamGuardData = {
      accountName: response.accountName || session.accountName,
      steamId: session.steamId,
      sharedSecret: response.sharedSecret,
      identitySecret: response.identitySecret,
      deviceId: deviceId,
      accessToken: accessToken,
      refreshToken: session.refreshToken,
      sessionId: '',
      revocationCode: response.revocationCode,
      serialNumber: response.serialNumber,
      uri: response.uri,
      serverTime: response.serverTime,
      tokenGid: response.tokenGid,
      secret1: response.secret1,
      status: response.status,
      fullyEnrolled: false,
      maFile: ''
    };
    return {
      data: data,
      confirmType: response.confirmType,
      phoneNumberHint: response.phoneNumberHint,
      serverTimeReceivedAt: Date.now()
    };
  }

  async sendPhoneVerificationCode(accessToken: string): Promise<void> {
    await this.requestText(
      'https://api.steampowered.com/IPhoneService/SendPhoneVerificationCode/v1/?access_token=' +
      encodeURIComponent(accessToken),
      http.RequestMethod.POST,
      ''
    );
  }

  async finalizeAuthenticator(draft: SteamAuthenticatorDraft, activationCode: string): Promise<SteamGuardData> {
    let serverTime = draft.data.serverTime;
    for (let attempt = 0; attempt <= 10; attempt++) {
      const elapsed = Math.max(0, Math.floor((Date.now() - draft.serverTimeReceivedAt) / 1000));
      const authenticatorTime = serverTime > 0 ? serverTime + elapsed : Math.floor(Date.now() / 1000);
      const authenticatorCode = Totp.generate(
        draft.data.sharedSecret,
        authenticatorTime * 1000,
        'SHA1',
        5,
        30,
        'Steam'
      );
      const responseData = await this.requestProtobuf(
        'https://api.steampowered.com/ITwoFactorService/FinalizeAddAuthenticator/v1/?access_token=' +
        encodeURIComponent(draft.data.accessToken),
        SteamProto.finalizeAuthenticatorRequest(
          draft.data.steamId,
          authenticatorCode,
          authenticatorTime,
          activationCode
        )
      );
      const response: SteamFinalizeAuthenticatorResponse = SteamProto.decodeFinalizeAuthenticator(responseData);
      if (response.status === 89) {
        throw new Error('验证码不正确或已过期');
      }
      if (response.status === 88 && attempt >= 10) {
        throw new Error('设备时间与 Steam 服务器时间无法对齐');
      }
      if (!response.success) {
        throw new Error('Steam 验证器确认失败（状态 ' + response.status.toString() + '）');
      }
      if (!response.wantMore) {
        draft.data.fullyEnrolled = true;
        draft.data.serverTime = response.serverTime > 0 ? response.serverTime : authenticatorTime;
        return draft.data;
      }
      if (response.serverTime > 0) {
        serverTime = response.serverTime;
        draft.serverTimeReceivedAt = Date.now();
      }
    }
    throw new Error('Steam 未能完成验证器确认');
  }

  enrollmentConfirmation(confirmations: SteamAllowedConfirmation[]): SteamAllowedConfirmation {
    const preferredTypes: number[] = [2, 5, 1];
    for (let typeIndex = 0; typeIndex < preferredTypes.length; typeIndex++) {
      for (let index = 0; index < confirmations.length; index++) {
        if (confirmations[index].type === preferredTypes[typeIndex]) {
          return confirmations[index];
        }
      }
    }
    return { type: 0, message: '' };
  }

  hasExistingMobileAuthenticator(confirmations: SteamAllowedConfirmation[]): boolean {
    for (let index = 0; index < confirmations.length; index++) {
      if (confirmations[index].type === 3 || confirmations[index].type === 4) {
        return true;
      }
    }
    return false;
  }

  private encryptPassword(password: string, key: SteamRsaKeyResponse): string {
    const rsaSpec: cryptoFramework.RSAPubKeySpec = {
      algName: 'RSA',
      specType: cryptoFramework.AsyKeySpecType.PUBLIC_KEY_SPEC,
      params: {
        algName: 'RSA',
        specType: cryptoFramework.AsyKeySpecType.COMMON_PARAMS_SPEC,
        n: BigInt('0x' + key.publickey_mod)
      },
      pk: BigInt('0x' + key.publickey_exp)
    };
    const publicKey = cryptoFramework.createAsyKeyGeneratorBySpec(rsaSpec).generatePubKeySync();
    const cipher = cryptoFramework.createCipher('RSA1024|PKCS1');
    cipher.initSync(cryptoFramework.CryptoMode.ENCRYPT_MODE, publicKey, null);
    const encrypted = cipher.doFinalSync({ data: new util.TextEncoder().encodeInto(password) });
    return new util.Base64Helper().encodeToStringSync(encrypted.data);
  }

  private async generateAccessToken(session: SteamLoginSession): Promise<string> {
    const responseText = await this.requestText(
      'https://api.steampowered.com/IAuthenticationService/GenerateAccessTokenForApp/v1/',
      http.RequestMethod.POST,
      'refresh_token=' + encodeURIComponent(session.refreshToken) + '&steamid=' +
      encodeURIComponent(session.steamId) + '&renewal_type=0'
    );
    const envelope: SteamAccessTokenEnvelope = JSON.parse(responseText);
    if (!envelope.response || !envelope.response.access_token) {
      throw new Error('Steam 访问令牌生成失败');
    }
    return envelope.response.access_token;
  }

  private async requestProtobuf(targetUrl: string, protobuf: Uint8Array): Promise<Uint8Array> {
    const body = 'input_protobuf_encoded=' + encodeURIComponent(
      new util.Base64Helper().encodeToStringSync(protobuf)
    );
    const client = http.createHttp();
    try {
      const response = await client.request(targetUrl, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept-Type': 'application/json'
        },
        extraData: body,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 15000,
        readTimeout: 25000
      });
      this.validateResponse(response.responseCode, response.header);
      if (!(response.result instanceof ArrayBuffer)) {
        throw new Error('Steam 返回了无法识别的协议数据');
      }
      return new Uint8Array(response.result);
    } catch (error) {
      throw new Error(this.errorMessage(error));
    } finally {
      client.destroy();
    }
  }

  private async requestText(targetUrl: string, method: http.RequestMethod, body: string): Promise<string> {
    const client = http.createHttp();
    try {
      const response = await client.request(targetUrl, {
        method: method,
        header: { 'Content-Type': 'application/x-www-form-urlencoded' },
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 25000
      });
      this.validateResponse(response.responseCode, response.header);
      return typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
    } catch (error) {
      throw new Error(this.errorMessage(error));
    } finally {
      client.destroy();
    }
  }

  private validateResponse(responseCode: number, headers: Object): void {
    if (responseCode < 200 || responseCode >= 300) {
      throw new Error('Steam 请求失败（HTTP ' + responseCode.toString() + '）');
    }
    const serialized = JSON.stringify(headers);
    const match = /"x-eresult"\s*:\s*"?([^",}]+)"?/i.exec(serialized);
    const result = match && match.length > 1 ? match[1].trim() : '';
    if (result.length > 0 && result !== '1' && result.toUpperCase() !== 'OK') {
      throw new Error(this.resultMessage(result));
    }
  }

  private resultMessage(result: string): string {
    if (result === '5') {
      return 'Steam 账号或密码错误';
    }
    if (result === '9') {
      return 'Steam 登录会话已失效，请重新登录';
    }
    if (result === '63') {
      return 'Steam 登录已被限制，请稍后重试';
    }
    if (result === '65') {
      return 'Steam 登录验证码错误';
    }
    if (result === '29') {
      return 'Steam 拒绝了当前验证方式。账号可能已启用移动验证器，请导入原 maFile；本功能不能复制现有验证器密钥。';
    }
    if (result === '84') {
      return 'Steam 请求过于频繁，请稍后重试';
    }
    return 'Steam 请求失败（EResult ' + result + '）';
  }

  private errorMessage(error: Object): string {
    const serialized = JSON.stringify(error);
    if (serialized.indexOf('2300999') >= 0) {
      return 'Steam 登录请求未完成，请检查当前网络能否直接访问 Steam 后重试';
    }
    if (error instanceof Error && error.message.length > 0) {
      return error.message;
    }
    return serialized.length > 2 ? serialized : 'Steam 网络请求失败';
  }
}
