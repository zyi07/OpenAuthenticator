import { FormExtensionAbility, formBindingData, formInfo } from '@kit.FormKit';
import { Want, common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TokenRepository } from '../data/TokenRepository';
import { FormManager } from './FormManager';
import { TokenRecord } from '../model/TokenRecord';

const DOMAIN = 0x0001;
const TAG = 'FormAbility';

export default class FormAbility extends FormExtensionAbility {
  onCreate(want: Want): void {
    hilog.info(DOMAIN, TAG, 'onCreate');
    FormManager.init(this.context as common.Context);
  }

  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId = want.parameters?.[formInfo.FormParam.IDENTITY_KEY] as string;
    hilog.info(DOMAIN, TAG, 'onAddForm formId=%{public}s', formId);
    FormManager.init(this.context as common.Context);
    this.refreshFormAsync(formId);
    return FormManager.buildInitialDataSync(this.context as common.Context);
  }

  onUpdateForm(formId: string): void {
    hilog.info(DOMAIN, TAG, 'onUpdateForm formId=%{public}s', formId);
    FormManager.init(this.context as common.Context);
    this.refreshFormAsync(formId);
  }

  onChangeFormVisibility(newStatus: Record<string, number>): void {
    hilog.info(DOMAIN, TAG, 'onChangeFormVisibility');
    FormManager.init(this.context as common.Context);
  }

  onFormEvent(formId: string, message: string): void {
    hilog.info(DOMAIN, TAG, 'onFormEvent formId=%{public}s msg=%{public}s', formId, message);
    FormManager.init(this.context as common.Context);
    this.refreshFormAsync(formId);
  }

  onRemoveForm(formId: string): void {
    hilog.info(DOMAIN, TAG, 'onRemoveForm formId=%{public}s', formId);
    FormManager.init(this.context as common.Context);
    FormManager.removeFormId(formId);
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onDestroy');
  }

  private async refreshFormAsync(formId: string): Promise<void> {
    FormManager.init(this.context as common.Context);
    await FormManager.addFormId(formId);
    let tokens: TokenRecord[] = await FormManager.getCardTokenSnapshot();
    if (tokens.length === 0) {
      try {
        tokens = await TokenRepository.load(this.context);
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'TokenRepository.load failed: %{public}s', JSON.stringify(e));
      }
      if (tokens.length > 0) {
        await FormManager.saveCardTokenSnapshot(tokens);
      }
    }
    await FormManager.updateForm(formId, tokens);
  }
}
