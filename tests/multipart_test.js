'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const P = require('../bridge/protocol');

function frames(text, session = 'session1', id = 8) {
  const record = [session, 'chat1', id, 'C:/work', 'c;agent=codex', 'Items', 'character context', text].join('\x1F');
  const bytes = Buffer.from(record);
  const count = Math.ceil(bytes.length / 1100);
  return Array.from({ length: count }, (_, i) => ['F1', session, id, i + 1, count, bytes.subarray(i * 1100, (i + 1) * 1100).toString('hex')].join('\x1F'));
}

test('reassembles 48 KB of UTF-8, reordered and repeated, as one complete job', () => {
  const text = 'ação 🧙 '.repeat(3000);
  const parts = frames(text);
  const assemble = P.createStripAssembler();
  for (const part of parts.slice(1).reverse()) {
    assert.equal(assemble(part), null);
    assert.equal(assemble(part), null);
    assert.ok(Buffer.byteLength(part) <= 2392);
  }
  const payload = assemble(parts[0]);
  const jobs = P.jobsFromStrip(8, payload);
  assert.equal(jobs.length, 1);
  assert.equal(jobs[0].text, text);
  assert.equal(jobs[0].ctx, 'character context');
  assert.equal(jobs[0].agent, 'codex');
});

test('independent sessions, expired fragments and unchanged legacy messages', () => {
  const a = frames('a'.repeat(7000));
  const b = frames('b'.repeat(7000), 'other');
  const assemble = P.createStripAssembler();
  assert.equal(assemble('legacy'), 'legacy');
  assert.equal(assemble(a[0], 0), null);
  for (const part of a.slice(1)) assert.equal(assemble(part, 120001), null);
  for (const part of b.slice(1)) assert.equal(assemble(part, 120001), null);
  assert.equal(P.jobsFromStrip(8, assemble(b[0], 120001))[0].text, 'b'.repeat(7000));
  assert.equal(P.jobsFromStrip(8, assemble(a[0], 120001))[0].text, 'a'.repeat(7000));
});

test('rejects malformed fragments and envelopes with mismatched identity', () => {
  const assemble = P.createStripAssembler();
  for (const value of ['F1\x1Fs\x1F1\x1F0\x1F2\x1Faa', 'F1\x1Fs\x1F1\x1F1\x1F10000\x1Faa', 'F1\x1Fs\x1F1\x1F1\x1F2\x1Fxyz']) assert.equal(assemble(value), null);
  const parts = frames('x'.repeat(7000)).map(s => s.replace('F1\x1Fsession1', 'F1\x1Fforged'));
  for (const part of parts) assert.equal(assemble(part), null);
});
