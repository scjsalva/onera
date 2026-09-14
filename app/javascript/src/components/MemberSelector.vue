<script setup>
import { ref } from 'vue';
import PersonPicker from './PersonPicker.vue';

const props = defineProps({
  people: { type: [Array, String], default: () => [] },
  field: { type: String, required: true },
  newPersonPath: { type: String, default: null },
});

const list = typeof props.people === 'string' ? JSON.parse(props.people) : props.people;
const selected = ref([]);

function toggle(id) {
  const index = selected.value.indexOf(id);
  if (index >= 0) selected.value.splice(index, 1);
  else selected.value.push(id);
}
</script>

<template>
  <div>
    <PersonPicker v-if="list.length" :people="list" :selected="selected" @toggle="toggle" />
    <p v-else class="text-sm text-ink-500">Nobody else to add yet.</p>

    <input v-for="id in selected" :key="id" type="hidden" :name="field" :value="id" />

    <Transition name="fade">
      <p v-if="selected.length" class="mt-2 text-xs font-medium text-brand-600">
        {{ selected.length }} selected
      </p>
    </Transition>

    <a v-if="newPersonPath" :href="newPersonPath" class="mt-3 inline-block text-sm font-medium text-brand-600">
      Someone not listed?
    </a>
  </div>
</template>

<style scoped>
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.18s ease;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
