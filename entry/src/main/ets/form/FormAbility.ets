import { FormExtensionAbility, formBindingData, formInfo } from '@kit.FormKit';
import { Want, common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TokenRepository } from '../data/TokenRepository';
import { FormManager } from './FormManager';

const DOMAIN = 0x0001;
const TAG = 'FormAbility';

export default class FormAbility extends FormExtensionAbility {

  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId = want.parameters?.[formInfo.FormParam.IDENTITY_KEY] as string;
    hilog.info(DOMAIN, TAG, 'onAddForm formId=%{public}s', formId);
    this.refreshForm(formId);
    setTimeout((): void => {
      this.refreshForm(formId);
    }, 500);
    return formBindingData.createFormBindingData({
      count: 0,
      t1Name: '加载中...',
      t1Code: '',
      t1Remaining: 0,
      t1Period: 30,
      t1Progress: 0,
      t1Remark: '',
      t1Type: '',
      t2Name: '',
      t2Code: '',
      t2Remaining: 0,
      t2Period: 30,
      t2Progress: 0,
      t2Remark: '',
      t2Type: '',
      t3Name: '',
      t3Code: '',
      t3Remaining: 0,
      t3Period: 30,
      t3Progress: 0,
      t3Remark: '',
      t3Type: '',
      t4Name: '',
      t4Code: '',
      t4Remaining: 0,
      t4Period: 30,
      t4Progress: 0,
      t4Remark: '',
      t4Type: '',
      t5Name: '',
      t5Code: '',
      t5Remaining: 0,
      t5Period: 30,
      t5Progress: 0,
      t5Remark: '',
      t5Type: '',
      t6Name: '',
      t6Code: '',
      t6Remaining: 0,
      t6Period: 30,
      t6Progress: 0,
      t6Remark: '',
      t6Type: '',
      t7Name: '',
      t7Code: '',
      t7Remaining: 0,
      t7Period: 30,
      t7Progress: 0,
      t7Remark: '',
      t7Type: '',
      t8Name: '',
      t8Code: '',
      t8Remaining: 0,
      t8Period: 30,
      t8Progress: 0,
      t8Remark: '',
      t8Type: ''
    });
  }

  onCastToNormalForm(formId: string): void {
    hilog.info(DOMAIN, TAG, 'onCastToNormalForm formId=%{public}s', formId);
  }

  onUpdateForm(formId: string): void {
    hilog.info(DOMAIN, TAG, 'onUpdateForm formId=%{public}s', formId);
    this.refreshForm(formId);
  }

  onChangeFormVisibility(newStatus: Record<string, number>): void {
    hilog.info(DOMAIN, TAG, 'onChangeFormVisibility');
  }

  onFormEvent(formId: string, message: string): void {
    hilog.info(DOMAIN, TAG, 'onFormEvent formId=%{public}s message=%{public}s', formId, message);
    this.refreshForm(formId);
  }

  onRemoveForm(formId: string): void {
    hilog.info(DOMAIN, TAG, 'onRemoveForm formId=%{public}s', formId);
    FormManager.init(this.context as common.Context);
    FormManager.removeFormId(formId);
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }

  private async refreshForm(formId: string): Promise<void> {
    FormManager.init(this.context as common.Context);
    await FormManager.addFormId(formId);
    let tokens = await FormManager.getCardTokenSnapshot();
    if (tokens.length === 0) {
      tokens = await TokenRepository.load(this.context);
    }
    await FormManager.updateForm(formId, tokens);
  }
}
