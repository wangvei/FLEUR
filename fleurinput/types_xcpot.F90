!--------------------------------------------------------------------------------
! Copyright (c) 2016 Peter Grünberg Institut, Forschungszentrum Jülich, Germany
! This file is part of FLEUR and available as free software under the conditions
! of the MIT license as expressed in the LICENSE file in more detail.
!--------------------------------------------------------------------------------
!> This module defines two data-types used in the calculation of xc-potentials
!! a) the abstract t_xcpot which should be overwritten for actual implementations
!! b) the t_gradients that collects the gradients needed in GGAs
!!
!! Currently t_xcpot_inbuild implements the XC-pots directly build into FLEUR
!! and t_xcpot_libxc provides and interface to libxc.
!! In addition to overloading the t_xcpot datatype also mpi_bc_xcpot must be adjusted
!! for additional implementations.
MODULE m_types_xcpot
   USE m_juDFT
   USE m_types_fleurinput_base
   IMPLICIT NONE
   PRIVATE
   PUBLIC :: t_xcpot, t_gradients
   TYPE t_gradients
      !Naming convention:
      !t,u,d as last letter for total,up,down
      !agr for absolute value of gradient
      !g2r for laplacien of gradient
      !+??
      REAL, ALLOCATABLE :: agrt(:), agru(:), agrd(:)
      REAL, ALLOCATABLE :: g2ru(:), g2rd(:), gggrt(:)
      REAL, ALLOCATABLE :: gggru(:), gzgr(:), g2rt(:)
      REAL, ALLOCATABLE :: gggrd(:), grgru(:), grgrd(:)
      !These are the contracted Gradients used in libxc
      REAL, ALLOCATABLE :: sigma(:, :)
      REAL, ALLOCATABLE :: vsigma(:, :)
      REAL, ALLOCATABLE :: gr(:, :, :)
      REAL, ALLOCATABLE :: laplace(:, :)
   END TYPE t_gradients

   TYPE, abstract, EXTENDS(t_fleurinput_base) :: t_xcpot
      REAL :: gmaxxc=0.0
      !Data for libxc
      LOGICAL                  :: l_libxc = .FALSE.
      INTEGER                  :: func_vxc_id_c, func_vxc_id_x !> functionals to be used for potential & density convergence
      INTEGER                  :: func_exc_id_c, func_exc_id_x !> functionals to be used in exc- & totale-calculations
      !For inbuild

      LOGICAL          :: l_inbuild = .FALSE.
      CHARACTER(len=10):: inbuild_name = "vwn"
      LOGICAL          :: l_relativistic = .FALSE.

   CONTAINS

      PROCEDURE        :: vxc_is_LDA => xcpot_vxc_is_LDA
      PROCEDURE        :: vxc_is_GGA => xcpot_vxc_is_GGA

      PROCEDURE        :: vx_is_LDA => xcpot_vx_is_LDA
      PROCEDURE        :: vx_is_GGA => xcpot_vx_is_GGA
      PROCEDURE        :: vx_is_MetaGGA => xcpot_vx_is_MetaGGA

      PROCEDURE(vc_is_LDA_abstract), DEFERRED :: vc_is_LDA
      PROCEDURE        :: vc_is_GGA => xcpot_vc_is_GGA

      PROCEDURE        :: exc_is_LDA => xcpot_exc_is_LDA
      PROCEDURE        :: exc_is_GGA => xcpot_exc_is_GGA
      PROCEDURE        :: exc_is_MetaGGA => xcpot_exc_is_MetaGGA

      PROCEDURE        :: needs_grad => xcpot_needs_grad
      PROCEDURE(is_hybrid_abstract), DEFERRED :: is_hybrid

      PROCEDURE        :: get_exchange_weight => xcpot_get_exchange_weight
      PROCEDURE        :: get_vxc => xcpot_get_vxc
      PROCEDURE        :: get_exc => xcpot_get_exc
      PROCEDURE        :: get_fxc => xcpot_get_fxc
      PROCEDURE,NOPASS :: apply_cutoffs

      PROCEDURE, NOPASS :: alloc_gradients => xcpot_alloc_gradients
      PROCEDURE        :: read_xml => read_xml_xcpot
      PROCEDURE        :: mpi_bc => mpi_bc_xcpot_abstract
   END TYPE t_xcpot

   INTERFACE
      LOGICAL FUNCTION is_hybrid_abstract(xcpot)
         IMPORT t_xcpot
         CLASS(t_xcpot), INTENT(IN):: xcpot
      END FUNCTION is_hybrid_abstract
   END INTERFACE

   INTERFACE
      LOGICAL FUNCTION vc_is_LDA_abstract(xcpot)
         IMPORT t_xcpot
         CLASS(t_xcpot), INTENT(IN):: xcpot
      END FUNCTION vc_is_LDA_abstract
   END INTERFACE


