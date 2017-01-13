#This file contains specific compiler flags for
#individual files and compilers
#E.G. it is used to switch of optimization for some files
#The compiler flags are added at the end and hence can be used
#to overwrite previous settings

if (${CMAKE_Fortran_COMPILER_ID} MATCHES "Intel")
   set_source_files_properties(io/eig66_mpi.F90 PROPERTIES COMPILE_FLAGS -O0)
   set_source_files_properties(cdn/pwden.F90 PROPERTIES COMPILE_FLAGS -O0)
   set_source_files_properties(init/lhcal.f PROPERTIES COMPILE_FLAGS -O0)
endif()

