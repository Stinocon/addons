<p align="center">
  <strong>English</strong> · <a href="README.it.md">Italiano</a>
</p>

# Reel2Recipe — Home Assistant add-on

Extracts recipes from cooking reels and makes them usable: it structures them, normalises the
amounts, files them in a searchable library and exports them in **Mela** format.

The problem it solves is not "extracting a recipe" but **finding it again**: people save
recipes on Instagram and then never find them.

Source code and full documentation:
**[Stinocon/Reel2Recipe](https://github.com/Stinocon/Reel2Recipe)**.

## Languages

**Italian and English, on both sides of the tool.** The interface switch is in the header;
the choice is remembered, and on first open it follows your browser's language. From it
descend the other two axes — the recipe's language and the measurement system — which follow
it by default and stay overridable under *Options*.

The language *spoken* in the reel is a separate matter and is not inferred from those:
Whisper detects it, so an English reel can become an Italian recipe, or stay English.

One honest limitation before you rely on it: translating **ingredient names** is the least
reliable part of the chain — see [what it does not do](#what-it-does-not-do-worth-knowing-first).
The amounts stay right; the words are what slip.

## What runs inside the add-on

Everything. Transcription uses **Whisper** locally, structuring a **local LLM via Ollama**,
both inside this container. No API key, no subscription, no data leaving the machine — and
that is a design constraint, not a property of this release: the product has to keep working
even if you stop paying for everything.

The corollary is that your server's CPU does the heavy lifting.

## Requirements

| | |
|---|---|
| Architecture | **amd64 only** — a miniPC or a NUC, not a Raspberry Pi |
| RAM | **16 GB** recommended: the default model takes about 9 when loaded |
| Disk | **~15 GB**: 1.5 GB of image, ~9 GB for the LLM, ~1.5 GB for Whisper |
| Time | A few minutes per recipe on CPU. It is a job you start and let run |

On a more modest machine you can set `modello_llm` to `qwen2.5:7b-instruct`: it halves memory
and time, but **loses ingredient groups** ("for the sauce", "for the base") and tends to fill
in missing amounts instead of declaring them. That is why the larger model is the default.

## Installation

1. In Home Assistant: **Settings → Add-ons → Add-on Store**, top-right menu,
   **Repositories**, then add:

   ```
   https://github.com/Stinocon/addons
   ```

2. Install **Reel2Recipe** and start it.
3. **The first start downloads about 10 GB**: the language model and the transcription one.
   The interface is already reachable meanwhile and shows "LLM not ready" until it has
   finished; the add-on log reports progress every minute. They are downloaded once and stay
   on `/data`, so add-on updates do not pay for them again.
4. Open the panel from the sidebar.

## Options

| option | default | what it does |
|---------|-------------|---------|
| `modello_llm` | `qwen2.5:14b` | The Ollama model that structures the recipe. Downloaded on first start if missing |
| `scarica_modello` | `true` | Turn it off if you prefer to manage models by hand |
| `file_cookie` | *(empty)* | Netscape-format cookie file inside `/share`. Both `cookies.txt` and `/share/cookies.txt` work. The file is never modified: a copy is used |
| `log_level` | `info` | Log verbosity |

## How to use it

Two routes, and they are not equivalent legally:

- **You upload a file** you already have on the device (drag and drop onto the page), pasting
  the caption in. This is the frictionless route.
- **You paste the reel's link** and the add-on downloads it. Downloading a reel breaches
  Instagram's Terms of Use — which is why this tool is **local and for personal use**, and
  why the route without downloading always exists. See
  [docs/legal.md](https://github.com/Stinocon/Reel2Recipe/blob/main/docs/legal.md)
  (Italian, with an English summary).

Instagram requires you to be signed in for much of its content. There is no browser in here
to take cookies from, so the way is to export them elsewhere in Netscape format, put them in
`/share` and name them in `file_cookie` — `cookies-instagram.txt`, for instance.

The result is not a file dropped in a folder: the recipe enters a library with full-text
search, gets corrected by hand where needed, and exports to `.melarecipe`, Markdown or PDF.

## What it does not do, worth knowing first

- **The model does not convert the amounts, the code does**, with density tables that each
  cite a source. Where a density is unknown the conversion is not done: the volume is kept
  and the gap declared. In a kitchen, a wrong weight you don't know is wrong does real
  damage.
- **It does not invent.** Amounts or steps not deducible from the material stay declared
  gaps. An incomplete but honest recipe is usable; one completed at random is not.
- **Translating ingredient names is the weak spot.** From an English source, names go wrong
  with some regularity; from a long Italian caption towards English the model translates the
  title and stays anchored to Italian in the list. It is a limit of the local model, not of
  the conversion, which stays deterministic in both directions.
- **It does not create Home Assistant entities.** It is an application living in the sidebar,
  not an integration: there are no sensors, services or automations.

## Data and backups

Everything sits on `/data`, which survives updates:

```
/data/workspace/ricette.db     the library
/data/workspace/media/         the downloaded reels
/data/ollama/                  the LLM models
/data/whisper/                 the transcription models
```

Models and media are **excluded from Home Assistant backups**: they are ten-odd GB that can
be downloaded again, and a backup containing them would be unmanageable. The recipe library,
the one thing that cannot be reproduced, is included.

The downloaded material belongs to third parties: it stays here and is not redistributed.

## Reporting problems

Problems with **installing, configuring or starting the add-on** go
[here](https://github.com/Stinocon/addons/issues). Anything about the recipe itself —
transcription, ingredients, conversions, exports — goes to
[Stinocon/Reel2Recipe](https://github.com/Stinocon/Reel2Recipe/issues), where the code lives.

## Licence

MIT: this add-on under the repository's [`LICENSE`](../LICENSE), the application under
[Reel2Recipe's](https://github.com/Stinocon/Reel2Recipe/blob/main/LICENSE). Dependency
attributions are in
[Reel2Recipe's NOTICE.md](https://github.com/Stinocon/Reel2Recipe/blob/main/NOTICE.md); the
provenance of what lives in this repository is in the [`NOTICE.md`](../NOTICE.md) next door.
