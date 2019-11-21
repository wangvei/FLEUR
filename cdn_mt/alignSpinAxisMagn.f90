!--------------------------------------------------------------------------------
! Copyright (c) 2018 Peter Grünberg Institut, Forschungszentrum Jülich, Germany
! This file is part of FLEUR and avhttps://gcc.gnu.org/onlinedocs/gfortran/SQRT.htmlailable as free software under the conditions
! of the MIT license as expressed in the LICENSE file in more detail.
!------------------------------------------------------------------------------
!  This routine allows to rotate the cdn in a way that the direction of magnetization aligns with the direction of the spin quantization axis. 
!  This routine also allows to reverse the rotation by using the angles stored in atoms (phi_mt_avg,theta_mt_avg) which are generated by the 
!  routine magnMomFromDen. 
!
! Robin Hilgers, Nov '19
MODULE m_alignSpinAxisMagn

USE m_magnMomFromDen
USE m_types
USE m_flipcdn
USE m_constants

CONTAINS
SUBROUTINE rotateMagnetToSpinAxis(vacuum,sphhar,stars&
,sym,oneD,cell,noco,input,atoms,den)
   TYPE(t_input), INTENT(INOUT)  :: input
   TYPE(t_atoms), INTENT(INOUT)  :: atoms
   TYPE(t_noco), INTENT(INOUT)   :: noco
   TYPE(t_stars),INTENT(IN)      :: stars
   TYPE(t_vacuum),INTENT(IN)     :: vacuum
   TYPE(t_sphhar),INTENT(IN)     :: sphhar
   TYPE(t_sym),INTENT(IN)        :: sym
   TYPE(t_oneD),INTENT(IN)       :: oneD
   TYPE(t_cell),INTENT(IN)       :: cell
   TYPE(t_potden), INTENT(INOUT) :: den 
   REAL                          :: moments(atoms%ntype,3)
   REAL                          :: phiTemp(atoms%ntype),thetaTemp(atoms%ntype)   
   
   phiTemp=mod(atoms%phi_mt_avg,2*pimach())
   thetaTemp=mod(atoms%theta_mt_avg,2*pimach())
   CALL magnMomFromDen(input,atoms,noco,den,moments)
   write(*,*) "mx1"
   write(*,*) moments(1,1)
   write(*,*) "mz1"
   write(*,*) moments(1,3)
   write(*,*) "mx2"
   write(*,*) moments(2,1)
   write(*,*) "mz2"
   write(*,*) moments(2,3)
   CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco,oneD,cell,-atoms%phi_mt_avg,-atoms%theta_mt_avg,den)
   noco%alph=mod(atoms%phi_mt_avg+noco%alph,2*pimach())
   noco%beta=mod(atoms%theta_mt_avg+noco%beta,2*pimach())


   atoms%phi_mt_avg=mod(atoms%phi_mt_avg+phiTemp,2*pimach())
   atoms%theta_mt_avg=mod(atoms%theta_mt_avg+thetaTemp,2*pimach())
   write(*,*) "Phi Total"
   write(*,*) atoms%phi_mt_avg
   write(*,*) "Theta Total"
   write(*,*) atoms%theta_mt_avg

END SUBROUTINE rotateMagnetToSpinAxis


SUBROUTINE rotateMagnetFromSpinAxis(noco,vacuum,sphhar,stars&
,sym,oneD,cell,input,atoms,den)
   TYPE(t_input), INTENT(INOUT)  :: input
   TYPE(t_atoms), INTENT(INOUT)  :: atoms
   TYPE(t_noco), INTENT(IN)	 :: noco
   TYPE(t_stars),INTENT(IN)	 :: stars
   TYPE(t_vacuum),INTENT(IN)     :: vacuum
   TYPE(t_sphhar),INTENT(IN)     :: sphhar
   TYPE(t_sym),INTENT(IN)        :: sym
   TYPE(t_oneD),INTENT(IN)	 :: oneD
   TYPE(t_cell),INTENT(IN)	 :: cell
   TYPE(t_potden), INTENT(INOUT) :: den 


   CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco,oneD,cell,atoms%phi_mt_avg,atoms%theta_mt_avg,den)
   atoms%flipSpinPhi=0
   atoms%flipSpinTheta=0


END SUBROUTINE rotateMagnetFromSpinAxis


END MODULE m_alignSpinAxisMagn

