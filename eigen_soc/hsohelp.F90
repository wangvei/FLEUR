!--------------------------------------------------------------------------------
! Copyright (c) 2016 Peter Grünberg Institut, Forschungszentrum Jülich, Germany
! This file is part of FLEUR and available as free software under the conditions
! of the MIT license as expressed in the LICENSE file in more detail.
!--------------------------------------------------------------------------------

MODULE m_hsohelp
  !
  !*********************************************************************
  ! preparation of spin-orbit matrix elements: ahelp, bhelp
  ! ahelp(i,n,l,m,jspin) =Sum_(G) (conj(c(G,i,jspin)*a(G,n,l,m,jspin))
  ! bhelp - same a|->b
  ! Original version replaced by a call to abcof. Maybe not so efficient
  ! but includes now LO's and could also be used for noco
  !                                                        gb`02
  !*********************************************************************
  !
CONTAINS
  SUBROUTINE hsohelp(atoms,sym,input,lapw,nsz, cell,&
       zmat,usdus, zso,noco ,&
       nat_start,nat_stop,nat_l,ahelp,bhelp,chelp)
    !
    USE m_abcof_soc
    USE m_types
#ifdef CPP_MPI
    use mpi 
#endif
    IMPLICIT NONE
#ifdef CPP_MPI
    INTEGER ierr(3)
#endif
    
     
    TYPE(t_input),INTENT(IN)       :: input
    TYPE(t_noco),INTENT(IN)        :: noco
    TYPE(t_sym),INTENT(IN)         :: sym
    TYPE(t_cell),INTENT(IN)        :: cell
    TYPE(t_atoms),INTENT(IN)       :: atoms
    TYPE(t_usdus),INTENT(IN)       :: usdus
    TYPE(t_lapw),INTENT(IN)        :: lapw
    !     ..
    !     .. Scalar Arguments ..
    !     ..
    INTEGER, INTENT (IN) :: nat_start,nat_stop,nat_l
    !     .. Array Arguments ..
    INTEGER, INTENT (IN) :: nsz(input%jspins)  
    COMPLEX, INTENT (INOUT) :: zso(:,:,:)!lapw%dim_nbasfcn(),2*input%neig,input%jspins)
    COMPLEX, INTENT (OUT):: ahelp(atoms%lmaxd*(atoms%lmaxd+2),nat_l,input%neig,input%jspins)
    COMPLEX, INTENT (OUT):: bhelp(atoms%lmaxd*(atoms%lmaxd+2),nat_l,input%neig,input%jspins)
    COMPLEX, INTENT (OUT):: chelp(-atoms%llod :atoms%llod, input%neig,atoms%nlod,nat_l,input%jspins)
    TYPE(t_mat),INTENT(IN)      :: zmat(:) ! (lapw%dim_nbasfcn(),input%neig,input%jspins)
    !-odim
    !+odim
    !     ..
    !     .. Locals ..
    TYPE(t_mat)     :: zMat_local
    INTEGER ispin ,l,n ,na,ie,lm,ll1,nv1(input%jspins),m,lmd
    INTEGER, ALLOCATABLE :: g1(:,:),g2(:,:),g3(:,:)
    COMPLEX, ALLOCATABLE :: acof(:,:,:),bcof(:,:,:)
    !
    ! turn off the non-collinear part of abcof
    !
    lmd = atoms%lmaxd*(atoms%lmaxd+2)
    !
    ! some praparations to match array sizes
    !
    nv1(1) = lapw%nv(1) ; nv1(input%jspins) = lapw%nv(1)
    ALLOCATE (g1(lapw%dim_nvd(),input%jspins))
    ALLOCATE (g2(lapw%dim_nvd(),input%jspins))
    ALLOCATE (g3(lapw%dim_nvd(),input%jspins))
    g1 = 0 ; g2 = 0 ; g3 = 0
    g1(:SIZE(lapw%k1,1),1) = lapw%k1(:SIZE(lapw%k1,1),1) ; g1(:SIZE(lapw%k1,1),input%jspins) = lapw%k1(:SIZE(lapw%k1,1),1)
    g2(:SIZE(lapw%k1,1),1) = lapw%k2(:SIZE(lapw%k1,1),1) ; g2(:SIZE(lapw%k1,1),input%jspins) = lapw%k2(:SIZE(lapw%k1,1),1)
    g3(:SIZE(lapw%k1,1),1) = lapw%k3(:SIZE(lapw%k1,1),1) ; g3(:SIZE(lapw%k1,1),input%jspins) = lapw%k3(:SIZE(lapw%k1,1),1)

    chelp(:,:,:,:,input%jspins) = CMPLX(0.0,0.0)

    ALLOCATE ( acof(input%neig,0:lmd,nat_l),bcof(input%neig,0:lmd,nat_l) )
    DO ispin = 1, input%jspins
       IF (zmat(1)%l_real.AND.noco%l_soc) THEN
          zso(:,1:input%neig,ispin) = CMPLX(zmat(ispin)%data_r(:,1:input%neig),0.0)
          zMat_local%l_real = .FALSE.
          zMat_local%matsize1 = zmat(1)%matsize1
          zMat_local%matsize2 = input%neig
          ALLOCATE(zMat_local%data_c(zmat(1)%matsize1,input%neig))
          zMat_local%data_c(:,:) = zso(:,1:input%neig,ispin)
          CALL abcof_soc(input,atoms,sym,cell,lapw,nsz(ispin),&
               usdus, noco,ispin ,nat_start,nat_stop,nat_l,&
               acof,bcof,chelp(-atoms%llod:,:,:,:,ispin),zMat_local)
          DEALLOCATE(zMat_local%data_c)
          !
          !
          ! transfer (a,b)cofs to (a,b)helps used in hsoham
          !
          DO ie = 1, input%neig
             DO na = 1, nat_l
                DO l = 1, atoms%lmaxd
                   ll1 = l*(l+1)
                   DO m = -l,l
                      lm = ll1 + m
                      ahelp(lm,na,ie,ispin) = (acof(ie,lm,na))
                      bhelp(lm,na,ie,ispin) = (bcof(ie,lm,na))
                   ENDDO
                ENDDO
             ENDDO
          ENDDO
       ELSE
          zMat_local%l_real = zmat(1)%l_real
          zMat_local%matsize1 = zmat(1)%matsize1
          zMat_local%matsize2 = input%neig
          ALLOCATE(zMat_local%data_c(zmat(1)%matsize1,input%neig))
          zMat_local%data_c(:,:) = zmat(ispin)%data_c(:,:)
          CALL abcof_soc(input,atoms,sym,cell,lapw,nsz(ispin),&
               usdus,noco,ispin ,nat_start,nat_stop,nat_l,&
               acof,bcof,chelp(-atoms%llod:,:,:,:,ispin),zMat_local)
          DEALLOCATE(zMat_local%data_c)
          !
          ! transfer (a,b)cofs to (a,b)helps used in hsoham
          !
          DO ie = 1, input%neig
             DO na = 1, nat_l
                DO l = 1, atoms%lmaxd
                   ll1 = l*(l+1)
                   DO m = -l,l
                      lm = ll1 + m
                      ahelp(lm,na,ie,ispin) = (acof(ie,lm,na))
                      bhelp(lm,na,ie,ispin) = (bcof(ie,lm,na))
                   ENDDO
                ENDDO
             ENDDO
          ENDDO
       ENDIF
       !      write(54,'(6f15.8)')(((chelp(m,ie,1,na,1),m=-1,1),ie=1,5),na=1,2)
       !      write(54,'(8f15.8)')(((acof(ie,l,na),l=0,3),ie=1,5),na=1,2)
    ENDDO    ! end of spin loop (ispin)
    !
    DEALLOCATE ( acof,bcof,g1,g2,g3 )
    RETURN
  END SUBROUTINE hsohelp
END MODULE m_hsohelp
