ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base-debian:trixie-2026.02.0
FROM ${BUILD_FROM}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Base Debian e non Alpine: faster-whisper tira dentro ctranslate2 e onnxruntime, che
# pubblicano wheel solo per glibc. Su musl non ci sono binari e si finirebbe a compilare
# ctranslate2 dai sorgenti a ogni build.

ARG BUILD_ARCH=amd64
ARG OLLAMA_VERSION="0.32.6"
# Digest preso da https://github.com/ollama/ollama/releases/download/v${OLLAMA_VERSION}/sha256sum.txt
# Fissato a mano di proposito: scaricare anche il file dei digest dalla stessa origine
# verificherebbe solo che il trasferimento è andato a buon fine, non che il contenuto è
# quello che abbiamo letto quando abbiamo deciso di fidarci.
ARG OLLAMA_SHA256="dec2fa50d24e6868ca3c4c977d69d059399372105f951a9acc320a5a79aadcfc"
ARG UV_VERSION="0.12.3"
ARG R2R_REF="main"

ENV \
    LANG="C.UTF-8" \
    # I dati vanno sul volume persistente dell'addon: la libreria di ricette deve
    # sopravvivere agli aggiornamenti, e i modelli non vanno riscaricati ogni volta.
    R2R_WORKSPACE="/data/workspace" \
    OLLAMA_MODELS="/data/ollama" \
    OLLAMA_HOST="127.0.0.1:11434" \
    # Un solo modello residente: sono ~9 GB di RAM l'uno, e questa macchina fa anche
    # girare Home Assistant.
    OLLAMA_MAX_LOADED_MODELS="1" \
    # Cache dei modelli Whisper (faster-whisper li scarica da Hugging Face al primo uso).
    HF_HOME="/data/whisper" \
    # Senza GPU un 14b su una didascalia lunga supera i 5 minuti predefiniti, e allo
    # scadere si perde tutta la lavorazione — trascrizione compresa.
    R2R_TIMEOUT_LLM="1800" \
    UV_NO_CACHE="1" \
    UV_PYTHON_INSTALL_DIR="/opt/python"

RUN \
    if [ "${BUILD_ARCH}" != "amd64" ]; then \
        echo "Architettura non supportata: ${BUILD_ARCH}. Vedi config.yaml." >&2; exit 1; \
    fi

# ffmpeg estrae la traccia audio dai reel; zstd serve solo a scompattare Ollama; git a
# prendere il codice sorgente.
RUN \
    apt-get update \
    && apt-get install -y --no-install-recommends \
        ffmpeg \
        git \
        zstd \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------------------
# Ollama — il "cervello" locale che struttura la ricetta
# ---------------------------------------------------------------------------------------
RUN \
    curl -fsSL -o /tmp/ollama.tar.zst \
        "https://github.com/ollama/ollama/releases/download/v${OLLAMA_VERSION}/ollama-linux-amd64.tar.zst" \
    && echo "${OLLAMA_SHA256}  /tmp/ollama.tar.zst" | sha256sum -c - \
    && tar --use-compress-program=unzstd -xf /tmp/ollama.tar.zst -C /usr/local \
    && rm -f /tmp/ollama.tar.zst \
    && test -x /usr/local/bin/ollama

# ---------------------------------------------------------------------------------------
# uv — l'unico modo con cui questo progetto gestisce Python (mai pip diretto)
# ---------------------------------------------------------------------------------------
RUN \
    curl -fsSL -o /tmp/uv.tar.gz \
        "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-unknown-linux-gnu.tar.gz" \
    && tar -xzf /tmp/uv.tar.gz -C /tmp \
    && mv /tmp/uv-x86_64-unknown-linux-gnu/uv /usr/local/bin/uv \
    && rm -rf /tmp/uv.tar.gz /tmp/uv-x86_64-unknown-linux-gnu \
    && uv --version

# ---------------------------------------------------------------------------------------
# Reel2Recipe
# ---------------------------------------------------------------------------------------
# Cache-bust: il contenuto di questo file cambia a ogni commit su main, e invalida il
# clone e l'installazione qui sotto. Senza, BuildKit riuserebbe il layer del clone e
# l'addon spedirebbe codice vecchio senza dirlo a nessuno.
ADD https://api.github.com/repos/Stinocon/Reel2Recipe/commits/${R2R_REF} /tmp/r2r-source.json

RUN \
    git clone --depth 1 --branch "${R2R_REF}" \
        https://github.com/Stinocon/Reel2Recipe.git /app \
    && rm -rf /app/.git

WORKDIR /app
# --frozen: si installa esattamente ciò che dice uv.lock, o la build fallisce. --no-dev:
# pytest qui non serve. Gli extra sono quelli che rendono l'addon completo — trascrizione,
# interfaccia web, export PDF.
RUN \
    uv sync --frozen --no-dev \
        --extra asr \
        --extra api \
        --extra doc

# Il codice trova `web/` e `data/` risalendo da dove sta il modulo. Regge finché il progetto
# è installato in forma editabile — che è il predefinito di uv, non una garanzia eterna. Se
# un giorno smettesse di esserlo, senza questo controllo l'immagine partirebbe lo stesso e
# il guasto si vedrebbe come una pagina bianca e una conversione che non trova le tabelle.
RUN \
    /app/.venv/bin/python -c "\
from reel2recipe.paths import REPO_ROOT; \
from reel2recipe.units import load_tables; \
assert (REPO_ROOT / 'web' / 'index.html').is_file(), REPO_ROOT; \
load_tables(); \
print('paths and tables are fine:', REPO_ROOT)"

COPY rootfs /

ARG BUILD_VERSION
LABEL \
    io.hass.name="Reel2Recipe" \
    io.hass.description="Ricette dai reel, in locale, esportabili in Mela" \
    io.hass.arch="amd64" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION}
