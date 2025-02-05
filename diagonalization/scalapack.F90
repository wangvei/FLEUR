!--------------------------------------------------------------------------------
! Copyright (c) 2016 Peter Grünberg Institut, Forschungszentrum Jülich, Germany
! This file is part of FLEUR and available as free software under the conditions
! of the MIT license as expressed in the LICENSE file in more detail.
!--------------------------------------------------------------------------------
#ifdef FLEUR_USE_SCOREP
#include 'scorep/SCOREP_User.inc'
#endif
MODULE m_scalapack
CONTAINS
  SUBROUTINE scalapack(hmat,smat,ne,eig,ev)
    !
    !----------------------------------------------------
    !- Parallel eigensystem solver - driver routine; gb99
    !  Uses the SCALAPACK for the actual diagonalization
    !
    ! hmat ..... Hamiltonian matrix
    ! smat ..... overlap matrix
    ! ne ....... number of ev's searched (and found) on this node
    !            On input, overall number of ev's searched,
    !            On output, local number of ev's found
    ! eig ...... all eigenvalues, output
    ! ev ....... local eigenvectors, output
    !
    !----------------------------------------------------
    !
    USE m_juDFT
    USE m_constants
    USE m_types_mpimat
    USE m_types_mat
#ifdef CPP_MPI
    USE mpi
#endif
    IMPLICIT NONE
    CLASS(t_mat),INTENT(INOUT)    :: hmat,smat
    CLASS(t_mat),ALLOCATABLE,INTENT(OUT)::ev
    REAL,INTENT(out)              :: eig(:)
    INTEGER,INTENT(INOUT)         :: ne
    
    
#ifdef CPP_SCALAPACK
    !...  Local variables
    !
    INTEGER i , ierr, err
    INTEGER, ALLOCATABLE :: iwork(:)
    REAL,    ALLOCATABLE :: rwork(:)
    INTEGER              :: lrwork

    !
    !  ScaLAPACK things
    CHARACTER (len=1)    :: uplo
    INTEGER              :: num,num1,num2,liwork,lwork2,np0,mq0,np,myid
    INTEGER              :: iceil, numroc, nn, nb
    INTEGER, ALLOCATABLE :: ifail(:), iclustr(:)
    REAL                 :: abstol,orfac=1.E-4,dlamch
    REAL,ALLOCATABLE     :: eig2(:), gap(:)
    REAL,    ALLOCATABLE :: work2_r(:)
    COMPLEX, ALLOCATABLE :: work2_c(:)

    TYPE(t_mpimat):: ev_dist
    
    EXTERNAL iceil, numroc
    EXTERNAL dlamch


#ifdef FLEUR_USE_SCOREP

    SCOREP_RECORDING_OFF()    
