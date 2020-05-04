module m_wavefproducts_aux

CONTAINS
   subroutine prep_list_of_gvec(lapw, mpdata, g_bounds, g_t, iq, jsp, pointer, gpt0, ngpt0)
      use m_types
      use m_juDFT
      implicit none
      type(t_lapw), intent(in)    :: lapw
      TYPE(t_mpdata), intent(in)         :: mpdata
      integer, intent(in)    :: g_bounds(:), g_t(:), iq, jsp
      integer, allocatable, intent(inout) :: pointer(:, :, :), gpt0(:, :)
      integer, intent(inout) :: ngpt0

      integer :: ic, ig1, igptm, iigptm, ok, g(3)

      allocate (pointer(-g_bounds(1):g_bounds(1), &
                        -g_bounds(2):g_bounds(2), &
                        -g_bounds(3):g_bounds(3)), stat=ok)
      IF (ok /= 0) call juDFT_error('wavefproducts_noinv2: error allocation pointer')
      allocate (gpt0(3, size(pointer)), stat=ok)
      IF (ok /= 0) call juDFT_error('wavefproducts_noinv2: error allocation gpt0')

      call timestart("prep list of Gvec")
      pointer = 0
      ic = 0
      DO ig1 = 1, lapw%nv(jsp)
         DO igptm = 1, mpdata%n_g(iq)
            iigptm = mpdata%gptm_ptr(igptm, iq)
            g = lapw%gvec(:, ig1, jsp) + mpdata%g(:, iigptm) - g_t
            IF (pointer(g(1), g(2), g(3)) == 0) THEN
               ic = ic + 1
               gpt0(:, ic) = g
               pointer(g(1), g(2), g(3)) = ic
            END IF
         END DO
      END DO
      ngpt0 = ic
      call timestop("prep list of Gvec")
   end subroutine prep_list_of_gvec

   function calc_number_of_basis_functions(lapw, atoms, noco) result(nbasfcn)
      use m_types
      implicit NONE
      type(t_lapw), intent(in)  :: lapw
      type(t_atoms), intent(in) :: atoms
      type(t_noco), intent(in)  :: noco
      integer                   :: nbasfcn

      if (noco%l_noco) then
         nbasfcn = lapw%nv(1) + lapw%nv(2) + 2*atoms%nlotot
      else
         nbasfcn = lapw%nv(1) + atoms%nlotot
      endif
   end function calc_number_of_basis_functions

   function outer_prod(x, y) result(outer)
      implicit NONE
      complex, intent(in) :: x(:), y(:)
      complex :: outer(size(x), size(y))
      integer  :: i, j

      do j = 1, size(y)
         do i = 1, size(x)
            outer(i, j) = x(i)*y(j)
         enddo
      enddo
   end function outer_prod

   subroutine wavef2rs_cmplx(fi, lapw, stars, zmat, bandoi, bandof, jspin, psi)
      use m_types
      use m_fft_interface
      implicit none
      type(t_fleurinput), intent(in) :: fi
      type(t_lapw), intent(in)       :: lapw
      type(t_mat), intent(in)        :: zmat
      type(t_stars), intent(in)      :: stars
      integer, intent(in)            :: jspin, bandoi, bandof
      complex, intent(inout)         :: psi(0:,bandoi:) ! (nv,ne)

      integer :: ivmap(SIZE(lapw%gvec, 2))
      integer :: iv, nu
      integer :: length_zfft(3), fft_idx(3)


      DO iv = 1, lapw%nv(jspin)
         ivmap(iv) = stars%g2fft(lapw%gvec(:, iv, jspin))
      ENDDO

      psi = 0.0
      do nu = bandoi, bandof
         !------> map WF nto FFTbox
         DO iv = 1, lapw%nv(jspin)
            psi(ivmap(iv), nu) = zMat%data_c(iv, nu)
         ENDDO

         length_zfft = [stars%kq1_fft, stars%kq2_fft, stars%kq3_fft]
         call fft_interface(3, length_zfft, psi(:,nu), .false., ivmap(1:lapw%nv(jspin)))
      enddo
   end subroutine wavef2rs_cmplx
end module m_wavefproducts_aux
