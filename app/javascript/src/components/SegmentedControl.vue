<script setup>
import { computed, nextTick, ref, watch } from 'vue';

const props = defineProps({
  modelValue: { type: [String, Number], default: null },
  options: { type: Array, required: true },
  size: { type: String, default: 'md' },
});
const emit = defineEmits(['update:modelValue']);

const root = ref(null);
const indicator = ref({ left: 0, width: 0 });

const padding = computed(() => (props.size === 'sm' ? 'px-3 py-1.5 text-xs' : 'px-3.5 py-2 text-sm'));

async function reposition() {
  await nextTick();
  const active = root.value?.querySelector('[data-active="true"]');
  if (!active) return;
  indicator.value = { left: active.offsetLeft, width: active.offsetWidth };
}

watch(() => props.modelValue, reposition, { immediate: true });
watch(() => props.options, reposition, { deep: true });
</script>

<template>
  <div ref="root" class="relative flex overflow-x-auto rounded-xl bg-ink-200/70 p-1">
    <span
      class="absolute inset-y-1 rounded-lg bg-surface shadow-sm transition-all duration-300"
      :style="{ left: `${indicator.left}px`, width: `${indicator.width}px` }"
      style="transition-timing-function: cubic-bezier(0.22, 1, 0.36, 1)"
    />
    <button
      v-for="option in options"
      :key="option.value"
      type="button"
      :data-active="option.value === modelValue"
      :class="[
        'relative z-10 shrink-0 whitespace-nowrap rounded-lg font-medium transition-colors',
        padding,
        option.value === modelValue ? 'text-ink-900' : 'text-ink-500 hover:text-ink-700',
      ]"
      @click="emit('update:modelValue', option.value)"
    >
      {{ option.label }}
    </button>
  </div>
</template>
