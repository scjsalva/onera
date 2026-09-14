<script setup>
import { computed, ref } from 'vue';
import SegmentedControl from './SegmentedControl.vue';
import AvatarBubble from './AvatarBubble.vue';

// Actual debts versus the fewest-transfers suggestion.
//
// Simplifying is a presentation choice: switching the toggle changes what is
// drawn and nothing else. No expense, settlement or balance is rewritten.
const props = defineProps({
  pairwise: { type: [Array, String], default: () => [] },
  simplified: { type: [Array, String], default: () => [] },
  currency: { type: String, default: '' },
});

const parse = (value) => (typeof value === 'string' ? JSON.parse(value) : value);
const actual = parse(props.pairwise);
const simple = parse(props.simplified);

const mode = ref('actual');
const rows = computed(() => (mode.value === 'actual' ? actual : simple));

const options = [
  { value: 'actual', label: `Actual (${actual.length})` },
  { value: 'simple', label: `Simplified (${simple.length})` },
];
</script>

<template>
  <div v-if="actual.length" class="mt-3">
    <SegmentedControl v-model="mode" :options="options" size="sm" />

    <TransitionGroup tag="ul" name="debt" class="mt-2 space-y-2">
      <li
        v-for="debt in rows"
        :key="`${mode}-${debt.from.id}-${debt.to.id}`"
        class="flex items-center gap-2 rounded-xl border border-ink-200 bg-white px-3 py-2.5"
      >
        <AvatarBubble :user="debt.from" size="xs" />
        <span class="min-w-0 flex-1 truncate text-sm">
          <span class="font-medium text-ink-900">{{ debt.from.name.split(' ')[0] }}</span>
          <span class="text-ink-400"> → </span>
          <span class="font-medium text-ink-900">{{ debt.to.name.split(' ')[0] }}</span>
        </span>
        <AvatarBubble :user="debt.to" size="xs" />
        <span class="tnum shrink-0 text-sm font-semibold text-ink-900">{{ debt.formatted }}</span>
      </li>
    </TransitionGroup>

    <Transition name="fade">
      <p v-if="mode === 'simple'" class="mt-2 text-xs text-ink-500">
        A suggestion for fewer transfers. Your actual debts are unchanged until payments are recorded.
      </p>
    </Transition>
  </div>
</template>

<style scoped>
.debt-move,
.debt-enter-active,
.debt-leave-active {
  transition: all 0.34s cubic-bezier(0.22, 1, 0.36, 1);
}
.debt-enter-from,
.debt-leave-to {
  opacity: 0;
  transform: translateX(-12px);
}
.debt-leave-active {
  position: absolute;
  width: 100%;
}

.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
