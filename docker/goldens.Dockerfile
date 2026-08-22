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
# Pinned by digest, not `:latest`. The Flutter version is checked out below, but
# goldens also depend on the base image's fonts and rendering libraries — a
# floating base would shift baselines without a single line of our code
# changing, which is precisely the unexplainable-diff failure this file exists
# to prevent. This digest is the image the committed baselines were generated
# with (ghcr.io/cirruslabs/flutter:latest as of 2026-08-23).
FROM ghcr.io/cirruslabs/flutter@sha256:217a3d81b124f3fab82b24633bf66b256cc74528b894e7f17103f70150232077

# PIN 1 of 2. Must be identical to FLUTTER_VERSION in
# .github/workflows/ci.yml (the `dart` job). Change both together, in the same
# commit — if they drift, baselines are generated on one Flutter version and
# compared on another, and the symptom is an unexplainable golden diff months
# later. See docs/adr/0004-golden-baselines.md.
ARG FLUTTER_VERSION=3.47.1
ENV FLUTTER_ROOT=/sdks/flutter

RUN git config --global --add safe.directory "$FLUTTER_ROOT" \
 && cd "$FLUTTER_ROOT" \
 && git fetch --depth 1 origin "refs/tags/${FLUTTER_VERSION}:refs/tags/${FLUTTER_VERSION}" \
 && git checkout "${FLUTTER_VERSION}" \
 && flutter --version \
 && flutter precache --universal

WORKDIR /work
