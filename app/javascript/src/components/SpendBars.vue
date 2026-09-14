<script setup>
import { computed, onMounted, ref } from 'vue';

// Horizontal bars that grow on first view. Deliberately not a chart library:
// a proportional bar and a number is all this needs to say.
const props = defineProps({
  rows: { type: [Array, String], default: () => [] },
  symbol: { type: String, default: '' },
});

const data = typeof props.rows === 'string' ? JSON.parse(props.rows) : props.rows;
const grown = ref(false);
const max = computed(() => Math.max(1, ...data.map((row) => row.minor)));

onMounted(() => requestAnimationFrame(() => (grown.value = true)));
</script>

<template>
  <ul class="space-y-3">
    <li v-for="(row, index) in data" :key="row.label">
      <div class="mb-1 flex items-baseline justify-between gap-3 text-sm">
        <span class="truncate font-medium text-ink-700">{{ row.label }}</span>
        <span class="tnum shrink-0 font-semibold text-ink-900">{{ row.formatted }}</span>
      </div>
      <div class="h-2 overflow-hidden rounded-full bg-ink-100">
        <div
          class="h-full rounded-full bg-gradient-to-r from-brand-500 to-brand-700 transition-all duration-700"
          :style="{
            width: grown ? `${Math.max(3, (row.minor / max) * 100)}%` : '0%',
            transitionDelay: `${index * 70}ms`,
            transitionTimingFunction: 'cubic-bezier(0.22, 1, 0.36, 1)',
          }"
        />
      </div>
    </li>
  </ul>
</template>
