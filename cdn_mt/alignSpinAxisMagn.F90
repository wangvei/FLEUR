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
MODULE m_Relaxspinaxismagn

USE m_magnMomFromDen
USE m_types
USE m_types_fleurinput
USE m_flipcdn
USE m_constants
USE m_polangle

IMPLICIT NONE

CONTAINS

!Rotates cdn to global frame at initialization before the scf loop.
SUBROUTINE initRelax(noco,nococonv,atoms,input,vacuum,sphhar,stars,sym ,cell,den)
   TYPE(t_input),     INTENT(IN)    :: input
   TYPE(t_atoms),     INTENT(IN)    :: atoms
   TYPE(t_noco),      INTENT(IN)    :: noco
   TYPE(t_nococonv),  INTENT(INOUT) :: nococonv
   TYPE(t_stars),     INTENT(IN)    :: stars
   TYPE(t_vacuum),    INTENT(IN)    :: vacuum
   TYPE(t_sphhar),    INTENT(IN)    :: sphhar
   TYPE(t_sym),       INTENT(IN)    :: sym
    
   TYPE(t_cell),      INTENT(IN)    :: cell
   TYPE(t_potden),    INTENT(INOUT) :: den

   REAL                             ::zeros(atoms%ntype)
   zeros(:)=0.0
   ALLOCATE(nococonv%alphPrev(atoms%ntype),nococonv%betaPrev(atoms%ntype))
   nococonv%alphPrev=noco%alph_inp
   nococonv%betaPrev=noco%beta_inp

    CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco ,cell,zeros,noco%beta_inp,den)
    CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco ,cell,noco%alph_inp,zeros,den)
    nococonv%alph=zeros
    nococonv%beta=zeros

   END SUBROUTINE initRelax

   SUBROUTINE precond_noco(it,vacuum,sphhar,stars,sym ,cell,noco,nococonv,input,atoms,inden,outden,fsm)
     use m_types_mixvector
     INTEGER,INTENT(IN)               :: it
     TYPE(t_input),     INTENT(IN)    :: input
     TYPE(t_atoms),     INTENT(IN)    :: atoms
     TYPE(t_noco),      INTENT(IN)    :: noco
     TYPE(t_nococonv),  INTENT(IN)    :: nococonv
     TYPE(t_stars),     INTENT(IN)    :: stars
     TYPE(t_vacuum),    INTENT(IN)    :: vacuum
     TYPE(t_sphhar),    INTENT(IN)    :: sphhar
     TYPE(t_sym),       INTENT(IN)    :: sym
      
     TYPE(t_cell),      INTENT(IN)    :: cell
     TYPE(t_potden),    INTENT(IN)    :: inden
     TYPE(t_potden),    INTENT(INOUT) :: outden
     TYPE(t_mixvector), INTENT(INOUT)   :: fsm

     if (.not.(noco%l_noco.and.any(noco%l_alignMT))) return

     select case (noco%mag_mixing_scheme)
     case(1)
       if (it>1) return
       call precond_noco_anglerotate(vacuum,sphhar,stars,sym ,cell,noco,nococonv,input,atoms,inden,outden,fsm)
     case(2)
       call precond_noco_anglerotate(vacuum,sphhar,stars,sym ,cell,noco,nococonv,input,atoms,inden,outden,fsm)
     case(3)
       call precond_noco_densitymatrix(vacuum,sphhar,stars,sym ,cell,noco,nococonv,input,atoms,inden,outden,fsm)
     end select
   END subroutine precond_noco

   !Preconditioner to control relaxation of the direction of the magnetic moment
   SUBROUTINE precond_noco_anglerotate(vacuum,sphhar,stars,sym ,cell,noco,nococonv,input,atoms,inden,outden,fsm)
     use m_types_mixvector
     TYPE(t_input),     INTENT(IN)    :: input
     TYPE(t_atoms),     INTENT(IN)    :: atoms
     TYPE(t_noco),      INTENT(IN)    :: noco
     TYPE(t_nococonv),  INTENT(IN)    :: nococonv
     TYPE(t_stars),     INTENT(IN)    :: stars
     TYPE(t_vacuum),    INTENT(IN)    :: vacuum
     TYPE(t_sphhar),    INTENT(IN)    :: sphhar
     TYPE(t_sym),       INTENT(IN)    :: sym
      
     TYPE(t_cell),      INTENT(IN)    :: cell
     TYPE(t_potden),    INTENT(IN)    :: inden
     TYPE(t_potden),    INTENT(INOUT) :: outden
     TYPE(t_mixvector), INTENT(OUT)   :: fsm

     real,dimension(atoms%ntype) :: dphi,dtheta,zeros
     TYPE(t_potden)              :: delta_den,outden_rot
     integer                     :: n
     zeros(:) = 0.0
     !Put outden in local frame of inden
     CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco ,cell,-nococonv%alphPrev,zeros,outden)
     CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco ,cell,zeros,-nococonv%betaPrev,outden)
     !rotation angle
     CALL gimmeAngles(input,atoms,noco,vacuum,sphhar,stars,outden,dPhi,dtheta)
     !dphi   = dphi  *(noco%mix_RelaxWeightOffD-1.0)
     dtheta = dtheta *(noco%mix_RelaxWeightOffD-1.0)

     !if (any(abs(dphi)>2.0).or.any(abs(dtheta)>2.0)) THEN
     !   print *,"No precond"
      ! dphi=0.0
       !dtheta=0.0
     !endif

     !Scale Off-diagonal parts
     !DO n=1,atoms%ntype
      !  outden%mt(:,0:,n,3)=outden%mt(:,0:,n,3)*noco%mix_RelaxWeightOffD(n)
       !outden%mt(:,0:,n,4)=outden%mt(:,0:,n,4)*noco%mix_RelaxWeightOffD(n)
     !ENDDO

     !CALL cureTooSmallAngles(atoms,dphi,dtheta)
     CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco ,cell,zeros,dtheta,outden)
     !CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco ,cell,dphi,zeros,outden)
     !Rotate back in global frame
     CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco ,cell,zeros,nococonv%betaPrev,outden)
     CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco ,cell,nococonv%alphPrev,zeros,outden)

     CALL gimmeAngles(input,atoms,noco,vacuum,sphhar,stars,outden,dPhi,dtheta)
  
     call delta_den%subPotDen(outden,inden)
     !CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco ,cell,-dphi,zeros,delta_den)
     !CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco ,cell,zeros,-dtheta,delta_den)

     call fsm%alloc()
     call fsm%from_density(delta_den)

   END SUBROUTINE precond_noco_anglerotate

      !Preconditioner to control relaxation of the direction of the magnetic moment
   SUBROUTINE precond_noco_densitymatrix(vacuum,sphhar,stars,sym ,cell,noco,nococonv,input,atoms,inden,outden,fsm)
     use m_types_mixvector
     TYPE(t_input),     INTENT(IN)    :: input
     TYPE(t_atoms),     INTENT(IN)    :: atoms
     TYPE(t_noco),      INTENT(IN)    :: noco
     TYPE(t_nococonv),  INTENT(IN)    :: nococonv
     TYPE(t_stars),     INTENT(IN)    :: stars
     TYPE(t_vacuum),    INTENT(IN)    :: vacuum
     TYPE(t_sphhar),    INTENT(IN)    :: sphhar
     TYPE(t_sym),       INTENT(IN)    :: sym
      
     TYPE(t_cell),      INTENT(IN)    :: cell
     TYPE(t_potden),    INTENT(IN)    :: inden,outden
     TYPE(t_mixvector), INTENT(OUT)   :: fsm

     TYPE(t_potden)              :: delta_den
     integer                     :: n
     real,dimension(atoms%ntype) :: zeros,theta,phi
     zeros(:) = 0.0
     call delta_den%subPotDen(outden,inden)
     !Put in local frame
     CALL gimmeAngles(input,atoms,noco,vacuum,sphhar,stars,inden,Phi,theta)
     zeros(:) = 0.0
     CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco ,cell,-phi,zeros,delta_den)
     CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco ,cell,zeros,-theta,delta_den)
     !Scale Off-diagonal parts
     DO n=1,atoms%ntype
       delta_den%mt(:,0:,n,3)=delta_den%mt(:,0:,n,3)*noco%mix_RelaxWeightOffD(n)
       delta_den%mt(:,0:,n,4)=delta_den%mt(:,0:,n,4)*noco%mix_RelaxWeightOffD(n)
     ENDDO
      !Put back in global frame
     zeros(:) = 0.0
     CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco ,cell,zeros,theta,delta_den)
     CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco ,cell,phi,zeros,delta_den)

     call fsm%alloc()
     call fsm%from_density(delta_den)


   END SUBROUTINE precond_noco_densitymatrix

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
SUBROUTINE Gimmeangles(Input,Atoms,Noco,Vacuum,Sphhar,Stars,Den,Phitemp,Thetatemp)
  use m_types_nococonv
   TYPE(t_input) ,INTENT(IN)     :: input
   TYPE(t_atoms) ,INTENT(IN)     :: atoms
   TYPE(t_noco)  ,INTENT(IN)     :: noco
   TYPE(t_stars) ,INTENT(IN)     :: stars
   TYPE(t_vacuum),INTENT(IN)     :: vacuum
   TYPE(t_sphhar),INTENT(IN)     :: sphhar
   TYPE(t_potden),INTENT(IN)     :: den
   REAL          ,INTENT(OUT)    :: phiTemp(atoms%ntype),thetaTemp(atoms%ntype)

   REAL                          :: moments(3,atoms%ntype)

  type(t_nococonv):: nococonv
  call nococonv%avg_moments(den,atoms,moments,thetatemp,phitemp)
   !!CALL magnMomFromDen(input,atoms,noco,den,moments,thetaTemp,phiTemp)
   !phiTemp(:)=(-1)*phiTemp(:)

