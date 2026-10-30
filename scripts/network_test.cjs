const { readFileSync } = require('node:fs');
const { runInNewContext } = require('node:vm');
const { EventEmitter } = require('node:events');
const assert = require('node:assert/strict');
const peers = new Map();
let nextId = 0;
class Connection extends EventEmitter {
  open = false;
  dataChannel = { bufferedAmount: 0 };
  send(data) { this.other.emit('data', data); }
  close() {
    this.open = false;
    this.other.open = false;
    this.emit('close');
    this.other.emit('close');
  }
}
class Peer extends EventEmitter {
  constructor(id = `guest-${++nextId}`) {
    super(); this.id = id; peers.set(id, this);
    setImmediate(() => this.emit('open', id));
  }
  connect(id) {
    const local = new Connection(), remote = new Connection();
    local.other = remote; remote.other = local;
    setImmediate(() => {
      const host = peers.get(id);
      if (!host) return this.emit('error', { type: 'peer-unavailable' });
      host.emit('connection', remote);
      setImmediate(() => {
        local.open = remote.open = true;
        local.emit('open'); remote.emit('open');
      });
    });
    return local;
  }
  destroy() { peers.delete(this.id); }
}
function client() {
  const window = { Peer };
  runInNewContext(readFileSync('web/multiplayer.js', 'utf8'), {
    window, Peer, crypto: globalThis.crypto, setTimeout, clearTimeout,
  });
  return window.pongNet;
}
const settle = () => new Promise(resolve => setTimeout(resolve, 20));
(async () => {
  const host = client(), guest = client();
  await host.start('host'); await settle();
  assert.match(host.room, /^[A-Z2-9]{8}$/);
  await guest.start('guest', host.room.toLowerCase()); await settle();
  assert.ok(host.connected && guest.connected);
  guest.send({ input: 50 }); assert.equal(host.input, 1);
  guest.send({ input: NaN }); assert.equal(host.input, 1);
  const state = [340, 350, 480, 340, 0, 1, 1, 0, 0, 0];
  host.send({ state }); assert.deepEqual(guest.state, state);
  host.send({ state: [1] }); assert.deepEqual(guest.state, state);
  guest.leave(); assert.equal(host.connected, false); assert.equal(host.input, 0);
  host.leave();
  await guest.start('guest', 'BAD'); assert.match(guest.status, /8-character/);
  guest.leave();
  console.log('PASS: room creation/join, input validation, snapshots, disconnect and cleanup');
})().catch(error => { console.error(error); process.exitCode = 1; });
