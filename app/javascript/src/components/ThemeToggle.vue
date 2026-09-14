<script setup>
import { onMounted, ref } from 'vue';
import { setTheme, storedTheme } from '@/lib/theme';
import SegmentedControl from './SegmentedControl.vue';

const preference = ref('system');

onMounted(() => {
  preference.value = storedTheme();
});

function choose(value) {
  preference.value = value;
  setTheme(value);
}

const options = [
  { value: 'system', label: 'System' },
  { value: 'light', label: 'Light' },
  { value: 'dark', label: 'Dark' },
];
</script>

<template>
  <div>
    <SegmentedControl :model-value="preference" :options="options" @update:model-value="choose" />
    <p class="mt-2 text-xs text-ink-500">
      <template v-if="preference === 'system'">Follows your device.</template>
      <template v-else>Always {{ preference }}, on this device.</template>
    </p>
  </div>
</template>
