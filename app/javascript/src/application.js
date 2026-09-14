import * as Turbo from '@hotwired/turbo';
import { createApp } from 'vue';
import http from '@/lib/http';
import { startRevealObserver } from '@/lib/reveal';
import { applyTheme, watchSystemTheme } from '@/lib/theme';
import { formatMoney, formatMinor } from '@/lib/money';

// Mirrors the Rails-monolith pattern: one Vue app mounted over the server
// rendered layout, with components dropped into HAML as custom elements.
// Vue enhances islands of interactivity; it never owns routing or data.
const modules = import.meta.glob('@/components/**/*.vue', { eager: true });

// A fresh app per visit: Turbo replaces the DOM the previous one was mounted
// on, so reusing it would leave the new markup uncontrolled.
function createRoot() {
  const app = createApp({
    name: 'OneraRoot',
    data() {
      return { userMenuOpen: false, mobileNavOpen: false };
    },
    methods: {
      closeMenus() {
        this.userMenuOpen = false;
        this.mobileNavOpen = false;
      },
    },
  });

  for (const [path, module] of Object.entries(modules)) {
    const name = path.split('/').pop().replace(/\.vue$/, '');
    app.component(name, module.default);
  }

  app.config.globalProperties.$http = http;
  app.config.globalProperties.$formatMoney = formatMoney;
  app.config.globalProperties.$formatMinor = formatMinor;

  return app;
}

applyTheme();
watchSystemTheme();

// Turbo swaps the body instead of reloading the document, which is what makes
// navigation feel like an app rather than a series of page loads. Everything
// that used to run once on DOMContentLoaded now runs on every render.
//
// Deliberately no unmount: Turbo has already discarded the nodes the previous
// app was mounted on by the time a new page renders, and asking Vue to tidy
// up DOM that no longer exists throws part-way through and leaves the page
// blank. The orphaned instance goes with the markup it was attached to.
function mountIfNeeded() {
  const root = document.querySelector('#vue');
  // Marked on the element itself: the element is replaced with the page, so
  // the flag cannot outlive what it describes.
  if (!root || root.dataset.mounted === 'true') return;

  root.dataset.mounted = 'true';
  createRoot().mount(root);
  startRevealObserver();
}

// turbo:load covers ordinary visits. A form that comes back 4xx renders
// through turbo:render without a load event, and that page was left inert -
// which is how a rejected sign-in ended up as a blank screen.
document.addEventListener('turbo:load', mountIfNeeded);
document.addEventListener('turbo:render', mountIfNeeded);
document.addEventListener('DOMContentLoaded', mountIfNeeded);

Turbo.start();

window.Onera = { http, Turbo };
