<script setup>
import { ref } from 'vue';
import ExpenseComposer from './ExpenseComposer.vue';

// The raised action in the middle of the tab bar. Opens the composer sheet
// rather than navigating, so adding an expense never loses your place.
defineProps({
  groups: { type: [Array, String], default: () => [] },
});

const open = ref(false);
</script>

<template>
  <div class="w-full">
    <button
      type="button"
      class="group absolute -top-6 left-1/2 grid h-14 w-14 -translate-x-1/2 place-items-center rounded-full bg-brand-600 text-white shadow-lift transition duration-200 active:scale-90 hover:bg-brand-700 md:static md:h-auto md:w-full md:translate-x-0 md:rounded-xl md:px-3 md:py-2.5 md:shadow-sm"
      aria-label="Add an expense"
      @click="open = true"
    >
      <span class="flex items-center gap-2">
        <svg
          class="h-7 w-7 transition-transform duration-300 group-hover:rotate-90 md:h-5 md:w-5"
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

    <ExpenseComposer v-if="open" :groups="groups" open @close="open = false" />
  </div>
</template>
