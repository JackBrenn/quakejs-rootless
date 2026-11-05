// Starts the engine and connects to the server that served this page.
// Query string parameters become console commands, e.g. ?name%20Player.
window.onload = function () {
	function resizeViewport() {
		// Ignore resizes before the canvas exists and while fullscreen.
		if (!ioq3.canvas || document.fullscreenElement || document.webkitFullscreenElement) {
			return;
		}
		ioq3.setCanvasSize(ioq3.viewport.offsetWidth, ioq3.viewport.offsetHeight);
	}

	ioq3.viewport = document.getElementById('viewport-frame');
	ioq3.elementPointerLock = true;
	ioq3.exitHandler = function (err) {
		if (err) {
			alert(err);
		}
		window.location.href = '/';
	};
	window.addEventListener('resize', resizeViewport);

	var url = new URL(window.location.href);
	var port = url.port || (url.protocol === 'https:' ? '443' : '80');
	var connectAddr = url.hostname + ':' + port;
	var args = ['+set', 'fs_cdn', connectAddr, '+connect', connectAddr];
	url.search.substring(1).split(/[&=]/).forEach(function (token) {
		if (!token) {
			return;
		}
		var words = decodeURIComponent(token).split(' ');
		words[0] = '+' + words[0];
		args.push.apply(args, words);
	});
	ioq3.callMain(args);
};

// Show the source URL on the demo EULA screen, the first screen a player sees,
// so anyone receiving the software can find its source (GPLv2 section 3).
new MutationObserver(function (mutations, observer) {
	var inner = document.getElementById('eula-frame-inner');
	if (!inner) {
		return;
	}
	observer.disconnect();
	var p = document.createElement('p');
	p.id = 'source-link';
	p.innerHTML = 'Server software: <a href="https://github.com/JackBrenn/quakejs-rootless" ' +
		'target="_blank" rel="noopener">github.com/JackBrenn/quakejs-rootless</a> &mdash; ' +
		'container packaging of QuakeJS by Anthony Pesch, engine derived from ioquake3, ' +
		'GPL-2.0-or-later. Game content is id Software and third-party data under their ' +
		'own terms, not GPL.';
	inner.appendChild(p);
}).observe(document.documentElement, { childList: true, subtree: true });
