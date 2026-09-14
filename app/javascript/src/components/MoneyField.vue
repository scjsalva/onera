<script setup>
import { computed } from 'vue';

// Amount plus currency in one control. The currency menu is a native select so
// it uses the platform picker on a phone.
const props = defineProps({
  modelValue: { type: [String, Number], default: '' },
  currency: { type: String, default: 'PHP' },
  currencies: { type: Array, default: () => [] },
  autofocus: { type: Boolean, default: false },
  size: { type: String, default: 'lg' },
});
const emit = defineEmits(['update:modelValue', 'update:currency']);

const active = computed(() => props.currencies.find((c) => c.code === props.currency));

function onInput(event) {
  emit('update:modelValue', event.target.value.replace(/[^\d.]/g, ''));
}
</script>

<template>
  <div class="flex items-stretch gap-2">
    <div class="relative flex-1">
      <span
        class="pointer-events-none absolute inset-y-0 left-4 flex items-center text-ink-400"
        :class="size === 'lg' ? 'text-2xl font-semibold' : 'text-base'"
      >
        {{ active?.symbol }}
      </span>
      <input
        :value="modelValue"
        inputmode="decimal"
        placeholder="0"
        :autofocus="autofocus"
        :class="[
          'input tnum w-full',
          size === 'lg' ? 'py-3.5 pl-11 pr-4 text-2xl font-semibold' : 'py-2.5 pl-9 pr-3',
        ]"
        @input="onInput"
      />
    </div>

    <select
      :value="currency"
      class="input w-[7.25rem] shrink-0 font-medium"
      :class="size === 'lg' ? 'text-base' : 'text-sm'"
      @change="emit('update:currency', $event.target.value)"
    >
      <option v-for="option in currencies" :key="option.code" :value="option.code">
        {{ option.code }}
      </option>
    </select>
  </div>
</template>
