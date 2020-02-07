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
USE m_types_fleurinput
USE m_flipcdn
USE m_constants
USE m_polangle
IMPLICIT NONE

CONTAINS
SUBROUTINE rotateMagnetToSpinAxis(vacuum,sphhar,stars&
,sym,oneD,cell,noco,nococonv,input,atoms,den)
   TYPE(t_input), INTENT(IN)     :: input
   TYPE(t_atoms), INTENT(IN)     :: atoms
   TYPE(t_noco), INTENT(IN)      :: noco
   TYPE(t_nococonv),INTENT(INOUT):: nococonv
   TYPE(t_stars),INTENT(IN)      :: stars
   TYPE(t_vacuum),INTENT(IN)     :: vacuum
   TYPE(t_sphhar),INTENT(IN)     :: sphhar
   TYPE(t_sym),INTENT(IN)        :: sym
   TYPE(t_oneD),INTENT(IN)       :: oneD
   TYPE(t_cell),INTENT(IN)       :: cell
   TYPE(t_potden), INTENT(INOUT) :: den

   REAL                          :: moments(3,atoms%ntype)
   REAL                          :: phiTemp(atoms%ntype),thetaTemp(atoms%ntype)
   integer                       ::  i
   CALL magnMomFromDen(input,atoms,noco,den,moments,thetaTemp,phiTemp)
   DO i=1, atoms%ntype
     IF(thetaTemp(i).LE.10**(-3)) thetaTemp(i)=0
     IF(phiTemp(i).LE.10**(-3)) phiTemp(i)=0
   END DO
   CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco,oneD,cell,-phiTemp,-thetaTemp,den)

   nococonv%alph=mod(nococonv%alph+phiTemp,2*pimach())

   nococonv%beta=mod(nococonv%beta+thetaTemp,2*pimach())
   write(*,*) "Noco Phi"
   write(*,*) nococonv%alph
   write(*,*) "Noco Theta"
   write(*,*) nococonv%beta
END SUBROUTINE rotateMagnetToSpinAxis


SUBROUTINE rotateMagnetFromSpinAxis(noco,nococonv,vacuum,sphhar,stars&
,sym,oneD,cell,input,atoms,den,inDen)
   TYPE(t_input), INTENT(IN)  :: input
   TYPE(t_atoms), INTENT(IN)  :: atoms
   TYPE(t_noco), INTENT(IN)	  :: noco
   TYPE(t_nococonv), INTENT(INOUT)	 :: nococonv
   TYPE(t_stars),INTENT(IN)	  :: stars
   TYPE(t_vacuum),INTENT(IN)     :: vacuum
   TYPE(t_sphhar),INTENT(IN)     :: sphhar
   TYPE(t_sym),INTENT(IN)        :: sym
   TYPE(t_oneD),INTENT(IN)	 :: oneD
   TYPE(t_cell),INTENT(IN)	 :: cell
   TYPE(t_potden), INTENT(INOUT) :: den, inDen


   CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco,oneD,cell,nococonv%alph,nococonv%beta,den)
   CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco,oneD,cell,nococonv%alph,nococonv%beta,inDen)

   nococonv%alph=0
   nococonv%beta=0

END SUBROUTINE rotateMagnetFromSpinAxis


END MODULE m_alignSpinAxisMagn
