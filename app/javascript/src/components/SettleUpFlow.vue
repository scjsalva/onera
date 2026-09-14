<script setup>
import { computed, reactive, ref } from 'vue';
import SegmentedControl from './SegmentedControl.vue';
import AvatarBubble from './AvatarBubble.vue';
import BottomSheet from './BottomSheet.vue';

// The settle-up decision, and the only place a conversion becomes binding.
//
// Two ways out of a group that has spent in more than one currency:
//   - "Each currency" pays every ledger in its own currency and converts
//     nothing at all;
//   - "One currency" picks a target, locks a rate per currency onto the
//     underlying expenses, and collapses everything into one figure.
//
// Converting is optional and it is never done behind anyone's back.
const props = defineProps({
  group: { type: [Object, String], required: true },
  currencies: { type: [Array, String], default: () => [] },
  targetCurrency: { type: String, required: true },
  perCurrency: { type: [Array, String], default: () => [] },
  consolidated: { type: [Object, String], required: true },
  settlePath: { type: String, required: true },
  recordPath: { type: String, required: true },
  reloadPath: { type: String, required: true },
});

const parse = (value) => (typeof value === 'string' ? JSON.parse(value) : value);
const group = parse(props.group);
const currencyList = parse(props.currencies);
const buckets = parse(props.perCurrency);
const summary = parse(props.consolidated);

const mode = ref(buckets.length > 1 ? 'each' : 'one');
const target = ref(props.targetCurrency);
const confirming = ref(false);

// Rates start at whatever the server suggested and are the user's to change.
const rates = reactive(Object.fromEntries(summary.lines.map((line) => [line.currency.code, line.rate])));

const modes = [
  { value: 'each', label: 'Each currency' },
  { value: 'one', label: 'One currency' },
];

const foreignLines = computed(() => summary.lines.filter((line) => line.currency.code !== target.value));
const anyUnlocked = computed(() => foreignLines.value.some((line) => !line.locked));

// A brand new database has no rates in it at all, so a rate the server could
// not supply is the ordinary first case rather than an exotic one. Nothing is
// converted until every one of them has a number.
const rateFor = (code) => Number(String(rates[code] ?? '').trim());
const needsRate = computed(() =>
  foreignLines.value.filter((line) => !line.locked && !(rateFor(line.currency.code) > 0))
);
const canLock = computed(() => anyUnlocked.value && needsRate.value.length === 0);

// A local preview of what a rate does. The figures that get written are
// recomputed by Rails when the rates are locked.
function previewFor(line) {
  const rate = Number(rates[line.currency.code]);
  if (!rate || Number.isNaN(rate)) return null;

  const sourceMajor = Number(line.source.replace(/[^\d.-]/g, ''));
  const targetCurrency = currencyList.find((c) => c.code === target.value);
  const value = sourceMajor * rate;
  return `${targetCurrency?.symbol ?? ''}${value.toLocaleString(undefined, {
    minimumFractionDigits: targetCurrency?.exponent ?? 2,
    maximumFractionDigits: targetCurrency?.exponent ?? 2,
  })}`;
}

// Changing the target currency needs the server to re-derive the balances.
function changeTarget(code) {
  target.value = code;
  window.location = `${props.reloadPath}?currency=${code}`;
}

const token = document.querySelector('meta[name="csrf-token"]')?.content;
</script>

