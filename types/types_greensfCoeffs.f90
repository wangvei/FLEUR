!--------------------------------------------------------------------------------
! Copyright (c) 2016 Peter Grünberg Institut, Forschungszentrum Jülich, Germany
! This file is part of FLEUR and available as free software under the conditions
! of the MIT license as expressed in the LICENSE file in more detail.
!--------------------------------------------------------------------------------

MODULE m_types_greensfCoeffs

   !------------------------------------------------------------------------------
   !
   ! MODULE: m_types_greensfCoeffs
   !
   !> @author
   !> Henning Janßen
   !
   ! DESCRIPTION:
   !>  Contains a type, which stores coefficients for the Green's function calculated
   !>  in the k-point loop in cdnval
   !>  Contains Arrays for the following cases:
   !>       -onsite
   !>           -spherically averaged/radial dependence (r=r')
   !>           -non-magnetic/collinear/noco
   !>       -intersite
   !>  Furthermore this module contains the information about the energy grid where
   !>  the imaginary part is calculated
   ! REVISION HISTORY:
   ! February 2019 - Initial Version
   !------------------------------------------------------------------------------

   USE m_juDFT
   USE m_types_setup
   USE m_constants

   IMPLICIT NONE

   PRIVATE

      TYPE t_greensfCoeffs

         !Energy grid for Imaginary part
         INTEGER  :: ne       !number of energy grid points for imaginary part calculations (REDUNDANT)
         REAL     :: e_top    !Cutoff energies
         REAL     :: e_bot
         REAL     :: del

         INTEGER, ALLOCATABLE :: kkintgr_cutoff(:,:,:)

         !Array declarations
         !If we look at the Green's function that only depends on Energy and not on spatial arguments
         !the imaginary part is equal to the proected density of states
         COMPLEX, ALLOCATABLE :: projdos(:,:,:,:,:,:)

         ! These arrays are only used in the case we want the green's function with radial dependence
         COMPLEX, ALLOCATABLE :: uu(:,:,:,:,:,:)
         COMPLEX, ALLOCATABLE :: dd(:,:,:,:,:,:)
         COMPLEX, ALLOCATABLE :: du(:,:,:,:,:,:)
         COMPLEX, ALLOCATABLE :: ud(:,:,:,:,:,:)

         CONTAINS
            PROCEDURE, PASS :: init    =>  greensfCoeffs_init
            PROCEDURE       :: eMesh   =>  getEnergyMesh
      END TYPE t_greensfCoeffs

   PUBLIC t_greensfCoeffs

   CONTAINS

      SUBROUTINE greensfCoeffs_init(thisGREENSFCOEFFS,input,lmax,atoms,noco,ef)

         CLASS(t_greensfCoeffs), INTENT(INOUT)  :: thisGREENSFCOEFFS
         TYPE(t_atoms),          INTENT(IN)     :: atoms
         TYPE(t_input),          INTENT(IN)     :: input
         INTEGER,                INTENT(IN)     :: lmax
         REAL,                   INTENT(IN)     :: ef
         TYPE(t_noco),           INTENT(IN)     :: noco

         INTEGER i,j,l_dim,spin_dim

         !Set up general parameters for the Green's function (intersite and onsite)
         !
         !Parameters for calculation of the imaginary part
         thisGREENSFCOEFFS%ne       = input%gf_ne
         !take the energyParameterLimits from inp.xml if they are set, otherwise use default values
         IF(input%gf_ellow.NE.0.0.OR.input%gf_elup.NE.0.0) THEN
            thisGREENSFCOEFFS%e_top    = ef+input%gf_elup
            thisGREENSFCOEFFS%e_bot    = ef+input%gf_ellow
         ELSE
            thisGREENSFCOEFFS%e_top    = input%elup
            thisGREENSFCOEFFS%e_bot    = input%ellow
         ENDIF

         !set up energy grid for imaginary part
         thisGREENSFCOEFFS%del = (thisGREENSFCOEFFS%e_top-thisGREENSFCOEFFS%e_bot)/REAL(thisGREENSFCOEFFS%ne-1)

         spin_dim = MERGE(3,input%jspins,input%l_gfmperp)

         IF(atoms%n_gf.GT.0) THEN
            ALLOCATE(thisGREENSFCOEFFS%kkintgr_cutoff(atoms%n_gf,input%jspins,2),source=0)
            ALLOCATE (thisGREENSFCOEFFS%projdos(thisGREENSFCOEFFS%ne,-lmax:lmax,-lmax:lmax,0:MAXVAL(atoms%neq),MAX(1,atoms%n_gf),spin_dim),source=cmplx_0)
            IF(.NOT.input%l_gfsphavg) THEN
               ALLOCATE (thisGREENSFCOEFFS%uu(thisGREENSFCOEFFS%ne,-lmax:lmax,-lmax:lmax,0:MAXVAL(atoms%neq),MAX(1,atoms%n_gf),spin_dim),source=cmplx_0)
               ALLOCATE (thisGREENSFCOEFFS%dd(thisGREENSFCOEFFS%ne,-lmax:lmax,-lmax:lmax,0:MAXVAL(atoms%neq),MAX(1,atoms%n_gf),spin_dim),source=cmplx_0)
               ALLOCATE (thisGREENSFCOEFFS%du(thisGREENSFCOEFFS%ne,-lmax:lmax,-lmax:lmax,0:MAXVAL(atoms%neq),MAX(1,atoms%n_gf),spin_dim),source=cmplx_0)
               ALLOCATE (thisGREENSFCOEFFS%ud(thisGREENSFCOEFFS%ne,-lmax:lmax,-lmax:lmax,0:MAXVAL(atoms%neq),MAX(1,atoms%n_gf),spin_dim),source=cmplx_0)
            ENDIF
         END IF

      END SUBROUTINE greensfCoeffs_init

      SUBROUTINE getEnergyMesh(this,ne,eMesh)
         
         CLASS(t_greensfCoeffs),    INTENT(IN)  :: this
         INTEGER,                   INTENT(OUT) :: ne
         REAL, ALLOCATABLE,         INTENT(OUT) :: eMesh(:)

         INTEGER :: ie

         ne = this%ne

         IF(ALLOCATED(eMesh)) DEALLOCATE(eMesh)
         ALLOCATE(eMesh(ne))

         DO ie = 1, ne
            eMesh(ie) = (ie-1)*this%del+this%e_bot
         ENDDO

      END SUBROUTINE getEnergyMesh


END MODULE m_types_greensfCoeffs