

<div align="center">

### ⚠️ BROKEN

Container fails to start due to a hardcoded domain dependency in the precompiled ioquake3/quakejs fork. The domain is offline and baked into the binary, causing startup failure.

**Fix not feasible:** Recompiling is out of scope—this project only packages existing work as a rootless container.

**Alternative:** Check ✨ **[q3js.com](https://q3js.com/)** ✨ for updated implementations.



# QuakeJS Rootless Project

## Play multiplayer Quake III Arena in your browser with Podman / Docker

![Podman](https://img.shields.io/badge/Podman-892CA0?style=for-the-badge&logo=podman&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Debian](https://img.shields.io/badge/Debian-A81D33?style=for-the-badge&logo=debian&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js_22.x-339933?style=for-the-badge&logo=node.js&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-009639?style=for-the-badge&logo=nginx&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)

[![Docker Hub](https://img.shields.io/badge/Docker%20Hub-awakenedpower%2Fquakejs--rootless-blue?style=for-the-badge&logo=docker)](https://hub.docker.com/r/awakenedpower/quakejs-rootless)

A fully self-contained, Dockerized QuakeJS server running on Debian 13 and Node.js 22.x LTS

**🔒 This container runs as a non-root user for enhanced security**

</div>

## 🎮 About

This project provides a completely local QuakeJS server that runs entirely in Docker. No external dependencies, no content servers, no proxies - just pure Quake III Arena gaming in your browser.

**Key improvements in this fork:**
- ✨ Updated to **Debian 13 Slim** base image
- 🚀 Upgraded to **Node.js 22.x LTS** for better performance and security
- 🔒 Forked Quake3JS Core **to remove CRITICAL and HIGH NPM package vulnerabilities** ([quakejs](https://github.com/JackBrenn/quakejs))
- 🌐 **Production-ready Nginx-light web server** with security headers
- 🛡️ **Runs as non-root user (quakejs)** for enhanced container security
- 📦 Fully self-contained with all game assets bundled, no external content servers required

## 🎮 Live Demo

**Experience QuakeJS** in action at [oldschoolfrag.com](https://oldschoolfrag.com)

## 🚀 Quick Start

### Using Podman (Recommended)

```bash
podman run -d \
  --name quakejs \
  -e HTTP_PORT=8080 \
  -p 8080:8080 \
  -p 27960:27960 \
  docker.io/awakenedpower/quakejs-rootless:latest
```

### Using Docker Run

```bash
docker run -d \
  --name quakejs \
  -e HTTP_PORT=8080 \
  -p 8080:8080 \
  -p 27960:27960 \
  docker.io/awakenedpower/quakejs-rootless:latest
```

Then open your browser and navigate to `http://localhost:8080` to start playing!

### Using Docker Compose

Create a `docker-compose.yml` file:

```yaml
version: '3.8'
services:
  quakejs:
    container_name: quakejs
    image: awakenedpower/quakejs-rootless:latest
    environment:
      - HTTP_PORT=8080
    ports:
      - '8080:8080'
      - '27960:27960'
    restart: unless-stopped
```

Then run:

```bash
docker-compose up -d
```

## 🛠️ Building from Source

### Building with Podman (Recommended)

1. **Clone the repository:**
```bash
git clone https://github.com/JackBrenn/quakejs-rootless.git
cd quakejs-rootless
```

2. **Build the image:**
```bash
podman build -t quakejs-rootless:latest .
```

3. **Run the container:**
```bash
podman run -d \
  --name quakejs \
  -e HTTP_PORT=8080 \
  -p 8080:8080 \
  -p 27960:27960 \
  quakejs-rootless:latest
```

### Building with Docker

1. **Clone the repository:**
```bash
git clone https://github.com/JackBrenn/quakejs-rootless.git
cd quakejs-rootless
```
2. **Build the image:**
```bash
docker build -t quakejs-rootless:latest .
```

3. **Run the container:**
```bash
docker run -d \
  --name quakejs \
  -e HTTP_PORT=8080 \
  -p 8080:8080 \
  -p 27960:27960 \
  quakejs-rootless:latest
```

## ⚙️ Configuration

### Environment Variables

- `HTTP_PORT` - The HTTP port to serve the web interface (default: 8080)

### Server Configuration

The server configuration can be customized by modifying `server.cfg`.

### Ports

- **8080** (or your custom HTTP_PORT) - Web interface (Nginx)
- **27960** - Game server (WebSocket)

## 📝 What's Different?

This fork builds upon the excellent work of [@treyyoder/quakejs-docker](https://github.com/treyyoder/quakejs-docker) with the following updates:

| Component | Original | This Fork |
|-----------|----------|-----------|
| Base OS | Ubuntu 20.04 | **Debian 13 Slim** |
| Node.js | 14.x | **22.x LTS** |
| Web Server | Apache 2 | **Nginx Light** |
| Container User | root | **non-root (quakejs)** |
| Maintenance | Updated 2020 | **Updated 2025** |

These updates provide:
- Extended security support from Debian 13 Slim
- Updated to the latest version of Node.js
- Updated all npm packages removing critical vulnerabilities
- Reduced attack surface with NGINX Light
- Enhanced security through non-root container execution

## 🙏 Credits & Acknowledgments

This wouldn't be possible without these projects:

- **[@treyyoder](https://github.com/treyyoder)** - Original [quakejs-docker](https://github.com/treyyoder/quakejs-docker) implementation that made fully local QuakeJS servers possible
- **[@nerosketch](https://github.com/nerosketch)** - [QuakeJS fork](https://github.com/nerosketch/quakejs.git) with local server capabilities
- **[@inolen](https://github.com/inolen)** - Original [QuakeJS](https://github.com/inolen/quakejs) project

## 📜 License

MIT

## 🎯 Questions

- If you have questions, just open a GitHub issue and maybe I can help!

---

<div align="center">

**Ready to frag?** Share the server URL with your friends and enjoy some classic Quake III Arena! 🚀

*For best security: Rootless container + Podman + Nginx + firewall + regular updates*

</div>
