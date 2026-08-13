# Changelog

<!-- English only, on purpose: Home Assistant shows this file to whoever installs the
     add-on, from any country. One language, and the one that reaches the most people. The
     add-on's README is the bilingual one. -->

## 1.0.4

**The add-on could not be built.** Its Dockerfile ends with a sanity check that imports two
names from Reel2Recipe, to make sure the clone is installed in a shape where the code can
still find `web/` and `data/`. Two renames in the upstream project moved those names —
`percorsi` became `paths`, `carica_tabelle` became `load_tables` — and nothing connected the
two repositories, so every build since has stopped on that line.

The failure was at least loud: the build halts and no broken image ships. But it went
unnoticed for two releases because the list of coupling points between the two repos named
four, and this was the fifth. Reel2Recipe's own test suite now holds this contract too, next
to the start-up line it already held, so a rename there turns something red before it stops a
build here.

Nothing changes for anyone already running the add-on.

## 1.0.3

**The interface speaks English too.** The switch is in the header: the choice is remembered
and on first open it follows your browser's language. From it descends a chain of three
links — interface, recipe language, measurement system — each falling back to the one before
it and each overridable. Change nothing and you get a coherent set; someone who cooks in one
language and lives in another can cross them.

**The recipe-language selector was not wired to anything.** It had been drawn in the
*Options* panel since 1.0.0, you could pick a language, and every extraction came out in
Italian with metric units regardless. A control that does nothing is worse than a missing
one: it teaches you not to trust the interface.

**Whisper was told every reel was Italian.** The spoken language was pinned to "it" and
exposed nowhere, so even an English reel was transcribed as if it were Italian — Italian
words forced onto English sounds, and everything downstream then worked on those. The fault
was invisible, because the model produces a plausible recipe anyway. Now Whisper detects the
language itself, and it can still be forced from *Options* when detection gets it wrong.

**Dragging in a video threw away your settings.** Uploading a file only accepted the language
and the measurement system: transcription backend, model and "use the caption only" were
silently discarded. Both routes now take the same options.

## 1.0.2

**The model stopped re-downloading after a failure.** On first install the 9 GB of
`qwen2.5:14b` arrived whole and were rejected by the sha256 check (`digest mismatch`). The
pull was attempted once only: after that failure the add-on stayed without a model forever,
and the only remedy was restarting it by hand.

It now retries **three times**, with growing waits. Three and not endlessly: if the cause is
a full disk, retrying forever does not fix it. To tell the two causes apart — a file
truncated by exhausted space gives the same `digest mismatch` as corruption in transit — the
log writes the free space on `/data` at every failure.

**The interface's message was wrong three times over.** It suggested
`ollama pull qwen2.5:7b-instruct`: a different model from the one the add-on installs, and
moreover the one rejected for losing ingredient groups and inventing amounts. It told you to
run commands in a shell that does not exist inside Home Assistant. And it did not distinguish
"no model" from "downloading it right now", which is the normal case for the first half hour.

## 1.0.1

**The interface would not start.** The add-on installed and started, but opening it made Home
Assistant answer "502 Bad Gateway".

The service script passed `--ollama` after the `serve` subcommand, but it is a global option
of the program and goes before it: argparse exited with code 2, s6 restarted the service
endlessly, and the Ingress found nobody listening on port 8500. The server never started even
once — with a proxy in front it looked like a network problem.

The log added to the confusion: it announced "Interface ready on the Ingress" *before*
starting it, so at every restart it asserted something that was not true. It now says
"Starting the interface" and no longer testifies to what it has not seen.

That line is a contract between two repositories and nobody was checking it: it is now held
in place by `tests/test_cli.py` in Reel2Recipe.

## 1.0.0

First stable version. The 0.1.x releases before it were trial runs and are no longer
available: what they fixed is inside this one.

- The Reel2Recipe interface served through the Ingress, in the sidebar.
- Ollama and Whisper run inside the add-on: no remote service, no API key, no data leaving
  the machine.
- The LLM is downloaded on first start (`modello_llm`, `scarica_modello`) without blocking
  the interface, which meanwhile declares itself not ready. The transcription model (~1.5 GB)
  is downloaded at startup too, rather than on the first recipe: previously the progress bar
  sat on "Transcribing the speech" for minutes with no explanation.
- Library, media and models on `/data`; models and media excluded from backups.
- `file_cookie` for reels that require signing in, read from `/share` read-only. A private,
  temporary copy is used: yt-dlp rewrites that file when a download ends, but `/share` is
  mounted read-only, and without the copy a successful download failed at the last step. The
  copy holds session credentials, so it is created with restricted permissions and an
  unpredictable name, and deleted afterwards.
- Method steps come out unnumbered: Mela numbers the lines itself, and adding it produced
  "1 1. Blend the tofu".
- `amd64` only: inference runs on the CPU and needs a machine with 16 GB of RAM.
