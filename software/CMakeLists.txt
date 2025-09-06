# Software CMakeLists.txt

message(STATUS "Configuring executables...")

# Define list of executables to compile
set(EXECUTABLES solver identification L_eff Elastic_props ODF PDF)

# Create executables
foreach(exe ${EXECUTABLES})
  add_executable(${exe} ${exe}.cpp)

  # Link with required libraries
  target_link_libraries(${exe} simcoon ${ARMADILLO_LIBRARIES})
  
  # Link with dl library on Unix systems
  if(NOT WIN32)
    target_link_libraries(${exe} -ldl)
  endif()
endforeach()

message(STATUS "Executables configured successfully")
