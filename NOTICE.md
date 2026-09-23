# Provenance and licence scope

[`LICENSE`](LICENSE) is MIT and covers everything in this repository: the packaging of every
add-on, the workflows, the documentation and the artwork are original work.

The add-ons do not stop there, though. Each one installs an application it did not write,
and those applications come with their own licences and their own authors. This file says
who they are, because an image that ships someone else's software has to carry their notice
with it.

## What the add-ons run at runtime

No add-on here vendors the application it runs; each fetches it at build time. Four of them fetch
it from a repository of ours; `sbfspot-mqtt` fetches SBFspot from its own project, because that is
not code to fork — which also means it is the one add-on whose packaging has no application
repository behind it, and carries its own tests for that reason.

| Add-on | Application | Licence |
|---|---|---|
| `ialarm-mqtt/` | [Stinocon/ialarm-mqtt](https://github.com/Stinocon/ialarm-mqtt), a fork of [maxill1/ialarm-mqtt](https://github.com/maxill1/ialarm-mqtt) | MIT, © 2019 Luca Mazzilli — the notice travels with every image that installs it |
| `reel2recipe/` | [Stinocon/Reel2Recipe](https://github.com/Stinocon/Reel2Recipe) | MIT — dependency attributions in its [`NOTICE.md`](https://github.com/Stinocon/Reel2Recipe/blob/main/NOTICE.md) |
| `rethink-dishwasher/` | [Stinocon/rethink-dishwasher](https://github.com/Stinocon/rethink-dishwasher), a fork of [anszom/rethink](https://github.com/anszom/rethink) | GPL-2.0 — the notice travels with every image that installs it |
| `ezviz-stream-bridge/` | [RenierM26/pyEzvizApi](https://github.com/RenierM26/pyEzvizApi) (the EZVIZ cloud API and stream protocol) | Apache-2.0, © Renier Moorcroft |
| `sbfspot-mqtt/` | [SBFspot/SBFspot](https://github.com/SBFspot/SBFspot) (compiled from source at image build time, pinned to a tag) | CC BY-NC-SA 3.0, © 2012-2025 SBF — the notice travels with every image that installs it |

SBFspot's licence is worth a second look before reusing this add-on for anything commercial: it is
Creative Commons, not an open source licence, and the **NonCommercial** clause forbids commercial
use of the software, the image that contains it and anything built on it. The ShareAlike clause
applies to modified versions — this repository does not modify SBFspot, it compiles the upstream
source unchanged and points at it.

## Artwork

`docs/brand/banner.svg` is drawn from scratch — plain SVG geometry, system font stacks, no
embedded icon set. Unlike the Reel2Recipe banner, which traces a Material Symbols glyph and
attributes it, there is nothing here to attribute. The add-on icons and logos are original: the
iAlarm pair is a shield with a keyhole and a drawn wordmark, and the SBFspot pair is a panel grid
under a sun, neither traced from anything.

The container images also bundle third-party software installed from their own distribution
channels — the Home Assistant base images, Node.js and npm packages for `ialarm-mqtt`,
[Ollama](https://github.com/ollama/ollama), faster-whisper and yt-dlp for `reel2recipe` —
each under its own licence. Nothing here modifies or relicenses any of it.
