
! Copyright (c) 2016 Peter Grünberg Institut, Forschungszentrum Jülich, Germany
! This file is part of FLEUR and available as free software under the conditions
! of the MIT license as expressed in the LICENSE file in more detail.
!--------------------------------------------------------------------------------

MODULE m_mpi_col_den
  !
  ! collect all data calculated in cdnval on different pe's on pe 0
  !
  ! for some data also spread them back onto all pe's (Jan. 2019  U.Alekseeva)
  !
#ifdef CPP_MPI
   use mpi
#endif
CONTAINS
  SUBROUTINE mpi_col_den(fmpi,sphhar,atoms ,stars,vacuum,input,noco,jspin,dos,vacdos,&
                         results,denCoeffs,orb,denCoeffsOffdiag,den,regCharges,mcd,slab,orbcomp,jDOS)

    USE m_types
    USE m_constants
    USE m_juDFT
    use m_types_mcd
    use m_types_slab
    use m_types_orbcomp
    use m_types_jDOS
    use m_types_vacdos
    IMPLICIT NONE

    TYPE(t_results),INTENT(INOUT):: results
    TYPE(t_mpi),INTENT(IN)       :: fmpi

    TYPE(t_input),INTENT(IN)     :: input
    TYPE(t_vacuum),INTENT(IN)    :: vacuum
    TYPE(t_noco),INTENT(IN)      :: noco
    TYPE(t_stars),INTENT(IN)     :: stars
    TYPE(t_sphhar),INTENT(IN)    :: sphhar
    TYPE(t_atoms),INTENT(IN)     :: atoms
    TYPE(t_potden),INTENT(INOUT) :: den
    ! ..
    ! ..  Scalar Arguments ..
    INTEGER, INTENT (IN) :: jspin
    ! ..
    ! ..  Array Arguments ..

    TYPE (t_orb),               INTENT(INOUT) :: orb
    TYPE (t_denCoeffs),         INTENT(INOUT) :: denCoeffs
    TYPE (t_denCoeffsOffdiag),  INTENT(INOUT) :: denCoeffsOffdiag
    TYPE (t_dos),               INTENT(INOUT) :: dos
    TYPE (t_vacdos),            INTENT(INOUT) :: vacdos
    TYPE (t_regionCharges), OPTIONAL, INTENT(INOUT) :: regCharges
    TYPE (t_mcd),     OPTIONAL, INTENT(INOUT) :: mcd
    TYPE (t_slab),    OPTIONAL, INTENT(INOUT) :: slab
    TYPE (t_orbcomp), OPTIONAL, INTENT(INOUT) :: orbcomp
    TYPE (t_jDOS),    OPTIONAL, INTENT(INOUT) :: jDOS
    ! ..
    ! ..  Local Scalars ..
    INTEGER :: n, i
    ! ..
    ! ..  Local Arrays ..
    INTEGER :: ierr
    COMPLEX, ALLOCATABLE :: c_b(:)
    REAL,    ALLOCATABLE :: r_b(:)
    INTEGER, ALLOCATABLE :: i_b(:)
    ! ..
    ! ..  External Subroutines
