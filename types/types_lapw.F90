!--------------------------------------------------------------------------------
! Copyright (c) 2016 Peter Grünberg Institut, Forschungszentrum Jülich, Germany
! This file is part of FLEUR and available as free software under the conditions
! of the MIT license as expressed in the LICENSE file in more detail.
!--------------------------------------------------------------------------------

MODULE m_types_lapw
   USE m_judft
   use m_types_fleurinput
   use m_types_nococonv
   IMPLICIT NONE
   PRIVATE
   !These dimensions should be set once per call of FLEUR
   !They can be queried by the functions lapw%dim_nvd,...
   !You probably should avoid using the variables directly
   integer, save :: lapw_dim_nvd
   integer, save :: lapw_dim_nv2d
   integer, save :: lapw_dim_nbasfcn

   TYPE t_lapw
      INTEGER :: nv(2)
      INTEGER :: num_local_cols(2)
      INTEGER :: nv_tot
      INTEGER :: nmat
      INTEGER :: nlotot
      INTEGER, ALLOCATABLE:: k1(:, :)
      INTEGER, ALLOCATABLE:: k2(:, :)
      INTEGER, ALLOCATABLE:: k3(:, :)
      INTEGER, ALLOCATABLE:: gvec(:, :, :) !replaces k1,k2,k3
      INTEGER, ALLOCATABLE:: kp(:, :)
      REAL, ALLOCATABLE::rk(:, :)
      REAL, ALLOCATABLE::gk(:, :, :)
      REAL, ALLOCATABLE::vk(:, :, :)
      INTEGER, ALLOCATABLE::index_lo(:, :)
      INTEGER, ALLOCATABLE::kvec(:, :, :)
      INTEGER, ALLOCATABLE::nkvec(:, :)
      REAL   :: bkpt(3)
      REAL   :: qphon(3)
   CONTAINS
      procedure       :: lapw_init => t_lapw_init
      procedure       :: lapw_init_fi => t_lapw_init_fi
      GENERIC         :: init => lapw_init, lapw_init_fi
      PROCEDURE, PASS :: alloc => lapw_alloc
      PROCEDURE, PASS :: phase_factors => lapw_phase_factors
      procedure, pass :: hyb_num_bas_fun => hyb_num_bas_fun
      PROCEDURE, NOPASS:: dim_nvd
      PROCEDURE, NOPASS:: dim_nv2d
      PROCEDURE, NOPASS:: dim_nbasfcn
      PROCEDURE, NOPASS:: init_dim => lapw_init_dim
   END TYPE t_lapw
   PUBLIC :: t_lapw, lapw_dim_nbasfcn, lapw_dim_nvd, lapw_dim_nv2d

