<script setup>
import { computed } from 'vue';
import AvatarBubble from './AvatarBubble.vue';

// The per-person split, with the server's computed share shown live beside
// each input. The bar under each row is the visual weight of that share, so
// an uneven split is obvious without reading the numbers.
const props = defineProps({
  modelValue: { type: Array, required: true },
  people: { type: Array, required: true },
  method: { type: String, default: 'equal' },
  preview: { type: Object, default: null },
  previewing: { type: Boolean, default: false },
  currency: { type: Object, default: null },
});
defineEmits(['update:modelValue']);

const hints = {
  equal: 'Everyone pays the same. Odd units go to the first people listed.',
  shares: 'Give each person a number of shares.',
  percentage: 'Percentages must add up to 100.',
  fixed: 'Exact amounts must add up to the total.',
};

const units = computed(() => {
  if (props.method === 'percentage') return '%';
  if (props.method === 'shares') return 'shares';
  return props.currency?.symbol ?? '';
});

// The unit sits inside the field, so the field has to reserve room for it.
// A fixed padding worked for "%" and "₱" but "shares" ran straight under the
// typed value. Deriving it from the label keeps every unit clear, including
// three-character symbols like CN¥.
const unitPadding = computed(() => `calc(${units.value.length}ch + 1.4rem)`);

const shares = computed(() => {
  const map = {};
  (props.preview?.splits || []).forEach((split) => (map[split.user_id] = split));
  return map;
});

const largest = computed(() => Math.max(1, ...(props.preview?.splits || []).map((s) => Math.abs(s.minor))));

function personFor(id) {
  return props.people.find((p) => p.id === id);
}
</script>

<template>
  <section v-if="modelValue.length">
    <div class="mb-2 flex items-center justify-between">
      <p class="text-xs text-ink-500">{{ hints[method] }}</p>
      <Transition name="fade">
        <span v-if="previewing" class="text-xs font-medium text-ink-400">Checking…</span>
      </Transition>
    </div>

    <ul class="divide-y divide-ink-100 overflow-hidden rounded-xl border border-ink-200">
      <li v-for="row in modelValue" :key="row.user_id" class="relative bg-white px-3 py-2.5">
        <div class="flex items-center gap-3">
          <AvatarBubble :user="personFor(row.user_id) || { name: '?', initials: '?' }" size="sm" />
          <span class="min-w-0 flex-1 truncate text-sm font-medium text-ink-800">
            {{ personFor(row.user_id)?.name }}
          </span>

          <div v-if="method !== 'equal'" class="relative" :class="method === 'shares' ? 'w-32' : 'w-28'">
            <input
              v-model="row.split_value"
              inputmode="decimal"
              placeholder="0"
              class="input tnum py-1.5 pl-2.5 text-right text-sm"
              :style="{ paddingRight: unitPadding }"
            />
            <span class="pointer-events-none absolute inset-y-0 right-2.5 flex items-center text-xs text-ink-400">
              {{ units }}
            </span>
          </div>

          <span
            v-if="shares[row.user_id]"
            class="tnum w-24 shrink-0 text-right text-sm font-semibold text-ink-900"
          >
            {{ shares[row.user_id].formatted }}
          </span>
          <span v-else-if="previewing" class="skeleton h-4 w-16 shrink-0 rounded" />
        </div>

        <!-- Weight of this person's share, drawn as a hairline. -->
        <span
          v-if="shares[row.user_id]"
          class="absolute bottom-0 left-0 h-0.5 bg-brand-400/70 transition-all duration-500"
          :style="{ width: `${(Math.abs(shares[row.user_id].minor) / largest) * 100}%` }"
        />
      </li>
    </ul>

    <Transition name="fade">
      <ul v-if="preview?.errors?.length" class="mt-2 space-y-1">
        <li v-for="error in preview.errors" :key="error" class="flex items-start gap-1.5 text-xs text-negative-600">
          <svg class="mt-0.5 h-3.5 w-3.5 shrink-0" fill="none" stroke="currentColor" stroke-width="2.2" viewBox="0 0 24 24">
            <path stroke-linecap="round" d="M12 8v5m0 3.5v.01" />
            <circle cx="12" cy="12" r="9" />
          </svg>
          {{ error }}
        </li>
      </ul>
    </Transition>
  </section>
</template>

<style scoped>
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.18s ease;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
