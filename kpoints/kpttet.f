      MODULE m_kpttet
      use m_juDFT
      CONTAINS
      SUBROUTINE kpttet(
     >                  nkpt,ndiv3,
     >                  rltv,voluni,
     >                  nsym,ccr,mdir,mface,
     >                  ncorn,nface,fdist,fnorm,cpoint,
     <                  voltet,ntetra,ntet,
     <                  vkxyz,wghtkp)
c
c
c ---> This program generates k-points
c           in irreducible wedge of BZ  
c      (BZ = 1. Brillouin-zone) for all canonical Bravais lattices
c      in 3 dimensions,
c      using the basis vectors of the reciprocal lattice,
c      the corner points of the irreducible wedge of the BZ
c      and the bordering planes of the irreducible wedge.
c
c      The k-points are generated by the tetrahedron method.
c      by generating a set of k-points which are maximally far apart
c      for the rquired number of points.
c      The method and the subroutines were obtained via St.Bluegel.
c      The information about the irr wedge of the BZ
c      is taken from BRZONE.
c
c-----------------------------------------------------------------------
c    Meaning of variables:
c    INPUT:
c
c    Symmetry of lattice:
c    rltv     : cartesian coordinates of basis vectors for
c               reciprocal lattice: rltv(ix,jn), ix=1,3; jn=1,3
c    voluni   : volume of the Bravais lattice unit cell
c    nsym     : number of symmetry elements of points group
c    ccr     : rotation matrix for symmetry element
c                   in cartesian representation
c
c    representation of the irreducible part of the BZ:
c    fnorm    : normal vector of the planes bordering the irrBZ
c    fdist    : distance vector of the planes bordering the irrBZ
c    ncorn    : number of corners of the irrBZ
c    nface    : number of faces of the irrBZ
c    cpoint   : cartesian coordinates of corner points of irrBZ
c
c    characterization of the tetrahedron-method k-point set:
c    nkpt     : on input: required number of k-points inside irrBZ
c               to build the tetrahedrons
c    ntet     : number of tetrahedra generated
c    ntetra   : list of four points for each tetrahedron
c               containing the indices of the respective corner points
c    vktet    : corner points of tetrahedra
c
c    OUTPUT: k-point set
c    nkpt     : number of k-points generated in set
c    vkxyz    : vector of kpoint generated; in cartesian representation
c    wghtkp   : weight associated with k-points for BZ integration
c
c-----------------------------------------------------------------------
      USE m_constants
      USE m_tetcon
      USE m_kvecon
      USE m_fulstar
      IMPLICIT NONE
C
C-----> PARAMETER STATEMENTS
C
      INTEGER, INTENT (IN) :: ndiv3,mface,mdir
c
c
c ---> running mode parameter
C
C----->  Symmetry information
C
      INTEGER, INTENT (IN) :: nsym
      REAL,    INTENT (IN) :: ccr(3,3,48)
C
C----->  BRAVAIS LATTICE INFORMATION
C
      REAL,    INTENT (IN) ::  voluni
C
C----->  RECIPROCAL LATTICE INFORMATION
C
      INTEGER, INTENT (IN) :: ncorn,nface
      REAL,    INTENT (IN) :: rltv(3,3),fnorm(3,mface),fdist(mface)
      REAL,    INTENT (IN) :: cpoint(3,mface)
C
C----->  BRILLOUINE ZONE INTEGRATION
C
      INTEGER, INTENT (IN) :: nkpt
      INTEGER, INTENT (OUT) :: ntetra(4,ndiv3),ntet
      REAL,    INTENT (OUT) :: voltet(ndiv3)
      REAL,    INTENT (OUT) :: vkxyz(3,nkpt),wghtkp(nkpt)

C
C --->  local variables
c
      INTEGER   i,j,ii
      REAL      eps,one,tpi,sumvol,volirbz

      REAL :: vktet(3,nkpt)

C
C --->  set local constants
c
      SAVE      eps,one
      DATA      eps/1.0e-9/,one/1.0/
c
c======================================================================
c
      tpi = 2.0 * pimach()
c

      WRITE (oUnit,'('' k-points generated with tetrahedron '',
     >                                              ''method'')')
      WRITE (oUnit,'(''# k-points generated with tetrahedron '',
     >                                              ''method'')')
      WRITE (oUnit,'(3x,'' in irred wedge of 1. Brillouin zone'')')
      WRITE (oUnit,'(3x,'' ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'')')

      CALL kvecon(
     >            nkpt,mface,
     >            ncorn,nsym,nface,rltv,fdist,fnorm,cpoint,
     <            vktet )
!
! --->  generate tetrahedra and mid-tetrahedron k-points
!
! --->  (a) Determine the corner K-POINTs for X number of Tetrahedra for
!           doing a very pretty Brillouine zone Integration;
! --->      determine the volume of each tetrahedron

      DO i = 1, nkpt
         wghtkp(i) = 1.0 / nkpt
         vkxyz(:,i) = vktet(:,i)
         WRITE (oUnit,'(3(f10.7,1x),f12.10,1x,i4,3x,
     +          ''vkxyz, wghtkp'')') (vkxyz(ii,i),ii=1,3),wghtkp(i),i
      END DO

      CALL tetcon(
     >            nkpt,ndiv3,voluni,vktet,nsym,
     <            ntet,voltet,ntetra)

      WRITE (oUnit,'('' the number of tetrahedra '')')
      WRITE (oUnit,*) ntet
      WRITE (oUnit,'('' volumes of the tetrahedra '')')
      WRITE (oUnit,'(e19.12,1x,i5,5x,''voltet(i),i'')')
     >                               (voltet(i),i,i=1,ntet)
      WRITE (oUnit,'('' corners of the tetrahedra '')')
      WRITE (oUnit, '(4(3x,4i4))') ((ntetra(j,i),j=1,4),i=1,ntet)
      WRITE (oUnit,'('' the # of different k-points '')')
      WRITE (oUnit,*) nkpt
      WRITE (oUnit,'('' k-points used to construct tetrahedra'')')
      WRITE (oUnit,'(3(4x,f10.6))') ((vktet(i,j),i=1,3),j=1,nkpt)
c
c --->   calculate weights from volume of tetrahedra
c
      volirbz =  tpi**3 /(real(nsym)*voluni)
      sumvol = 0.0
      DO i = 1, ntet
         sumvol = sumvol + voltet(i)
         voltet(i) = ntet * voltet(i) / volirbz 
      ENDDO

      IF ((sumvol-volirbz)/volirbz.GT. eps) THEN
         WRITE (oUnit, '(2(e19.12,1x),5x,''summvol.ne.volirbz'')')
     >                                     sumvol,volirbz
         CALL juDFT_error("sumvol =/= volirbz",calledby="kpttet")
      ENDIF

      RETURN
      END SUBROUTINE kpttet
      END MODULE m_kpttet

