<script setup>
import { computed, onMounted, ref, watch } from 'vue';

// Money that settles into place. The value counts up from zero on first paint
// and eases between values afterwards, so a figure changing is something you
// notice rather than something you miss.
const props = defineProps({
  // Every numeric prop accepts a string: values set as HTML attributes always
  // arrive as one, and declaring them Number-only just logs a warning on
  // every render.
  minor: { type: [ Number, String ], required: true },
  symbol: { type: String, default: '' },
  exponent: { type: [ Number, String ], default: 2 },
  sign: { type: [ Boolean, String ], default: false },
  duration: { type: [ Number, String ], default: 700 },
});

// Props set as HTML attributes always arrive as strings - Vue does not coerce
// Number props from in-DOM templates - so every numeric prop is cast here.
// Skipping this made padStart(exponent + 1) pad to twenty-one characters.
const exponent = computed(() => Number(props.exponent) || 0);
const target = computed(() => Number(props.minor) || 0);

const shown = ref(0);
let frame = null;

function animateTo(to, from = shown.value) {
  cancelAnimationFrame(frame);

  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    shown.value = to;
    return;
  }

  const start = performance.now();
  const delta = to - from;

  const step = (now) => {
    const progress = Math.min((now - start) / (Number(props.duration) || 700), 1);
    // easeOutExpo: fast out of the gate, gentle landing.
    const eased = progress === 1 ? 1 : 1 - Math.pow(2, -10 * progress);
    shown.value = Math.round(from + delta * eased);
    if (progress < 1) frame = requestAnimationFrame(step);
  };

  frame = requestAnimationFrame(step);
}

onMounted(() => animateTo(target.value, 0));
watch(target, (value) => animateTo(value));

function format(minor) {
  const places = exponent.value;
  const negative = minor < 0;
  const digits = Math.abs(minor).toString().padStart(places + 1, '0');
  const whole = digits.slice(0, digits.length - places).replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  const fraction = places ? `.${digits.slice(-places)}` : '';
  const showPlus = props.sign && props.sign !== 'false';
  const prefix = negative ? '-' : showPlus && minor > 0 ? '+' : '';
  return `${prefix}${props.symbol}${whole}${fraction}`;
}
</script>

<template>
  <span class="tnum">{{ format(shown) }}</span>
</template>
