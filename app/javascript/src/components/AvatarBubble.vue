<script setup>
import { ref } from 'vue';

// Initials underneath, illustrated avatar on top. The illustration has a
// transparent background, so the initials hide once it arrives - and stay if
// it never does, which is what makes this safe to depend on.
defineProps({
  user: { type: Object, required: true },
  size: { type: String, default: 'md' },
  ring: { type: Boolean, default: false },
});

const loaded = ref(false);
const failed = ref(false);

const sizes = {
  xs: 'h-6 w-6 text-[10px]',
  sm: 'h-8 w-8 text-xs',
  md: 'h-10 w-10 text-sm',
  lg: 'h-14 w-14 text-base',
};
</script>

<template>
  <span
    :class="[
      'relative inline-flex shrink-0 select-none items-center justify-center overflow-hidden rounded-full font-semibold',
      sizes[size],
      user.tone || 'bg-brand-600',
      user.toneText || 'text-white',
      ring ? 'ring-2 ring-surface' : '',
    ]"
    :title="user.name"
  >
    <span :class="loaded ? 'invisible' : ''">{{ user.initials }}</span>
    <img
      v-if="user.avatar && !failed"
      :src="user.avatar"
      alt=""
      aria-hidden="true"
      loading="lazy"
      class="absolute inset-0 h-full w-full object-cover"
      @load="loaded = true"
      @error="failed = true"
    />
  </span>
</template>
