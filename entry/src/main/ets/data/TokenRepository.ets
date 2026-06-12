import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { sanitizeTokenRecord, TokenRecord } from '../model/TokenRecord';

const STORE_NAME: string = 'tool_2fa_tokens';
const TOKENS_KEY: string = 'tokens';

export class TokenRepository {
  static async load(context: common.UIAbilityContext): Promise<TokenRecord[]> {
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      const value = await store.get(TOKENS_KEY, '[]');

      if (typeof value !== 'string') {
        return [];
      }

      const parsedRecords = JSON.parse(value) as TokenRecord[];
      return parsedRecords.map((record: TokenRecord) => sanitizeTokenRecord(record));
    } catch (error) {
      console.error(`Failed to load token store: ${JSON.stringify(error)}`);
      return [];
    }
  }

  static async save(context: common.UIAbilityContext, records: TokenRecord[]): Promise<boolean> {
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      await store.put(TOKENS_KEY, JSON.stringify(records));
      await store.flush();
      return true;
    } catch (error) {
      console.error(`Failed to save token store: ${JSON.stringify(error)}`);
      return false;
    }
  }
}