END SUBROUTINE gimmeAngles

!Rotates from global frame into current local frame
SUBROUTINE toLocalSpinFrame(fmpi,vacuum,sphhar,stars&
        ,sym ,cell,noco,nococonv,input,atoms,l_adjust,den,l_update_nococonv)

   TYPE(t_mpi),INTENT(IN)                :: fmpi
   TYPE(t_input), INTENT(IN)             :: input
   TYPE(t_atoms), INTENT(IN)             :: atoms
   TYPE(t_noco), INTENT(IN)              :: noco
   TYPE(t_nococonv), INTENT(INOUT)       :: nococonv
   TYPE(t_stars),INTENT(IN)              :: stars
   TYPE(t_vacuum),INTENT(IN)             :: vacuum
   TYPE(t_sphhar),INTENT(IN)             :: sphhar
   TYPE(t_sym),INTENT(IN)                :: sym
    
   TYPE(t_cell),INTENT(IN)               :: cell
   LOGICAL,INTENT(IN)                    :: l_adjust
   TYPE(t_potden),INTENT(INOUT)          :: den
   LOGICAL,OPTIONAL,INTENT(IN)           :: l_update_nococonv

   REAL                                  :: zeros(atoms%ntype),alph_old(atoms%ntype),dalph
   integer :: n
   if (.not.any(noco%l_alignMT)) RETURN
   if (fmpi%irank==0) THEN
     zeros(:) = 0.0

     alph_old=nococonv%alphprev
     if (l_adjust) then
       !if (.not.allocated(nococonv%alphPrev)) allocate(nococonv%alphprev(atoms%ntype),nococonv%betaprev(atoms%ntype))
       call Gimmeangles(input,atoms,noco,vacuum,sphhar,stars,den,nococonv%alphPrev,nococonv%betaPrev)
     endif
     !Now try to minimize difference to previous angles
     !DO n=1,atoms%ntype
     !  dalph=abs(alph_old(n)-nococonv%alphPrev(n))
     !  if (abs(nococonv%alph(n)-nococonv%alphprev(n)-Pi_const)<dalph) THEN
     !    nococonv%alphprev(n)=nococonv%alphprev(n)+pi_const
     !    nococonv%betaprev(n)=-1*nococonv%betaprev(n)
     !  elseif (abs(nococonv%alph(n)-nococonv%alphprev(n)+Pi_const)<dalph) THEN
     !    nococonv%alphprev(n)=nococonv%alphprev(n)-pi_const
     !    nococonv%betaprev(n)=-1*nococonv%betaprev(n)
     !  endif
     !enddo

  
     CAlL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco ,cell,merge(nococonv%alphprev,zeros,noco%l_alignMT),merge(nococonv%betaprev,zeros,noco%l_alignMT),Den,toGlobal=.false.)
     
     !CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco ,cell,merge(-nococonv%alphPrev,zeros,noco%l_alignMT),zeros,den)
     !CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco ,cell,zeros,merge(-nococonv%betaPreV,zeros,noco%l_alignMT),den)
     if (present(l_update_nococonv)) then
       if (l_update_nococonv) THEN
         nococonv%alph=merge(nococonv%alphPrev,nococonv%alph,noco%l_alignMT)
         nococonv%beta=merge(nococonv%betaPrev,nococonv%beta,noco%l_alignMT)
         nococonv%alphPrev=0.0
         nococonv%betaPrev=0.0
       ENDIF
     ENDIF
   endif
   call den%distribute(fmpi%mpi_comm)
   call nococonv%mpi_bc(fmpi%mpi_comm)


