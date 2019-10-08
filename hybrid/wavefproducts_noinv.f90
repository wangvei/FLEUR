module m_wavefproducts_noinv

CONTAINS
   SUBROUTINE wavefproducts_noinv5(&
  &                      bandi, bandf, bandoi, bandof,&
  &                      nk, iq, dimension, input, jsp,&
  &                      cell, atoms, hybrid,&
  &                      hybdat,&
  &                      kpts,&
  &                      lapw, sym,&
  &                      nbasm_mt,&
  &                      noco,&
  &                      nkqpt, cprod)

      USE m_constants
      USE m_util, ONLY: modulo1
      USE m_types_hybrid, ONLY: gptnorm
      USE m_trafo
      USE m_wrapper
      USE m_types
      USE m_io_hybrid
      USE m_wavefproducts_aux
      IMPLICIT NONE
      TYPE(t_dimension), INTENT(IN)   :: dimension
      TYPE(t_input), INTENT(IN)       :: input
      TYPE(t_noco), INTENT(IN)        :: noco
      TYPE(t_sym), INTENT(IN)         :: sym
      TYPE(t_cell), INTENT(IN)        :: cell
      TYPE(t_kpts), INTENT(IN)        :: kpts
      TYPE(t_atoms), INTENT(IN)       :: atoms
      TYPE(t_lapw), INTENT(IN)        :: lapw
      TYPE(t_hybrid), INTENT(IN)      :: hybrid
      TYPE(t_hybdat), INTENT(INOUT)   :: hybdat

!     - scalars -
      INTEGER, INTENT(IN)      ::  bandi, bandf, bandoi, bandof
      INTEGER, INTENT(IN)      ::  nk, iq, jsp
      INTEGER, INTENT(IN)      ::  nbasm_mt
      INTEGER, INTENT(OUT)     ::  nkqpt

!     - arrays -

      COMPLEX, INTENT(OUT)    ::  cprod(hybrid%maxbasm1, bandoi:bandof, bandf - bandi + 1)

!     - local scalars -
      INTEGER                 ::  ic, l, n, l1, l2, n1, n2, lm_0, lm1_0, lm2_0, lm, lm1, lm2, m1, m2, i, j, ll
      INTEGER                 ::  itype, ieq, iband, iband1
      INTEGER                 ::  ic1, ig1, ig2, ig
      INTEGER                 ::  igptm, iigptm, nbasm_ir, ngpt0, nbasfcn, m

      REAL                    ::  rdum

      COMPLEX                 ::  cdum, cdum1
      COMPLEX                 ::  cmplx_exp

      LOGICAL                 ::  offdiag
      TYPE(t_lapw)            ::  lapw_nkqpt

