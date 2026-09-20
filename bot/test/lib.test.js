import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { PassThrough } from 'node:stream';
import test from 'node:test';

import {
  PayloadTooLargeError,
  boundedText,
  parsePort,
  parseRobloxSignatureHeader,
  readBody,
  safeSecretEqual,
  stableWebhookNotificationKey,
  validateHttpsUrl,
  verifyRobloxWebhookSignature,
} from '../src/lib.js';

test('safeSecretEqual only accepts an exact string match', () => {
  assert.equal(safeSecretEqual('secret-value', 'secret-value'), true);
  assert.equal(safeSecretEqual('secret-value', 'secret-valuE'), false);
  assert.equal(safeSecretEqual('short', 'longer'), false);
  assert.equal(safeSecretEqual(['secret-value'], 'secret-value'), false);
});

test('boundedText removes nulls, trims, falls back, and enforces length', () => {
  assert.equal(boundedText('  abc\u0000def  ', 'fallback', 20), 'abcdef');
  assert.equal(boundedText('   ', 'fallback', 20), 'fallback');
  assert.equal(boundedText('123456', 'fallback', 4), '1234');
});

test('parsePort accepts valid ports and rejects invalid values', () => {
  assert.equal(parsePort(undefined, 8787), 8787);
  assert.equal(parsePort('443', 8787), 443);
  assert.throws(() => parsePort('0', 8787), /Invalid WEBHOOK_PORT/);
  assert.throws(() => parsePort('70000', 8787), /Invalid WEBHOOK_PORT/);
  assert.throws(() => parsePort('not-a-port', 8787), /Invalid WEBHOOK_PORT/);
});

test('validateHttpsUrl rejects non-HTTPS URLs', () => {
  assert.equal(
    validateHttpsUrl('https://www.roblox.com/games/75490500628229'),
    'https://www.roblox.com/games/75490500628229',
  );
  assert.throws(() => validateHttpsUrl('http://example.com'), /must use https/);
});

test('parseRobloxSignatureHeader requires one timestamp and one v1 signature', () => {
  assert.deepEqual(parseRobloxSignatureHeader('t=1700000000,v1=abc123'), {
    timestamp: '1700000000',
    signature: 'abc123',
  });
  assert.deepEqual(parseRobloxSignatureHeader('v1=abc123, t=1700000000'), {
    timestamp: '1700000000',
    signature: 'abc123',
  });
  assert.equal(parseRobloxSignatureHeader('t=1700000000'), null);
  assert.equal(parseRobloxSignatureHeader('t=1700000000,t=1700000001,v1=x'), null);
  assert.equal(parseRobloxSignatureHeader(undefined), null);
});

test('verifyRobloxWebhookSignature accepts a fresh authentic payload', () => {
  const secret = '0123456789abcdef0123456789abcdef';
  const timestamp = 1_700_000_000;
  const payload = {
    NotificationId: 'notification-1',
    EventType: 'SampleNotification',
    EventTime: '2023-11-14T22:13:20Z',
    EventPayload: { UserId: 1 },
  };
  const message = `${timestamp}.${JSON.stringify(payload)}`;
  const signature = crypto.createHmac('sha256', secret).update(message).digest('base64');

  assert.equal(
    verifyRobloxWebhookSignature(`t=${timestamp},v1=${signature}`, secret, payload, {
      nowMs: timestamp * 1000,
    }),
    true,
  );
});

test('verifyRobloxWebhookSignature rejects stale, future, and invalid signatures', () => {
  const secret = '0123456789abcdef0123456789abcdef';
  const timestamp = 1_700_000_000;
  const payload = { NotificationId: 'notification-2' };
  const message = `${timestamp}.${JSON.stringify(payload)}`;
  const signature = crypto.createHmac('sha256', secret).update(message).digest('base64');
  const header = `t=${timestamp},v1=${signature}`;

  assert.equal(
    verifyRobloxWebhookSignature(header, secret, payload, {
      nowMs: (timestamp + 301) * 1000,
    }),
    false,
  );
  assert.equal(
    verifyRobloxWebhookSignature(header, secret, payload, {
      nowMs: (timestamp - 301) * 1000,
    }),
    false,
  );
  assert.equal(
    verifyRobloxWebhookSignature(`t=${timestamp},v1=invalid`, secret, payload, {
      nowMs: timestamp * 1000,
    }),
    false,
  );
});

test('stableWebhookNotificationKey is deterministic and filesystem-safe', () => {
  const key = stableWebhookNotificationKey('abc/../notification');
  assert.match(key, /^[a-f0-9]{64}$/);
  assert.equal(key, stableWebhookNotificationKey('abc/../notification'));
});

test('readBody returns a bounded UTF-8 body', async () => {
  const request = new PassThrough();
  const bodyPromise = readBody(request, 64);
  request.end('{"ok":true}');

  assert.equal(await bodyPromise, '{"ok":true}');
});

test('readBody rejects bodies over the configured limit', async () => {
  const request = new PassThrough();
  const bodyPromise = readBody(request, 4);
  request.end('12345');

  await assert.rejects(bodyPromise, PayloadTooLargeError);
});
