# CMakeLists.txt

cmake_minimum_required(VERSION 3.15)

project(simcoon LANGUAGES C CXX)
include(CheckIncludeFileCXX)
include(CheckLibraryExists)

# Read version from Python package
file(READ "src/python/simcoon/__version__.py" VERSION_FILE)
string(REGEX MATCH "__version__ = \"([0-9]+\\.[0-9]+\\.[0-9]+)\"" _ ${VERSION_FILE})
set(PROJECT_VERSION ${CMAKE_MATCH_1})

# Print and set the project version
message(STATUS "Project version: ${PROJECT_VERSION}")
set(PROJECT_VERSION ${PROJECT_VERSION})

# Optionally use this version in packaging/configuration
set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})

message(STATUS "Configuring ${PROJECT_NAME} ${PROJECT_VERSION}")

# Adhere to GNU filesystem layout conventions
include(GNUInstallDirs)

# Build options
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING
        "Choose the type of build, options are: None Debug Release RelWithDebInfo MinSizeRel"
        FORCE)
endif()

# Python bindings option (default ON)
option(BUILD_PYTHON_BINDINGS "Build Python bindings" ON)

# Build tests option (default ON)
option(BUILD_TESTS "Build tests" ON)

message(STATUS "Build type             = ${CMAKE_BUILD_TYPE}")
message(STATUS "BUILD_PYTHON_BINDINGS  = ${BUILD_PYTHON_BINDINGS}")
message(STATUS "BUILD_TESTS            = ${BUILD_TESTS}")

# Dependency Management
message(STATUS "Finding dependencies...")

# BLAS/LAPACK configuration
if (MSVC)
  set(BLA_PKGCONFIG_BLAS True)
  set(CMAKE_FIND_DEBUG_MODE FALSE)
endif()

find_package(BLAS REQUIRED)
find_package(LAPACK REQUIRED)

# Override debug libraries with release versions for MSVC builds
if(MSVC AND BLAS_FOUND AND LAPACK_FOUND)
  string(REPLACE "/debug/lib/" "/lib/" BLAS_LIBRARIES_RELEASE "${BLAS_LIBRARIES}")
  string(REPLACE "/debug/lib/" "/lib/" LAPACK_LIBRARIES_RELEASE "${LAPACK_LIBRARIES}")
  
  set(USE_RELEASE_LIBS TRUE)
  foreach(lib ${BLAS_LIBRARIES_RELEASE} ${LAPACK_LIBRARIES_RELEASE})
    if(NOT EXISTS "${lib}")
      set(USE_RELEASE_LIBS FALSE)
      break()
    endif()
  endforeach()
  
  if(USE_RELEASE_LIBS)
    set(BLAS_LIBRARIES ${BLAS_LIBRARIES_RELEASE})
    set(LAPACK_LIBRARIES ${LAPACK_LIBRARIES_RELEASE})
    message(STATUS "Using release BLAS/LAPACK libraries instead of debug")
  endif()
endif()

# Armadillo
find_package(Armadillo 12.6 REQUIRED)

# GTest for testing (only if building tests)
if(BUILD_TESTS)
  find_package(GTest REQUIRED)
endif()

# Configure Armadillo libraries
if (MSVC)
  set(ARMADILLO_LIBRARIES ${ARMADILLO_LIBRARIES} ${BLAS_LIBRARIES} ${LAPACK_LIBRARIES})
  if(USE_RELEASE_LIBS)
    string(REPLACE "/debug/lib/" "/lib/" ARMADILLO_LIBRARIES "${ARMADILLO_LIBRARIES}")
    message(STATUS "Fixed ARMADILLO_LIBRARIES to use release versions")
  endif()
endif()

include_directories(SYSTEM ${ARMADILLO_INCLUDE_DIRS})

# Boost - handle both old FindBoost and new BoostConfig
# First try new Boost CONFIG mode without components
find_package(Boost 1.57.0 QUIET CONFIG)
if(Boost_FOUND AND TARGET Boost::filesystem AND TARGET Boost::atomic)
  # New Boost CMake config - targets are available directly
  # Note: Boost::system is header-only since Boost 1.69 and may not be available as a target
  if(TARGET Boost::system)
    set(BOOST_LIBRARIES Boost::system Boost::filesystem Boost::atomic)
  else()
    set(BOOST_LIBRARIES Boost::filesystem Boost::atomic)
  endif()
  message(STATUS "Using new Boost CMake config with targets")
