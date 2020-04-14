      MODULE m_kptmop
      use m_juDFT
!-----------------------------------------------------------------------
!     ---> This program generates k-points
!     in irreducible wedge of BZ
!     (BZ = 1. Brillouin-zone) for all canonical Bravais lattices
!     in 2 and 3 dimensions,
!     using the basis vectors of the reciprocal lattice
!     and the bordering planes of the irreducible wedge.
!
!     The k-points are generated by the Monkhorst--Pack method.
!     The information on the bordering planes of the irr wedge
!     is taken from BRZONE.
!
!     The program checks the compatibility of the dimension and
!     symmetry and of the provided Monkhorst-Pack-parameters.
!-----------------------------------------------------------------------
      CONTAINS
      SUBROUTINE kptmop(
     >     idsyst,idtype,nmop,
     >     rltv,bltv,nbound,idimens,
     >     xvec,fnorm,fdist,ncorn,nface,nedge,cpoint,
     >     nsym,ccr,rlsymr,talfa,mkpt,mface,mdir,
     <     nkpt,vkxyz,wghtkp)
c
c     Meaning of variables:
c     INPUT:
c
c     Symmetry of lattice:
c     idsyst   : crystal system identification in MDDFT programs
c     idtype   : lattice type identification in MDDFT programs
c     bltv     : cartesian coordinates of basis vectors for
c     Bravais lattice: bltv(ix,jn), ix=1,3; jn=1,3
c     rltv     : cartesian coordinates of basis vectors for
c     reciprocal lattice: rltv(ix,jn), ix=1,3; jn=1,3
c     nsym     : number of symmetry elements of points group
c     ccr     : rotation matrix for symmetry element
c     in cartesian representation
c     rlsymr   : rotation matrix for symmetry element
c     in reciprocal lattice basis representation
c     talfa    : translation vector associated with (non-symmorphic)
c     symmetry elements in Bravais lattice representation
c
c     representation of the irreducible part of the BZ:
c     fnorm    : normal vector of the planes bordering the irrBZ
c     fdist    : distance vector of the planes bordering the irrBZ
c     ncorn    : number of corners of the irrBZ
c     nface    : number of faces of the irrBZ
c     nedge    : number of edges of the irrBZ
c     xvec     : arbitrary vector lying in the irrBZ (FOR SURE!!)
c     components are:
c
c     characterization of the Monkhorst-Pack k-point set:
c     idimens  : number of dimensions for k-point set (2 or 3)
c     nbound   : 0 no primary points on BZ boundary;
c     1 with boundary points (not for BZ integration!!!)
c     nmop     : integer number triple: nmop(i), i=1,3; nmop(i)
c     determines number of k-points in direction of rltv(ix,i)
c
c     OUTPUT: k-point set
c     nkpt     : number of k-points generated in set
c     vkxyz    : vector of kpoint generated; in cartesian representation
c     wghtkp   : weight associated with k-points for BZ integration
c     divis    : integer triple divis(i); i=1,4.
c     Used to find more accurate representation of k-points
c     vklmn(i,kpt)/divis(i) and weights as wght(kpt)/divis(4)
c     nkstar   : number of stars for k-points generated in full stars
c
c-----------------------------------------------------------------------
      USE m_constants
      USE m_ordstar
      USE m_fulstar
      IMPLICIT NONE
C
C-----> PARAMETER STATEMENTS
C
      INTEGER, INTENT (IN) :: mkpt,mface,mdir
c
C----->  Symmetry information
C
      INTEGER, INTENT (IN) :: nsym,idsyst,idtype
      REAL,    INTENT (IN) :: ccr(3,3,48)
      REAL,    INTENT (IN) :: rlsymr(3,3,48),talfa(3,48)
C
C----->  BRAVAIS LATTICE INFORMATION
C
      REAL,    INTENT (IN) :: bltv(3,3),cpoint(3,mface)
C
C----->  RECIPROCAL LATTICE INFORMATION
C
      INTEGER, INTENT (IN) :: ncorn,nface,nedge
      REAL,    INTENT (IN) :: xvec(3),rltv(3,3)
      REAL,    INTENT (IN) :: fnorm(3,mface),fdist(mface)
C
C----->  BRILLOUINE ZONE INTEGRATION
C
      INTEGER, INTENT (IN) :: nbound,idimens
      INTEGER, INTENT (INOUT) :: nmop(3)
      INTEGER, INTENT (OUT):: nkpt
      REAL,    INTENT (OUT):: vkxyz(3,mkpt),wghtkp(mkpt)
