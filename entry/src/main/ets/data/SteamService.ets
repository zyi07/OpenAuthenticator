import { util } from '@kit.ArkTS';
import { systemDateTime } from '@kit.BasicServicesKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { http } from '@kit.NetworkKit';
import {
  SteamConfirmation,
  SteamGuardData,
  SteamInventoryGame,
  SteamInventoryItem,
  SteamInventoryOverview,
  SteamInventoryPage,
  SteamMarketListing,
  SteamMarketListingPage,
  SteamMarketPriceHistory,
  SteamMarketPricePoint,
  SteamMarketSaleHistoryItem,
  SteamMarketSaleHistoryPage,
  SteamMarketSellResult,
  SteamPendingLogin,
  SteamProfile
} from '../model/SteamGuardData';
import { SteamProto } from '../utils/SteamProto';

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
  version: number;
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

interface SteamInventoryAssetResponse {
  appid: number;
  contextid: string;
  assetid: string;
  classid: string;
  instanceid: string;
  amount: string;
}

interface SteamInventoryDescriptionResponse {
  classid: string;
  instanceid: string;
  market_hash_name: string;
  market_name: string;
  name: string;
  type: string;
  icon_url: string;
  marketable: number;
  tradable: number;
  market_fee?: number;
}

interface SteamInventoryEnvelope {
  assets: SteamInventoryAssetResponse[];
  descriptions: SteamInventoryDescriptionResponse[];
  last_assetid: string;
  more_items: boolean;
  total_inventory_count: number;
}

interface SteamMarketPriceHistoryEnvelope {
  success: boolean;
  price_prefix: string;
  price_suffix: string;
  prices: Object[][];
  message?: string;
}

interface SteamMarketSellEnvelope {
  success: boolean | number;
  requires_confirmation?: number | boolean;
  needs_mobile_confirmation?: boolean;
  needs_email_confirmation?: boolean;
  message?: string;
}

interface SteamMarketListingsEnvelope {
  success?: boolean | number;
  results_html?: string;
  assets?: Record<string, Object>;
  num_active_listings?: number;
  total_count?: number;
  pagesize?: number;
  message?: string;
}

interface SteamMarketRemoveEnvelope {
  success?: boolean | number;
  message?: string;
}

interface SteamServerInfoResponse {
  servertime: number;
  servertimestring: string;
}

export class SteamService {
  private options: SteamNetworkOptions;

  constructor(options: SteamNetworkOptions) {
    this.options = options;
  }

