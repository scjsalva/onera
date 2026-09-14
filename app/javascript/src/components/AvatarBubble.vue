<script setup>
defineProps({
  user: { type: Object, required: true },
  size: { type: String, default: 'md' },
  ring: { type: Boolean, default: false },
});

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
      'inline-flex shrink-0 select-none items-center justify-center rounded-full font-semibold text-white',
      sizes[size],
      user.tone || 'bg-brand-600',
      ring ? 'ring-2 ring-surface' : '',
    ]"
    :title="user.name"
  >
    {{ user.initials }}
  </span>
</template>
