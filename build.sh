#!/bin/bash
# Unified build script for simcoon with integrated Python bindings

# Clean previous builds
rm -rf build
rm -rf install
rm -rf python/build

# Build everything with unified CMake (Python bindings ON by default)
uv run cmake -S . -B build -D USE_CARMA=ON
uv run cmake --build build --config Release
uv run cmake --install build --prefix install

# Install Python package (optional)
uv pip install ./src/python --force-reinstall
uv run python -c "import simcoon.simmit"
