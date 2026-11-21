// Shows the demo licence, downloads the game data, then starts the engine and
// connects to the game server behind the address that served this page.
// Query string parameters become console commands, e.g. ?name%20Player.
import ioquake3 from './ioquake3.js';

// id's installers are served intact. Each is a shell script followed by a
// gzipped tar archive; these are the paks the game needs out of them.
const INSTALLERS = [
	{ name: 'linuxq3ademo-1.11-6.x86.gz.sh', scriptLines: 164, paks: /^demoq3\/pak0\.pk3$/ },
	{ name: 'linuxq3apoint-1.32b-3.x86.run', scriptLines: 355, paks: /^baseq3\/pak\d\.pk3$/ },
];
const SOCKET_URL = location.origin.replace(/^http/, 'ws') + '/';

const play = document.getElementById('play');
const status = document.getElementById('status');

// Asks the game server which map it is running.
function serverInfo() {
	return new Promise((resolve, reject) => {
		const socket = new WebSocket(SOCKET_URL);
		const fail = () => reject(new Error('The game server is not answering. Reload the page to try again.'));
		socket.binaryType = 'arraybuffer';
		socket.onopen = () => socket.send(Uint8Array.from('\xff\xff\xff\xffgetinfo', (c) => c.charCodeAt(0)));
		socket.onmessage = (event) => {
			const fields = new TextDecoder('latin1').decode(event.data).split('\\');
			const info = {};
			for (let i = 1; i + 1 < fields.length; i += 2) {
				info[fields[i]] = fields[i + 1];
			}
			socket.onclose = null;
			socket.close();
			resolve(info);
		};
		socket.onclose = fail;
		setTimeout(fail, 5000);
	});
}

// Lists the files in a directory under assets/ (nginx's JSON directory index).
async function list(dir) {
	const response = await fetch('assets/' + dir);
	if (!response.ok) {
		throw new Error(`Could not list assets/${dir} (HTTP ${response.status}).`);
	}
	return (await response.json())
		.filter((entry) => entry.type === 'file')
		.map((entry) => ({ path: dir + entry.name, size: entry.size }));
}

// Downloads files into memory, reporting progress across all of them.
async function download(files) {
	const total = files.reduce((sum, file) => sum + file.size, 0);
	let received = 0;
	return Promise.all(files.map(async (file) => {
		const response = await fetch('assets/' + file.path);
		if (!response.ok) {
			throw new Error(`Could not download ${file.path} (HTTP ${response.status}).`);
		}
		const data = new Uint8Array(file.size);
		const reader = response.body.getReader();
		for (let at = 0; ;) {
			const { done, value } = await reader.read();
			if (done) {
				return data;
			}
			data.set(value, at);
			at += value.length;
			received += value.length;
			status.textContent = `Downloading game data: ${Math.round(received / 2 ** 20)} of ${Math.round(total / 2 ** 20)} MB`;
		}
	}));
}

// Calls write(path, bytes) for the wanted paks inside an installer.
async function unpack(installer, bytes, write) {
	let start = 0;
	for (let line = 0; line < installer.scriptLines; line++) {
		start = bytes.indexOf(10, start) + 1;
	}
	const archive = new Blob([bytes.subarray(start)]).stream().pipeThrough(new DecompressionStream('gzip'));
	const tar = new Uint8Array(await new Response(archive).arrayBuffer());
	const text = new TextDecoder();
	// A tar archive is a sequence of 512-byte headers, each followed by its file padded to 512 bytes.
	for (let at = 0; at + 512 <= tar.length;) {
		const name = text.decode(tar.subarray(at, at + 100)).replace(/\0.*/, '');
		const size = parseInt(text.decode(tar.subarray(at + 124, at + 135)), 8) || 0;
		if (installer.paks.test(name)) {
			write(name, tar.subarray(at + 512, at + 512 + size));
		}
		at += 512 + Math.ceil(size / 512) * 512;
	}
}

async function start() {
	play.disabled = true;
	status.textContent = 'Contacting the game server…';
	const info = await serverInfo();

	// Paks named pakN hold the game itself and are needed up front. The others
	// each hold one map: fetch the one being played now, and let the engine
	// download any other from the game server if the map changes to it.
	const listed = (await Promise.all(['', 'demoq3/', 'baseq3/'].map(list))).flat();
	const installers = INSTALLERS.map((installer) => listed.find((file) => file.path === installer.name));
	const paks = listed.filter((file) => /\/(pak\d+|vm)\.pk3$/.test(file.path) || file.path.endsWith(`/${info.mapname}.pk3`));
	const data = await download([...installers, ...paks]);

	status.textContent = 'Unpacking…';
	const files = paks.map((pak, i) => ({ path: pak.path, bytes: data[INSTALLERS.length + i] }));
	for (const [i, installer] of INSTALLERS.entries()) {
		await unpack(installer, data[i], (path, bytes) => files.push({ path, bytes }));
	}

	const commands = [];
	for (const token of location.search.slice(1).split(/[&=]/).filter(Boolean)) {
		const words = decodeURIComponent(token).split(' ');
		commands.push('+' + words[0], ...words.slice(1));
	}
	const scale = window.devicePixelRatio || 1;
	document.body.className = 'playing';
	await ioquake3({
		canvas: document.getElementById('canvas'),
		arguments: [
			// The demo's pak0 is only accepted from a demoq3 directory.
			'+set', 'fs_basegame', 'demoq3',
			// IPv4 only: the engine's UDP socket is carried over the WebSocket below.
			'+set', 'net_enabled', '1', '+set', 'cl_allowDownload', '1',
			'+set', 'r_fullscreen', '0', '+set', 'r_allowResize', '1', '+set', 'r_mode', '-1',
			'+set', 'r_customwidth', Math.round(window.innerWidth * scale),
			'+set', 'r_customheight', Math.round(window.innerHeight * scale),
			// Per-pixel lighting renders surfaces white on WebGL, and Quake 3's own art has no use for it.
			'+set', 'r_normalMapping', '0', '+set', 'r_specularMapping', '0',
			...commands,
			'+connect', location.host,
		].map(String),
		// Every address the engine sends to is this one WebSocket endpoint.
		websocket: { url: SOCKET_URL },
		preRun: [(module) => {
			for (const file of files) {
				module.FS.mkdirTree('/' + file.path.replace(/\/[^/]*$/, ''));
				module.FS.writeFile('/' + file.path, file.bytes);
			}
		}],
		// "quit" in the game returns to this page's first screen.
		// The engine reports through stderr; none of it is an error to the browser.
		printErr: (line) => console.log(line),
		onExit: (code) => (code ? stopped() : location.reload()),
		onAbort: stopped,
	});
}

function stopped() {
	document.body.className = '';
	status.textContent = 'The game stopped after an error; the browser console has the details. Reload the page to play again.';
}

play.onclick = () => start().catch((error) => {
	document.body.className = '';
	status.textContent = error.message;
	console.error(error);
});

fetch('eula.txt').then((response) => response.text()).then((text) => {
	document.getElementById('eula').textContent = text;
	play.disabled = false;
});
