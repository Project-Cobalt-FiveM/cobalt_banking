<script lang="ts" module>
  interface Point {
    x: number;
    y: number;
  }

  const width = 706;
  const height = 96;
  const top = 10;
  const baseline = 88;
  const lastInset = 6;

  function plot(values: number[]): Point[] {
    const min = Math.min(...values);
    const range = Math.max(...values) - min;
    const step = width / Math.max(values.length - 1, 1);
    return values.map((value, i) => ({
      x: i * step,
      y: range === 0 ? baseline - 2 : baseline - 2 - ((value - min) / range) * (baseline - 2 - top),
    }));
  }

  function curve(points: Point[]): string {
    return points.reduce((path, point, i) => {
      const previous = points[i - 1];
      if (!previous) return `M${point.x},${point.y}`;
      const mid = (previous.x + point.x) / 2;
      return `${path} C${mid},${previous.y} ${mid},${point.y} ${point.x},${point.y}`;
    }, '');
  }

  function percent(change: number, start: number): string | null {
    if (start <= 0) return null;
    const value = (change / start) * 100;
    return `${value >= 0 ? '+' : '−'}${Math.abs(value).toFixed(1)}%`;
  }
</script>

<script lang="ts">
  import { dayLabel, formatMoney, formatSigned } from '../lib/format';
  import { t } from '../lib/locale.svelte';
  import type { History } from '../lib/types';

  interface Props {
    history: History;
    balance: number;
  }

  let { history, balance }: Props = $props();

  const points = $derived(plot(history.points));
  const line = $derived(curve(points));
  const peak = $derived(points.reduce<Point | undefined>((best, point) => (!best || point.y < best.y ? point : best), undefined));
  const last = $derived(points.at(-1));
  const change = $derived(balance - history.start);
  const pct = $derived(percent(change, history.start));
  const totals = $derived([
    [t('ui.chart.in'), history.incoming],
    [t('ui.chart.out'), history.outgoing],
  ] as const);
</script>

<div class="flex shrink-0 flex-col gap-2.5 rounded-lg border border-border px-4 pt-3.5 pb-2.5">
  <div class="flex items-end justify-between">
    <div class="flex flex-col gap-1">
      <span class="text-xs text-muted-foreground">{t('ui.chart.title')}</span>
      <div class="flex items-baseline gap-2">
        <span class="text-xl/6 font-bold text-foreground tabular-nums">{formatSigned(change)}</span>
        {#if pct}
          <span class="text-xs font-semibold tabular-nums {change >= 0 ? 'text-success' : 'text-destructive'}">{pct}</span>
        {/if}
      </div>
    </div>
    <div class="flex gap-4">
      {#each totals as [label, value] (label)}
        <div class="flex flex-col items-end gap-0.5">
          <span class="text-xs text-muted-foreground">{label}</span>
          <span class="text-13/4 font-semibold text-foreground tabular-nums">{formatMoney(value)}</span>
        </div>
      {/each}
    </div>
  </div>

  <svg viewBox="0 0 {width} {height}" class="h-24 w-full shrink-0" aria-hidden="true">
    <line x1="0" y1="8" x2={width} y2="8" stroke="#1C1C1C" />
    <line x1="0" y1="48" x2={width} y2="48" stroke="#1C1C1C" />
    <line x1="0" y1={baseline} x2={width} y2={baseline} stroke="#262626" />
    <path d="{line} L{width},{baseline} L0,{baseline} Z" fill="#1C1C1C" />
    <path d={line} fill="none" stroke="#FAFAFA" stroke-width="2" stroke-linecap="round" />
    {#if peak && peak !== last}
      <circle cx={peak.x} cy={peak.y} r="3" fill="#141414" stroke="#FAFAFA" stroke-width="2" />
    {/if}
    {#if last}
      <circle cx={last.x - lastInset} cy={last.y} r="4.5" fill="#5078D7" stroke="#141414" stroke-width="2" />
    {/if}
  </svg>

  <div class="flex justify-between">
    {#each history.points as _, i (i)}
      {@const daysAgo = history.points.length - 1 - i}
      <span class="text-11/3.5 {daysAgo === 0 ? 'font-semibold text-foreground' : 'text-muted-foreground'}">{dayLabel(daysAgo)}</span>
    {/each}
  </div>
</div>
