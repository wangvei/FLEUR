cmake_minimum_required(VERSION 3.0)
project(FLEUR LANGUAGES Fortran)

include("../cmake/Generate_Schema.cmake")

#set(FLEURINPUT_COMPILEOPTS "-r8")

add_library(fleurinput	 STATIC
fleurinput_read_xml.f90    fleurinput_mpi_bc.f90
types_fleurinput_base.F90  types_input.f90      
types_coreSpecInput.f90    types_hybinp.f90     types_noco.f90
types_vacuum.f90           types_banddos.f90    types_wannier.f90
types_cell.f90             types_kpts.F90       types_fleurinput.f90
types_sliceplot.f90        types_sym.f90        types_atoms.F90
types_econfig.F90          types_field.F90      types_xcpot.F90
types_enparaXML.f90        types_forcetheo_data.f90
types_mpinp.f90            types_gfinp.F90      types_hub1inp.f90
types_xml.f90              types_juPhon.F90     types_brZone.f90
calculator.f90 constants.f90 mpi_bc_tool.F90 ../include/inputSchema.h ../include/outputSchema.h ../io/xml/dropInputSchema.c 
../io/xml/dropOutputSchema.c ../io/xml/inputSchema_old.h ../io/xml/outputSchema_old.h ../io/xml/xmlInterfaceWrapper.c
../math/d_wigner.F90 ../math/inv3.f90 ../math/grule.f90 ../global/sort.f90 ../global/atom_shells.f90 ../kpoints/tetcon.f90 
../kpoints/triang.f ../kpoints/bravais.f ../kpoints/brzone2.f90
../hybrid/map_to_unit.f90
)
#Set module directories
include_directories("${CMAKE_CURRENT_BINARY_DIR}/modules/fleurinput")

if (DEFINED FLEURINPUT_COMPILEOPTS )
  target_compile_options(fleurinput PRIVATE $<$<COMPILE_LANGUAGE:Fortran>:${FLEURINPUT_COMPILEOPTS}>)
endif()



target_compile_definitions(fleurinput PUBLIC ${FLEUR_DEFINITIONS})
target_link_libraries(fleurinput ${FLEUR_LINK_LIBRARIES})
target_link_libraries(fleurinput juDFT)
set_target_properties(fleurinput PROPERTIES Fortran_MODULE_DIRECTORY modules/fleurinput)

if ((CMAKE_Fortran_COMPILER_ID MATCHES "PGI") OR (CMAKE_Fortran_COMPILER_ID MATCHES "NVHPC"))
	set_source_files_properties(types_kpts.F90 TARGET_DIRECTORY fleurinput PROPERTIES COMPILE_OPTIONS "-nomp")
endif()    