END SUBROUTINE

!Rotates into the global frame so mixing can be performed without any restrictions. => Compatible with anderson mixing scheme.
SUBROUTINE toGlobalSpinFrame(noco,nococonv,vacuum,sphhar,stars&
,sym ,cell,input,atoms, den,fmpi,l_update_nococonv)

   TYPE(t_mpi),INTENT(IN),OPTIONAL       :: fmpi
   TYPE(t_input), INTENT(IN)             :: input
   TYPE(t_atoms), INTENT(IN)             :: atoms
   TYPE(t_noco), INTENT(IN)              :: noco
   TYPE(t_nococonv), INTENT(INOUT)       :: nococonv
   TYPE(t_stars),INTENT(IN)              :: stars
   TYPE(t_vacuum),INTENT(IN)             :: vacuum
   TYPE(t_sphhar),INTENT(IN)             :: sphhar
   TYPE(t_sym),INTENT(IN)                :: sym
    
   TYPE(t_cell),INTENT(IN)               :: cell
   TYPE(t_potden), INTENT(INOUT)         :: Den
   LOGICAL,OPTIONAL,INTENT(IN)           :: l_update_nococonv

   REAL                                  :: zeros(atoms%ntype)

   LOGICAL l_irank0
   if (.not.any(noco%l_alignMT)) RETURN

   l_irank0=.true.
   if (present(fmpi)) l_irank0=fmpi%irank==0

   if (l_irank0) then
     zeros(:)=0.0
     CAlL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco ,cell,merge(nococonv%alph,zeros,noco%l_alignMT),merge(nococonv%beta,zeros,noco%l_alignMT),Den,toGlobal=.true.)
     !CAlL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco ,cell,zeros,merge(nococonv%beta,zeros,noco%l_alignMT),Den)
     !CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco ,cell,merge(nococonv%alph,zeros,noco%l_alignMT),zeros,Den)
     ! Nococonv is zero now since rotation has been reverted.
     if (present(l_update_nococonv)) THEN
       if (l_update_nococonv) THEN
         nococonv%alphPrev=merge(nococonv%alph,nococonv%alphPrev,noco%l_alignMT)
         nococonv%betaPrev=merge(nococonv%beta,nococonv%betaPrev,noco%l_alignMT)
         nococonv%alph=merge(zeros,nococonv%alph,noco%l_alignMT)
         nococonv%beta=merge(zeros,nococonv%beta,noco%l_alignMT)
       ENDIF
     ENDIF
   ENDIF
   if (present(fmpi)) then
      call den%distribute(fmpi%mpi_comm)
      call nococonv%mpi_bc(fmpi%mpi_comm)
   endif

