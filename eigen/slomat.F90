!--------------------------------------------------------------------------------
! Copyright (c) 2016 Peter Grünberg Institut, Forschungszentrum Jülich, Germany
! This file is part of FLEUR and available as free software under the conditions
! of the MIT license as expressed in the LICENSE file in more detail.
!--------------------------------------------------------------------------------

MODULE m_slomat
  !***********************************************************************
  ! updates the overlap matrix with the contributions from the local
  ! orbitals.
  !                                                p.kurz sept. 1996
  !***********************************************************************
CONTAINS
   SUBROUTINE slomat(input,atoms,sym,fmpi,lapw,cell,nococonv,ntyp,na,&
                     isp,ud, alo1,blo1,clo1,fjgj,&
                     igSpinPr,igSpin,chi,smat,l_fullj,lapwq,fjgjq)
    !***********************************************************************
    ! locol stores the number of columns already processed; on parallel
    !       computers this decides, whether the LO-contribution is
    !       done on this node                                          gb00
    !
    ! function legpol() at end of module
    !***********************************************************************

      USE m_constants,ONLY: fpi_const
      !USE m_types_mpimat
      USE m_types
      USE m_hsmt_fjgj

      IMPLICIT NONE

      TYPE(t_input),INTENT(IN)  :: input
      TYPE(t_atoms),INTENT(IN)  :: atoms
      TYPE(t_sym),INTENT(IN)    :: sym
      TYPE(t_lapw),INTENT(IN),Target   :: lapw
      TYPE(t_mpi),INTENT(IN)    :: fmpi
      TYPE(t_cell),INTENT(IN)   :: cell
      TYPE(t_nococonv),INTENT(IN)   :: nococonv
      TYPE(t_fjgj),INTENT(IN),target   :: fjgj

      ! Scalar Arguments
      INTEGER, INTENT (IN)      :: na,ntyp
      INTEGER, INTENT (IN)      :: igSpin,igSpinPr
      COMPLEX, INTENT (IN)      :: chi
      INTEGER, INTENT(IN)       :: isp

      ! Array Arguments
      REAL,   INTENT (IN)       :: alo1(atoms%nlod),blo1(atoms%nlod),clo1(atoms%nlod)
      TYPE(t_usdus),INTENT(IN)  :: ud
      CLASS(t_mat),INTENT(INOUT) :: smat
      LOGICAL, INTENT(IN) :: l_fullj

      TYPE(t_lapw), OPTIONAL, TARGET, INTENT(IN) :: lapwq
      TYPE(t_fjgj), OPTIONAL, Target, INTENT(IN) :: fjgjq

      ! Local Scalars
      REAL    :: con,dotp,fact1,fact2,fact3,fl2p1
      INTEGER :: invsfct,k ,l,lo,lop,lp,nkvec,nkvecp,kp,i
      INTEGER :: locol,lorow
      LOGICAL :: l_samelapw

      COMPLEX,   ALLOCATABLE  :: cphPr(:), cph(:)

      TYPE(t_lapw),pointer :: lapwPr
      TYPE(t_fjgj),pointer :: fjgjPr

      l_samelapw = .FALSE.
      IF (.NOT.PRESENT(lapwq)) l_samelapw = .TRUE.
      IF (.NOT.l_samelapw) THEN
         lapwPr => lapwq
         fjgjPr => fjgjq
      ELSE
         lapwPr => lapw
         fjgjPr => fjgj
      END IF
      
      ALLOCATE(cph(MAXVAL(lapw%nv)))
      ALLOCATE(cphPr(MAXVAL(lapwPr%nv)))

      ! TODO: Introduce the logic for different lapw and the full rectangular
      !       instead of triangular construction...

      CALL lapwPr%phase_factors(igSpinPr,atoms%taual(:,na),nococonv%qss,cphPr)
      IF (l_samelapw) THEN
         cph = cphPr
      ELSE
         CALL lapw%phase_factors(igSpin,atoms%taual(:,na),nococonv%qss,cph)
      END IF

      IF ((sym%invsat(na) == 0) .OR. (sym%invsat(na) == 1)) THEN
         ! If this atom is the first of two atoms related by inversion, the
         ! contributions to the overlap matrix of both atoms are added simultaneously.
         ! Where it is made use of the fact, that the sum of these contributions
         ! is twice the real part of the contribution of each atom. Note, that in
         ! this case there are twice as many (2*(2*l+1)) k-vectors.
         ! (compare abccoflo and comments there).
         IF (sym%invsat(na) == 0) invsfct = 1
         IF (sym%invsat(na) == 1) invsfct = 2

         con = fpi_const/SQRT(cell%omtil)* ((atoms%rmt(ntyp))**2)/2.0

         !$acc kernels present(smat,smat%data_c,smat%data_r)&
         !$acc & copyin(fjgj,fjgj%fj,fjgj%gj,fjgjPr,fjgjPr%fj,fjgjPr%gj,l,lapw,lapw%kvec(:,:,na),lapwPr,lapwPr%kvec(:,:,na),ud,clo1(:),dotp,cph(:),cphPr(:),atoms,lapw%index_lo(:,na),lapw%gk(:,:,:)) &
         !$acc & copyin(lapwPr%index_lo(:,na),lapwPr%gk(:,:,:),ud%dulon(:,ntyp,isp),ud%ddn(:,ntyp,isp),ud%uulon(:,ntyp,isp),ud%uloulopn(:,:,ntyp,isp),blo1(:)) &
         !$acc & copyin(atoms%nlo(ntyp),lapw%nv(:),lapwPr%nv(:),atoms%llo(:,ntyp),alo1(:), fmpi, fmpi%n_size, fmpi%n_rank)&
         !$acc & default(none)
         
         !$acc loop gang private(fact1,fl2p1,l) independent
         DO lo = 1,atoms%nlo(ntyp) !loop over all LOs for this atom
            l = atoms%llo(lo,ntyp)
            fl2p1 = (2*l+1)/fpi_const
            fact1 = (con**2) * fl2p1 * ( &
                  & alo1(lo)*(alo1(lo) &
                        & + 2*clo1(lo)*ud%uulon(lo,ntyp,isp)) + &
                  & blo1(lo)*(blo1(lo)*ud%ddn(l,ntyp,isp) &
                        & + 2*clo1(lo)*ud%dulon(lo,ntyp,isp)) + &
                  & clo1(lo)*clo1(lo) )
            
            DO nkvec = 1,invsfct* (2*l+1) !Each LO can have several functions
               ! lop-kG part (l_fullj). |====|
               IF (l_fullj) THEN
                  lorow = lapwPr%nv(igSpinPr)+lapwPr%index_lo(lo,na)+nkvec
                  kp = lapwPr%kvec(nkvec,lo,na)
                  !$acc loop vector private(fact2,dotp,kp) independent
                  DO k = fmpi%n_rank + 1, lapw%nv(igSpin), fmpi%n_size
                     fact2 = con * fl2p1 * ( &
                           & fjgj%fj(k,l,isp,igSpin)*(alo1(lo) &
                                                  & + clo1(lo)*ud%uulon(lo,ntyp,isp)) + &
                           & fjgj%gj(k,l,isp,igSpin)*(blo1(lo)*ud%ddn(l,ntyp,isp) &
                                                  & + clo1(lo)*ud%dulon(lo,ntyp,isp)) )
                     dotp = dot_PRODUCT(lapw%gk(:,k,igSpin),lapwPr%gk(:,kp,igSpinPr))

                     IF (smat%l_real) THEN
                        smat%data_r(lorow,(k-1) / fmpi%n_size + 1) = smat%data_r(lorow,(k-1) / fmpi%n_size + 1) &
                                            & + chi * invsfct * fact2 * legpol(atoms%llo(lo,ntyp),dotp) &
                                            & * CONJG(cphPr(kp)) * cph(k)
                     ELSE
                        smat%data_c(lorow,(k-1) / fmpi%n_size + 1) = smat%data_c(lorow,(k-1) / fmpi%n_size + 1) &
                                            & + chi * invsfct * fact2 * legpol(atoms%llo(lo,ntyp),dotp) &
                                            & * CONJG(cphPr(kp)) * cph(k)
                     END IF
                  END DO
                  !$acc end loop
               END IF
               locol = lapw%nv(igSpin)+lapw%index_lo(lo,na)+nkvec !this is the column of the matrix
               IF (MOD(locol-1,fmpi%n_size) == fmpi%n_rank) THEN
                  locol=(locol-1)/fmpi%n_size+1 !this is the column in local storage!
                  k = lapw%kvec(nkvec,lo,na)
                  ! Calculate the overlap matrix elements with the regular Flapw
                  ! basis functions
                  !$acc loop vector private(fact2,dotp,kp) independent
                  DO kp = 1,lapwPr%nv(igSpinPr)
                     fact2 = con * fl2p1 * ( &
                           & fjgjPr%fj(kp,l,isp,igSpinPr)*(alo1(lo) &
                                                     & + clo1(lo)*ud%uulon(lo,ntyp,isp)) + &
                           & fjgjPr%gj(kp,l,isp,igSpinPr)*(blo1(lo)*ud%ddn(l,ntyp,isp) &
                                                     & + clo1(lo)*ud%dulon(lo,ntyp,isp)) )
                     dotp = dot_PRODUCT(lapw%gk(:,k,igSpin),lapwPr%gk(:,kp,igSpinPr))

                     IF (smat%l_real) THEN
                        smat%data_r(kp,locol) = smat%data_r(kp,locol) &
                                            & + chi * invsfct * fact2 * legpol(atoms%llo(lo,ntyp),dotp) &
                                            & * CONJG(cphPr(kp)) * cph(k)
                     ELSE
                        smat%data_c(kp,locol) = smat%data_c(kp,locol) &
                                            & + chi * invsfct * fact2 * legpol(atoms%llo(lo,ntyp),dotp) &
                                            & * CONJG(cphPr(kp)) * cph(k)
                     END IF
                  END DO
                  !$acc end loop
                  ! Calculate the overlap matrix elements with other local orbitals
                  ! of the same atom, if they have the same l
                  !$acc loop vector private(lp,fact3,nkvecp,kp,lorow,dotp) independent
                  DO lop = 1, MERGE(lo-1,atoms%nlo(ntyp),igSpinPr==igSpin.AND..NOT.l_fullj)
                     IF (lop==lo) CYCLE !Do later
                     lp = atoms%llo(lop,ntyp)
                     IF (l == lp) THEN
                        fact3 = con**2 * fl2p1 * ( &
                              & alo1(lop)*(alo1(lo) &
                                       & + clo1(lo)*ud%uulon(lo,ntyp,isp)) + &
                              & blo1(lop)*(blo1(lo)*ud%ddn(l,ntyp,isp) &
                                       & + clo1(lo)*ud%dulon(lo,ntyp,isp)) + &
                              & clo1(lop)*(alo1(lo)*ud%uulon(lop,ntyp,isp) &
                                       & + blo1(lo)*ud%dulon(lop,ntyp,isp) &
                                       & + clo1(lo)*ud%uloulopn(lop,lo,ntyp,isp)) )
                        DO nkvecp = 1,invsfct* (2*lp+1)
                           kp = lapwPr%kvec(nkvecp,lop,na)
                           lorow=lapwPr%nv(igSpinPr)+lapwPr%index_lo(lop,na)+nkvecp
                           dotp = dot_PRODUCT(lapw%gk(:,k,igSpin),lapwPr%gk(:,kp,igSpinPr))

                           IF (smat%l_real) THEN
                              smat%data_r(lorow,locol) = smat%data_r(lorow,locol) &
                                                     & + chi * invsfct * fact3 * legpol(atoms%llo(lo,ntyp),dotp) &
                                                     & * CONJG(cphPr(kp)) * cph(k)
                           ELSE
                              smat%data_c(lorow,locol) = smat%data_c(lorow,locol) &
                                                     & + chi * invsfct * fact3 * legpol(atoms%llo(lo,ntyp),dotp) &
                                                     & * CONJG(cphPr(kp)) * cph(k)
                           END IF
                        END DO
                     END IF
                  END DO
                  ! Calculate the overlap matrix elements of one local
                  ! orbital with itself
                  lop=lo
                  !$acc loop vector private(kp,lorow,dotp) independent
                  DO nkvecp = 1,MERGE(nkvec,invsfct* (2*l+1),igSpinPr==igSpin.AND..NOT.l_fullj)
                     kp = lapwPr%kvec(nkvecp,lo,na)
                     lorow = lapwPr%nv(igSpinPr)+lapwPr%index_lo(lo,na)+nkvecp
                     dotp = dot_PRODUCT(lapw%gk(:,k,igSpin),lapwPr%gk(:,kp,igSpinPr))

                     IF (smat%l_real) THEN
                        smat%data_r(lorow,locol) = smat%data_r(lorow,locol) &
                                               & + chi * invsfct * fact1 * legpol(l,dotp) &
                                               & * CONJG(cphPr(kp)) * cph(k)
                     ELSE
                        smat%data_c(lorow,locol) = smat%data_c(lorow,locol) &
                                               & + chi * invsfct * fact1 * legpol(l,dotp) &
                                               & * CONJG(cphPr(kp)) * cph(k)
                     END IF
                  END DO
                  !$acc end loop
               END IF ! mod(locol-1,n_size) = nrank
            END DO
            !$acc end loop
         END DO
         !$acc end loop
         !$acc end kernels
      END IF
    
   END SUBROUTINE slomat

   PURE REAL FUNCTION legpol(l,arg)
      !$acc routine seq

      IMPLICIT NONE

      REAL,INTENT(IN)   :: arg
      INTEGER,INTENT(IN):: l

      INTEGER :: lp

      REAL :: plegend(0:l)

      plegend(0) = 1.0
      IF (l.GE.1) THEN
         plegend(1) = arg
         DO lp = 1,l - 1
            plegend(lp+1) = (lp+lp+1)*arg*plegend(lp)/ (lp+1) -lp*plegend(lp-1)/ (lp+1)
         END DO
      END IF
      legpol = plegend(l)
   END FUNCTION legpol

END MODULE m_slomat
