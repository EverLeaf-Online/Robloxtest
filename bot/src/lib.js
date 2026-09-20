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

export function parseRobloxSignatureHeader(value) {
  if (typeof value !== 'string') return null;

  let timestamp = null;
  let signature = null;

  for (const part of value.split(',')) {
    const trimmed = part.trim();
    if (trimmed.startsWith('t=')) {
      if (timestamp !== null) return null;
      timestamp = trimmed.slice(2);
    } else if (trimmed.startsWith('v1=')) {
      if (signature !== null) return null;
      signature = trimmed.slice(3);
    }
  }

  if (!timestamp || !signature || !/^\d+$/.test(timestamp)) return null;
  if (signature.length > 256) return null;

  return { timestamp, signature };
}

export function verifyRobloxWebhookSignature(
  signatureHeader,
  secret,
  payload,
  { nowMs = Date.now(), maxSkewSeconds = 300 } = {},
) {
  if (typeof secret !== 'string' || secret.length < 16) return false;
  if (payload === null || typeof payload !== 'object' || Array.isArray(payload)) return false;
  if (!Number.isFinite(nowMs) || !Number.isFinite(maxSkewSeconds) || maxSkewSeconds <= 0) {
    return false;
  }

  const parsed = parseRobloxSignatureHeader(signatureHeader);
  if (!parsed) return false;

  const timestampSeconds = Number(parsed.timestamp);
  if (!Number.isSafeInteger(timestampSeconds)) return false;

  const nowSeconds = Math.floor(nowMs / 1000);
  if (Math.abs(nowSeconds - timestampSeconds) > maxSkewSeconds) return false;

  const message = `${parsed.timestamp}.${JSON.stringify(payload)}`;
  const expected = crypto.createHmac('sha256', secret).update(message).digest('base64');
  return safeSecretEqual(parsed.signature, expected);
}

export function stableWebhookNotificationKey(notificationId) {
  if (typeof notificationId !== 'string' || notificationId.length === 0) {
    throw new Error('NotificationId must be a non-empty string');
  }
  return crypto.createHash('sha256').update(notificationId, 'utf8').digest('hex');
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
