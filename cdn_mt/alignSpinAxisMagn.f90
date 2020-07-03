!--------------------------------------------------------------------------------
! Copyright (c) 2018 Peter Grünberg Institut, Forschungszentrum Jülich, Germany
! This file is part of FLEUR and available as free software under the conditions
! of the MIT license as expressed in the LICENSE file in more detail.
!------------------------------------------------------------------------------
!  This routine allows to rotate the cdn in a way that the direction of magnetization aligns with the direction of the spin quantization axis.
!  This routine also allows to reverse the rotation by using the angles stored in atoms (nococonv%alph,nococonv%beta) which are generated by the
!  routine magnMomFromDen.
!
! Robin Hilgers, Nov  '19 Adaption to new nococonv type in Feb '20, Added RelaxMixing parameter + Allow Relaxation of alpha and Beta individually Jul '20'
MODULE m_RelaxSpinAxisMagn


USE m_magnMomFromDen
USE m_types
USE m_types_fleurinput
USE m_flipcdn
USE m_constants
USE m_polangle

IMPLICIT NONE

CONTAINS

!Rotates cdn to global frame at initialization before the scf loop.
SUBROUTINE initRelax(noco,nococonv,atoms,input,vacuum,sphhar,stars,sym,oneD,cell,den)
   TYPE(t_input),     INTENT(IN)    :: input
   TYPE(t_atoms),     INTENT(IN)    :: atoms
   TYPE(t_noco),      INTENT(IN)    :: noco
   TYPE(t_nococonv),  INTENT(INOUT) :: nococonv
   TYPE(t_stars),     INTENT(IN)    :: stars
   TYPE(t_vacuum),    INTENT(IN)    :: vacuum
   TYPE(t_sphhar),    INTENT(IN)    :: sphhar
   TYPE(t_sym),       INTENT(IN)    :: sym
   TYPE(t_oneD),      INTENT(IN)    :: oneD
   TYPE(t_cell),      INTENT(IN)    :: cell
   TYPE(t_potden),    INTENT(INOUT) :: den
   
   REAL                             ::zeros(atoms%ntype)
   zeros(:)=0.0
   ALLOCATE(nococonv%alphPrev(atoms%ntype),nococonv%betaPrev(atoms%ntype))
   nococonv%alphPrev=noco%alph_inp
   nococonv%betaPrev=noco%beta_inp
   
   IF(.NOT.noco%l_RelaxAlpha)  THEN
      ALLOCATE(nococonv%alphRlx(atoms%ntype))
      nococonv%alphRlx=noco%alph_inp
   END IF
   IF(.NOT.noco%l_RelaxBeta)  THEN
      ALLOCATE(nococonv%betaRlx(atoms%ntype))
      nococonv%betaRlx=noco%beta_inp
   END IF
    CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco,oneD,cell,zeros,noco%beta_inp,den)
    CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco,oneD,cell,noco%alph_inp,zeros,den)
    nococonv%alph=zeros
    nococonv%beta=zeros
   
   

   END SUBROUTINE initRelax
   
 !Decides which relaxation routine will be executed based on which angles should be relaxed. 
   SUBROUTINE doRelax(vacuum,sphhar,stars&
        ,sym,oneD,cell,noco,nococonv,input,atoms,den)
        
   TYPE(t_input),     INTENT(IN)    :: input
   TYPE(t_atoms),     INTENT(IN)    :: atoms
   TYPE(t_noco),      INTENT(IN)    :: noco
   TYPE(t_nococonv),  INTENT(INOUT) :: nococonv
   TYPE(t_stars),     INTENT(IN)    :: stars
   TYPE(t_vacuum),    INTENT(IN)    :: vacuum
   TYPE(t_sphhar),    INTENT(IN)    :: sphhar
   TYPE(t_sym),       INTENT(IN)    :: sym
   TYPE(t_oneD),      INTENT(IN)    :: oneD
   TYPE(t_cell),      INTENT(IN)    :: cell
   TYPE(t_potden),    INTENT(INOUT) :: den

   IF (noco%l_RelaxAlpha.AND.noco%l_RelaxBeta) CALL bothRelax(vacuum,sphhar,stars&
        ,sym,oneD,cell,noco,nococonv,input,atoms,den)
   IF (noco%l_RelaxAlpha.AND..NOT.noco%l_RelaxBeta) CALL alphaRelax(vacuum,sphhar,stars&
        ,sym,oneD,cell,noco,nococonv,input,atoms,den)
   IF (.NOT.noco%l_RelaxAlpha.AND.noco%l_RelaxBeta) CALL betaRelax(vacuum,sphhar,stars&
        ,sym,oneD,cell,noco,nococonv,input,atoms,den)


