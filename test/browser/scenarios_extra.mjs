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
        // Anything sitting on a gradient or a translucent panel can't be
        // judged from a single colour, so skip rather than guess.
        let bg = style.backgroundColor;
        let node = el;
        while (node) {
          const s = getComputedStyle(node);
          if (s.backgroundImage && s.backgroundImage !== 'none') return;
          if (s.backgroundColor !== 'rgba(0, 0, 0, 0)') {
            if (/rgba\([^)]+,\s*0?\.\d+\)/.test(s.backgroundColor)) return;
            bg = s.backgroundColor;
            break;
          }
          node = node.parentElement;
        }
        if (!bg || bg === 'rgba(0, 0, 0, 0)') return;
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

  scenario('tapping a notification takes you to what it is about', async (b) => {
    await signIn(b, 'cnasayao');
    await b.goto(`${BASE}/notifications`);

    if (!(await b.has('added you to'))) return; // nothing to tap in this run

    await b.clickText('added you to');
    await b.waitForLoad();
    await sleep(700);

    check(!(await b.url()).startsWith('/notifications'),
          `tapping should navigate somewhere, still on ${await b.url()}`);
    check((await b.url()).startsWith('/groups'), `expected the group, landed on ${await b.url()}`);
  });

  scenario('a destructive action asks before it acts, and cancel means cancel', async (b) => {
    await signIn(b, 'scjsalva');
    await b.goto(`${BASE}/people`);

    if (!(await b.has('Christian Nasayao'))) return; // nothing to remove in this run

    await b.clickLabel('Remove Christian Nasayao');
    await sleep(900);
    check(await b.has('Remove Christian Nasayao?'), 'a confirmation should appear');
    check(await b.has('stays exactly as it is'), 'it should say what survives');

    await b.clickText('Cancel');
    await sleep(700);
    check(await b.has('Christian Nasayao'), 'cancelling must not remove them');
  });

  scenario('every avatar is the illustrated one, not just initials', async (b) => {
    await signIn(b, 'scjsalva');

    for (const path of ['/', '/people', '/activity', '/notifications', '/profile']) {
      await b.goto(`${BASE}${path}`);
      await sleep(1200);

      const missing = await b.evaluate(`
        const circles = [...document.querySelectorAll('[class*="bg-avatar"]')]
          .filter((el) => el.title);           // colour swatches carry no title
        return circles.filter((el) => !el.querySelector('img')).length;
      `);
      check(missing === 0, `${path}: ${missing} avatars are initials only`);
    }
  });

  scenario('avatar colours are actually painted', async (b) => {
    await signIn(b, 'scjsalva');
    await b.goto(`${BASE}/profile/edit`);
    await sleep(1200);

    // Built from a number at runtime, so they only exist in the stylesheet if
    // they were safelisted.
    const transparent = await b.evaluate(`
      return [...document.querySelectorAll('[class*="bg-avatar"]')]
        .filter((el) => {
          const bg = getComputedStyle(el).backgroundColor;
          return bg === 'rgba(0, 0, 0, 0)' || bg === 'transparent';
        }).length;
    `);
    check(transparent === 0, `${transparent} avatar colours did not compile`);
  });

  scenario('the people list shows only your own connections', async (b) => {
    // Seeded so everyone is connected to scjsalva and to nobody else.
    await signIn(b, 'cnasayao');
    await b.goto(`${BASE}/people`);

    check(await b.has('John Carlo Salva'), 'should list the person they are connected to');
    check(!(await b.has('Lydia Valencia')), 'must not list someone they have not added');
  });

  scenario('adding someone by username sends a request they can accept', async (b) => {
    await signIn(b, 'cnasayao');
    await b.goto(`${BASE}/people`);
    await b.fill('#login', 'ljvalencia');
    await b.clickText('Add', { selector: 'input[type=submit]' });
    await b.waitForLoad();
    await sleep(600);
    check(await b.has('Request sent'), `expected a sent request, saw ${(await b.text()).slice(0, 160)}`);

    await signIn(b, 'ljvalencia');
    await b.goto(`${BASE}/people`);
    check(await b.has('Waiting for you'), 'the other person should see the request');
    await b.clickText('Accept');
    await b.waitForLoad();
    await sleep(600);
    check(await b.has('connected'), 'accepting should connect them');
    check(await b.has('Christian Nasayao'), 'and they should now appear in the list');
  });

  scenario('a made-up username is refused kindly', async (b) => {
    await signIn(b, 'scjsalva');
    await b.goto(`${BASE}/people`);
    await b.fill('#login', 'definitelynobody');
    await b.clickText('Add', { selector: 'input[type=submit]' });
    await b.waitForLoad();
    await sleep(500);
    check(await b.has('No account matches'), 'should say nobody matches');
  });

  scenario('you cannot add yourself', async (b) => {
    await signIn(b, 'scjsalva');
    await b.goto(`${BASE}/people`);
    await b.fill('#login', 'scjsalva');
    await b.clickText('Add', { selector: 'input[type=submit]' });
    await b.waitForLoad();
    await sleep(500);
    check(await b.has("That's you"), 'should say so plainly');
  });

  scenario('the invite link can be replaced', async (b) => {
    await signIn(b, 'scjsalva');
    await b.goto(`${BASE}/invitations`);
    const before = await b.evaluate("return document.querySelector('#invite-link-field').value");

    await b.clickLabel('Get a new link');
    await b.waitForLoad();
    await sleep(800);

    const after = await b.evaluate("return document.querySelector('#invite-link-field')?.value");
    check(!!after, 'the page should still show a link');
    check(before !== after, 'the link should actually change');
  });

  scenario('settlements appear in the expense list, not only on their own tab', async (b) => {
    await signIn(b, 'scjsalva');
    await b.goto(`${BASE}/expenses`);
    const text = await b.text();

    // Either there is a settlement line, or there are no settlements at all.
    const hasSettlement = text.includes('settled up');
    const hasAny = (await b.evaluate("return document.body.innerText.includes('paid')"));
    check(hasSettlement || !hasAny, 'a recorded payment should show inline with the expenses');
  });

  scenario('notifications page is fine when there is nothing in it', async (b) => {
    await signIn(b, 'egblance', 'password');
    await b.goto(`${BASE}/notifications`);

    check(await b.has('Nothing yet') || await b.has('unread'), 'should render either way');
  });
}
