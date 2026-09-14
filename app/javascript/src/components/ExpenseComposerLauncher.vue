<script setup>
import { computed, ref } from 'vue';
import ExpenseComposer from './ExpenseComposer.vue';

// The raised action in the middle of the tab bar. Opens the composer sheet
// rather than navigating, so adding an expense never loses your place.
const props = defineProps({
  groups: { type: [ Array, String ], default: () => [] },
  currencies: { type: [ Array, String ], default: () => [] },
  categories: { type: [ Array, String ], default: () => [] },
  friends: { type: [ Array, String ], default: () => [] },
  currentUserId: { type: [ Number, String ], default: null },
  // Set when the page being viewed belongs to a group, so the composer opens
  // already pointed at it.
  groupId: { type: [ Number, String ], default: null },
  groupName: { type: String, default: '' },
});

const open = ref(false);

// Swipe up on the action as well as tapping it. The button follows your thumb
// and springs back if you let go early, so the gesture is found by accident
// rather than needing to be explained.
const LIFT = 56;
const pull = ref(0);
let startY = null;

// Where the button was when the sheet took over. Carrying it across means the
// launch continues the swipe instead of restarting from the resting position.
const launchedFrom = ref(0);
const phone = ref(false);

function onTouchStart(event) {
  startY = event.touches[0].clientY;
}

function onTouchMove(event) {
  if (startY === null) return;

  const travelled = startY - event.touches[0].clientY;
  pull.value = Math.max(0, Math.min(travelled, LIFT * 1.4));
}

function onTouchEnd() {
  // No haptic here: a swipe is not a tap, so Chrome blocks navigator.vibrate
  // and logs an intervention every time.
  if (pull.value >= LIFT) launch();

  pull.value = 0;
  startY = null;
}

function launch() {
  phone.value = !window.matchMedia('(min-width: 768px)').matches;
  launchedFrom.value = pull.value;
  open.value = true;
}

// Three states, and they have to read as one movement: at rest, following the
// thumb, and handing over to the sheet. The last one keeps travelling up from
// wherever the swipe ended and dissolves as the sheet arrives underneath it.
const pullStyle = computed(() => {
  if (open.value) {
    const lifted = Math.max(launchedFrom.value, LIFT) * 0.55 + 18;
    return {
      transform: phone.value
        ? `translate(-50%, ${-lifted}px) scale(0.35)`
        : 'scale(0.94)',
      opacity: 0,
      transition:
        'transform 0.34s cubic-bezier(0.32, 0, 0.2, 1), opacity 0.22s ease-out',
    };
  }

  if (pull.value) {
    return {
      transform: `translate(-50%, ${-pull.value * 0.55}px) scale(${1 + pull.value / 420})`,
      transition: 'none',
    };
  }

  // Coming back: waits for the sheet to clear, then drops into place with a
  // little overshoot so the button feels like it was thrown back.
  return {
    transition:
      'transform 0.42s cubic-bezier(0.22, 1.4, 0.4, 1) 0.08s, opacity 0.2s ease 0.08s',
  };
});

// The plus keeps turning through the launch rather than unwinding halfway.
const iconStyle = computed(() => {
  const turn = open.value ? Math.max(pull.value, LIFT) : pull.value;
  return turn ? { transform: `rotate(${turn * 1.6}deg)` } : {};
});

const label = computed(() =>
  props.groupName ? `Add an expense to ${props.groupName}` : 'Add an expense'
);
</script>

<template>
  <div class="w-full">
    <button
      type="button"
      class="group absolute -top-6 left-1/2 grid h-14 w-14 -translate-x-1/2 place-items-center rounded-full bg-brand-600 text-white shadow-lift transition duration-200 active:scale-90 hover:bg-brand-700 md:static md:h-auto md:w-full md:translate-x-0 md:rounded-xl md:px-3 md:py-2.5 md:shadow-sm"
      :aria-label="label"
      :style="pullStyle"
      @click="launch"
      @touchstart.passive="onTouchStart"
      @touchmove.passive="onTouchMove"
      @touchend="onTouchEnd"
      @touchcancel="onTouchEnd"
    >
      <span class="flex items-center gap-2">
        <svg
          class="icon-nav transition-transform duration-300 group-hover:rotate-90"
          :style="iconStyle"
          fill="none"
          stroke="currentColor"
          stroke-width="2.4"
          viewBox="0 0 24 24"
        >
          <path stroke-linecap="round" d="M12 5v14M5 12h14" />
        </svg>
        <span class="hidden text-sm font-semibold md:inline">Add expense</span>
      </span>

      <!-- A grab handle that only shows while the button is being pulled. -->
      <span
        class="pointer-events-none absolute -top-3 left-1/2 h-1 w-6 -translate-x-1/2 rounded-full bg-white/60 transition-opacity md:hidden"
        :style="{ opacity: pull && !open ? 1 : 0 }"
      />
    </button>

    <ExpenseComposer
      v-if="open"
      open
      :groups="groups"
      :currencies="currencies"
      :categories="categories"
      :friends="friends"
      :current-user-id="currentUserId"
      :group-id="groupId"
      @close="open = false"
    />
  </div>
</template>