CONTAINS
   function hyb_num_bas_fun(lapw, fi) result(nbasfcn)
      implicit NONE
      class(t_lapw), intent(in)         :: lapw
      type(t_fleurinput), intent(in)    :: fi

      integer :: nbasfcn
      if (fi%noco%l_noco) then
         nbasfcn = lapw%nv(1) + lapw%nv(2) + 2*fi%atoms%nlotot
      else
         nbasfcn = lapw%nv(1) + fi%atoms%nlotot
      endif
   end function hyb_num_bas_fun

   subroutine lapw_init_dim(nvd_in, nv2d_in, nbasfcn_in)
      IMPLICIT NONE
      INTEGER, INTENT(IN)      :: nvd_in, nv2d_in, nbasfcn_in
      lapw_dim_nvd = nvd_in
      lapw_dim_nv2d = nv2d_in
      lapw_dim_nbasfcn = nbasfcn_in
   end subroutine

   PURE INTEGER function dim_nvd()
      dim_nvd = lapw_dim_nvd
   end function
   PURE INTEGER function dim_nv2d()
      dim_nv2d = lapw_dim_nv2d
   end function
   PURE INTEGER function dim_nbasfcn()
      dim_nbasfcn = lapw_dim_nbasfcn
   end function

   SUBROUTINE lapw_alloc(lapw, cell, input, noco, nococonv)
      !
      !*********************************************************************
      !     determines dimensions of the lapw basis set with |k+G|<rkmax.
      !     bkpt is the k-point given in internal units
      !*********************************************************************
      USE m_boxdim
      USE m_types_fleurinput
      USE m_types_nococonv
      IMPLICIT NONE
      TYPE(t_cell), INTENT(IN)      :: cell
      TYPE(t_input), INTENT(IN)     :: input
      TYPE(t_noco), INTENT(IN)      :: noco
      TYPE(t_nococonv), INTENT(IN)  :: nococonv
      CLASS(t_lapw), INTENT(INOUT)  :: lapw

      INTEGER j1, j2, j3, mk1, mk2, mk3, nv, addX, addY, addZ
      INTEGER ispin, nvh(2)

      REAL arltv1, arltv2, arltv3, rkm, rk2, r2, s(3), sonlyg(3)
      ! ..
      !
      !------->          ABBREVIATIONS
      !

      !   rkmax       : cut-off for |g+k|
      !   arltv(i)    : length of reciprical lattice vector along
      !                 direction (i)
      !
      !---> Determine rkmax box of size mk1, mk2, mk3,
      !     for which |G(mk1,mk2,mk3) + (k1,k2,k3)| < rkmax
      !
      CALL boxdim(cell%bmat, arltv1, arltv2, arltv3)

      !     (add 1+1 due to integer rounding, strange k_vector in BZ)
      mk1 = int(input%rkmax/arltv1) + 2
      mk2 = int(input%rkmax/arltv2) + 2
      mk3 = int(input%rkmax/arltv3) + 2

      rkm = input%rkmax
      rk2 = rkm*rkm
      !---> obtain vectors
      !---> in a spin-spiral calculation different basis sets are used for
      !---> the two spin directions, because the cutoff radius is defined
      !---> by |G + k +/- qss/2| < rkmax.
      nvh(2) = 0
      DO ispin = 1, MERGE(2, 1, noco%l_ss)
         addX = abs(NINT((lapw%bkpt(1) + (2*ispin - 3)/2.0*nococonv%qss(1)+lapw%qphon(1))/arltv1))
         addY = abs(NINT((lapw%bkpt(2) + (2*ispin - 3)/2.0*nococonv%qss(2)+lapw%qPhon(2))/arltv2))
         addZ = abs(NINT((lapw%bkpt(3) + (2*ispin - 3)/2.0*nococonv%qss(3)+lapw%qphon(3))/arltv3))
         nv = 0
         DO j1 = -mk1 - addX, mk1 + addX
            DO j2 = -mk2 - addY, mk2 + addY
               DO j3 = -mk3 - addZ, mk3 + addZ
                  s = lapw%bkpt + (/j1, j2, j3/) + (2*ispin - 3)/2.0*nococonv%qss + lapw%qphon
                  sonlyg = (/j1, j2, j3/)
                  r2 = dot_PRODUCT(MATMUL(s, cell%bbmat), s)
                  !r2 = dot_PRODUCT(MATMUL(sonlyg, cell%bbmat), sonlyg)
                  IF (r2 .LE. rk2) nv = nv + 1
               END DO
            END DO
         END DO
         nvh(ispin) = nv
      END DO
      nv = MAX(nvh(1), nvh(2))

      IF (ALLOCATED(lapw%rk)) THEN
         IF (SIZE(lapw%rk) == nv) THEN
            RETURN !
         ELSE
            DEALLOCATE (lapw%rk, lapw%gvec, lapw%vk, lapw%gk)
            DEALLOCATE (lapw%k1, lapw%k2, lapw%k3)
         ENDIF
      ENDIF
      ALLOCATE (lapw%k1(nv, input%jspins)) !should be removed
      ALLOCATE (lapw%k2(nv, input%jspins)) !
      ALLOCATE (lapw%k3(nv, input%jspins)) !
      ALLOCATE (lapw%rk(nv, input%jspins))
      ALLOCATE (lapw%gvec(3, nv, input%jspins))
      ALLOCATE (lapw%vk(3, nv, input%jspins))
      ALLOCATE (lapw%gk(3, nv, input%jspins))
     
      lapw%rk = 0; lapw%gvec = 0; lapw%nv = 0
   END SUBROUTINE lapw_alloc

   subroutine t_lapw_init_fi(lapw, fi, nococonv, nk, mpi, dfpt_q) 
      USE m_types_mpi
      use m_types_fleurinput
      implicit none 
      CLASS(t_lapw), INTENT(INOUT)    :: lapw
      type(t_fleurinput), intent(in)  :: fi
      TYPE(t_nococonv), INTENT(IN)    :: nococonv
      INTEGER, INTENT(IN) :: nk
      TYPE(t_mpi), INTENT(IN), OPTIONAL:: mpi
      REAL, INTENT(IN), OPTIONAL :: dfpt_q(3)

      IF (PRESENT(mpi)) THEN
         IF (PRESENT(dfpt_q)) THEN
            call lapw%lapw_init(fi%input, fi%noco, nococonv, fi%kpts, fi%atoms, fi%sym, nk, fi%cell, mpi, dfpt_q)
         ELSE
            call lapw%lapw_init(fi%input, fi%noco, nococonv, fi%kpts, fi%atoms, fi%sym, nk, fi%cell, mpi)
         END IF
      ELSE
         IF (PRESENT(dfpt_q)) THEN
            call lapw%lapw_init(fi%input, fi%noco, nococonv, fi%kpts, fi%atoms, fi%sym, nk, fi%cell, dfpt_q=dfpt_q)
         ELSE
            call lapw%lapw_init(fi%input, fi%noco, nococonv, fi%kpts, fi%atoms, fi%sym, nk, fi%cell)
         END IF
      END IF  
   end subroutine t_lapw_init_fi

   SUBROUTINE t_lapw_init(lapw, input, noco, nococonv, kpts, atoms, sym, &
                        nk, cell,  mpi, dfpt_q)
      USE m_types_mpi
      USE m_sort
      USE m_boxdim
      USE m_types_fleurinput
      USE m_types_kpts
      USE m_types_nococonv
      IMPLICIT NONE


      TYPE(t_input), INTENT(IN)       :: input
      TYPE(t_noco), INTENT(IN)        :: noco
      TYPE(t_nococonv), INTENT(IN)    :: nococonv
      TYPE(t_cell), INTENT(IN)        :: cell
      TYPE(t_atoms), INTENT(IN)       :: atoms
      TYPE(t_sym), INTENT(IN)         :: sym
      TYPE(t_kpts), INTENT(IN)        :: kpts
      TYPE(t_mpi), INTENT(IN), OPTIONAL:: mpi
      CLASS(t_lapw), INTENT(INOUT)    :: lapw

      REAL, INTENT(IN), OPTIONAL :: dfpt_q(3)
      !     ..
      !     .. Scalar Arguments ..
      INTEGER, INTENT(IN) :: nk
      !LOGICAL, INTENT(IN)  :: l_zref
      !     ..
      !     .. Array Arguments ..
      !     ..
      !     .. Local Scalars ..
      REAL arltv1, arltv2, arltv3, r2, rk2, rkm, r2q, gla, eps, t, r2g, r2phon
      INTEGER i, j, j1, j2, j3, k, l, mk1, mk2, mk3, n, ispin, gmi, m, nred, n_inner, n_bound, itt(3), addX, addY, addZ
      !     ..
      !     .. Local Arrays ..
      REAL                :: s(3), sq(3), sg(3), qphon(3), sphon(3)
      REAL, ALLOCATABLE    :: rk(:), rkq(:), rkqq(:), rg(:)
      INTEGER, ALLOCATABLE :: gvec(:, :), index3(:)

      call timestart("t_lapw_init")
      !     ..
      !---> in a spin-spiral calculation different basis sets are used for
      !---> the two spin directions, because the cutoff radius is defined
      !---> by |G + k +/- qss/2| < rkmax.

      lapw%qphon = [0.0,0.0,0.0]
      IF (PRESENT(dfpt_q)) lapw%qphon = dfpt_q
      
      IF (nk > kpts%nkpt) THEN
         lapw%bkpt(:) = kpts%bkf(:, nk)
      ELSE
         lapw%bkpt(:) = kpts%bk(:, nk)
      ENDIF

      CALL lapw%alloc(cell, input, noco, nococonv)

      ALLOCATE (gvec(3, SIZE(lapw%gvec, 2)))
      ALLOCATE (rk(SIZE(lapw%gvec, 2)), rkq(SIZE(lapw%gvec, 2)), rkqq(SIZE(lapw%gvec, 2)))
      ALLOCATE (rg(SIZE(lapw%gvec, 2)))
      ALLOCATE (index3(SIZE(lapw%gvec, 2)))

      !---> Determine rkmax box of size mk1, mk2, mk3,
      !     for which |G(mk1,mk2,mk3) + (k1,k2,k3)| < rkmax
      !     arltv(i) length of reciprical lattice vector along direction (i)
      !
      CALL boxdim(cell%bmat, arltv1, arltv2, arltv3)

      !     (add 1+1 due to integer rounding, strange k_vector in BZ)
      mk1 = int(input%rkmax/arltv1) + 4
      mk2 = int(input%rkmax/arltv2) + 4
      mk3 = int(input%rkmax/arltv3) + 4

      rk2 = input%rkmax*input%rkmax
      !---> if too many basis functions, reduce rkmax
      spinloop: DO ispin = 1, input%jspins
         addX = abs(NINT((lapw%bkpt(1) + (2*ispin - 3)/2.0*nococonv%qss(1)+lapw%qphon(1))/arltv1))
         addY = abs(NINT((lapw%bkpt(2) + (2*ispin - 3)/2.0*nococonv%qss(2)+lapw%qphon(2))/arltv2))
         addZ = abs(NINT((lapw%bkpt(3) + (2*ispin - 3)/2.0*nococonv%qss(3)+lapw%qphon(3))/arltv3))
         !--->    obtain vectors
         n = 0
         DO j1 = -mk1 - addX, mk1 + addX
            DO j2 = -mk2 - addY, mk2 + addY
               DO j3 = -mk3 - addZ, mk3 + addZ
                  s = lapw%bkpt + (/j1, j2, j3/) + (2*ispin - 3)/2.0*nococonv%qss + lapw%qphon
                  sq = lapw%bkpt + (/j1, j2, j3/)
                  sg = (/j1, j2, j3/)
                  r2 = dot_PRODUCT(s, MATMUL(s, cell%bbmat))
                  r2q = dot_PRODUCT(sq, MATMUL(sq, cell%bbmat))
                  r2g = dot_PRODUCT(sg, MATMUL(sg, cell%bbmat))
                  IF (r2 .LE. rk2) THEN
                  !IF (r2g .LE. rk2) THEN
                     n = n + 1
                     gvec(:, n) = (/j1, j2, j3/)
                     rk(n) = SQRT(r2)
                     rkq(n) = SQRT(r2q)
                     rg(n) = SQRT(r2g)
                  END IF
               ENDDO
            ENDDO
         ENDDO
         lapw%nv(ispin) = n

         !Sort according to k+g, first construct secondary sort key
         DO k = 1, lapw%nv(ispin)
            rkqq(k) = (mk1 + gvec(1, k)) + (mk2 + gvec(2, k))*(2*mk1 + 1) + &
                      (mk3 + gvec(3, k))*(2*mk1 + 1)*(2*mk2 + 1)
         ENDDO
         CALL sort(index3(:lapw%nv(ispin)), rkq, rkqq)
         !CALL sort(index3(:lapw%nv(ispin)), rg, rkqq)
         DO n = 1, lapw%nv(ispin)
            lapw%gvec(:, n, ispin) = gvec(:, index3(n))
            lapw%rk(n, ispin) = rk(index3(n))
         ENDDO
         !--->    determine pairs of K-vectors, where K_z = K'_-z to use
         !--->    z-reflection
         DO k = 1, lapw%nv(ispin)
            lapw%vk(:, k, ispin) = lapw%bkpt + lapw%gvec(:, k, ispin) + (ispin - 1.5)*nococonv%qss + lapw%qphon
            lapw%gk(:, k, ispin) = MATMUL(TRANSPOSE(cell%bmat), lapw%vk(:, k, ispin))/MAX(lapw%rk(k, ispin), 1.0e-30)
         ENDDO

         IF (.NOT. noco%l_ss .AND. input%jspins == 2) THEN
            !Second spin is the same
            lapw%nv(2) = lapw%nv(1)
            lapw%gvec(:, :, 2) = lapw%gvec(:, :, 1)
            lapw%rk(:, 2) = lapw%rk(:, 1)
            lapw%vk(:, :, 2) = lapw%vk(:, :, 1)
            lapw%gk(:, :, 2) = lapw%gk(:, :, 1)
            EXIT spinloop
         END IF

      ENDDO spinloop
      !should be removed later...
      lapw%k1 = lapw%gvec(1, :, :)
      lapw%k2 = lapw%gvec(2, :, :)
      lapw%k3 = lapw%gvec(3, :, :)

      !Count No of lapw distributed to this PE
      lapw%num_local_cols = 0
      DO ispin = 1, input%jspins
         IF (PRESENT(mpi)) THEN
            DO k = mpi%n_rank + 1, lapw%nv(ispin), mpi%n_size
               lapw%num_local_cols(ispin) = lapw%num_local_cols(ispin) + 1
            END DO
         ELSE
            lapw%num_local_cols(ispin) = lapw%nv(ispin)
         END IF
      END DO

      IF (ANY(atoms%nlo > 0)) CALL priv_lo_basis_setup(lapw, atoms, input, sym, noco, nococonv, cell)

      lapw%nv_tot = lapw%nv(1)
      lapw%nmat = lapw%nv(1) + atoms%nlotot
      IF (noco%l_noco) lapw%nv_tot = lapw%nv_tot + lapw%nv(2)
      IF (noco%l_noco) lapw%nmat = lapw%nv_tot + 2*atoms%nlotot


      call timestop("t_lapw_init")
   CONTAINS

      SUBROUTINE priv_lo_basis_setup(lapw, atoms, input, sym, noco, nococonv, cell)
         USE m_types_fleurinput

         IMPLICIT NONE
         TYPE(t_lapw), INTENT(INOUT):: lapw
         TYPE(t_atoms), INTENT(IN)  :: atoms
         TYPE(t_input), INTENT(IN)  :: input
         TYPE(t_sym), INTENT(IN)    :: sym
         TYPE(t_cell), INTENT(IN)   :: cell
         TYPE(t_noco), INTENT(IN)   :: noco
         TYPE(t_nococonv), INTENT(IN)   :: nococonv

         INTEGER:: n, na, nn, np, lo, nkvec_sv, nkvec(atoms%nlod, 2), iindex
         IF (.NOT. ALLOCATED(lapw%kvec)) THEN
            ALLOCATE (lapw%kvec(2*(2*atoms%llod + 1), atoms%nlod, atoms%nat))
            ALLOCATE (lapw%nkvec(atoms%nlod, atoms%nat));lapw%nkvec=0
            ALLOCATE (lapw%index_lo(atoms%nlod, atoms%nat))
         ENDIF
         iindex = 0
         na = 0
         nkvec_sv = 0
         DO n = 1, atoms%ntype
            DO nn = 1, atoms%neq(n)
               na = na + 1
               if (sym%invsat(na) > 1) cycle
               np = sym%invtab(sym%ngopr(na))
               CALL priv_vec_for_lo(atoms, input, sym, na, n, np, noco, nococonv, lapw, cell)
               DO lo = 1, atoms%nlo(n)
                  lapw%index_lo(lo, na) = iindex
                  iindex = iindex + lapw%nkvec(lo, na)
               ENDDO
            ENDDO
         ENDDO
      END SUBROUTINE priv_lo_basis_setup

   END SUBROUTINE t_lapw_init

   SUBROUTINE lapw_phase_factors(lapw, iintsp, tau, qss, cph)
      USE m_constants
      USE m_types_fleurinput
      IMPLICIT NONE
      CLASS(t_lapw), INTENT(in):: lapw
      INTEGER, INTENT(IN)     :: iintsp
      REAL, INTENT(in)        :: tau(3), qss(3)
      COMPLEX, INTENT(out)    :: cph(:)

      INTEGER:: k
      REAL:: th

      !$OMP PARALLEL DO DEFAULT(none) &
      !$OMP& SHARED(lapw,iintsp,tau,qss,cph)&
      !$OMP& PRIVATE(k,th)
      DO k = 1, lapw%nv(iintsp)
         th = DOT_PRODUCT(lapw%gvec(:, k, iintsp) + (iintsp - 1.5)*qss + lapw%bkpt + lapw%qphon, tau)
         cph(k) = CMPLX(COS(tpi_const*th), SIN(tpi_const*th))
      END DO
      !$OMP END PARALLEL DO
   END SUBROUTINE lapw_phase_factors

   SUBROUTINE priv_vec_for_lo_old(atoms, input, sym, na, n, np, noco, nococonv, lapw, cell)

      USE m_constants
      USE m_orthoglo
      USE m_ylm
      USE m_types_fleurinput

      IMPLICIT NONE

      TYPE(t_noco), INTENT(IN)   :: noco
      TYPE(t_nococonv), INTENT(IN):: nococonv
      TYPE(t_sym), INTENT(IN)    :: sym
      TYPE(t_cell), INTENT(IN)   :: cell
      TYPE(t_atoms), INTENT(IN)  :: atoms
      TYPE(t_input), INTENT(IN)  :: input
      TYPE(t_lapw), INTENT(INOUT):: lapw
      !     ..
      !     .. Scalar Arguments ..
      INTEGER, INTENT(IN) :: na, n, np
      !     ..
      !     .. Array Arguments ..
      !     ..
      !     .. Local Scalars ..
      COMPLEX term1
      REAL th, con1
      INTEGER l, lo, mind, ll1, lm, iintsp, k, nkmin, ntyp, lmp, m, nintsp, k_start
      LOGICAL linind, enough, l_lo1
      !     ..
      !     .. Local Arrays ..
      INTEGER :: nkvec(atoms%nlod, 2)
      REAL qssbti(3), bmrot(3, 3), v(3), vmult(3)
      REAL :: gkrot(3, SIZE(lapw%gk, 2), 2)
      REAL :: rph(SIZE(lapw%gk, 2), 2)
      REAL :: cph(SIZE(lapw%gk, 2), 2)
      COMPLEX ylm((atoms%lmaxd + 1)**2)
      COMPLEX cwork(-2*atoms%llod:2*atoms%llod + 1, 2*(2*atoms%llod + 1), atoms%nlod, 2)
      !     ..
      !     .. Data statements ..
      REAL, PARAMETER :: eps = 1.0E-8
      REAL, PARAMETER :: linindq = 1.0e-6

      con1 = fpi_const/SQRT(cell%omtil)
      ntyp = n
      nintsp = MERGE(2, 1, noco%l_ss)
      DO iintsp = 1, nintsp
         IF (iintsp .EQ. 1) THEN
            qssbti = -nococonv%qss/2
         ELSE
            qssbti = +nococonv%qss/2
         ENDIF

         !--->    set up phase factors
         DO k = 1, lapw%nv(iintsp)
            th = tpi_const*DOT_PRODUCT((/lapw%k1(k, iintsp), lapw%k2(k, iintsp), lapw%k3(k, iintsp)/) + qssbti + lapw%qphon, atoms%taual(:, na))
            rph(k, iintsp) = COS(th)
            cph(k, iintsp) = -SIN(th)
         END DO

         IF (np .EQ. 1) THEN
            gkrot(:, :, iintsp) = lapw%gk(:, :, iintsp)
         ELSE
            bmrot = MATMUL(1.*sym%mrot(:, :, np), cell%bmat)
            DO k = 1, lapw%nv(iintsp)
               !-->           apply the rotation that brings this atom into the
               !-->           representative (this is the definition of ngopr(na))
               !-->           and transform to cartesian coordinates
               v(:) = lapw%vk(:, k, iintsp)
               gkrot(:, k, iintsp) = MATMUL(v, bmrot)
            END DO
         END IF
         !--->   end loop over interstitial spin
      ENDDO

      nkvec(:, :) = 0
      cwork(:, :, :, :) = CMPLX(0.0, 0.0)
      enough = .FALSE.

      IF (noco%l_ss) THEN
         k_start = 2  ! avoid k=1 !!! GB16
      ELSE
         k_start = 1
      ENDIF

      DO k = k_start, MIN(lapw%nv(1), lapw%nv(nintsp))
