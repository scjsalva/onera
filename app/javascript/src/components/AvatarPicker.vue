<script setup>
import { ref } from 'vue';

// Each option previews the person's own avatar in that style, so the choice
// is made by looking rather than by reading a name.
const props = defineProps({
  styles: { type: [ Array, String ], default: () => [] },
  current: { type: String, default: '' },
  updatePath: { type: String, required: true },
  shufflePath: { type: String, required: true },
});

const options = typeof props.styles === 'string' ? JSON.parse(props.styles) : props.styles;
const chosen = ref(props.current);
const form = ref(null);
const token = document.querySelector('meta[name="csrf-token"]')?.content;

function choose(value) {
  chosen.value = value;
  requestAnimationFrame(() => form.value.submit());
}
</script>

<template>
  <div>
    <form ref="form" :action="updatePath" method="post">
      <input type="hidden" name="_method" value="patch" />
      <input type="hidden" name="authenticity_token" :value="token" />
      <input type="hidden" name="avatar_style" :value="chosen" />

      <ul class="grid grid-cols-4 gap-2 sm:grid-cols-7">
        <li v-for="option in options" :key="option.value">
          <button
            type="button"
            :class="[
              'flex w-full flex-col items-center gap-1 rounded-xl border p-2 transition active:scale-95',
              option.value === chosen
                ? 'border-brand-600 bg-brand-50'
                : 'border-ink-200 hover:border-ink-300',
            ]"
            :aria-pressed="option.value === chosen"
            @click="choose(option.value)"
          >
            <img :src="option.preview" :alt="option.label" class="h-10 w-10" loading="lazy" />
            <span class="text-[10px] font-medium text-ink-600">{{ option.label }}</span>
          </button>
        </li>
      </ul>
    </form>

    <form :action="shufflePath" method="post" class="mt-3">
      <input type="hidden" name="_method" value="patch" />
      <input type="hidden" name="authenticity_token" :value="token" />
      <button type="submit" class="btn-secondary w-full">Shuffle this style</button>
    </form>
  </div>
</template>
