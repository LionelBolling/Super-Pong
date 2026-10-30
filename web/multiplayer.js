(() => {
  let peer, connection, timer, generation = 0;
  const net = window.pongNet = { role: '', status: '', room: '', connected: false, input: 0, state: null };
  let library;
  function loadLibrary() {
    if (window.Peer) return Promise.resolve();
    return library ||= new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = 'https://cdn.jsdelivr.net/npm/peerjs@1.5.5/dist/peerjs.min.js';
      script.onload = resolve;
      script.onerror = () => { library = null; script.remove(); reject(new Error('Could not load multiplayer. Check your internet connection.')); };
      document.head.appendChild(script);
    });
  }
  net.leave = () => {
    generation++;
    clearTimeout(timer);
    if (connection) connection.close();
    if (peer) peer.destroy();
    connection = peer = null;
    Object.assign(net, { role: '', status: '', room: '', connected: false, input: 0, state: null });
  };
  net.start = async (role, room = '') => {
    net.leave();
    const run = generation;
    net.role = role;
    net.status = 'Connecting...';
    try { await loadLibrary(); } catch (e) { if (run === generation) net.status = e.message; return; }
    if (run !== generation) return;
    room = role === 'host' ? Array.from(crypto.getRandomValues(new Uint8Array(8)), n => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'[n % 32]).join('') : room.toUpperCase().trim();
    if (!/^[A-Z2-9]{8}$/.test(room)) { net.status = 'Enter the 8-character room code.'; return; }
    net.room = room;
    const prefix = 'super-pong-lb-v1-';
    peer = role === 'host' ? new Peer(prefix + room) : new Peer();
    const fail = message => {
      if (run !== generation) return;
      clearTimeout(timer);
      net.connected = false;
      net.input = 0;
      net.status = message;
    };
    function attach(conn) {
      if (connection) { conn.close(); return; }
      connection = conn;
      timer = setTimeout(() => { fail('Connection timed out. Try another network or create a new room.'); conn.close(); }, 20000);
      conn.on('open', () => {
        if (run !== generation) return conn.close();
        clearTimeout(timer);
        net.connected = true;
        net.status = 'Connected';
      });
      conn.on('data', data => {
        if (run !== generation || !net.connected || !data || typeof data !== 'object') return;
        if (role === 'host' && Number.isFinite(data.input)) net.input = Math.max(-1, Math.min(1, data.input));
        if (role === 'guest' && Array.isArray(data.state) && data.state.length === 10 && data.state.every(Number.isFinite)) net.state = data.state;
      });
      conn.on('close', () => fail('Opponent disconnected. Leave and create or join a new room.'));
      conn.on('error', () => fail('Connection failed. Leave and try again.'));
    }
    peer.on('open', () => {
      if (run !== generation) return;
      net.status = role === 'host' ? 'Share your room code. Waiting for player 2...' : 'Joining room...';
      if (role === 'guest') attach(peer.connect(prefix + room, { reliable: false, serialization: 'json' }));
    });
    peer.on('connection', conn => { if (run !== generation || role !== 'host') conn.close(); else attach(conn); });
    peer.on('error', error => fail(error.type === 'peer-unavailable' ? 'Room not found. Check the code and ask the host to keep the tab open.' : 'Multiplayer service unavailable. Leave and try again.'));
    peer.on('disconnected', () => { if (!net.connected) fail('Signaling disconnected. Leave and try again.'); });
  };
  net.send = data => { if (net.connected && connection?.open && connection.dataChannel?.bufferedAmount < 65536) connection.send(data); };
  net.poll = () => JSON.stringify({ role: net.role, status: net.status, room: net.room, connected: net.connected, input: net.input, state: net.state });
})();
