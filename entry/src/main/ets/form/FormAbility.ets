import { FormExtensionAbility, formBindingData, formInfo } from '@kit.FormKit';
import { Want, common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TokenRepository } from '../data/TokenRepository';
import { FormManager } from './FormManager';

const DOMAIN = 0x0001;
const TAG = 'FormAbility';
const REFRESH_INTERVAL_MS = 1000;

export default class FormAbility extends FormExtensionAbility {
  private refreshTimerId: number = -1;

  onCreate(want: Want): void {
    hilog.info(DOMAIN, TAG, 'onCreate');
    FormManager.init(this.context as common.Context);
    this.startRefreshTimer();
  }

  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId = want.parameters?.[formInfo.FormParam.IDENTITY_KEY] as string;
    hilog.info(DOMAIN, TAG, 'onAddForm formId=%{public}s', formId);
    FormManager.init(this.context as common.Context);
    this.startRefreshTimer();
    this.refreshFormImmediate(formId);
    setTimeout((): void => { this.refreshFormImmediate(formId); }, 300);
    setTimeout((): void => { this.refreshFormImmediate(formId); }, 1000);
    setTimeout((): void => { this.refreshFormImmediate(formId); }, 2000);
    return this.buildInitialData();
  }

  onUpdateForm(formId: string): void {
    hilog.info(DOMAIN, TAG, 'onUpdateForm formId=%{public}s', formId);
    FormManager.init(this.context as common.Context);
    this.startRefreshTimer();
    this.refreshFormImmediate(formId);
  }

  onChangeFormVisibility(newStatus: Record<string, number>): void {
    hilog.info(DOMAIN, TAG, 'onChangeFormVisibility');
    FormManager.init(this.context as common.Context);
    this.startRefreshTimer();
  }

  onFormEvent(formId: string, message: string): void {
    hilog.info(DOMAIN, TAG, 'onFormEvent formId=%{public}s msg=%{public}s', formId, message);
    this.refreshFormImmediate(formId);
  }

  onRemoveForm(formId: string): void {
    hilog.info(DOMAIN, TAG, 'onRemoveForm formId=%{public}s', formId);
    FormManager.init(this.context as common.Context);
    FormManager.removeFormId(formId);
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onDestroy');
    this.stopRefreshTimer();
  }

  private startRefreshTimer(): void {
    if (this.refreshTimerId !== -1) {
      return;
    }
    hilog.info(DOMAIN, TAG, 'startRefreshTimer');
    this.refreshTimerId = setInterval((): void => {
      FormManager.refreshAllFormsWithSnapshot();
    }, REFRESH_INTERVAL_MS);
  }

  private stopRefreshTimer(): void {
    if (this.refreshTimerId !== -1) {
      clearInterval(this.refreshTimerId);
      this.refreshTimerId = -1;
    }
  }

  private async refreshFormImmediate(formId: string): Promise<void> {
    FormManager.init(this.context as common.Context);
    await FormManager.addFormId(formId);
    let tokens = await FormManager.getCardTokenSnapshot();
    if (tokens.length === 0) {
      try {
        tokens = await TokenRepository.load(this.context);
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'TokenRepository.load failed: %{public}s', JSON.stringify(e));
      }
    }
    await FormManager.updateForm(formId, tokens);
  }

  private buildInitialData(): formBindingData.FormBindingData {
    const data: Record<string, number | string> = {};
    data['count'] = 0;
    data['t1Name'] = '加载中...';
    data['t1Code'] = ''; data['t1Remaining'] = 0; data['t1Period'] = 30; data['t1Progress'] = 0; data['t1Remark'] = ''; data['t1Type'] = '';
    data['t2Name'] = ''; data['t2Code'] = ''; data['t2Remaining'] = 0; data['t2Period'] = 30; data['t2Progress'] = 0; data['t2Remark'] = ''; data['t2Type'] = '';
    data['t3Name'] = ''; data['t3Code'] = ''; data['t3Remaining'] = 0; data['t3Period'] = 30; data['t3Progress'] = 0; data['t3Remark'] = ''; data['t3Type'] = '';
    data['t4Name'] = ''; data['t4Code'] = ''; data['t4Remaining'] = 0; data['t4Period'] = 30; data['t4Progress'] = 0; data['t4Remark'] = ''; data['t4Type'] = '';
    data['t5Name'] = ''; data['t5Code'] = ''; data['t5Remaining'] = 0; data['t5Period'] = 30; data['t5Progress'] = 0; data['t5Remark'] = ''; data['t5Type'] = '';
    data['t6Name'] = ''; data['t6Code'] = ''; data['t6Remaining'] = 0; data['t6Period'] = 30; data['t6Progress'] = 0; data['t6Remark'] = ''; data['t6Type'] = '';
    data['t7Name'] = ''; data['t7Code'] = ''; data['t7Remaining'] = 0; data['t7Period'] = 30; data['t7Progress'] = 0; data['t7Remark'] = ''; data['t7Type'] = '';
    data['t8Name'] = ''; data['t8Code'] = ''; data['t8Remaining'] = 0; data['t8Period'] = 30; data['t8Progress'] = 0; data['t8Remark'] = ''; data['t8Type'] = '';
    return formBindingData.createFormBindingData(data);
  }
}
