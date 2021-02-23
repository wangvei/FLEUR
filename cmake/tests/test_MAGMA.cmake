#First check if we can compile with MAGMA
if (CLI_FLEUR_USE_MAGMA)
   message("Set FLEUR_USE_MAGMA to environment, skipping test")
   set(FLEUR_USE_MAGMA ${CLI_FLEUR_USE_MAGMA})
else()
try_compile(FLEUR_USE_MAGMA ${CMAKE_BINARY_DIR} ${CMAKE_SOURCE_DIR}/cmake/tests/test_MAGMA.f90 LINK_LIBRARIES ${FLEUR_LIBRARIES})
endif()
foreach(test_string "-lmagma" "-L$ENV{MAGMA_LIB};-lmagma")
        if (NOT FLEUR_USE_MAGMA)
                message("Magma test:${test_string}")
             set(TEST_LIBRARIES "${test_string};${FLEUR_LIBRARIES}")
             try_compile(FLEUR_USE_MAGMA ${CMAKE_BINARY_DIR} ${CMAKE_SOURCE_DIR}/cmake/tests/test_MAGMA.f90 LINK_LIBRARIES ${TEST_LIBRARIES} OUTPUT_VARIABLE compile_output)
             if ("$ENV{VERBOSE}")
                     message("MAGMA compile test: ${FLEUR_USE_MAGMA}\nLINK_LIBRARIES ${TEST_LIBRARIES}\n${compile_output}")
             endif()
             if (FLEUR_USE_MAGMA)
               set(FLEUR_LIBRARIES ${TEST_LIBRARIES})
             endif()
        endif()
endforeach()


message("MAGMA Library found:${FLEUR_USE_MAGMA}")

if (FLEUR_USE_MAGMA)
   set(FLEUR_DEFINITIONS ${FLEUR_DEFINITIONS} "CPP_MAGMA")
endif()
