#!/usr/bin/env python3
"""
Setup script for simcoon Python package.
This setup.py is designed to work with the CMake build system.
"""

from setuptools import setup, find_packages
import os

# Read version from the package
def get_version():
    version_file = os.path.join(os.path.dirname(__file__), 'simcoon', '__version__.py')
    version = {}
    with open(version_file) as f:
        exec(f.read(), version)
    return version['__version__']

# Read README if available
def get_long_description():
    readme_path = os.path.join(os.path.dirname(__file__), '..', '..', 'README.md')
    if os.path.exists(readme_path):
        with open(readme_path, 'r', encoding='utf-8') as f:
            return f.read()
    return "SIMCOON Python bindings for computational mechanics simulations"

setup(
    name="simcoon",
    version=get_version(),
    author="SIMCOON Development Team",
    description="Python bindings for SIMCOON computational mechanics library",
    long_description=get_long_description(),
    long_description_content_type="text/markdown",
    packages=find_packages(),
    package_data={
        'simcoon': ['*.pyd', '*.so', '*.dll', '*.dylib'],  # Include compiled extensions and libraries
    },
    include_package_data=True,
    python_requires='>=3.7',
    install_requires=[
        'numpy>=1.15.0',
    ],
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Science/Research",
        "Topic :: Scientific/Engineering",
        "License :: OSI Approved :: GNU General Public License v3 (GPLv3)",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.7",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
    ],
    zip_safe=False,  # Required for compiled extensions
)
