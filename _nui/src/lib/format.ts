import { t } from './locale.svelte';

const money = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' });
const wholeMoney = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 });
const whole = new Intl.NumberFormat('en-US', { maximumFractionDigits: 0 });
const clock = new Intl.DateTimeFormat('en-GB', { hour: '2-digit', minute: '2-digit' });
const weekday = new Intl.DateTimeFormat('en-US', { weekday: 'short' });
const shortDate = new Intl.DateTimeFormat('en-US', { day: 'numeric', month: 'short' });

const dayMs = 86400000;

export const formatMoney = (value: number): string => money.format(value);

export const formatWholeMoney = (value: number): string => wholeMoney.format(value);

export const formatSigned = (value: number): string => `${value < 0 ? '−' : '+'}${money.format(Math.abs(value))}`;

export const formatDigits = (value: number): string => whole.format(value);

export function parseDigits(raw: string): number {
  const digits = raw.replace(/\D/g, '').slice(0, 10);
  return digits === '' ? 0 : Number(digits);
}

export function dayLabel(daysAgo: number): string {
  if (daysAgo === 0) return t('ui.time.today');
  const date = new Date();
  date.setDate(date.getDate() - daysAgo);
  return weekday.format(date);
}

export function formatWhen(timestamp: string): string {
  const date = new Date(timestamp);
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const days = Math.round((today.getTime() - new Date(date).setHours(0, 0, 0, 0)) / dayMs);
  const time = clock.format(date);
  if (days === 0) return t('ui.time.today_at', time);
  if (days === 1) return t('ui.time.yesterday_at', time);
  if (days < 7) return t('ui.time.day_at', weekday.format(date), time);
  return t('ui.time.day_at', shortDate.format(date), time);
}

export const initials = (name: string): string =>
  name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part.charAt(0).toUpperCase())
    .join('');
