<script setup>
import { ref } from 'vue';
import BottomSheet from './BottomSheet.vue';

// Voiding needs a moment's thought, so it asks - and explains that the record
// survives rather than disappearing.
defineProps({
  action: { type: String, required: true },
  description: { type: String, default: 'this expense' },
});

const open = ref(false);
const reason = ref('');
const token = document.querySelector('meta[name="csrf-token"]')?.content;
</script>

<template>
  <div class="flex-1">
    <button type="button" class="btn-danger w-full" @click="open = true">Void</button>

    <BottomSheet :open="open" title="Void this expense?" @close="open = false">
      <p class="text-sm text-ink-600">
        <span class="font-medium text-ink-900">{{ description }}</span> stays in the history and in this
        list, marked as voided. It stops counting towards anyone's balance.
      </p>

      <label class="label mt-4">Why? (optional)</label>
      <input v-model="reason" class="input" placeholder="Refunded, duplicate, entered by mistake…" />

      <template #footer>
        <form :action="action" method="post" class="flex gap-3">
          <input type="hidden" name="_method" value="patch" />
          <input type="hidden" name="authenticity_token" :value="token" />
          <input type="hidden" name="reason" :value="reason" />
          <button type="button" class="btn-secondary flex-1" @click="open = false">Keep it</button>
          <button type="submit" class="btn-danger flex-1">Void expense</button>
        </form>
      </template>
    </BottomSheet>
  </div>
</template>
