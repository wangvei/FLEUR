!--------------------------------------------------------------------------------
! Copyright (c) 2016 Peter Grünberg Institut, Forschungszentrum Jülich, Germany
! This file is part of FLEUR and available as free software under the conditions
! of the MIT license as expressed in the LICENSE file in more detail.
!--------------------------------------------------------------------------------

MODULE m_hs_int
CONTAINS
   !Subroutine to construct the interstitial Hamiltonian and overlap matrix
   SUBROUTINE hs_int(input, noco, nococonv, stars, lapw, fmpi, bbmat, isp, vpw, &
                   & smat, hmat)
      ! Control subroutine for the calculation of Hamiltonian/overlap matrix
      ! elements in the interstitial. The spin logic and case selections are
      ! found here while the actual calculation loop is one layer deeper in
      ! hs_int_direct.
      !
      ! <\Phi'|H/S|\Phi>
      !
      ! All primed indices are to be understood as corresponding to the Bra
      ! basis function, e.g. iSpinPr is the left and iSpin the right hand spin.

      USE m_types
      USE m_hs_int_direct

      IMPLICIT NONE

      TYPE(t_input),    INTENT(IN)    :: input
      TYPE(t_noco),     INTENT(IN)    :: noco
      TYPE(t_nococonv), INTENT(IN)    :: nococonv
      TYPE(t_stars),    INTENT(IN)    :: stars
      REAL,             INTENT(IN)    :: bbmat(3, 3)
      TYPE(t_lapw),     INTENT(IN)    :: lapw
      TYPE(t_mpi),      INTENT(IN)    :: fmpi
      INTEGER,          INTENT(IN)    :: isp
      COMPLEX,          INTENT(IN)    :: vpw(:,:)
      CLASS(t_mat),     INTENT(INOUT) :: smat(:,:),hmat(:,:)

      INTEGER :: iSpinPr, iSpin, igSpin, igSpinPr
      INTEGER :: iTkin, fact, iQss
      LOGICAL :: l_smat

      COMPLEX, ALLOCATABLE :: vpw_temp(:)

      ALLOCATE(vpw_temp(SIZE(vpw,1)))

      IF (noco%l_noco.AND.isp==2) RETURN !was done already

      DO iSpinPr=MERGE(1,isp,noco%l_noco),MERGE(2,isp,noco%l_noco)
         igSpinPr=MIN(iSpinPr,SIZE(smat,1))
         DO iSpin=MERGE(1,isp,noco%l_noco),MERGE(2,isp,noco%l_noco)
            igSpin=MIN(iSpin,SIZE(smat,1))
            IF (iSpinPr.EQ.1.AND.iSpin.EQ.2) THEN
               vpw_temp = conjg(vpw(:, 3))
               l_smat   = .FALSE. ! Offdiagonal part --> No step function part.
               iTkin    = 0       ! Offdiagonal part --> No T part.
               fact     = -1      ! (12)-element --> (-1) prefactor
               iQss     = 0       ! No spin-spiral considered (no T).
            ELSE IF (iSpinPr.EQ.2.AND.iSpin.EQ.1) THEN
               vpw_temp = vpw(:, 3)
               l_smat   = .FALSE.
               iTkin    = 0
               fact     = 1
               iQss     = 0
            ELSE
               vpw_temp = vpw(:, iSpin)
               l_smat   = .TRUE.
               IF (input%l_useapw) THEN
                  iTkin = 1 ! Dirac form.
                  iQss  = 0 ! No q-vector in kinetic energy.
               ELSE
                  iTkin = 2 ! Symmetrized Laplace form.
                  iQss  = 1 ! Additional q-vectors in kinetic energy.
               END IF
               fact     = 1
            END IF
            CALL hs_int_direct(fmpi, stars, bbmat, lapw%gvec(:,:,iSpinPr), lapw%gvec(:,:,iSpin), &
                             & lapw%bkpt+iQss*(2*iSpinPr - 3)/2.0*nococonv%qss+lapw%qphon, lapw%bkpt+iQss*(2*iSpin - 3)/2.0*nococonv%qss+lapw%qphon, &
                             & lapw%nv(iSpinPr), lapw%nv(iSpin), iTkin, fact, l_smat, .FALSE., vpw_temp, hmat(igSpinPr,igSpin), smat(igSpinPr,igSpin))
            END DO
      END DO
   END SUBROUTINE hs_int
END MODULE m_hs_int
