# ============================================================================
# BUILD STAGE - Install dependencies and build Python packages
# ============================================================================
FROM python:3.12-slim-bookworm AS build

# C4ai version
ARG C4AI_VER=0.7.7
ENV C4AI_VERSION=$C4AI_VER
LABEL c4ai.version=$C4AI_VER

# Set build arguments
ARG APP_HOME=/app
ARG GITHUB_REPO=https://github.com/unclecode/crawl4ai.git
ARG GITHUB_BRANCH=main
ARG USE_LOCAL=true
ARG PYTHON_VERSION=3.12
ARG INSTALL_TYPE=default
ARG ENABLE_GPU=false
ARG TARGETARCH

ENV PYTHONFAULTHANDLER=1 \
    PYTHONHASHSEED=random \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_DEFAULT_TIMEOUT=100 \
    DEBIAN_FRONTEND=noninteractive

LABEL maintainer="unclecode"
LABEL description="🔥🕷️ Crawl4AI: Open-source LLM Friendly Web Crawler & scraper"
LABEL version="1.0"

# Install build dependencies only
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    wget \
    gnupg \
    git \
    cmake \
    pkg-config \
    python3-dev \
    libjpeg-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install platform-specific build dependencies
RUN if [ "$TARGETARCH" = "arm64" ]; then \
        apt-get update && apt-get install -y --no-install-recommends \
        libopenblas-dev \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/*; \
    elif [ "$TARGETARCH" = "amd64" ]; then \
        apt-get update && apt-get install -y --no-install-recommends \
        libomp-dev \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/*; \
    fi

WORKDIR ${APP_HOME}

# Create install script
RUN echo '#!/bin/bash\n\
if [ "$USE_LOCAL" = "true" ]; then\n\
    echo "📦 Installing from local source..."\n\
    pip install --no-cache-dir /tmp/project/\n\
else\n\
    echo "🌐 Installing from GitHub..."\n\
    for i in {1..3}; do \n\
        git clone --branch ${GITHUB_BRANCH} ${GITHUB_REPO} /tmp/crawl4ai && break || \n\
        { echo "Attempt $i/3 failed! Taking a short break... ☕"; sleep 5; }; \n\
    done\n\
    pip install --no-cache-dir /tmp/crawl4ai\n\
fi' > /tmp/install.sh && chmod +x /tmp/install.sh

# Copy project files
COPY . /tmp/project/
COPY deploy/docker/requirements.txt /tmp/requirements.txt

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r /tmp/requirements.txt

# Install optional dependencies based on INSTALL_TYPE
RUN if [ "$INSTALL_TYPE" = "all" ] ; then \
        pip install --no-cache-dir \
            torch \
            torchvision \
            torchaudio \
            scikit-learn \
            nltk \
            transformers \
            tokenizers && \
        python -m nltk.downloader punkt stopwords ; \
    fi

# Install crawl4ai package
RUN if [ "$INSTALL_TYPE" = "all" ] ; then \
        pip install "/tmp/project[all]" && \
        python -m crawl4ai.model_loader ; \
    elif [ "$INSTALL_TYPE" = "torch" ] ; then \
        pip install "/tmp/project[torch]" ; \
    elif [ "$INSTALL_TYPE" = "transformer" ] ; then \
        pip install "/tmp/project[transformer]" && \
        python -m crawl4ai.model_loader ; \
    else \
        pip install "/tmp/project" ; \
    fi

# Run install script
RUN /tmp/install.sh && \
    python -c "import crawl4ai; print('✅ crawl4ai is ready to rock!')" && \
    python -c "from playwright.sync_api import sync_playwright; print('✅ Playwright is feeling dramatic!')"

# Setup crawl4ai and install Playwright browsers
RUN crawl4ai-setup && \
    playwright install --with-deps

# ============================================================================
# RUNTIME STAGE - Minimal runtime image
# ============================================================================
FROM python:3.12-slim-bookworm AS runtime

ARG APP_HOME=/app
ARG ENABLE_GPU=false
ARG TARGETARCH

ENV PYTHONFAULTHANDLER=1 \
    PYTHONHASHSEED=random \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    DEBIAN_FRONTEND=noninteractive \
    REDIS_HOST=localhost \
    REDIS_PORT=6379 \
    PYTHON_ENV=production

# Install runtime dependencies only (no build tools)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    # Playwright runtime dependencies
    libglib2.0-0 \
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libdbus-1-3 \
    libxcb1 \
    libxkbcommon0 \
    libx11-6 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libpango-1.0-0 \
    libcairo2 \
    libasound2 \
    libatspi2.0-0 \
    # Application dependencies
    redis-server \
    supervisor \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install GPU runtime dependencies if enabled
RUN if [ "$ENABLE_GPU" = "true" ] && [ "$TARGETARCH" = "amd64" ] ; then \
        apt-get update && apt-get install -y --no-install-recommends \
        nvidia-cuda-toolkit \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/* ; \
    fi

# Create non-root user
RUN groupadd -r appuser && useradd --no-log-init -r -g appuser appuser && \
    mkdir -p /home/appuser && chown -R appuser:appuser /home/appuser

WORKDIR ${APP_HOME}

# Copy Python packages from build stage
COPY --from=build /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=build /usr/local/bin /usr/local/bin

# Copy Playwright browsers and cache
COPY --from=build --chown=appuser:appuser /root/.cache/ms-playwright /home/appuser/.cache/ms-playwright

# Copy application code
COPY deploy/docker/supervisord.conf ${APP_HOME}/
COPY deploy/docker/* ${APP_HOME}/
COPY deploy/docker/static ${APP_HOME}/static

# Create necessary directories
RUN mkdir -p /var/lib/redis /var/log/redis && \
    chown -R appuser:appuser ${APP_HOME} /var/lib/redis /var/log/redis

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD bash -c '\
    MEM=$(free -m | awk "/^Mem:/{print \$2}"); \
    if [ $MEM -lt 2048 ]; then \
        echo "⚠️ Warning: Less than 2GB RAM available! Your container might need a memory boost! 🚀"; \
        exit 1; \
    fi && \
    if [ -z "$REDIS_URI" ]; then \
        redis-cli ping > /dev/null || exit 1; \
    fi && \
    curl -f http://localhost:11235/health || exit 1'

EXPOSE 6379

# Switch to non-root user
USER appuser

# Start the application using supervisord
CMD ["supervisord", "-c", "supervisord.conf"]