  async officialApiLatency(): Promise<number> {
    const client = http.createHttp();
    const startedAt = Date.now();
    const headers: Record<string, string> = { 'Cache-Control': 'no-cache' };
    try {
      const response = await client.request(
        'https://api.steampowered.com/ISteamWebAPIUtil/GetServerInfo/v1/?_=' + startedAt.toString(),
        {
          method: http.RequestMethod.GET,
          header: headers,
          expectDataType: http.HttpDataType.STRING,
          connectTimeout: 5000,
          readTimeout: 5000
        }
      );
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error('Steam API latency request failed');
      }
      if (typeof response.result !== 'string' || response.result.trim().length === 0) {
        throw new Error('Steam API latency response is empty');
      }
      const serverInfo: SteamServerInfoResponse = JSON.parse(response.result);
      if (serverInfo.servertime <= 0 || serverInfo.servertimestring.length === 0) {
        throw new Error('Steam API latency response is invalid');
      }
      return Math.max(1, Date.now() - startedAt);
    } finally {
      client.destroy();
    }
  }

  async profile(data: SteamGuardData): Promise<SteamProfile> {
    if (data.steamId.length === 0) {
      return { displayName: data.accountName, avatarUrl: '' };
    }
    const token = await this.accessToken(data);
    const body = await this.request(
      'https://steamcommunity.com/profiles/' + encodeURIComponent(data.steamId) + '?xml=1',
      http.RequestMethod.GET,
      '',
      this.communityCookie(data, token)
    );
    return {
      displayName: this.xmlValue(body, 'steamID') || data.accountName,
      avatarUrl: this.xmlValue(body, 'avatarMedium') || this.xmlValue(body, 'avatarIcon')
    };
  }

  async pendingLogins(data: SteamGuardData): Promise<SteamPendingLogin[]> {
    const token = await this.accessToken(data);
    const responseData = await this.requestProtobuf(
      'https://api.steampowered.com/IAuthenticationService/GetAuthSessionsForAccount/v1/' +
        '?access_token=' + encodeURIComponent(token),
      SteamProto.emptyRequest(),
      http.RequestMethod.GET
    );
    const clientIds = SteamProto.decodePendingLoginClientIds(responseData);
    const pending: SteamPendingLogin[] = [];
    for (let index = 0; index < clientIds.length; index++) {
      try {
        const infoData = await this.requestProtobuf(
          'https://api.steampowered.com/IAuthenticationService/GetAuthSessionInfo/v1/' +
            '?access_token=' + encodeURIComponent(token),
          SteamProto.pendingLoginInfoRequest(clientIds[index])
        );
        const response = SteamProto.decodePendingLoginInfo(infoData);
        const locationValues: string[] = [];
        if (response.city.length > 0) {
          locationValues.push(response.city);
        }
        if (response.country.length > 0 && !locationValues.includes(response.country)) {
          locationValues.push(response.country);
        }
        pending.push({
          clientId: clientIds[index],
          version: response.version,
          ip: response.ip,
          location: locationValues.join(' · '),
          deviceName: response.deviceName,
          creationTime: Date.now()
        });
      } catch (error) {
        console.error('Failed to load Steam pending login details: ' + this.requestErrorMessage(error));
      }
    }
    return pending;
  }

  async respondPendingLogin(
    data: SteamGuardData,
    pending: SteamPendingLogin,
    confirm: boolean
  ): Promise<void> {
    const token = await this.accessToken(data);
    const responseData = await this.requestProtobuf(
      'https://api.steampowered.com/IAuthenticationService/UpdateAuthSessionWithMobileConfirmation/v1/' +
        '?access_token=' + encodeURIComponent(token),
      SteamProto.pendingLoginResponseRequest(
        pending.version,
        pending.clientId,
        data.steamId,
        this.qrSignatureData(data.sharedSecret, data.steamId, pending.version.toString(), pending.clientId),
        confirm
      )
    );
    if (!SteamProto.decodePendingLoginResponse(responseData)) {
      throw new Error('Steam 登录批准操作失败');
    }
  }

  async inventoryOverview(data: SteamGuardData): Promise<SteamInventoryOverview> {
    const token = await this.accessToken(data);
    const html = await this.request(
      'https://steamcommunity.com/profiles/' + encodeURIComponent(data.steamId) + '/inventory/',
      http.RequestMethod.GET,
      '',
      this.communityCookie(data, token)
    );
    const rawApps = this.assignedJsonObject(html, 'g_rgAppContextData');
    if (rawApps.length === 0) {
      return { games: [] };
    }
    const apps: Record<string, Object> = JSON.parse(rawApps);
    const games: SteamInventoryGame[] = [];
    const appIds = Object.keys(apps);
    for (let appIndex = 0; appIndex < appIds.length; appIndex++) {
      const appIdText = appIds[appIndex];
      const appValue = apps[appIdText];
      if (typeof appValue !== 'object' || appValue === null) {
        continue;
      }
      const app: Record<string, Object> = JSON.parse(JSON.stringify(appValue));
      const contextsValue = app['rgContexts'];
      if (typeof contextsValue !== 'object' || contextsValue === null) {
        continue;
      }
      const contexts: Record<string, Object> = JSON.parse(JSON.stringify(contextsValue));
      const contextIds = Object.keys(contexts);
      for (let contextIndex = 0; contextIndex < contextIds.length; contextIndex++) {
        const contextId = contextIds[contextIndex];
        const contextValue = contexts[contextId];
        if (typeof contextValue !== 'object' || contextValue === null) {
          continue;
        }
        const context: Record<string, Object> = JSON.parse(JSON.stringify(contextValue));
        const itemCount = this.recordNumber(context, 'asset_count');
        if (itemCount <= 0) {
          continue;
        }
        games.push({
          appId: Number(appIdText) || 0,
          contextId: contextId,
          name: this.recordString(app, 'name'),
          contextName: this.recordString(context, 'name'),
          iconUrl: this.normalizeImageUrl(this.recordString(app, 'icon')),
          itemCount: itemCount
        });
      }
    }
    games.sort((left: SteamInventoryGame, right: SteamInventoryGame): number => right.itemCount - left.itemCount);
    return { games: games };
  }

  async inventoryItems(
    data: SteamGuardData,
    game: SteamInventoryGame,
    language: string,
    startAssetId: string = ''
  ): Promise<SteamInventoryPage> {
    const token = await this.accessToken(data);
    let query = '?l=' + encodeURIComponent(language) + '&count=75';
    if (startAssetId.length > 0) {
      query += '&start_assetid=' + encodeURIComponent(startAssetId);
    }
    const body = await this.request(
      'https://steamcommunity.com/inventory/' + encodeURIComponent(data.steamId) + '/' +
        game.appId.toString() + '/' + encodeURIComponent(game.contextId) + query,
      http.RequestMethod.GET,
      '',
      this.communityCookie(data, token)
    );
    const envelope: SteamInventoryEnvelope = JSON.parse(body);
    const descriptions = new Map<string, SteamInventoryDescriptionResponse>();
    const rawDescriptions = envelope.descriptions || [];
    for (let index = 0; index < rawDescriptions.length; index++) {
      const description = rawDescriptions[index];
      descriptions.set(description.classid + '_' + description.instanceid, description);
    }
    const items: SteamInventoryItem[] = [];
    const rawAssets = envelope.assets || [];
    for (let index = 0; index < rawAssets.length; index++) {
      const asset = rawAssets[index];
      const description = descriptions.get(asset.classid + '_' + asset.instanceid);
      if (description === undefined) {
        continue;
      }
      items.push({
        appId: asset.appid || game.appId,
        contextId: asset.contextid || game.contextId,
        assetId: asset.assetid || '',
        classId: asset.classid || '',
        instanceId: asset.instanceid || '',
        amount: Math.max(1, Number(asset.amount) || 1),
        marketHashName: description.market_hash_name || '',
        name: description.name || description.market_name || '',
        type: description.type || '',
        iconUrl: this.normalizeImageUrl(description.icon_url || ''),
        marketable: description.marketable === 1,
        tradable: description.tradable === 1,
        marketFee: typeof description.market_fee === 'number' && Number.isFinite(description.market_fee) ?
          Math.max(0, description.market_fee) : 0.10
      });
    }
    return {
      items: items,
      lastAssetId: envelope.last_assetid || '',
      hasMore: envelope.more_items || false,
      totalCount: envelope.total_inventory_count || items.length
    };
  }

  async marketPriceHistory(data: SteamGuardData, item: SteamInventoryItem): Promise<SteamMarketPriceHistory> {
    if (item.marketHashName.trim().length === 0) {
      throw new Error('该物品没有 Steam 市场名称');
    }
    const token = await this.accessToken(data);
    const body = await this.request(
      'https://steamcommunity.com/market/pricehistory/?appid=' + item.appId.toString() +
        '&market_hash_name=' + encodeURIComponent(item.marketHashName),
      http.RequestMethod.GET,
      '',
      this.communityCookie(data, token)
    );
    const envelope: SteamMarketPriceHistoryEnvelope = JSON.parse(body);
    if (!envelope.success) {
      throw new Error(envelope.message || 'Steam 市场价格历史获取失败');
    }
    const points: SteamMarketPricePoint[] = [];
    const rawPrices = envelope.prices || [];
    for (let index = 0; index < rawPrices.length; index++) {
      const row = rawPrices[index];
      if (row.length < 2) {
        continue;
      }
      const labelValue = row[0];
      const priceValue = row[1];
      const volumeValue = row.length > 2 ? row[2] : 0;
      const label = typeof labelValue === 'string' ? labelValue : labelValue.toString();
      const price = typeof priceValue === 'number' ? priceValue : Number(priceValue.toString());
      const volume = typeof volumeValue === 'number' ? volumeValue : Number(volumeValue.toString());
      if (!Number.isFinite(price) || price <= 0) {
        continue;
      }
      points.push({
        label: label,
        price: price,
        volume: Number.isFinite(volume) ? Math.max(0, volume) : 0
      });
    }
    return {
      prefix: envelope.price_prefix || '',
      suffix: envelope.price_suffix || '',
      points: points
    };
  }

  async sellMarketItem(
    data: SteamGuardData,
    item: SteamInventoryItem,
    sellerReceivesMinorUnits: number
  ): Promise<SteamMarketSellResult> {
    if (!item.marketable) {
      throw new Error('该物品不支持在 Steam 社区市场出售');
    }
    if (item.assetId.length === 0 || item.contextId.length === 0 || item.appId <= 0) {
      throw new Error('该物品缺少市场上架信息');
    }
    if (!Number.isInteger(sellerReceivesMinorUnits) || sellerReceivesMinorUnits <= 0) {
      throw new Error('请输入有效的出售价格');
    }
    const token = await this.accessToken(data);
    const cookie = this.communityCookie(data, token);
    const requestBody = 'sessionid=' + encodeURIComponent(data.sessionId) +
      '&appid=' + item.appId.toString() +
      '&contextid=' + encodeURIComponent(item.contextId) +
      '&assetid=' + encodeURIComponent(item.assetId) +
      '&amount=1&price=' + sellerReceivesMinorUnits.toString();
    const responseText = await this.request(
      'https://steamcommunity.com/market/sellitem/',
      http.RequestMethod.POST,
      requestBody,
      cookie,
      data.steamId.length > 0 ?
        'https://steamcommunity.com/profiles/' + encodeURIComponent(data.steamId) + '/inventory/' :
        'https://steamcommunity.com/my/inventory/'
    );
    const envelope: SteamMarketSellEnvelope = JSON.parse(responseText);
    const mobileConfirmation = envelope.needs_mobile_confirmation === true;
    const emailConfirmation = envelope.needs_email_confirmation === true;
    const responseMessage = envelope.message || '';
    const normalizedMessage = responseMessage.toLowerCase();
    const pendingConfirmation = normalizedMessage.indexOf('pending confirmation') >= 0 ||
      responseMessage.indexOf('等待确认') >= 0 || responseMessage.indexOf('移动确认') >= 0;
    const succeeded = envelope.success === true || envelope.success === 1;
    if (!succeeded && !pendingConfirmation && !mobileConfirmation && !emailConfirmation) {
      throw new Error(responseMessage || 'Steam 市场上架失败');
    }
    return {
      requiresConfirmation: envelope.requires_confirmation === 1 || envelope.requires_confirmation === true ||
        pendingConfirmation || mobileConfirmation || emailConfirmation,
      mobileConfirmation: mobileConfirmation || pendingConfirmation,
      emailConfirmation: emailConfirmation
    };
  }

  async marketListings(data: SteamGuardData): Promise<SteamMarketListing[]> {
    const listings: SteamMarketListing[] = [];
    let start = 0;
    for (let pageIndex = 0; pageIndex < 100; pageIndex++) {
      const page = await this.marketListingsPage(data, start, 100);
      listings.push(...page.items);
      start = page.nextStart;
      if (!page.hasMore || page.items.length === 0) {
        break;
      }
    }
    return listings;
  }

  async marketListingsPage(data: SteamGuardData, start: number, count: number): Promise<SteamMarketListingPage> {
    const normalizedStart = Math.max(0, start);
    const normalizedCount = Math.max(1, Math.min(100, count));
    const token = await this.accessToken(data);
    const cookie = this.communityCookie(data, token);
    const responseText = await this.request(
      'https://steamcommunity.com/market/mylistings/?query=&start=' + normalizedStart.toString() +
        '&count=' + normalizedCount.toString() + '&l=schinese',
      http.RequestMethod.GET,
      '',
      cookie,
      'https://steamcommunity.com/market/'
    );
    const envelope: SteamMarketListingsEnvelope = JSON.parse(responseText);
    if (envelope.success === false || envelope.success === 0) {
      throw new Error(envelope.message || 'Steam 市场上架列表获取失败');
    }
    const assets: Record<string, Object> = envelope.assets === undefined ? JSON.parse('{}') : envelope.assets;
    const items = this.parseMarketListings(envelope.results_html || '', assets);
    let totalCount = normalizedStart + items.length;
    if (typeof envelope.total_count === 'number') {
      totalCount = Math.max(0, envelope.total_count);
    } else if (typeof envelope.num_active_listings === 'number') {
      totalCount = Math.max(0, envelope.num_active_listings);
    }
    const pageSize = typeof envelope.pagesize === 'number' && envelope.pagesize > 0 ?
      envelope.pagesize : normalizedCount;
    const nextStart = normalizedStart + pageSize;
    return {
      items: items,
      nextStart: nextStart,
      hasMore: nextStart < totalCount && items.length > 0,
      totalCount: totalCount
    };
  }

  async marketSaleHistoryPage(
    data: SteamGuardData,
    start: number,
    count: number
  ): Promise<SteamMarketSaleHistoryPage> {
    const normalizedCount = Math.max(1, Math.min(100, count));
    const token = await this.accessToken(data);
    const cookie = this.communityCookie(data, token);
    const items: SteamMarketSaleHistoryItem[] = [];
    let nextStart = Math.max(0, start);
    let totalCount = nextStart;
    let hasMore = true;
    for (let pageIndex = 0; pageIndex < 20 && items.length < normalizedCount && hasMore; pageIndex++) {
      const requestCount = 20;
      const responseText = await this.request(
        'https://steamcommunity.com/market/myhistory/render/?query=&start=' + nextStart.toString() +
          '&count=' + requestCount.toString() + '&l=schinese',
        http.RequestMethod.GET,
        '',
        cookie,
        'https://steamcommunity.com/market/'
      );
      const envelope: SteamMarketListingsEnvelope = JSON.parse(responseText);
      if (envelope.success === false || envelope.success === 0) {
        throw new Error(envelope.message || 'Steam 市场出售记录获取失败');
      }
      const pageItems = this.parseMarketSaleHistory(envelope.results_html || '', nextStart);
      for (let itemIndex = 0; itemIndex < pageItems.length && items.length < normalizedCount; itemIndex++) {
        items.push(pageItems[itemIndex]);
      }
      totalCount = typeof envelope.total_count === 'number' ? Math.max(0, envelope.total_count) :
        nextStart + requestCount;
      const pageSize = typeof envelope.pagesize === 'number' && envelope.pagesize > 0 ?
        envelope.pagesize : requestCount;
      nextStart += pageSize;
      hasMore = nextStart < totalCount && pageSize > 0;
    }
    return {
      items: items,
      nextStart: nextStart,
      hasMore: hasMore,
      totalCount: totalCount
    };
  }

  async removeMarketListing(data: SteamGuardData, listingId: string): Promise<void> {
    const normalizedListingId = listingId.trim();
    if (normalizedListingId.length === 0) {
      throw new Error('Steam 市场上架记录无效');
    }
    const token = await this.accessToken(data);
    const cookie = this.communityCookie(data, token);
    const responseText = await this.request(
      'https://steamcommunity.com/market/removelisting/' + encodeURIComponent(normalizedListingId),
      http.RequestMethod.POST,
      'sessionid=' + encodeURIComponent(data.sessionId),
      cookie,
      'https://steamcommunity.com/market/'
    );
    if (responseText.trim().length === 0) {
      return;
    }
    const envelope: SteamMarketRemoveEnvelope = JSON.parse(responseText);
    if (envelope.success === false || envelope.success === 0) {
      throw new Error(envelope.message || 'Steam 市场物品撤下失败');
    }
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

  private async requestProtobuf(
    targetUrl: string,
    protobuf: Uint8Array,
    method: http.RequestMethod = http.RequestMethod.POST
  ): Promise<Uint8Array> {
    let body = '';
    if (protobuf.length > 0) {
      const encoded = new util.Base64Helper().encodeToStringSync(protobuf);
      body = 'input_protobuf_encoded=' + encodeURIComponent(encoded);
    }
    const client = http.createHttp();
    let requestUrl = targetUrl;
    if (method === http.RequestMethod.GET && body.length > 0) {
      requestUrl += (requestUrl.indexOf('?') >= 0 ? '&' : '?') + body;
    }
    const headers: Record<string, string> = { 'Content-Type': 'application/x-www-form-urlencoded' };
    if (this.options.enhancedAccess && this.options.gatewayUrl.trim().length > 0) {
      requestUrl = this.gatewayTarget(targetUrl, this.options.gatewayUrl.trim());
      if (this.options.gatewayToken.length > 0) {
        headers['Proxy-Auth-Token'] = this.options.gatewayToken;
      }
    }
    try {
      const response = await client.request(requestUrl, {
        method: method,
        header: headers,
        extraData: method === http.RequestMethod.GET ? '' : body,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
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
      if (!(response.result instanceof ArrayBuffer)) {
        throw new Error('Steam 返回了无法识别的协议数据');
      }
      return new Uint8Array(response.result);
    } catch (error) {
      throw new Error(this.requestErrorMessage(error));
    } finally {
      client.destroy();
    }
  }

  private assignedJsonObject(html: string, variableName: string): string {
    const expression = new RegExp(variableName + '\\s*=\\s*');
    const match = expression.exec(html);
    if (!match) {
      return '';
    }
    let index = match.index + match[0].length;
    while (index < html.length && html.charAt(index) !== '{') {
      index++;
    }
    if (index >= html.length) {
      return '';
    }
    const start = index;
    let depth = 0;
    let quote = '';
    let escaped = false;
    while (index < html.length) {
      const character = html.charAt(index);
      if (quote.length > 0) {
        if (escaped) {
          escaped = false;
        } else if (character === '\\') {
          escaped = true;
        } else if (character === quote) {
          quote = '';
        }
      } else if (character === '"' || character === "'") {
        quote = character;
      } else if (character === '{') {
        depth++;
      } else if (character === '}') {
        depth--;
        if (depth === 0) {
          return html.substring(start, index + 1);
        }
      }
      index++;
    }
    return '';
  }

  private recordString(record: Record<string, Object>, key: string): string {
    const value = record[key];
    return typeof value === 'string' ? value : value === undefined || value === null ? '' : value.toString();
  }

  private parseMarketListings(html: string, assets: Record<string, Object>): SteamMarketListing[] {
    const listings: SteamMarketListing[] = [];
    const expression = new RegExp(
      "RemoveMarketListing\\(\\s*['\"]\\/?mylisting['\"]\\s*,\\s*['\"]([0-9]+)['\"]\\s*,\\s*" +
        "([0-9]+)\\s*,\\s*['\"]([0-9]+)['\"]\\s*,\\s*['\"]([0-9]+)['\"]",
      'g'
    );
    let match = expression.exec(html);
    while (match !== null && match.length >= 5) {
      const listingId = match[1];
      const appId = Number(match[2]) || 0;
      const contextId = match[3];
      const assetId = match[4];
      const rowHtml = this.marketListingRowHtml(html, listingId);
      const asset = this.marketListingAsset(assets, appId.toString(), contextId, assetId);
      let name = this.recordString(asset, 'market_name') || this.recordString(asset, 'name');
      if (name.length === 0) {
        name = this.marketListingElementText(rowHtml, 'mylisting_' + listingId + '_name');
      }
      const assetIconUrl = this.recordString(asset, 'icon_url');
      const rowIconUrl = this.marketListingImageUrl(rowHtml);
      listings.push({
        listingId: listingId,
        appId: appId,
        contextId: contextId,
        assetId: assetId,
        name: name.length > 0 ? name : 'Steam 市场物品',
        type: this.recordString(asset, 'type'),
        iconUrl: this.normalizeImageUrl(assetIconUrl.length > 0 ? assetIconUrl : rowIconUrl),
        priceText: this.marketListingPriceText(rowHtml),
        listedDateText: this.marketListingClassText(rowHtml, 'market_listing_listed_date')
      });
      match = expression.exec(html);
    }
    return listings;
  }

  private parseMarketSaleHistory(html: string, pageStart: number): SteamMarketSaleHistoryItem[] {
    const items: SteamMarketSaleHistoryItem[] = [];
    const rowMarker = 'market_listing_row market_recent_listing_row';
    let rowStart = html.indexOf(rowMarker);
    let rowIndex = 0;
    while (rowStart >= 0) {
      const nextRow = html.indexOf(rowMarker, rowStart + rowMarker.length);
      const rowHtml = html.substring(rowStart, nextRow >= 0 ? nextRow : html.length);
      const direction = this.marketListingClassText(rowHtml, 'market_listing_gainorloss');
      if (direction.indexOf('+') >= 0) {
        const rowId = this.marketHistoryRowId(rowHtml, pageStart + rowIndex);
        const name = this.marketListingClassText(rowHtml, 'market_listing_item_name');
        items.push({
          id: rowId,
          name: name.length > 0 ? name : 'Steam 市场物品',
          type: this.marketListingClassText(rowHtml, 'market_listing_game_name'),
          iconUrl: this.normalizeImageUrl(this.marketListingImageUrl(rowHtml)),
          priceText: this.marketListingPriceText(rowHtml),
          dateText: this.marketListingClassText(rowHtml, 'market_listing_listed_date')
        });
      }
      rowIndex++;
      rowStart = nextRow;
    }
    return items;
  }

  private marketHistoryRowId(html: string, fallbackIndex: number): string {
    const expression = new RegExp("id=[\"']([^\"']*history[^\"']*)[\"']", 'i');
    const match = expression.exec(html);
    return match !== null && match.length > 1 ? match[1] : 'market-sale-' + fallbackIndex.toString();
  }

  private marketListingAsset(
    assets: Record<string, Object>,
    appId: string,
    contextId: string,
    assetId: string
  ): Record<string, Object> {
    const app = this.marketListingNestedRecord(assets, appId);
    const context = this.marketListingNestedRecord(app, contextId);
    return this.marketListingNestedRecord(context, assetId);
  }

  private marketListingNestedRecord(record: Record<string, Object>, key: string): Record<string, Object> {
    const value = record[key];
    if (typeof value !== 'object' || value === null) {
      return JSON.parse('{}');
    }
    return JSON.parse(JSON.stringify(value));
  }

  private marketListingRowHtml(html: string, listingId: string): string {
    let anchorIndex = html.indexOf('id="mylisting_' + listingId + '"');
    if (anchorIndex < 0) {
      anchorIndex = html.indexOf("id='mylisting_" + listingId + "'");
    }
    if (anchorIndex < 0) {
      return '';
    }
    const rowStart = html.lastIndexOf('<div class="market_listing_row', anchorIndex);
    const start = rowStart >= 0 ? rowStart : anchorIndex;
    const nextRow = html.indexOf('<div class="market_listing_row', anchorIndex + 1);
    return html.substring(start, nextRow >= 0 ? nextRow : html.length);
  }

  private marketListingElementText(html: string, elementId: string): string {
    const expression = new RegExp(
      'id=["\\\']' + elementId + '["\\\'][^>]*>([\\s\\S]*?)<\\/',
      'i'
    );
    const match = expression.exec(html);
    return match !== null && match.length > 1 ? this.stripMarketHtml(match[1]) : '';
  }

  private marketListingImageUrl(html: string): string {
    const expression = new RegExp('<img[^>]+src=["\\\']([^"\\\']+)["\\\']', 'i');
    const match = expression.exec(html);
    return match !== null && match.length > 1 ? match[1] : '';
  }

  private marketListingClassText(html: string, className: string): string {
    const expression = new RegExp(
      '<[^>]*class=["\\\'][^"\\\']*' + className + '[^"\\\']*["\\\'][^>]*>([\\s\\S]*?)<\\/[^>]+>',
      'i'
    );
    const match = expression.exec(html);
    return match !== null && match.length > 1 ? this.stripMarketHtml(match[1]) : '';
  }

  private marketListingPriceText(html: string): string {
    const text = this.marketListingClassText(html, 'market_listing_price');
    const lineBreakIndex = text.indexOf('\n');
    const firstLine = lineBreakIndex >= 0 ? text.substring(0, lineBreakIndex).trim() : text.trim();
    const feeIndex = firstLine.indexOf('(');
    return feeIndex > 0 ? firstLine.substring(0, feeIndex).trim() : firstLine;
  }

  private stripMarketHtml(value: string): string {
    return this.decodeXmlText(value.replace(/<br\s*\/?\s*>/gi, '\n').replace(/<[^>]+>/g, ' '))
      .split('&nbsp;').join(' ').replace(/[ \t]+/g, ' ').replace(/ *\n */g, '\n').trim();
  }

  private recordNumber(record: Record<string, Object>, key: string): number {
    const value = record[key];
    if (typeof value === 'number') {
      return value;
    }
    if (typeof value === 'string') {
      return Number(value) || 0;
    }
    return 0;
  }

  private normalizeImageUrl(value: string): string {
    const normalized = value.trim();
    if (normalized.length === 0) {
      return '';
    }
    if (normalized.startsWith('https://') || normalized.startsWith('http://')) {
      return normalized;
    }
    if (normalized.startsWith('//')) {
      return 'https:' + normalized;
    }
    const path = normalized.startsWith('/') ? normalized.substring(1) : normalized;
    return 'https://community.fastly.steamstatic.com/economy/image/' + path;
  }

  private xmlValue(xml: string, tag: string): string {
    const cdataExpression = new RegExp('<' + tag + '><!\\[CDATA\\[([\\s\\S]*?)\\]\\]></' + tag + '>', 'i');
    const cdataMatch = cdataExpression.exec(xml);
    if (cdataMatch && cdataMatch.length > 1) {
      return this.decodeXmlText(cdataMatch[1].trim());
    }
    const expression = new RegExp('<' + tag + '>([\\s\\S]*?)</' + tag + '>', 'i');
    const match = expression.exec(xml);
    return match && match.length > 1 ? this.decodeXmlText(match[1].trim()) : '';
  }

  private decodeXmlText(value: string): string {
    return value.split('&amp;').join('&').split('&lt;').join('<').split('&gt;').join('>')
      .split('&quot;').join('"').split('&#39;').join("'");
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

  private async request(
    originalUrl: string,
    method: http.RequestMethod,
    body: string,
    cookie: string,
    communityReferer: string = ''
  ): Promise<string> {
    const client = http.createHttp();
    let targetUrl = originalUrl;
    const headers: Record<string, string> = { 'Content-Type': 'application/x-www-form-urlencoded' };
    if (cookie.length > 0) {
      headers['Cookie'] = cookie;
    }
    if (communityReferer.length > 0) {
      headers['Accept'] = 'application/json, text/javascript, */*; q=0.01';
      headers['Origin'] = 'https://steamcommunity.com';
      headers['Referer'] = communityReferer;
      headers['X-Requested-With'] = 'XMLHttpRequest';
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
    return new util.Base64Helper().encodeToStringSync(
      this.qrSignatureData(secret, steamId, version, clientId)
    );
  }

  private qrSignatureData(secret: string, steamId: string, version: string, clientId: string): Uint8Array {
    const helper = new util.Base64Helper();
    const keyData = helper.decodeSync(secret);
    const mac = cryptoFramework.createMac('SHA256');
    const key = cryptoFramework.createSymKeyGenerator('HMAC').convertKeySync({ data: keyData });
    mac.initSync(key);
    mac.updateSync({ data: this.littleEndian(BigInt(version), 2) });
    mac.updateSync({ data: this.littleEndian(BigInt(clientId), 8) });
    mac.updateSync({ data: this.littleEndian(BigInt(steamId), 8) });
    return mac.doFinalSync().data;
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