!      - local arrays -
      INTEGER                 ::  g(3), g_t(3)
      INTEGER                 ::  lmstart(0:atoms%lmaxd, atoms%ntype)
      INTEGER, ALLOCATABLE    ::  gpt0(:, :)
      INTEGER, ALLOCATABLE    ::  pointer(:,:,:)

      REAL                    ::  kqpt(3), kqpthlp(3)

      COMPLEX                 ::  carr1(bandoi:bandof)
      COMPLEX                 ::  carr2(bandoi:bandof, bandf - bandi + 1)
      TYPE(t_mat)             ::  z_nk, z_kqpt
      COMPLEX                 ::  cmt(dimension%neigd, hybrid%maxlmindx, atoms%nat)
      COMPLEX                 ::  cmt_nk(dimension%neigd, hybrid%maxlmindx, atoms%nat)
      COMPLEX, ALLOCATABLE     ::  z0(:, :)

      call timestart("wavefproducts_noinv5")
      call timestart("wavefproducts_noinv5 IR")
      cprod = 0

      nbasm_ir = maxval(hybrid%ngptm)

      !
      ! compute k+q point for given q point in EIBZ(k)
      !
      kqpthlp = kpts%bkf(:, nk) + kpts%bkf(:, iq)
      ! k+q can lie outside the first BZ, transfer
      ! it back into the 1. BZ
      kqpt = kpts%to_first_bz(kqpthlp)
      g_t(:) = nint(kqpt - kqpthlp)
      ! determine number of kqpt
      nkqpt = kpts%get_nk(kqpt)
      IF (.not. kpts%is_kpt(kqpt)) call juDFT_error('wavefproducts: k-point not found')

      !
      ! compute G's fulfilling |bk(:,nkqpt) + G| <= rkmax
      !
      CALL lapw_nkqpt%init(input, noco, kpts, atoms, sym, nkqpt, cell, sym%zrfs)
      nbasfcn = calc_number_of_basis_functions(lapw, atoms, noco)
      call z_nk%alloc(.false., nbasfcn, dimension%neigd)
      nbasfcn = calc_number_of_basis_functions(lapw_nkqpt, atoms, noco)
      call z_kqpt%alloc(.false., nbasfcn, dimension%neigd)

      ! read in z at k-point nk and nkqpt
      call timestart("read_z")
      call read_z(z_nk, nk)
      call read_z(z_kqpt, nkqpt)
      call timestop("read_z")

      g = maxval(abs(lapw%gvec(:,:lapw%nv(jsp), jsp)), dim=2) &
     &  + maxval(abs(lapw_nkqpt%gvec(:,:lapw_nkqpt%nv(jsp), jsp)), dim=2)&
     &  + maxval(abs(hybrid%gptm(:, hybrid%pgptm(:hybrid%ngptm(iq), iq))), dim=2) + 1

      call hybdat%set_stepfunction(cell, atoms,g, sqrt(cell%omtil))

      !
      ! convolute phi(n,k) with the step function and store in cpw0
      !

      !(1) prepare list of G vectors
      call prep_list_of_gvec(lapw, lapw_nkqpt, hybrid, g, g_t, iq, jsp, pointer, gpt0, ngpt0)

      !(2) calculate convolution
      call timestart("calc convolution")
      call timestart("step function")
      ALLOCATE (z0(bandoi:bandof, ngpt0))
      z0 = 0
      DO ig2 = 1, lapw_nkqpt%nv(jsp)
         carr1 = z_kqpt%data_c(ig2, bandoi:bandof)
         DO ig = 1, ngpt0
            g = gpt0(:, ig) - lapw_nkqpt%gvec(:,ig2, jsp)
            cdum = hybdat%stepfunc(g(1), g(2), g(3))
            DO n2 = bandoi, bandof
               z0(n2, ig) = z0(n2, ig) + carr1(n2)*cdum
            END DO
         END DO
      END DO
      call timestop("step function")

      call timestart("hybrid gptm")
      ic = nbasm_mt
      DO igptm = 1, hybrid%ngptm(iq)
         carr2 = 0
         ic = ic + 1
         iigptm = hybrid%pgptm(igptm, iq)

         DO ig1 = 1, lapw%nv(jsp)
            g = lapw%gvec(:,ig1, jsp) + hybrid%gptm(:, iigptm) - g_t
            ig2 = pointer(g(1), g(2), g(3))

            IF (ig2 == 0) THEN
               call juDFT_error('wavefproducts_noinv2: pointer undefined')
            END IF

            DO n1 = 1, bandf - bandi + 1
               cdum1 = conjg(z_nk%data_c(ig1, n1))
               DO n2 = bandoi, bandof
                  carr2(n2, n1) = carr2(n2, n1) + cdum1*z0(n2, ig2)
               END DO
            END DO

         END DO
         cprod(ic, :, :) = carr2(:, :)
      END DO
      call timestop("hybrid gptm")
      DEALLOCATE (z0, pointer, gpt0)
      call timestop("calc convolution")

      call timestop("wavefproducts_noinv5 IR")

