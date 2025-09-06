# Tests CMakeLists.txt

message(STATUS "Configuring tests...")

# Test files
file(GLOB_RECURSE TEST_SRCS ${CMAKE_SOURCE_DIR}/test/*.cpp)
file(GLOB_RECURSE TEST_EXTERN ${CMAKE_SOURCE_DIR}/test_extern/*.cpp)

# Plugin libraries for testing
if(NOT MSVC)
  add_library(umat_plugin_aba SHARED 
    ${CMAKE_SOURCE_DIR}/testBin/Umats/UMABA/external/UMAT_ABAQUS_ELASTIC.for 
    ${CMAKE_SOURCE_DIR}/testBin/Umats/UMABA/external/umat_plugin_aba.cpp)
  set_target_properties(umat_plugin_aba PROPERTIES 
    PREFIX "" 
    SUFFIX "" 
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/testBin/Umats/UMABA/external)
  target_link_libraries(umat_plugin_aba simcoon ${ARMADILLO_LIBRARIES})
endif()

# Cross-platform plugin
if(MSVC)
  set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/testBin/Umats/UMEXT/external)
  foreach(CONFIG_TYPE ${CMAKE_CONFIGURATION_TYPES})
    string(TOUPPER ${CONFIG_TYPE} CONFIG)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_${CONFIG} "${CMAKE_SOURCE_DIR}/testBin/Umats/UMEXT/external")
  endforeach()
endif()

add_library(umat_plugin_ext SHARED ${CMAKE_SOURCE_DIR}/testBin/Umats/UMEXT/external/umat_plugin_ext.cpp)
if(MSVC)
  set_target_properties(umat_plugin_ext PROPERTIES PREFIX "" SUFFIX ".dll")
  if (USE_CARMA AND TARGET carma::carma)
    target_link_libraries(umat_plugin_ext simcoon ${ARMADILLO_LIBRARIES} carma::carma)
  else()
    target_link_libraries(umat_plugin_ext simcoon ${ARMADILLO_LIBRARIES})
  endif()
else()
  set_target_properties(umat_plugin_ext PROPERTIES 
    PREFIX "" 
    SUFFIX "" 
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/testBin/Umats/UMEXT/external)
  target_link_libraries(umat_plugin_ext simcoon ${ARMADILLO_LIBRARIES})
endif()

# Configure main test suite
foreach(testSrc ${TEST_SRCS})
  get_filename_component(testFolder ${testSrc} REALPATH ${CMAKE_SOURCE_DIR})
  file(RELATIVE_PATH testRel ${CMAKE_SOURCE_DIR}/test ${testFolder})

  get_filename_component(testName ${testRel} NAME_WE)
  get_filename_component(testFolder ${testRel} DIRECTORY)

  add_executable(${testName} ${testSrc})

  if (MSVC AND USE_CARMA AND TARGET carma::carma)
    target_link_libraries(${testName} simcoon ${ARMADILLO_LIBRARIES} GTest::gtest GTest::gtest_main carma::carma)
  else()
    target_link_libraries(${testName} simcoon ${ARMADILLO_LIBRARIES} GTest::gtest GTest::gtest_main)
  endif()
  target_include_directories(${testName} PRIVATE ${ARMADILLO_INCLUDE_DIRS} ${GTEST_INCLUDE_DIRS})

  set_target_properties(${testName} PROPERTIES 
      RUNTIME_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/testBin/${testFolder}
      RUNTIME_OUTPUT_DIRECTORY_RELEASE ${CMAKE_SOURCE_DIR}/testBin/${testFolder}
      RUNTIME_OUTPUT_DIRECTORY_DEBUG ${CMAKE_SOURCE_DIR}/testBin/${testFolder})

  if(MSVC)
    add_dependencies(${testName} simcoon)
    add_custom_command(TARGET ${testName} POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${CMAKE_BINARY_DIR}/bin
        ${CMAKE_SOURCE_DIR}/testBin/${testFolder})
  endif()

  add_test(NAME ${testFolder}/${testName} 
          WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/testBin/${testFolder}
          COMMAND ${CMAKE_SOURCE_DIR}/testBin/${testFolder}/${testName})
endforeach()

# External tests (Unix only)
if(NOT MSVC)
  foreach(testSrc ${TEST_EXTERN})
    get_filename_component(testFolder ${testSrc} REALPATH ${CMAKE_SOURCE_DIR})
    file(RELATIVE_PATH testRel ${CMAKE_SOURCE_DIR}/test_extern ${testFolder})

    get_filename_component(testName ${testRel} NAME_WE)
    get_filename_component(testFolder ${testRel} DIRECTORY)

    add_executable(${testName} ${testSrc})
    target_link_libraries(${testName} simcoon GTest::gtest GTest::gtest_main)
    target_include_directories(${testName} PRIVATE ${Boost_INCLUDE_DIRS} ${ARMADILLO_INCLUDE_DIRS} ${GTEST_INCLUDE_DIRS})

    set_target_properties(${testName} PROPERTIES 
        RUNTIME_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/testBin/${testFolder}
        RUNTIME_OUTPUT_DIRECTORY_RELEASE ${CMAKE_SOURCE_DIR}/testBin/${testFolder}
        RUNTIME_OUTPUT_DIRECTORY_DEBUG ${CMAKE_SOURCE_DIR}/testBin/${testFolder})

    add_test(NAME ${testFolder}/${testName} 
            WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/testBin/${testFolder}
            COMMAND ${CMAKE_SOURCE_DIR}/testBin/${testFolder}/${testName})
  endforeach()
endif()

message(STATUS "Tests configured successfully")