C
C     --->  local variables
c
      CHARACTER*80 blank
      INTEGER  nkstar,divis(4)
      INTEGER  i,idim,i1,i2,i3,ii,ij,ik,is,isym,ifac, iik,iiik
      INTEGER  ikc, i1red,nred,isumkpt,nleft,nirrbz
      INTEGER  dirmin,dirmax,ndir1,ndir2,idir
      INTEGER  kpl,kpm,kpn,nstar(mdir),nstnew
      INTEGER  iplus,iminus,nc2d,n
      REAL     invtpi,zero,one,half,eps,eps1,orient,sum,denom,aivnkpt

      INTEGER  nfract(3),lim(3),isi(3)
      REAL     cp2d(3,mface)
      REAL     vktra(3),vkstar(3,48),ainvnmop(3),fsig(2),vktes(3)
      INTEGER, ALLOCATABLE :: ikpn(:,:),irrkpn(:),nkrep(:)
      INTEGER, ALLOCATABLE :: iside(:),iostar(:)
      REAL,    ALLOCATABLE :: fract(:,:), vkrep(:,:)
C
C     --->  intrinsic functions
c
      INTRINSIC   real,abs
C
C     --->  save and data statements
c
      SAVE     one,zero,half,eps,eps1,iplus,iminus
      DATA     zero/0.00/,one/1.00/,half/0.50/,
     +     eps/1.0e-8/,eps1/1.0e-6/,iplus/1/,iminus/-1/
c
c-----------------------------------------------------------------------
c
      ALLOCATE (fract(mkpt,3),vkrep(3,mkpt),ikpn(48,mkpt),irrkpn(mkpt))
      ALLOCATE (nkrep(mkpt),iostar(mkpt),iside(mface))

!
!     --->   for 2 dimensions only the following Bravais lattices exist:
!     TYPE                    EQUIVALENT 3-DIM        idsyst/idtype
!     square               = p-tetragonal ( 1+2 axis )      2/1
!     rectangular          = p-orthorhomb ( 1+2 axis )      3/1
!     centered rectangular = c-face-orthorhomb( 1+2 axis)   3/6
!     hexagonal            = p-hexagonal  ( 1+2 axis )      4/1
!     oblique              = p-monoclinic ( 1+2 axis )      6/1
!
      IF (idimens .EQ. 2) THEN
!
!     --->   identify the allowed symmetries
!     and check the consistency of the Monkhorst-Pack-parameters
!
         IF (idsyst.EQ.2 .OR. idsyst.EQ.4) THEN
            IF (idtype.EQ.1) THEN
               If (Nmop(1)==1) Nmop(1)=0
               IF (nmop(1).NE.nmop(2) .OR. nmop(3).NE.0) THEN
                  nmop(2) = nmop(1)
                  nmop(3) = 0
                  WRITE (oUnit,'(1x,''WARNING!!!!!!!'',/,
     +''nmop-Parameters not in accordance with symmetry'',/,
     +2(1x,i4),/,
     +'' we have set nmop(2) = nmop(1)'',/,
     +'' and/or nmop(3) = 0'')') idsyst, idtype
                  WRITE (oUnit,'(3(1x,i4),'' new val for nmop: '')')
     +                 (nmop(i),i=1,3)
               ELSE
                  WRITE (oUnit,'('' values accepted unchanged'')')
                  WRITE (oUnit,'(3(1x,i4),14x,''nmop(i),i=1,3'')')
     +                 (nmop(i),i=1,3)
               ENDIF
            ENDIF
         ELSEIF (idsyst.EQ.3) THEN
            IF (idtype.EQ.1 .OR. idtype.EQ.6) THEN
              If (Nmop(3)==1) Nmop(3)=0
              IF (nmop(3).NE.0) THEN
                  nmop(3) = 0
                  WRITE (oUnit,'(1x,''WARNING!!!!!!!'',/,
     +''nmop-Parameters not in accordance with symmetry'',/,
     +2(1x,i4),/,
     +'' we have set nmop(3) = 0'')') idsyst, idtype
                  WRITE (oUnit,'(3(1x,i4),'' new val for nmop: '')')
     +                 (nmop(i),i=1,3)
               ELSE
                  WRITE (oUnit,'('' values accepted unchanged'')')
                  WRITE (oUnit,'(3(1x,i4),14x,''nmop(i),i=1,3'')')
     +                 (nmop(i),i=1,3)
               ENDIF
            ENDIF
         ELSEIF (idsyst.EQ.6) THEN
            IF (idtype.EQ.1) THEN
               If (Nmop(3)==1) Nmop(3)=0
               IF (nmop(3).NE.0) THEN
                  nmop(3) = 0
                  WRITE (oUnit,'(1x,''WARNING!!!!!!!'',/,
     +''nmop-Parameters not in accordance with symmetry'',/,
     +2(1x,i4),/,
     +'' we have set nmop(3) = 0'')') idsyst, idtype
                  WRITE (oUnit,'(3(1x,i4),'' new val for nmop: '')')
     +                 (nmop(i),i=1,3)
               ELSE
                  WRITE (oUnit,'('' values accepted unchanged'')')
                  WRITE (oUnit,'(3(1x,i4),14x,''nmop(i),i=1,3'')')
     +                 (nmop(i),i=1,3)
               ENDIF
            ENDIF
         ELSE
