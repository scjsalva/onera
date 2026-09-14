<script setup>
import { onMounted, ref, watch } from 'vue';

// Money that settles into place. The value counts up from zero on first paint
// and eases between values afterwards, so a figure changing is something you
// notice rather than something you miss.
const props = defineProps({
  minor: { type: [Number, String], required: true },
  symbol: { type: String, default: '' },
  exponent: { type: Number, default: 2 },
  sign: { type: Boolean, default: false },
  duration: { type: Number, default: 700 },
});

const shown = ref(0);
let frame = null;

function animateTo(target, from = shown.value) {
  cancelAnimationFrame(frame);

  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    shown.value = target;
    return;
  }

  const start = performance.now();
  const delta = target - from;

  const step = (now) => {
    const progress = Math.min((now - start) / props.duration, 1);
    // easeOutExpo: fast out of the gate, gentle landing.
    const eased = progress === 1 ? 1 : 1 - Math.pow(2, -10 * progress);
    shown.value = Math.round(from + delta * eased);
    if (progress < 1) frame = requestAnimationFrame(step);
  };

  frame = requestAnimationFrame(step);
}

onMounted(() => animateTo(Number(props.minor), 0));
watch(() => Number(props.minor), (value) => animateTo(value));

function format(minor) {
  const negative = minor < 0;
  const digits = Math.abs(minor).toString().padStart(props.exponent + 1, '0');
  const whole = digits.slice(0, digits.length - props.exponent).replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  const fraction = props.exponent ? `.${digits.slice(-props.exponent)}` : '';
  const prefix = negative ? '-' : props.sign && minor > 0 ? '+' : '';
  return `${prefix}${props.symbol}${whole}${fraction}`;
}
</script>

<template>
  <span class="tnum">{{ format(shown) }}</span>
</template>
