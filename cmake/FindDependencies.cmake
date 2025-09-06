# FindDependencies.cmake
# Centralized dependency management for simcoon

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
  # Export USE_RELEASE_LIBS for parent scope (only if we have a parent)
  get_directory_property(HAS_PARENT PARENT_DIRECTORY)
  if(HAS_PARENT)
    set(USE_RELEASE_LIBS ${USE_RELEASE_LIBS} PARENT_SCOPE)
  endif()
endif()

# Armadillo
find_package(Armadillo 12.6 REQUIRED)

# GTest for testing
find_package(GTest REQUIRED)

# Carma for NumPy integration (optional, mainly for MSVC)
if (MSVC AND USE_CARMA)
  find_package(Carma QUIET)
  if(NOT Carma_FOUND)
    message(STATUS "Carma not found via find_package, will be fetched by Python bindings if needed")
  endif()
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

# Boost
find_package(Boost 1.57.0 REQUIRED COMPONENTS system filesystem atomic)
include_directories(SYSTEM ${Boost_INCLUDE_DIRS})

message(STATUS "Dependencies found successfully")