else()
  # Fall back to old FindBoost module with components
  # Set policy to allow deprecated FindBoost module
  cmake_policy(PUSH)
  if(POLICY CMP0167)
    cmake_policy(SET CMP0167 OLD)
  endif()
  
  find_package(Boost 1.57.0 REQUIRED COMPONENTS filesystem atomic)
  
  cmake_policy(POP)
  
  if(TARGET Boost::filesystem)
    # Include Boost::system only if it exists (may not be available in newer versions as it's header-only)
    if(TARGET Boost::system)
      set(BOOST_LIBRARIES Boost::system Boost::filesystem Boost::atomic)
    else()
      set(BOOST_LIBRARIES Boost::filesystem Boost::atomic)
    endif()
    message(STATUS "Using legacy FindBoost module with targets")
  else()
    include_directories(SYSTEM ${Boost_INCLUDE_DIRS})
    set(BOOST_LIBRARIES ${Boost_LIBRARIES})
    message(STATUS "Using legacy FindBoost module with variables")
  endif()
endif()

message(STATUS "Dependencies found successfully")

#Setup CMake to run tests
enable_testing()

#Set executable files and library files
set(EXECUTABLE_OUTPUT_PATH bin)
set(LIBRARY_OUTPUT_PATH lib)

# OpenMP
#include(FindOpenMP)
#find_package(OpenMP)

# Set the CFLAGS and CXXFLAGS depending on the options the user specified.
#set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra -Wno-unused-parameter")
#set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -Wextra -Wno-unused-parameter")

if (MSVC) #if windows using visual c++
  set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /std:c++latest /Drestrict=") #\Y- to disable precompile header (don't work for an unknown reason)
  #set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /std:c++latest /Drestrict=")
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS}") #do nothing but kept anyway if required to add some options
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS}") #do nothing but kept anyway if required to add some options

  set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
  set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
  set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

  # Specify the output directory for each configuration (Debug, Release, etc.)
  foreach(CONFIG_TYPE ${CMAKE_CONFIGURATION_TYPES})
    string(TOUPPER ${CONFIG_TYPE} CONFIG)
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_${CONFIG} "${CMAKE_BINARY_DIR}/lib")
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_${CONFIG} "${CMAKE_BINARY_DIR}/lib")
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_${CONFIG} "${CMAKE_BINARY_DIR}/bin")
  endforeach()

elseif (UNIX AND NOT APPLE)
  #enable Fortran
  enable_language(Fortran)

  if (CMAKE_BUILD_TYPE STREQUAL "Debug")
      set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++20 -O0 -Drestrict=")
      set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -std=c++20")
      set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -std=c++20")
  else()
      set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++20 -O3 -Drestrict=")
      set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -std=c++20")
      set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -std=c++20")
  endif()
else()
  #enable Fortran
  enable_language(Fortran)

  if (CMAKE_BUILD_TYPE STREQUAL "Debug")
      set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++20 -stdlib=libc++ -O0 -fpermissive -Drestrict=")
      set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -std=c++20 -stdlib=libc++")
      set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -std=c++20 -stdlib=libc++")
  else()
      set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++20 -stdlib=libc++ -O3 -fpermissive -Drestrict=")
      set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -std=c++20 -stdlib=libc++")
      set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -std=c++20 -stdlib=libc++")
  endif()
endif()

if(OPENMP_FOUND)
	set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${OpenMP_CXX_FLAGS}")
endif()

message(STATUS "CMAKE_SYSTEM_NAME          = ${CMAKE_SYSTEM_NAME}"         )
message(STATUS "CMAKE_CXX_COMPILER_ID      = ${CMAKE_CXX_COMPILER_ID}"     )
message(STATUS "CMAKE_CXX_COMPILER_VERSION = ${CMAKE_CXX_COMPILER_VERSION}")
message(STATUS "CMAKE_CXX_FLAGS            = ${CMAKE_CXX_FLAGS}")
message(STATUS "CMAKE_COMPILER_IS_GNUCXX   = ${CMAKE_COMPILER_IS_GNUCXX}"  )
message(STATUS "BUILD_SHARED_LIBS          = ${BUILD_SHARED_LIBS}"         )
message(STATUS "DETECT_HDF5                = ${DETECT_HDF5}"               )
message(STATUS "ARMADILLO_INCLUDE_DIRS = ${ARMADILLO_INCLUDE_DIRS}")
message(STATUS "ARMADILLO_LIBRARIES = ${ARMADILLO_LIBRARIES}")

