# Imagen reproducible y autocontenida: restaura renv, genera artefactos y
# ejecuta las pruebas antes de producir la imagen de ejecución.
FROM rocker/r-ver:4.3.3 AS base

ARG DEBIAN_FRONTEND=noninteractive
ENV RENV_CONFIG_SANDBOX_ENABLED=FALSE \
    RENV_CONFIG_AUTOLOADER_ENABLED=TRUE \
    RENV_CONFIG_CACHE_SYMLINKS=FALSE \
    TZ=Etc/UTC

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        gfortran \
        libcurl4-openssl-dev \
        libfontconfig1-dev \
        libfreetype6-dev \
        libfribidi-dev \
        libglpk-dev \
        libharfbuzz-dev \
        libicu-dev \
        libjpeg-dev \
        libpng-dev \
        libssl-dev \
        libtiff5-dev \
        libuv1-dev \
        libxml2-dev \
        libxt-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/breast-cancer-mvp

FROM base AS builder

# Restaurar primero el lockfile mejora el uso de caché cuando cambia el código.
COPY .Rprofile renv.lock ./
# No copiar renv/library/: puede contener enlaces locales no versionados.
COPY renv/activate.R renv/settings.json ./renv/
RUN R -q -e 'renv::restore(prompt = FALSE)'

COPY DESCRIPTION README.md project_spec.md ./
COPY R/ ./R/
COPY app/ ./app/
COPY data/ ./data/
COPY tests/ ./tests/

# Los artefactos se crean dentro del build: no se necesita versionar binarios.
RUN Rscript R/train_model.R \
    && Rscript tests/run_tests.R

FROM base AS runtime

# En ejecución se usa explícitamente la biblioteca ya restaurada. No se activa
# renv para volver a escanear fuentes de desarrollo que no viajan en la imagen.
ENV R_LIBS_USER=/opt/breast-cancer-mvp/renv/library/R-4.3/x86_64-pc-linux-gnu

COPY --from=builder /opt/breast-cancer-mvp/renv.lock ./
COPY --from=builder /opt/breast-cancer-mvp/renv/ ./renv/
COPY --from=builder /opt/breast-cancer-mvp/DESCRIPTION ./
COPY --from=builder /opt/breast-cancer-mvp/R/ ./R/
COPY --from=builder /opt/breast-cancer-mvp/app/ ./app/
COPY --from=builder /opt/breast-cancer-mvp/artifacts/ ./artifacts/

RUN groupadd --system shiny \
    && useradd --system --gid shiny --home-dir /opt/breast-cancer-mvp shiny \
    && chown -R shiny:shiny /opt/breast-cancer-mvp

USER shiny
EXPOSE 3838

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl --fail --silent http://127.0.0.1:3838/ || exit 1

CMD ["R", "-q", "-e", "shiny::runApp('app', host = '0.0.0.0', port = 3838, launch.browser = FALSE)"]
