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

class MaintainedLogoEntry {
  slug: string = '';
  aliases: string[] = [];
  brand: string = '';
  light: string = '';
  dark: string = '';
  revision: string = '1';
}

const MAINTAINED_LOGO_RAW_BASE =
  'https://api.gitcode.com/api/v5/repos/mroble/Authenticator/raw/issuer-logos/';
const MAINTAINED_LOGO_MANIFEST_URL = `${MAINTAINED_LOGO_RAW_BASE}manifest.json?ref=main`;
const MAINTAINED_LOGO_MANIFEST_CACHE = 'issuer_logo_manifest.json';
const MAINTAINED_LOGO_CACHE_TTL_MS = 10 * 60 * 1000;
const MAINTAINED_LOGO_MAX_TEXT_LENGTH = 1024 * 1024;

const LOGO_ALIASES: LogoAlias[] = [
  { slug: 'openai', keys: ['openai', 'chatgpt', 'codex'] },
  { slug: 'google', keys: ['google', 'gmail'] },
  { slug: 'huawei', keys: ['huawei', '华为'] },
  { slug: 'alibabacloud', keys: ['aliyun', 'alibaba', '阿里云', '阿里'] },
  { slug: 'binance', keys: ['binance', '币安'] },
  { slug: 'steam', keys: ['steam'] },
  { slug: 'microsoft', keys: ['microsoft', '微软', 'outlook', 'hotmail'] },
  { slug: 'github', keys: ['github'] },
  { slug: 'gitcode', keys: ['gitcode'] },
  { slug: 'gitee', keys: ['gitee', '码云'] },
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
  private static maintainedLogos: MaintainedLogoEntry[] = [];
  private static maintainedLogosLoadedAt: number = 0;

  static async resolve(context: common.UIAbilityContext, issuer: string, name: string): Promise<LogoResolveResult | null> {
    const candidates = LogoResolver.logoCandidates(issuer, name);
    for (const slug of candidates) {
      if (slug === 'gitcode') {
        return {
          logoUri: '',
          logoLightUri: '',
          logoDarkUri: '',
          logoSource: 'bundled:gitcode'
        };
      }
      const result = await LogoResolver.downloadSimpleIcon(context, slug);
      if (result) {
        return result;
      }
    }
    return await LogoResolver.resolveMaintainedLogo(context, issuer, name);
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

  private static async resolveMaintainedLogo(
    context: common.UIAbilityContext,
    issuer: string,
    name: string
  ): Promise<LogoResolveResult | null> {
    const entries = await LogoResolver.loadMaintainedLogos(context);
    for (let index = 0; index < entries.length; index++) {
      const entry = entries[index];
      if (!LogoResolver.matchesMaintainedLogo(entry, issuer, name)) {
        continue;
      }
      const result = await LogoResolver.downloadMaintainedLogo(context, entry);
      if (result) {
        return result;
      }
    }
    return null;
  }

  private static async loadMaintainedLogos(context: common.UIAbilityContext): Promise<MaintainedLogoEntry[]> {
    const now = Date.now();
    if (LogoResolver.maintainedLogosLoadedAt > 0 &&
      now - LogoResolver.maintainedLogosLoadedAt < MAINTAINED_LOGO_CACHE_TTL_MS) {
      return LogoResolver.maintainedLogos;
    }
    LogoResolver.maintainedLogosLoadedAt = now;
    try {
      const manifest = await LogoResolver.fetchText(MAINTAINED_LOGO_MANIFEST_URL);
      const parsed = LogoResolver.parseMaintainedLogoManifest(manifest);
      if (parsed !== null) {
        LogoResolver.maintainedLogos = parsed;
        LogoResolver.writeTextFile(`${context.filesDir}/${MAINTAINED_LOGO_MANIFEST_CACHE}`, manifest);
        return LogoResolver.maintainedLogos;
      }
    } catch (error) {
      console.error(`Failed to fetch maintained logo manifest: ${JSON.stringify(error)}`);
    }
    const cachedPath = `${context.filesDir}/${MAINTAINED_LOGO_MANIFEST_CACHE}`;
    try {
      if (fileIo.accessSync(cachedPath)) {
        const parsed = LogoResolver.parseMaintainedLogoManifest(fileIo.readTextSync(cachedPath));
        if (parsed !== null) {
          LogoResolver.maintainedLogos = parsed;
        }
      }
    } catch (error) {
      console.error(`Failed to read maintained logo manifest cache: ${JSON.stringify(error)}`);
    }
    return LogoResolver.maintainedLogos;
  }

  private static parseMaintainedLogoManifest(content: string): MaintainedLogoEntry[] | null {
    if (content.length === 0 || content.length > MAINTAINED_LOGO_MAX_TEXT_LENGTH) {
      return null;
    }
    try {
      const source = JSON.parse(content) as Record<string, Object>;
      const logoItems = source['logos'];
      if (!Array.isArray(logoItems)) {
        return null;
      }
      const entries: MaintainedLogoEntry[] = [];
      logoItems.forEach((item: Object): void => {
        if (typeof item !== 'object' || item === null || Array.isArray(item)) {
          return;
        }
        const record = item as Record<string, Object>;
        const entry = new MaintainedLogoEntry();
        entry.slug = LogoResolver.safeFilePart(LogoResolver.recordString(record, 'slug'));
        entry.brand = LogoResolver.safeMaintainedPath(LogoResolver.recordString(record, 'brand'));
        entry.light = LogoResolver.safeMaintainedPath(LogoResolver.recordString(record, 'light'));
        entry.dark = LogoResolver.safeMaintainedPath(LogoResolver.recordString(record, 'dark'));
        entry.revision = LogoResolver.safeFilePart(LogoResolver.recordString(record, 'revision') || '1');
        if (entry.revision.length === 0) {
          entry.revision = '1';
        }
        const aliases = record['aliases'];
        if (Array.isArray(aliases)) {
          aliases.forEach((alias: Object): void => {
            if (typeof alias === 'string' && alias.trim().length > 0) {
              entry.aliases.push(alias.trim().toLowerCase());
            }
          });
        }
        if (entry.slug.length > 0 && entry.brand.length > 0) {
          entries.push(entry);
        }
      });
      return entries;
    } catch (error) {
      return null;
    }
  }

  private static recordString(source: Record<string, Object>, key: string): string {
    const value = source[key];
    return typeof value === 'string' ? value.trim() : '';
  }

  private static safeMaintainedPath(path: string): string {
    if (path.length === 0 || path.startsWith('/') || path.indexOf('..') >= 0 ||
      path.indexOf('://') >= 0 || !new RegExp('^[a-zA-Z0-9_./-]+$').test(path)) {
      return '';
    }
    return path;
  }

  private static safeFilePart(value: string): string {
    return value.toLowerCase().replace(new RegExp('[^a-z0-9_-]', 'g'), '');
  }

  private static matchesMaintainedLogo(entry: MaintainedLogoEntry, issuer: string, name: string): boolean {
    const source = `${issuer} ${name}`.trim().toLowerCase();
    if (source.length === 0) {
      return false;
    }
    const issuerSlug = LogoResolver.slugify(issuer);
    const nameSlug = LogoResolver.slugify(name);
    if (entry.slug === issuerSlug || entry.slug === nameSlug) {
      return true;
    }
    for (let index = 0; index < entry.aliases.length; index++) {
      if (source.indexOf(entry.aliases[index]) >= 0) {
        return true;
      }
    }
    return false;
  }

  private static async downloadMaintainedLogo(
    context: common.UIAbilityContext,
    entry: MaintainedLogoEntry
  ): Promise<LogoResolveResult | null> {
    try {
      const brandSvg = await LogoResolver.fetchMaintainedSvg(entry.brand);
      if (brandSvg.length === 0) {
        return null;
      }
      const lightSvg = entry.light.length > 0 ? await LogoResolver.fetchMaintainedSvg(entry.light) : '';
      const darkSvg = entry.dark.length > 0 ? await LogoResolver.fetchMaintainedSvg(entry.dark) : '';
      const cacheSlug = `maintained_${LogoResolver.safeFilePart(entry.slug)}_${entry.revision}`;
      const logoUri = LogoResolver.writeSvg(context, cacheSlug, 'brand', brandSvg);
      const logoLightUri = LogoResolver.writeSvg(context, cacheSlug, 'light',
        lightSvg.length > 0 ? lightSvg : brandSvg);
      const logoDarkUri = LogoResolver.writeSvg(context, cacheSlug, 'dark',
        darkSvg.length > 0 ? darkSvg : brandSvg);
      return {
        logoUri: logoUri,
        logoLightUri: logoLightUri,
        logoDarkUri: logoDarkUri,
        logoSource: `gitcode-logo:${entry.slug}:${entry.revision}`
      };
    } catch (error) {
      console.error(`Failed to download maintained logo ${entry.slug}: ${JSON.stringify(error)}`);
      return null;
    }
  }

  private static async fetchMaintainedSvg(path: string): Promise<string> {
    const content = await LogoResolver.fetchText(`${MAINTAINED_LOGO_RAW_BASE}${path}?ref=main`);
    if (content.length === 0 || content.length > MAINTAINED_LOGO_MAX_TEXT_LENGTH) {
      return '';
    }
    const svg = content.trim();
    return svg.indexOf('<svg') >= 0 ? svg : '';
  }

  private static async fetchText(url: string): Promise<string> {
    const request = http.createHttp();
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 5000,
        readTimeout: 5000
      });
      if (response.responseCode !== 200 || typeof response.result !== 'string') {
        return '';
      }
      return response.result;
    } finally {
      request.destroy();
    }
  }

  private static writeTextFile(path: string, content: string): void {
    const file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(file.fd, content);
    } finally {
      fileIo.closeSync(file);
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