END SUBROUTINE doRelax

!Relaxation routine for only relaxing alpha. How it works: See two routines below.
SUBROUTINE alphaRelax(vacuum,sphhar,stars&
        ,sym,oneD,cell,noco,nococonv,input,atoms,den)
   TYPE(t_input),   INTENT(IN)    :: input
   TYPE(t_atoms),   INTENT(IN)    :: atoms
   TYPE(t_noco),    INTENT(IN)    :: noco
   TYPE(t_nococonv),INTENT(INOUT) :: nococonv
   TYPE(t_stars),   INTENT(IN)    :: stars
   TYPE(t_vacuum),  INTENT(IN)    :: vacuum
   TYPE(t_sphhar),  INTENT(IN)    :: sphhar
   TYPE(t_sym),     INTENT(IN)    :: sym
   TYPE(t_oneD),    INTENT(IN)    :: oneD
   TYPE(t_cell),    INTENT(IN)    :: cell
   TYPE(t_potden),  INTENT(INOUT) :: den
   
   REAL                           :: moments(3,atoms%ntype)
   REAL                           :: diffT(atoms%ntype),diffP(atoms%ntype), zeros(atoms%ntype)
   zeros(:)=0.0

   CALL gimmeAngles(input,atoms,noco,vacuum,sphhar,stars,den,diffP,diffT)
   CALL cureTooSmallAngles(atoms,diffT,diffP)
   diffP=diffP-nococonv%alphPrev
   diffP=diffP*noco%mix_RelaxWeightOffD
   CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco,oneD,cell,-diffP-nococonv%alphPrev,zeros,den)
   CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco,oneD,cell,zeros,-nococonv%betaRlx,den)
   nococonv%beta=nococonv%betaRlx
   nococonv%betaPrev=nococonv%betaRlx
   nococonv%alph=nococonv%alphPrev+diffP
   nococonv%alphPrev=nococonv%alph
   CALL cureTooSmallAngles(atoms,nococonv%alph)
END SUBROUTINE alphaRelax

!Relaxation routine for only relaxing beta. How it works: See one routine below.
SUBROUTINE betaRelax(vacuum,sphhar,stars&
        ,sym,oneD,cell,noco,nococonv,input,atoms,den)
   TYPE(t_input),   INTENT(IN)    :: input
   TYPE(t_atoms),   INTENT(IN)    :: atoms
   TYPE(t_noco),    INTENT(IN)    :: noco
   TYPE(t_nococonv),INTENT(INOUT) :: nococonv
   TYPE(t_stars),   INTENT(IN)    :: stars
   TYPE(t_vacuum),  INTENT(IN)    :: vacuum
   TYPE(t_sphhar),  INTENT(IN)    :: sphhar
   TYPE(t_sym),     INTENT(IN)    :: sym
   TYPE(t_oneD),    INTENT(IN)    :: oneD
   TYPE(t_cell),    INTENT(IN)    :: cell
   TYPE(t_potden),  INTENT(INOUT) :: den
   
   LOGICAL                        :: nonZeroAngles 
   REAL                           :: moments(3,atoms%ntype)
   REAL                           :: diffT(atoms%ntype),diffP(atoms%ntype), zeros(atoms%ntype)
   zeros(:)=0.0

   CALL gimmeAngles(input,atoms,noco,vacuum,sphhar,stars,den,diffP,diffT)
   CALL cureTooSmallAngles(atoms,diffT,diffP)
   diffT=diffT-nococonv%betaPrev
   diffT=diffT*noco%mix_RelaxWeightOffD
   CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco,oneD,cell,-nococonv%alphRlx,zeros,den)
   CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco,oneD,cell,zeros,-diffT-nococonv%betaPrev,den)
   nococonv%beta=nococonv%betaPrev+diffT
   nococonv%betaPrev=nococonv%beta
   nococonv%alph=nococonv%alphRlx
   CALL cureTooSmallAngles(atoms,nococonv%beta)
