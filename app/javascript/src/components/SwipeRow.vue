<script setup>
import { computed, ref } from 'vue';

// Swipe actions on a list row, the way a phone app behaves.
//
// Drag left to reveal Edit, right to reveal the destructive action. A long
// drag past the commit point fires immediately without waiting for a tap,
// which is what makes it feel like a gesture rather than a menu. Holding a
// row opens the same actions as a sheet, for anyone who would rather not
// swipe - and for pointer devices, which cannot.
const props = defineProps({
  editPath: { type: String, default: null },
  actionPath: { type: String, default: null },
  actionLabel: { type: String, default: 'Void' },
  actionTone: { type: String, default: 'danger' },
  actionMethod: { type: String, default: 'patch' },
  confirm: { type: String, default: null },
  disabled: { type: Boolean, default: false },
});

const REVEAL = 88;      // how far a row rests when opened
const COMMIT = 150;     // past this, letting go fires the action
const SLOP = 12;        // ignore tiny movements so taps still work

const offset = ref(0);
const dragging = ref(false);
const busy = ref(false);
let startX = 0;
let startY = 0;
let axis = null;
let holdTimer = null;

const emit = defineEmits(['longpress']);
const token = () => document.querySelector('meta[name="csrf-token"]')?.content;

const canEdit = computed(() => !!props.editPath && !props.disabled);
const canAct = computed(() => !!props.actionPath && !props.disabled);

const style = computed(() => ({
  transform: `translateX(${offset.value}px)`,
  transition: dragging.value ? 'none' : 'transform 0.28s cubic-bezier(0.22, 1, 0.36, 1)',
}));

function buzz(pattern = 8) {
  try {
    navigator.vibrate?.(pattern);
  } catch {
    /* not supported, and not important */
  }
}

function onTouchStart(event) {
  if (props.disabled || busy.value) return;

  startX = event.touches[0].clientX;
  startY = event.touches[0].clientY;
  axis = null;

  holdTimer = setTimeout(() => {
    if (axis === null) {
      buzz(12);
      emit('longpress');
    }
  }, 550);
}

function onTouchMove(event) {
  if (props.disabled || busy.value) return;

  const dx = event.touches[0].clientX - startX;
  const dy = event.touches[0].clientY - startY;

  // Decide once whether this is a horizontal gesture or the page scrolling.
  if (axis === null) {
    if (Math.abs(dx) < SLOP && Math.abs(dy) < SLOP) return;
    axis = Math.abs(dx) > Math.abs(dy) ? 'x' : 'y';
    clearTimeout(holdTimer);
  }

  if (axis !== 'x') return;

  dragging.value = true;
  const allowed = dx > 0 ? canAct.value : canEdit.value;
  // Resist rather than refuse, so a swipe with nothing behind it still feels
  // like a surface being pulled.
  offset.value = allowed ? dx : dx * 0.18;
}

function onTouchEnd() {
  clearTimeout(holdTimer);
  if (!dragging.value) {
    axis = null;
    return;
  }

  dragging.value = false;
  const travelled = offset.value;
  axis = null;

  if (travelled > COMMIT && canAct.value) return runAction();
  if (travelled < -COMMIT && canEdit.value) return openEdit();

  if (travelled > REVEAL / 2 && canAct.value) {
    offset.value = REVEAL;
    buzz();
    return;
  }

  if (travelled < -REVEAL / 2 && canEdit.value) {
    offset.value = -REVEAL;
    buzz();
    return;
  }

  offset.value = 0;
}

function close() {
  offset.value = 0;
}

function openEdit() {
  if (!canEdit.value) return;

  busy.value = true;
  window.location = props.editPath;
}

function runAction() {
  if (!canAct.value) return;
  if (props.confirm && !window.confirm(props.confirm)) return close();

  busy.value = true;
  buzz([ 10, 40, 10 ]);

  const form = document.createElement('form');
  form.method = 'post';
  form.action = props.actionPath;
  form.innerHTML =
    `<input name="_method" value="${props.actionMethod}">` +
    `<input name="authenticity_token" value="${token()}">`;
  document.body.appendChild(form);
  form.submit();
}

defineExpose({ close, openEdit, runAction });
</script>

<template>
  <div class="relative overflow-hidden">
    <!-- Revealed behind the row. Left edge is the destructive action, because
         that is the direction you swipe to reach it. -->
    <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center" :style="{ width: `${REVEAL}px` }">
      <button
        v-if="canAct"
        type="button"
        :class="[
          'pointer-events-auto flex h-full w-full flex-col items-center justify-center gap-1 text-xs font-semibold text-white',
          actionTone === 'danger' ? 'bg-negative-600' : 'bg-brand-600',
        ]"
        @click="runAction"
      >
        <svg class="icon-lg" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
          <circle cx="12" cy="12" r="9" />
          <path stroke-linecap="round" d="M9 9l6 6m0-6l-6 6" />
        </svg>
        {{ actionLabel }}
      </button>
    </div>

    <div class="pointer-events-none absolute inset-y-0 right-0 flex items-center" :style="{ width: `${REVEAL}px` }">
      <button
        v-if="canEdit"
        type="button"
        class="pointer-events-auto flex h-full w-full flex-col items-center justify-center gap-1 bg-ink-300 text-xs font-semibold text-ink-900"
        @click="openEdit"
      >
        <svg class="icon-lg" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round"
                d="M11 4H7a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-4M18.5 2.5a2.12 2.12 0 013 3L12 15l-4 1 1-4z" />
        </svg>
        Edit
      </button>
    </div>

    <div
      data-swipe-content
      class="relative bg-surface"
      :style="style"
      @touchstart.passive="onTouchStart"
      @touchmove.passive="onTouchMove"
      @touchend="onTouchEnd"
      @touchcancel="onTouchEnd"
    >
      <slot />
    </div>
  </div>
</template>
