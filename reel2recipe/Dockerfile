ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base-debian:trixie-2026.02.0
FROM ${BUILD_FROM}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Debian base and not Alpine: faster-whisper pulls in ctranslate2 and onnxruntime, which
# publish wheels for glibc only. On musl there are no binaries and it would end up compiling
# ctranslate2 from source on every build.

ARG BUILD_ARCH=amd64
ARG OLLAMA_VERSION="0.32.6"
# Digest taken from https://github.com/ollama/ollama/releases/download/v${OLLAMA_VERSION}/sha256sum.txt
# Pinned by hand on purpose: downloading the digest file from the same origin too would only
# verify that the transfer went through, not that the content is the one we read when we
# decided to trust it.
ARG OLLAMA_SHA256="dec2fa50d24e6868ca3c4c977d69d059399372105f951a9acc320a5a79aadcfc"
ARG UV_VERSION="0.12.3"
ARG R2R_REF="v1.1.0"

ENV \
    LANG="C.UTF-8" \
    # The data goes on the add-on's persistent volume: the recipe library has to survive
    # updates, and the models must not be downloaded again every time.
    R2R_WORKSPACE="/data/workspace" \
    OLLAMA_MODELS="/data/ollama" \
    OLLAMA_HOST="127.0.0.1:11434" \
    # One resident model only: they are ~9 GB of RAM each, and this machine is also running
    # Home Assistant.
    OLLAMA_MAX_LOADED_MODELS="1" \
    # Whisper model cache (faster-whisper downloads them from Hugging Face on first use).
    HF_HOME="/data/whisper" \
    # With no GPU a 14b on a long caption goes past the default 5 minutes, and when it
    # expires the whole job is lost — transcription included.
    R2R_TIMEOUT_LLM="1800" \
    UV_NO_CACHE="1" \
    UV_PYTHON_INSTALL_DIR="/opt/python"

RUN \
    if [ "${BUILD_ARCH}" != "amd64" ]; then \
        echo "Unsupported architecture: ${BUILD_ARCH}. See config.yaml." >&2; exit 1; \
    fi

# ffmpeg extracts the audio track from the reels; zstd is only for unpacking Ollama; git for
# fetching the source code.
RUN \
    apt-get update \
    && apt-get install -y --no-install-recommends \
        ffmpeg \
        git \
        zstd \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------------------
# Ollama — the local "brain" that structures the recipe
# ---------------------------------------------------------------------------------------
RUN \
    curl -fsSL -o /tmp/ollama.tar.zst \
        "https://github.com/ollama/ollama/releases/download/v${OLLAMA_VERSION}/ollama-linux-amd64.tar.zst" \
    && echo "${OLLAMA_SHA256}  /tmp/ollama.tar.zst" | sha256sum -c - \
    && tar --use-compress-program=unzstd -xf /tmp/ollama.tar.zst -C /usr/local \
    && rm -f /tmp/ollama.tar.zst \
    && test -x /usr/local/bin/ollama

# ---------------------------------------------------------------------------------------
# uv — the only way this project manages Python (never pip directly)
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
# Cache-bust: the content of this file changes on every commit to main, and invalidates the
# clone and the install below. Without it, BuildKit would reuse the clone's layer and the
# add-on would ship old code without telling anybody.
ADD https://api.github.com/repos/Stinocon/Reel2Recipe/commits/${R2R_REF} /tmp/r2r-source.json

RUN \
    git clone --depth 1 --branch "${R2R_REF}" \
        https://github.com/Stinocon/Reel2Recipe.git /app \
    && rm -rf /app/.git

WORKDIR /app
# --frozen: exactly what uv.lock says gets installed, or the build fails. --no-dev: pytest is
# not needed here. The extras are the ones that make the add-on complete — transcription, web
# interface, PDF export.
RUN \
    uv sync --frozen --no-dev \
        --extra asr \
        --extra api \
        --extra doc

# The code finds `web/` and `data/` by walking up from where the module sits. That holds as
# long as the project is installed editable — which is uv's default, not an eternal guarantee.
# If it ever stopped being so, without this check the image would start anyway and the fault
# would show up as a blank page and a conversion that cannot find its tables.
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
    io.hass.description="Recipes from reels, locally, exportable to Mela" \
    io.hass.arch="amd64" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION}