#Inclusion of public headers
include_directories(include)

# add the binary tree to the search path for include files
include_directories("${PROJECT_BINARY_DIR}")

#Command file to get all the files in the src/ and include/
file(GLOB_RECURSE source_files src*/* include/*)

set(objs
 external/umat_externalM.o external/umat_externalT.o
 PROPERTIES
 EXTERNAL_OBJECT true
 GENERATED true
)

#Add the files to the lib
add_library(simcoon SHARED ${source_files})
#link against armadillo and boost
target_link_libraries(simcoon ${ARMADILLO_LIBRARIES} ${BOOST_LIBRARIES})

# Include software executables
add_subdirectory(software)

# Include tests (optional)
if(BUILD_TESTS)
  add_subdirectory(tests)
endif()

# Include Python bindings (optional)
if(BUILD_PYTHON_BINDINGS)
    message(STATUS "Python bindings enabled - checking dependencies...")
    
    # Check if Python dependencies are available
    find_package(Python3 COMPONENTS Interpreter Development NumPy QUIET)
    
    # Try to find pybind11, including via pip install
    find_package(pybind11 QUIET)
    if(NOT pybind11_FOUND AND Python3_FOUND)
        # Try to find pybind11 via Python's site-packages
        execute_process(
            COMMAND ${Python3_EXECUTABLE} -m pybind11 --cmakedir
            OUTPUT_VARIABLE PYBIND11_CMAKE_DIR
            OUTPUT_STRIP_TRAILING_WHITESPACE
            RESULT_VARIABLE PYBIND11_CMAKE_RESULT
        )
        if(PYBIND11_CMAKE_RESULT EQUAL 0 AND EXISTS ${PYBIND11_CMAKE_DIR})
            set(pybind11_DIR ${PYBIND11_CMAKE_DIR})
            find_package(pybind11 QUIET)
        endif()
    endif()
    
    if(Python3_FOUND AND Python3_NumPy_FOUND AND pybind11_FOUND)
        message(STATUS "Python dependencies found - building Python bindings")
        add_subdirectory(python)
    else()
        message(WARNING "Python bindings requested but dependencies missing:")
        if(NOT Python3_FOUND)
            message(WARNING "  - Python3 development headers not found")
        endif()
        if(NOT Python3_NumPy_FOUND)
            message(WARNING "  - NumPy development headers not found")
        endif()
        if(NOT pybind11_FOUND)
            message(WARNING "  - pybind11 not found")
        endif()
        message(WARNING "Continuing build without Python bindings...")
        message(WARNING "To fix: install python3-dev, python3-numpy, and pybind11")
    endif()
else()
    message(STATUS "Python bindings disabled")
endif()

#set_property(TARGET FOR PROPERTY)
#add_library(ABA OBJECT testBin/Umats/UMABA/external/umat_plugin_aba.cpp)
#set_property(TARGET ABA PROPERTY COMPILE_FLAGS "${CMAKE_CXX_FLAGS} -fPIC o umat_plugin_aba -lsimcoon -larmadillo -lgfortran")

#add_library(umat OBJECT software/umat_single.cpp)
#set_property(TARGET umat PROPERTY COMPILE_FLAGS "${CMAKE_CXX_FLAGS} -fPIC -c -openm -larmadillo -std=c++20 -DARMA_DONT_USE_WRAPPER")

#add_library(umatT OBJECT software/umat_singleT.cpp)
#set_property(TARGET umatT PROPERTY COMPILE_FLAGS "${CMAKE_CXX_FLAGS} -fPIC -c -openm -larmadillo -std=c++20 -DARMA_DONT_USE_WRAPPER")


################################################################################
# INSTALL CONFIGURATION

set(INSTALL_INCLUDE_DIR include)
set(INSTALL_LIB_DIR lib)

# executables destination
if(NOT INSTALL_BIN_DIR)
  set(INSTALL_BIN_DIR bin)
endif()

message(STATUS "CMAKE_INSTALL_PREFIX = ${CMAKE_INSTALL_PREFIX}")
message(STATUS "INSTALL_LIB_DIR      = ${INSTALL_LIB_DIR}"     )
message(STATUS "INSTALL_INCLUDE_DIR  = ${INSTALL_INCLUDE_DIR}" )
message(STATUS "INSTALL_BIN_DIR      = ${INSTALL_BIN_DIR}"    )

install(DIRECTORY include/ DESTINATION ${INSTALL_INCLUDE_DIR})
install(TARGETS simcoon)

# Install runtime DLLs on Windows
if(WIN32)
  # Install all DLLs from build/bin to install/bin for complete installation
  install(DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/
          DESTINATION ${INSTALL_BIN_DIR}
          FILES_MATCHING PATTERN "*.dll")

  # Note: Boost libraries are statically linked into simcoon.dll
  # No boost DLL installation needed

  # Install BLAS/LAPACK DLLs by finding them near the library files
  if(BLAS_FOUND AND LAPACK_FOUND)
    foreach(lib_path ${BLAS_LIBRARIES} ${LAPACK_LIBRARIES})
      get_filename_component(lib_dir ${lib_path} DIRECTORY)
      get_filename_component(lib_name ${lib_path} NAME_WE)
      
      # Convert lib directory to bin directory to find DLLs
      string(REPLACE "/lib" "/bin" bin_dir "${lib_dir}")
      # Also convert debug paths to release if we're preferring release libraries
      if(USE_RELEASE_LIBS)
        string(REPLACE "/debug/bin" "/bin" bin_dir "${bin_dir}")
      endif()
      
      # Try common DLL names based on the library
      set(possible_dlls "")
      if(lib_name MATCHES "openblas")
        list(APPEND possible_dlls "openblas.dll")
      elseif(lib_name MATCHES "lapack")
        list(APPEND possible_dlls "liblapack.dll")
      endif()
      
      foreach(dll_name ${possible_dlls})
        set(dll_path "${bin_dir}/${dll_name}")
        if(EXISTS "${dll_path}")
          install(FILES "${dll_path}" DESTINATION ${INSTALL_BIN_DIR})
          message(STATUS "Will install BLAS/LAPACK DLL: ${dll_path}")
        endif()
      endforeach()
    endforeach()
  endif()

  # Install GCC runtime DLLs that might be needed by dependencies
  # (even with MSVC, some vcpkg packages might have been built with MinGW)
  set(GCC_RUNTIME_DLLS
      "libgcc_s_seh-1.dll"
      "libgfortran-5.dll"
      "libquadmath-0.dll"
      "libwinpthread-1.dll")
  
  foreach(dll_name ${GCC_RUNTIME_DLLS})
    set(dll_found FALSE)
    
    # First try to find in the same location as BLAS libraries (likely vcpkg/bin)
    foreach(lib_path ${BLAS_LIBRARIES})
      if(NOT dll_found)
        get_filename_component(lib_dir ${lib_path} DIRECTORY)
        string(REPLACE "/lib" "/bin" bin_dir "${lib_dir}")
        if(USE_RELEASE_LIBS)
          string(REPLACE "/debug/bin" "/bin" bin_dir "${bin_dir}")
        endif()
        set(dll_path "${bin_dir}/${dll_name}")
        if(EXISTS "${dll_path}")
          install(FILES "${dll_path}" DESTINATION ${INSTALL_BIN_DIR})
          message(STATUS "Will install GCC runtime DLL: ${dll_path}")
          set(dll_found TRUE)
        endif()
      endif()
    endforeach()
    
    # If not found and we're using GCC, try compiler directory
    if(NOT dll_found AND CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
      get_filename_component(COMPILER_DIR "${CMAKE_CXX_COMPILER}" DIRECTORY)
      set(dll_path "${COMPILER_DIR}/${dll_name}")
      if(EXISTS "${dll_path}")
        install(FILES "${dll_path}" DESTINATION ${INSTALL_BIN_DIR})
        message(STATUS "Will install GCC runtime DLL: ${dll_path}")
        set(dll_found TRUE)
      endif()
    endif()
  endforeach()
endif()
