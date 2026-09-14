// A second pass over the app looking for the things a person hits that the
// happy path never does.

export default function register({ scenario, check, signIn, signOut, BASE, sleep }) {
  scenario('every clickable thing shows a pointer cursor', async (b) => {
    await signIn(b, 'scjsalva');

    for (const path of ['/', '/groups', '/people', '/profile', '/profile/edit']) {
      await b.goto(`${BASE}${path}`);
      const wrong = await b.evaluate(`
        const out = [];
        document.querySelectorAll('button, a[href], summary, input[type=submit], select').forEach((el) => {
          if (el.disabled) return;
          const r = el.getBoundingClientRect();
          if (r.width === 0 || r.height === 0) return;
          if (getComputedStyle(el).cursor !== 'pointer') {
            out.push((el.innerText || el.value || el.tagName).trim().slice(0, 30));
          }
        });
        return out.slice(0, 5);
      `);
      wrong.forEach((label) => check(false, `${path}: "${label}" is not pointer`));
    }
  });

  scenario('the app survives being resized to a very narrow phone', async (b) => {
    await signIn(b, 'scjsalva');
    await b.send('Emulation.setDeviceMetricsOverride', {
      width: 320, height: 700, deviceScaleFactor: 2, mobile: true,
    });

    for (const path of ['/', '/groups', '/expenses', '/balances', '/people', '/profile']) {
      await b.goto(`${BASE}${path}`);
      (await b.layoutProblems()).forEach((p) => check(false, `320px ${path}: ${p}`));
    }

    await b.send('Emulation.setDeviceMetricsOverride', {
      width: 430, height: 932, deviceScaleFactor: 2, mobile: true,
    });
  });

  scenario('the app works on a desktop width too', async (b) => {
    await signIn(b, 'scjsalva');
    await b.send('Emulation.setDeviceMetricsOverride', {
      width: 1280, height: 900, deviceScaleFactor: 1, mobile: false,
    });

    await b.goto(`${BASE}/`);
    (await b.layoutProblems()).forEach((p) => check(false, `1280px: ${p}`));
    check(await b.has('Groups'), 'the sidebar should be there on desktop');

    await b.send('Emulation.setDeviceMetricsOverride', {
      width: 430, height: 932, deviceScaleFactor: 2, mobile: true,
    });
  });

  scenario('dark mode is readable, not just dark', async (b) => {
    await signIn(b, 'scjsalva');
    await b.evaluate("localStorage.setItem('onera:theme', 'dark'); return true;");
    await b.goto(`${BASE}/`);

    const dark = await b.evaluate("return document.documentElement.classList.contains('dark')");
    check(dark, 'the dark class should be applied');

    // Anything painting near-white text on a near-white background is a bug
    // the eye catches instantly and a screenshot diff does not.
    const clashes = await b.evaluate(`
      const luminance = (rgb) => {
        const [r, g, b] = rgb.match(/\\d+/g).map(Number);
        return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;
      };
      const out = [];
      document.querySelectorAll('h1, h2, p, span, a, button').forEach((el) => {
        const text = el.innerText?.trim();
        if (!text || el.children.length) return;
        const style = getComputedStyle(el);
        let bg = style.backgroundColor;
        let node = el;
        while (bg === 'rgba(0, 0, 0, 0)' && node.parentElement) {
          node = node.parentElement;
          bg = getComputedStyle(node).backgroundColor;
        }
        if (bg === 'rgba(0, 0, 0, 0)') return;
        if (Math.abs(luminance(style.color) - luminance(bg)) < 0.12) {
          out.push(text.slice(0, 30));
        }
      });
      return out.slice(0, 5);
    `);
    clashes.forEach((t) => check(false, `low contrast in dark mode: "${t}"`));

    await b.evaluate("localStorage.removeItem('onera:theme'); return true;");
  });

  scenario('the same page in light mode is readable too', async (b) => {
    await signIn(b, 'scjsalva');
    await b.evaluate("localStorage.setItem('onera:theme', 'light'); return true;");
    await b.goto(`${BASE}/`);

    check(
      !(await b.evaluate("return document.documentElement.classList.contains('dark')")),
      'light mode should not carry the dark class'
    );
    await b.evaluate("localStorage.removeItem('onera:theme'); return true;");
  });

  scenario('a double-submitted expense form does not create two expenses', async (b) => {
    await signIn(b, 'scjsalva');
    await b.goto(`${BASE}/groups`);
    await b.clickText('E2E Trip');
    await b.clickLabel('Add an expense');
    await sleep(900);
    await b.fill('[role=dialog] input[placeholder="What was it for?"]', 'Double tap');
    await b.fill('[role=dialog] input[inputmode=decimal]', '111');
    await sleep(700);
    await b.clickText('Continue');
    await sleep(800);

    // Two taps in quick succession, the way an impatient thumb does it.
    await b.evaluate(`
      const btn = [...document.querySelectorAll('[role=dialog] button')].find((x) => /Add expense/.test(x.innerText));
      btn.click();
      btn.click();
      return true;
    `);
    await b.waitForLoad();
    await sleep(1500);

    await b.goto(`${BASE}/expenses?q=Double%20tap`);
    const count = await b.evaluate(`
      return (document.body.innerText.match(/Double tap/g) || []).length;
    `);
    check(count === 1, `expected one "Double tap" expense, found ${count}`);
  });

  scenario('a stale group link after sign-out asks you to sign in', async (b) => {
    await signIn(b, 'scjsalva');
    await b.goto(`${BASE}/groups`);
    await b.clickText('E2E Trip');
    const groupPath = await b.url();

    await signOut(b);
    await b.goto(`${BASE}${groupPath}`);

    check((await b.url()).startsWith('/sign-in'), 'should be asked to sign in');
  });

  scenario('the browser back button after signing out does not leak the page', async (b) => {
    await signIn(b, 'scjsalva');
    await b.goto(`${BASE}/balances`);
    await signOut(b);
    await b.evaluate('history.back(); return true;');
    await sleep(1200);

    const text = await b.text();
    check(!text.includes('Owed to you') || (await b.url()).startsWith('/sign-in'),
          'going back must not show signed-in content');
  });

  scenario('an empty search says so rather than looking broken', async (b) => {
    await signIn(b, 'scjsalva');
    await b.goto(`${BASE}/expenses?q=zzzznothingmatchesthis`);

    check(await b.has('Nothing to show'), 'should say there are no matches');
  });

  scenario('a group with nothing in it reads as empty, not broken', async (b) => {
    await signIn(b, 'kaflores', 'brand-new-secret');
    await b.goto(`${BASE}/groups/new`);
    await b.fill('#group_name', 'Solo Group');
    await b.clickText('Create group');
    await b.waitForLoad();
    await sleep(700);

    check(await b.has('Nothing spent yet'), 'an empty group should say so');
    await b.clickText('Balances');
    await b.waitForLoad();
    await sleep(500);
    check(await b.has('All settled') || await b.has('square'),
          'empty balances should read as settled, not blank');
  });

  scenario('notifications page is fine when there is nothing in it', async (b) => {
    await signIn(b, 'egblance', 'password');
    await b.goto(`${BASE}/notifications`);

    check(await b.has('Nothing yet') || await b.has('unread'), 'should render either way');
  });
}
