!--------------------------------------------------------------------------------
! Copyright (c) 2022 Peter Grünberg Institut, Forschungszentrum Jülich, Germany
! This file is part of FLEUR and available as free software under the conditions
! of the MIT license as expressed in the LICENSE file in more detail.
!--------------------------------------------------------------------------------
MODULE m_dfpt_cdngen
#ifdef CPP_MPI
   USE mpi
#endif
CONTAINS

SUBROUTINE dfpt_cdngen(eig_id,eig_id_q,dfpt_eig_id,fmpi,input,banddosdummy,vacuum,&
                  kpts,atoms,sphhar,starsq,sym,gfinp,hub1inp,&
                  enpara,cell,noco,nococonv,vTot,resultsdummy, resultsdummy1,&
                  archiveType, xcpot,outDen,outDenIm,bqpt,iDtype,iDir,l_real)

   use m_types_vacdos
   USE m_types
   USE m_constants
   USE m_juDFT
   USE m_dfpt_cdnval
   USE m_cdn_io
   USE m_wrtdop
   USE m_cdncore

   IMPLICIT NONE

   ! Type instance arguments
   TYPE(t_results),INTENT(INOUT)    :: resultsdummy, resultsdummy1
   TYPE(t_mpi),INTENT(IN)           :: fmpi
   TYPE(t_enpara),INTENT(IN)        :: enpara
   TYPE(t_banddos),INTENT(IN)       :: banddosdummy
   TYPE(t_input),INTENT(IN)         :: input
   TYPE(t_vacuum),INTENT(IN)        :: vacuum
   TYPE(t_noco),INTENT(IN)          :: noco
   TYPE(t_nococonv),INTENT(IN)      :: nococonv
   TYPE(t_sym),INTENT(IN)           :: sym
   TYPE(t_stars),INTENT(IN)         :: starsq
   TYPE(t_cell),INTENT(IN)          :: cell
   TYPE(t_kpts),INTENT(IN)          :: kpts
   TYPE(t_sphhar),INTENT(IN)        :: sphhar
   TYPE(t_atoms),INTENT(IN)         :: atoms
   TYPE(t_potden),INTENT(IN)        :: vTot
   TYPE(t_gfinp),INTENT(IN)         :: gfinp
   TYPE(t_hub1inp),INTENT(IN)       :: hub1inp
   CLASS(t_xcpot),INTENT(IN)     :: xcpot
   TYPE(t_potden),INTENT(INOUT)     :: outDen, outDenIm

   !Scalar Arguments
   INTEGER, INTENT(IN)              :: eig_id, eig_id_q, dfpt_eig_id, archiveType, iDtype, iDir
   LOGICAL, INTENT(IN)              :: l_real

   REAL, INTENT(IN) :: bqpt(3)

   ! Local type instances
   TYPE(t_regionCharges)          :: regCharges
   TYPE(t_dos),TARGET             :: dosdummy
   TYPE(t_vacdos),TARGET          :: vacdosdummy
   TYPE(t_moments)                :: moments
   TYPE(t_cdnvalJob)       :: cdnvalJob, cdnvalJob1
   !TYPE(t_kpts)              :: kqpts ! basically kpts, but with q added onto each one.

   !Local Scalars
   REAL                  :: fix, qtot, dummy,eFermiPrev
   INTEGER               :: jspin, ierr
   INTEGER               :: dim_idx
   INTEGER               :: n, iK

   LOGICAL               :: l_error,Perform_metagga

   !kqpts = kpts
   !! Modify this from kpts only in DFPT case.
   !DO iK = 1, kpts%nkpt
   !   kqpts%bk(:, iK) = kqpts%bk(:, iK) + bqpt
   !END DO

   ! Initialization section
   CALL moments%init(fmpi,input,sphhar,atoms)
   !initalize data for DOS
   if (noco%l_noco) resultsdummy%eig(:,:,2)=resultsdummy%eig(:,:,1)
   if (noco%l_noco) resultsdummy1%eig(:,:,2)=resultsdummy1%eig(:,:,1)
   CALL dosdummy%init(input,atoms,kpts,banddosdummy,resultsdummy%eig)
   CALL vacdosdummy%init(input,atoms,kpts,banddosdummy,resultsdummy%eig)

   !CALL outDen%init(starsq, atoms, sphhar, vacuum, noco, input%jspins, POTDEN_TYPE_DEN,.TRUE.)
   !CALL outDenIm%init(starsq, atoms, sphhar, vacuum, noco, input%jspins, POTDEN_TYPE_DEN)

   CALL timestart("dfpt_cdngen: cdnval")
   DO jspin = 1,merge(1,input%jspins,noco%l_mperp)
      CALL cdnvalJob%init(fmpi,input,kpts,noco,resultsdummy,jspin)
      CALL cdnvalJob1%init(fmpi,input,kpts,noco,resultsdummy1,jspin)
      CALL dfpt_cdnval(eig_id, eig_id_q, dfpt_eig_id,fmpi,kpts,jspin,noco,nococonv,input,banddosdummy,cell,atoms,enpara,starsq,&
                       vacuum,sphhar,sym,vTot,cdnvalJob,outDen,dosdummy,vacdosdummy,&
                        hub1inp, cdnvalJob1, resultsdummy, resultsdummy1, bqpt, iDtype, iDir, outDenIm, l_real)
   END DO
   CALL timestop("dfpt_cdngen: cdnval")

   ! TODO: Implement this appropriately.
   !CALL timestart("cdngen: cdncore")
   !CALL cdncore(fmpi,input,vacuum,noco,nococonv,sym,&
   !             starsq,cell,sphhar,atoms,vTot,outDen,moments,results)
   !CALL timestop("cdngen: cdncore")

   ! These should already be broadcast.
!#ifdef CPP_MPI
!   CALL MPI_BCAST(nococonv%alph,atoms%ntype,MPI_DOUBLE_PRECISION,0,fmpi%mpi_comm,ierr)
!   CALL MPI_BCAST(nococonv%beta,atoms%ntype,MPI_DOUBLE_PRECISION,0,fmpi%mpi_comm,ierr)
!   CALL MPI_BCAST(nococonv%b_con,atoms%ntype*2,MPI_DOUBLE_PRECISION,0,fmpi%mpi_comm,ierr)
!   CALL MPI_BCAST(nococonv%qss,3,MPI_DOUBLE_PRECISION,0,fmpi%mpi_comm,ierr)
!#endif
   CALL outDen%distribute(fmpi%mpi_comm)
   CALL outDenIm%distribute(fmpi%mpi_comm)

END SUBROUTINE dfpt_cdngen

END MODULE m_dfpt_cdngen
