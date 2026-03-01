#!/bin/bash
# Run all SDLC Central integration tests
set -e
cd "$(dirname "$0")/.."
node --test tests/*.test.js
