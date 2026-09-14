<script setup>
import { computed, onMounted, onBeforeUnmount, ref } from 'vue';

// Offers to put Onera on the home screen, where it opens without browser
// chrome and behaves like any other app on the phone.
//
// The two platforms need opposite treatment. Chrome hands us a real install
// prompt through `beforeinstallprompt`, so there is a button that installs.
// Safari has no such API and never will, so the only thing on offer is telling
// somebody where the button already is - which is worth doing, because nobody
// finds Add to Home Screen on their own.
const DISMISSED = 'onera:install-dismissed';

const deferred = ref(null);
const visible = ref(false);
// Which iOS browser, because the share button is in a different place in each
// and "tap the share icon" is useless if you cannot see one.
const iosBrowser = ref(null);

// Already installed: opened from the home screen, or Safari's older flag.
function installed() {
  return window.matchMedia?.('(display-mode: standalone)').matches || navigator.standalone === true;
}

function dismissedBefore() {
  try {
    return localStorage.getItem(DISMISSED) === '1';
  } catch {
    // Private browsing can throw on read. Treat it as not dismissed; the worst
    // case is being asked again, which beats crashing the page.
    return false;
  }
}

function remember() {
  try {
    localStorage.setItem(DISMISSED, '1');
  } catch {
    /* nothing to do about it */
  }
}

function onBeforeInstallPrompt(event) {
  // Chrome would otherwise show its own bar at a moment of its choosing.
  event.preventDefault();
  deferred.value = event;
  if (!dismissedBefore()) visible.value = true;
}

let timer = null;

onMounted(() => {
  if (installed() || dismissedBefore()) return;

  window.addEventListener('beforeinstallprompt', onBeforeInstallPrompt);
  window.addEventListener('appinstalled', dismiss);

  const ua = navigator.userAgent;
  // iPadOS reports itself as a Mac, so a touch-capable "Mac" is really an iPad.
  const apple = /iPhone|iPod/.test(ua) ||
    (/iPad|Macintosh/.test(ua) && navigator.maxTouchPoints > 1);

  if (apple) {
    // Add to Home Screen comes from the iOS share sheet, which every browser
    // on the platform presents - so this is not Safari-only, as it first
    // appeared. What differs is where the share button lives.
    if (/CriOS/.test(ua)) iosBrowser.value = 'chrome';
    else if (/FxiOS/.test(ua)) iosBrowser.value = 'firefox';
    else if (/EdgiOS/.test(ua)) iosBrowser.value = 'edge';
    else iosBrowser.value = 'safari';

    // Not the instant the page loads. Let them see the app first.
    timer = window.setTimeout(() => (visible.value = true), 4000);
  }
});

onBeforeUnmount(() => {
  window.removeEventListener('beforeinstallprompt', onBeforeInstallPrompt);
  window.removeEventListener('appinstalled', dismiss);
  window.clearTimeout(timer);
});

function dismiss() {
  visible.value = false;
  remember();
}

async function install() {
  const prompt = deferred.value;
  if (!prompt) return;

  visible.value = false;
  prompt.prompt();
  await prompt.userChoice;
  deferred.value = null;
  remember();
}

const canInstall = computed(() => deferred.value !== null);

// Named precisely, because "tap share" sends people hunting. In Safari it is
// in the bar along the bottom; the others keep it behind their own menu.
const shareLocation = computed(() => ({
  safari: 'the share button at the bottom',
  chrome: 'the ⋯ menu, then Share',
  firefox: 'the ⋯ menu, then Share',
  edge: 'the ⋯ menu, then Share',
}[iosBrowser.value] ?? 'the share button'));
</script>

<template>
  <Teleport to="body">
    <Transition name="install">
      <div
        v-if="visible"
        class="pointer-events-none fixed inset-x-0 bottom-0 z-40 flex justify-center px-3 pb-[calc(4.5rem+env(safe-area-inset-bottom))] md:pb-5"
      >
        <div
          class="pointer-events-auto flex w-full max-w-md items-center gap-3 rounded-2xl bg-surface px-4 py-3 shadow-lift"
        >
          <span class="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-brand-600">
            <svg class="icon-lg text-white" fill="none" viewBox="0 0 24 24" role="img" aria-label="Onera">
              <circle class="onera-mark-right" cx="15" cy="12" r="6" opacity="0.55" stroke="currentColor" stroke-linecap="round" stroke-width="2.4" />
              <circle class="onera-mark-left" cx="9" cy="12" r="6" stroke="currentColor" stroke-width="2.4" />
            </svg>
          </span>

          <p class="min-w-0 flex-1 text-sm leading-snug text-ink-700">
            <template v-if="canInstall">
              <span class="font-medium text-ink-900">Keep Onera on your home screen.</span>
              Opens straight in, no browser.
            </template>
            <template v-else>
              <span class="font-medium text-ink-900">Add Onera to your home screen.</span>
              Open
              <svg class="mx-0.5 inline h-4 w-4 -translate-y-px" fill="none" stroke="currentColor" stroke-width="1.8" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 16V4m0 0L8 8m4-4l4 4M5 15v3a2 2 0 002 2h10a2 2 0 002-2v-3" />
              </svg>
              {{ shareLocation }}, then scroll down to
              <span class="font-medium text-ink-900">Add to Home Screen</span>.
              <span class="block text-ink-500">It is below the row of apps — and hidden in Private Browsing.</span>
            </template>
          </p>

          <button
            v-if="canInstall"
            type="button"
            class="btn-primary btn-sm shrink-0"
            @click="install"
          >
            Add
          </button>
          <button
            type="button"
            class="press grid h-8 w-8 shrink-0 place-items-center rounded-full text-ink-400 transition hover:bg-ink-100"
            aria-label="Not now"
            @click="dismiss"
          >
            <svg class="icon-md" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" d="M6 6l12 12M18 6L6 18" />
            </svg>
          </button>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.install-enter-active {
  transition: transform 0.42s cubic-bezier(0.22, 1, 0.36, 1), opacity 0.3s ease;
}
.install-leave-active {
  transition: transform 0.24s cubic-bezier(0.4, 0, 1, 1), opacity 0.2s ease;
}
.install-enter-from,
.install-leave-to {
  transform: translateY(120%);
  opacity: 0;
}
</style>
