<script setup>
import AvatarBubble from './AvatarBubble.vue';

// Tap-to-toggle chips. Faster than checkboxes on a phone and reads at a glance.
defineProps({
  people: { type: Array, required: true },
  selected: { type: Array, default: () => [] },
  multiple: { type: Boolean, default: true },
});
const emit = defineEmits(['toggle']);
</script>

<template>
  <div class="flex flex-wrap gap-2">
    <button
      v-for="person in people"
      :key="person.id"
      type="button"
      :class="[
        'flex items-center gap-2 rounded-full border py-1.5 pl-1.5 pr-3.5 text-sm font-medium transition active:scale-95',
        selected.includes(person.id)
          ? 'border-brand-600 bg-brand-50 text-brand-800 shadow-sm'
          : 'border-ink-200 bg-white text-ink-600 hover:border-ink-300',
      ]"
      @click="emit('toggle', person.id)"
    >
      <AvatarBubble :user="person" size="xs" />
      {{ person.name.split(' ')[0] }}
    </button>
  </div>
</template>
