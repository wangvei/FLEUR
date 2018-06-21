#First check if we can compile with ELPA
try_compile(FLEUR_USE_ELPA ${CMAKE_BINARY_DIR} ${CMAKE_SOURCE_DIR}/cmake/tests/test_ELPA.f90
LINK_LIBRARIES ${FLEUR_LIBRARIES})

if (NOT FLEUR_USE_ELPA)
   if (DEFINED CLI_ELPA_OPENMP)
      set(TEST_LIBRARIES "${FLEUR_LIBRARIES};-lelpa_openmp")
   else()
      set(TEST_LIBRARIES "${FLEUR_LIBRARIES};-lelpa")
   endif()
   try_compile(FLEUR_USE_ELPA ${CMAKE_BINARY_DIR} ${CMAKE_SOURCE_DIR}/cmake/tests/test_ELPA.f90
LINK_LIBRARIES ${TEST_LIBRARIES})
   if (FLEUR_USE_ELPA)
      set(FLEUR_LIBRARIES "${TEST_LIBRARIES}")
   endif()
endif()


message("ELPA Library found:${FLEUR_USE_ELPA}")

#Now check for version of elpa
if (FLEUR_USE_ELPA)
    set(FLEUR_USE_ELPA false)
    try_compile(FLEUR_USE_ELPA_OLD ${CMAKE_BINARY_DIR} ${CMAKE_SOURCE_DIR}/cmake/tests/test_ELPA_OLD.f90
LINK_LIBRARIES ${FLEUR_LIBRARIES})
try_compile(FLEUR_USE_ELPA_NEW ${CMAKE_BINARY_DIR} ${CMAKE_SOURCE_DIR}/cmake/tests/test_ELPA_NEW.f90
LINK_LIBRARIES ${FLEUR_LIBRARIES})
try_compile(FLEUR_USE_ELPA_201605003 ${CMAKE_BINARY_DIR} ${CMAKE_SOURCE_DIR}/cmake/tests/test_ELPA_201605003.f90
LINK_LIBRARIES ${FLEUR_LIBRARIES})
try_compile(FLEUR_USE_ELPA_201605004 ${CMAKE_BINARY_DIR} ${CMAKE_SOURCE_DIR}/cmake/tests/test_ELPA_201605004.f90
LINK_LIBRARIES ${FLEUR_LIBRARIES})
try_compile(FLEUR_USE_ELPA_201705003 ${CMAKE_BINARY_DIR} ${CMAKE_SOURCE_DIR}/cmake/tests/test_ELPA_201705003.f90
LINK_LIBRARIES ${FLEUR_LIBRARIES})
    message("Version check for ELPA:")
    message("OLD ELPA      : ${FLEUR_USE_ELPA_OLD}")
    message("NEW ELPA      : ${FLEUR_USE_ELPA_NEW}")
    message("201605003 ELPA: ${FLEUR_USE_ELPA_201605003}")
    message("201605004 ELPA: ${FLEUR_USE_ELPA_201605004}")
    message("201705003 ELPA: ${FLEUR_USE_ELPA_201705003}")
#Set preprocessor switches
   if (FLEUR_USE_ELPA_OLD)
       set(FLEUR_USE_ELPA TRUE)
       set(FLEUR_MPI_DEFINITIONS ${FLEUR_MPI_DEFINITIONS} "CPP_ELPA" "CPP_ELPA2")
   endif()
   if (FLEUR_USE_ELPA_NEW)
       set(FLEUR_USE_ELPA TRUE)
       set(FLEUR_MPI_DEFINITIONS ${FLEUR_MPI_DEFINITIONS} "CPP_ELPA" "CPP_ELPA2" "CPP_ELPA_NEW")
   endif()
   if (FLEUR_USE_ELPA_201605003)
       set(FLEUR_USE_ELPA TRUE)
       set(FLEUR_MPI_DEFINITIONS ${FLEUR_MPI_DEFINITIONS} "CPP_ELPA" "CPP_ELPA2" "CPP_ELPA_201605003")
   endif()
   if (FLEUR_USE_ELPA_201605004)
       set(FLEUR_USE_ELPA TRUE)
       set(FLEUR_MPI_DEFINITIONS ${FLEUR_MPI_DEFINITIONS} "CPP_ELPA" "CPP_ELPA2" "CPP_ELPA_201605004")
   endif()
   if (FLEUR_USE_ELPA_201705003)
       set(FLEUR_USE_ELPA TRUE)
       set(FLEUR_MPI_DEFINITIONS ${FLEUR_MPI_DEFINITIONS} "CPP_ELPA" "CPP_ELPA2" "CPP_ELPA_201705003")
   endif()
endif() 