END SUBROUTINE betaRelax

!Relaxation routine for both angles at the same time. Calculates the angles by which the magnetization direction changed
!based on the angle nococonv%*Prev which store the angles from the previous iteration. The resulting angular difference is then weighted (mix_RelaxWeightOffD)
!and the cdn will be manipulated so that the magnetization direction is rotated towards the new magnetization direction by AngularDifference*Weight.
!If both angles are relaxed: weight=1 direction of magnetization is || to SQA after relaxation. 
SUBROUTINE bothRelax(vacuum,sphhar,stars&
        ,sym,oneD,cell,noco,nococonv,input,atoms,den)
   TYPE(t_input),   INTENT(IN)    :: input
   TYPE(t_atoms),   INTENT(IN)    :: atoms
   TYPE(t_noco),    INTENT(IN)    :: noco
   TYPE(t_nococonv),INTENT(INOUT) :: nococonv
   TYPE(t_stars),   INTENT(IN)    :: stars
   TYPE(t_vacuum),  INTENT(IN)    :: vacuum
   TYPE(t_sphhar),  INTENT(IN)    :: sphhar
   TYPE(t_sym),     INTENT(IN)    :: sym
   TYPE(t_oneD),    INTENT(IN)    :: oneD
   TYPE(t_cell),    INTENT(IN)    :: cell
   TYPE(t_potden),  INTENT(INOUT) :: den

   LOGICAL                        :: nonZeroAngles 
   REAL                           :: moments(3,atoms%ntype)
   REAL                           :: diffT(atoms%ntype),diffP(atoms%ntype), zeros(atoms%ntype)
   zeros(:)=0.0

   CALL gimmeAngles(input,atoms,noco,vacuum,sphhar,stars,den,diffP,diffT)
   CALL cureTooSmallAngles(atoms,diffT,diffP)
   diffT=diffT-nococonv%betaPrev
   diffT=diffT*noco%mix_RelaxWeightOffD
   diffP=diffP-nococonv%alphPrev
   diffP=diffP*noco%mix_RelaxWeightOffD
   CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco,oneD,cell,-diffP-nococonv%alphPrev,zeros,den)
   CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco,oneD,cell,zeros,-diffT-nococonv%betaPrev,den)
   nococonv%beta=nococonv%betaPrev+diffT
   nococonv%betaPrev=nococonv%beta
   nococonv%alph=nococonv%alphPrev+diffP
   nococonv%alphPrev=nococonv%alph
   CALL cureTooSmallAngles(atoms,nococonv%beta,nococonv%alph)
END SUBROUTINE bothRelax

!Purges to small  angles below 10^-4 rad to 0. => Stabilizes convergence.
SUBROUTINE cureTooSmallAngles(atoms,angleA,angleB)
   TYPE(t_atoms),INTENT(IN)               :: atoms
   REAL         ,INTENT(INOUT)            :: angleA(:)
   REAL         ,INTENT(INOUT), OPTIONAL  :: angleB(:)    
   
   REAL                                   :: eps 
   INTEGER                                :: i
   eps=0.0001
   DO i=1, atoms%ntype
      IF (abs(angleA(i)).LE.eps) angleA(i)=0.0
      IF(PRESENT(angleB).AND.abs(angleB(i)).LE.eps) angleB(i)=0.0
   END DO
END SUBROUTINE cureTooSmallAngles

