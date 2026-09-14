import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { mount } from '@vue/test-utils';
import InstallPrompt from '@/components/InstallPrompt.vue';

const SAFARI_IPHONE =
  'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1';
const CHROME_IPHONE =
  'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/126.0 Mobile/15E148 Safari/604.1';
const CHROME_ANDROID =
  'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Mobile Safari/537.36';

function setPlatform({ ua, touch = 5, standalone = false }) {
  Object.defineProperty(navigator, 'userAgent', { value: ua, configurable: true });
  Object.defineProperty(navigator, 'maxTouchPoints', { value: touch, configurable: true });
  Object.defineProperty(navigator, 'standalone', { value: standalone, configurable: true });
  window.matchMedia = vi.fn().mockReturnValue({ matches: standalone });
}

function fireInstallPrompt() {
  const event = new Event('beforeinstallprompt');
  event.prompt = vi.fn();
  event.userChoice = Promise.resolve({ outcome: 'accepted' });
  window.dispatchEvent(event);
  return event;
}

describe('InstallPrompt', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    localStorage.clear();
  });
  afterEach(() => vi.useRealTimers());

  it('tells an iPhone where the button it cannot press for them is', async () => {
    setPlatform({ ua: SAFARI_IPHONE });
    const wrapper = mount(InstallPrompt, { attachTo: document.body });

    expect(document.body.textContent).not.toContain('Add to Home Screen');
    vi.advanceTimersByTime(4000);
    await wrapper.vm.$nextTick();

    expect(document.body.textContent).toContain('Add to Home Screen');
    wrapper.unmount();
  });

  // Add to Home Screen comes from the iOS share sheet, which every browser on
  // the platform presents - so Chrome gets the hint too. What it must not do
  // is tell people to look in the wrong place.
  it('helps Chrome on iOS as well, pointing at its own menu', async () => {
    setPlatform({ ua: CHROME_IPHONE });
    const wrapper = mount(InstallPrompt, { attachTo: document.body });

    vi.advanceTimersByTime(4000);
    await wrapper.vm.$nextTick();

    expect(document.body.textContent).toContain('Add to Home Screen');
    expect(document.body.textContent).toContain('menu');
    expect(document.body.textContent).not.toContain('button at the bottom');
    wrapper.unmount();
  });

  it('points Safari at the bar along the bottom instead', async () => {
    setPlatform({ ua: SAFARI_IPHONE });
    const wrapper = mount(InstallPrompt, { attachTo: document.body });

    vi.advanceTimersByTime(4000);
    await wrapper.vm.$nextTick();

    expect(document.body.textContent).toContain('share button at the bottom');
    wrapper.unmount();
  });

  // It is below the fold of the share sheet, which is the whole reason people
  // cannot find it.
  it('says the option needs scrolling to, and is hidden in private browsing', async () => {
    setPlatform({ ua: SAFARI_IPHONE });
    const wrapper = mount(InstallPrompt, { attachTo: document.body });

    vi.advanceTimersByTime(4000);
    await wrapper.vm.$nextTick();

    expect(document.body.textContent).toContain('scroll down');
    expect(document.body.textContent).toContain('Private Browsing');
    wrapper.unmount();
  });

  it('offers a real install button where the browser provides one', async () => {
    setPlatform({ ua: CHROME_ANDROID, touch: 5 });
    const wrapper = mount(InstallPrompt, { attachTo: document.body });

    fireInstallPrompt();
    await wrapper.vm.$nextTick();

    expect(document.body.textContent).toContain('home screen');
    expect([...document.querySelectorAll('button')].some((b) => b.textContent.trim() === 'Add')).toBe(true);
    wrapper.unmount();
  });

  it('stays quiet once it is already installed', async () => {
    setPlatform({ ua: SAFARI_IPHONE, standalone: true });
    const wrapper = mount(InstallPrompt, { attachTo: document.body });

    vi.advanceTimersByTime(10000);
    await wrapper.vm.$nextTick();

    expect(document.body.textContent).not.toContain('Add to Home Screen');
    wrapper.unmount();
  });

  it('does not ask twice after being waved away', async () => {
    setPlatform({ ua: SAFARI_IPHONE });
    const first = mount(InstallPrompt, { attachTo: document.body });
    vi.advanceTimersByTime(4000);
    await first.vm.$nextTick();

    const close = [...document.querySelectorAll('button')].find(
      (b) => b.getAttribute('aria-label') === 'Not now'
    );
    close.click();
    await first.vm.$nextTick();
    first.unmount();

    const second = mount(InstallPrompt, { attachTo: document.body });
    vi.advanceTimersByTime(10000);
    await second.vm.$nextTick();

    expect(document.body.textContent).not.toContain('Add to Home Screen');
    second.unmount();
  });

  it('survives a browser that throws on localStorage', async () => {
    setPlatform({ ua: SAFARI_IPHONE });
    const getItem = vi.spyOn(Storage.prototype, 'getItem').mockImplementation(() => {
      throw new Error('private browsing');
    });

    const wrapper = mount(InstallPrompt, { attachTo: document.body });
    vi.advanceTimersByTime(4000);
    await wrapper.vm.$nextTick();

    expect(document.body.textContent).toContain('Add to Home Screen');
    getItem.mockRestore();
    wrapper.unmount();
  });
});
