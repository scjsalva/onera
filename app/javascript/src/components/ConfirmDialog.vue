<script setup>
import { ref } from 'vue';
import BottomSheet from './BottomSheet.vue';

// One dialog for the whole app. Any form carrying data-confirm is paused,
// asked about here, and only then submitted.
//
// This replaces data-turbo-confirm, which did nothing at all: there is no
// Turbo in this app, so every destructive action went through unchallenged.
const open = ref(false);
const message = ref('');
const detail = ref('');
const confirmLabel = ref('Yes, do it');
const tone = ref('danger');
let pendingForm = null;

function ask(form) {
  pendingForm = form;
  message.value = form.dataset.confirm || 'Are you sure?';
  detail.value = form.dataset.confirmDetail || '';
  confirmLabel.value = form.dataset.confirmLabel || 'Yes, do it';
  tone.value = form.dataset.confirmTone || 'danger';
  open.value = true;
}

function cancel() {
  open.value = false;
  pendingForm = null;
}

function proceed() {
  const form = pendingForm;
  open.value = false;
  pendingForm = null;
  if (!form) return;

  // Marked so the interceptor lets it through the second time.
  form.dataset.confirmed = 'true';
  form.requestSubmit ? form.requestSubmit() : form.submit();
}

document.addEventListener(
  'submit',
  (event) => {
    const form = event.target;
    if (!form.dataset?.confirm || form.dataset.confirmed === 'true') return;

    event.preventDefault();
    event.stopPropagation();
    ask(form);
  },
  true
);
</script>

<template>
  <BottomSheet :open="open" :title="message" @close="cancel">
    <p v-if="detail" class="text-sm text-ink-600">{{ detail }}</p>

    <template #footer>
      <div class="sheet-actions">
        <button type="button" class="sheet-action sheet-action-quiet" @click="cancel">Cancel</button>
        <button
          type="button"
          :class="['sheet-action', tone === 'danger' ? 'sheet-action-danger' : 'sheet-action-primary']"
          @click="proceed"
        >
          {{ confirmLabel }}
        </button>
      </div>
    </template>
  </BottomSheet>
</template>
