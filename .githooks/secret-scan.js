#!/usr/bin/env node
// Pre-commit secret scan (MyHazMate secrets policy, claude-files/SECRETS_INVENTORY.md).
// Blocks staged secret FILES and added LINES that look like live secrets. Never prints the value.
// Supabase anon JWTs are allowed (public by design); service_role JWTs are blocked.
// False positive? Fix the line (read the value from env). Do not bypass with --no-verify without Zac's OK.
const { execSync } = require('child_process');
const sh = (c) => execSync(c, { encoding: 'utf8', maxBuffer: 256 * 1024 * 1024 });

const BAD_FILES = [
  [/(^|\/)\.env(\.[^/]*)?$/i, 'env file', (f) => !/\.(example|template|sample)$/i.test(f)],
  [/(^|\/)Keys\//, 'Keys/ folder'],
  [/\.(p8|p12|pfx|pem|key|jks|keystore)$/i, 'private key / keystore file'],
  [/(^|\/)secrets\.env$/i, 'secrets.env'],
  [/service[-_]?account.*\.json$/i, 'service account json'],
];
const RULES = [
  ['Supabase secret key', /sb_secret_[A-Za-z0-9_-]{20,}/],
  ['Anthropic key', /sk-ant-[A-Za-z0-9_-]{20,}/],
  ['Stripe / RevenueCat secret or restricted key', /\b(sk|rk)_(live|test)_[A-Za-z0-9]{16,}/],
  ['RevenueCat secret key', /\bsk_[A-Za-z0-9]{24,}\b/],
  ['Webhook signing secret', /\bwhsec_[A-Za-z0-9]{16,}/],
  ['Private key block', /-----BEGIN [A-Z ]*PRIVATE KEY-----/],
  ['Service account private key', /"private_key"\s*:\s*"-----BEGIN/],
  ['Discord webhook URL', /discord(app)?\.com\/api\/webhooks\/\d+\/[A-Za-z0-9_-]{20,}/],
  ['GitHub token', /\b(ghp|gho|ghs|ghu)_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}/],
  ['Google OAuth client secret', /GOCSPX-[A-Za-z0-9_-]{20,}/],
  ['Slack token', /xox[baprs]-[A-Za-z0-9-]{10,}/],
  ['AWS access key', /\bAKIA[0-9A-Z]{16}\b/],
  ['Postgres URL with password', /postgres(ql)?:\/\/[^:\s\/@]+:[^@\s$<{]{6,}@/],
  ['Basic auth header literal', /Basic\s+[A-Za-z0-9+\/]{24,}={0,2}/],
  ['Password/secret assignment with literal value',
    /(PASSWORD|PASSWD|_PASS|SECRET|API_KEY|APIKEY|ACCESS_TOKEN|AUTH_TOKEN)["']?\s*[:=]\s*["'`][^"'`\s$<{}]{12,}["'`]/i],
];
const JWT = /eyJ[A-Za-z0-9_-]{10,}\.(eyJ[A-Za-z0-9_-]{10,})\.[A-Za-z0-9_-]{10,}/g;

const problems = [];
const files = sh('git diff --cached --name-only --diff-filter=ACMR').split('\n').filter(Boolean);
for (const f of files) {
  for (const [re, what, extra] of BAD_FILES) if (re.test(f) && (!extra || extra(f))) problems.push(`${f}: ${what} must not be committed`);
}
let cur = '', line = 0;
for (const l of sh('git diff --cached -U0 --no-color --diff-filter=ACMR').split('\n')) {
  if (l.startsWith('+++ ')) { cur = l.slice(6); continue; }
  const h = l.match(/^@@ -\d+(?:,\d+)? \+(\d+)/); if (h) { line = +h[1]; continue; }
  if (!l.startsWith('+') || l.startsWith('+++')) { continue; }
  const text = l.slice(1);
  if (/secret-scan: allow/.test(text)) { line++; continue; }
  for (const [name, re] of RULES) if (re.test(text)) problems.push(`${cur}:${line}: ${name}`);
  for (const m of text.matchAll(JWT)) {
    let role = '?';
    try { role = JSON.parse(Buffer.from(m[1], 'base64url').toString()).role || '?'; } catch {}
    if (role !== 'anon') problems.push(`${cur}:${line}: JWT with role "${role}" (only the public anon key may be committed)`);
  }
  line++;
}
if (problems.length) {
  console.error('\nCOMMIT BLOCKED by .githooks/secret-scan.js (values not shown):');
  for (const p of problems.slice(0, 50)) console.error('  - ' + p);
  console.error('\nMove the value to an env var / Vercel / server env file (see MyHazMate claude-files/SECRETS_INVENTORY.md).');
  console.error('Example/placeholder text that trips a rule: add the comment "secret-scan: allow" on that line.\n');
  process.exit(1);
}
