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

    <div class="mt-2 flex items-center gap-2">
      <button type="button" class="btn-primary flex-1" @click="canShare ? share() : copy()">
        {{ copied ? 'Copied' : canShare ? 'Share link' : 'Copy link' }}
      </button>

      <!-- Guarded: an empty action posts to whatever page this happens to be
           on, which is how this quietly submitted the wrong form. -->
      <form v-if="refreshPath" :action="refreshPath" method="post" class="shrink-0">
        <input type="hidden" name="authenticity_token" :value="token" />
        <input type="hidden" name="refresh" value="1" />
        <button
          type="submit"
          class="press grid h-[42px] w-[42px] place-items-center rounded-lg border border-ink-300 text-ink-500 transition hover:text-ink-800"
          title="Get a new link. The current one stops working."
          aria-label="Get a new link"
        >
          <svg class="icon-md" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round"
                  d="M4 4v5h5M20 20v-5h-5M20 9A8 8 0 006.3 5.3L4 8m0 7a8 8 0 0013.7 3.7L20 16" />
          </svg>
        </button>
      </form>
    </div>
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