#ifdef CPP_MPI
    CALL timestart("mpi_col_den")

    ! -> Collect den%pw(:,jspin)
    n = stars%ng3
    ALLOCATE(c_b(n))
    CALL MPI_ALLREDUCE(den%pw(:,jspin),c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM,MPI_COMM_WORLD,ierr)
    CALL zcopy(n, c_b, 1, den%pw(:,jspin), 1)
    DEALLOCATE (c_b)

    ! -> Collect den%vacxy(:,:,:,jspin)
    IF (input%film) THEN
       n=size(den%vacxy(:,:,:,jspin))
       ALLOCATE(c_b(n))
       CALL MPI_REDUCE(den%vacxy(:,:,:,jspin),c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM,0, MPI_COMM_WORLD,ierr)
       IF (fmpi%irank.EQ.0) CALL zcopy(n, c_b, 1, den%vacxy(:,:,:,jspin), 1)
       DEALLOCATE (c_b)

       ! -> Collect den%vacz(:,:,jspin)
       !n = vacuum%nmzd*2
       n=size(den%vacz(:,:,jspin))
       ALLOCATE(r_b(n))
       CALL MPI_REDUCE(den%vacz(:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM,0, MPI_COMM_WORLD,ierr)
       IF (fmpi%irank.EQ.0) CALL dcopy(n, r_b, 1, den%vacz(:,:,jspin), 1)
       DEALLOCATE (r_b)
    ENDIF

    ! -> Collect uu(),ud() and dd()
    n = (atoms%lmaxd+1)*atoms%ntype
    ALLOCATE(r_b(n))
    CALL MPI_ALLREDUCE(denCoeffs%uu(0:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM,MPI_COMM_WORLD,ierr)
    CALL dcopy(n, r_b, 1, denCoeffs%uu(0:,:,jspin), 1)
    CALL MPI_ALLREDUCE(denCoeffs%du(0:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM,MPI_COMM_WORLD,ierr)
    CALL dcopy(n, r_b, 1, denCoeffs%du(0:,:,jspin), 1)
    CALL MPI_ALLREDUCE(denCoeffs%dd(0:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM,MPI_COMM_WORLD,ierr)
    CALL dcopy(n, r_b, 1, denCoeffs%dd(0:,:,jspin), 1)
    DEALLOCATE (r_b)

    ! Refactored stuff
    n = 4*(atoms%lmaxd+1)*atoms%ntype
    ALLOCATE(c_b(n))
    CALL MPI_ALLREDUCE(denCoeffs%mt_coeff(0:,:,0:1,0:1,jspin,jspin),c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM,MPI_COMM_WORLD,ierr)
    CALL zcopy(n, c_b, 1, denCoeffs%mt_coeff(0:,:,0:1,0:1,jspin,jspin), 1)
    DEALLOCATE (c_b)

    !--> Collect uunmt,udnmt,dunmt,ddnmt
    n = (((atoms%lmaxd*(atoms%lmaxd+3))/2)+1)*sphhar%nlhd*atoms%ntype
    ALLOCATE(r_b(n))
    CALL MPI_ALLREDUCE(denCoeffs%uunmt(0:,:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM,MPI_COMM_WORLD,ierr)
    CALL dcopy(n, r_b, 1, denCoeffs%uunmt(0:,:,:,jspin), 1)
    CALL MPI_ALLREDUCE(denCoeffs%udnmt(0:,:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM,MPI_COMM_WORLD,ierr)
    CALL dcopy(n, r_b, 1, denCoeffs%udnmt(0:,:,:,jspin), 1)
    CALL MPI_ALLREDUCE(denCoeffs%dunmt(0:,:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM,MPI_COMM_WORLD,ierr)
    CALL dcopy(n, r_b, 1, denCoeffs%dunmt(0:,:,:,jspin), 1)
    CALL MPI_ALLREDUCE(denCoeffs%ddnmt(0:,:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM,MPI_COMM_WORLD,ierr)
    CALL dcopy(n, r_b, 1, denCoeffs%ddnmt(0:,:,:,jspin), 1)
    DEALLOCATE (r_b)

    ! Refactored stuff
    n = 4*((atoms%lmaxd+1)**2)*sphhar%nlhd*atoms%ntype
    ALLOCATE(c_b(n))
    CALL MPI_ALLREDUCE(denCoeffs%nmt_coeff(0:,:,:,0:1,0:1,jspin,jspin),c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM,MPI_COMM_WORLD,ierr)
    CALL zcopy(n, c_b, 1, denCoeffs%nmt_coeff(0:,:,:,0:1,0:1,jspin,jspin), 1)
    DEALLOCATE (c_b)

    IF (PRESENT(regCharges)) THEN
      !--> ener & sqal
      n=4*atoms%ntype
      ALLOCATE(r_b(n))
      CALL MPI_ALLREDUCE(regCharges%ener(0:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM,MPI_COMM_WORLD,ierr)
      CALL dcopy(n, r_b, 1, regCharges%ener(0:,:,jspin), 1)
      CALL MPI_ALLREDUCE(regCharges%sqal(0:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM,MPI_COMM_WORLD,ierr)
      CALL dcopy(n, r_b, 1, regCharges%sqal(0:,:,jspin), 1)
      DEALLOCATE (r_b)

      !--> svac & pvac
      IF ( input%film ) THEN
         n=SIZE(regCharges%svac,1)
         ALLOCATE(r_b(n))
         CALL MPI_ALLREDUCE(regCharges%svac(:,jspin),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM,MPI_COMM_WORLD,ierr)
         CALL dcopy(n, r_b, 1, regCharges%svac(:,jspin), 1)
         CALL MPI_ALLREDUCE(regCharges%pvac(:,jspin),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM,MPI_COMM_WORLD,ierr)
         CALL dcopy(n, r_b, 1, regCharges%pvac(:,jspin), 1)
         DEALLOCATE (r_b)
       END IF
    END IF

    !collect DOS stuff
    n = SIZE(dos%jsym,1)*SIZE(dos%jsym,2)
    ALLOCATE(i_b(n))
    CALL MPI_REDUCE(dos%jsym(:,:,jspin),i_b,n,MPI_INTEGER,MPI_SUM,0, MPI_COMM_WORLD,ierr)
    IF (fmpi%irank.EQ.0) THEN
       DO i = 1, SIZE(dos%jsym,2)
          dos%jsym(:,i,jspin) = i_b((i-1)*SIZE(dos%jsym,1)+1:i*SIZE(dos%jsym,1))
       END DO
    END IF
    DEALLOCATE (i_b)

    n = SIZE(dos%qis,1)*SIZE(dos%qis,2)
    ALLOCATE(r_b(n))
    CALL MPI_REDUCE(dos%qis(:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM,0, MPI_COMM_WORLD,ierr)
    IF (fmpi%irank.EQ.0) CALL dcopy(n, r_b, 1, dos%qis(:,:,jspin), 1)
    DEALLOCATE (r_b)

    n = SIZE(dos%qTot,1)*SIZE(dos%qTot,2)
    ALLOCATE(r_b(n))
    CALL MPI_REDUCE(dos%qTot(:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM,0, MPI_COMM_WORLD,ierr)
    IF (fmpi%irank.EQ.0) CALL dcopy(n, r_b, 1, dos%qTot(:,:,jspin), 1)
    DEALLOCATE (r_b)

    n = SIZE(dos%qal,1)*SIZE(dos%qal,2)*SIZE(dos%qal,3)*SIZE(dos%qal,4)
    ALLOCATE(r_b(n))
    CALL MPI_REDUCE(dos%qal(0:,:,:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM,0, MPI_COMM_WORLD,ierr)
    IF (fmpi%irank.EQ.0) CALL dcopy(n, r_b, 1, dos%qal(0:,:,:,:,jspin), 1)
    DEALLOCATE (r_b)

    n = SIZE(vacdos%qvac,1)*SIZE(vacdos%qvac,2)*SIZE(vacdos%qvac,3)
    ALLOCATE(r_b(n))
    CALL MPI_REDUCE(vacdos%qvac(:,:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM,0, MPI_COMM_WORLD,ierr)
    IF (fmpi%irank.EQ.0) CALL dcopy(n, r_b, 1, vacdos%qvac(:,:,:,jspin), 1)
    DEALLOCATE (r_b)

    n = SIZE(vacdos%qvlay,1)*SIZE(vacdos%qvlay,2)*SIZE(vacdos%qvlay,3)*SIZE(vacdos%qvlay,4)
    ALLOCATE(r_b(n))
    CALL MPI_REDUCE(vacdos%qvlay(:,:,:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM,0, MPI_COMM_WORLD,ierr)
    IF (fmpi%irank.EQ.0) CALL dcopy(n, r_b, 1, vacdos%qvlay(:,:,:,:,jspin), 1)
    DEALLOCATE (r_b)

    n = SIZE(vacdos%qstars,1)*SIZE(vacdos%qstars,2)*SIZE(vacdos%qstars,3)*SIZE(vacdos%qstars,4)*SIZE(vacdos%qstars,5)
    ALLOCATE(c_b(n))
    CALL MPI_REDUCE(vacdos%qstars(:,:,:,:,:,jspin),c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM,0, MPI_COMM_WORLD,ierr)
    IF (fmpi%irank.EQ.0) CALL zcopy(n, c_b, 1, vacdos%qstars(:,:,:,:,:,jspin), 1)
    DEALLOCATE (c_b)

    ! Collect mcd%mcd
    IF (PRESENT(mcd)) THEN
       n = SIZE(mcd%mcd,1)*SIZE(mcd%mcd,2)*SIZE(mcd%mcd,3)*SIZE(mcd%mcd,4)
       ALLOCATE(r_b(n))
       CALL MPI_REDUCE(mcd%mcd(:,:,:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM,0, MPI_COMM_WORLD,ierr)
       IF (fmpi%irank.EQ.0) CALL dcopy(n, r_b, 1, mcd%mcd(:,:,:,:,jspin), 1)
       DEALLOCATE (r_b)
    END IF

    ! Collect slab - qintsl and qmtsl
    IF (PRESENT(slab)) THEN
       n = SIZE(slab%qintsl,1)*SIZE(slab%qintsl,2)*SIZE(slab%qintsl,3)
       ALLOCATE(r_b(n))
       CALL MPI_REDUCE(slab%qintsl(:,:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM,0, MPI_COMM_WORLD,ierr)
       IF (fmpi%irank.EQ.0) CALL dcopy(n, r_b, 1, slab%qintsl(:,:,:,jspin), 1)
       DEALLOCATE (r_b)

       n = SIZE(slab%qmtsl,1)*SIZE(slab%qmtsl,2)*SIZE(slab%qmtsl,3)
       ALLOCATE(r_b(n))
       CALL MPI_REDUCE(slab%qmtsl(:,:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM,0, MPI_COMM_WORLD,ierr)
       IF (fmpi%irank.EQ.0) CALL dcopy(n, r_b, 1, slab%qmtsl(:,:,:,jspin), 1)
       DEALLOCATE (r_b)
    END IF

    ! Collect orbcomp - comp and qmtp
    IF (PRESENT(orbcomp)) THEN
       n = SIZE(orbcomp%comp,1)*SIZE(orbcomp%comp,2)*SIZE(orbcomp%comp,3)*SIZE(orbcomp%comp,4)
       ALLOCATE(r_b(n))
       CALL MPI_REDUCE(orbcomp%comp(:,:,:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM,0, MPI_COMM_WORLD,ierr)
       IF (fmpi%irank.EQ.0) CALL dcopy(n, r_b, 1, orbcomp%comp(:,:,:,:,jspin), 1)
       DEALLOCATE (r_b)

       n = SIZE(orbcomp%qmtp,1)*SIZE(orbcomp%qmtp,2)*SIZE(orbcomp%qmtp,3)
       ALLOCATE(r_b(n))
       CALL MPI_REDUCE(orbcomp%qmtp(:,:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM,0, MPI_COMM_WORLD,ierr)
       IF (fmpi%irank.EQ.0) CALL dcopy(n, r_b, 1, orbcomp%qmtp(:,:,:,jspin), 1)
       DEALLOCATE (r_b)
    END IF

    !+jDOS
    IF(PRESENT(jDOS)) THEN
      IF(jspin.EQ.1) THEN

        n = SIZE(jDOS%comp)
        ALLOCATE(r_b(n))
        CALL MPI_REDUCE(jDOS%comp,r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM,0,MPI_COMM_WORLD,ierr)
        IF(fmpi%irank.EQ.0) CALL dcopy(n,r_b,1,jDOS%comp,1)
        DEALLOCATE(r_b)

        n = SIZE(jDOS%qmtp)
        ALLOCATE(r_b(n))
        CALL MPI_REDUCE(jDOS%qmtp,r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM,0,MPI_COMM_WORLD,ierr)
        IF(fmpi%irank.EQ.0) CALL dcopy(n,r_b,1,jDOS%qmtp,1)
        DEALLOCATE(r_b)

        n = SIZE(jDOS%occ)
        ALLOCATE(r_b(n))
        CALL MPI_REDUCE(jDOS%occ,r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM,0,MPI_COMM_WORLD,ierr)
        IF(fmpi%irank.EQ.0) CALL dcopy(n,r_b,1,jDOS%occ,1)
        DEALLOCATE(r_b)

      ENDIF
    ENDIF
    !-jDOS

    ! -> Collect force
    IF (input%l_f) THEN
       n=3*atoms%ntype
       ALLOCATE(r_b(n))
       CALL MPI_REDUCE(results%force(1,1,jspin),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM,0, MPI_COMM_WORLD,ierr)
       IF (fmpi%irank.EQ.0) CALL dcopy(n, r_b, 1, results%force(1,1,jspin), 1)
       DEALLOCATE (r_b)
    ENDIF

    ! -> Optional the LO-coefficients: aclo,bclo,enerlo,cclo,acnmt,bcnmt,ccnmt
    IF (atoms%nlod.GE.1) THEN

       n=atoms%nlod*atoms%ntype
       ALLOCATE (r_b(n))
       CALL MPI_ALLREDUCE(denCoeffs%aclo(:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM, MPI_COMM_WORLD,ierr)
       CALL dcopy(n, r_b, 1, denCoeffs%aclo(:,:,jspin), 1)
       CALL MPI_ALLREDUCE(denCoeffs%bclo(:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM, MPI_COMM_WORLD,ierr)
       CALL dcopy(n, r_b, 1, denCoeffs%bclo(:,:,jspin), 1)
       IF (PRESENT(regCharges)) THEN
         CALL MPI_ALLREDUCE(regCharges%enerlo(:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM,MPI_COMM_WORLD,ierr)
         CALL dcopy(n, r_b, 1, regCharges%enerlo(:,:,jspin), 1)
         CALL MPI_ALLREDUCE(regCharges%sqlo(:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM,MPI_COMM_WORLD,ierr)
         CALL dcopy(n, r_b, 1, regCharges%sqlo(:,:,jspin), 1)
       END IF
       DEALLOCATE (r_b)

       ! Refactored stuff
       n=2*atoms%nlod*atoms%ntype
       ALLOCATE (c_b(n))
       CALL MPI_ALLREDUCE(denCoeffs%mt_ulo_coeff(:,:,0:1,jspin,jspin),c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM, MPI_COMM_WORLD,ierr)
       CALL zcopy(n, c_b, 1, denCoeffs%mt_ulo_coeff(:,:,0:1,jspin,jspin), 1)
       CALL MPI_ALLREDUCE(denCoeffs%mt_lou_coeff(:,:,0:1,jspin,jspin),c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM, MPI_COMM_WORLD,ierr)
       CALL zcopy(n, c_b, 1, denCoeffs%mt_lou_coeff(:,:,0:1,jspin,jspin), 1)
       DEALLOCATE (c_b)

       n = atoms%nlod * atoms%nlod * atoms%ntype
       ALLOCATE (r_b(n))
       CALL MPI_ALLREDUCE(denCoeffs%cclo(:,:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM, MPI_COMM_WORLD,ierr)
       CALL dcopy(n, r_b, 1, denCoeffs%cclo(:,:,:,jspin), 1)
       DEALLOCATE (r_b)

       ! Refactored stuff
       n = atoms%nlod * atoms%nlod * atoms%ntype
       ALLOCATE (c_b(n))
       CALL MPI_ALLREDUCE(denCoeffs%mt_lolo_coeff(:,:,:,jspin,jspin),c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM, MPI_COMM_WORLD,ierr)
       CALL zcopy(n, c_b, 1, denCoeffs%mt_lolo_coeff(:,:,:,jspin,jspin), 1)
       DEALLOCATE (c_b)

       n = (atoms%lmaxd+1) * atoms%ntype * atoms%nlod * sphhar%nlhd
       ALLOCATE (r_b(n))
       CALL MPI_ALLREDUCE(denCoeffs%acnmt(0:,:,:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM, MPI_COMM_WORLD,ierr)
       CALL dcopy(n, r_b, 1, denCoeffs%acnmt(0:,:,:,:,jspin), 1)
       CALL MPI_ALLREDUCE(denCoeffs%bcnmt(0:,:,:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM, MPI_COMM_WORLD,ierr)
       CALL dcopy(n, r_b, 1, denCoeffs%bcnmt(0:,:,:,:,jspin), 1)
       DEALLOCATE (r_b)

       ! Refactored stuff
       n=2*atoms%nlod*atoms%ntype*(atoms%lmaxd+1)*sphhar%nlhd
       ALLOCATE (c_b(n))
       CALL MPI_ALLREDUCE(denCoeffs%nmt_ulo_coeff(0:,:,:,:,0:1,jspin,jspin),c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM, MPI_COMM_WORLD,ierr)
       CALL zcopy(n, c_b, 1, denCoeffs%nmt_ulo_coeff(0:,:,:,:,0:1,jspin,jspin), 1)
       CALL MPI_ALLREDUCE(denCoeffs%nmt_lou_coeff(0:,:,:,:,0:1,jspin,jspin),c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM, MPI_COMM_WORLD,ierr)
       CALL zcopy(n, c_b, 1, denCoeffs%nmt_lou_coeff(0:,:,:,:,0:1,jspin,jspin), 1)
       DEALLOCATE (c_b)

       n = atoms%ntype * sphhar%nlhd * atoms%nlod**2
       ALLOCATE (r_b(n))
       CALL MPI_ALLREDUCE(denCoeffs%ccnmt(:,:,:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM, MPI_COMM_WORLD,ierr)
       CALL dcopy(n, r_b, 1, denCoeffs%ccnmt(:,:,:,:,jspin), 1)
       DEALLOCATE (r_b)

       ! Refactored stuff
       n = atoms%ntype * sphhar%nlhd * atoms%nlod**2
       ALLOCATE (c_b(n))
       CALL MPI_ALLREDUCE(denCoeffs%nmt_lolo_coeff(:,:,:,:,jspin,jspin),c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM, MPI_COMM_WORLD,ierr)
       CALL zcopy(n, c_b, 1, denCoeffs%nmt_lolo_coeff(:,:,:,:,jspin,jspin), 1)
       DEALLOCATE (c_b)

    ENDIF

    ! ->  Now the SOC - stuff: orb, orblo and orblo
    IF (noco%l_soc) THEN
       ! orb
       n=(atoms%lmaxd+1)*(2*atoms%lmaxd+1)*atoms%ntype
       ALLOCATE (r_b(n))
       CALL MPI_ALLREDUCE(orb%uu(:,:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION, MPI_SUM,MPI_COMM_WORLD,ierr)
       CALL dcopy(n, r_b, 1, orb%uu(:,:,:,jspin), 1)
       CALL MPI_ALLREDUCE(orb%dd(:,:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION, MPI_SUM,MPI_COMM_WORLD,ierr)
       CALL dcopy(n, r_b, 1, orb%dd(:,:,:,jspin), 1)
       DEALLOCATE (r_b)

       ALLOCATE (c_b(n))
       CALL MPI_ALLREDUCE(orb%uup(:,:,:,jspin),c_b,n,MPI_DOUBLE_COMPLEX, MPI_SUM,MPI_COMM_WORLD,ierr)
       CALL zcopy(n, c_b, 1, orb%uup(:,:,:,jspin), 1)
       CALL MPI_ALLREDUCE(orb%ddp(:,:,:,jspin),c_b,n,MPI_DOUBLE_COMPLEX, MPI_SUM,MPI_COMM_WORLD,ierr)
       CALL zcopy(n, c_b, 1, orb%ddp(:,:,:,jspin), 1)
       CALL MPI_ALLREDUCE(orb%uum(:,:,:,jspin),c_b,n,MPI_DOUBLE_COMPLEX, MPI_SUM,MPI_COMM_WORLD,ierr)
       CALL zcopy(n, c_b, 1, orb%uum(:,:,:,jspin), 1)
       CALL MPI_ALLREDUCE(orb%ddm(:,:,:,jspin),c_b,n,MPI_DOUBLE_COMPLEX, MPI_SUM,MPI_COMM_WORLD,ierr)
       CALL zcopy(n, c_b, 1, orb%ddm(:,:,:,jspin), 1)
       DEALLOCATE (c_b)

       n = atoms%nlod * (2*atoms%llod+1) * atoms%ntype
       ALLOCATE (r_b(n))
       CALL MPI_ALLREDUCE(orb%uulo(:,:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION, MPI_SUM,MPI_COMM_WORLD,ierr)
       CALL dcopy(n, r_b, 1, orb%uulo(:,:,:,jspin), 1)
       CALL MPI_ALLREDUCE(orb%dulo(:,:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION, MPI_SUM,MPI_COMM_WORLD,ierr)
       CALL dcopy(n, r_b, 1, orb%dulo(:,:,:,jspin), 1)
       DEALLOCATE (r_b)

       ALLOCATE (c_b(n))
       CALL MPI_ALLREDUCE(orb%uulop(:,:,:,jspin),c_b,n,MPI_DOUBLE_COMPLEX, MPI_SUM,MPI_COMM_WORLD,ierr)
       CALL zcopy(n, c_b, 1, orb%uulop(:,:,:,jspin), 1)
       CALL MPI_ALLREDUCE(orb%dulop(:,:,:,jspin),c_b,n,MPI_DOUBLE_COMPLEX, MPI_SUM,MPI_COMM_WORLD,ierr)
       CALL zcopy(n, c_b, 1, orb%dulop(:,:,:,jspin), 1)
       CALL MPI_ALLREDUCE(orb%uulom(:,:,:,jspin),c_b,n,MPI_DOUBLE_COMPLEX, MPI_SUM,MPI_COMM_WORLD,ierr)
       CALL zcopy(n, c_b, 1, orb%uulom(:,:,:,jspin), 1)
       CALL MPI_ALLREDUCE(orb%dulom(:,:,:,jspin),c_b,n,MPI_DOUBLE_COMPLEX, MPI_SUM,MPI_COMM_WORLD,ierr)
       CALL zcopy(n, c_b, 1, orb%dulom(:,:,:,jspin), 1)
       DEALLOCATE (c_b)

       n = atoms%nlod * atoms%nlod * (2*atoms%llod+1) * atoms%ntype
       ALLOCATE (r_b(n))
       CALL MPI_ALLREDUCE(orb%z(:,:,:,:,jspin),r_b,n,MPI_DOUBLE_PRECISION, MPI_SUM,MPI_COMM_WORLD,ierr)
       CALL dcopy(n, r_b, 1, orb%z(:,:,:,:,jspin), 1)
       DEALLOCATE (r_b)

       ALLOCATE (c_b(n))
       CALL MPI_ALLREDUCE(orb%p(:,:,:,:,jspin),c_b,n,MPI_DOUBLE_COMPLEX, MPI_SUM,MPI_COMM_WORLD,ierr)
       CALL zcopy(n, c_b, 1, orb%p(:,:,:,:,jspin), 1)
       CALL MPI_ALLREDUCE(orb%m(:,:,:,:,jspin),c_b,n,MPI_DOUBLE_COMPLEX, MPI_SUM,MPI_COMM_WORLD,ierr)
       CALL zcopy(n, c_b, 1, orb%m(:,:,:,:,jspin), 1)
       DEALLOCATE (c_b)

    ENDIF

    ! -> Collect the noco stuff:
    IF ( noco%l_noco .AND. jspin.EQ.1 ) THEN

       n = stars%ng3
       ALLOCATE(c_b(n))
       CALL MPI_REDUCE(den%pw(:,3),c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM,0, MPI_COMM_WORLD,ierr)
       IF (fmpi%irank.EQ.0) THEN
          den%pw(:,3)=RESHAPE(c_b,(/n/))
       ENDIF
       DEALLOCATE (c_b)
       !
       IF (input%film) THEN

          n=size(den%vacxy(:,:,:,3))
          ALLOCATE(c_b(n))
          CALL MPI_REDUCE(den%vacxy(:,:,:,3),c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM,0, MPI_COMM_WORLD,ierr)
          IF (fmpi%irank.EQ.0) THEN
             CALL zcopy(n, c_b, 1, den%vacxy(:,:,:,3), 1)
          ENDIF
          DEALLOCATE (c_b)
          !
          !n = vacuum%nmzd*2*2
          n=SIZE(den%vacz(:,:,3:4))
          ALLOCATE(r_b(n))
          CALL MPI_REDUCE(den%vacz(:,:,3:4),r_b,n,MPI_DOUBLE_PRECISION,MPI_SUM,0, MPI_COMM_WORLD,ierr)
          IF (fmpi%irank.EQ.0) THEN
             den%vacz(:,:,3:4)=RESHAPE(r_b,SHAPE(den%vacz(:,:,3:4)))
          ENDIF
          DEALLOCATE (r_b)

       ENDIF ! input%film


       IF (noco%l_mperp) THEN

          ! -->     for (spin)-off diagonal part of muffin-tin
          n = (atoms%lmaxd+1) * atoms%ntype ! TODO: Why not from 0: in l-index?
          ALLOCATE(c_b(n))
          CALL MPI_ALLREDUCE(denCoeffsOffdiag%uu21(:,:),c_b,n,MPI_DOUBLE_COMPLEX, MPI_SUM,MPI_COMM_WORLD,ierr)
          CALL zcopy(n, c_b, 1, denCoeffsOffdiag%uu21(:,:), 1)
          CALL MPI_ALLREDUCE(denCoeffsOffdiag%ud21(:,:),c_b,n,MPI_DOUBLE_COMPLEX, MPI_SUM,MPI_COMM_WORLD,ierr)
          CALL zcopy(n, c_b, 1, denCoeffsOffdiag%ud21(:,:), 1)
          CALL MPI_ALLREDUCE(denCoeffsOffdiag%du21(:,:),c_b,n,MPI_DOUBLE_COMPLEX, MPI_SUM,MPI_COMM_WORLD,ierr)
          CALL zcopy(n, c_b, 1, denCoeffsOffdiag%du21(:,:), 1)
          CALL MPI_ALLREDUCE(denCoeffsOffdiag%dd21(:,:),c_b,n,MPI_DOUBLE_COMPLEX, MPI_SUM,MPI_COMM_WORLD,ierr)
          CALL zcopy(n, c_b, 1, denCoeffsOffdiag%dd21(:,:), 1)
          DEALLOCATE (c_b)

          ! Refactored stuff
          n = 4*(atoms%lmaxd+1)*atoms%ntype
          ALLOCATE(c_b(n))
          CALL MPI_ALLREDUCE(denCoeffs%mt_coeff(0:,:,0:1,0:1,2,1),c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM,MPI_COMM_WORLD,ierr)
          CALL zcopy(n, c_b, 1, denCoeffs%mt_coeff(0:,:,0:1,0:1,2,1), 1)
          CALL MPI_ALLREDUCE(denCoeffs%mt_coeff(0:,:,0:1,0:1,1,2),c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM,MPI_COMM_WORLD,ierr)
          CALL zcopy(n, c_b, 1, denCoeffs%mt_coeff(0:,:,0:1,0:1,1,2), 1)
          DEALLOCATE (c_b)

          ! -->     lo,u coeff's:
          n = atoms%nlod * atoms%ntype
          ALLOCATE(c_b(n))
          CALL MPI_ALLREDUCE(denCoeffsOffdiag%uulo21(:,:),c_b,n,MPI_DOUBLE_COMPLEX, MPI_SUM,MPI_COMM_WORLD,ierr)
          CALL zcopy(n, c_b, 1, denCoeffsOffdiag%uulo21(:,:), 1)
          CALL MPI_ALLREDUCE(denCoeffsOffdiag%ulou21(:,:),c_b,n,MPI_DOUBLE_COMPLEX, MPI_SUM,MPI_COMM_WORLD,ierr)
          CALL zcopy(n, c_b, 1, denCoeffsOffdiag%ulou21(:,:), 1)
          CALL MPI_ALLREDUCE(denCoeffsOffdiag%dulo21(:,:),c_b,n,MPI_DOUBLE_COMPLEX, MPI_SUM,MPI_COMM_WORLD,ierr)
          CALL zcopy(n, c_b, 1, denCoeffsOffdiag%dulo21(:,:), 1)
          CALL MPI_ALLREDUCE(denCoeffsOffdiag%ulod21(:,:),c_b,n,MPI_DOUBLE_COMPLEX, MPI_SUM,MPI_COMM_WORLD,ierr)
          CALL zcopy(n, c_b, 1, denCoeffsOffdiag%ulod21(:,:), 1)
          DEALLOCATE (c_b)

          ! Refactored stuff
          n=2*atoms%nlod*atoms%ntype
          ALLOCATE (c_b(n))
          CALL MPI_ALLREDUCE(denCoeffs%mt_ulo_coeff(:,:,0:1,2,1),c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM, MPI_COMM_WORLD,ierr)
          CALL zcopy(n, c_b, 1, denCoeffs%mt_ulo_coeff(:,:,0:1,2,1), 1)
          CALL MPI_ALLREDUCE(denCoeffs%mt_lou_coeff(:,:,0:1,2,1),c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM, MPI_COMM_WORLD,ierr)
          CALL zcopy(n, c_b, 1, denCoeffs%mt_lou_coeff(:,:,0:1,2,1), 1)
          CALL MPI_ALLREDUCE(denCoeffs%mt_ulo_coeff(:,:,0:1,1,2),c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM, MPI_COMM_WORLD,ierr)
          CALL zcopy(n, c_b, 1, denCoeffs%mt_ulo_coeff(:,:,0:1,1,2), 1)
          CALL MPI_ALLREDUCE(denCoeffs%mt_lou_coeff(:,:,0:1,1,2),c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM, MPI_COMM_WORLD,ierr)
          CALL zcopy(n, c_b, 1, denCoeffs%mt_lou_coeff(:,:,0:1,1,2), 1)
          DEALLOCATE (c_b)

          ! -->     lo,lo' coeff's:
          n = atoms%nlod*atoms%nlod*atoms%ntype
          ALLOCATE(c_b(n))
          CALL MPI_ALLREDUCE(denCoeffsOffdiag%uloulop21,c_b,n,MPI_DOUBLE_COMPLEX, MPI_SUM,MPI_COMM_WORLD,ierr)
          CALL zcopy(n, c_b, 1, denCoeffsOffdiag%uloulop21, 1)
          DEALLOCATE (c_b)

          ! Refactored stuff
          n = atoms%nlod * atoms%nlod * atoms%ntype
          ALLOCATE (c_b(n))
          CALL MPI_ALLREDUCE(denCoeffs%mt_lolo_coeff(:,:,:,2,1),c_b,n,MPI_DOUBLE_PRECISION,MPI_SUM, MPI_COMM_WORLD,ierr)
          CALL zcopy(n, c_b, 1, denCoeffs%mt_lolo_coeff(:,:,:,2,1), 1)
          CALL MPI_ALLREDUCE(denCoeffs%mt_lolo_coeff(:,:,:,1,2),c_b,n,MPI_DOUBLE_PRECISION,MPI_SUM, MPI_COMM_WORLD,ierr)
          CALL zcopy(n, c_b, 1, denCoeffs%mt_lolo_coeff(:,:,:,1,2), 1)
          DEALLOCATE (c_b)

          IF (denCoeffsOffdiag%l_fmpl) THEN

             !-->        Full magnetization plots: Collect uunmt21, etc.
             n = (atoms%lmaxd+1)**2 *sphhar%nlhd*atoms%ntype
             ALLOCATE(c_b(n))
             CALL MPI_ALLREDUCE(denCoeffsOffdiag%uunmt21,c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM,MPI_COMM_WORLD,ierr)
             CALL zcopy(n, c_b, 1, denCoeffsOffdiag%uunmt21, 1)
             CALL MPI_ALLREDUCE(denCoeffsOffdiag%udnmt21,c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM,MPI_COMM_WORLD,ierr)
             CALL zcopy(n, c_b, 1, denCoeffsOffdiag%udnmt21, 1)
             CALL MPI_ALLREDUCE(denCoeffsOffdiag%dunmt21,c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM,MPI_COMM_WORLD,ierr)
             CALL zcopy(n, c_b, 1, denCoeffsOffdiag%dunmt21, 1)
             CALL MPI_ALLREDUCE(denCoeffsOffdiag%ddnmt21,c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM,MPI_COMM_WORLD,ierr)
             CALL zcopy(n, c_b, 1, denCoeffsOffdiag%ddnmt21, 1)
             DEALLOCATE (c_b)

             ! Refactored stuff
             n = 4*((atoms%lmaxd+1)**2)*sphhar%nlhd*atoms%ntype
             ALLOCATE(c_b(n))
             CALL MPI_ALLREDUCE(denCoeffs%nmt_coeff(0:,:,:,0:1,0:1,2,1),c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM,MPI_COMM_WORLD,ierr)
             CALL zcopy(n, c_b, 1, denCoeffs%nmt_coeff(0:,:,:,0:1,0:1,2,1), 1)
             CALL MPI_ALLREDUCE(denCoeffs%nmt_coeff(0:,:,:,0:1,0:1,1,2),c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM,MPI_COMM_WORLD,ierr)
             CALL zcopy(n, c_b, 1, denCoeffs%nmt_coeff(0:,:,:,0:1,0:1,1,2), 1)
             DEALLOCATE (c_b)

             ! Refactored stuff
             n=2*atoms%nlod*atoms%ntype*(atoms%lmaxd+1)*sphhar%nlhd
             ALLOCATE (c_b(n))
             CALL MPI_ALLREDUCE(denCoeffs%nmt_ulo_coeff(0:,:,:,:,0:1,2,1),c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM, MPI_COMM_WORLD,ierr)
             CALL zcopy(n, c_b, 1, denCoeffs%nmt_ulo_coeff(0:,:,:,:,0:1,2,1), 1)
             CALL MPI_ALLREDUCE(denCoeffs%nmt_lou_coeff(0:,:,:,:,0:1,2,1),c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM, MPI_COMM_WORLD,ierr)
             CALL zcopy(n, c_b, 1, denCoeffs%nmt_lou_coeff(0:,:,:,:,0:1,2,1), 1)
             CALL MPI_ALLREDUCE(denCoeffs%nmt_ulo_coeff(0:,:,:,:,0:1,1,2),c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM, MPI_COMM_WORLD,ierr)
             CALL zcopy(n, c_b, 1, denCoeffs%nmt_ulo_coeff(0:,:,:,:,0:1,1,2), 1)
             CALL MPI_ALLREDUCE(denCoeffs%nmt_lou_coeff(0:,:,:,:,0:1,1,2),c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM, MPI_COMM_WORLD,ierr)
             CALL zcopy(n, c_b, 1, denCoeffs%nmt_lou_coeff(0:,:,:,:,0:1,1,2), 1)
             DEALLOCATE (c_b)

             ! Refactored stuff
             n = atoms%ntype * sphhar%nlhd * atoms%nlod**2
             ALLOCATE (c_b(n))
             CALL MPI_ALLREDUCE(denCoeffs%nmt_lolo_coeff(:,:,:,:,2,1),c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM, MPI_COMM_WORLD,ierr)
             CALL zcopy(n, c_b, 1, denCoeffs%nmt_lolo_coeff(:,:,:,:,2,1), 1)
             CALL MPI_ALLREDUCE(denCoeffs%nmt_lolo_coeff(:,:,:,:,1,2),c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM, MPI_COMM_WORLD,ierr)
             CALL zcopy(n, c_b, 1, denCoeffs%nmt_lolo_coeff(:,:,:,:,1,2), 1)
             DEALLOCATE (c_b)

          ENDIF ! fmpl
       ENDIF  ! mperp
    ENDIF   ! noco

    !+lda+U
    IF ( atoms%n_u.GT.0 ) THEN
       n = 49*atoms%n_u
       ALLOCATE(c_b(n))
       CALL MPI_REDUCE(den%mmpMat(:,:,1:atoms%n_u,jspin),c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM,0, MPI_COMM_WORLD,ierr)
       IF (fmpi%irank.EQ.0) THEN
          CALL zcopy(n, c_b, 1, den%mmpMat(:,:,1:atoms%n_u,jspin), 1)
       ENDIF
       DEALLOCATE (c_b)
       IF(noco%l_mperp.AND.jspin.EQ.1) THEN
         n = 49*atoms%n_u
         ALLOCATE(c_b(n))
         CALL MPI_REDUCE(den%mmpMat(:,:,1:atoms%n_u,3),c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM,0, MPI_COMM_WORLD,ierr)
         IF (fmpi%irank.EQ.0) THEN
            CALL zcopy(n, c_b, 1, den%mmpMat(:,:,1:atoms%n_u,3), 1)
         ENDIF
         DEALLOCATE (c_b)
       ENDIF
    ENDIF
    !-lda+U

    !+lda+OP
    IF ( atoms%n_opc.GT.0 ) THEN
      n = 49*atoms%n_opc
      ALLOCATE(c_b(n))
      CALL MPI_REDUCE(den%mmpMat(:,:,atoms%n_u+atoms%n_hia+1:,jspin),c_b,n,MPI_DOUBLE_COMPLEX,MPI_SUM,0, MPI_COMM_WORLD,ierr)
      IF (fmpi%irank.EQ.0) THEN
         CALL zcopy(n, c_b, 1, den%mmpMat(:,:,atoms%n_u+atoms%n_hia+1:,jspin), 1)
      ENDIF
      DEALLOCATE (c_b)
   ENDIF
   !-lda+U

    CALL timestop("mpi_col_den")

#endif

  END SUBROUTINE mpi_col_den
END MODULE m_mpi_col_den
