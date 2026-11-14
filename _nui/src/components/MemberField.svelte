<script lang="ts">
  import XIcon from 'phosphor-svelte/lib/XIcon';
  import { nui } from '../lib/nui';
  import { t } from '../lib/locale.svelte';
  import type { Member } from '../lib/types';
  import { focusRing, motion } from '../lib/ui';
  import ErrorText from './ErrorText.svelte';

  interface Props {
    id: string;
    members: Member[];
    maxMembers: number;
  }

  let { id, members = $bindable(), maxMembers }: Props = $props();

  let query = $state('');
  let problem = $state<string | null>(null);
  let busy = $state(false);

  const full = $derived(members.length >= maxMembers);

  async function add(): Promise<void> {
    const citizenid = query.trim();
    if (!citizenid || busy || full) return;

    if (members.some((member) => member.citizenid === citizenid)) {
      problem = t('ui.members.already');
      return;
    }

    busy = true;
    const found = await nui('findPlayer', citizenid);
    busy = false;

    if (!found) {
      problem = t('ui.members.not_found', citizenid);
      return;
    }

    problem = null;
    query = '';
    members = [...members, found];
  }

  function remove(citizenid: string): void {
    members = members.filter((member) => member.citizenid !== citizenid);
  }

  function onkeydown(event: KeyboardEvent): void {
    if (event.key !== 'Enter') return;
    event.preventDefault();
    void add();
  }
</script>

<div
  class="flex min-h-10 flex-wrap items-center gap-1.5 rounded-md border border-input px-2 py-1.5 focus-within:ring-2 focus-within:ring-cobalt {motion}"
>
  <span class="flex h-6.5 items-center gap-1.5 rounded-sm border border-border bg-muted px-2.5 text-xs">
    <span class="font-medium text-foreground">{t('ui.members.you')}</span>
    <span class="text-muted-foreground">{t('ui.members.owner')}</span>
  </span>
  {#each members as member (member.citizenid)}
    <span class="flex h-6.5 animate-fade items-center gap-1.5 rounded-sm border border-border bg-muted pr-1.5 pl-2.5 text-xs font-medium text-foreground">
      {member.name}
      <button
        type="button"
        aria-label={t('ui.members.remove', member.name)}
        onclick={() => remove(member.citizenid)}
        class="rounded-sm text-muted-foreground hover:text-foreground {focusRing} {motion}"
      >
        <XIcon size={12} weight="fill" />
      </button>
    </span>
  {/each}
  <input
    {id}
    autocomplete="off"
    maxlength={50}
    disabled={full}
    bind:value={query}
    oninput={() => (problem = null)}
    {onkeydown}
    placeholder={full ? t('ui.members.full', maxMembers) : t('ui.members.placeholder')}
    class="h-6.5 min-w-32 grow bg-transparent pl-1 text-13/4 text-foreground caret-cobalt outline-none placeholder:text-muted-foreground"
  />
</div>
<ErrorText message={problem} />
