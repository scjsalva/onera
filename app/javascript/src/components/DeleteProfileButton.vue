<script setup>
import { ref } from 'vue';
import BottomSheet from './BottomSheet.vue';

// Removing yourself is irreversible and easy to misread as "delete all my
// expenses", so the sheet spells out both halves: what is erased, and what
// deliberately isn't.
const props = defineProps({
  action: { type: String, required: true },
  name: { type: String, required: true },
  archivedLabel: { type: String, default: 'Removed person' },
  groupCount: { type: [Number, String], default: 0 },
  expenseCount: { type: [Number, String], default: 0 },
});

const open = ref(false);
const token = document.querySelector('meta[name="csrf-token"]')?.content;

const groups = Number(props.groupCount) || 0;
const expenses = Number(props.expenseCount) || 0;
const plural = (n, word) => `${n} ${word}${n === 1 ? '' : 's'}`;
</script>

<template>
  <div>
    <div class="card card-pad">
      <p class="font-semibold text-ink-900">Delete your profile</p>
      <p class="mt-1 text-sm text-ink-500">
        Removes you from Onera without touching any money you're part of.
      </p>
      <button type="button" class="btn-danger mt-3 w-full" @click="open = true">Delete profile</button>
    </div>

    <BottomSheet :open="open" title="Delete your profile?" @close="open = false">
      <p class="text-sm text-ink-600">
        This can't be undone, and it doesn't work the way delete usually does. Here's exactly what happens.
      </p>

      <section class="mt-4">
        <h3 class="flex items-center gap-2 text-sm font-semibold text-negative-700">
          <span class="grid h-5 w-5 place-items-center rounded-full bg-negative-100">
            <svg class="h-3 w-3" fill="none" stroke="currentColor" stroke-width="3" viewBox="0 0 24 24">
              <path stroke-linecap="round" d="M6 6l12 12M18 6L6 18" />
            </svg>
          </span>
          Erased for good
        </h3>
        <ul class="mt-2 space-y-1.5 pl-7 text-sm text-ink-600">
          <li>Your name, email and birthday.</li>
          <li>You disappear from the "who's looking?" picker, the People list, and anywhere someone adds a person to a group.</li>
        </ul>
      </section>

      <section class="mt-4">
        <h3 class="flex items-center gap-2 text-sm font-semibold text-positive-700">
          <span class="grid h-5 w-5 place-items-center rounded-full bg-positive-100">
            <svg class="h-3 w-3" fill="none" stroke="currentColor" stroke-width="3" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
            </svg>
          </span>
          Kept exactly as it is
        </h3>
        <ul class="mt-2 space-y-1.5 pl-7 text-sm text-ink-600">
          <li>
            Every expense you're on<span v-if="expenses"> — {{ plural(expenses, 'expense') }}</span>, who paid, and every split.
          </li>
          <li>All payments and balances. Nothing is recalculated and nobody ends up owing a different amount.</li>
          <li v-if="groups">
            You stay in the people list of your {{ plural(groups, 'group') }}, shown as
            <span class="font-semibold text-ink-900">{{ archivedLabel }}</span>.
          </li>
        </ul>
      </section>

      <p class="mt-4 rounded-xl bg-ink-100 px-3 py-2.5 text-xs text-ink-500">
        Anyone still in a group with you will see
        <span class="font-semibold text-ink-700">{{ archivedLabel }}</span> where your name used to be. Each
        removed person keeps their own number and colour, so two of them are never mistaken for each other.
      </p>

      <template #footer>
        <form :action="action" method="post" class="flex gap-3">
          <input type="hidden" name="_method" value="delete" />
          <input type="hidden" name="authenticity_token" :value="token" />
          <button type="button" class="btn-secondary flex-1" @click="open = false">Keep my profile</button>
          <button type="submit" class="btn-danger flex-1">Yes, delete it</button>
        </form>
      </template>
    </BottomSheet>
  </div>
</template>
