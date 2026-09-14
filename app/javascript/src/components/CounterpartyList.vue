<script setup>
import { ref } from 'vue';
import AvatarBubble from './AvatarBubble.vue';

// Who you owe and who owes you, netted across groups. Tapping a person
// expands the per-group breakdown in place rather than navigating away.
const props = defineProps({
  people: { type: [Array, String], default: () => [] },
});

const rows = typeof props.people === 'string' ? JSON.parse(props.people) : props.people;
const expanded = ref(null);

function toggle(id) {
  expanded.value = expanded.value === id ? null : id;
}
</script>

<template>
  <ul class="card divide-y divide-ink-100 overflow-hidden">
    <li v-for="person in rows" :key="person.id">
      <button
        type="button"
        class="press flex w-full items-center gap-3 px-4 py-3 text-left transition hover:bg-ink-50"
        @click="toggle(person.id)"
      >
        <AvatarBubble :user="person" size="sm" />
        <span class="min-w-0 flex-1">
          <span class="block truncate font-medium text-ink-900">{{ person.name }}</span>
          <span class="text-xs text-ink-500">
            {{ person.net_minor > 0 ? 'owes you' : 'you owe' }}
            · {{ person.breakdown.length }} {{ person.breakdown.length === 1 ? 'group' : 'groups' }}
          </span>
        </span>
        <span
          class="tnum shrink-0 font-semibold"
          :class="person.net_minor > 0 ? 'text-positive-600' : 'text-negative-600'"
        >
          {{ person.formatted.replace('-', '') }}
        </span>
        <svg
          class="icon-md shrink-0 text-ink-400 transition-transform duration-300"
          :class="expanded === person.id ? 'rotate-180' : ''"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          viewBox="0 0 24 24"
        >
          <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      <Transition name="expand">
        <div v-if="expanded === person.id" class="overflow-hidden bg-ink-50">
          <dl class="divide-y divide-ink-100 px-4">
            <div v-for="line in person.breakdown" :key="line.group" class="flex justify-between py-2 text-sm">
              <dt class="text-ink-600">{{ line.group }}</dt>
              <dd class="tnum font-medium" :class="line.minor > 0 ? 'text-positive-600' : 'text-negative-600'">
                {{ line.formatted }}
              </dd>
            </div>
          </dl>
          <p class="px-4 pb-3 pt-1 text-xs text-ink-400">
            Shown together for convenience. Each group's ledger stays separate.
          </p>
        </div>
      </Transition>
    </li>
  </ul>
</template>

<style scoped>
.expand-enter-active,
.expand-leave-active {
  transition:
    grid-template-rows 0.28s cubic-bezier(0.22, 1, 0.36, 1),
    opacity 0.2s ease;
  display: grid;
  grid-template-rows: 1fr;
}
.expand-enter-from,
.expand-leave-to {
  grid-template-rows: 0fr;
  opacity: 0;
}
.expand-enter-active > *,
.expand-leave-active > * {
  overflow: hidden;
}
</style>
