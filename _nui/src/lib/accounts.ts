import BriefcaseIcon from 'phosphor-svelte/lib/BriefcaseIcon';
import UsersThreeIcon from 'phosphor-svelte/lib/UsersThreeIcon';
import WalletIcon from 'phosphor-svelte/lib/WalletIcon';
import { t } from './locale.svelte';
import type { Account, AccountType, Recipient } from './types';

export type Icon = typeof WalletIcon;

export interface AccountGroup {
  key: string;
  titleKey: string;
  types: readonly AccountType[];
}

export const accountGroups: readonly AccountGroup[] = [
  { key: 'personal', titleKey: 'ui.group.personal', types: ['personal'] },
  { key: 'shared', titleKey: 'ui.group.shared', types: ['shared'] },
  { key: 'society', titleKey: 'ui.group.society', types: ['society'] },
];

export const accountIcons: Record<AccountType, Icon> = {
  personal: WalletIcon,
  shared: UsersThreeIcon,
  society: BriefcaseIcon,
};

export const accountName = (account: Account): string =>
  account.primary ? t('ui.account.checking') : account.label || t('ui.account.fallback');

export const accountGroup = (account: Account): string =>
  t(accountGroups.find((group) => group.types.includes(account.type))?.titleKey ?? 'ui.group.personal');

export function accountCaption(account: Account): string {
  if (account.frozen) return t('ui.account.frozen');
  if (account.primary) return t('ui.account.default');
  if (account.type === 'shared') return account.members === 1 ? t('ui.account.member_one') : t('ui.account.member_many', account.members);
  if (account.type === 'society') return t('ui.account.boss_access');
  return t('ui.group.personal');
}

export const accountLine = (account: Account): string => `${accountName(account)} · ${account.id}`;

export const recipientName = (recipient: Recipient): string => recipient.name || recipient.label || recipient.accountId;

export const recipientAccount = (recipient: Recipient): string =>
  recipient.type === 'personal' ? t('ui.account.checking') : recipient.label || t('ui.account.fallback');