#endif    
    SELECT TYPE(hmat)
    TYPE IS (t_mpimat)
    SELECT TYPE(smat)
    TYPE IS (t_mpimat)

    ALLOCATE(eig2(hmat%global_size1))


    CALL MPI_COMM_RANK(hmat%blacsdata%mpi_com,myid,ierr)
    CALL MPI_COMM_SIZE(hmat%blacsdata%mpi_com,np,ierr)

    num=ne !no of states solved for
    
    abstol=2.0*dlamch('S') ! PDLAMCH gave an error on ZAMpano

    CALL ev_dist%init(hmat)

    !smat%blacs_desc(2)    = hmat%blacs_desc(2)
    !ev_dist%blacs_desc(2) = hmat%blacs_desc(2)
    !smat%blacs_desc=hmat%blacs_desc
    !ev_dist%blacs_desc=hmat%blacs_desc
    
    
    nb=hmat%blacsdata%blacs_desc(5)! Blocking factor
    IF (nb.NE.hmat%blacsdata%blacs_desc(6)) CALL judft_error("Different block sizes for rows/columns not supported")
  
    !
    nn=MAX(MAX(hmat%global_size1,nb),2)
    np0=numroc(nn,nb,0,0,hmat%blacsdata%nprow)
    mq0=numroc(MAX(MAX(ne,nb),2),nb,0,0,hmat%blacsdata%npcol)
    IF (hmat%l_real) THEN
       lwork2=5*hmat%global_size1+MAX(5*nn,np0*mq0+2*nb*nb)+ iceil(ne,hmat%blacsdata%nprow*hmat%blacsdata%npcol)*nn
       ALLOCATE ( work2_r(lwork2+10*hmat%global_size1), stat=err ) ! Allocate more in case of clusters
    ELSE
       lwork2=hmat%global_size1+MAX(nb*(np0+1),3)
       ALLOCATE ( work2_c(lwork2), stat=err )
    ENDIF
    IF (err.NE.0) THEN 
       WRITE (*,*) 'work2  :',err,lwork2
       CALL juDFT_error('Failed to allocated "work2"', calledby ='chani')
    ENDIF
    
    liwork=6*MAX(MAX(hmat%global_size1,hmat%blacsdata%nprow*hmat%blacsdata%npcol+1),4)
    ALLOCATE ( iwork(liwork), stat=err )
    IF (err.NE.0) THEN
       WRITE (*,*) 'iwork  :',err,liwork
       CALL juDFT_error('Failed to allocated "iwork"', calledby ='chani')
    ENDIF
    ALLOCATE ( ifail(hmat%global_size1), stat=err )
    IF (err.NE.0) THEN
       WRITE (*,*) 'ifail  :',err,hmat%global_size1
       CALL juDFT_error('Failed to allocated "ifail"', calledby ='chani')
    ENDIF
    ALLOCATE ( iclustr(2*hmat%blacsdata%nprow*hmat%blacsdata%npcol), stat=err )
    IF (err.NE.0) THEN
       WRITE (*,*) 'iclustr:',err,2*hmat%blacsdata%nprow*hmat%blacsdata%npcol
       CALL juDFT_error('Failed to allocated "iclustr"', calledby ='chani')
    ENDIF
    ALLOCATE ( gap(hmat%blacsdata%nprow*hmat%blacsdata%npcol), stat=err )
    IF (err.NE.0) THEN
       WRITE (*,*) 'gap    :',err,hmat%blacsdata%nprow*hmat%blacsdata%npcol
       CALL juDFT_error('Failed to allocated "gap"', calledby ='chani')
    ENDIF
    !
    !     Compute size of workspace
    !
    IF (hmat%l_real) THEN
       uplo='U'
       CALL pdsygvx(1,'V','I','U',hmat%global_size1,hmat%data_r,1,1,&
            hmat%blacsdata%blacs_desc,smat%data_r,1,1,smat%blacsdata%blacs_desc,&
            0.0,1.0,1,num,abstol,num1,num2,eig2,orfac,ev_dist%data_r,1,1,&
            ev_dist%blacsdata%blacs_desc,work2_r,-1,iwork,-1,ifail,iclustr, gap,ierr)
       IF ( work2_r(1).GT.lwork2) THEN
          lwork2 = work2_r(1)
          DEALLOCATE (work2_r)
          ALLOCATE ( work2_r(lwork2+20*hmat%global_size1), stat=err ) ! Allocate even more in case of clusters
          IF (err.NE.0) THEN
             WRITE (*,*) 'work2  :',err,lwork2
             CALL juDFT_error('Failed to allocated "work2"', calledby ='chani')
          ENDIF
       ENDIF
    ELSE
       lrwork=4*hmat%global_size1+MAX(5*nn,np0*mq0)+ iceil(ne,hmat%blacsdata%nprow*hmat%blacsdata%npcol)*nn
       ! Allocate more in case of clusters
       ALLOCATE(rwork(lrwork+10*hmat%global_size1), stat=ierr)
       IF (err /= 0) THEN
          WRITE (*,*) 'ERROR: chani.F: Allocating rwork failed'
          CALL juDFT_error('Failed to allocated "rwork"', calledby ='chani')
       ENDIF
       
       CALL pzhegvx(1,'V','I','U',hmat%global_size1,hmat%data_c,1,1,&
            hmat%blacsdata%blacs_desc,smat%data_c,1,1, smat%blacsdata%blacs_desc,&
            0.0,1.0,1,num,abstol,num1,num2,eig2,orfac,ev_dist%data_c,1,1,&
            ev_dist%blacsdata%blacs_desc,work2_c,-1,rwork,-1,iwork,-1,ifail,iclustr,&
            gap,ierr)
       IF (ABS(work2_c(1)).GT.lwork2) THEN
          lwork2=work2_c(1)
          DEALLOCATE (work2_c)
          ALLOCATE (work2_c(lwork2), stat=err)
          IF (err /= 0) THEN
             WRITE (*,*) 'ERROR: chani.F: Allocating rwork failed:',lwork2
             CALL juDFT_error('Failed to allocated "work2"', calledby ='chani')
          ENDIF
       ENDIF
       IF (rwork(1).GT.lrwork) THEN
          lrwork=rwork(1)
          DEALLOCATE(rwork)
          ! Allocate even more in case of clusters
          ALLOCATE (rwork(lrwork+20*hmat%global_size1), stat=err)
          IF (err /= 0) THEN
             WRITE (*,*) 'ERROR: chani.F: Allocating rwork failed: ', lrwork+20*hmat%global_size1
             CALL juDFT_error('Failed to allocated "rwork"', calledby ='chani')
          ENDIF
       ENDIF
    endif
    IF (iwork(1) .GT. liwork) THEN
       liwork = iwork(1)
       DEALLOCATE (iwork)
       ALLOCATE (iwork(liwork), stat=err)
       IF (err /= 0) THEN
          WRITE (*,*) 'ERROR: chani.F: Allocating iwork failed: ',liwork
          CALL juDFT_error('Failed to allocated "iwork"', calledby ='chani')
       ENDIF
    ENDIF
    !
    !     Now solve generalized eigenvalue problem
    !
    CALL timestart("SCALAPACK call")
    if (hmat%l_real) THEN
       CALL pdsygvx(1,'V','I','U',hmat%global_size1,hmat%data_r,1,1,hmat%blacsdata%blacs_desc,smat%data_r,1,1, smat%blacsdata%blacs_desc,&
            1.0,1.0,1,num,abstol,num1,num2,eig2,orfac,ev_dist%data_r,1,1,&
            ev_dist%blacsdata%blacs_desc,work2_r,lwork2,iwork,liwork,ifail,iclustr,&
            gap,ierr)
    else
       CALL pzhegvx(1,'V','I','U',hmat%global_size1,hmat%data_c,1,1,hmat%blacsdata%blacs_desc,smat%data_c,1,1, smat%blacsdata%blacs_desc,&
            1.0,1.0,1,num,abstol,num1,num2,eig2,orfac,ev_dist%data_c,1,1,&
            ev_dist%blacsdata%blacs_desc,work2_c,lwork2,rwork,lrwork,iwork,liwork,&
            ifail,iclustr,gap,ierr)
       DEALLOCATE(rwork)
    endif
    CALL timestop("SCALAPACK call")
    IF (ierr .NE. 0) THEN
       !IF (ierr /= 2) WRITE (oUnit,*) myid,' error in pzhegvx/pdsygvx, ierr=',ierr
       !IF (ierr <= 0) WRITE (oUnit,*) myid,' illegal input argument'
       IF (MOD(ierr,2) /= 0) THEN
          !WRITE (oUnit,*) myid,'some eigenvectors failed to converge'
          eigs: DO i = 1, ne
             IF (ifail(i) /= 0) THEN
                !WRITE (oUnit,*) myid,' eigenvector',ifail(i), 'failed to converge'
             ELSE
                EXIT eigs
             ENDIF
          ENDDO eigs
          !CALL CPP_flush(oUnit)
       ENDIF
       IF (MOD(ierr/4,2).NE.0) THEN
          !WRITE(oUnit,*) myid,' only',num2,' eigenvectors converged'
          !CALL CPP_flush(oUnit)
       ENDIF
       IF (MOD(ierr/8,2).NE.0) THEN
          !WRITE(oUnit,*) myid,' PDSTEBZ failed to compute eigenvalues'
          CALL judft_warn("SCALAPACK failed to solve eigenvalue problem",calledby="scalapack.f90")
       ENDIF
       IF (MOD(ierr/16,2).NE.0) THEN
          !WRITE(oUnit,*) myid,' B was not positive definite, Cholesky failed at',ifail(1)
          CALL judft_warn("SCALAPACK failed: B was not positive definite. " // new_line("a") // &
                          "Order of the smallest minor which is not positive definite:" // int2str(ifail(1))&
                         ,calledby="scalapack.f90")
       ENDIF
    ENDIF
    IF (num2 < num1) THEN
       !IF (myid ==0) THEN
          WRITE(oUnit,*) 'Not all eigenvalues wanted are found'
          WRITE(oUnit,*) 'number of eigenvalues/vectors wanted',num1
          WRITE(oUnit,*) 'number of eigenvalues/vectors found',num2
          !CALL CPP_flush(oUnit)
       !ENDIF
    ENDIF
    !
    !     Each process has all eigenvalues in output
    eig(:num2) = eig2(:num2)    
    DEALLOCATE(eig2)
    !
    !
    !     Redistribute eigenvectors  from ScaLAPACK distribution to each process, i.e. for
    !     process i these are eigenvectors i+1, np+i+1, 2*np+i+1...
    !     Only num=num2/np eigenvectors per process
    !
    num=FLOOR(REAL(num2)/np)
    IF (myid.LT.num2-(num2/np)*np) num=num+1
    ne=0
    DO i=myid+1,num2,np
       ne=ne+1
       !eig(ne)=eig2(i)
    ENDDO
    ALLOCATE(t_mpimat::ev)
    CALL ev%init(ev_dist%l_real,ev_dist%global_size1,ev_dist%global_size1,ev_dist%blacsdata%mpi_com,.FALSE.)
    CALL ev%copy(ev_dist,1,1)
    CLASS DEFAULT
      call judft_error("Wrong type (1) in scalapack")
    END SELECT
    CLASS DEFAULT
      call judft_error("Wrong type (2) in scalapack")
    END SELECT
#ifdef FLEUR_USE_SCOREP
    SCOREP_RECORDING_ON()
#endif    
#endif
  END SUBROUTINE scalapack
END MODULE m_scalapack
