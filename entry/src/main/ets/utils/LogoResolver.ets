import { common } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';

export interface LogoResolveResult {
  logoUri: string;
  logoLightUri: string;
  logoDarkUri: string;
  logoSource: string;
}

interface LogoAlias {
  slug: string;
  keys: string[];
}

const LOGO_ALIASES: LogoAlias[] = [
  { slug: 'openai', keys: ['openai', 'chatgpt', 'codex'] },
  { slug: 'google', keys: ['google', 'gmail'] },
  { slug: 'huawei', keys: ['huawei', '华为'] },
  { slug: 'alibabacloud', keys: ['aliyun', 'alibaba', '阿里云', '阿里'] },
  { slug: 'binance', keys: ['binance', '币安'] },
  { slug: 'steam', keys: ['steam'] },
  { slug: 'microsoft', keys: ['microsoft', '微软', 'outlook', 'hotmail'] },
  { slug: 'github', keys: ['github'] },
  { slug: 'gitee', keys: ['gitcode', 'gitee', '码云'] },
  { slug: 'apple', keys: ['apple', 'icloud', '苹果'] },
  { slug: 'amazonaws', keys: ['amazon', 'aws'] },
  { slug: 'meta', keys: ['facebook', 'meta'] },
  { slug: 'x', keys: ['twitter', 'x.com'] },
  { slug: 'telegram', keys: ['telegram'] },
  { slug: 'discord', keys: ['discord'] },
  { slug: 'notion', keys: ['notion'] },
  { slug: 'dropbox', keys: ['dropbox'] },
  { slug: 'cloudflare', keys: ['cloudflare'] },
  { slug: 'paypal', keys: ['paypal'] },
  { slug: 'tiktok', keys: ['tiktok', '抖音'] },
  { slug: 'wechat', keys: ['wechat', '微信'] }
];

export class LogoResolver {
  static async resolve(context: common.UIAbilityContext, issuer: string, name: string): Promise<LogoResolveResult | null> {
    const candidates = LogoResolver.logoCandidates(issuer, name);
    for (const slug of candidates) {
      const result = await LogoResolver.downloadSimpleIcon(context, slug);
      if (result) {
        return result;
      }
    }
    return null;
  }

  private static logoCandidates(issuer: string, name: string): string[] {
    const result: string[] = [];
    LogoResolver.appendCandidates(result, issuer);
    LogoResolver.appendCandidates(result, name);
    return result;
  }

  private static appendCandidates(result: string[], text: string): void {
    const source = text.trim().toLowerCase();
    if (source.length === 0) {
      return;
    }
    for (const alias of LOGO_ALIASES) {
      for (const key of alias.keys) {
        if (source.indexOf(key.toLowerCase()) >= 0) {
          LogoResolver.pushUnique(result, alias.slug);
        }
      }
    }
    const slug = LogoResolver.slugify(source);
    if (slug.length > 0) {
      LogoResolver.pushUnique(result, slug);
    }
  }

  private static pushUnique(result: string[], slug: string): void {
    if (result.indexOf(slug) < 0) {
      result.push(slug);
    }
  }

  private static slugify(text: string): string {
    return text.toLowerCase().replace(/[^a-z0-9]/g, '');
  }

  private static async downloadSimpleIcon(context: common.UIAbilityContext, slug: string): Promise<LogoResolveResult | null> {
    try {
      const brandSvg = await LogoResolver.fetchSvg(slug, '');
      if (brandSvg.length === 0) {
        return null;
      }
      const lightSvg = await LogoResolver.fetchSvg(slug, '000000');
      const darkSvg = await LogoResolver.fetchSvg(slug, 'FFFFFF');
      const logoUri = LogoResolver.writeSvg(context, slug, 'brand', brandSvg);
      const logoLightUri = LogoResolver.writeSvg(context, slug, 'light', lightSvg.length > 0 ? lightSvg : brandSvg);
      const logoDarkUri = LogoResolver.writeSvg(context, slug, 'dark', darkSvg.length > 0 ? darkSvg : brandSvg);
      return {
        logoUri: logoUri,
        logoLightUri: logoLightUri,
        logoDarkUri: logoDarkUri,
        logoSource: `simple-icons-v2:${slug}`
      };
    } catch (error) {
      console.error(`Failed to resolve logo ${slug}: ${JSON.stringify(error)}`);
      return null;
    }
  }

  private static async fetchSvg(slug: string, color: string): Promise<string> {
    const request = http.createHttp();
    try {
      const url = color.length > 0 ? `https://cdn.simpleicons.org/${slug}/${color}` :
        `https://cdn.simpleicons.org/${slug}`;
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 6000,
        readTimeout: 6000
      });
      if (response.responseCode !== 200 || typeof response.result !== 'string') {
        return '';
      }
      const svg = response.result.trim();
      return svg.indexOf('<svg') >= 0 ? svg : '';
    } finally {
      request.destroy();
    }
  }

  private static writeSvg(context: common.UIAbilityContext, slug: string, mode: string, svg: string): string {
    const path = `${context.filesDir}/issuer_logo_${slug}_${mode}.svg`;
    const file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(file.fd, svg);
    } finally {
      fileIo.closeSync(file);
    }
    return fileUri.getUriFromPath(path);
  }
}
