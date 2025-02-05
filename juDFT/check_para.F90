MODULE m_judft_para

CONTAINS
   subroutine juDFT_check_para()
#ifdef CPP_MPI
      USE mpi
#endif
      implicit none
      logical   :: omp_para_loc, omp_root_and
      integer   :: irank, ierr

#ifdef CPP_MPI
      call MPI_COMM_RANK(MPI_COMM_WORLD, irank, ierr)
      omp_para_loc = check_omp_para()

      call MPI_Reduce(omp_para_loc, omp_root_and, 1,&
                      MPI_LOGICAL, MPI_LAND, 0, MPI_COMM_WORLD,ierr)

      if(irank == 0 .and. omp_root_and) then
         write (*,*) "Parallelization OK"
      endif
#else
      omp_para_loc = check_omp_para()
      if(omp_para_loc) write (*,*) "Parallelization OK"
#endif

   end subroutine juDFT_check_para

   !subroutine check_mpi_para(mpi)
      !use m_judft_string
      !use m_judft_stop
      !implicit none
      !TYPE(t_mpi)    ,INTENT(IN) :: mpi
      !real(8)                    :: summe, summe_seq, t_mpi, t_seq
      !integer(4)                 :: rank, size, ierr
      !integer                    :: i, omp_threads
      !integer, parameter          :: loop_end = 300000000

      !t_mpi = MPI_Wtime()
      !summe = 0.0
      !do i = 1, loop_end*omp_threads
         !summe = summe + 1.0
      !enddo
      !t_mpi = MPI_Wtime() - t_mpi

      !call MPI_Reduce(summe, summe_seq, 1, MPI_REAL8, MPI_SUM, 0, mpi%mpi_comm)

      !if(mpi%irank == 0) then
         !summe = summe / mpi%isize

         !t_seq = MPI_Wtime()
         !summe = 0.0
         !do i = 1, loop_end*omp_threads
            !summe = summe + 1.0
         !enddo
         !t_seq = MPI_Wtime() - t_seq
      !endif

   !end subroutine check_mpi_para

   function check_omp_para() result(parallel_ok)
      !$ use omp_lib
      use m_judft_string
      use m_judft_stop
      implicit none
      logical            :: parallel_ok
      real               :: summe, t_omp, t_seq
      integer            :: rank, size, ierr
      integer            :: i, j, omp_threads
      integer, parameter :: loop_end = 300000000

      summe = 0.0
      t_omp = 0.0
   
      !$omp parallel reduction(+: t_omp) default(shared)
      omp_threads = 1
      !$ omp_threads = OMP_GET_NUM_THREADS()
      t_omp = 1.0
      !$ t_omp = OMP_GET_WTIME()
      !$omp do schedule(static) reduction(+:summe)
      do i = 1, loop_end
         do j = 1, omp_threads
            summe = summe + 1.0
         enddo
      enddo
      !$omp end do
      !$ t_omp = OMP_GET_WTIME() - t_omp
      !$omp end parallel

      t_omp = t_omp / omp_threads
      summe = summe / omp_threads

      t_seq = 1.0
      !$ t_seq = OMP_GET_WTIME()
      do i = 1, loop_end
         summe = summe - 1.0
      enddo
      !$ t_seq = OMP_GET_WTIME() - t_seq

      if( abs(t_seq/t_omp -1.0) < 0.1)then
         parallel_ok = .True.
      else
         write (*,*) "number of OMPs = ", omp_threads
         write (*,*) "t_omp = ", t_omp
         write (*,*) "t_seq = ", t_seq
         write (*,*) "Summe = ", summe

         call juDFT_warn("OpenMP parallelization underperform with a parallel efficiency of " // &
            float2str(t_seq/t_omp), hint="check if your slurm files is set properly")
         parallel_ok = .False.
      endif
   end function check_omp_para

END MODULE m_judft_para
