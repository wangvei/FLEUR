!--------------------------------------------------------------------------------
! Copyright (c) 2016 Peter Grünberg Institut, Forschungszentrum Jülich, Germany
! This file is part of FLEUR and available as free software under the conditions
! of the MIT license as expressed in the LICENSE file in more detail.
!--------------------------------------------------------------------------------

      MODULE m_wann_rw_eig
      use m_juDFT
#ifdef CPP_MPI
#define CPP_HYBEIG
#endif
c****************************************************************
c    write WF1.eig and determine maximum of number of bands
c      Frank Freimuth, October 2006
c****************************************************************
      CONTAINS
      SUBROUTINE wann_write_eig(
     >     fmpi,cell,noco,nococonv,input,kpts,sym,atoms,          
     >              eig_id,l_real,
     >              ntypd,nvd,jspd,
     >              isize,jspin,
     >              l_ss,l_noco,nrec,fullnkpts,
     >              l_bzsym,l_byindex,l_bynumber,l_byenergy,
     >              irreduc,band_min,band_max,numbands,
     >              e1s,e2s,ef,l_paulimag,nkpt,    
     <              nbnd,kpoints,l_gwf,iqpt)

      use m_types
      use m_constants
      use m_cdnread, only:cdn_read

      IMPLICIT NONE
      TYPE(t_mpi),       INTENT(IN) :: fmpi
      TYPE(t_cell),      INTENT(IN) :: cell
      TYPE(t_noco),      INTENT(IN) :: noco
      TYPE(t_nococonv),  INTENT(IN) :: nococonv
      TYPE(t_input),     INTENT(IN) :: input
      TYPE(t_kpts),      INTENT(IN) :: kpts
      TYPE(t_sym),       INTENT(IN) :: sym
      TYPE(t_atoms),     INTENT(IN) :: atoms
      integer,intent(in) :: eig_id
      integer,intent(in) :: ntypd,nvd,jspd
      integer,intent(in) :: isize,jspin
      logical,intent(in) :: l_ss,l_noco,l_real
      integer,intent(in) :: nrec,fullnkpts

      logical,intent(in) :: l_byindex,l_bynumber,l_byenergy
      integer,intent(in) :: irreduc(fullnkpts)
      integer,intent(in) :: band_min,band_max,numbands
      logical,intent(in) :: l_bzsym
      real,intent(in)    :: e1s,e2s,ef
      logical,intent(in) :: l_paulimag
      integer,intent(in) :: nkpt

      integer,intent(out):: nbnd
      real,intent(out)   :: kpoints(fullnkpts)

      logical          :: l_eig
      character(len=3) :: spin12(2)
      data spin12/'WF1' , 'WF2'/
      integer          :: ikpt,kptibz
      integer          :: nmat,nbands,nv(jspd)
      real             :: wk, bkpt(3),eig(input%neig),cp_time(9)
      integer          :: k1(nvd,jspd),k2(nvd,jspd),k3(nvd,jspd)
      integer          :: nkbnd,i
      integer          :: co
      integer          :: bnd1,bnd2,kpt
      complex, allocatable :: paulimat(:,:,:,:) 
      real             :: sum1,sum2,sum3
      integer          :: num_bands,err,numbasfcn
      
! BEGIN QPOINTS
      LOGICAL, INTENT(IN) :: l_gwf
      INTEGER, INTENT(IN) :: iqpt
      CHARACTER(len=12) :: fname
! END QPOINTS
!      real,parameter   :: hartree=27.21138505  !now in module constants

      TYPE(t_mat) :: zMat !z(nbasfcn,noccbd) !can be real/complex
      TYPE(t_lapw)  :: lapw


      call timestart("wann_write_eig")
!      zMat%l_real = l_real
!      zMat%matsize1 = nbasfcn
!      zMat%matsize2 = neigd
!      IF(l_real) THEN  !allocates not needed, due to zmat%init further below
!         ALLOCATE (zMat%data_r(zMat%matsize1,zMat%matsize2))
!      ELSE
!         ALLOCATE (zMat%data_c(zMat%matsize1,zMat%matsize2))
!      END IF

!      WRITE(*,*)'min',band_min,'max',band_max,'num',numbands
!      WRITE(*,*)'wann_rw_eig: neigd',neigd
!      n_start=1
!      n_end=neigd
      IF (l_gwf) THEN
         WRITE(fname,'("_",i4.4,".eig")')iqpt
         fname=spin12(jspin)//trim(fname)
      ELSE
         fname=spin12(jspin)//'.eig'
      ENDIF

