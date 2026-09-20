import crypto from 'node:crypto';

export class PayloadTooLargeError extends Error {
  constructor() {
    super('Webhook body too large');
    this.name = 'PayloadTooLargeError';
  }
}

export function safeSecretEqual(actual, expected) {
  if (typeof actual !== 'string' || typeof expected !== 'string') return false;

  const actualBytes = Buffer.from(actual, 'utf8');
  const expectedBytes = Buffer.from(expected, 'utf8');
  if (actualBytes.length !== expectedBytes.length) return false;

  return crypto.timingSafeEqual(actualBytes, expectedBytes);
}

export function boundedText(value, fallback, maxLength) {
  const text = String(value ?? fallback).replaceAll('\u0000', '').trim();
  const resolved = text.length > 0 ? text : fallback;
  return resolved.slice(0, maxLength);
}

export function parsePort(value, fallback) {
  const parsed = Number(value ?? fallback);
  if (!Number.isInteger(parsed) || parsed < 1 || parsed > 65535) {
    throw new Error(`Invalid WEBHOOK_PORT: ${String(value)}`);
  }
  return parsed;
}

export function validateHttpsUrl(value) {
  const parsed = new URL(value);
  if (parsed.protocol !== 'https:') {
    throw new Error('ROBLOX_GAME_URL must use https');
  }
  return parsed.toString();
}

export function readBody(request, maxBytes = 64 * 1024) {
  return new Promise((resolve, reject) => {
    let settled = false;
    let size = 0;
    const chunks = [];

    const fail = (error) => {
      if (settled) return;
      settled = true;
      reject(error);
    };

    request.on('data', (chunk) => {
      if (settled) return;

      const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
      size += buffer.length;
      if (size > maxBytes) {
        chunks.length = 0;
        request.pause();
        fail(new PayloadTooLargeError());
        return;
      }
      chunks.push(buffer);
    });

    request.on('end', () => {
      if (settled) return;
      settled = true;
      resolve(Buffer.concat(chunks).toString('utf8'));
    });

    request.on('error', fail);
    request.on('aborted', () => fail(new Error('Webhook request aborted')));
  });
}
