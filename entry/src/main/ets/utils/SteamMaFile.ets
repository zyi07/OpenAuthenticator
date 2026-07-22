import { util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';

interface SdaManifestEntry {
  encryption_iv?: string;
  encryption_salt?: string;
  filename?: string;
}

interface SdaManifest {
  encrypted?: boolean;
  entries?: SdaManifestEntry[];
}

export interface SdaEncryptionParameters {
  iv: string;
  salt: string;
}

export class SteamMaFile {
  static isEncryptedContent(content: string): boolean {
    const trimmed = content.trim();
    if (trimmed.length === 0 || trimmed.startsWith('{') || trimmed.startsWith('[')) {
      return false;
    }
    try {
      const bytes = new util.Base64Helper().decodeSync(trimmed);
      return bytes.length > 0 && bytes.length % 16 === 0;
    } catch (error) {
      return false;
    }
  }

  static isManifest(content: string): boolean {
    try {
      const parsed: SdaManifest = JSON.parse(content);
      return parsed.encrypted === true && parsed.entries !== undefined && parsed.entries.length > 0;
    } catch (error) {
      return false;
    }
  }

  static encryptionParameters(manifestContent: string, fileName: string): SdaEncryptionParameters {
    try {
      const manifest: SdaManifest = JSON.parse(manifestContent);
      if (!manifest.encrypted || !manifest.entries || manifest.entries.length === 0) {
        throw new Error('SDA manifest.json 中没有加密记录');
      }
      let selected: SdaManifestEntry | undefined = undefined;
      for (let index = 0; index < manifest.entries.length; index++) {
        const entry = manifest.entries[index];
        if (entry.filename && entry.filename.toLowerCase() === fileName.toLowerCase()) {
          selected = entry;
          break;
        }
      }
      if (!selected && manifest.entries.length === 1) {
        selected = manifest.entries[0];
      }
      if (!selected || !selected.encryption_iv || !selected.encryption_salt) {
        throw new Error('manifest.json 中未找到匹配的 maFile 加密参数');
      }
      return { iv: selected.encryption_iv, salt: selected.encryption_salt };
    } catch (error) {
      throw new Error('无法读取 SDA manifest.json：' + error.toString());
    }
  }

  static decrypt(content: string, password: string, params: SdaEncryptionParameters): string {
    if (password.length === 0) {
      throw new Error('请输入 SDA 加密密码');
    }
    const helper = new util.Base64Helper();
    const spec: cryptoFramework.PBKDF2Spec = {
      algName: 'PBKDF2',
      password: password,
      salt: helper.decodeSync(params.salt),
      iterations: 50000,
      keySize: 32
    };
    const keyData = cryptoFramework.createKdf('PBKDF2|SHA1').generateSecretSync(spec).data;
    const key = cryptoFramework.createSymKeyGenerator('AES256').convertKeySync({ data: keyData });
    const ivParams: cryptoFramework.IvParamsSpec = {
      algName: 'IvParamsSpec',
      iv: { data: helper.decodeSync(params.iv) }
    };
    const cipher = cryptoFramework.createCipher('AES256|CBC|PKCS7');
    cipher.initSync(cryptoFramework.CryptoMode.DECRYPT_MODE, key, ivParams);
    const plainData = cipher.doFinalSync({ data: helper.decodeSync(content.trim()) }).data;
    const plaintext = util.TextDecoder.create('utf-8').decodeToString(plainData).replace(/^\uFEFF/, '');
    JSON.parse(plaintext);
    return plaintext;
  }
}
