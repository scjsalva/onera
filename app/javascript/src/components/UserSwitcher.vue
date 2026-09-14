<script setup>
import { ref } from 'vue';
import BottomSheet from './BottomSheet.vue';
import AvatarBubble from './AvatarBubble.vue';

// Switching perspective, not signing in. Nothing here writes to the ledger.
const props = defineProps({
  currentUser: { type: [Object, String], required: true },
  users: { type: [Array, String], required: true },
  switchPath: { type: String, required: true },
  profilePath: { type: String, required: true },
  newPersonPath: { type: String, default: null },
});
defineEmits(['close']);

const parse = (value) => (typeof value === 'string' ? JSON.parse(value) : value);
const people = parse(props.users);
const me = parse(props.currentUser);
const submitting = ref(null);
const form = ref(null);
const chosen = ref(null);

function choose(user) {
  if (user.id === me.id) return;
  submitting.value = user.id;
  chosen.value = user.id;
  requestAnimationFrame(() => form.value.submit());
}

const token = document.querySelector('meta[name="csrf-token"]')?.content;

const actions = [
  props.newPersonPath && {
    label: 'Add a person',
    hint: 'Someone new to split with',
    href: props.newPersonPath,
    icon: 'M16 7a4 4 0 11-8 0 4 4 0 018 0zM5 21v-1a7 7 0 0110.5-6.06M18 14v6m3-3h-6',
  },
  {
    label: 'Your profile',
    hint: 'Name, email, birthday, currency',
    href: props.profilePath,
    icon: 'M11 4H7a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-4M18.5 2.5a2.12 2.12 0 013 3L12 15l-4 1 1-4z',
  },
].filter(Boolean);
</script>

<template>
  <BottomSheet open title="Who's looking?" subtitle="Switching only changes the view. Nothing is edited." @close="$emit('close')">
    <form ref="form" :action="switchPath" method="post">
      <input type="hidden" name="authenticity_token" :value="token" />
      <input type="hidden" name="user_id" :value="chosen" />

      <!-- People and the actions below them are one continuous list, so the
           actions read as part of the sheet rather than a bar bolted to it. -->
      <ul class="divide-y divide-ink-100">
        <li v-for="user in people" :key="user.id">
          <button
            type="button"
            class="flex w-full items-center gap-3 py-3 text-left transition active:scale-[0.99]"
            @click="choose(user)"
          >
            <AvatarBubble :user="user" />
            <span class="min-w-0 flex-1">
              <span class="block truncate font-medium text-ink-900">{{ user.name }}</span>
              <span v-if="user.id === me.id" class="text-xs font-medium text-brand-600">Currently viewing</span>
            </span>
            <svg
              v-if="submitting === user.id"
              class="h-5 w-5 animate-spin text-brand-600"
              fill="none"
              viewBox="0 0 24 24"
            >
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="3" />
              <path class="opacity-90" fill="currentColor" d="M4 12a8 8 0 018-8v3a5 5 0 00-5 5H4z" />
            </svg>
            <svg
              v-else-if="user.id === me.id"
              class="h-5 w-5 text-brand-600"
              fill="none"
              stroke="currentColor"
              stroke-width="2.5"
              viewBox="0 0 24 24"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
            </svg>
          </button>
        </li>

        <li v-for="action in actions" :key="action.label">
          <a :href="action.href" class="flex w-full items-center gap-3 py-3 text-left transition active:scale-[0.99]">
            <span class="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-ink-100 text-ink-500">
              <svg class="h-5 w-5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" :d="action.icon" />
              </svg>
            </span>
            <span class="min-w-0 flex-1">
              <span class="block truncate font-medium text-ink-900">{{ action.label }}</span>
              <span class="block truncate text-xs text-ink-500">{{ action.hint }}</span>
            </span>
            <svg class="h-4 w-4 shrink-0 text-ink-400" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7" />
            </svg>
          </a>
        </li>
      </ul>
    </form>
  </BottomSheet>
</template>