<template>
  <div class="space-y-5">
    <div v-if="buckets.length > 1" data-reveal class="is-revealed">
      <SegmentedControl v-model="mode" :options="modes" />
      <p class="mt-2 text-xs text-ink-500">
        <template v-if="mode === 'each'">
          Pay each currency on its own. Nothing is converted and no rate is locked.
        </template>
        <template v-else>
          Turn every balance into one currency. This locks a rate per currency onto the expenses behind it.
        </template>
      </p>
    </div>

    <!-- Pay each currency in its own terms -->
    <Transition name="swap" mode="out-in">
      <div v-if="mode === 'each'" key="each" class="space-y-4">
        <section v-for="bucket in buckets" :key="bucket.currency.code" class="card overflow-hidden">
          <div class="flex items-center justify-between border-b border-ink-100 px-4 py-3">
            <span class="flex items-center gap-2">
              <span class="pill bg-brand-50 text-brand-700">{{ bucket.currency.code }}</span>
              <span class="text-sm text-ink-500">{{ bucket.currency.name }}</span>
            </span>
            <span v-if="bucket.locked" class="pill bg-positive-50 text-positive-700">rate locked</span>
          </div>

          <ul v-if="bucket.debts.length" class="divide-y divide-ink-100">
            <li v-for="debt in bucket.debts" :key="`${debt.from.id}-${debt.to.id}`" class="flex items-center gap-2 px-4 py-3">
              <AvatarBubble :user="debt.from" size="xs" />
              <span class="min-w-0 flex-1 truncate text-sm">
                <span class="font-medium text-ink-900">{{ debt.from.name.split(' ')[0] }}</span>
                <span class="text-ink-400"> pays </span>
                <span class="font-medium text-ink-900">{{ debt.to.name.split(' ')[0] }}</span>
              </span>
              <span class="tnum shrink-0 text-sm font-semibold text-ink-900">{{ debt.formatted }}</span>
            </li>
          </ul>
          <p v-else class="px-4 py-4 text-sm text-ink-500">Nothing outstanding in {{ bucket.currency.code }}.</p>
        </section>

        <a :href="recordPath" class="btn-primary w-full">Record a payment</a>
      </div>

      <!-- Convert everything into one currency -->
      <div v-else key="one" class="space-y-4">
        <section class="card card-pad">
          <label class="label">Settle everything in</label>
          <select :value="target" class="input" @change="changeTarget($event.target.value)">
            <option v-for="currency in currencyList" :key="currency.code" :value="currency.code">
              {{ currency.code }} · {{ currency.name }}
            </option>
          </select>
          <p class="mt-1.5 text-xs text-ink-500">
            Defaults to {{ group.base_currency }}, the group's currency. Change it if you'd rather settle in
            something else.
          </p>
        </section>

        <section v-if="foreignLines.length" class="card overflow-hidden">
          <div class="border-b border-ink-100 px-4 py-3">
            <h2 class="text-sm font-semibold text-ink-900">Rates</h2>
            <p class="mt-0.5 text-xs text-ink-500">
              These are the rates that will be written onto the expenses. Once locked they never change.
            </p>
          </div>

          <div v-for="line in foreignLines" :key="line.currency.code" class="border-b border-ink-100 px-4 py-3 last:border-0">
            <div class="flex items-center justify-between gap-3">
              <span class="text-sm">
                <span class="font-medium text-ink-900">{{ line.source }}</span>
                <span class="text-ink-400"> →</span>
              </span>
              <span class="tnum text-sm font-semibold text-ink-900">
                {{ previewFor(line) ?? line.converted }}
              </span>
            </div>

            <div class="mt-2 flex items-center gap-2">
              <span class="shrink-0 text-xs text-ink-500">1 {{ line.currency.code }} =</span>
              <input
                v-model="rates[line.currency.code]"
                inputmode="decimal"
                :disabled="line.locked"
                class="input tnum flex-1 py-2 text-sm disabled:bg-ink-100 disabled:text-ink-500"
              />
              <span class="shrink-0 text-xs text-ink-500">{{ target }}</span>
            </div>

            <p v-if="line.locked" class="mt-1.5 text-xs text-positive-700">
              Already locked at {{ line.rate }} — historical records aren't re-converted.
            </p>
          </div>
        </section>

        <section v-if="summary.transfers.length" class="card overflow-hidden">
          <div class="border-b border-ink-100 px-4 py-3">
            <h2 class="text-sm font-semibold text-ink-900">Then everyone pays</h2>
            <p v-if="summary.estimated" class="mt-0.5 text-xs text-sand-600">
              Based on today's estimate. Lock the rates to fix these figures.
            </p>
          </div>
          <ul class="divide-y divide-ink-100">
            <li v-for="debt in summary.transfers" :key="`${debt.from.id}-${debt.to.id}`" class="flex items-center gap-2 px-4 py-3">
              <AvatarBubble :user="debt.from" size="xs" />
              <span class="min-w-0 flex-1 truncate text-sm">
                <span class="font-medium text-ink-900">{{ debt.from.name.split(' ')[0] }}</span>
                <span class="text-ink-400"> pays </span>
                <span class="font-medium text-ink-900">{{ debt.to.name.split(' ')[0] }}</span>
              </span>
              <span class="tnum shrink-0 text-sm font-semibold text-ink-900">{{ debt.formatted }}</span>
            </li>
          </ul>
        </section>

        <p v-if="needsRate.length" class="rounded-xl bg-sand-50 px-4 py-3 text-sm text-sand-600">
          No rate on file for
          {{ needsRate.map((l) => l.currency.code).join(', ') }} yet — put one in above, or pay each
          currency on its own and convert nothing.
        </p>

        <button
          v-if="anyUnlocked"
          type="button"
          class="btn-primary w-full"
          :disabled="!canLock"
          @click="confirming = true"
        >
          Lock these rates
        </button>
        <p v-else class="rounded-xl bg-positive-50 px-4 py-3 text-sm text-positive-700">
          Every currency in this group is already locked to {{ target }}.
        </p>

        <a :href="recordPath" class="btn-secondary w-full">Record a payment instead</a>
      </div>
    </Transition>

    <BottomSheet :open="confirming" title="Lock these rates?" @close="confirming = false">
      <p class="text-sm text-ink-600">
        Every unlocked expense in {{ foreignLines.map((l) => l.currency.code).join(', ') }} will be converted
        into <span class="font-semibold text-ink-900">{{ target }}</span> at the rates above and fixed there.
      </p>
      <p class="mt-3 text-sm text-ink-600">
        The original amounts and currencies are kept. This only decides what the group's balances are counted in.
      </p>

      <template #footer>
        <form :action="settlePath" method="post" class="sheet-actions">
          <input type="hidden" name="authenticity_token" :value="token" />
          <input type="hidden" name="currency" :value="target" />
          <input v-for="(rate, code) in rates" :key="code" type="hidden" :name="`rates[${code}]`" :value="rate" />
          <button type="button" class="sheet-action sheet-action-quiet" @click="confirming = false">Not yet</button>
          <button type="submit" class="sheet-action sheet-action-primary">Lock rates</button>
        </form>
      </template>
    </BottomSheet>
  </div>
</template>

<style scoped>
.swap-enter-active,
.swap-leave-active {
  transition:
    opacity 0.2s ease,
    transform 0.26s cubic-bezier(0.22, 1, 0.36, 1);
}
.swap-enter-from {
  opacity: 0;
  transform: translateY(10px);
}
.swap-leave-to {
  opacity: 0;
  transform: translateY(-6px);
}
</style>
