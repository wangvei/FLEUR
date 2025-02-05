!--------------------------------------------------------------------------------
! Copyright (c) 2016 Peter Grünberg Institut, Forschungszentrum Jülich, Germany
! This file is part of FLEUR and available as free software under the conditions
! of the MIT license as expressed in the LICENSE file in more detail.
!--------------------------------------------------------------------------------

MODULE m_constants
  use m_types_fleurinput_base
  IMPLICIT NONE

  TYPE,EXTENDS(t_fleurinput_base)::t_constants
   CONTAINS
     PROCEDURE:: read_xml=>read_xml_constants
     PROCEDURE:: mpi_bc=>mpi_bc_constants
  END TYPE t_constants

  REAL                        :: warp_factor=1.0  !should be set from input later
  INTEGER,          PARAMETER :: oUnit = 50 !This is the unit number for the out file
  INTEGER,          PARAMETER :: noState_const = 0
  INTEGER,          PARAMETER :: coreState_const = 1
  INTEGER,          PARAMETER :: valenceState_const = 2
  INTEGER,          PARAMETER :: lmaxU_const = 3
  COMPLEX,          PARAMETER :: cmplx_0=(0.0,0.0)
  COMPLEX,          PARAMETER :: cmplx_1=(1.0,0.0)
  REAL,             PARAMETER :: pi_const=3.1415926535897932
  REAL,             PARAMETER :: tpi_const=2.*3.1415926535897932
  REAL,             PARAMETER :: fpi_const=4.*3.1415926535897932
  REAL,             PARAMETER :: sfp_const=SQRT(4.*3.1415926535897932)
  real,             parameter :: sqrt_2=sqrt(2.0)
  COMPLEX,          PARAMETER :: ImagUnit=(0.0,1.0)
  REAL,             PARAMETER :: hartree_to_ev_const=27.211386245988 ! value from  https://physics.nist.gov/cgi-bin/cuu/Value?hrev
                                                                     ! 27.211386245988(53)
  REAL,             PARAMETER :: bohr_to_angstrom_const=0.529177210903 ! value from https://physics.nist.gov/cgi-bin/cuu/Value?bohrrada0
                                                                       ! 0.529177210903(80)
  REAL,             PARAMETER :: eVac0Default_const = -0.25
  CHARACTER(len=9), PARAMETER :: version_const = 'fleur 37'
  CHARACTER(len=49), PARAMETER :: version_const_MaX = '     MaX-Release 6.2          (www.max-centre.eu)'
  CHARACTER(len=4), PARAMETER :: inputFileVersion_const = '0.37'
  ! outputFileVersion_const is defined in juDFT/xmlOutput.f90
  ! For version number update also update version numbers in files io/xml/FleurInputSchema.xsd, io/xml/FleurOutputSchema.xsd, fleurInput/types_xml, and update the files
  ! io/xml/inputSchema.h.backup, io/xml/outputSchema.h.backup, dropInputSchema.c, dropOutputSchema.c, inputSchema_old.h, outputSchema_old.h.
  REAL, PARAMETER             :: boltzmann_const = 3.1668114e-6 ! value is given in Hartree/Kelvin

  INTEGER, PARAMETER :: POTDEN_TYPE_OTHER        = 0    ! POTDEN_TYPE <= 0 ==> undefined
  INTEGER, PARAMETER :: POTDEN_TYPE_POTTOT       = 1    ! 0 < POTDEN_TYPE <= 1000 ==> potential
  INTEGER, PARAMETER :: POTDEN_TYPE_POTCOUL      = 2
  INTEGER, PARAMETER :: POTDEN_TYPE_POTX         = 3
  INTEGER, PARAMETER :: POTDEN_TYPE_POTYUK       = 4
  INTEGER, PARAMETER :: POTDEN_TYPE_EnergyDen    = 5
  INTEGER, PARAMETER :: POTDEN_TYPE_CRYSTALFIELD = 6
  INTEGER, PARAMETER :: POTDEN_TYPE_DEN          = 1001 ! 1000 < POTDEN_TYPE ==> density

  INTEGER, PARAMETER :: KPTS_KIND_UNSPECIFIED = 0
  INTEGER, PARAMETER :: KPTS_KIND_MESH        = 1
  INTEGER, PARAMETER :: KPTS_KIND_PATH        = 2
  INTEGER, PARAMETER :: KPTS_KIND_TRIA_BULK   = 3
  INTEGER, PARAMETER :: KPTS_KIND_TRIA        = 4
  INTEGER, PARAMETER :: KPTS_KIND_SPEX_MESH   = 5

  CHARACTER(LEN=11),DIMENSION(0:5),PARAMETER :: kptsKindString_consts = &
     (/'unspecified','mesh       ','path       ','tria-bulk  ','tria       ','SPEX mesh  ' /)

  INTEGER, PARAMETER :: BZINT_METHOD_HIST  = 0
  INTEGER, PARAMETER :: BZINT_METHOD_GAUSS = 1
  INTEGER, PARAMETER :: BZINT_METHOD_TRIA  = 2
  INTEGER, PARAMETER :: BZINT_METHOD_TETRA = 3

   ! 11 == plot not yet implemented
   INTEGER, PARAMETER :: PLOT_INPDEN=1
   INTEGER, PARAMETER :: PLOT_INPDEN_N_CORE=11
   INTEGER, PARAMETER :: PLOT_POT_TOT=2
   INTEGER, PARAMETER :: PLOT_POT_EXT=11
   INTEGER, PARAMETER :: PLOT_POT_COU=3
   INTEGER, PARAMETER :: PLOT_POT_VXC=4
   INTEGER, PARAMETER :: PLOT_OUTDEN_Y_CORE=5
   INTEGER, PARAMETER :: PLOT_MIXDEN_Y_CORE=6
   INTEGER, PARAMETER :: PLOT_MIXDEN_N_CORE=11

  CHARACTER(2),DIMENSION(0:103),PARAMETER :: namat_const=(/&
       'va',' H','He','Li','Be',' B',' C',' N',' O',' F','Ne',&
       'Na','Mg','Al','Si',' P',' S','Cl','Ar',' K','Ca','Sc','Ti',&
       ' V','Cr','Mn','Fe','Co','Ni','Cu','Zn','Ga','Ge','As','Se',&
       'Br','Kr','Rb','Sr',' Y','Zr','Nb','Mo','Tc','Ru','Rh','Pd',&
       'Ag','Cd','In','Sn','Sb','Te',' I','Xe','Cs','Ba','La','Ce',&
       'Pr','Nd','Pm','Sm','Eu','Gd','Tb','Dy','Ho','Er','Tm','Yb',&
       'Lu','Hf','Ta',' W','Re','Os','Ir','Pt','Au','Hg','Tl','Pb',&
       'Bi','Po','At','Rn','Fr','Ra','Ac','Th','Pa',' U','Np','Pu',&
       'Am','Cm','Bk','Cf','Es','Fm','Md','No','Lw'/)

  CHARACTER(7),DIMENSION(29),PARAMETER :: coreStateList_const=(/&
       '(1s1/2)','(2s1/2)','(2p1/2)','(2p3/2)','(3s1/2)',&
       '(3p1/2)','(3p3/2)','(4s1/2)','(3d3/2)','(3d5/2)',&
       '(4p1/2)','(4p3/2)','(5s1/2)','(4d3/2)','(4d5/2)',&
       '(5p1/2)','(5p3/2)','(6s1/2)','(4f5/2)','(4f7/2)',&
       '(5d3/2)','(5d5/2)','(6p1/2)','(6p3/2)','(7s1/2)',&
       '(5f5/2)','(5f7/2)','(6d3/2)','(6d5/2)' /)

  INTEGER,DIMENSION(29),PARAMETER :: coreStateNumElecsList_const=(/& ! This is the number of electrons per spin
       1, 1, 1, 2, 1, 1, 2, 1, 2, 3, 1, 2, 1, 2,&
       3, 1, 2, 1, 3, 4, 2, 3, 1, 2, 1, 3, 4, 2, 3/)

  INTEGER,DIMENSION(29),PARAMETER :: coreStateNprncList_const=(/&
       1, 2, 2, 2, 3, 3, 3, 4, 3, 3, 4, 4, 5, 4, 4,&
       5, 5, 6, 4, 4, 5, 5, 6, 6, 7, 5, 5, 6, 6/)
  INTEGER,DIMENSION(29),PARAMETER :: coreStateKappaList_const=(/&
       -1,-1, 1,-2,-1, 1,-2,-1, 2,-3, 1,-2,-1, 2,-3,&
       1,-2,-1, 3,-4, 2,-3, 1,-2,-1, 3,-4, 2,-3/)

  CHARACTER(4),DIMENSION(6),PARAMETER :: nobleGasConfigList_const=(/'[He]','[Ne]','[Ar]','[Kr]','[Xe]','[Rn]'/)

  INTEGER,DIMENSION(6),PARAMETER :: nobleGasNumStatesList_const=(/1, 4, 7, 12, 17, 24/)

  ! juPhon stuff:
  complex, dimension(3, 3), parameter  :: Tmatrix0 = reshape( &
                                              [(0.7071067811865475, 0.),(0.,-0.7071067811865475),(0., 0.),&
                                               (0., 0.),(0., 0.),(1., 0.), &
                                               (-0.7071067811865475,0.),(0.,-0.7071067811865475),(0., 0.)],[3,3])!< Klüppelberg PhD thesis 4.18
  complex, dimension(3, 3), parameter :: c_im =   reshape([ &
                                                (1.4472025091165353, 0.),(0., 1.4472025091165353),(0., 0.),&
                                                 (0., 0.), (0., 0.),(2.0466534158929770, 0.),&
                                                (-1.4472025091165353, 0.),(0., 1.4472025091165353),(0., 0.)&


                                              & ], [3, 3] )   !< Klüppelberg PhD thesis 4.28
  

  integer, parameter, dimension(3)    :: dirvecx = [1, 0, 0]
  integer, parameter, dimension(3)    :: dirvecy = [0, 1, 0]
  integer, parameter, dimension(3)    :: dirvecz = [0, 0, 1]
  integer, parameter, dimension(3, 3) :: id3x3   = reshape([dirvecx, dirvecy, dirvecz], [3, 3])

