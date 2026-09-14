<script setup>
import { ref } from 'vue';

// Each option previews the person's own avatar in that style, so the choice
// is made by looking rather than by reading a name.
const props = defineProps({
  styles: { type: [ Array, String ], default: () => [] },
  tones: { type: [ Array, String ], default: () => [] },
  current: { type: String, default: '' },
  currentTone: { type: [ Number, String ], default: null },
  updatePath: { type: String, required: true },
  shufflePath: { type: String, required: true },
});

const parse = (value) => (typeof value === 'string' ? JSON.parse(value) : value);
const options = parse(props.styles);
const toneOptions = parse(props.tones);

const chosenStyle = ref(props.current);
const chosenTone = ref(Number(props.currentTone) || null);
const form = ref(null);
const token = document.querySelector('meta[name="csrf-token"]')?.content;

function submit() {
  requestAnimationFrame(() => form.value.submit());
}

function chooseStyle(value) {
  chosenStyle.value = value;
  submit();
}

function chooseTone(value) {
  chosenTone.value = value;
  submit();
}
</script>

<template>
  <div>
    <form ref="form" :action="updatePath" method="post">
      <input type="hidden" name="_method" value="patch" />
      <input type="hidden" name="authenticity_token" :value="token" />
      <input type="hidden" name="avatar_style" :value="chosenStyle" />
      <input type="hidden" name="avatar_tone" :value="chosenTone ?? ''" />

      <ul class="grid grid-cols-4 gap-2 sm:grid-cols-7">
        <li v-for="option in options" :key="option.value">
          <button
            type="button"
            :class="[
              'flex w-full flex-col items-center gap-1 rounded-xl border p-2 transition active:scale-95',
              option.value === chosenStyle
                ? 'border-brand-600 bg-brand-50'
                : 'border-ink-200 hover:border-ink-300',
            ]"
            :aria-pressed="option.value === chosenStyle"
            @click="chooseStyle(option.value)"
          >
            <span
              class="grid h-10 w-10 place-items-center overflow-hidden rounded-full"
              :class="`bg-avatar-${chosenTone || 1}`"
            >
              <img :src="option.preview" :alt="option.label" class="h-10 w-10" loading="lazy" />
            </span>
            <span class="text-[10px] font-medium text-ink-600">{{ option.label }}</span>
          </button>
        </li>
      </ul>

      <p class="label mt-4">Colour</p>
      <ul class="flex flex-wrap gap-2">
        <li v-for="tone in toneOptions" :key="tone">
          <button
            type="button"
            :class="[
              'h-9 w-9 rounded-full transition active:scale-90',
              `bg-avatar-${tone}`,
              tone === chosenTone ? 'ring-2 ring-brand-600 ring-offset-2 ring-offset-surface' : '',
            ]"
            :aria-label="`Colour ${tone}`"
            :aria-pressed="tone === chosenTone"
            @click="chooseTone(tone)"
          />
        </li>
      </ul>
    </form>

    <form :action="shufflePath" method="post" class="mt-4">
      <input type="hidden" name="_method" value="patch" />
      <input type="hidden" name="authenticity_token" :value="token" />
      <button type="submit" class="btn-secondary w-full">Shuffle this style</button>
    </form>
  </div>
</template>
