<script setup>
import { onMounted, ref } from 'vue';

const props = defineProps({
  message: { type: String, required: true },
  tone: { type: String, default: 'positive' },
});

const visible = ref(false);

onMounted(() => {
  requestAnimationFrame(() => (visible.value = true));
  setTimeout(() => (visible.value = false), 4200);
});

const tones = {
  positive: 'bg-ink-900 text-white',
  negative: 'bg-negative-600 text-white',
};
</script>

<template>
  <Teleport to="body">
    <Transition name="toast">
      <div
        v-if="visible"
        class="pointer-events-none fixed inset-x-0 top-3 z-[60] flex justify-center px-4 md:top-5"
        role="status"
      >
        <div
          :class="[
            'pointer-events-auto flex max-w-md items-center gap-2.5 rounded-full px-4 py-2.5 text-sm font-medium shadow-lift',
            tones[props.tone] || tones.positive,
          ]"
        >
          <span class="grid h-5 w-5 place-items-center rounded-full bg-white/20">
            <svg class="h-3 w-3" fill="none" stroke="currentColor" stroke-width="3" viewBox="0 0 24 24">
              <path v-if="tone === 'positive'" stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
              <path v-else stroke-linecap="round" d="M12 8v5m0 3.5v.01" />
            </svg>
          </span>
          {{ message }}
        </div>
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
