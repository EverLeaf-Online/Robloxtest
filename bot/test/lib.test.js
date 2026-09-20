import assert from 'node:assert/strict';
import { PassThrough } from 'node:stream';
import test from 'node:test';

import {
  PayloadTooLargeError,
  boundedText,
  parsePort,
  readBody,
  safeSecretEqual,
  validateHttpsUrl,
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
