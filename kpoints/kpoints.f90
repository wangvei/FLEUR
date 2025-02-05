!--------------------------------------------------------------------------------
! Copyright (c) 2016 Peter Grünberg Institut, Forschungszentrum Jülich, Germany
! This file is part of FLEUR and available as free software under the conditions
! of the MIT license as expressed in the LICENSE file in more detail.
!--------------------------------------------------------------------------------

module m_kpoints
contains
  subroutine kpoints( sym,cell,input,noco,banddos,kpts,l_kpts)
    USE m_juDFT
    USE m_types
    USE m_julia
    USE m_kptgen_hybrid
     
    USE m_unfold_band_kpts
  
    implicit none
    TYPE(t_input),INTENT(IN)   :: input
    TYPE(t_sym),INTENT(IN)     :: sym
     
    TYPE(t_cell),INTENT(IN)     :: cell
    TYPE(t_banddos),INTENT(IN)  :: banddos
    TYPE(t_noco),INTENT(IN)     :: noco
    TYPE(t_kpts),INTENT(INOUT)  :: kpts
    LOGICAL,INTENT(IN)          :: l_kpts
    TYPE(t_kpts)                :: p_kpts
    TYPE(t_cell)                :: p_cell
    TYPE(t_kpts)                :: tmp_kpts

    TYPE(t_sym) :: sym_hlp

    IF (input%l_wann) THEN
       IF (kpts%specificationType.NE.2 .AND. kpts%specificationType.NE.3) THEN
          CALL juDFT_error('l_wann only with kPointMesh or kPointListFile', calledby = 'kpoints')
       END IF
    END IF

    IF (.NOT.l_kpts) THEN
          IF (input%l_wann) THEN
             sym_hlp=sym
             sym_hlp%nop=1
             sym_hlp%nop2=1
             CALL kptgen_hybrid(input,cell,sym_hlp,kpts,noco%l_soc,.FALSE.)
          ELSE IF (.FALSE.) THEN !this was used to generate q-points in jij case
             sym_hlp=sym
             sym_hlp%nop=1
             sym_hlp%nop2=1
             CALL julia(sym_hlp,cell,input,noco,banddos,kpts,.FALSE.,.TRUE.)
          ELSE IF (kpts%l_gamma.and.(banddos%ndir.eq.0)) THEN
             CALL kptgen_hybrid(input,cell,sym,kpts,noco%l_soc,.FALSE.)
          ELSE
             IF (banddos%unfoldband) THEN
               CALL unfold_band_kpts(banddos,p_cell,cell,p_kpts,kpts)
 	            CALL julia(sym,cell,input,noco,banddos,kpts,.FALSE.,.TRUE.)
               CALL julia(sym,p_cell,input,noco,banddos,p_kpts,.FALSE.,.TRUE.)
               CALL find_supercell_kpts(banddos,p_cell,cell,p_kpts,kpts)
             ELSE
               CALL julia(sym,cell,input,noco,banddos,kpts,.FALSE.,.TRUE.)
             END IF
          END IF
      
       !Rescale weights and kpoints
       IF (.not.banddos%unfoldband) THEN
          kpts%wtkpt(:) = kpts%wtkpt(:) / sum(kpts%wtkpt)
       END IF
       kpts%bk(:,:) = kpts%bk(:,:) / kpts%posScale
       kpts%posScale = 1.0
       IF (kpts%nkpt3(3).EQ.0) kpts%nkpt3(3) = 1
    ELSE
       IF (banddos%unfoldband) THEN
          CALL unfold_band_kpts(banddos,p_cell,cell,p_kpts,kpts)
          CALL find_supercell_kpts(banddos,p_cell,cell,p_kpts,kpts)
       END IF
    END IF

end subroutine kpoints
end module m_kpoints
