!--------------------------------------------------------------------------------
! Copyright (c) 2016 Peter Grünberg Institut, Forschungszentrum Jülich, Germany
! This file is part of FLEUR and available as free software under the conditions
! of the MIT license as expressed in the LICENSE file in more detail.
!--------------------------------------------------------------------------------

MODULE m_types_ssdisp

  USE m_types
  USE m_types_forcetheo
  USE m_judft
  IMPLICIT NONE
  TYPE,EXTENDS(t_forcetheo) :: t_forcetheo_ssdisp
     INTEGER :: q_done
     REAL,ALLOCATABLE:: qvec(:,:)
     REAL,ALLOCATABLE:: evsum(:)
   CONTAINS
     PROCEDURE :: start   =>ssdisp_start
     PROCEDURE :: next_job=>ssdisp_next_job
     PROCEDURE :: eval    =>ssdisp_eval
     PROCEDURE :: postprocess => ssdisp_postprocess
     PROCEDURE :: init   => ssdisp_init !not overloaded
     PROCEDURE :: dist   => ssdisp_dist !not overloaded
  END TYPE t_forcetheo_ssdisp

CONTAINS


  SUBROUTINE ssdisp_init(this,q)
    USE m_calculator
    USE m_constants
    IMPLICIT NONE
    CLASS(t_forcetheo_ssdisp),INTENT(INOUT):: this
    REAL,INTENT(in)                     :: q(:,:)

    ALLOCATE(this%qvec(3,SIZE(q,2)))
    this%qvec=q
    this%l_needs_vectors=.false.
   
    ALLOCATE(this%evsum(SIZE(q,2)))
    this%evsum=0
  END SUBROUTINE ssdisp_init

  SUBROUTINE ssdisp_start(this,potden,l_io)
    USE m_types_potden
    IMPLICIT NONE
    CLASS(t_forcetheo_ssdisp),INTENT(INOUT):: this
    TYPE(t_potden) ,INTENT(INOUT)          :: potden
    LOGICAL,INTENT(IN)                     :: l_io
    this%q_done=0
    CALL this%t_forcetheo%start(potden,l_io) !call routine of basis type

    IF (SIZE(potden%pw,2)<2) RETURN
    !Average out magnetic part of potential/charge in INT+Vacuum
    potden%pw(:,1)=(potden%pw(:,1)+potden%pw(:,2))/2.0
    potden%pw(:,2)=potden%pw(:,1)

    potden%vacz(:,:,1)=(potden%vacz(:,:,1)+potden%vacz(:,:,2))/2.0
    potden%vacxy(:,:,:,1)=(potden%vacxy(:,:,:,1)+potden%vacxy(:,:,:,2))/2.0
    potden%vacz(:,:,2)=potden%vacz(:,:,1)
    potden%vacxy(:,:,:,2)=potden%vacxy(:,:,:,1)
    !Off diagonal part
    IF (SIZE(potden%pw,2)==3) THEN
       potden%pw(:,3)=0.0
       potden%vacz(:,:,3:)=0.0
       potden%vacxy(:,:,:,3)=0.0
    END IF

  END SUBROUTINE  ssdisp_start

  LOGICAL FUNCTION ssdisp_next_job(this,fmpi,lastiter,atoms,noco,nococonv)
    USE m_types_setup
    USE m_xmlOutput
    USE m_constants
    USE m_types_mpi
    IMPLICIT NONE
    CLASS(t_forcetheo_ssdisp),INTENT(INOUT):: this
    TYPE(t_mpi), INTENT(IN)                :: fmpi
    LOGICAL,INTENT(IN)                  :: lastiter
    TYPE(t_atoms),INTENT(IN)            :: atoms
    TYPE(t_noco),INTENT(IN)             :: noco
    !Stuff that might be modified...
    TYPE(t_nococonv),INTENT(INOUT) :: nococonv
    CHARACTER(LEN=12):: attributes(2)
    INTEGER                    :: itype
    IF (.NOT.lastiter) THEN
       ssdisp_next_job=this%t_forcetheo%next_job(fmpi,lastiter,atoms,noco,nococonv)
       RETURN
    ENDIF
    !OK, now we start the SSDISP-loop
    this%l_in_forcetheo_loop = .true.
    this%q_done=this%q_done+1
    ssdisp_next_job=(this%q_done<=SIZE(this%qvec,2)) !still q-vectors to do
    IF (.NOT.ssdisp_next_job) RETURN

    !Now modify the noco-file
    nococonv%qss=this%qvec(:,this%q_done)
    !Modify the alpha-angles
    DO iType = 1,atoms%ntype
       nococonv%alph(iType) = noco%alph_inp(iType) + tpi_const*dot_PRODUCT(nococonv%qss,atoms%taual(:,atoms%firstAtom(itype)))
    END DO
    IF (.NOT.this%l_io) RETURN
    IF (fmpi%irank .EQ. 0) THEN
       IF (this%q_done.NE.1) CALL closeXMLElement('Forcetheorem_Loop')
       WRITE(attributes(1),'(a)') 'SSDISP'
       WRITE(attributes(2),'(i5)') this%q_done
       CALL openXMLElementPoly('Forcetheorem_Loop',(/'calculationType','No             '/),attributes)
    END IF
  END FUNCTION ssdisp_next_job

  SUBROUTINE ssdisp_postprocess(this)
    USE m_xmlOutput
    IMPLICIT NONE
    CLASS(t_forcetheo_ssdisp),INTENT(INOUT):: this

    !Locals
    INTEGER:: n,q
    CHARACTER(LEN=12):: attributes(4)
    IF (this%q_done==0) RETURN
    !Now output the results
    IF (this%l_io) THEN
       CALL closeXMLElement('Forcetheorem_Loop')
       attributes = ''
       WRITE(attributes(1),'(i5)') SIZE(this%evsum)
       WRITE(attributes(2),'(a)') 'Htr'
       CALL openXMLElement('Forcetheorem_SSDISP',(/'qvectors','units   '/),attributes(:2))
       DO q=1,SIZE(this%evsum)
          WRITE(attributes(1),'(i5)') q
          WRITE(attributes(2),'(f12.7)') this%evsum(q)
          CALL writeXMLElementForm('Entry',(/'q     ','ev-sum'/),attributes(1:2),&
               RESHAPE((/1,6,5,12/),(/2,2/)))
       ENDDO
       CALL closeXMLElement('Forcetheorem_SSDISP')
    ENDIF
    CALL judft_end("Forcetheorem:SpinSpiralDispersion")
  END SUBROUTINE ssdisp_postprocess

  SUBROUTINE ssdisp_dist(this,fmpi)