CONTAINS

  subroutine mpi_bc_xcpot_abstract(This, Mpi_comm, Irank)
    Use M_mpi_bc_tool
    class(t_xcpot), intent(inout)::This
    integer, intent(in):: Mpi_comm
    integer, intent(in), Optional::Irank
    INTEGER :: rank

    rank = 0
    IF(PRESENT(Irank)) rank = Irank
    ! Bcasts for abstract base class t_xcpot
    CALL mpi_bc(this%l_libxc, rank, mpi_comm)
    CALL mpi_bc(this%func_vxc_id_c, rank, mpi_comm)
    CALL mpi_bc(this%func_vxc_id_x, rank, mpi_comm)
    CALL mpi_bc(this%func_exc_id_c, rank, mpi_comm)
    CALL mpi_bc(this%func_exc_id_x, rank, mpi_comm)
    CALL mpi_bc(this%l_inbuild, rank, mpi_comm)
    CALL mpi_bc(rank, mpi_comm, this%inbuild_name)
    CALL mpi_bc(this%l_relativistic, rank, mpi_comm)
  end subroutine mpi_bc_xcpot_abstract


  subroutine apply_cutoffs(density_cutoff,rh,grad)
    real,intent(INOUT) :: rh(:,:)
    real,INTENT(IN)    :: density_cutoff
    type(t_gradients),INTENT(INOUT),OPTIONAL :: grad

    !Do nothing here, only in libxc case
  end subroutine

   SUBROUTINE read_xml_xcpot(this, xml)
      USE m_types_xml
#ifdef CPP_LIBXC
      USE xc_f90_lib_m
