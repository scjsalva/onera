// End-to-end journeys, driven through a real browser as a person would.
//
// Usage: node test/browser/run.mjs [name-filter]
// The app must be running on localhost:3000 with a freshly seeded database.

import { Browser, sleep } from './driver.mjs';

const BASE = process.env.ONERA_URL || 'http://localhost:3000';
const filter = process.argv[2];

const scenarios = [];
export const scenario = (name, fn) => scenarios.push({ name, fn });

let currentFailures = [];
export function check(condition, message) {
  if (!condition) currentFailures.push(message);
}

// Always starts from no session. Scenarios used to inherit whoever the last
// one left signed in, which made failures depend on the order they ran in.
export async function signIn(b, login, password = 'password') {
  await signOut(b);
  await b.goto(`${BASE}/sign-in`);

  await b.fill('#user_login', login);
  await b.fill('#user_password', password);
  await b.clickText('Sign in');
  await b.waitForLoad();
  await sleep(700);

  // Email is optional and asked for once per sign-in; dismiss it so journeys
  // are not interrupted by a prompt they are not about.
  if ((await b.url()).startsWith('/email/edit')) {
    await b.clickText('Not now');
    await b.waitForLoad();
    await sleep(400);
  }
}

// Posts the sign-out directly rather than hunting for a button on a page that
// may have been redirected somewhere else.
export async function signOut(b) {
  await b.goto(`${BASE}/`);
  await b.evaluate(`
    const token = document.querySelector('meta[name="csrf-token"]')?.content;
    if (!token) return false;
    const form = document.createElement('form');
    form.method = 'post';
    form.action = '/sign-out';
    form.innerHTML =
      '<input name="_method" value="delete">' +
      '<input name="authenticity_token" value="' + token + '">';
    document.body.appendChild(form);
    form.submit();
    return true;
  `);
  await b.waitForLoad();
  await sleep(500);
}

for (const file of [ './scenarios.mjs', './scenarios_extra.mjs' ]) {
  const { default: register } = await import(file);
  register({ scenario, check, signIn, signOut, BASE, sleep });
}

const b = new Browser({ headless: process.env.HEADED !== '1' });
await b.start();

// Without this a scenario that leaves a rejected promise behind kills the
// process silently, part-way through the list.
process.on('unhandledRejection', (reason) => {
  console.log(`\n\x1b[31munhandled rejection\x1b[0m: ${reason}`);
});

let passed = 0;
const failures = [];

for (const { name, fn } of scenarios) {
  if (filter && !name.includes(filter)) continue;

  currentFailures = [];
  b.drain();
  process.stdout.write(`• ${name} … `);

  try {
    await fn(b);
    const noise = b.drain();
    // A page that throws in the console is broken even if the assertions pass.
    noise.pageErrors.forEach((e) => currentFailures.push(`js error: ${e.split('\n')[0]}`));
      // 4xx is often the correct answer (a refused login, a blocked group), so
    // scenarios assert on those themselves. A 5xx is never expected.
    noise.failedRequests
      .filter((r) => /^5\d\d /.test(r))
      .forEach((r) => currentFailures.push(`server error: ${r}`));

    if (currentFailures.length === 0) {
      console.log('\x1b[32mpass\x1b[0m');
      passed++;
    } else {
      console.log('\x1b[31mFAIL\x1b[0m');
      currentFailures.forEach((f) => console.log(`    - ${f}`));
      failures.push(name);
      await b.screenshot(`fail-${name.replace(/[^a-z0-9]+/gi, '-')}`);
    }
  } catch (error) {
    console.log('\x1b[31mERROR\x1b[0m');
    console.log(`    ${error.message.split('\n')[0]}`);
    failures.push(name);
    await b.screenshot(`error-${name.replace(/[^a-z0-9]+/gi, '-')}`);
  }
}

await b.stop();

console.log(`\n${passed} passed, ${failures.length} failed`);
if (failures.length) {
  console.log('failed:', failures.join(', '));
  process.exit(1);
}