END SUBROUTINE

END MODULE m_RelaxSpinAxisMagn

#ifdef CPP_NEVER
!Relaxation routine for only relaxing alpha. How it works: See two routines below.
SUBROUTINE alphaRelax(vacuum,sphhar,stars&
        ,sym ,cell,noco,nococonv,input,atoms,den)
   TYPE(t_input),   INTENT(IN)    :: input
   TYPE(t_atoms),   INTENT(IN)    :: atoms
   TYPE(t_noco),    INTENT(IN)    :: noco
   TYPE(t_nococonv),INTENT(INOUT) :: nococonv
   TYPE(t_stars),   INTENT(IN)    :: stars
   TYPE(t_vacuum),  INTENT(IN)    :: vacuum
   TYPE(t_sphhar),  INTENT(IN)    :: sphhar
   TYPE(t_sym),     INTENT(IN)    :: sym
    
   TYPE(t_cell),    INTENT(IN)    :: cell
   TYPE(t_potden),  INTENT(INOUT) :: den

   REAL                           :: moments(3,atoms%ntype)
   REAL                           :: diffT(atoms%ntype),diffP(atoms%ntype), zeros(atoms%ntype)
   zeros(:)=0.0

   CALL gimmeAngles(input,atoms,noco,vacuum,sphhar,stars,den,diffP,diffT)
   CALL cureTooSmallAngles(atoms,diffT,diffP)
   diffP=diffP-nococonv%alphPrev
   diffP=diffP*noco%mix_RelaxWeightOffD
   CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco ,cell,-diffP-nococonv%alphPrev,zeros,den)
   CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco ,cell,zeros,-nococonv%betaRlx,den)
   nococonv%beta=nococonv%betaRlx
   nococonv%betaPrev=nococonv%betaRlx
   nococonv%alph=nococonv%alphPrev+diffP
   nococonv%alphPrev=nococonv%alph
   CALL cureTooSmallAngles(atoms,nococonv%alph)

