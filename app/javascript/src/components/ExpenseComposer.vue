<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import BottomSheet from './BottomSheet.vue';
import MoneyField from './MoneyField.vue';
import SegmentedControl from './SegmentedControl.vue';
import SplitEditor from './SplitEditor.vue';
import PersonPicker from './PersonPicker.vue';
import http from '@/lib/http';

// Adding or editing an expense.
//
// Everything shown here is a preview. The split figures come from the server
// so the numbers on screen are the ones that will be stored, but the form
// still posts raw inputs and Rails recalculates from scratch on submit.
const props = defineProps({
  open: { type: Boolean, default: false },
  groups: { type: [Array, String], default: () => [] },
  currencies: { type: [Array, String], default: () => [] },
  members: { type: [Array, String], default: () => [] },
  categories: { type: [Array, String], default: () => [] },
  groupId: { type: [Number, String], default: null },
  currentUserId: { type: [Number, String], default: null },
  expense: { type: [Object, String], default: null },
  action: { type: String, default: '/expenses' },
  method: { type: String, default: 'post' },
});
const emit = defineEmits(['close']);

const parse = (value, fallback) => {
  if (value === null || value === undefined || value === '') return fallback;
  return typeof value === 'string' ? JSON.parse(value) : value;
};

const groupList = parse(props.groups, []);
const currencyList = parse(props.currencies, []);
const categoryList = parse(props.categories, []);
const existing = parse(props.expense, null);
const memberList = ref(parse(props.members, []));

const step = ref(1);
const saving = ref(false);
const preview = ref(null);
const previewing = ref(false);

const form = ref({
  group_id: existing?.group_id ?? (props.groupId ? Number(props.groupId) : null),
  description: existing?.description ?? '',
  amount: existing?.amount ?? '',
  currency_code: existing?.currency_code ?? currencyList[0]?.code ?? 'PHP',
  spent_on: existing?.spent_on ?? new Date().toISOString().slice(0, 10),
  category_id: existing?.category_id ?? null,
  notes: existing?.notes ?? '',
  split_method: existing?.split_method ?? 'equal',
  payers: existing?.payers ?? [],
  participants: existing?.participants ?? [],
});

const personal = computed(() => !form.value.group_id);
const activeCurrency = computed(() => currencyList.find((c) => c.code === form.value.currency_code));

const payerIds = computed({
  get: () => form.value.payers.map((p) => p.user_id),
  set: () => {},
});

const splitMethods = [
  { value: 'equal', label: 'Equally' },
  { value: 'shares', label: 'Shares' },
  { value: 'percentage', label: 'Percent' },
  { value: 'fixed', label: 'Exact' },
];

// Who can be involved, and which currency is implied, both follow the group.
// Runs immediately as well as on change: opening the composer from inside a
// group preselects it, and with no change event the members would never load.
watch(
  () => form.value.group_id,
  async (groupId) => {
    if (!groupId) {
      memberList.value = [];
      form.value.payers = [];
      form.value.participants = [];
      return;
    }

    // Editing already has its members and its own currency; don't refetch or
    // overwrite what the expense was saved with.
    if (existing && memberList.value.length) return;

    const { data } = await http.get(`/groups/${groupId}/memberships.json`);
    memberList.value = data.members;
    if (existing) return;

    form.value.currency_code = data.base_currency;
    form.value.payers = props.currentUserId ? [{ user_id: Number(props.currentUserId), amount: '' }] : [];
    form.value.participants = data.members.map((m) => ({ user_id: m.id, split_value: null }));
  },
  { immediate: true }
);

function togglePayer(userId) {
  const index = form.value.payers.findIndex((p) => p.user_id === userId);
  if (index >= 0) form.value.payers.splice(index, 1);
  else form.value.payers.push({ user_id: userId, amount: '' });

  // A single payer always covers the whole amount, so we fill it for them.
  if (form.value.payers.length === 1) form.value.payers[0].amount = form.value.amount;
}

function toggleParticipant(userId) {
  const index = form.value.participants.findIndex((p) => p.user_id === userId);
  if (index >= 0) form.value.participants.splice(index, 1);
  else form.value.participants.push({ user_id: userId, split_value: null });
}

watch(
  () => form.value.amount,
  (amount) => {
    if (form.value.payers.length === 1) form.value.payers[0].amount = amount;
  }
);

let previewTimer = null;
watch(
  () => [form.value.amount, form.value.currency_code, form.value.split_method, form.value.participants, form.value.payers, form.value.group_id],
  () => {
    clearTimeout(previewTimer);
    if (!form.value.amount) {
      preview.value = null;
      return;
    }
    previewing.value = true;
    previewTimer = setTimeout(fetchPreview, 260);
  },
  { deep: true }
);

