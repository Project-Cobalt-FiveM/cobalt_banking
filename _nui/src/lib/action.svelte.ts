import { t } from './locale.svelte';
import { nui, type CallbackArgs, type CallbackResult } from './nui';
import type { ActionName } from './types';

export type ActionSuccess<K extends ActionName> = Extract<CallbackResult<K>, { ok: true }>;

export interface Action<K extends ActionName> {
  readonly busy: boolean;
  readonly error: string | null;
  submit(args: CallbackArgs<K>): Promise<void>;
}

function isSuccess<T extends { ok: boolean }>(result: T): result is Extract<T, { ok: true }> {
  return result.ok;
}

export function createAction<K extends ActionName>(name: K, onSuccess: (result: ActionSuccess<K>) => void): Action<K> {
  let busy = $state(false);
  let error = $state<string | null>(null);

  return {
    get busy() {
      return busy;
    },
    get error() {
      return error;
    },
    async submit(args) {
      if (busy) return;

      busy = true;
      error = null;
      const result = await nui(name, args);
      busy = false;

      if (!result) {
        error = t('ui.error.no_answer');
        return;
      }

      if (!result.ok) {
        error = result.error;
        return;
      }

      if (isSuccess(result)) onSuccess(result);
    },
  };
}
