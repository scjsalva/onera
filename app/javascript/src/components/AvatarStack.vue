<script setup>
import { computed } from 'vue';
import AvatarBubble from './AvatarBubble.vue';

const props = defineProps({
  users: { type: Array, default: () => [] },
  limit: { type: Number, default: 4 },
  size: { type: String, default: 'sm' },
});

const shown = computed(() => props.users.slice(0, props.limit));
const overflow = computed(() => Math.max(0, props.users.length - props.limit));
</script>

<template>
  <span class="flex items-center -space-x-2">
    <AvatarBubble v-for="user in shown" :key="user.id" :user="user" :size="size" ring />
    <span
      v-if="overflow"
      class="inline-flex h-8 w-8 items-center justify-center rounded-full bg-ink-200 text-xs font-semibold text-ink-600 ring-2 ring-surface"
    >
      +{{ overflow }}
    </span>
  </span>
</template>