#endif
      CLASS(t_xcpot), INTENT(INOUT):: this
      TYPE(t_xml), INTENT(INOUT)    ::xml

      CHARACTER(len=:), allocatable ::xpathA, xpathB, valueString
      CHARACTER(LEN=50) :: xPathC
      INTEGER          :: jspins
      LOGICAL          :: l_libxc_names
      l_libxc_names = .FALSE.
      this%gmaxxc = evaluateFirstOnly(xml%GetAttributeValue('/fleurInput/calculationSetup/cutoffs/@GmaxXC'))

      xPathC = ''
      IF (xml%GetNumberOfNodes('/fleurInput/calculationSetup/xcFunctional') > 0) THEN
         xPathC = '/fleurInput/calculationSetup/xcFunctional'
      ELSE
         xPathC = '/fleurInput/xcFunctional'
      END IF

      IF (xml%GetNumberOfNodes(TRIM(ADJUSTL(xPathC))//'/@name') == 1) THEN
         this%l_inbuild = .TRUE.
         this%inbuild_name = TRIM(ADJUSTL(xml%GetAttributeValue(TRIM(ADJUSTL(xPathC))//'/@name')))
         this%l_relativistic = evaluateFirstBoolOnly(xml%GetAttributeValue(TRIM(ADJUSTL(xPathC))//'/@relativisticCorrections'))
      ENDIF

      if(this%inbuild_name == "LibXC" ) then
         this%l_inbuild = .False.
         this%l_libxc = .True.
      endif

      !Input for libxc
      ! Read in xc functional parameters
      !Read in libxc parameters if present
      xPathA = trim(xpathC)//'/LibXCID'
      xPathB = trim(xpathC)//'/LibXCName'

      if(xml%GetNumberOfNodes(xPathA) == 1 .and. xml%GetNumberOfNodes(xPathB) == 1) then
         CALL judft_error("You specified libxc by name and id, please choose only one option")
      endif

      ! LibXCID
      IF (xml%GetNumberOfNodes(xPathA) == 1) THEN
         this%l_libxc = .TRUE.
         this%func_vxc_id_x = evaluateFirstOnly(xml%GetAttributeValue(xPathA//'/@exchange'))
         this%func_vxc_id_c = evaluateFirstOnly(xml%GetAttributeValue(xPathA//'/@correlation'))
         IF (xml%GetNumberOfNodes(xPathA//'/@etot_exchange') == 1) THEN
            this%func_exc_id_x = evaluateFirstOnly(xml%GetAttributeValue(xPathA//'/@etot_exchange'))
         ELSE
            this%func_exc_id_x = this%func_vxc_id_x
         ENDIF

         IF (xml%GetNumberOfNodes(xPathA//'/@etot_correlation') == 1) THEN
            this%func_exc_id_c = evaluateFirstOnly(xml%GetAttributeValue(xPathA//'/@etot_correlation'))
         ELSE
            this%func_exc_id_c = this%func_vxc_id_c
         ENDIF
         ! LibXCName
      ELSEIF (xml%GetNumberOfNodes(xPathB) == 1) THEN
         l_libxc_names = .TRUE.
#ifdef CPP_LIBXC
         valueString = xml%GetAttributeValue(xPathB //'/@exchange')
         this%func_vxc_id_x = xc_f90_functional_get_number(valueString)

         valueString = TRIM(ADJUSTL(xml%GetAttributeValue(xPathB//'/@correlation')))
         this%func_vxc_id_c = xc_f90_functional_get_number(valueString)

         IF (xml%GetNumberOfNodes(xPathB//'/@etot_exchange') == 1) THEN
            valueString = TRIM(ADJUSTL(xml%GetAttributeValue(xPathB//'/@etot_exchange')))
            this%func_exc_id_x = xc_f90_functional_get_number(valueString)
         ELSE
            this%func_exc_id_x = this%func_vxc_id_x
         ENDIF

         IF (xml%GetNumberOfNodes(xPathB//'/@etot_correlation') == 1) THEN
            valueString = TRIM(ADJUSTL(xml%GetAttributeValue(xPathB//'/@etot_correlation')))
            this%func_exc_id_c = xc_f90_functional_get_number(valueString)
         ELSE
            this%func_exc_id_c = this%func_vxc_id_c
         ENDIF
#else
         CALL judft_error("To use libxc functionals you have to compile with libXC support")
#endif
      else
         if(this%l_libxc) call judft_error("LibXC functional not specified", &
            hint='add something like <xcFunctional name="LibXC" relativisticCorrections="F"><LibXCName exchange="gga_x_pbe" correlation="gga_c_pbe"/></xcFunctional>')
      ENDIF

      IF (this%l_inbuild .AND. this%l_libxc) CALL judft_error("You specified libxc and an inbuild xc-pot, please choose only one option")
      IF (.NOT. (this%l_inbuild .OR. this%l_libxc)) CALL judft_error("You specified no xc-pot")

   END SUBROUTINE read_xml_xcpot

   ! LDA
   LOGICAL FUNCTION xcpot_vx_is_LDA(xcpot)
      IMPLICIT NONE
      CLASS(t_xcpot), INTENT(IN):: xcpot
      xcpot_vx_is_LDA = .FALSE.
   END FUNCTION xcpot_vx_is_LDA

   LOGICAL FUNCTION xcpot_vxc_is_LDA(xcpot)
      IMPLICIT NONE
      CLASS(t_xcpot), INTENT(IN):: xcpot
      xcpot_vxc_is_LDA = xcpot%vx_is_LDA() .AND. xcpot%vc_is_LDA()
   END FUNCTION xcpot_vxc_is_LDA

   LOGICAL FUNCTION xcpot_exc_is_LDA(xcpot)
      IMPLICIT NONE
      CLASS(t_xcpot), INTENT(IN):: xcpot
      xcpot_exc_is_LDA = .FALSE.
   END FUNCTION xcpot_exc_is_LDA

   ! GGA
   LOGICAL FUNCTION xcpot_vc_is_GGA(xcpot)
      IMPLICIT NONE
      CLASS(t_xcpot), INTENT(IN):: xcpot
      xcpot_vc_is_GGA = .FALSE.
   END FUNCTION xcpot_vc_is_GGA

   LOGICAL FUNCTION xcpot_vx_is_GGA(xcpot)
      IMPLICIT NONE
      CLASS(t_xcpot), INTENT(IN):: xcpot
      xcpot_vx_is_GGA = .FALSE.
   END FUNCTION xcpot_vx_is_GGA

   LOGICAL FUNCTION xcpot_vxc_is_gga(xcpot)
      IMPLICIT NONE
      CLASS(t_xcpot), INTENT(IN):: xcpot
      xcpot_vxc_is_gga = xcpot%vx_is_GGA() .AND. xcpot%vc_is_GGA()
   END FUNCTION xcpot_vxc_is_gga

   LOGICAL FUNCTION xcpot_exc_is_gga(xcpot)
      IMPLICIT NONE
      CLASS(t_xcpot), INTENT(IN):: xcpot
      xcpot_exc_is_gga = .FALSE.
   END FUNCTION xcpot_exc_is_gga

   LOGICAL FUNCTION xcpot_vx_is_MetaGGA(xcpot)
      IMPLICIT NONE
      CLASS(t_xcpot), INTENT(IN):: xcpot
      xcpot_vx_is_MetaGGA = .FALSE.
   END FUNCTION xcpot_vx_is_MetaGGA

   LOGICAL FUNCTION xcpot_exc_is_MetaGGA(xcpot)
      IMPLICIT NONE
      CLASS(t_xcpot), INTENT(IN):: xcpot
      xcpot_exc_is_MetaGGA = .FALSE.
   END FUNCTION xcpot_exc_is_MetaGGA

   LOGICAL FUNCTION xcpot_needs_grad(xcpot)
      IMPLICIT NONE
      CLASS(t_xcpot), INTENT(IN):: xcpot

      xcpot_needs_grad = xcpot%vc_is_gga()
   END FUNCTION xcpot_needs_grad

   FUNCTION xcpot_get_exchange_weight(xcpot) RESULT(a_ex)
      USE m_judft
      IMPLICIT NONE
      CLASS(t_xcpot), INTENT(IN):: xcpot
      REAL:: a_ex
      a_ex = -1
   END FUNCTION xcpot_get_exchange_weight

   SUBROUTINE xcpot_get_vxc(xcpot, jspins, rh, vxc, vx, grad,kinEnergyDen_KS)
      USE m_judft
      IMPLICIT NONE

      CLASS(t_xcpot), INTENT(IN) :: xcpot
      INTEGER, INTENT(IN)     :: jspins
      !--> charge density
      REAL, INTENT(IN)         :: rh(:, :)
      !---> xc potential
      REAL, INTENT(OUT)       :: vxc(:, :), vx(:, :)
      TYPE(t_gradients), OPTIONAL, INTENT(INOUT)::grad
      REAL, INTENT(IN), OPTIONAL            :: kinEnergyDen_KS(:, :)
      vxc = 0.0
      vx = 0.0
      CALL juDFT_error("Can't use XC-parrent class")
   END SUBROUTINE xcpot_get_vxc

   SUBROUTINE xcpot_get_exc(xcpot, jspins, rh, exc, grad, kinEnergyDen_KS, mt_call)
      !USE m_types_misc
      USE m_judft
      USE, INTRINSIC :: IEEE_ARITHMETIC
      IMPLICIT NONE

      CLASS(t_xcpot), INTENT(IN)             :: xcpot
      INTEGER, INTENT(IN)                  :: jspins
      !--> charge density
      REAL, INTENT(IN)                      :: rh(:, :)
      !--> kinetic energy density
      !---> xc energy density
      REAL, INTENT(OUT)                    :: exc(:)
      TYPE(t_gradients), OPTIONAL, INTENT(IN) :: grad
      LOGICAL, OPTIONAL, INTENT(IN)         :: mt_call
      REAL, INTENT(IN), OPTIONAL            :: kinEnergyDen_KS(:, :)

      exc = 0.0
      CALL juDFT_error("Can't use XC-parrent class")
   END SUBROUTINE xcpot_get_exc

   SUBROUTINE xcpot_get_fxc(xcpot, jspins, rh, fxc)
      USE m_judft
      IMPLICIT NONE

      CLASS(t_xcpot), INTENT(IN) :: xcpot
      INTEGER, INTENT(IN)     :: jspins
      !--> charge density
      REAL, INTENT(IN)         :: rh(:, :)
      !---> xc potential
      REAL, INTENT(OUT)       :: fxc(:, :)
      fxc = 0.0
      CALL juDFT_error("Can't use XC-parrent class")
  END SUBROUTINE xcpot_get_fxc

   SUBROUTINE xcpot_alloc_gradients(ngrid, jspins, grad)
      IMPLICIT NONE

      INTEGER, INTENT(IN)         :: jspins, ngrid
      TYPE(t_gradients), INTENT(INOUT):: grad

      IF (ALLOCATED(grad%agrt)) THEN
         DEALLOCATE (grad%agrt, grad%agru, grad%agrd)
         DEALLOCATE (grad%g2ru, grad%g2rd, grad%gggrt)
         DEALLOCATE (grad%gggru, grad%gzgr, grad%g2rt)
         DEALLOCATE (grad%gggrd, grad%grgru, grad%grgrd)
      ENDIF
      !For the in-build xc-pots
      ALLOCATE (grad%agrt(ngrid), grad%agru(ngrid), grad%agrd(ngrid))
      ALLOCATE (grad%g2ru(ngrid), grad%g2rd(ngrid), grad%gggrt(ngrid))
      ALLOCATE (grad%gggru(ngrid), grad%gzgr(ngrid), grad%g2rt(ngrid))
      ALLOCATE (grad%gggrd(ngrid), grad%grgru(ngrid), grad%grgrd(ngrid))
   END SUBROUTINE xcpot_alloc_gradients

END MODULE m_types_xcpot
