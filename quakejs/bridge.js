// Carries game traffic between browsers and the game server. Browsers cannot
// send UDP, so the web client sends each Quake packet as one binary WebSocket
// message. This relays each message to the server as one UDP datagram, and
// each datagram back as one message. Every WebSocket gets its own UDP socket.
'use strict';

const crypto = require('crypto');
const dgram = require('dgram');
const { WebSocketServer } = require('ws');

const SERVER_PORT = 27960; // the game server, on UDP; this bridge listens on the same number on TCP

// Quake packets are at most 16 KiB, so nothing legitimate is near 64 KiB.
const bridge = new WebSocketServer({ host: '127.0.0.1', port: SERVER_PORT, maxPayload: 65536 });

bridge.on('connection', (ws, request) => {
	if (bridge.clients.size > 256) {
		ws.terminate();
		return;
	}
	// The game server rate-limits and bans by source address. Send from a
	// loopback address derived from the client's address (as nginx saw it), so
	// that one client cannot use up the allowance of the others.
	const [a, b, c] = crypto.createHash('sha256').update(String(request.headers['x-real-ip'])).digest();
	const udp = dgram.createSocket('udp4');
	udp.bind(0, `127.${a}.${b}.${1 + c % 254}`);
	udp.on('message', (packet, from) => {
		// Like UDP, drop packets for a player who is not keeping up instead of queueing them.
		if (from.port === SERVER_PORT && ws.bufferedAmount < 1 << 20) {
			ws.send(packet);
		}
	});
	udp.on('error', () => ws.terminate());
	ws.on('message', (packet) => udp.send(packet, SERVER_PORT, '127.0.0.1'));
	ws.on('error', () => ws.terminate());
	ws.on('close', () => udp.close());
});
