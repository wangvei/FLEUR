option(FLEUR_USE_OPENMP "whether to use OpenMP" ON)

if (FLEUR_USE_OPENMP)
    find_package(OpenMP)

    if (OpenMP_Fortran_FOUND)
        set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} ${OpenMP_Fortran_FLAGS}")
        if (OpenMP_Fortran_VERSION VERSION_GREATER "3.0")
            set(FLEUR_MPI_DEFINITIONS ${FLEUR_MPI_DEFINITIONS} "CPP_OMP_SIMD='$omp'")
            set(FLEUR_DEFINITIONS ${FLEUR_DEFINITIONS} "CPP_OMP_SIMD='$omp'")
        endif()
        set(FLEUR_USE_OPENMP FALSE)
    endif()
endif()        