!--------------------------------------------------------------------------------
! Copyright (c) 2016 Peter Grünberg Institut, Forschungszentrum Jülich, Germany
! This file is part of FLEUR and available as free software under the conditions
! of the MIT license as expressed in the LICENSE file in more detail.
!--------------------------------------------------------------------------------
module m_distance
contains
  SUBROUTINE distance(irank,vol,jspins,fsm,inden,outden,results,fsm_mag)
    use m_types
    use m_types_mixvector
    USE m_constants
    use m_xmlOutput

    implicit none
    integer,intent(in)             :: irank,jspins
    real,intent(in)                :: vol
    type(t_mixvector),INTENT(IN)   :: fsm
    TYPE(t_potden),INTENT(INOUT)   :: inden,outden
    TYPE(t_results),INTENT(INOUT)  :: results
    type(t_mixvector),INTENT(OUT)  :: fsm_mag

    integer         ::js
    REAL            :: dist(6) !1:up,2:down,3:spinoff,4:total,5:magnet,6:noco
    TYPE(t_mixvector)::fmMet
    character(len=100)::attributes(2)

    CALL fmMet%alloc()
    IF (jspins==2) THEN
       CALL fsm_mag%alloc()
       ! calculate Magnetisation-difference
       CALL fsm_mag%from_density(outden,swapspin=.TRUE.)
       call fmMet%from_density(inden,swapspin=.true.)
       fsm_mag=fsm_mag-fmMet
    ENDIF
    ! Apply metric w to fsm and store in fmMet:  w |fsm>
    fmMet=fsm%apply_metric(.FALSE.)

    dist(:) = 0.0
    DO js = 1,jspins
       dist(js) = fsm%multiply_dot_mask(fmMet,(/.true.,.true.,.true.,.false./),js)
    END DO
    IF (SIZE(outden%pw,2)>2) dist(6) = fsm%multiply_dot_mask(fmMet,(/.TRUE.,.TRUE.,.TRUE.,.FALSE./),3)
    IF (jspins.EQ.2) THEN
       dist(3) = fmMet%multiply_dot_mask(fsm_mag,(/.true.,.true.,.true.,.false./),1)
       dist(4) = dist(1) + dist(2) + 2.0e0*dist(3)
       dist(5) = dist(1) + dist(2) - 2.0e0*dist(3)
    ENDIF

    results%last_distance=maxval(1000*SQRT(ABS(dist/vol)))
    if (irank>0) return
    !calculate the distance of charge densities for each spin
    CALL openXMLElement('densityConvergence',(/'units'/),(/'me/bohr^3'/))

    DO js = 1,jspins
       attributes = ''
       WRITE(attributes(1),'(i0)') js
       WRITE(attributes(2),'(f20.10)') 1000*SQRT(ABS(dist(js)/vol))
       CALL writeXMLElementForm('chargeDensity',(/'spin    ','distance'/),attributes,reshape((/4,8,1,20/),(/2,2/)))
       WRITE (oUnit,FMT=7900) js,inDen%iter,1000*SQRT(ABS(dist(js)/vol))
    END DO

    IF (SIZE(outden%pw,2)>2) WRITE (oUnit,FMT=7900) 3,inDen%iter,1000*SQRT(ABS(dist(6)/vol))

    !calculate the distance of total charge and spin density
    !|rho/m(o) - rho/m(i)| = |rh1(o) -rh1(i)|+ |rh2(o) -rh2(i)| +/_
    !                        +/_2<rh2(o) -rh2(i)|rh1(o) -rh1(i)>
    IF (jspins.EQ.2) THEN
       CALL writeXMLElementFormPoly('overallChargeDensity',(/'distance'/),&
            (/1000*SQRT(ABS(dist(4)/vol))/),reshape((/10,20/),(/1,2/)))
       CALL writeXMLElementFormPoly('spinDensity',(/'distance'/),&
            (/1000*SQRT(ABS(dist(5)/vol))/),reshape((/19,20/),(/1,2/)))
       WRITE (oUnit,FMT=8000) inDen%iter,1000*SQRT(ABS(dist(4)/vol))
       WRITE (oUnit,FMT=8010) inDen%iter,1000*SQRT(ABS(dist(5)/vol))

       !dist/vol should always be >= 0 ,
       !but for dist=0 numerically you might obtain dist/vol < 0
       !(e.g. when calculating non-magnetic systems with jspins=2).
    END IF
    CALL closeXMLElement('densityConvergence')