!
!     --->   in all other cases:
!
            WRITE (oUnit,'(3(1x,i4),20x,'' idimens,idsyst,idtype: '',
     >''wrong choice for 2-dimensional crystal structure'')')
     >           idimens,idsyst,idtype
            CALL juDFT_error("2-dim crystal",calledby="kptmop")
         ENDIF
!
!     --->   check consistency of nmop-parameters with crystal symmetry
!
      ELSEIF (idimens.EQ.3) THEN
         IF (idsyst.EQ.1 .OR. idsyst.EQ.5) THEN
            IF (nmop(1).NE.nmop(2) .OR. nmop(1).NE.nmop(3)
     +           .OR. nmop(2).NE.nmop(3)) THEN
               nmop(3) = nmop(1)
               nmop(2) = nmop(1)
               WRITE (oUnit,'(1x,''WARNING!!!!!!!'',/,
     +''nmop-Parameters not in accordance with symmetry'',/,
     +2(1x,i4),/,
     +'' we have set all nmop(i) = nmop(1)'')') idsyst, idtype
               WRITE (oUnit,'(3(1x,i4),'' new val for nmop(i): '')')
     +              (nmop(i),i=1,3)
            ELSE
               WRITE (oUnit,'('' values accepted unchanged'')')
               WRITE (oUnit,'(3(1x,i4),14x,''nmop(i),i=1,3'')')
     +              (nmop(i),i=1,3)
            ENDIF
         ELSEIF (idsyst.EQ.2 .OR. idsyst.eq.4) THEN
            if((nmop(3).eq.nmop(2)).and.idsyst.eq.2)then
               WRITE (oUnit,'('' values accepted unchanged'')')
               WRITE (oUnit,'(3(1x,i4),14x,''nmop(i),i=1,3'')')
     +              (nmop(i),i=1,3)
            elseif(nmop(1).NE.nmop(2)) THEN
               nmop(2) = nmop(1)
               WRITE (oUnit,'(1x,''WARNING!!!!!!!'',/,
     +''nmop-Parameters not in accordance with symmetry'',/,
     +2(1x,i4),/,
     +'' we have set nmop(2) = nmop(1)'')') idsyst, idtype
               WRITE (oUnit,'(3(1x,i4),'' new val for nmop: '')')
     +              (nmop(i),i=1,3)
               CALL juDFT_warn(
     +             "k point mesh not compatible with symmetry (1)",
     +             calledby='kptmop')
            ELSE
               WRITE (oUnit,'('' values accepted unchanged'')')
               WRITE (oUnit,'(3(1x,i4),14x,''nmop(i),i=1,3'')')
     +              (nmop(i),i=1,3)
            ENDIF
         ELSEIF (idsyst.LT.1 .OR. idsyst.GT.7) THEN
            WRITE (oUnit,'(1x,''wrong choice of symmetry'',/,
     +2(1x,i4))') idsyst, idtype
            WRITE (oUnit,'(''only values 1.le.idsyst.le.7 allowed'')')
            CALL juDFT_error("wrong idsyst",calledby="kptmop")
         ELSE
            WRITE (oUnit,'('' values accepted unchanged'')')
            WRITE (oUnit,'(3(1x,i4),11x,''nmop(i),i=1,3'')')
     +           (nmop(i),i=1,3)
         ENDIF
      ELSE
         CALL juDFT_error("idimens =/= 2,3 ",calledby="kptmop")
      ENDIF
!
!     --->   start calculation
!     =====================================================================
!
!     ---> set sign constants
      isi(1) = 0
      isi(2) = iminus
      isi(3) = iplus