!       RETURN

      !
      ! MT contribution
      !

      ! lmstart = lm start index for each l-quantum number and atom type (for cmt-coefficients)
      DO itype = 1, atoms%ntype
         DO l = 0, atoms%lmax(itype)
            lmstart(l, itype) = sum((/(hybrid%nindx(ll, itype)*(2*ll + 1), ll=0, l - 1)/))
         END DO
      END DO

      ! read in cmt coefficients from direct access file cmt
      call read_cmt(cmt_nk(:, :, :), nk)
      call read_cmt(cmt(:, :, :), nkqpt)

      lm_0 = 0
      ic = 0

      DO itype = 1, atoms%ntype
         DO ieq = 1, atoms%neq(itype)
            ic = ic + 1
            ic1 = 0

            cmplx_exp = exp(-ImagUnit*tpi_const*dot_product(kpts%bkf(:, iq), atoms%taual(:, ic)))

            DO l = 0, hybrid%lcutm1(itype)
               DO n = 1, hybdat%nindxp1(l, itype) ! loop over basis-function products

                  l1 = hybdat%prod(n, l, itype)%l1 !
                  l2 = hybdat%prod(n, l, itype)%l2 ! current basis-function product
                  n1 = hybdat%prod(n, l, itype)%n1 ! = bas(:,n1,l1,itype)*bas(:,n2,l2,itype) = b1*b2
                  n2 = hybdat%prod(n, l, itype)%n2 !

                  IF (mod(l1 + l2 + l, 2) /= 0) cycle

                  offdiag = l1 /= l2 .or. n1 /= n2 ! offdiag=true means that b1*b2 and b2*b1 are different combinations
                  !(leading to the same basis-function product)

                  lm1_0 = lmstart(l1, itype) ! start at correct lm index of cmt-coefficients
                  lm2_0 = lmstart(l2, itype) ! (corresponding to l1 and l2)

                  lm = lm_0
                  DO m = -l, l

                     carr2 = 0.0

                     lm1 = lm1_0 + n1 ! go to lm index for m1=-l1
                     DO m1 = -l1, l1
                        m2 = m1 + m ! Gaunt condition -m1+m2-m=0
                        IF (abs(m2) <= l2) THEN
                           lm2 = lm2_0 + n2 + (m2 + l2)*hybrid%nindx(l2, itype)
                           rdum = hybdat%gauntarr(1, l1, l2, l, m1, m) ! precalculated Gaunt coefficient
                           IF (abs(rdum) > 1e-12) THEN
                              DO iband = bandi, bandf
                                 cdum = rdum*conjg(cmt_nk(iband, lm1, ic)) !nk
                                 DO iband1 = bandoi, bandof
                                    carr2(iband1, iband) = carr2(iband1, iband) + cdum*cmt(iband1, lm2, ic) !ikpt

                                 END DO
                              END DO
                           END IF
                        END IF

                        m2 = m1 - m ! switch role of b1 and b2
                        IF (abs(m2) <= l2 .and. offdiag) THEN
                           lm2 = lm2_0 + n2 + (m2 + l2)*hybrid%nindx(l2, itype)
                           rdum = hybdat%gauntarr(2, l1, l2, l, m1, m) ! precalculated Gaunt coefficient
                           IF (abs(rdum) > 1e-12) THEN
                              DO iband = bandi, bandf
                                 cdum = rdum*conjg(cmt_nk(iband, lm2, ic)) !nk
                                 DO iband1 = bandoi, bandof
                                    carr2(iband1, iband) = carr2(iband1, iband) + cdum*cmt(iband1, lm1, ic)
                                 END DO
                              END DO
                           END IF
                        END IF

                        lm1 = lm1 + hybrid%nindx(l1, itype) ! go to lm start index for next m1-quantum number

                     END DO  !m1

                     DO iband = bandi, bandf
                        DO iband1 = bandoi, bandof
                           cdum = carr2(iband1, iband)*cmplx_exp
                           DO i = 1, hybrid%nindxm1(l, itype)
                              j = lm + i
                              cprod(j, iband1, iband) = cprod(j, iband1, iband) + hybdat%prodm(i, n, l, itype)*cdum
                           END DO

                        END DO
                     END DO

                     lm = lm + hybrid%nindxm1(l, itype) ! go to lm start index for next m-quantum number

                  END DO

               END DO
               lm_0 = lm_0 + hybrid%nindxm1(l, itype)*(2*l + 1) ! go to the lm start index of the next l-quantum number
               IF (lm /= lm_0) call juDFT_error('wavefproducts_noinv2: counting of lm-index incorrect (bug?)')
            END DO
         END DO
      END DO

      call timestop("wavefproducts_noinv5")

   END SUBROUTINE wavefproducts_noinv5

end module m_wavefproducts_noinv