7900  FORMAT (/,'---->    distance of charge densities for spin ',i2,'                 it=',i5,':',f13.6,' me/bohr**3')
8000 FORMAT (/,'---->    distance of charge densities for it=',i5,':', f13.6,' me/bohr**3')
8010 FORMAT (/,'---->    distance of spin densities for it=',i5,':', f13.6,' me/bohr**3')
8020 FORMAT (4d25.14)
8030  FORMAT (10i10)
  end SUBROUTINE distance

   SUBROUTINE dfpt_distance(irank,vol,jspins,fsm,inden,outden,indenIm,outdenIm,results,fsm_mag)
      USE m_types
      USE m_types_mixvector
      USE m_constants
      USE m_xmlOutput

      IMPLICIT NONE

      INTEGER, INTENT(IN) :: irank,jspins
      REAL,    INTENT(IN) :: vol

      TYPE(t_mixvector), INTENT(IN)    :: fsm
      TYPE(t_potden),    INTENT(INOUT) :: inden,outden,indenIm,outdenIm
      TYPE(t_results),   INTENT(INOUT) :: results
      TYPE(t_mixvector), INTENT(OUT)   :: fsm_mag

      INTEGER :: js
      REAL    :: dist(7,2)

      TYPE(t_mixvector) :: fmMet

      CALL fmMet%alloc()
      IF (jspins==2) THEN
         CALL fsm_mag%alloc()
         ! calculate Magnetisation-difference
         CALL fsm_mag%from_density(outden,swapspin=.TRUE.,denIm=outDenIm)
         CALL fmMet%from_density(inden,swapspin=.TRUE.,denIm=inDenIm)
         fsm_mag=fsm_mag-fmMet
      END IF

      ! Apply metric w to fsm and store in fmMet:  w |fsm>
      fmMet=fsm%apply_metric(.TRUE.)

      dist(:,:) = 0.0
      DO js = 1,jspins
         CALL fsm%dfpt_multiply_dot_mask(fmMet,(/.TRUE.,.TRUE./),js,dist(js,:))
      END DO
      IF (SIZE(outden%pw,2)>2) THEN
         CALL fsm%dfpt_multiply_dot_mask(fmMet,(/.TRUE.,.TRUE./),3,dist(6,:),dist(7,:))
      END IF
      IF (jspins.EQ.2) THEN
         CALL fmMet%dfpt_multiply_dot_mask(fsm_mag,(/.TRUE.,.TRUE./),1,dist(3,:))
         dist(4,:) = dist(1,:) + dist(2,:) + 2.0e0*dist(3,:)
         dist(5,:) = dist(1,:) + dist(2,:) - 2.0e0*dist(3,:)
      END IF

      results%last_distance=maxval(1000*SQRT(ABS(dist/vol)))
      if (irank>0) return
      !calculate the distance of charge densities for each spin

      DO js = 1,jspins
         WRITE (oUnit,FMT=7900) js,inDen%iter,1000*SQRT(ABS(dist(js,1)/vol))
         WRITE (oUnit,FMT=7901) js,inDen%iter,1000*SQRT(ABS(dist(js,2)/vol))
      END DO

      IF (SIZE(outden%pw,2)>2) THEN
         WRITE (oUnit,FMT=7900) 3,inDen%iter,1000*SQRT(ABS(dist(6,1)/vol))
         WRITE (oUnit,FMT=7901) 3,inDen%iter,1000*SQRT(ABS(dist(6,2)/vol))
         WRITE (oUnit,FMT=7900) 4,inDen%iter,1000*SQRT(ABS(dist(7,1)/vol))
         WRITE (oUnit,FMT=7901) 4,inDen%iter,1000*SQRT(ABS(dist(7,2)/vol))
      END IF

      IF (jspins.EQ.2) THEN
         WRITE (oUnit,FMT=8000) inDen%iter,1000*SQRT(ABS(dist(4,1)/vol))
         WRITE (oUnit,FMT=8001) inDen%iter,1000*SQRT(ABS(dist(4,2)/vol))
         WRITE (oUnit,FMT=8010) inDen%iter,1000*SQRT(ABS(dist(5,1)/vol))
         WRITE (oUnit,FMT=8011) inDen%iter,1000*SQRT(ABS(dist(5,2)/vol))
      END IF

7900  FORMAT (/,'---->    distance of charge density perturbation real part for spin ',i2,'                 it=',i5,':',f13.6,' me/bohr**3')
7901  FORMAT (/,'---->    distance of charge density perturbation imag part for spin ',i2,'                 it=',i5,':',f13.6,' me/bohr**3')
8000  FORMAT (/,'---->    distance of charge density perturbation real part for it=',i5,':', f13.6,' me/bohr**3')
8001  FORMAT (/,'---->    distance of charge density perturbation imag part for it=',i5,':', f13.6,' me/bohr**3')
8010  FORMAT (/,'---->    distance of spin density perturbation real part for it=',i5,':', f13.6,' me/bohr**3')
8011  FORMAT (/,'---->    distance of spin density perturbation imag part for it=',i5,':', f13.6,' me/bohr**3')
   END SUBROUTINE dfpt_distance
end module m_distance