!
!     ---> calc orientation of boundary faces of irr wedge of BZ
!     characterized by
!     iside(i)= sign( (xvec,fnorm(i))-fdist(i) ) ;(i=1,nface )
!
      WRITE (oUnit,'(1x,''orientation of boundary faces'')')
      DO ifac = 1, nface
         orient = zero
         iside(ifac) = iplus
         DO ii = 1, 3
            orient = orient + xvec(ii)*fnorm(ii,ifac)
         ENDDO
         orient = orient - fdist(ifac)
         IF (orient .LT. 0) iside(ifac) = iminus
         WRITE (oUnit,'(1x,2(i4,2x),f10.7,10x,''ifac,iside,orient'',
     +'' for xvec'')') ifac,iside(ifac),orient
      ENDDO

      invtpi = one / ( 2.0 * pimach() )

      WRITE (oUnit,'(''Bravais lattice vectors'')' )
      DO ii = 1, 3
         WRITE (oUnit,'(43x,3(1x,f11.6))') (bltv(ii,ikc), ikc=1,3)
      ENDDO
      WRITE (oUnit,'(''reciprocal lattice vectors'')' )
      DO ii = 1, 3
         WRITE (oUnit,'(43x,3(1x,f11.6))' ) (rltv(ii,ikc), ikc=1,3)
      ENDDO
!
!     ---> nmop(i) are Monkhorst-Pack parameters; they determine the
!     number of k-points in i-direction
!     if basis vector lengths are not related by symmetry,
!     we can use independent fractions for each direction
!
      WRITE (oUnit,'(3(1x,i4),10x,'' Monkhorst-Pack-parameters'')')
     +     (nmop(i1),i1=1,3)

      DO idim = 1, idimens
         IF (nmop(idim).GT.0) THEN
            ainvnmop(idim) = one/ real(nmop(idim))
         ELSE
            WRITE (oUnit,'('' nmop('',i4,'') ='',i4,
     +'' not allowed'')') idim, nmop(idim)
            CALL juDFT_error("nmop wrong",calledby="kptmop")
         ENDIF
      ENDDO

      WRITE (oUnit,'(1x,''Monkhorst-Pack-fractions'')' )
!
!     ---> nbound=1: k-points are generated on boundary of BZ
!     include  fract(1) =       -1/2
!     and  fract(2*nmop+1) = 1/2     for surface points of BZ
!
      IF ( nbound .EQ. 1) THEN
         WRITE (oUnit,'(1x,i4,10x,''nbound; k-points on boundary'',
     +'' of BZ included'')' ) nbound
!
!     ---> irregular Monkhorst--Pack--fractions
!     fract(r) = r / (2*nmop)
!
         DO idim = 1,idimens
            denom = half*ainvnmop(idim)
            divis(idim) = one / denom

            DO kpn = -nmop(idim),nmop(idim)
               fract(kpn+nmop(idim)+1,idim) = denom * real (kpn)
             WRITE (oUnit,'(10x,f10.7)' ) fract(kpn+nmop(idim)+1,idim)
            ENDDO
            nfract(idim) = 2*nmop(idim) + 1
         ENDDO
         IF (idimens .eq. 2) THEN
            nfract(3) = 1
            fract(1,3) = 0
            divis(3) = one
         END IF
!
!     ---> nbound=0: k-points are NOT generated on boundary of BZ
!     This is the regular Monkhorst-Pack-method
!
      ELSEIF ( nbound .eq. 0) then
         WRITE (oUnit,'(1x,i4,10x,''nbound; no k-points '',
     +'' on boundary of BZ'')' ) nbound
!
!     --->   regular Monkhorst--Pack--fractions
!     fract(r) =(2*r-nmop-1) / (2*nmop)
!
         DO idim = 1,idimens
            denom = half*ainvnmop(idim)
            divis(idim) = one / denom
            WRITE(oUnit,'(5x,i4,5x,''idim'')' ) idim
            DO  kpn = 1,nmop(idim)
               fract(kpn,idim) = denom * real (2*kpn -nmop(idim)-1)
               write(oUnit,'(10x,f10.7)' ) fract(kpn,idim)
            ENDDO
            nfract(idim) = nmop(idim)
         ENDDO

         IF (idimens .EQ. 2) THEN
            nfract(3) = 1
            fract(1,3) = 0
            divis(3) = one
         ENDIF

      ELSE
         WRITE (oUnit,'(3x,'' wrong choice of nbound:'', i4)') nbound
         WRITE (oUnit,'(3x,'' ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'')')
         CALL juDFT_error("nbound",calledby="kptmop")
      ENDIF

!
!
!     --->   initialize k-points = zero and weights = 1.0
!
      DO  kpn = 1,mkpt
         vkxyz(1,kpn) = zero
         vkxyz(2,kpn) = zero
         vkxyz(3,kpn) = zero
         wghtkp(kpn) = one
      ENDDO
