import { common } from '@kit.AbilityKit';
import { formBindingData, formProvider } from '@kit.FormKit';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { sanitizeTokenRecord, TokenRecord } from '../model/TokenRecord';
import { Totp } from '../utils/Totp';

const DOMAIN = 0x0001;
const TAG = 'FormManager';
const PREFS_NAME = 'tool_2fa_forms';
const FORM_IDS_KEY = 'formIds';
const CARD_TOKEN_IDS_KEY = 'cardTokenIds';
const CARD_TOKEN_SNAPSHOT_KEY = 'cardTokenSnapshot';
const MAX_SLOTS = 8;

export class FormManager {
  private static context: common.Context | null = null;

  static init(context: common.Context): void {
    FormManager.context = context.getApplicationContext();
  }

  static async addFormId(formId: string): Promise<void> {
    try {
      const ids = await FormManager.getFormIds();
      if (!ids.includes(formId)) {
        ids.push(formId);
        await FormManager.saveFormIds(ids);
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'addFormId failed: %{public}s', JSON.stringify(error));
    }
  }

  static async removeFormId(formId: string): Promise<void> {
    try {
      const ids = await FormManager.getFormIds();
      const filtered = ids.filter((id: string) => id !== formId);
      await FormManager.saveFormIds(filtered);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'removeFormId failed: %{public}s', JSON.stringify(error));
    }
  }

  static async getFormIds(): Promise<string[]> {
    if (!FormManager.context) {
      return [];
    }
    try {
      const store = await preferences.getPreferences(FormManager.context, { name: PREFS_NAME });
      const value = await store.get(FORM_IDS_KEY, '[]');
      const json = typeof value === 'string' ? value : '[]';
      return JSON.parse(json) as string[];
    } catch (error) {
      return [];
    }
  }

  private static async saveFormIds(ids: string[]): Promise<void> {
    if (!FormManager.context) {
      return;
    }
    const store = await preferences.getPreferences(FormManager.context, { name: PREFS_NAME });
    await store.put(FORM_IDS_KEY, JSON.stringify(ids));
    await store.flush();
  }

  static async getCardTokenIds(): Promise<string[]> {
    if (!FormManager.context) {
      return [];
    }
    try {
      const store = await preferences.getPreferences(FormManager.context, { name: PREFS_NAME });
      const value = await store.get(CARD_TOKEN_IDS_KEY, '[]');
      const json = typeof value === 'string' ? value : '[]';
      return JSON.parse(json) as string[];
    } catch (error) {
      return [];
    }
  }

  static async setCardTokenIds(ids: string[]): Promise<void> {
    if (!FormManager.context) {
      return;
    }
    const store = await preferences.getPreferences(FormManager.context, { name: PREFS_NAME });
    await store.put(CARD_TOKEN_IDS_KEY, JSON.stringify(ids));
    await store.flush();
  }

  static async getCardTokenSnapshot(): Promise<TokenRecord[]> {
    if (!FormManager.context) {
      return [];
    }
    try {
      const store = await preferences.getPreferences(FormManager.context, { name: PREFS_NAME });
      const value = await store.get(CARD_TOKEN_SNAPSHOT_KEY, '[]');
      const json = typeof value === 'string' ? value : '[]';
      const records = JSON.parse(json) as TokenRecord[];
      return records.map((record: TokenRecord) => sanitizeTokenRecord(record));
    } catch (error) {
      return [];
    }
  }

  static async saveCardTokenSnapshot(tokens: TokenRecord[]): Promise<void> {
    if (!FormManager.context) {
      return;
    }
    try {
      const store = await preferences.getPreferences(FormManager.context, { name: PREFS_NAME });
      await store.put(CARD_TOKEN_SNAPSHOT_KEY, JSON.stringify(tokens));
      await store.flush();
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'saveSnapshot failed: %{public}s', JSON.stringify(error));
    }
  }

  static async updateAllForms(allTokens: TokenRecord[]): Promise<void> {
    await FormManager.saveCardTokenSnapshot(allTokens);
    const formIds = await FormManager.getFormIds();
    if (formIds.length === 0) {
      return;
    }
    const selected = await FormManager.selectedTokens(allTokens);
    const formData = FormManager.buildFormData(selected);
    for (const formId of formIds) {
      try {
        await formProvider.updateForm(formId, formBindingData.createFormBindingData(formData));
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'updateAllForms formId=%{public}s err=%{public}s', formId, JSON.stringify(error));
      }
    }
  }

  static async updateForm(formId: string, allTokens: TokenRecord[]): Promise<void> {
    const selected = await FormManager.selectedTokens(allTokens);
    const formData = FormManager.buildFormData(selected);
    try {
      await formProvider.updateForm(formId, formBindingData.createFormBindingData(formData));
      hilog.info(DOMAIN, TAG, 'updateForm ok formId=%{public}s count=%{public}d time=%{public}d', formId, selected.length, Date.now());
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'updateForm formId=%{public}s err=%{public}s', formId, JSON.stringify(error));
    }
  }

  static async refreshAllFormsWithSnapshot(): Promise<void> {
    const formIds = await FormManager.getFormIds();
    if (formIds.length === 0) {
      return;
    }
    const tokens = await FormManager.getCardTokenSnapshot();
    if (tokens.length === 0) {
      return;
    }
    const selected = await FormManager.selectedTokens(tokens);
    const formData = FormManager.buildFormData(selected);
    for (const formId of formIds) {
      try {
        await formProvider.updateForm(formId, formBindingData.createFormBindingData(formData));
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'refreshAll formId=%{public}s err=%{public}s', formId, JSON.stringify(error));
      }
    }
  }

  private static async selectedTokens(allTokens: TokenRecord[]): Promise<TokenRecord[]> {
    const selectedIds = await FormManager.getCardTokenIds();
    const result: TokenRecord[] = [];
    for (const id of selectedIds) {
      const token = allTokens.find((t: TokenRecord) => t.id === id);
      if (token) {
        result.push(token);
      }
    }
    if (result.length === 0 && allTokens.length > 0) {
      result.push(...allTokens.slice(0, MAX_SLOTS));
    }
    return result.slice(0, MAX_SLOTS);
  }

  static getSnapshotSync(context: common.Context): TokenRecord[] {
    try {
      const store = preferences.getPreferencesSync(context.getApplicationContext(), { name: PREFS_NAME });
      const value = store.getSync(CARD_TOKEN_SNAPSHOT_KEY, '[]');
      const json = typeof value === 'string' ? value : '[]';
      const records = JSON.parse(json) as TokenRecord[];
      return records.map((r: TokenRecord) => sanitizeTokenRecord(r));
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'getSnapshotSync failed: %{public}s', JSON.stringify(e));
      return [];
    }
  }

  private static getCardTokenIdsSync(context: common.Context): string[] {
    try {
      const store = preferences.getPreferencesSync(context.getApplicationContext(), { name: PREFS_NAME });
      const value = store.getSync(CARD_TOKEN_IDS_KEY, '[]');
      const json = typeof value === 'string' ? value : '[]';
      return JSON.parse(json) as string[];
    } catch (e) {
      return [];
    }
  }

  private static selectedTokensSync(context: common.Context, allTokens: TokenRecord[]): TokenRecord[] {
    const selectedIds = FormManager.getCardTokenIdsSync(context);
    const result: TokenRecord[] = [];
    for (const id of selectedIds) {
      const token = allTokens.find((t: TokenRecord) => t.id === id);
      if (token) {
        result.push(token);
      }
    }
    if (result.length === 0 && allTokens.length > 0) {
      result.push(...allTokens.slice(0, MAX_SLOTS));
    }
    return result.slice(0, MAX_SLOTS);
  }

  static buildInitialDataSync(context: common.Context): formBindingData.FormBindingData {
    const tokens = FormManager.getSnapshotSync(context);
    if (tokens.length > 0) {
      const selected = FormManager.selectedTokensSync(context, tokens);
      return formBindingData.createFormBindingData(FormManager.buildFormData(selected));
    }
    const data: Record<string, number | string> = {};
    data['count'] = 0;
    data['t1Name'] = '加载中...';
    for (let index = 1; index <= 8; index++) {
      data[`t${index}Code`] = '';
      data[`t${index}Remaining`] = 0;
      data[`t${index}Period`] = 30;
      data[`t${index}Progress`] = 0;
      data[`t${index}Remark`] = '';
      data[`t${index}Type`] = '';
      if (index > 1) {
        data[`t${index}Name`] = '';
      }
    }
    return formBindingData.createFormBindingData(data);
  }

  static buildFormData(tokens: TokenRecord[]): Record<string, number | string> {
    const data: Record<string, number | string> = {};
    const now = Date.now();
    data['count'] = Math.min(tokens.length, MAX_SLOTS);

    for (let i = 0; i < MAX_SLOTS; i++) {
      const idx = i + 1;
      if (i < tokens.length) {
        const token = sanitizeTokenRecord(tokens[i]);
        const period = token.type === 'HOTP' ? 30 : (token.period === 60 ? 60 : 30);
        const digits = token.type === 'Steam' ? 5 : (token.digits ?? 6);
        const code = Totp.formatCode(Totp.generate(
          token.secret, now, token.algorithm, digits, period, token.type, token.counter ?? 0
        ));
        const seconds = Math.floor(now / 1000);
        const elapsed = seconds % period;
        const remaining = period - elapsed;
        const progress = (remaining / period) * 100;

        data[`t${idx}Name`] = token.name;
        data[`t${idx}Remark`] = token.remark;
        data[`t${idx}Code`] = code;
        data[`t${idx}Remaining`] = remaining;
        data[`t${idx}Period`] = period;
        data[`t${idx}Progress`] = progress;
        data[`t${idx}Type`] = token.type;
      } else {
        data[`t${idx}Name`] = '';
        data[`t${idx}Remark`] = '';
        data[`t${idx}Code`] = '';
        data[`t${idx}Remaining`] = 0;
        data[`t${idx}Period`] = 30;
        data[`t${idx}Progress`] = 0;
        data[`t${idx}Type`] = '';
      }
    }
    return data;
  }
}
