import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mount } from '@vue/test-utils';

vi.mock('@/lib/http', () => ({
  default: {
    get: vi.fn(async () => ({ data: { members: [], base_currency: 'PHP' } })),
    post: vi.fn(async () => ({ data: { valid: true, errors: [], splits: [] } })),
  },
}));

const { default: ExpenseComposer } = await import('@/components/ExpenseComposer.vue');

const currencies = [
  { code: 'PHP', symbol: '₱', exponent: 2 },
  { code: 'JPY', symbol: '¥', exponent: 0 },
];
const members = [
  { id: 1, name: 'John Salva', initials: 'JS', tone: 'bg-avatar-1' },
  { id: 2, name: 'Alice Cruz', initials: 'AC', tone: 'bg-avatar-2' },
];

function mountComposer(expense) {
  return mount(ExpenseComposer, {
    props: {
      open: true,
      currencies,
      members,
      friends: members,
      currentUserId: 1,
      groupId: 4,
      expense,
      // Teleport would move the sheet out of the wrapper and hide it from text().
      attachTo: document.body,
    },
    global: { stubs: { Teleport: true } },
  });
}

const baseExpense = {
  group_id: 4,
  description: 'Dinner',
  amount: '1000.00',
  currency_code: 'PHP',
  spent_on: '2026-01-01',
  split_method: 'equal',
  payers: [{ user_id: 1, amount: '1000.00' }],
  participants: [{ user_id: 1, split_value: null }, { user_id: 2, split_value: null }],
};

const amountField = (wrapper) =>
  wrapper.find('input[name="expense[amount]"]').element.value;

describe('ExpenseComposer', () => {
  beforeEach(() => {
    document.head.innerHTML = '<meta name="csrf-token" content="tok">';
  });

  it('leaves the amount alone while there is a single payer', async () => {
    const wrapper = mountComposer(baseExpense);
    await wrapper.vm.$nextTick();
    expect(amountField(wrapper)).toBe('1000.00');
  });

  // The bug: adding a second payer used to leave the total - and so every
  // split - on the figure typed in step one.
  it('follows the payers once there is more than one of them', async () => {
    const wrapper = mountComposer({
      ...baseExpense,
      payers: [{ user_id: 1, amount: '1000.00' }, { user_id: 2, amount: '500.00' }],
    });
    await wrapper.vm.$nextTick();
    expect(amountField(wrapper)).toBe('1500.00');
  });

  it('lets the payers exceed what was typed first', async () => {
    const wrapper = mountComposer({
      ...baseExpense,
      payers: [{ user_id: 1, amount: '1000.00' }, { user_id: 2, amount: '2500.50' }],
    });
    await wrapper.vm.$nextTick();
    expect(amountField(wrapper)).toBe('3500.50');
  });

  it('keeps whole units on a currency with no subunit', async () => {
    const wrapper = mountComposer({
      ...baseExpense,
      currency_code: 'JPY',
      amount: '1000',
      payers: [{ user_id: 1, amount: '1000' }, { user_id: 2, amount: '250' }],
    });
    await wrapper.vm.$nextTick();
    expect(amountField(wrapper)).toBe('1250');
  });
});
