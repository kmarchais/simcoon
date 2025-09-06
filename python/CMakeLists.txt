# Python CMakeLists.txt
# Builds Python bindings for simcoon using pybind11

message(STATUS "Configuring Python bindings...")

# Find Python and required components
find_package(Python3 COMPONENTS Interpreter Development NumPy)
if(NOT Python3_FOUND OR NOT Python3_NumPy_FOUND)
  message(FATAL_ERROR "Python3 with NumPy development headers is required for Python bindings. "
                      "Install python3-dev and python3-numpy (Ubuntu) or equivalent packages.")
endif()

find_package(pybind11)
if(NOT pybind11_FOUND)
  message(FATAL_ERROR "pybind11 is required for Python bindings. "
                      "Install via 'pip install pybind11' or package manager.")
endif()

# Fetch carma if not found (for NumPy integration)
include(FetchContent)
find_package(carma CONFIG QUIET)
if(NOT carma_FOUND)
  message(STATUS "carma not found, fetching from GitHub")
  FetchContent_Declare(
    carma
    GIT_REPOSITORY https://github.com/RUrlus/carma.git
    GIT_TAG        stable
  )
  FetchContent_MakeAvailable(carma)
endif()

# Find simcoon library (built by root CMakeLists.txt)
find_package(simcoon REQUIRED)

# Include directories
include_directories(SYSTEM ${ARMADILLO_INCLUDE_DIRS})
include_directories(SYSTEM ${PYTHON_INCLUDE_DIRS})
include_directories(SYSTEM ${SIMCOON_INCLUDE_DIRS})
include_directories(SYSTEM ${CARMA_INCLUDE_DIR})
include_directories(include)

# OpenMP support (optional)
if (NOT DEFINED USE_OPENMP)
  set(USE_OPENMP TRUE)
endif()
if (USE_OPENMP)
  find_package(OpenMP)
endif()

# Compiler settings for Python bindings
if (MSVC)
  set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)
  if (USE_OPENMP)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /std:c++latest /Drestrict= /openmp:llvm /Y-")
  else()
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /std:c++latest /Drestrict=")
  endif()
endif()

# Get source files for Python bindings
file(GLOB_RECURSE PYTHON_WRAPPER_SOURCES src/python_wrappers/* include/simcoon/python_wrappers/*)

# Create the main Python module
pybind11_add_module(simmit ${PYTHON_WRAPPER_SOURCES})

# Set RPATH for Unix systems
if(APPLE)
  set_target_properties(simmit PROPERTIES
      INSTALL_RPATH "@loader_path"
      BUILD_WITH_INSTALL_RPATH ON
  )
elseif(UNIX)
  set_target_properties(simmit PROPERTIES
      INSTALL_RPATH "$ORIGIN"
      BUILD_WITH_INSTALL_RPATH ON
  )
endif()

# Set file extension
if (MSVC)
  set_target_properties(simmit PROPERTIES PREFIX "" SUFFIX ".pyd")
else()
  set_target_properties(simmit PROPERTIES PREFIX "" SUFFIX ".so")
endif()

# Link libraries
target_link_libraries(simmit PRIVATE ${ARMADILLO_LIBRARIES} carma::carma Python3::Module ${SIMCOON_LIBRARIES})
if (USE_OPENMP AND OpenMP_CXX_FOUND)
  target_link_libraries(simmit PUBLIC OpenMP::OpenMP_CXX)
endif()

set_target_properties(simmit PROPERTIES CXX_STANDARD 17 CXX_STANDARD_REQUIRED ON)

# Create destination directory in source tree for development builds
set(PYTHON_PACKAGE_DIR ${CMAKE_SOURCE_DIR}/src/python/simcoon)
file(MAKE_DIRECTORY ${PYTHON_PACKAGE_DIR})

# Install Python extension
install(TARGETS simmit DESTINATION ${PYTHON_PACKAGE_DIR})

# Install simcoon library
if(APPLE)
  set(SIMCOON_LIB_FILE ${SIMCOON_LIBRARIES})
elseif(UNIX)
  set(SIMCOON_LIB_FILE ${SIMCOON_LIBRARIES})
elseif(WIN32)
  get_filename_component(SIMCOON_DIR ${SIMCOON_LIBRARIES} DIRECTORY)
  set(SIMCOON_LIB_FILE "${SIMCOON_DIR}/../bin/simcoon.dll")
endif()

install(FILES ${SIMCOON_LIB_FILE} DESTINATION ${PYTHON_PACKAGE_DIR})

# Install Windows DLL dependencies
if(WIN32)
  get_filename_component(SIMCOON_BIN_DIR ${SIMCOON_LIB_FILE} DIRECTORY)
  file(GLOB INSTALL_DLLS "${SIMCOON_BIN_DIR}/*.dll")
  if(INSTALL_DLLS)
    install(FILES ${INSTALL_DLLS} DESTINATION ${PYTHON_PACKAGE_DIR})
    foreach(DLL_FILE ${INSTALL_DLLS})
      get_filename_component(DLL_NAME ${DLL_FILE} NAME)
      message(STATUS "Installing dependency DLL: ${DLL_NAME}")
    endforeach()
  else()
    message(WARNING "No DLLs found in install/bin directory: ${SIMCOON_BIN_DIR}")
  endif()
endif()

# Tests
enable_testing()

# Carma tests
file(GLOB_RECURSE TEST_CARMA_FILES test/Carma/*.cpp test/Carma/*.hpp)
if(TEST_CARMA_FILES)
  pybind11_add_module(test_carma ${TEST_CARMA_FILES})
  
  if(MSVC)
    set_target_properties(test_carma PROPERTIES PREFIX "" SUFFIX ".pyd")
  else()
    set_target_properties(test_carma PROPERTIES 
      PREFIX "" 
      SUFFIX ".so"
      LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/test/Carma")
  endif()
  
  target_link_libraries(test_carma PRIVATE carma::carma ${ARMADILLO_LIBRARIES} Python3::Module)
  
  # Add carma tests
  add_test(NAME test_carma_roundtrip 
           WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/test/Carma
           COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/test/Carma/run_test_roundtrip.py)
  add_test(NAME test_carma_arr_to_mat 
           WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/test/Carma
           COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/test/Carma/run_test_arr_to_mat.py)
endif()

# Simmit integration test
add_test(NAME simmit_test 
         WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/test/simmit_test
         COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/test/simmit_test/run_test.py)

message(STATUS "Python bindings configured successfully")