!Calculates angles from magnetization and assigns correct sign to be used in the rotation (flipcdn) routine properly.
SUBROUTINE gimmeAngles(input,atoms,noco,vacuum,sphhar,stars,den,phiTemp,thetaTemp)
   TYPE(t_input) ,INTENT(IN)     :: input
   TYPE(t_atoms) ,INTENT(IN)     :: atoms
   TYPE(t_noco)  ,INTENT(IN)     :: noco
   TYPE(t_stars) ,INTENT(IN)     :: stars
   TYPE(t_vacuum),INTENT(IN)     :: vacuum
   TYPE(t_sphhar),INTENT(IN)     :: sphhar
   TYPE(t_potden),INTENT(IN)     :: den
   REAL          ,INTENT(OUT)    :: phiTemp(atoms%ntype),thetaTemp(atoms%ntype)
   
   REAL                          :: moments(3,atoms%ntype)

   CALL magnMomFromDen(input,atoms,noco,den,moments,thetaTemp,phiTemp)
   phiTemp(:)=(-1)*phiTemp(:)

END SUBROUTINE gimmeAngles

!Rotates from global frame into that frame which has been determined by the latest relaxation process.
SUBROUTINE fromGlobalRelax(vacuum,sphhar,stars&
        ,sym,oneD,cell,noco,nococonv,input,atoms,den)

   TYPE(t_input), INTENT(IN)             :: input
   TYPE(t_atoms), INTENT(IN)             :: atoms
   TYPE(t_noco), INTENT(IN)              :: noco
   TYPE(t_nococonv), INTENT(INOUT)       :: nococonv
   TYPE(t_stars),INTENT(IN)              :: stars
   TYPE(t_vacuum),INTENT(IN)             :: vacuum
   TYPE(t_sphhar),INTENT(IN)             :: sphhar
   TYPE(t_sym),INTENT(IN)                :: sym
   TYPE(t_oneD),INTENT(IN)               :: oneD
   TYPE(t_cell),INTENT(IN)               :: cell
   TYPE(t_potden), OPTIONAL,INTENT(INOUT):: den
   REAL                                  :: zeros(atoms%ntype)

   CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco,oneD,cell,-nococonv%alphPrev,zeros,den)
   CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco,oneD,cell,zeros,-nococonv%betaPrev,den)
   nococonv%alph=nococonv%alphPrev
   nococonv%beta=nococonv%betaPrev
   
END SUBROUTINE fromGlobalRelax

!Rotates into the global frame so mixing can be performed without any restrictions. => Compatible with anderson mixing scheme.
SUBROUTINE toGlobalRelax(noco,nococonv,vacuum,sphhar,stars&
,sym,oneD,cell,input,atoms,inDen, den)
   TYPE(t_input), INTENT(IN)             :: input
   TYPE(t_atoms), INTENT(IN)             :: atoms
   TYPE(t_noco), INTENT(IN)              :: noco
   TYPE(t_nococonv), INTENT(INOUT)       :: nococonv
   TYPE(t_stars),INTENT(IN)              :: stars
   TYPE(t_vacuum),INTENT(IN)             :: vacuum
   TYPE(t_sphhar),INTENT(IN)             :: sphhar
   TYPE(t_sym),INTENT(IN)                :: sym
   TYPE(t_oneD),INTENT(IN)               :: oneD
   TYPE(t_cell),INTENT(IN)               :: cell
   TYPE(t_potden), INTENT(INOUT)         :: inDen
   TYPE(t_potden), OPTIONAL,INTENT(INOUT):: den

   REAL                                  :: zeros(atoms%ntype)


   zeros(:)=0.0
   CAlL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco,oneD,cell,zeros,nococonv%beta,inDen)
   CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco,oneD,cell,nococonv%alph,zeros,inDen)
   IF (present(den)) THEN
      CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco,oneD,cell,zeros,nococonv%beta,den)
      CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco,oneD,cell,nococonv%alph,zeros,den)
   END IF
! Nococonv is zero now since rotation has been reverted.
   nococonv%alphPrev=nococonv%alph
   nococonv%betaPrev=nococonv%beta
   nococonv%alph=zeros
   nococonv%beta=zeros


END SUBROUTINE toGlobalRelax


END MODULE m_RelaxSpinAxisMagn
