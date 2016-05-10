      MODULE m_setab
      use m_juDFT
!*********************************************************************
!     set up lattice quantities and matrices 
!*********************************************************************
      CONTAINS
      SUBROUTINE setab(
     >                 a1,a2,a3,aa,scale,noangles,
     <                 amat,bmat,aamat,bbmat,amatinv,omtil)

      USE m_constants

      IMPLICIT NONE

!==>  Arguments
      REAL, INTENT (IN)  :: aa
      REAL, INTENT (IN)  :: a1(3),a2(3),a3(3),scale(3)
      LOGICAL, INTENT (IN)  :: noangles
      REAL, INTENT (OUT) :: amat(3,3),bmat(3,3),amatinv(3,3)
      REAL, INTENT (OUT) :: aamat(3,3),bbmat(3,3)
      REAL, INTENT (OUT) :: omtil

!==>  Locals
      INTEGER i, j
      REAL    volume
      LOGICAL lerr
      REAL    tmat(3,3),b1(3),b2(3),b3(3)

!  volume in scaled Cartesian units
      volume  = a1(1)*a2(2)*a3(3) + a2(1)*a3(2)*a1(3) +
     &          a3(1)*a1(2)*a2(3) - a1(3)*a2(2)*a3(1) -
     &          a2(3)*a3(2)*a1(1) - a3(3)*a1(2)*a2(1)

!  reciprocal lattice vectors in scaled Cartesian units
      b1(1) = (a2(2)*a3(3) - a2(3)*a3(2))/volume
      b1(2) = (a2(3)*a3(1) - a2(1)*a3(3))/volume
      b1(3) = (a2(1)*a3(2) - a2(2)*a3(1))/volume
      b2(1) = (a3(2)*a1(3) - a3(3)*a1(2))/volume
      b2(2) = (a3(3)*a1(1) - a3(1)*a1(3))/volume
      b2(3) = (a3(1)*a1(2) - a3(2)*a1(1))/volume
      b3(1) = (a1(2)*a2(3) - a1(3)*a2(2))/volume
      b3(2) = (a1(3)*a2(1) - a1(1)*a2(3))/volume
      b3(3) = (a1(1)*a2(2) - a1(2)*a2(1))/volume

!  volume and area (assuming a1 and a2 define surface periodicity)
      omtil = (aa**3)*scale(1)*scale(2)*scale(3)*volume

!  matrices of lattice vectors in full Cartesian units

      IF (noangles) THEN  ! we scale the coordinate system in the case of cP, cI, cF, tI etc.

      DO i=1,3
         amat(i,1) = aa*scale(i)*a1(i)
         amat(i,2) = aa*scale(i)*a2(i)
         amat(i,3) = aa*scale(i)*a3(i)
      ENDDO

      DO i=1,3
         bmat(1,i) = (pi_const/(aa*scale(i))) * b1(i)
         bmat(2,i) = (pi_const/(aa*scale(i))) * b2(i)
         bmat(3,i) = (pi_const/(aa*scale(i))) * b3(i)
      ENDDO

      DO i=1,3
         amatinv(1,i) = (1.0/(aa*scale(i))) * b1(i)
         amatinv(2,i) = (1.0/(aa*scale(i))) * b2(i)
         amatinv(3,i) = (1.0/(aa*scale(i))) * b3(i)
      ENDDO

      ELSE ! we scale the lattice vectors in the case of mP, mA, mB, aP


      DO i=1,3
         amat(i,1) = aa*scale(1)*a1(i)
         amat(i,2) = aa*scale(2)*a2(i)
         amat(i,3) = aa*scale(3)*a3(i)
      ENDDO

      DO i=1,3
         bmat(1,i) = (pi_const/(aa*scale(1))) * b1(i)
         bmat(2,i) = (pi_const/(aa*scale(2))) * b2(i)
         bmat(3,i) = (pi_const/(aa*scale(3))) * b3(i)
      ENDDO

      DO i=1,3
         amatinv(1,i) = (1.0/(aa*scale(1))) * b1(i)
         amatinv(2,i) = (1.0/(aa*scale(2))) * b2(i)
         amatinv(3,i) = (1.0/(aa*scale(3))) * b3(i)
      ENDDO

      ENDIF

!--->  check that amat and amatinv consistent 
!      (amat*amatinv should be identity)

      tmat = matmul( amat, amatinv )
      lerr = .false.
      DO j=1,3
         if( abs( tmat(j,j) - 1.000 ) .gt. 1.e-10 ) lerr = .true.
         DO i=1,3
            if(i.eq.j) cycle
            if( abs( tmat(i,j) ) .gt. 1.e-10 ) lerr = .true.
         ENDDO
      ENDDO
      IF (lerr) THEN
         WRITE(6,'(" error in set-up of amat and amatinv matrices")')
         WRITE(6,'(" (",3f12.8," )")') tmat(1,1),tmat(1,2),tmat(1,3)
         WRITE(6,'(" (",3f12.8," )")') tmat(2,1),tmat(2,2),tmat(2,3)
         WRITE(6,'(" (",3f12.8," )")') tmat(3,1),tmat(3,2),tmat(3,3)
         CALL juDFT_error("ERROR in amat,amatinv matrices",calledby
     +        ="setab")
      ENDIF

      aamat=matmul(transpose(amat),amat)
      bbmat=matmul(transpose(bmat),bmat)

      END SUBROUTINE setab
      END MODULE m_setab
