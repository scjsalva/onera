<script setup>
import { onMounted, ref } from 'vue';

// Toasts teleport into one shared stack so several of them queue vertically
// rather than landing on top of each other.
const props = defineProps({
  message: { type: String, required: true },
  tone: { type: String, default: 'positive' },
  // Long enough to read a sentence, glance away, and look back.
  duration: { type: [ Number, String ], default: 15000 },
});

const visible = ref(false);
const mounted = ref(false);
let timer = null;

onMounted(() => {
  mounted.value = !!document.getElementById('toast-stack');
  requestAnimationFrame(() => (visible.value = true));
  timer = setTimeout(() => (visible.value = false), Number(props.duration) || 15000);
});

function dismiss() {
  clearTimeout(timer);
  visible.value = false;
}

const tones = {
  positive: 'bg-ink-900 text-ink-50',
  negative: 'bg-negative-600 text-ink-50 dark:text-ink-100',
};
</script>

<template>
  <Teleport v-if="mounted" to="#toast-stack">
    <Transition name="toast">
      <div v-if="visible" class="flex w-full justify-center" role="status">
        <button
          type="button"
          :class="[
            'pointer-events-auto flex max-w-md items-center gap-2.5 rounded-full px-4 py-2.5 text-left text-sm font-medium shadow-lift transition active:scale-[0.98]',
            tones[tone] || tones.positive,
          ]"
          aria-label="Dismiss"
          @click="dismiss"
        >
          <span class="grid h-5 w-5 shrink-0 place-items-center rounded-full bg-ink-50/20">
            <svg class="icon-xs" fill="none" stroke="currentColor" stroke-width="3" viewBox="0 0 24 24">
              <path v-if="tone === 'positive'" stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
              <path v-else stroke-linecap="round" d="M12 8v5m0 3.5v.01" />
            </svg>
          </span>
          {{ message }}
        </button>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.toast-enter-active {
  transition:
    transform 0.36s cubic-bezier(0.22, 1, 0.36, 1),
    opacity 0.24s ease;
}
.toast-leave-active {
  transition:
    transform 0.24s ease,
    opacity 0.24s ease;
}
.toast-enter-from,
.toast-leave-to {
  transform: translateY(-14px);
  opacity: 0;
}
</style>
