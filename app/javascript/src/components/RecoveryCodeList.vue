<script setup>
import { ref } from 'vue';

// Codes are readable exactly once, so copying and downloading them has to be
// effortless at this moment - there is no second chance to come back for them.
const props = defineProps({
  codes: { type: [Array, String], default: () => [] },
});

const list = typeof props.codes === 'string' ? JSON.parse(props.codes) : props.codes;
const copied = ref(false);

const asText = () => `Onera recovery codes\n\n${list.map((c, i) => `${i + 1}. ${c}`).join('\n')}\n`;

async function copy() {
  try {
    await navigator.clipboard.writeText(asText());
    copied.value = true;
    setTimeout(() => (copied.value = false), 2400);
  } catch {
    copied.value = false;
  }
}

function download() {
  const blob = new Blob([asText()], { type: 'text/plain' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = 'onera-recovery-codes.txt';
  link.click();
  URL.revokeObjectURL(url);
}
</script>

<template>
  <div>
    <ul class="mt-3 grid grid-cols-2 gap-2">
      <li
        v-for="(code, index) in list"
        :key="code"
        class="rounded-lg bg-ink-200/50 px-3 py-2 font-mono text-sm tracking-wide text-ink-900"
      >
        <span class="mr-2 text-xs text-ink-400">{{ index + 1 }}</span>{{ code }}
      </li>
    </ul>

    <div class="mt-3 flex gap-2">
      <button type="button" class="btn-secondary flex-1" @click="copy">
        {{ copied ? 'Copied' : 'Copy all' }}
      </button>
      <button type="button" class="btn-secondary flex-1" @click="download">Download</button>
    </div>
  </div>
</template>
