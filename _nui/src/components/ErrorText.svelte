<script lang="ts">
  interface Props {
    message: string | null | undefined;
  }

  let { message }: Props = $props();
</script>

{#if message}
  <p role="alert" class="animate-fade text-xs text-destructive">{message}</p>
{/if}
