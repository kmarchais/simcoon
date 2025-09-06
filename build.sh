#!/bin/bash
# Unified build script for simcoon with integrated Python bindings

# Clean previous builds
rm -rf build
rm -rf install
rm -rf python/build

# Build everything with unified CMake (Python bindings ON by default)
cmake -S . -B build -D USE_CARMA=ON
cmake --build build --config Release
cmake --install build --prefix install

# Install Python package (optional)
# uv pip install ./src/python
