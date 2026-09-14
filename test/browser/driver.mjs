// A small Chrome DevTools Protocol driver.
//
// Cypress or Playwright would each pull in a large toolchain for what this
// needs to do: open pages, click things a person would click, type into
// fields, and read what came back. This talks to the browser directly.

import { spawn } from 'node:child_process';
import http from 'node:http';
import fs from 'node:fs';
import WebSocket from 'ws';

const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

export class Browser {
  constructor({ port = 9400, width = 430, height = 932, profile = '/tmp/onera-e2e', headless = true } = {}) {
    this.port = port;
    this.width = width;
    this.height = height;
    this.profile = profile;
    this.headless = headless;
    this.id = 0;
    this.pending = new Map();
    this.consoleErrors = [];
    this.pageErrors = [];
    this.failedRequests = [];
  }

  async start() {
    fs.rmSync(this.profile, { recursive: true, force: true });
    this.chrome = spawn(CHROME, [
      ...(this.headless ? ['--headless=new'] : []),
      `--remote-debugging-port=${this.port}`,
      '--no-first-run',
      '--no-default-browser-check',
      '--hide-scrollbars',
      '--disable-background-timer-throttling',
      `--window-size=${this.width},${this.height}`,
      `--user-data-dir=${this.profile}`,
    ]);

    let target = null;
    for (let i = 0; i < 60 && !target; i++) {
      try {
        const list = await this.#json('/json/list');
        target = list.find((t) => t.type === 'page');
      } catch {
        await sleep(250);
      }
    }
    if (!target) throw new Error('Chrome did not start');

    this.ws = new WebSocket(target.webSocketDebuggerUrl, { perMessageDeflate: false });
    this.ws.on('message', (raw) => this.#onMessage(JSON.parse(raw)));
    await new Promise((resolve, reject) => {
      this.ws.on('open', resolve);
      this.ws.on('error', reject);
    });

    await this.send('Page.enable');
    await this.send('Runtime.enable');
    await this.send('Network.enable');
    await this.send('Log.enable');
    await this.send('Emulation.setDeviceMetricsOverride', {
      width: this.width, height: this.height, deviceScaleFactor: 2, mobile: this.width < 700,
    });
  }

  #json(path) {
    return new Promise((resolve, reject) => {
      http.get({ host: '127.0.0.1', port: this.port, path }, (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => resolve(JSON.parse(data)));
      }).on('error', reject);
    });
  }

  #onMessage(msg) {
    if (msg.id && this.pending.has(msg.id)) {
      const { resolve, reject } = this.pending.get(msg.id);
      this.pending.delete(msg.id);
      msg.error ? reject(new Error(msg.error.message)) : resolve(msg.result);
      return;
    }

    if (msg.method === 'Runtime.consoleAPICalled' && msg.params.type === 'error') {
      this.consoleErrors.push(msg.params.args.map((a) => a.value ?? a.description ?? '').join(' '));
    }
    if (msg.method === 'Runtime.exceptionThrown') {
      const d = msg.params.exceptionDetails;
      this.pageErrors.push(d.exception?.description || d.text);
    }
    if (msg.method === 'Network.responseReceived') {
      const { status, url } = msg.params.response;
      if (status >= 400 && !url.includes('favicon')) this.failedRequests.push(`${status} ${url}`);
    }
  }

  // Every call is bounded. A protocol call that never comes back - a promise
  // in the page that never settles, a navigation that stalls - would
  // otherwise hang the whole suite with no output at all.
  send(method, params = {}, timeout = 15000) {
    const id = ++this.id;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`${method} timed out after ${timeout}ms`));
      }, timeout);

      this.pending.set(id, {
        resolve: (value) => { clearTimeout(timer); resolve(value); },
        reject: (error) => { clearTimeout(timer); reject(error); },
      });

      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }

  async evaluate(expression) {
    const { result, exceptionDetails } = await this.send('Runtime.evaluate', {
      // async so scenarios can await fetch() inside an evaluate block.
      expression: `(async () => { ${expression} })()`,
      returnByValue: true,
      awaitPromise: true,
    });
    if (exceptionDetails) throw new Error(exceptionDetails.exception?.description || exceptionDetails.text);
    return result.value;
  }

  async goto(url, { settle = 900 } = {}) {
    await this.send('Page.navigate', { url });
    await this.waitForLoad();
    await sleep(settle);
  }

  async waitForLoad(timeout = 10000) {
    const deadline = Date.now() + timeout;
    while (Date.now() < deadline) {
      const state = await this.evaluate('return document.readyState');
      if (state === 'complete') return;
      await sleep(100);
    }
    throw new Error('page did not finish loading');
  }

  url() { return this.evaluate('return location.pathname + location.search'); }
  text() { return this.evaluate('return document.body.innerText'); }
  title() { return this.evaluate('return document.title'); }

  async has(text) {
    return this.evaluate(
      `return document.body.innerText.toLowerCase().includes(${JSON.stringify(text.toLowerCase())})`
    );
  }

  async waitForText(text, timeout = 8000) {
    const deadline = Date.now() + timeout;
    while (Date.now() < deadline) {
      if (await this.has(text)) return true;
      await sleep(150);
    }
    throw new Error(`timed out waiting for text: ${text}`);
  }

  async waitFor(selector, timeout = 8000) {
    const deadline = Date.now() + timeout;
    while (Date.now() < deadline) {
      if (await this.evaluate(`return !!document.querySelector(${JSON.stringify(selector)})`)) return true;
      await sleep(150);
    }
    throw new Error(`timed out waiting for selector: ${selector}`);
  }

  // Clicks the first visible element whose trimmed text matches, the way a
  // person picks a button by reading it.
  async clickText(label, { selector = 'button, a, summary, label, input[type=submit]', exact = false } = {}) {
    const clicked = await this.evaluate(`
      const wanted = ${JSON.stringify(label)};
      const nodes = [...document.querySelectorAll(${JSON.stringify(selector)})];
      const match = nodes.find((el) => {
        const t = (el.innerText || el.value || '').trim().toLowerCase();
        const w = wanted.toLowerCase();
        const hit = ${exact} ? t === w : t.includes(w);
        return hit && el.offsetParent !== null;
      });
      if (!match) return false;
      match.scrollIntoView({ block: 'center' });
      match.click();
      return true;
    `);
    if (!clicked) {
      throw new Error(`no clickable element matching: ${label} (on ${await this.url()}; ${await this.snippet()})`);
    }
    await sleep(500);
  }

  // Some controls are icon-only on a phone, so their accessible name is the
  // only thing to aim at - which is also how a screen-reader user finds them.
  async clickLabel(label) {
    const clicked = await this.evaluate(`
      const wanted = ${JSON.stringify(label)};
      const match = [...document.querySelectorAll('[aria-label]')].find(
        (el) => el.getAttribute('aria-label').includes(wanted) && el.offsetParent !== null
      );
      if (!match) return false;
      match.scrollIntoView({ block: 'center' });
      match.click();
      return true;
    `);
    if (!clicked) throw new Error(`no element with aria-label matching: ${label}`);
    await sleep(600);
  }

  async click(selector) {
    const ok = await this.evaluate(`
      const el = document.querySelector(${JSON.stringify(selector)});
      if (!el) return false;
      el.scrollIntoView({ block: 'center' });
      el.click();
      return true;
    `);
    if (!ok) throw new Error(`no element matching: ${selector}`);
    await sleep(400);
  }

  // Sets a value through the native setter so Vue's v-model sees it.
  async fill(selector, value) {
    const ok = await this.evaluate(`
      const el = document.querySelector(${JSON.stringify(selector)});
      if (!el) return false;
      const proto = el instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
      Object.getOwnPropertyDescriptor(proto, 'value').set.call(el, ${JSON.stringify(String(value))});
      el.dispatchEvent(new Event('input', { bubbles: true }));
      el.dispatchEvent(new Event('change', { bubbles: true }));
      return true;
    `);
    if (!ok) throw new Error(`no field matching: ${selector} (on ${await this.url()}; ${await this.snippet()})`);
    await sleep(250);
  }

  async select(selector, value) {
    const ok = await this.evaluate(`
      const el = document.querySelector(${JSON.stringify(selector)});
      if (!el) return false;
      el.value = ${JSON.stringify(String(value))};
      el.dispatchEvent(new Event('change', { bubbles: true }));
      return true;
    `);
    if (!ok) throw new Error(`no select matching: ${selector}`);
    await sleep(300);
  }

  // A short, one-line view of the page, for failure messages.
  async snippet(length = 140) {
    const text = await this.evaluate('return document.body.innerText');
    return `page says: ${text.replace(/\s+/g, ' ').trim().slice(0, length)}`;
  }

  async screenshot(name) {
    fs.mkdirSync('/tmp/onera-e2e-shots', { recursive: true });
    const { data } = await this.send('Page.captureScreenshot', { format: 'png' });
    fs.writeFileSync(`/tmp/onera-e2e-shots/${name}.png`, Buffer.from(data, 'base64'));
  }

  // Anything horizontally overflowing, or an offscreen control - the classes
  // of layout bug that don't throw but do ruin a phone screen.
  async layoutProblems() {
    return this.evaluate(`
      const out = [];
      const vw = window.innerWidth;
      if (document.documentElement.scrollWidth > vw + 1) {
        out.push('page scrolls horizontally (' + document.documentElement.scrollWidth + ' > ' + vw + ')');
      }
      document.querySelectorAll('button, a, input, select, textarea').forEach((el) => {
        const r = el.getBoundingClientRect();
        if (r.width === 0 || r.height === 0) return;
        if (r.right > vw + 1) out.push('offscreen right: ' + (el.innerText || el.name || el.tagName).trim().slice(0, 40));
        if (r.left < -1) out.push('offscreen left: ' + (el.innerText || el.name || el.tagName).trim().slice(0, 40));
      });
      return out;
    `);
  }

  drain() {
    const snapshot = {
      consoleErrors: [...this.consoleErrors],
      pageErrors: [...this.pageErrors],
      failedRequests: [...this.failedRequests],
    };
    this.consoleErrors = [];
    this.pageErrors = [];
    this.failedRequests = [];
    return snapshot;
  }

  async stop() {
    try { this.ws?.close(); } catch { /* already gone */ }
    this.chrome?.kill();
  }
}

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
