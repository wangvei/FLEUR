#cmake file to set compiler flags for some of the known compilers

if (${CMAKE_Fortran_COMPILER_ID} MATCHES "Intel")
   message("Intel Fortran detected")
   if (${CMAKE_Fortran_COMPILER_VERSION} VERSION_LESS "13.0.0.0")
      set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -mkl -r8 -openmp")
   else()
      set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -mkl -r8 -qopenmp")
   endif()     
   set(CMAKE_Fortran_FLAGS_RELEASE "${CMAKE_Fortran_FLAGS_RELEASE} -xHost -O4")
   set(CMAKE_Fortran_FLAGS_DEBUG "${CMAKE_Fortran_FLAGS_DEBUG} -C -traceback -O0 -g")
elseif(${CMAKE_Fortan_COMPILER_ID} MATCHES "PGI")
   message("PGI Fortran detected")
   set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -mp -Mr8 -Mr8intrinsics")
   set(CMAKE_Fortran_FLAGS_RELEASE "${CMAKE_Fortran_FLAGS_RELEASE} -fast -O3")
   set(CMAKE_Fortran_FLAGS_DEBUG "${CMAKE_Fortran_FLAGS_DEBUG} -C -traceback -O0 -g -Mchkstk -Mchkptr")
elseif(${CMAKE_Fortran_COMPILER_ID} MATCHES "XL")
   message("IBM/BG Fortran detected")
   set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -qsmp=omp -qnosave -qarch=qp -qtune=qp -qrealsize=8 -qfixed -qsuppress=1520-022 -qessl") 
   set(CMAKE_Fortran_FLAGS_RELEASE "${CMAKE_Fortran_FLAGS_RELEASE} -O4   -qsuppress=1500-036")
   set(CMAKE_Fortran_FLAGS_DEBUG "${CMAKE_Fortran_FLAGS_DEBUG}  -O0 -g")
   set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -I/bgsys/local/libxml2/include/libxml2")
   set(FLEUR_DEFINITIONS ${FLEUR_DEFINITIONS} "CPP_AIX")
   set(FLEUR_MPI_DEFINITIONS ${FLEUR_MPI_DEFINITIONS} "CPP_AIX")
elseif(${CMAKE_Fortran_COMPILER_ID} MATCHES "GNU")
   message("gfortran detected")
   set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -ffree-line-length-none -fopenmp -fdefault-real-8 ")
   set(CMAKE_Fortran_FLAGS_RELEASE "${CMAKE_Fortran_FLAGS_RELEASE} -O4")
   set(CMAKE_Fortran_FLAGS_DEBUG "${CMAKE_Fortran_FLAGS_DEBUG} -O0 -g")
endif()
