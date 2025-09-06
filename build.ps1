# Clean previous builds
if (Test-Path "build") { Remove-Item -Recurse -Force "build" }
if (Test-Path "install") { Remove-Item -Recurse -Force "install" }

# Build everything with unified CMake (Python bindings ON by default)
cmake -S . -B build -D USE_CARMA=OFF
cmake --build build --config Release
cmake --install build --prefix install

# Install Python package (optional)
# uv pip install ./src/python
