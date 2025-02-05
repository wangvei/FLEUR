!--------------------------------------------------------------------------------
! Copyright (c) 2016 Peter Grünberg Institut, Forschungszentrum Jülich, Germany
! This file is part of FLEUR and available as free software under the conditions
! of the MIT license as expressed in the LICENSE file in more detail.
!--------------------------------------------------------------------------------


!>This module defines the basic type for calculations of force-theorem type
!! Here only a dummy is defined that should be extended by a custom made data-type
!! The functionality is encoded into four functions/subroutines:
!! start: This routine is called in each SC-loop before the force theorem-loop
!! next_job: This function returns .true. if another job should be done, it also modifies its
!!           arguments appropriately to perform the calculation
!! eval: Here the calculation is done in this function, the results might be stored in
!!           MODULE variables, IF a .TRUE. is returned, the rest of the loop (charge generation)
!!           is skipped
!! postprocess: After the calculation here some IO etc. can be done
!!
!!
!! An example for a non-trivial force-theorem type extending this datatype can be found in
!! forcetheorem/mae.F90

MODULE m_types_forcetheo
  USE m_juDFT 
  IMPLICIT NONE
  PRIVATE
  PUBLIC:: t_forcetheo
  TYPE :: t_forcetheo
     LOGICAL,PRIVATE :: firstloop=.false.
     LOGICAL :: l_IO=.true.
     LOGICAL :: l_needs_vectors=.true.
     logical :: l_in_forcetheo_loop=.false.
   CONTAINS
     PROCEDURE :: start   =>forcetheo_start
     PROCEDURE :: next_job=>forcetheo_next_job
     PROCEDURE :: eval    =>forcetheo_eval
     PROCEDURE :: postprocess => forcetheo_postprocess
  END TYPE t_forcetheo

CONTAINS
  SUBROUTINE forcetheo_start(this,potden,l_io)
    USE m_types_potden
    IMPLICIT NONE
    CLASS(t_forcetheo),INTENT(INOUT):: this
    TYPE(t_potden) ,INTENT(INOUT)   :: potden
    LOGICAL,INTENT(IN)              :: l_io
    this%firstloop=.TRUE.
    this%l_io=l_io
  END SUBROUTINE forcetheo_start

  LOGICAL FUNCTION forcetheo_next_job(this,fmpi,lastiter,atoms,noco,nococonv)
    USE m_types_atoms
    USE m_types_noco
    USE m_types_nococonv
    USE m_types_mpi
    IMPLICIT NONE
    CLASS(t_forcetheo),INTENT(INOUT)    :: this
    TYPE(t_mpi), INTENT(IN)             :: fmpi
    LOGICAL,INTENT(IN)                  :: lastiter
    TYPE(t_atoms),INTENT(IN)            :: atoms
    TYPE(t_noco),INTENT(IN)             :: noco
    !Stuff that might be modified...
    TYPE(t_nococonv),INTENT(INOUT) :: nococonv
    forcetheo_next_job=this%firstloop
    this%firstloop=.FALSE.
  END FUNCTION forcetheo_next_job

  FUNCTION forcetheo_eval(this,eig_id,atoms,kpts,sym,&
       cell,noco,nococonv, input,fmpi,  enpara,v,results)RESULT(skip)
    USE m_types_atoms
     
    USE m_types_input
    USE m_types_noco
    USE m_types_sym
    USE m_types_cell
    USE m_types_mpi
    USE m_types_potden
    USE m_types_misc
    USE m_types_kpts
    USE m_types_enpara
    USE m_types_nococonv

    IMPLICIT NONE
    CLASS(t_forcetheo),INTENT(INOUT):: this
    LOGICAL :: skip
    !Stuff that might be used...
    TYPE(t_mpi),INTENT(IN)         :: fmpi

     
    TYPE(t_input),INTENT(IN)       :: input
    TYPE(t_noco),INTENT(IN)        :: noco
    TYPE(t_nococonv),INTENT(IN)    :: nococonv
    TYPE(t_sym),INTENT(IN)         :: sym
    TYPE(t_cell),INTENT(IN)        :: cell
    TYPE(t_kpts),INTENT(IN)        :: kpts
    TYPE(t_atoms),INTENT(IN)       :: atoms
    TYPE(t_enpara),INTENT(IN)      :: enpara
    TYPE(t_potden),INTENT(IN)      :: v
    TYPE(t_results),INTENT(IN)     :: results
    INTEGER,INTENT(IN)             :: eig_id
    skip=.FALSE.
  END FUNCTION forcetheo_eval

  SUBROUTINE forcetheo_postprocess(this)
    IMPLICIT NONE
    CLASS(t_forcetheo),INTENT(INOUT):: this
  END SUBROUTINE forcetheo_postprocess


END MODULE m_types_forcetheo