CONTAINS

  REAL PURE FUNCTION pimach()
    IMPLICIT NONE
    !  This subprogram supplies the value of the constant PI correct to
    !  machine precision where

    !  PI=3.1415926535897932384626433832795028841971693993751058209749446

    pimach = 3.1415926535897932
  END FUNCTION pimach

  REAL ELEMENTAL FUNCTION c_light(fac)
    IMPLICIT NONE
    !  This subprogram supplies the value of c according to
    !  NIST standard 13.1.99
    !  Hartree and Rydbergs changed by fac = 1.0 or 2.0

    REAL, INTENT (IN) :: fac
    c_light = 137.0359895e0 * fac * warp_factor
    !c_light = 1e6*fac
  END FUNCTION c_light

  SUBROUTINE  read_xml_constants(this,xml)
    USE m_types_xml
    CLASS(t_constants),INTENT(INout)::this
    TYPE(t_xml),INTENT(inout)   ::xml

    IF (xml%GetNumberOfNodes('/fleurInput/calculationSetup/expertModes/@warp_factor')==1)&
    warp_factor=evaluateFirstOnly(xml%GetAttributeValue('/fleurInput/calculationSetup/expertModes/@warp_factor'))
  END SUBROUTINE read_xml_constants
  SUBROUTINE mpi_bc_constants(this,mpi_comm,irank)
    USE m_mpi_bc_tool
    CLASS(t_constants),INTENT(INOUT)::this
    INTEGER,INTENT(IN):: mpi_comm
    INTEGER,INTENT(IN),OPTIONAL::irank
    INTEGER ::rank
    IF (PRESENT(irank)) THEN
       rank=irank
    ELSE
       rank=0
    END IF
    CALL mpi_bc(warp_factor,rank,mpi_comm)
  END SUBROUTINE mpi_bc_constants
END MODULE m_constants
