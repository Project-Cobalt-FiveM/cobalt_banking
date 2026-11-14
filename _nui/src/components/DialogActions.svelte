<script lang="ts">
  import Button from './Button.svelte';
  import { t } from '../lib/locale.svelte';

  interface Props {
    label: string;
    disabled: boolean;
    onclose: () => void;
  }

  let { label, disabled, onclose }: Props = $props();
</script>

<Button onclick={onclose}>{t('ui.dialog.cancel')}</Button>
<Button type="submit" tone="primary" {disabled}>{label}</Button>