#ifdef CPP_MPI
    USE mpi
#endif
    USE m_types_mpi
    IMPLICIT NONE
    CLASS(t_forcetheo_ssdisp),INTENT(INOUT):: this
    TYPE(t_mpi),INTENT(in):: fmpi

    INTEGER:: q,ierr
#ifdef CPP_MPI
    IF (fmpi%irank==0) q=SIZE(this%qvec,2)
    CALL MPI_BCAST(q,1,MPI_INTEGER,0,fmpi%mpi_comm,ierr)
    IF (fmpi%irank.NE.0) ALLOCATE(this%qvec(3,q),this%evsum(q));this%evsum=0.0
    CALL MPI_BCAST(this%qvec,3*q,MPI_DOUBLE_PRECISION,0,fmpi%mpi_comm,ierr)
#endif
  END SUBROUTINE ssdisp_dist

  FUNCTION ssdisp_eval(this,eig_id,atoms,kpts,sym,&
       cell,noco,nococonv, input,fmpi,  enpara,v,results)RESULT(skip)
     USE m_types
     USE m_ssomat
    IMPLICIT NONE
    CLASS(t_forcetheo_ssdisp),INTENT(INOUT):: this
    LOGICAL :: skip
    !Stuff that might be used...
    TYPE(t_mpi),INTENT(IN)         :: fmpi

     
    TYPE(t_input),INTENT(IN)       :: input
    TYPE(t_noco),INTENT(IN)        :: noco
    TYPE(t_nococonv),INTENT(IN)   :: nococonv
    TYPE(t_sym),INTENT(IN)         :: sym
    TYPE(t_cell),INTENT(IN)        :: cell
    TYPE(t_kpts),INTENT(IN)        :: kpts
    TYPE(t_atoms),INTENT(IN)       :: atoms
    TYPE(t_enpara),INTENT(IN)      :: enpara
    TYPE(t_potden),INTENT(IN)      :: v
    TYPE(t_results),INTENT(IN)     :: results
    INTEGER,INTENT(IN)             :: eig_id
    skip=.FALSE.
    IF (this%q_done==0) RETURN

    this%evsum(this%q_done)=results%seigv
    skip=.TRUE.
  END FUNCTION  ssdisp_eval


END MODULE m_types_ssdisp