!      WRITE(*,*)'wann_rw_eig.F: writing eig file ',fname

      inquire (file=fname,exist=l_eig)
      if (l_eig) then
         open (306,file=fname,
     &                               form='formatted',status='old')
         rewind (306)
      else
         open (306,file=fname,
     &                               form='formatted',status='new')
      endif!l_eig

      if(l_paulimag.and..false.)then
        num_bands=band_max-band_min+1
        allocate( paulimat(num_bands,num_bands,3,nkpt),stat=err )
        IF (err/=0)  CALL juDFT_error
     +       ("error allocating paulimat",calledby
     +       ="wann_rw_eig")
        open(655,file='wpmat')
        do ikpt=1,nkpt
          read(655,*)
          do co=1,3
            read(655,*)
            do bnd2=1,num_bands
               do bnd1=1,num_bands
                  read(655,*)paulimat(bnd1,bnd2,co,ikpt)
               enddo
            enddo
          enddo
        enddo      
        close(655)
      endif
      sum1=0.0
      sum2=0.0
      sum3=0.0

      nbnd=0
      do ikpt = 1,fullnkpts

        kptibz=ikpt
        if(l_bzsym) kptibz=irreduc(ikpt)

         CALL lapw%init(input,noco,nococonv,kpts,
     & atoms,sym,kptibz,cell,fmpi)

         numbasfcn = MERGE(lapw%nv(1)+lapw%nv(2)+2*atoms%nlotot,
     &   lapw%nv(1)+atoms%nlotot,noco%l_noco)

        CALL zMat%init(l_real,numbasfcn,input%neig)


        kptibz=ikpt 
        if(l_bzsym) kptibz=irreduc(ikpt)
            call wann_read_eig(
     >              eig_id,     
     >              ntypd,input%neig,nvd,jspd,
     >              0,isize,kptibz,jspin,numbasfcn,
     >              l_ss,l_noco,nrec,
     <              nmat,nbands,eig,zMat,
     >              l_gwf,iqpt)


        nkbnd = 0
!        WRITE(*,*)'wann_rw_eig: nbands',nbands
        do i = 1,nbands
         if((eig(i).ge.e1s .and. nkbnd.lt.numbands.and.l_bynumber).or.
     &      (eig(i).ge.e1s.and.eig(i).le.e2s.and.l_byenergy ).or.
     &      (i.ge.band_min.and.i.le.band_max.and.l_byindex))  then
           nkbnd = nkbnd + 1
           if(l_bynumber.or.l_byindex)then
              write (306,'(2i12,f19.13)') nkbnd,ikpt,(eig(i)-ef)*
     &                                    hartree_to_ev_const
           endif
           if(l_paulimag.and..false.)then
              if(eig(i).le.ef)then
                 sum1=sum1+paulimat(nkbnd,nkbnd,1,kptibz)
                 sum2=sum2+paulimat(nkbnd,nkbnd,2,kptibz)
                 sum3=sum3+paulimat(nkbnd,nkbnd,3,kptibz)
              endif
           endif   
         endif 
        enddo
!        WRITE(*,*)'wann_rw_eig: nkbnd',nkbnd,'nbnd',nbnd 
        if (nkbnd.ge.nbnd) nbnd = nkbnd

    
      enddo !ikpt

      if(l_paulimag)then
        write(oUnit,*)"sum1=",sum1/fullnkpts
        write(oUnit,*)"sum2=",sum2/fullnkpts
        write(oUnit,*)"sum3=",sum3/fullnkpts
      endif  


      if(l_byenergy)then   !now we know the maximum of bands
         do ikpt=1,fullnkpts
            kptibz=ikpt
            if(l_bzsym)kptibz=irreduc(ikpt)
            call wann_read_eig(     
     >              eig_id,       
     >              ntypd,input%neig,nvd,jspd,
     >              0,isize,kptibz,jspin,numbasfcn,
     >              l_ss,l_noco,nrec,
     <              nmat,nbands,eig,zMat,
     >              l_gwf,iqpt)


              nkbnd = 0
              do i = 1,nbands
                if(eig(i).ge.e1s .and. nkbnd.lt.nbnd)then
                     nkbnd = nkbnd + 1
                  write (306,'(2i12,f19.13)')nkbnd,ikpt,(eig(i)-ef)*
     &                  hartree_to_ev_const
                endif
              enddo 
         enddo   
      endif
      close (306)

      call timestop("wann_write_eig")
      end subroutine wann_write_eig
 
c*****************************************************************
c     read in eig file
c*****************************************************************
      subroutine wann_read_eig(     
     >              eig_id,
     >              ntypd,neigd,nvd,jspd,
     >              irank,isize,kptibz,jspin,nbasfcn,
     >              l_ss,l_noco,nrec,
     <              nmat,nbands,eig,zMat,
     >              l_gwf,iqpt)
      USE m_judft
      USE m_types
      use m_cdnread, only:cdn_read
      implicit none
      integer, intent (in) :: eig_id
      INTEGER, INTENT (IN) :: irank,isize,kptibz,nbasfcn,neigd
      INTEGER, INTENT (IN) :: nrec,nvd,jspd,jspin
      INTEGER, INTENT (IN) :: ntypd,iqpt
      LOGICAL, INTENT (IN) :: l_ss,l_noco,l_gwf

      INTEGER, INTENT (OUT) :: nbands,nmat
  
      REAL,    INTENT (OUT) :: eig(neigd)

      TYPE(t_mat), INTENT (INOUT) :: zMat !z(nbasfcn,noccbd) !can be real/complex

      integer :: n_start,n_end

      call timestart("wann_read_eig")

      n_start=1
      n_end=neigd

      CALL cdn_read(
     >              eig_id,
     >              nvd,jspd,irank,isize,kptibz,jspin,nbasfcn,
     >              l_ss,l_noco,neigd,n_start,n_end,
     <              nbands,eig,zMat)
!      CALL judft_error("BUG: wann_read in wann_rw_eig not implemented")

      call timestop("wann_read_eig")
      END SUBROUTINE wann_read_eig  
      END MODULE m_wann_rw_eig
