<script setup>
import { computed, onMounted, ref } from 'vue';

// Six columns that grow from the baseline on first view.
const props = defineProps({
  rows: { type: [Array, String], default: () => [] },
});

const data = typeof props.rows === 'string' ? JSON.parse(props.rows) : props.rows;
const grown = ref(false);
const active = ref(null);
const max = computed(() => Math.max(1, ...data.map((row) => row.minor)));

onMounted(() => requestAnimationFrame(() => (grown.value = true)));
</script>

<template>
  <div>
    <div class="flex h-36 items-end gap-2">
      <button
        v-for="(row, index) in data"
        :key="row.label"
        type="button"
        class="group flex h-full flex-1 flex-col justify-end"
        @click="active = active === index ? null : index"
      >
        <span
          class="mb-1 block text-center text-[10px] font-semibold text-ink-500 transition-opacity"
          :class="active === index ? 'opacity-100' : 'opacity-0 group-hover:opacity-100'"
        >
          {{ row.formatted }}
        </span>
        <span
          class="block w-full rounded-t-lg transition-all duration-700"
          :class="active === index ? 'bg-brand-700' : 'bg-brand-400 group-hover:bg-brand-500'"
          :style="{
            height: grown ? `${Math.max(4, (row.minor / max) * 100)}%` : '0%',
            transitionDelay: `${index * 60}ms`,
            transitionTimingFunction: 'cubic-bezier(0.22, 1, 0.36, 1)',
          }"
        />
      </button>
    </div>
    <div class="mt-2 flex gap-2">
      <span v-for="row in data" :key="row.label" class="flex-1 text-center text-[11px] text-ink-500">
        {{ row.label }}
      </span>
    </div>
  </div>
</template>