!       IF (ANY(lapw%rk(k,:nintsp).LT.eps)) CYCLE
         IF (.NOT. enough) THEN
            DO iintsp = 1, nintsp

               !-->        generate spherical harmonics
               vmult(:) = gkrot(:, k, iintsp)
               CALL ylm4(atoms%lnonsph(ntyp), vmult, ylm)
               l_lo1 = .false.
               IF ((lapw%rk(k, iintsp) .LT. eps) .AND. (.not. noco%l_ss)) THEN
                  l_lo1 = .true.
               ELSE
                  l_lo1 = .false.
               ENDIF
               ! --> here comes a part of abccoflo()
               IF (l_lo1) THEN
                  DO lo = 1, atoms%nlo(ntyp)
                     IF ((nkvec(lo, iintsp) .EQ. 0) .AND. (atoms%llo(lo, ntyp) .EQ. 0)) THEN
                        enough = .false.
                        nkvec(lo, iintsp) = 1
                        lapw%kvec(nkvec(lo, iintsp), lo, na) = k
                        term1 = con1*((atoms%rmt(ntyp)**2)/2)
                        cwork(0, 1, lo, iintsp) = term1/sqrt(2*tpi_const)
                        IF ((sym%invsat(na) .EQ. 1) .OR. (sym%invsat(na) .EQ. 2)) THEN
                           cwork(1, 1, lo, iintsp) = conjg(term1)/sqrt(2*tpi_const)
                        ENDIF
                     ENDIF
                  ENDDO
               ELSE
                  enough = .TRUE.
                  term1 = con1*((atoms%rmt(ntyp)**2)/2)*CMPLX(rph(k, iintsp), cph(k, iintsp))
                  DO lo = 1, atoms%nlo(ntyp)
                     IF (sym%invsat(na) .EQ. 0) THEN
                        IF ((nkvec(lo, iintsp)) .LT. (2*atoms%llo(lo, ntyp) + 1)) THEN
                           enough = .FALSE.
                           nkvec(lo, iintsp) = nkvec(lo, iintsp) + 1
                           l = atoms%llo(lo, ntyp)
                           ll1 = l*(l + 1) + 1
                           DO m = -l, l
                              lm = ll1 + m
                              cwork(m, nkvec(lo, iintsp), lo, iintsp) = term1*ylm(lm)
                           END DO
                           CALL orthoglo(input%l_real, atoms, nkvec(lo, iintsp), lo, l, linindq, .FALSE., cwork(-2*atoms%llod, 1, 1, iintsp), linind)
                           IF (linind) THEN
                              lapw%kvec(nkvec(lo, iintsp), lo, na) = k
                           ELSE
                              nkvec(lo, iintsp) = nkvec(lo, iintsp) - 1
                           ENDIF
                        ENDIF
                     ELSE
                        IF ((sym%invsat(na) .EQ. 1) .OR. (sym%invsat(na) .EQ. 2)) THEN
                           IF (nkvec(lo, iintsp) .LT. 2*(2*atoms%llo(lo, ntyp) + 1)) THEN
                              enough = .FALSE.
                              nkvec(lo, iintsp) = nkvec(lo, iintsp) + 1
                              l = atoms%llo(lo, ntyp)
                              ll1 = l*(l + 1) + 1
                              DO m = -l, l
                                 lm = ll1 + m
                                 mind = -l + m
                                 cwork(mind, nkvec(lo, iintsp), lo, iintsp) = term1*ylm(lm)
                                 mind = l + 1 + m
                                 lmp = ll1 - m
                                 cwork(mind, nkvec(lo, iintsp), lo, iintsp) = ((-1)**(l + m))*CONJG(term1*ylm(lmp))
                              END DO
                              CALL orthoglo(input%l_real, atoms, nkvec(lo, iintsp), lo, l, linindq, .TRUE., cwork(-2*atoms%llod, 1, 1, iintsp), linind)
                              IF (linind) THEN
                                 lapw%kvec(nkvec(lo, iintsp), lo, na) = k
                                 !                          write(*,*) nkvec(lo,iintsp),k,' <- '
                              ELSE
                                 nkvec(lo, iintsp) = nkvec(lo, iintsp) - 1
                              END IF
                           END IF
                        END IF
                     END IF
                  END DO
                  IF ((k .EQ. lapw%nv(iintsp)) .AND. (.NOT. enough)) THEN
                     WRITE (oUnit, FMT=*) 'vec_for_lo did not find enough linearly independent'
                     WRITE (oUnit, FMT=*) 'clo coefficient-vectors. the linear independence'
                     WRITE (oUnit, FMT=*) 'quality, linindq, is set: ', linindq
                     WRITE (oUnit, FMT=*) 'this value might be to large.'
                     WRITE (*, *) na, k, lapw%nv
                     CALL juDFT_error("not enough lin. indep. clo-vectors", calledby="vec_for_lo")
                  END IF
                  ! -- >        end of abccoflo-part
               ENDIF
            ENDDO
         ENDIF

         ! -->    check whether we have already enough k-vecs
         enough = .TRUE.
         DO lo = 1, atoms%nlo(ntyp)
            IF (nkvec(lo, 1) .EQ. nkvec(lo, nintsp)) THEN   ! k-vec accepted by both spin channels
               IF (sym%invsat(na) .EQ. 0) THEN
                  IF (nkvec(lo, 1) .LT. (2*atoms%llo(lo, ntyp) + 1)) THEN
                     enough = .FALSE.
                  ENDIF
               ELSE
                  IF (nkvec(lo, 1) .LT. (2*(2*atoms%llo(lo, ntyp) + 1))) THEN
                     enough = .FALSE.
                  ENDIF
               ENDIF
            ELSE
               nkmin = MIN(nkvec(lo, 1), nkvec(lo, nintsp)) ! try another k-vec
               nkvec(lo, 1) = nkmin; nkvec(lo, nintsp) = nkmin
               enough = .FALSE.
            ENDIF
         ENDDO
         IF (enough) THEN
            lapw%nkvec(:atoms%nlo(ntyp), na) = nkvec(:atoms%nlo(ntyp), 1)
            RETURN
         ENDIF
      ENDDO

   END SUBROUTINE priv_vec_for_lo_old

   SUBROUTINE priv_vec_for_lo(atoms, input, sym, na, ntype, np, noco, nococonv, lapw, cell)

      USE m_constants
      USE m_orthoglo
      USE m_ylm
      USE m_types_fleurinput

      IMPLICIT NONE

      TYPE(t_noco), INTENT(IN)   :: noco
      TYPE(t_nococonv), INTENT(IN):: nococonv
      TYPE(t_sym), INTENT(IN)    :: sym
      TYPE(t_cell), INTENT(IN)   :: cell
      TYPE(t_atoms), INTENT(IN)  :: atoms
      TYPE(t_input), INTENT(IN)  :: input
      TYPE(t_lapw), INTENT(INOUT):: lapw
      !     ..
      !     .. Scalar Arguments ..
      INTEGER, INTENT(IN) :: na, ntype, np
      !     ..
      !     .. Array Arguments ..
      !     ..
      !     .. Local Scalars ..
      COMPLEX term1, norm
      REAL th, con1, linindq, linindqStart, linindqEnd, numK, stepSize
      INTEGER l, lo, mind, ll1, lm, iintsp, k, nkmin, lmp, m, nintsp, k_start, k_end, minIndex, maxIndex, increment
      INTEGER nApproach, nApproachEnd
      LOGICAL linind, enough, l_lo1, l_norm
      !     ..
      !     .. Local Arrays ..
      INTEGER :: nkvec(atoms%nlod, 2)
      REAL qssbti(3), bmrot(3, 3), v(3), vmult(3)
      REAL :: gkrot(3, SIZE(lapw%gk, 2), 2)
      REAL :: rph(SIZE(lapw%gk, 2), 2)
      REAL :: cph(SIZE(lapw%gk, 2), 2)
      COMPLEX ylm((atoms%lmaxd + 1)**2)
      COMPLEX cwork(-2*atoms%llod:2*atoms%llod + 1, 2*(2*atoms%llod + 1), atoms%nlod, 2)
      !     ..
      !     .. Data statements ..
      REAL, PARAMETER :: eps = 1.0E-8

      con1 = fpi_const/SQRT(cell%omtil)
      nintsp = MERGE(2, 1, noco%l_ss)
      DO iintsp = 1, nintsp
         IF (iintsp .EQ. 1) THEN
            qssbti = -nococonv%qss/2
         ELSE
            qssbti = +nococonv%qss/2
         ENDIF

         !--->    set up phase factors
         DO k = 1, lapw%nv(iintsp)
            th = tpi_const*DOT_PRODUCT((/lapw%k1(k, iintsp), lapw%k2(k, iintsp), lapw%k3(k, iintsp)/) + qssbti, atoms%taual(:, na))
            rph(k, iintsp) = COS(th)
            cph(k, iintsp) = -SIN(th)
         END DO

         IF (np .EQ. 1) THEN
            gkrot(:, :, iintsp) = lapw%gk(:, :, iintsp)
         ELSE
            bmrot = MATMUL(1.*sym%mrot(:, :, np), cell%bmat)
            DO k = 1, lapw%nv(iintsp)
               !-->           apply the rotation that brings this atom into the
               !-->           representative (this is the definition of ngopr(na))
               !-->           and transform to cartesian coordinates
               v(:) = lapw%vk(:, k, iintsp)
               gkrot(:, k, iintsp) = MATMUL(v, bmrot)
            END DO
         END IF
         !--->   end loop over interstitial spin
      ENDDO

      nkvec(:, :) = 0
      cwork(:, :, :, :) = CMPLX(0.0, 0.0)
      enough = .FALSE.

      ! Typically the search for linearly independent K vectors starts from the
      ! top and then goes down. This seems to be more stable than the opposite
      ! direction. The exception is a calculation with a spin spiral. There it
      ! is important that the K vectors for both spins feature the same G
      ! vectors. When starting from the bottom this is typically simple to check
      ! by just comparing the indices of the two K vectors. From the top this
      ! would require a more elaborate comparison.

      nApproachEnd = 8

      IF (noco%l_ss) THEN
         nApproachEnd = 4
      END IF

      DO lo = 1, atoms%nlo(ntype)
         enough = .FALSE.
         nApproach = 0
         DO WHILE (.NOT.enough)
            nApproach = nApproach + 1
            nkvec(lo, :) = 0
            cwork(:,:,lo,:) = CMPLX(0.0, 0.0)
            k_start = 2
            k_end = 2
            increment = 1
            SELECT CASE (nApproach)
               CASE (1)
                  k_start = 2  ! avoid k=1 !!! GB16
                  k_end = MIN(lapw%nv(1), lapw%nv(nintsp))
                  increment = 1
                  l_norm = .FALSE.
                  linindqStart = 1.0e-6
                  linindqEnd = 1.0e-6
               CASE (2)
                  k_start = 2  ! avoid k=1 !!! GB16
                  k_end = MIN(lapw%nv(1), lapw%nv(nintsp))
                  increment = 1
                  l_norm = .TRUE.
                  linindqStart = 1.0e-6
                  linindqEnd = 1.0e-6
               CASE (3)
                  k_start = 2  ! avoid k=1 !!! GB16
                  k_end = MIN(lapw%nv(1), lapw%nv(nintsp))
                  increment = 1
                  l_norm = .FALSE.
                  linindqStart = 2.0e-5
                  linindqEnd = 1.0e-6
               CASE (4)
                  k_start = 2  ! avoid k=1 !!! GB16
                  k_end = MIN(lapw%nv(1), lapw%nv(nintsp))
                  increment = 1
                  l_norm = .TRUE.
                  linindqStart = 2.0e-5
                  linindqEnd = 1.0e-6
               CASE (5)
                  k_start = MIN(lapw%nv(1), lapw%nv(nintsp))
                  k_end = 1
                  increment = -1
                  l_norm = .FALSE.
                  linindqStart = 1.0e-6
                  linindqEnd = 1.0e-6
               CASE (6)
                  k_start = MIN(lapw%nv(1), lapw%nv(nintsp))
                  k_end = 1
                  increment = -1
                  l_norm = .TRUE.
                  linindqStart = 1.0e-6
                  linindqEnd = 1.0e-6
               CASE (7)
                  k_start = MIN(lapw%nv(1), lapw%nv(nintsp))
                  k_end = 1
                  increment = -1
                  l_norm = .FALSE.
                  linindqStart = 2.0e-5
                  linindqEnd = 1.0e-6
               CASE (8)
                  k_start = MIN(lapw%nv(1), lapw%nv(nintsp))
                  k_end = 1
                  increment = -1
                  l_norm = .TRUE.
                  linindqStart = 2.0e-5
                  linindqEnd = 1.0e-6
            END SELECT
            k = k_start - increment
            DO WHILE (.NOT.enough)
               enough = .FALSE.
               k = k + increment
               IF ((k.GT.MAX(k_start,k_end)).OR.(k.LT.MIN(k_start,k_end))) THEN
                  IF (nApproach.GT.nApproachEnd) THEN
                     WRITE (oUnit, FMT=*) 'vec_for_lo did not find enough linearly independent'
                     WRITE (oUnit, FMT=*) 'clo coefficient-vectors. the linear independence'
                     WRITE (oUnit, FMT=*) 'quality, linindq, is set: ', linindqEnd
                     WRITE (oUnit, FMT=*) 'this value might be to large.'
                     WRITE (*, *) 'Atom: ', na, 'type: ', ntype, 'nv: ', lapw%nv, 'lo: ', lo, 'l: ', atoms%llo(lo, ntype)
                     CALL juDFT_error("not enough lin. indep. clo-vectors", calledby="vec_for_lo")
                  END IF
                  EXIT
               END IF

               DO iintsp = 1, nintsp

                  vmult(:) = gkrot(:, k, iintsp)
                  CALL ylm4(atoms%lnonsph(ntype), vmult, ylm)
                  l_lo1 = .false.
                  IF ((lapw%rk(k, iintsp) .LT. eps) .AND. (.not. noco%l_ss)) THEN
                     l_lo1 = .true.
                  ELSE
                     l_lo1 = .false.
                  END IF

                  numK = MERGE(2*atoms%llo(lo, ntype)+1,2*(2*atoms%llo(lo, ntype)+1),sym%invsat(na).EQ.0)

                  IF (l_lo1) THEN
                     IF ((nkvec(lo, iintsp) .EQ. 0) .AND. (atoms%llo(lo, ntype) .EQ. 0)) THEN
                        nkvec(lo, iintsp) = 1
                        lapw%kvec(nkvec(lo, iintsp), lo, na) = k
                        term1 = con1 * (atoms%rmt(ntype)**2.0) / 2.0
                        cwork(0, 1, lo, iintsp) = term1 / sqrt(2.0*tpi_const)
                        norm = DOT_PRODUCT(cwork(0:0, 1, lo, iintsp),cwork(0:0, 1, lo, iintsp))
                        IF (l_norm) cwork(0:0, 1, lo, iintsp) = cwork(0:0, 1, lo, iintsp) / SQRT(norm)
                        IF ((sym%invsat(na) .EQ. 1) .OR. (sym%invsat(na) .EQ. 2)) THEN
                           cwork(1, 1, lo, iintsp) = conjg(term1) / sqrt(2.0*tpi_const)
                        END IF
                     
                     END IF
                  ELSE
                     term1 = con1 * ((atoms%rmt(ntype)**2.0)/2.0) * CMPLX(rph(k, iintsp), cph(k, iintsp))
                     IF (sym%invsat(na) .EQ. 0) THEN
                        IF ((nkvec(lo, iintsp)) .LT. (2*atoms%llo(lo, ntype) + 1)) THEN
                           nkvec(lo, iintsp) = nkvec(lo, iintsp) + 1
                           l = atoms%llo(lo, ntype)
                           ll1 = l*(l + 1) + 1
                           DO m = -l, l
                              lm = ll1 + m
                              cwork(m, nkvec(lo, iintsp), lo, iintsp) = term1 * ylm(lm)
                           END DO
                           norm = DOT_PRODUCT(cwork(-l:l, 1, lo, iintsp),cwork(-l:l, 1, lo, iintsp))
                           IF (l_norm) cwork(-l:l, 1, lo, iintsp) = cwork(-l:l, 1, lo, iintsp) / SQRT(norm)
                           stepSize = (REAL(linindqStart - linindqEnd)) / numK
                           linindq = (numK - (REAL(nkvec(lo, iintsp) + 1))) * stepSize + linindqEnd
                           CALL orthoglo(input%l_real, atoms, nkvec(lo, iintsp), lo, l, linindq, .FALSE., cwork(-2*atoms%llod, 1, 1, iintsp), linind)
                           IF (linind) THEN
                              lapw%kvec(nkvec(lo, iintsp), lo, na) = k
                           ELSE
                              nkvec(lo, iintsp) = nkvec(lo, iintsp) - 1
                           END IF
                        END IF
                     ELSE IF ((sym%invsat(na) .EQ. 1) .OR. (sym%invsat(na) .EQ. 2)) THEN
                        IF (nkvec(lo, iintsp) .LT. 2*(2*atoms%llo(lo, ntype) + 1)) THEN
                           nkvec(lo, iintsp) = nkvec(lo, iintsp) + 1
                           l = atoms%llo(lo, ntype)
                           ll1 = l*(l + 1) + 1
                           DO m = -l, l
                              lm = ll1 + m
                              mind = -l + m
                              cwork(mind, nkvec(lo, iintsp), lo, iintsp) = term1 * ylm(lm)
                              mind = l + 1 + m
                              lmp = ll1 - m
                              cwork(mind, nkvec(lo, iintsp), lo, iintsp) = ((-1)**(l + m))*CONJG(term1*ylm(lmp))
                           END DO
                           minIndex = -l - l
                           maxIndex = l + l + 1
                           norm = DOT_PRODUCT(cwork(-2*l:2*l+1, 1, lo, iintsp),cwork(-2*l:2*l+1, 1, lo, iintsp))
                           IF (l_norm) cwork(-2*l:2*l+1, 1, lo, iintsp) = cwork(-2*l:2*l+1, 1, lo, iintsp) / SQRT(norm)
                           stepSize = (REAL(linindqStart - linindqEnd)) / numK
                           linindq = (numK - (REAL(nkvec(lo, iintsp) + 1))) * stepSize + linindqEnd
                           CALL orthoglo(input%l_real, atoms, nkvec(lo, iintsp), lo, l, linindq, .TRUE., cwork(-2*atoms%llod, 1, 1, iintsp), linind)
                           IF (linind) THEN
                              lapw%kvec(nkvec(lo, iintsp), lo, na) = k
                           ELSE
                              nkvec(lo, iintsp) = nkvec(lo, iintsp) - 1
                           END IF
                        END IF

                     END IF
                  END IF
               END DO

               enough = .TRUE.
               IF (nkvec(lo, 1) .EQ. nkvec(lo, nintsp)) THEN   ! k-vec accepted by both spin channels
                  IF (sym%invsat(na) .EQ. 0) THEN
                     IF (nkvec(lo, 1) .LT. (2*atoms%llo(lo, ntype) + 1)) THEN
                        enough = .FALSE.
                     ENDIF
                  ELSE
                     IF (nkvec(lo, 1) .LT. (2*(2*atoms%llo(lo, ntype) + 1))) THEN
                        enough = .FALSE.
                     ENDIF
                  ENDIF
               ELSE
                  nkmin = MIN(nkvec(lo, 1), nkvec(lo, nintsp)) ! try another k-vec
                  nkvec(lo, 1) = nkmin
                  nkvec(lo, nintsp) = nkmin
                  enough = .FALSE.
               END IF
            END DO
         END DO
      END DO

      lapw%nkvec(:atoms%nlo(ntype), na) = nkvec(:atoms%nlo(ntype), 1)

   END SUBROUTINE priv_vec_for_lo

END MODULE m_types_lapw
