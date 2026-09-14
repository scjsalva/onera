// The journeys. Written as things a person does, including the things they
// do wrong, since that is where the bugs live.

export default function register({ scenario, check, signIn, signOut, BASE, sleep }) {
  // Creates the shared trip if a previous journey has not already, so
  // scenarios can be run individually or in any order.
  async function ensureGroup(b, name = 'E2E Trip') {
    await b.goto(`${BASE}/groups`);
    if (await b.has(name)) return;

    await b.goto(`${BASE}/groups/new`);
    await b.fill('#group_name', name);
    await b.clickText('Christian');
    await b.clickText('Lydia');
    await b.clickText('Create group');
    await b.waitForLoad();
    await sleep(700);
  }

  async function openGroup(b, name = 'E2E Trip') {
    await ensureGroup(b, name);
    await b.goto(`${BASE}/groups`);
    await b.clickText(name);
    await b.waitForLoad();
    await sleep(400);
  }

  // ---------------------------------------------------------------- auth

  scenario('signed out visitors are sent to sign in', async (b) => {
    await b.goto(`${BASE}/`);
    check((await b.url()).startsWith('/sign-in'), `expected /sign-in, got ${await b.url()}`);
    check(await b.has('Onera'), 'sign-in page should be branded');
  });

  scenario('wrong password is refused', async (b) => {
    await signIn(b, 'scjsalva', 'not-the-password');
    check(!(await b.url()).match(/^\/$/), 'should not reach the dashboard');
    check(await b.has('Invalid'), `expected an error, page said: ${(await b.text()).slice(0, 120)}`);
  });

  scenario('unknown email is refused the same way', async (b) => {
    await signIn(b, 'nobodyatall', 'password');
    check(await b.has('Invalid'), 'unknown email should fail like a wrong password');
  });

  scenario('signing in reaches the dashboard', async (b) => {
    await signIn(b, 'scjsalva');
    check((await b.url()) === '/', `expected /, got ${await b.url()}`);
    check(await b.has('John'), 'dashboard should greet the person');
  });

  scenario('signing out ends the session', async (b) => {
    await signIn(b, 'scjsalva');
    await signOut(b);
    await b.goto(`${BASE}/`);
    check((await b.url()).startsWith('/sign-in'), 'should be signed out');
  });

  // ------------------------------------------------------------- groups

  scenario('creating a group and adding people', async (b) => {
    await signIn(b, 'scjsalva');
    await b.goto(`${BASE}/groups/new`);
    await b.fill('#group_name', 'E2E Trip');
    await b.fill('#group_description', 'Driven by the test suite');
    await b.clickText('Christian');
    await b.clickText('Lydia');
    await b.clickText('Create group');
    await b.waitForLoad();
    await sleep(600);
    check(await b.has('E2E Trip'), 'should land on the new group');
    const members = await b.evaluate(`
      const r = await fetch('/groups/' + location.pathname.split('/')[2] + '/memberships.json', { headers: { Accept: 'application/json' } });
      const j = await r.json();
      return j.members.length;
    `);
    check(members === 3, `expected 3 members, got ${members}`);
  });

  scenario('an expense splits and shows my position', async (b) => {
    await signIn(b, 'scjsalva');
    await openGroup(b);
    await b.clickLabel('Add an expense');
    await sleep(900);
    await b.fill('[role=dialog] input[placeholder="What was it for?"]', 'Hotel');
    await b.fill('[role=dialog] input[inputmode=decimal]', '3000');
    await sleep(600);
    await b.clickText('Continue');
    await sleep(900);
    await b.clickText('Add expense');
    await b.waitForLoad();
    await sleep(900);
    check(await b.has('Hotel'), 'the expense should be listed');
    check(await b.has('you lent'), 'my own position should lead the row');
  });

  scenario('balances lead with what I am owed', async (b) => {
    await signIn(b, 'scjsalva');
    await openGroup(b);
    await b.clickText('Balances');
    await b.waitForLoad();
    await sleep(600);
    check(await b.has('Your position here'), 'my position should come first');
    check(await b.has('Owes you'), 'should list who owes me');
    check(await b.has('₱2,000.00'), `expected ₱2,000.00 owed to me, saw: ${(await b.text()).slice(0, 300)}`);
  });

  // ------------------------------------------------- validation and edges

  scenario('an expense with no amount cannot be submitted', async (b) => {
    await signIn(b, 'scjsalva');
    await openGroup(b);
    await b.clickLabel('Add an expense');
    await sleep(800);
    await b.fill('[role=dialog] input[placeholder="What was it for?"]', 'No amount');
    await sleep(400);
    const disabled = await b.evaluate(`
      const btn = [...document.querySelectorAll('[role=dialog] button')].find((x) => /Continue|Add expense/.test(x.innerText));
      return btn ? btn.disabled : null;
    `);
    check(disabled === true, 'the action should stay disabled without an amount');
  });

  scenario('percentages that do not total 100 are rejected', async (b) => {
    await signIn(b, 'scjsalva');
    await b.goto(`${BASE}/`);
    const result = await b.evaluate(`
      const token = document.querySelector('meta[name="csrf-token"]').content;
      const res = await fetch('/api/split_previews', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': token, Accept: 'application/json' },
        body: JSON.stringify({ amount: '100', currency_code: 'PHP', split_method: 'percentage',
                               participants: [{ user_id: 1, split_value: '70' }, { user_id: 2, split_value: '20' }] }),
      });
      return await res.json();
    `);
    check(result.valid === false, 'a 90% split should not validate');
    check(/100%/.test(result.errors.join(' ')), `expected a percentage error, got ${JSON.stringify(result.errors)}`);
  });

  scenario('a group I am not in is not reachable', async (b) => {
    await signIn(b, 'scjsalva');
    const id = await b.evaluate(`
      const r = await fetch('/groups', { headers: { Accept: 'text/html' } });
      const html = await r.text();
      const m = html.match(/\\/groups\\/(\\d+)/);
      return m ? Number(m[1]) : null;
    `);
    await signIn(b, 'aegonia');
    await b.goto(`${BASE}/groups/${id}`);
    check((await b.url()) === '/', `an outsider should be redirected away, landed on ${await b.url()}`);
    check(!(await b.has('E2E Trip')), 'the group name must not leak');
  });

  scenario('a group that does not exist redirects rather than erroring', async (b) => {
    await signIn(b, 'scjsalva');
    await b.goto(`${BASE}/groups/999999`);
    check((await b.url()) === '/', 'should redirect home');
    check(!(await b.has('Exception')), 'should not show an exception page');
  });

  // ------------------------------------------------------- notifications

  scenario('being added to a group notifies the person', async (b) => {
    await signIn(b, 'cnasayao');
    await b.goto(`${BASE}/notifications`);
    check(await b.has('added you to E2E Trip'), `expected an invite notification, saw: ${(await b.text()).slice(0, 200)}`);
  });

  scenario('an expense notifies the people sharing it', async (b) => {
    await signIn(b, 'ljvalencia');
    await b.goto(`${BASE}/notifications`);
    check(await b.has('Hotel'), 'should be told about the expense she shares');
  });

  scenario('notifications can be marked read', async (b) => {
    await signIn(b, 'cnasayao');
    await b.goto(`${BASE}/notifications`);
    await b.clickText('Mark all read');
    await b.waitForLoad();
    await sleep(500);
    check(!(await b.has('unread')), 'the unread count should clear');
  });

  // ------------------------------------------------------------ account

  scenario('changing password requires the current one', async (b) => {
    await signIn(b, 'egblance');
    await b.goto(`${BASE}/password/edit`);
    await b.fill('#current_password', 'wrong-password');
    await b.fill('#password', 'newpassword123');
    await b.fill('#password_confirmation', 'newpassword123');
    await b.clickText('Change password');
    await b.waitForLoad();
    await sleep(400);
    check(await b.has("isn't your current password"), 'should refuse without the current password');
  });

  scenario('a short password is refused', async (b) => {
    await signIn(b, 'egblance');
    await b.goto(`${BASE}/password/edit`);
    await b.fill('#current_password', 'password');
    await b.fill('#password', 'short');
    await b.fill('#password_confirmation', 'short');
    await b.clickText('Change password');
    await b.waitForLoad();
    await sleep(400);
    check(await b.has('8 characters'), 'should require a minimum length');
  });

  scenario('changing password works and the new one signs in', async (b) => {
    await signIn(b, 'kaflores');
    await b.goto(`${BASE}/password/edit`);
    await b.fill('#current_password', 'password');
    await b.fill('#password', 'brand-new-secret');
    await b.fill('#password_confirmation', 'brand-new-secret');
    await b.clickText('Change password');
    await b.waitForLoad();
    await sleep(500);
    check(await b.has('Password changed'), 'should confirm the change');

    await signOut(b);
    await signIn(b, 'kaflores', 'brand-new-secret');
    check((await b.url()) === '/', 'the new password should sign in');
  });

  scenario('recovery codes can be generated and one signs you back in', async (b) => {
    await signIn(b, 'aegonia');
    // Codes are redeemed against an email, so the account needs one.
    await b.goto(`${BASE}/email/edit`);
    await b.fill('#user_email', 'andrew@onera.test');
    await b.clickText('Save email');
    await b.waitForLoad();
    await sleep(500);

    await b.goto(`${BASE}/recovery_codes`);

    // First generation asks nothing; a replacement asks before wiping the set.
    const replacing = await b.has('Replace my codes');
    await b.clickText(replacing ? 'Replace my codes' : 'Generate my codes');
    await sleep(700);
    if (replacing) {
      await b.clickText('Replace them');
    }
    await b.waitForLoad();
    await sleep(900);
    check(await b.has('Save these now'), 'the fresh codes should be shown once');

    const code = await b.evaluate(`
      const li = document.querySelector('.grid.grid-cols-2 li');
      return li ? li.innerText.replace(/^\\d+\\s*/, '').trim() : null;
    `);
    check(!!code && code.includes('-'), `expected a readable code, got ${code}`);

    await signOut(b);
    await b.goto(`${BASE}/recover`);
    await b.fill('#email', 'andrew@onera.test');
    await b.fill('#code', code);
    await b.fill('#password', 'recovered-password');
    await b.fill('#password_confirmation', 'recovered-password');
    await b.clickText('Set new password');
    await b.waitForLoad();
    await sleep(700);
    check((await b.url()) === '/', `recovery should sign me in, landed on ${await b.url()}`);
  });

  scenario('a spent recovery code cannot be reused', async (b) => {
    await signIn(b, 'andrew@onera.test', 'recovered-password');
    await b.goto(`${BASE}/recovery_codes`);
    const left = await b.evaluate(`
      const m = document.body.innerText.match(/(\\d+) of (\\d+)/);
      return m ? Number(m[1]) : null;
    `);
    check(left === 9, `expected 9 codes left after using one, got ${left}`);
  });

  // ------------------------------------------------- email and invitations

  scenario('the email prompt returns on every sign-in until answered', async (b) => {
    await signOut(b);
    await b.goto(`${BASE}/sign-in`);
    await b.fill('#user_login', 'ljvalencia');
    await b.fill('#user_password', 'password');
    await b.clickText('Sign in');
    await b.waitForLoad();
    await sleep(600);
    check((await b.url()).startsWith('/email/edit'), `expected the email prompt, got ${await b.url()}`);
    check(await b.has('only way back into your account'), 'the prompt should say why it matters');

    await b.clickText('Not now');
    await b.waitForLoad();
    await sleep(400);
    check((await b.url()) === '/', 'skipping should let me in');

    await b.goto(`${BASE}/groups`);
    check(!(await b.url()).startsWith('/email/edit'), 'it should stay quiet for the rest of the session');

    // A fresh sign-in asks again.
    await signOut(b);
    await b.goto(`${BASE}/sign-in`);
    await b.fill('#user_login', 'ljvalencia');
    await b.fill('#user_password', 'password');
    await b.clickText('Sign in');
    await b.waitForLoad();
    await sleep(600);
    check((await b.url()).startsWith('/email/edit'), 'the next sign-in should ask again');
  });

  scenario('saving an email stops the prompt for good', async (b) => {
    await signOut(b);
    await b.goto(`${BASE}/sign-in`);
    await b.fill('#user_login', 'egblance');
    await b.fill('#user_password', 'password');
    await b.clickText('Sign in');
    await b.waitForLoad();
    await sleep(600);

    await b.fill('#user_email', 'eilon@example.com');
    await b.clickText('Save email');
    await b.waitForLoad();
    await sleep(600);
    check((await b.url()) === '/', 'saving should land me on the dashboard');

    await signOut(b);
    await signIn(b, 'eilon@example.com');
    check((await b.url()) === '/', 'the email should now sign me in');
  });

  scenario('recovery codes need an email first', async (b) => {
    await signIn(b, 'cnasayao');
    await b.goto(`${BASE}/recovery_codes`);
    check(await b.has('Add an email first'), 'should explain why there are no codes yet');
  });

  scenario('an invite link lets a stranger sign themselves up', async (b) => {
    await signIn(b, 'scjsalva');
    await b.goto(`${BASE}/invitations`);
    const url = await b.evaluate("return document.querySelector('#invite-link-field').value");
    check(url.includes('/join/'), `expected an invite url, got ${url}`);
    check(url.startsWith(BASE), `the link should use the host it was served from, got ${url}`);

    await signOut(b);
    await b.goto(url);
    check(await b.has('Join Onera'), 'the link should open a signup form');

    await b.fill('#user_name', 'Newcomer Person');
    await b.fill('#user_username', 'newcomer');
    await b.fill('#user_password', 'newcomer-pass');
    await b.fill('#user_password_confirmation', 'newcomer-pass');
    await b.clickText('Create account');
    await b.waitForLoad();
    await sleep(800);
    check(!(await b.url()).includes('/join/'), `signup should go through, landed on ${await b.url()}`);
  });

  scenario('a mistyped password confirmation is refused at signup', async (b) => {
    await signIn(b, 'scjsalva');
    await b.goto(`${BASE}/invitations`);
    const url = await b.evaluate("return document.querySelector('#invite-link-field').value");

    await signOut(b);
    await b.goto(url);
    await b.fill('#user_name', 'Typo Person');
    await b.fill('#user_username', 'typoperson');
    await b.fill('#user_password', 'one-password');
    await b.fill('#user_password_confirmation', 'other-password');
    await b.clickText('Create account');
    await b.waitForLoad();
    await sleep(600);
    check(await b.has("doesn't match"), 'should say the confirmation does not match');
  });

  scenario('a duplicate username is refused at signup', async (b) => {
    await signIn(b, 'scjsalva');
    await b.goto(`${BASE}/invitations`);
    const url = await b.evaluate("return document.querySelector('#invite-link-field').value");

    await signOut(b);
    await b.goto(url);
    await b.fill('#user_name', 'Copycat');
    await b.fill('#user_username', 'scjsalva');
    await b.fill('#user_password', 'copycat-pass');
    await b.fill('#user_password_confirmation', 'copycat-pass');
    await b.clickText('Create account');
    await b.waitForLoad();
    await sleep(600);
    check(await b.has('already been taken'), 'should say the username is taken');
  });

  // ------------------------------------------------------------- layout

  scenario('no page overflows a phone screen', async (b) => {
    await signIn(b, 'scjsalva');
    const paths = ['/', '/groups', '/expenses', '/balances', '/activity', '/insights',
                   '/people', '/profile', '/profile/edit', '/notifications',
                   '/password/edit', '/recovery_codes'];
    for (const path of paths) {
      await b.goto(`${BASE}${path}`);
      const problems = await b.layoutProblems();
      problems.forEach((p) => check(false, `${path}: ${p}`));
    }
  });
}
