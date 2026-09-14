<script setup>
import { computed, onBeforeUnmount, ref, watch } from 'vue';

// The workhorse container. On phones it is a sheet that rises from the bottom
// edge and can be flicked away; from `md` up the same content becomes a
// centred dialog. Everything that would otherwise be a separate page - adding
// an expense, settling up, filtering - goes in one of these.
const props = defineProps({
  open: { type: Boolean, default: false },
  title: { type: String, default: '' },
  subtitle: { type: String, default: '' },
  maxWidth: { type: String, default: 'max-w-lg' },
  dismissible: { type: Boolean, default: true },
});
const emit = defineEmits(['close']);

const dragY = ref(0);
const dragging = ref(false);
let startY = 0;

const sheetStyle = computed(() =>
  dragY.value > 0 ? { transform: `translateY(${dragY.value}px)`, transition: dragging.value ? 'none' : '' } : {}
);

function close() {
  if (props.dismissible) emit('close');
}

function onTouchStart(event) {
  if (event.target.closest('[data-no-drag]')) return;
  startY = event.touches[0].clientY;
  dragging.value = true;
}

function onTouchMove(event) {
  if (!dragging.value) return;
  dragY.value = Math.max(0, event.touches[0].clientY - startY);
}

function onTouchEnd() {
  dragging.value = false;
  if (dragY.value > 110) close();
  dragY.value = 0;
}

function onKeydown(event) {
  if (event.key === 'Escape') close();
}

watch(
  () => props.open,
  (open) => {
    document.body.style.overflow = open ? 'hidden' : '';
    if (open) window.addEventListener('keydown', onKeydown);
    else window.removeEventListener('keydown', onKeydown);
  },
  { immediate: true }
);

onBeforeUnmount(() => {
  document.body.style.overflow = '';
  window.removeEventListener('keydown', onKeydown);
});
</script>

<template>
  <Teleport to="body">
    <Transition name="sheet-backdrop" appear>
      <div v-if="open" class="scrim fixed inset-0 z-50 backdrop-blur-[2px]" @click="close" />
    </Transition>

    <Transition name="sheet" appear>
      <div
        v-if="open"
        class="fixed inset-x-0 bottom-0 z-50 flex justify-center md:inset-0 md:items-center md:p-6"
        role="dialog"
        aria-modal="true"
        @click.self="close"
      >
        <div
          :class="[
            'pointer-events-auto flex w-full flex-col overflow-hidden bg-surface shadow-lift',
            'max-h-[92dvh] rounded-t-3xl md:max-h-[86dvh] md:rounded-3xl',
            maxWidth,
          ]"
          :style="sheetStyle"
          @touchstart.passive="onTouchStart"
          @touchmove.passive="onTouchMove"
          @touchend="onTouchEnd"
        >
          <div class="shrink-0 px-5 pt-3 md:px-6">
            <div class="mx-auto mb-3 h-1.5 w-10 rounded-full bg-ink-300 md:hidden" />
            <div v-if="title" class="flex items-start justify-between gap-4 pb-3">
              <div class="min-w-0">
                <h2 class="truncate text-lg font-semibold text-ink-900">{{ title }}</h2>
                <p v-if="subtitle" class="mt-0.5 text-sm text-ink-500">{{ subtitle }}</p>
              </div>
              <button
                v-if="dismissible"
                type="button"
                data-no-drag
                class="-mr-1 -mt-1 grid h-9 w-9 shrink-0 place-items-center rounded-full text-ink-500 transition hover:bg-ink-100 active:scale-90"
                aria-label="Close"
                @click="close"
              >
                <svg class="icon-lg" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                  <path stroke-linecap="round" d="M6 6l12 12M18 6L6 18" />
                </svg>
              </button>
            </div>
          </div>

          <div data-no-drag class="min-h-0 flex-1 overflow-y-auto overscroll-contain px-5 pb-5 md:px-6">
            <slot />
          </div>

          <div v-if="$slots.footer" data-no-drag class="sheet-footer hairline-t shrink-0">
            <slot name="footer" />
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.sheet-backdrop-enter-active,
.sheet-backdrop-leave-active {
  transition: opacity 0.24s ease;
}
.sheet-backdrop-enter-from,
.sheet-backdrop-leave-to {
  opacity: 0;
}

.sheet-backdrop-appear-active {
  transition: opacity 0.24s ease;
}
.sheet-backdrop-appear-from {
  opacity: 0;
}

.sheet-appear-active > div,
.sheet-enter-active > div {
  transition: transform 0.38s cubic-bezier(0.22, 1, 0.36, 1);
}
.sheet-leave-active > div {
  transition: transform 0.24s cubic-bezier(0.4, 0, 1, 1);
}
.sheet-appear-from > div,
.sheet-enter-from > div,
.sheet-leave-to > div {
  transform: translateY(100%);
}

@media (min-width: 768px) {
  .sheet-appear-from > div,
  .sheet-enter-from > div,
  .sheet-leave-to > div {
    transform: translateY(12px) scale(0.97);
    opacity: 0;
  }
  .sheet-appear-active > div,
  .sheet-enter-active > div,
  .sheet-leave-active > div {
    transition:
      transform 0.26s cubic-bezier(0.22, 1, 0.36, 1),
      opacity 0.2s ease;
  }
}
</style>
