<script setup>
import { ref } from 'vue';
import ExpenseComposer from './ExpenseComposer.vue';

// The raised action in the middle of the tab bar. Opens the composer sheet
// rather than navigating, so adding an expense never loses your place.
const props = defineProps({
  groups: { type: [Array, String], default: () => [] },
  currencies: { type: [Array, String], default: () => [] },
  categories: { type: [Array, String], default: () => [] },
  friends: { type: [Array, String], default: () => [] },
  currentUserId: { type: [Number, String], default: null },
  // Set when the page being viewed belongs to a group, so the composer opens
  // already pointed at it.
  groupId: { type: [Number, String], default: null },
  groupName: { type: String, default: '' },
});

const open = ref(false);
</script>

<template>
  <div class="w-full">
    <button
      type="button"
      class="group absolute -top-6 left-1/2 grid h-14 w-14 -translate-x-1/2 place-items-center rounded-full bg-brand-600 text-white shadow-lift transition duration-200 active:scale-90 hover:bg-brand-700 md:static md:h-auto md:w-full md:translate-x-0 md:rounded-xl md:px-3 md:py-2.5 md:shadow-sm"
      :aria-label="groupName ? `Add an expense to ${groupName}` : 'Add an expense'"
      @click="open = true"
    >
      <span class="flex items-center gap-2">
        <svg
          class="icon-nav transition-transform duration-300 group-hover:rotate-90"
          fill="none"
          stroke="currentColor"
          stroke-width="2.4"
          viewBox="0 0 24 24"
        >
          <path stroke-linecap="round" d="M12 5v14M5 12h14" />
        </svg>
        <span class="hidden text-sm font-semibold md:inline">Add expense</span>
      </span>
    </button>

    <ExpenseComposer
      v-if="open"
      open
      :groups="groups"
      :currencies="currencies"
      :categories="categories"
      :friends="friends"
      :current-user-id="currentUserId"
      :group-id="groupId"
      @close="open = false"
    />
  </div>
</template>