!
!     ---> generate equidistant k-vectors in cartesian coordinates
!
      nkpt = 0
      DO i3 = 1,nfract(3)
         DO i2 = 1,nfract(2)
            DO i1 = 1,nfract(1)
               nkpt = nkpt + 1
               IF (nkpt>mkpt)  CALL juDFT_error("nkpt > mkpt",calledby
     +              ="kptmop")
               vkxyz(1,nkpt) = rltv(1,1)*fract(i1,1)
     +              + rltv(1,2)*fract(i2,2)
     +              + rltv(1,3)*fract(i3,3)
               vkxyz(2,nkpt) = rltv(2,1)*fract(i1,1)
     +              + rltv(2,2)*fract(i2,2)
     +              + rltv(2,3)*fract(i3,3)
               vkxyz(3,nkpt) = rltv(3,1)*fract(i1,1)
     +              + rltv(3,2)*fract(i2,2)
     +              + rltv(3,3)*fract(i3,3)
            ENDDO
         ENDDO
      ENDDO
!
!     --->   calculate weights of k-points and print out k-points
!     wghtkp = 1/nkpt
!     ( = 1/(nmop(1)*nmop(2)*nmop(3)) for reg Monk-Pack-method)
!
!      divis(4) = real(nkpt)
!      aivnkpt  = one/real(nkpt)

!      DO  kpn= 1,nkpt
!         wghtkp(kpn) = wghtkp(kpn)*aivnkpt
!      ENDDO

!
!     ====================================================================
!
!     --->   order generated k-points in stars by applying symmetry:
!     - determine number of different stars nkstar .le. nkpt
!     - determine order of star iostar(kpn) .le. nsym
!     - assign pointer ikpn(i,ik); i=1,iostar(ik); ik=1,nkstar
!     - determine representative vector in irrBZ for each star:
!     vkrep(ix,ik); ix=1,3; ik=1,nkstar
!
      CALL ordstar(
     >     6,0,0,
     >     fnorm,fdist,nface,iside,
     >     nsym,ccr,rltv,mkpt,mface,mdir,
     =     nkpt,vkxyz,
     <     nkstar,iostar,ikpn,vkrep,nkrep)
!
!
!     (a) calculate weights for k-points in irrBZ
!     - wghtkp(ik)=iostar(ik)/nkpt_old ; ik=1,nkstar
!
      DO ik = 1, nkstar
         wghtkp(ik) = wghtkp(ik)*iostar(ik)
      ENDDO
!
!     (b) final preparation of k-points for transfer to file
!     - assign nkpt= nkstar
!     - assign vkxyz(ix,ik) = vkrep(ix,ik); ix=1,3; ik=1,nkstar
!

         DO i1 = 1,3
            DO ik = 1,nkstar
               vkxyz(i1,ik) = vkrep(i1,ik)
            ENDDO
         ENDDO
         nkpt = nkstar
!
!     --> check for corner points, include them into k-point set:
!
      IF (nbound.EQ.1) THEN
         n = 1
         nc2d = 1               ! determine 2D corner points
         cp2d(:,nc2d) = cpoint(:,n)
         corn: DO n = 2, ncorn
         DO i = 1, n-1
            IF ((abs(cpoint(1,n)-cpoint(1,i)).LT.0.0001).AND.
     +           (abs(cpoint(2,n)-cpoint(2,i)).LT.0.0001)) CYCLE corn
         ENDDO
         nc2d = nc2d + 1
         cp2d(:,nc2d) = cpoint(:,n)
      ENDDO corn
      WRITE (oUnit,'(''2D corner points in internal units'')')
      corn2d: DO n = 1, nc2d
      WRITE (oUnit,'(i3,3x,2(f10.7,1x))') n,cp2d(1,n),cp2d(2,n)
      DO i = 1, nkpt
         IF ((abs(cp2d(1,n)-vkxyz(1,i)).LT.0.0001).AND.
     +        (abs(cp2d(2,n)-vkxyz(2,i)).LT.0.0001)) CYCLE corn2d
      ENDDO
      nkpt = nkpt + 1
      vkxyz(:,nkpt) = cp2d(:,n)
      ENDDO corn2d
      ENDIF
!
!     --->   print out k-points and weights
!
      DEALLOCATE (fract,vkrep,ikpn,irrkpn,nkrep,iostar,iside)

      RETURN
      END SUBROUTINE kptmop
      END MODULE m_kptmop
