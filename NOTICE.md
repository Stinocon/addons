# Provenance and licence scope

[`LICENSE`](LICENSE) is MIT and covers everything in this repository: the packaging of both
add-ons, the workflows, the documentation and the artwork are original work.

The add-ons do not stop there, though. Each one installs an application it did not write,
and those applications come with their own licences and their own authors. This file says
who they are, because an image that ships someone else's software has to carry their notice
with it.

## What the add-ons run at runtime

No add-on here vendors the application it runs; each fetches it at build time.

| Add-on | Application | Licence |
|---|---|---|
| `ialarm-mqtt/` | [Stinocon/ialarm-mqtt](https://github.com/Stinocon/ialarm-mqtt), a fork of [maxill1/ialarm-mqtt](https://github.com/maxill1/ialarm-mqtt) | MIT, © 2019 Luca Mazzilli — the notice travels with every image that installs it |
| `reel2recipe/` | [Stinocon/Reel2Recipe](https://github.com/Stinocon/Reel2Recipe) | MIT — dependency attributions in its [`NOTICE.md`](https://github.com/Stinocon/Reel2Recipe/blob/main/NOTICE.md) |

## Artwork

`docs/brand/banner.svg` is drawn from scratch — plain SVG geometry, system font stacks, no
embedded icon set. Unlike the Reel2Recipe banner, which traces a Material Symbols glyph and
attributes it, there is nothing here to attribute. The add-on icons and logos are original
in both directories: the iAlarm pair is a shield with a keyhole and a drawn wordmark, neither
traced from anything.

The container images also bundle third-party software installed from their own distribution
channels — the Home Assistant base images, Node.js and npm packages for `ialarm-mqtt`,
[Ollama](https://github.com/ollama/ollama), faster-whisper and yt-dlp for `reel2recipe` —
each under its own licence. Nothing here modifies or relicenses any of it.
