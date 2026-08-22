# syntax=docker/dockerfile:1

# Golden baseline generation, pinned to the Flutter version CI uses.
#
# Alchemist CI mode is platform-independent in intent, not in fact: a baseline
# generated on Windows differs from the same test on Linux by ~0.7% of pixels.
# CI runs Linux, so baselines must be generated here and only here.
#
#   docker compose -f docker-compose.goldens.yml run --rm goldens
#
# See docs/06-TESTING-STRATEGY.md §3 and docs/adr/0003.
FROM ghcr.io/cirruslabs/flutter:latest

# Must match FLUTTER_VERSION in .github/workflows/ci.yml.
ARG FLUTTER_VERSION=3.47.1
ENV FLUTTER_ROOT=/sdks/flutter

RUN git config --global --add safe.directory "$FLUTTER_ROOT" \
 && cd "$FLUTTER_ROOT" \
 && git fetch --depth 1 origin "refs/tags/${FLUTTER_VERSION}:refs/tags/${FLUTTER_VERSION}" \
 && git checkout "${FLUTTER_VERSION}" \
 && flutter --version \
 && flutter precache --universal

WORKDIR /work
