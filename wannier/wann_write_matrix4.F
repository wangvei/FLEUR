!--------------------------------------------------------------------------------
! Copyright (c) 2016 Peter Grünberg Institut, Forschungszentrum Jülich, Germany
! This file is part of FLEUR and available as free software under the conditions
! of the MIT license as expressed in the LICENSE file in more detail.
!--------------------------------------------------------------------------------

      module m_wann_write_matrix4
            use m_juDFT
      contains
      subroutine wann_write_matrix4(
     >               fmpi_comm,l_p0,filename,title,
     >               num_bands1,num_bands2,
     >               num_dims,fullnkpts,
     >               irank,isize,
     <               matrix4)
c*************************************************************
c     This subroutine is used to write several matrices to 
c     files. The corresponding 
c     filename has to be provided as input. 
c
c     MPI-Version: Collect the contributions to the matrix
c     from the various processors.
c
c     Frank Freimuth
c*************************************************************

      USE m_constants
#ifdef CPP_MPI
      USE mpi
#endif

      implicit none

      integer, intent(in)    :: fmpi_comm
      logical, intent(in)    :: l_p0
      character, intent(in)  :: filename*(*)
      character, intent(in)  :: title*(*)

      integer, intent(in)    :: num_bands1
      integer, intent(in)    :: num_bands2

      integer, intent(in)    :: num_dims
      integer, intent(in)    :: fullnkpts

      integer, intent(in)    :: irank,isize

      complex, intent(inout) :: matrix4(:,:,:,:)

      integer :: ikpt,i,j,ii,jj
      integer :: cpu_index,dir
#ifdef CPP_MPI
      integer :: ierr(3)
      integer :: stt(MPI_STATUS_SIZE)

#endif

#ifdef CPP_MPI
c**********************************************************
c     Collect contributions to the matrix4 matrix from the
c     various processors.
c**********************************************************
      call timestart("wann_write_matrix4")
	print*,"dim1=",size(matrix4,1)
	print*,"dim2=",size(matrix4,2)
	print*,"dim3=",size(matrix4,3)
	print*,"dim4=",size(matrix4,4)
      if(isize.ne.1)then
       do ikpt=1,fullnkpts
        if(l_p0)then
         do cpu_index=1,isize-1
          if(mod(ikpt-1,isize).eq.cpu_index)then
           call MPI_RECV(
     &             matrix4(1:num_dims,1:num_bands1,
     &             1:num_bands2,ikpt),
     &             num_bands1*num_bands2*num_dims,
     &             MPI_DOUBLE_COMPLEX,cpu_index,
     &             ikpt,fmpi_comm,stt,ierr(1))
          endif !processors
         enddo !cpu_index
        else
         if(mod(ikpt-1,isize).eq.irank)then
           call MPI_SEND(
     &             matrix4(1:num_dims,1:num_bands1,
     &             1:num_bands2,ikpt),
     &             num_bands1*num_bands2*num_dims,
     &             MPI_DOUBLE_COMPLEX,0,
     &             ikpt,fmpi_comm,ierr(1))
         endif !processors
        endif ! l_p0
        call MPI_BARRIER(fmpi_comm,ierr(1))
       enddo !ikpt 
      endif !isize
#endif

      write(oUnit,*)"wann_write_matrix4"

      if(l_p0)then
       open (305,file=filename)
       write (305,*)title
       write (305,'(3i5)') num_bands1,num_bands1,fullnkpts
       do ikpt=1,fullnkpts
        do i = 1,num_bands2
         do j = 1,num_bands1
          do dir=1,num_dims  
             write (305,'(4i5,3x,2f18.12)') dir,j,i,ikpt,
     &              real(matrix4(dir,j,i,ikpt)),
     &              aimag(matrix4(dir,j,i,ikpt))
          enddo !dir 
         enddo !j
        enddo !i
       enddo !ikpt
       close(305)
      endif
      call timestop("wann_write_matrix4")
      end subroutine wann_write_matrix4
      end module m_wann_write_matrix4
