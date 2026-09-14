<script setup>
import { ref } from 'vue';

// The link is built from the current host, so it is already correct wherever
// the app happens to be running - no configured base URL to forget.
const props = defineProps({
  url: { type: String, required: true },
  refreshPath: { type: String, required: true },
});

const copied = ref(false);
const token = document.querySelector('meta[name="csrf-token"]')?.content;

async function copy() {
  try {
    await navigator.clipboard.writeText(props.url);
  } catch {
    // Clipboard is blocked in some contexts; fall back to selecting the text.
    const field = document.getElementById('invite-link-field');
    field?.select();
    document.execCommand?.('copy');
  }
  copied.value = true;
  setTimeout(() => (copied.value = false), 2400);
}

async function share() {
  if (!navigator.share) return copy();
  try {
    await navigator.share({ title: 'Join me on Onera', url: props.url });
  } catch {
    /* dismissed */
  }
}
</script>

<template>
  <div class="mt-3">
    <input
      id="invite-link-field"
      :value="url"
      readonly
      class="input tnum w-full text-xs"
      @focus="$event.target.select()"
    />

    <div class="mt-2 flex gap-2">
      <button type="button" class="btn-primary flex-1" @click="copy">
        {{ copied ? 'Copied' : 'Copy link' }}
      </button>
      <button v-if="canShare" type="button" class="btn-secondary flex-1" @click="share">Share</button>
    </div>

    <form :action="refreshPath" method="post" class="mt-2">
      <input type="hidden" name="authenticity_token" :value="token" />
      <input type="hidden" name="refresh" value="1" />
      <button type="submit" class="w-full py-2 text-xs font-medium text-ink-500 transition hover:text-ink-800">
        Replace this link
      </button>
    </form>
  </div>
</template>

<script>
export default {
  computed: {
    canShare() {
      return typeof navigator !== 'undefined' && !!navigator.share;
    },
  },
};
</script>
