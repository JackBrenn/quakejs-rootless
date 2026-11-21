// Carries game traffic between browsers and the game server. Browsers cannot
// send UDP, so the web client sends each Quake packet as one binary WebSocket
// message. This relays each message to the server as one UDP datagram, and
// each datagram back as one message. Every WebSocket gets its own UDP socket,
// so the server sees every player as a distinct 127.0.0.1:port.
'use strict';

const dgram = require('dgram');
const { WebSocketServer } = require('ws');

const SERVER_PORT = 27960; // the game server, on UDP; this bridge listens on the same number on TCP
const PORT_HELLO = Buffer.from('\xff\xff\xff\xffport', 'latin1');

// Quake packets are at most 16 KiB, so nothing legitimate is near 64 KiB.
const bridge = new WebSocketServer({ host: '127.0.0.1', port: SERVER_PORT, maxPayload: 65536 });

bridge.on('connection', (ws) => {
	if (bridge.clients.size > 256) {
		ws.terminate();
		return;
	}
	const udp = dgram.createSocket('udp4');
	udp.bind(0, '127.0.0.1');
	udp.on('message', (packet, from) => {
		// Like UDP, drop packets for a player who is not keeping up instead of queueing them.
		if (from.port === SERVER_PORT && ws.bufferedAmount < 1 << 20) {
			ws.send(packet);
		}
	});
	udp.on('error', () => ws.terminate());
	ws.on('message', (packet) => {
		// The web client's socket layer first announces its local port. Not a game packet.
		if (packet.length === 10 && packet.subarray(0, 8).equals(PORT_HELLO)) {
			return;
		}
		udp.send(packet, SERVER_PORT, '127.0.0.1');
	});
	ws.on('error', () => ws.terminate());
	ws.on('close', () => udp.close());
});
