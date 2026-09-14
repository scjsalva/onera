<script setup>
import BottomSheet from './BottomSheet.vue';
import AvatarBubble from './AvatarBubble.vue';

// Replaces the old "who's looking?" picker. You are one account now, so this
// is about your account rather than about swapping perspective.
const props = defineProps({
  user: { type: [Object, String], required: true },
  email: { type: String, default: '' },
  profilePath: { type: String, required: true },
  passwordPath: { type: String, required: true },
  recoveryPath: { type: String, required: true },
  signOutPath: { type: String, required: true },
  recoveryCodesLeft: { type: [Number, String], default: 0 },
});
defineEmits(['close']);

const me = typeof props.user === 'string' ? JSON.parse(props.user) : props.user;
const token = document.querySelector('meta[name="csrf-token"]')?.content;
const codesLeft = Number(props.recoveryCodesLeft) || 0;

const links = [
  {
    label: 'Your profile',
    hint: 'Name, email, currency, appearance',
    href: props.profilePath,
    icon: 'M16 7a4 4 0 11-8 0 4 4 0 018 0zM5 21v-1a7 7 0 0114 0v1',
  },
  {
    label: 'Change password',
    hint: 'Requires your current one',
    href: props.passwordPath,
    icon: 'M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zM8 11V7a4 4 0 118 0v4',
  },
  {
    label: 'Recovery codes',
    hint: props.email ? (codesLeft > 0 ? `${codesLeft} left` : 'None yet — generate a set')
                      : 'Needs an email first',
    href: props.recoveryPath,
    warn: codesLeft === 0 || !props.email,
    icon: 'M15 7a2 2 0 012 2m4-2a6 6 0 01-7.7 5.7L11 15H9v2H7v2H4a1 1 0 01-1-1v-2.6a1 1 0 01.3-.7l6-6A6 6 0 1121 7z',
  },
];
</script>

<template>
  <BottomSheet open :title="me.name" :subtitle="email" @close="$emit('close')">
    <ul class="divide-y divide-ink-200">
      <li v-for="link in links" :key="link.label">
        <a :href="link.href" class="flex w-full items-center gap-3 py-3 text-left transition active:scale-[0.99]">
          <span class="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-ink-200/70 text-ink-500">
            <svg class="icon-lg" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" :d="link.icon" />
            </svg>
          </span>
          <span class="min-w-0 flex-1">
            <span class="block truncate font-medium text-ink-900">{{ link.label }}</span>
            <span class="block truncate text-xs" :class="link.warn ? 'text-negative-600' : 'text-ink-500'">
              {{ link.hint }}
            </span>
          </span>
          <svg class="icon-md text-ink-400" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7" />
          </svg>
        </a>
      </li>
    </ul>

    <template #footer>
      <form :action="signOutPath" method="post" class="sheet-actions">
        <input type="hidden" name="_method" value="delete" />
        <input type="hidden" name="authenticity_token" :value="token" />
        <button type="submit" class="sheet-action sheet-action-quiet">Sign out</button>
      </form>
    </template>
  </BottomSheet>
</template>
