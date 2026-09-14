<script setup>
import { computed, reactive, ref } from 'vue';
import BottomSheet from './BottomSheet.vue';
import SegmentedControl from './SegmentedControl.vue';

// Search plus a small set of combinable filters. Deliberately not a query
// builder: a search box, date chips, and a sheet holding the rest.
const props = defineProps({
  filter: { type: [Object, String], default: () => ({}) },
  scope: { type: String, default: 'global' },
  categories: { type: [Array, String], default: () => [] },
  currencies: { type: [Array, String], default: () => [] },
  people: { type: [Array, String], default: () => [] },
  groups: { type: [Array, String], default: () => [] },
});

const parse = (value) => (typeof value === 'string' ? JSON.parse(value) : value);
const categoryList = parse(props.categories);
const currencyList = parse(props.currencies);
const peopleList = parse(props.people);
const groupList = parse(props.groups);

const state = reactive({
  q: '',
  period: 'all',
  from: '',
  to: '',
  category_id: '',
  currency_code: '',
  person_id: '',
  payer_id: '',
  group_id: '',
  min_amount: '',
  max_amount: '',
  status: 'active',
  ...parse(props.filter),
});

const sheetOpen = ref(false);

const periods = [
  { value: 'all', label: 'All' },
  { value: 'today', label: 'Today' },
  { value: 'week', label: 'Week' },
  { value: 'month', label: 'Month' },
  { value: 'year', label: 'Year' },
  { value: 'custom', label: 'Range' },
];

const extraCount = computed(
  () =>
    [state.category_id, state.currency_code, state.person_id, state.payer_id, state.group_id, state.min_amount, state.max_amount].filter(
      Boolean
    ).length + (state.status !== 'active' ? 1 : 0)
);

function apply() {
  const params = new URLSearchParams();
  Object.entries(state).forEach(([key, value]) => {
    if (value === '' || value === null || value === undefined) return;
    if (key === 'period' && value === 'all') return;
    if (key === 'status' && value === 'active') return;
    params.set(key, value);
  });
  window.location = `${window.location.pathname}${params.toString() ? `?${params}` : ''}`;
}

function clearAll() {
  window.location = window.location.pathname;
}

let searchTimer = null;
function onSearch() {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(apply, 500);
}

function setPeriod(value) {
  state.period = value;
  if (value !== 'custom') apply();
}
</script>

<template>
  <div class="mb-4 space-y-2">
    <div class="flex gap-2">
      <div class="relative flex-1">
        <svg
          class="pointer-events-none absolute inset-y-0 left-3 my-auto h-4 w-4 text-ink-400"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          viewBox="0 0 24 24"
        >
          <circle cx="11" cy="11" r="7" />
          <path stroke-linecap="round" d="M20 20l-3.5-3.5" />
        </svg>
        <input
          v-model="state.q"
          type="search"
          placeholder="Search expenses, people, notes…"
          class="input py-2.5 pl-9 pr-3 text-sm"
          @input="onSearch"
          @keydown.enter.prevent="apply"
        />
      </div>

      <button
        type="button"
        class="press relative grid h-[42px] w-[42px] shrink-0 place-items-center rounded-lg border border-ink-300 bg-surface text-ink-600"
        aria-label="More filters"
        @click="sheetOpen = true"
      >
        <svg class="h-4.5 w-4.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
          <path stroke-linecap="round" d="M4 6h16M7 12h10M10 18h4" />
        </svg>
        <span
          v-if="extraCount"
          class="animate-pop absolute -right-1 -top-1 grid h-4.5 min-w-[1.125rem] place-items-center rounded-full bg-brand-600 px-1 text-[10px] font-bold text-white"
        >
          {{ extraCount }}
        </span>
      </button>
    </div>

    <div class="flex gap-1.5 overflow-x-auto pb-1">
      <button
        v-for="period in periods"
        :key="period.value"
        type="button"
        :class="[
          'press shrink-0 rounded-full border px-3 py-1.5 text-xs font-medium',
          state.period === period.value
            ? 'border-brand-600 bg-brand-600 text-white'
            : 'border-ink-200 bg-surface text-ink-600',
        ]"
        @click="setPeriod(period.value)"
      >
        {{ period.label }}
      </button>
    </div>

    <Transition name="fade-slide">
      <div v-if="state.period === 'custom'" class="flex items-center gap-2">
        <input v-model="state.from" type="date" class="input py-2 text-sm" />
        <span class="text-xs text-ink-400">to</span>
        <input v-model="state.to" type="date" class="input py-2 text-sm" />
        <button type="button" class="btn-primary btn-sm shrink-0" @click="apply">Go</button>
      </div>
    </Transition>

    <BottomSheet :open="sheetOpen" title="Filters" @close="sheetOpen = false">
      <div class="space-y-4">
        <div v-if="scope === 'global'">
          <label class="label">Group</label>
          <select v-model="state.group_id" class="input">
            <option value="">Any group</option>
            <option value="personal">Just me (no group)</option>
            <option v-for="group in groupList" :key="group.id" :value="group.id">{{ group.name }}</option>
          </select>
        </div>

        <div>
          <label class="label">Category</label>
          <select v-model="state.category_id" class="input">
            <option value="">Any category</option>
            <option v-for="category in categoryList" :key="category.id" :value="category.id">
              {{ category.name }}
            </option>
          </select>
        </div>

        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="label">Involves</label>
            <select v-model="state.person_id" class="input">
              <option value="">Anyone</option>
              <option v-for="person in peopleList" :key="person.id" :value="person.id">{{ person.name }}</option>
            </select>
          </div>
          <div>
            <label class="label">Paid by</label>
            <select v-model="state.payer_id" class="input">
              <option value="">Anyone</option>
              <option v-for="person in peopleList" :key="person.id" :value="person.id">{{ person.name }}</option>
            </select>
          </div>
        </div>

        <div>
          <label class="label">Currency</label>
          <select v-model="state.currency_code" class="input">
            <option value="">Any currency</option>
            <option v-for="currency in currencyList" :key="currency.code" :value="currency.code">
              {{ currency.code }} · {{ currency.name }}
            </option>
          </select>
        </div>

        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="label">Min amount</label>
            <input v-model="state.min_amount" inputmode="decimal" class="input tnum" placeholder="0" />
          </div>
          <div>
            <label class="label">Max amount</label>
            <input v-model="state.max_amount" inputmode="decimal" class="input tnum" placeholder="Any" />
          </div>
        </div>

        <div>
          <label class="label">Status</label>
          <SegmentedControl
            v-model="state.status"
            size="sm"
            :options="[
              { value: 'active', label: 'Active' },
              { value: 'voided', label: 'Voided' },
              { value: 'all', label: 'All' },
            ]"
          />
        </div>
      </div>

      <template #footer>
        <div class="sheet-actions">
          <button type="button" class="sheet-action sheet-action-quiet" @click="clearAll">Clear</button>
          <button type="button" class="sheet-action sheet-action-primary" @click="apply">Show results</button>
        </div>
      </template>
    </BottomSheet>
  </div>
</template>

<style scoped>
.fade-slide-enter-active,
.fade-slide-leave-active {
  transition:
    opacity 0.2s ease,
    transform 0.22s cubic-bezier(0.22, 1, 0.36, 1);
}
.fade-slide-enter-from,
.fade-slide-leave-to {
  opacity: 0;
  transform: translateY(-6px);
}
</style>