async function fetchPreview() {
  try {
    const { data } = await http.post('/api/split_previews', {
      group_id: form.value.group_id,
      amount: form.value.amount,
      currency_code: form.value.currency_code,
      split_method: form.value.split_method,
      participants: personal.value ? [] : form.value.participants,
      payers: personal.value ? [] : form.value.payers,
    });
    preview.value = data;
  } finally {
    previewing.value = false;
  }
}

onMounted(() => {
  if (form.value.amount) fetchPreview();
});

const conversion = computed(() => preview.value?.conversion);

const canContinue = computed(() => form.value.description.trim() && Number(form.value.amount) > 0);
const canSave = computed(() => canContinue.value && (personal.value || preview.value?.valid));

const formEl = ref(null);
function submit() {
  saving.value = true;
  formEl.value.submit();
}

const token = document.querySelector('meta[name="csrf-token"]')?.content;
const sheetTitle = computed(() => (existing ? 'Edit expense' : step.value === 1 ? 'New expense' : 'Who and how'));
</script>

<template>
  <BottomSheet :open="open" :title="sheetTitle" max-width="max-w-xl" @close="emit('close')">
    <form ref="formEl" :action="action" method="post" class="space-y-5 pt-1">
      <input type="hidden" name="authenticity_token" :value="token" />
      <input v-if="method !== 'post'" type="hidden" name="_method" :value="method" />
      <!-- The authoritative fields. Kept outside the step branches: a v-if
           removes its inputs from the DOM, so anything named inside step one
           would simply not be submitted from step two. -->
      <input type="hidden" name="expense[group_id]" :value="form.group_id || ''" />
      <input type="hidden" name="expense[split_method]" :value="form.split_method" />
      <input type="hidden" name="expense[description]" :value="form.description" />
      <input type="hidden" name="expense[amount]" :value="form.amount" />
      <input type="hidden" name="expense[currency_code]" :value="form.currency_code" />
      <input type="hidden" name="expense[spent_on]" :value="form.spent_on" />
      <input type="hidden" name="expense[category_id]" :value="form.category_id ?? ''" />
      <input type="hidden" name="expense[notes]" :value="form.notes ?? ''" />
      <template v-for="(payer, index) in form.payers" :key="`p${payer.user_id}`">
        <input type="hidden" :name="`expense[payers][${index}][user_id]`" :value="payer.user_id" />
        <input type="hidden" :name="`expense[payers][${index}][amount]`" :value="payer.amount" />
      </template>
      <template v-for="(person, index) in form.participants" :key="`s${person.user_id}`">
        <input type="hidden" :name="`expense[participants][${index}][user_id]`" :value="person.user_id" />
        <input
          type="hidden"
          :name="`expense[participants][${index}][split_value]`"
          :value="person.split_value ?? ''"
        />
      </template>

      <!-- Step 1: what and how much -->
      <Transition name="step" mode="out-in">
        <div v-if="step === 1" key="details" class="space-y-5">
          <div>
            <input
              v-model="form.description"
              placeholder="What was it for?"
              autocomplete="off"
              class="input border-0 border-b border-ink-200 px-0 text-lg font-medium shadow-none focus:border-brand-500 focus:ring-0"
            />
          </div>

          <div>
            <MoneyField
              v-model="form.amount"
              v-model:currency="form.currency_code"
              :currencies="currencyList"
            />
            <!-- The guide figure. Deliberately quiet, and honest about being an
                 estimate: the rate that counts is chosen at settle-up. -->
            <Transition name="fade-slide">
              <p v-if="conversion?.applicable" class="mt-2 flex items-start gap-1.5 pl-1 text-xs leading-relaxed text-ink-500">
                <svg class="mt-0.5 h-3.5 w-3.5 shrink-0 text-ink-400" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M8 7h12m0 0l-3-3m3 3l-3 3M16 17H4m0 0l3 3m-3-3l3-3" />
                </svg>
                <span v-if="conversion.unavailable">
                  No {{ conversion.target.code }} rate on file yet — set one when you settle up.
                </span>
                <span v-else>
                  About <span class="font-semibold text-ink-700">{{ conversion.amount.formatted }}</span>
                  at {{ conversion.rate }} — estimate only, locked when you settle up.
                </span>
              </p>
            </Transition>
          </div>

          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="label">Date</label>
              <input v-model="form.spent_on" type="date" class="input" />
            </div>
            <div>
              <label class="label">Category</label>
              <select v-model="form.category_id" class="input">
                <option :value="null">None</option>
                <option v-for="category in categoryList" :key="category.id" :value="category.id">
                  {{ category.name }}
                </option>
              </select>
            </div>
          </div>

          <div v-if="groupList.length">
            <label class="label">Where does it go?</label>
            <div class="flex flex-wrap gap-2">
              <button
                type="button"
                :class="[
                  'press rounded-full border px-3.5 py-1.5 text-sm font-medium',
                  !form.group_id ? 'border-brand-600 bg-brand-50 text-brand-800' : 'border-ink-200 bg-surface text-ink-600',
                ]"
                @click="form.group_id = null"
              >
                Just me
              </button>
              <button
                v-for="group in groupList"
                :key="group.id"
                type="button"
                :class="[
                  'press rounded-full border px-3.5 py-1.5 text-sm font-medium',
                  form.group_id === group.id
                    ? 'border-brand-600 bg-brand-50 text-brand-800'
                    : 'border-ink-200 bg-surface text-ink-600',
                ]"
                @click="form.group_id = group.id"
              >
                {{ group.name }}
              </button>
            </div>
          </div>

          <details class="group">
            <summary class="cursor-pointer list-none text-sm font-medium text-ink-500 transition hover:text-ink-700">
              <span class="inline-flex items-center gap-1">
                Add a note
                <svg class="h-4 w-4 transition-transform group-open:rotate-180" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7" />
                </svg>
              </span>
            </summary>
            <textarea v-model="form.notes" rows="2" class="input mt-2" placeholder="Anything worth remembering" />
          </details>
        </div>

        <!-- Step 2: who paid, who shares -->
        <div v-else key="split" class="space-y-6">
          <section>
            <div class="mb-2 flex items-baseline justify-between">
              <h3 class="text-sm font-semibold text-ink-900">Paid by</h3>
              <span v-if="form.payers.length > 1" class="text-xs text-ink-500">Tap an amount to adjust</span>
            </div>
            <PersonPicker :people="memberList" :selected="payerIds" @toggle="togglePayer" />

            <Transition name="fade-slide">
              <div v-if="form.payers.length > 1" class="mt-3 space-y-2">
                <div
                  v-for="payer in form.payers"
                  :key="payer.user_id"
                  class="flex items-center gap-3 rounded-xl bg-ink-50 px-3 py-2"
                >
                  <span class="min-w-0 flex-1 truncate text-sm font-medium text-ink-700">
                    {{ memberList.find((m) => m.id === payer.user_id)?.name }}
                  </span>
                  <div class="w-28 shrink-0">
                    <MoneyField
                      v-model="payer.amount"
                      :currency="form.currency_code"
                      :currencies="currencyList"
                      :currency-picker="false"
                      size="sm"
                    />
                  </div>
                </div>
              </div>
            </Transition>
          </section>

          <section>
            <h3 class="mb-2 text-sm font-semibold text-ink-900">Split between</h3>
            <PersonPicker
              :people="memberList"
              :selected="form.participants.map((p) => p.user_id)"
              @toggle="toggleParticipant"
            />
          </section>

          <section>
            <h3 class="mb-2 text-sm font-semibold text-ink-900">How</h3>
            <SegmentedControl v-model="form.split_method" :options="splitMethods" />
          </section>

          <SplitEditor
            v-model="form.participants"
            :people="memberList"
            :method="form.split_method"
            :preview="preview"
            :previewing="previewing"
            :currency="activeCurrency"
          />
        </div>
      </Transition>
    </form>

    <template #footer>
      <div class="sheet-actions">
        <button v-if="step === 2" type="button" class="sheet-action sheet-action-quiet" @click="step = 1">
          Back
        </button>

        <button
          v-if="step === 1 && !personal"
          type="button"
          class="sheet-action sheet-action-primary"
          :disabled="!canContinue"
          @click="step = 2"
        >
          Continue
        </button>

        <button
          v-else
          type="button"
          class="sheet-action sheet-action-primary"
          :disabled="!canSave || saving"
          @click="submit"
        >
          <span class="inline-flex items-center justify-center gap-2">
            <svg v-if="saving" class="h-4 w-4 animate-spin" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="3" />
              <path class="opacity-90" fill="currentColor" d="M4 12a8 8 0 018-8v3a5 5 0 00-5 5H4z" />
            </svg>
            {{ existing ? 'Save changes' : 'Add expense' }}
          </span>
        </button>
      </div>
    </template>
  </BottomSheet>
</template>

<style scoped>
.step-enter-active,
.step-leave-active {
  transition:
    opacity 0.2s ease,
    transform 0.28s cubic-bezier(0.22, 1, 0.36, 1);
}
.step-enter-from {
  opacity: 0;
  transform: translateX(18px);
}
.step-leave-to {
  opacity: 0;
  transform: translateX(-18px);
}

.fade-slide-enter-active,
.fade-slide-leave-active {
  transition:
    opacity 0.22s ease,
    transform 0.22s cubic-bezier(0.22, 1, 0.36, 1);
}
.fade-slide-enter-from,
.fade-slide-leave-to {
  opacity: 0;
  transform: translateY(-4px);
}
</style>