END SUBROUTINE alphaRelax

!Relaxation routine for only relaxing beta. How it works: See one routine below.
SUBROUTINE betaRelax(vacuum,sphhar,stars&
        ,sym ,cell,noco,nococonv,input,atoms,den)
   TYPE(t_input),   INTENT(IN)    :: input
   TYPE(t_atoms),   INTENT(IN)    :: atoms
   TYPE(t_noco),    INTENT(IN)    :: noco
   TYPE(t_nococonv),INTENT(INOUT) :: nococonv
   TYPE(t_stars),   INTENT(IN)    :: stars
   TYPE(t_vacuum),  INTENT(IN)    :: vacuum
   TYPE(t_sphhar),  INTENT(IN)    :: sphhar
   TYPE(t_sym),     INTENT(IN)    :: sym
    
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
   CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco ,cell,-nococonv%alphRlx,zeros,den)
   CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco ,cell,zeros,-diffT-nococonv%betaPrev,den)
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
        ,sym ,cell,noco,nococonv,input,atoms,den)
   TYPE(t_input),   INTENT(IN)    :: input
   TYPE(t_atoms),   INTENT(IN)    :: atoms
   TYPE(t_noco),    INTENT(IN)    :: noco
   TYPE(t_nococonv),INTENT(INOUT) :: nococonv
   TYPE(t_stars),   INTENT(IN)    :: stars
   TYPE(t_vacuum),  INTENT(IN)    :: vacuum
   TYPE(t_sphhar),  INTENT(IN)    :: sphhar
   TYPE(t_sym),     INTENT(IN)    :: sym
    
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
   CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco ,cell,-diffP-nococonv%alphPrev,zeros,den)
   CALL flipcdn(atoms,input,vacuum,sphhar,stars,sym,noco ,cell,zeros,-diffT-nococonv%betaPrev,den)
   nococonv%beta=nococonv%betaPrev+diffT
   nococonv%betaPrev=nococonv%beta
   nococonv%alph=nococonv%alphPrev+diffP
   nococonv%alphPrev=nococonv%alph
   CALL cureTooSmallAngles(atoms,nococonv%beta,nococonv%alph)

END SUBROUTINE bothRelax
#endif
