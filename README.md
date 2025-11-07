<div align="center">

# QuakeJS Docker

### Play Quake III Arena in your browser with Docker

![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Podman](https://img.shields.io/badge/Podman-892CA0?style=for-the-badge&logo=podman&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu_24.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js_22.x-339933?style=for-the-badge&logo=node.js&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)

A fully self-contained, Dockerized QuakeJS server running on Ubuntu 24.04 and Node.js 22.x LTS

</div>

## 🎮 About

This project provides a completely local QuakeJS server that runs entirely in Docker. No external dependencies, no content servers, no proxies - just pure Quake III Arena gaming in your browser.

**Key improvements in this fork:**
- ✨ Updated to **Ubuntu 24.04** base image
- 🚀 Upgraded to **Node.js 22.x LTS** for better performance and security
- 📦 Fully self-contained with all game assets bundled
- 🔒 No external content servers required

## ⚠️ Security Notice

**This project contains known security vulnerabilities from multiple sources:**

1. **Legacy Quake III Arena game code** - The original game engine was not designed with modern security practices and contains known exploits
2. **Deprecated NPM packages** - The QuakeJS implementation relies on old, unmaintained Node.js dependencies with known vulnerabilities

**It is strongly recommended to run this container using Podman as a non-root user** rather than Docker with sudo privileges. This provides better isolation and security through rootless containers.

**Important:** Only run this server on trusted, isolated networks (such as a private LAN or VPN). Do **NOT** expose this directly to the public internet (BUT, you can if you want!).

## 🚀 Quick Start

### Using Podman (Recommended)

```bash
podman run -d \
  --name quakejs \
  -e HTTP_PORT=8080 \
  -p 8080:80 \
  -p 27960:27960 \
  jackbrenn/quakejs:latest
```

### Using Docker Run

```bash
docker run -d \
  --name quakejs \
  -e HTTP_PORT=8080 \
  -p 8080:80 \
  -p 27960:27960 \
  jackbrenn/quakejs:latest
```

Then open your browser and navigate to `http://localhost:8080` to start playing!

### Using Docker Compose

Create a `docker-compose.yml` file:

```yaml
version: '3.8'
services:
  quakejs:
    container_name: quakejs
    image: jackbrenn/quakejs:latest
    environment:
      - HTTP_PORT=8080
    ports:
      - '8080:80'
      - '27960:27960'
    restart: unless-stopped
```

Then run:

```bash
docker-compose up -d
```

## 🛠️ Building from Source

### Building with Podman (Recommended for Security)

1. **Clone the repository:**
```bash
git clone https://github.com/JackBrenn/quakejs-docker.git
cd quakejs-docker
```

2. **Ensure line endings are correct** (convert CRLF to LF if needed):
   - `Dockerfile`
   - `entrypoint.sh`

3. **Build the image:**
```bash
podman build --add-host=content.quakejs.com:127.0.0.1 -t quakejs:latest .
```

4. **Run the container:**
```bash
podman run -d \
  --name quakejs \
  -e HTTP_PORT=8080 \
  -p 8080:80 \
  -p 27960:27960 \
  localhost/quakejs:latest
```

### Building with Docker

1. **Clone the repository:**
```bash
git clone https://github.com/JackBrenn/quakejs-docker.git
cd quakejs-docker
```

2. **Ensure line endings are correct** (convert CRLF to LF if needed):
   - `Dockerfile`
   - `entrypoint.sh`

3. **Build the image:**
```bash
docker build --add-host=content.quakejs.com:127.0.0.1 -t jackbrenn/quakejs:latest .
```

## ⚙️ Configuration

### Environment Variables

- `HTTP_PORT` - The HTTP port to serve the web interface (default: 80)

### Server Configuration

The server configuration can be customized by modifying `server.cfg`. Refer to the [Quake 3 World Server Guide](https://www.quake3world.com/q3guide/servers.html) for detailed configuration options.

### Ports

- **80** (or your custom HTTP_PORT) - Web interface
- **27960** - Game server (WebSocket)

## 🔐 Security Best Practices

Due to vulnerabilities in both the legacy Quake III game code and deprecated NPM packages, follow these security practices:

1. **Use Podman with a non-root user** - Provides rootless container execution for better isolation
2. **Run on isolated networks only** - Use dedicated VLANs, private LANs, or VPN connections
3. **Never expose to public internet** - This container should only be accessible on trusted networks
4. **Keep the container updated** - Regularly rebuild with the latest base image security patches
5. **Use firewall rules** - Restrict access to game ports to known IP addresses only
6. **Monitor container activity** - Watch for unusual behavior or unauthorized access attempts

While upgrading to Ubuntu 24.04 and Node.js 22.x LTS provides the latest security patches for the underlying system and runtime, the game code and its NPM dependencies remain vulnerable. Containerization and rootless execution provide defense-in-depth but do not eliminate the risks entirely.

## 📝 What's Different?

This fork builds upon the excellent work of [@treyyoder/quakejs-docker](https://github.com/treyyoder/quakejs-docker) with the following updates:

| Component | Original | This Fork |
|-----------|----------|-----------|
| Base OS | Ubuntu 20.04 | **Ubuntu 24.04** |
| Node.js | 14.x | **22.x LTS** |
| Maintenance | Updated 2020 | **Updated 2025** |

These updates provide:
- Extended security support from Ubuntu 24.04 LTS
- Improved Node.js performance and features
- Better long-term compatibility
- Modern package versions with security patches
- Reduced attack surface (though vulnerabilities remain in game code and NPM packages)

## 🙏 Credits & Acknowledgments

This project is built on the shoulders of giants:

- **[@treyyoder](https://github.com/treyyoder)** - Original [quakejs-docker](https://github.com/treyyoder/quakejs-docker) implementation that made fully local QuakeJS servers possible
- **[@begleysm](https://github.com/begleysm)** - [QuakeJS fork](https://github.com/begleysm/quakejs) with local server capabilities
- **[@inolen](https://github.com/inolen)** - Original [QuakeJS](https://github.com/inolen/quakejs) project

## 📜 License

MIT

## 🎯 Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

---

<div align="center">

**Ready to frag?** Share the server URL with your friends and enjoy some classic Quake III Arena! 🚀

*Remember: For maximum security, run with Podman as a non-root user on isolated networks only!*

</div>
