      MODULE m_setinp
      use m_juDFT
!---------------------------------------------------------------------
!  Check muffin tin radii and determine a reasonable choice for MTRs.
!  Derive also other parameters for the input file, to provide some
!  help in the out-file.                                        gb`02
!---------------------------------------------------------------------
      CONTAINS
      SUBROUTINE set_inp(&
     &                   infh,nline,xl_buffer,buffer,l_hyb,&
     &                   atoms,sym,cell,title,idlist,&
     &                   input,vacuum,noco,&
     &                   a1,a2,a3)

      USE m_chkmt
      USE m_constants, ONLY : namat_const
      USE m_atominput
      USE m_lapwinput
      USE m_rwinp
      USE m_types
      IMPLICIT NONE
      TYPE(t_input),INTENT(INOUT)    :: input
      TYPE(t_vacuum),INTENT(INOUT)   :: vacuum
      TYPE(t_noco),INTENT(INOUT)     :: noco
      TYPE(t_sym),INTENT(INOUT)      :: sym
      TYPE(t_cell),INTENT(INOUT)     :: cell
      TYPE(t_atoms),INTENT(INOUT)    :: atoms

      INTEGER, INTENT (IN) :: infh,xl_buffer
      INTEGER, INTENT (INOUT) :: nline
      CHARACTER(len=xl_buffer) :: buffer
      LOGICAL, INTENT (IN) :: l_hyb  
      REAL,    INTENT (IN) :: idlist(:)
      REAL,    INTENT (INOUT) :: a1(3),a2(3),a3(3) 
      CHARACTER(len=80), INTENT (IN) :: title
 
      INTEGER nel,i,j
      REAL    kmax,dtild,dvac1,n1,n2,gam,kmax0,dtild0,dvac0
      LOGICAL l_test,l_gga,l_exists
      REAL     dx0(atoms%ntype)
      INTEGER  div(3)
      INTEGER jri0(atoms%ntype),lmax0(atoms%ntype),nlo0(atoms%ntype),llo0(atoms%nlod,atoms%ntype)
      CHARACTER(len=1) :: ch_rw
      CHARACTER(len=4) :: namex
      CHARACTER(len=8) :: name(10)
      CHARACTER(len=3) :: noel(atoms%ntype)
      CHARACTER(len=12) :: relcor
      INTEGER  nu,iofile      
      INTEGER  iggachk
      INTEGER  n  ,iostat
      REAL    scale,scpos ,zc 

      TYPE(t_banddos)::banddos
      TYPE(t_obsolete)::obsolete
      TYPE(t_sliceplot)::sliceplot
      TYPE(t_oneD)::oneD
      TYPE(t_jij)::Jij
      TYPE(t_stars)::stars
      TYPE(t_hybrid)::hybrid
      TYPE(t_xcpot)::xcpot
      TYPE(t_kpts)::kpts

    !-odim
!+odim
!      REAL, PARAMETER :: eps=0.00000001
!     ..
!HF   added for HF and hybrid functionals
      REAL     ::  gcutm,tolerance
      REAL     ::  taual_hyb(3,atoms%nat)
      INTEGER  ::  selct(4,atoms%ntype),lcutm(atoms%ntype)
      INTEGER  ::  selct2(4,atoms%ntype) 
      INTEGER  ::  bands 
      LOGICAL  ::  l_gamma
      INTEGER  :: nkpt3(3)
!HF

      l_test = .false.
      l_gga  = .true.
      atoms%nlod=9
      ALLOCATE(atoms%nz(atoms%ntype))
      ALLOCATE(atoms%jri(atoms%ntype))
      ALLOCATE(atoms%dx(atoms%ntype))
      ALLOCATE(atoms%lmax(atoms%ntype))
      ALLOCATE(atoms%nlo(atoms%ntype))
      ALLOCATE(atoms%llo(atoms%nlod,atoms%ntype))
      ALLOCATE(atoms%ncst(atoms%ntype))
      ALLOCATE(atoms%lnonsph(atoms%ntype))
      ALLOCATE(atoms%nflip(atoms%ntype))
      ALLOCATE(atoms%l_geo(atoms%ntype))
      ALLOCATE(atoms%lda_u(atoms%ntype))
      ALLOCATE(atoms%bmu(atoms%ntype))
      ALLOCATE(atoms%relax(3,atoms%ntype))
      ALLOCATE(noco%soc_opt(atoms%ntype+2))

      atoms%nz(:) = NINT(atoms%zatom(:))
      DO i = 1, atoms%ntype
       noel(i) = namat_const(atoms%nz(i))
      ENDDO
      atoms%rmt(:) = 999.9
      atoms%pos(:,:) = matmul( cell%amat , atoms%taual(:,:) )
      ch_rw = 'w'
      sym%namgrp= 'any ' 
      banddos%dos   = .false. ; input%secvar = .false.
      input%vchk = .false. ; input%cdinf = .false. 
      obsolete%pot8 = .false. ; obsolete%eig66(1) = .false. ; obsolete%eig66(2) = .true.  
      obsolete%form66 = .false. ; obsolete%l_u2f= .false. ; obsolete%l_f2u = .false. 
      input%l_bmt= .false. ; input%eonly  = .false.
      input%gauss= .false. ; input%tria  = .false. 
      sliceplot%slice= .false. ; obsolete%disp  = .false. ; input%swsp  = .false.
      input%lflip= .false. ; banddos%vacdos= .false. ; input%integ = .false.
      sliceplot%iplot= .false. ; input%score = .false. ; sliceplot%plpot = .false.
      input%pallst = .false. ; obsolete%lwb = .false. ; vacuum%starcoeff = .false.
      input%strho  = .false.  ; input%l_f = .false. ; atoms%l_geo(:) = .true.
      noco%l_noco = noco%l_ss ; jij%l_J = .false. ; noco%soc_opt(:) = .false. ; input%jspins = 1
      obsolete%lpr = 0 ; input%itmax = 9 ; input%maxiter = 99 ; input%imix = 7 ; input%alpha = 0.05 
      input%spinf = 2.0 ;   obsolete%lepr = 0
      sliceplot%kk = 0 ; sliceplot%nnne = 0 ; obsolete%nwd = 1 ; vacuum%nstars = 0 ; vacuum%nstm = 0 
      input%isec1 = 99 ; nu = 5 ; vacuum%layerd = 1 ; iofile = 6  
      banddos%ndir = 0 ; vacuum%layers = 0 ; atoms%nflip(:) = 1 ; vacuum%izlay(:,:) = 0 
      atoms%lda_u%l = -1 ; atoms%relax(1:2,:) = 1 ; atoms%relax(:,:) = 1
      input%epsdisp = 0.00001 ; input%epsforce = 0.00001 ; input%xa = 2.0 ; input%thetad = 330.0
      sliceplot%e1s = 0.0 ; sliceplot%e2s = 0.0 ; banddos%e1_dos = 0.5 ; banddos%e2_dos = -0.5 ; input%tkb = 0.001
      banddos%sig_dos = 0.015 ; vacuum%tworkf = 0.0 ; scale = 1.0 ; scpos = 1.0 
      zc = 0.0 ; vacuum%locx(:) = 0.0 ;  vacuum%locy(:) = 0.0 

!+odim
      oneD%odd%mb = 0 ; oneD%odd%M = 0 ; oneD%odd%m_cyl = 0 ; oneD%odd%chi = 0 ; oneD%odd%rot = 0
      oneD%odd%k3 = 0 ; oneD%odd%n2d= 0 ; oneD%odd%nq2 = 0 ; oneD%odd%nn2d = 0 
      oneD%odd%nop = 0 ; oneD%odd%kimax2 = 0 ; oneD%odd%nat = 0
      oneD%odd%invs = .false. ; oneD%odd%zrfs = .false. ; oneD%odd%d1 = .false.
!-odim
! check for magnetism
      atoms%bmu(:) = 0.0
      DO n = 1, atoms%ntype
        IF (atoms%nz(n).EQ.24) atoms%bmu(n) = 1.0  ! Cr - Ni
        IF (atoms%nz(n).EQ.25) atoms%bmu(n) = 3.5
        IF (atoms%nz(n).EQ.26) atoms%bmu(n) = 2.2
        IF (atoms%nz(n).EQ.27) atoms%bmu(n) = 1.6
        IF (atoms%nz(n).EQ.28) atoms%bmu(n) = 1.1
        IF (atoms%nz(n).EQ.59) atoms%bmu(n) = 2.1  ! Pr - Tm
        IF (atoms%nz(n).EQ.60) atoms%bmu(n) = 3.1
        IF (atoms%nz(n).EQ.61) atoms%bmu(n) = 4.1
        IF (atoms%nz(n).EQ.62) atoms%bmu(n) = 5.1
        IF (atoms%nz(n).EQ.63) atoms%bmu(n) = 7.1
        IF (atoms%nz(n).EQ.64) atoms%bmu(n) = 7.1 
        IF (atoms%nz(n).EQ.65) atoms%bmu(n) = 6.1
        IF (atoms%nz(n).EQ.66) atoms%bmu(n) = 5.1
        IF (atoms%nz(n).EQ.67) atoms%bmu(n) = 4.1
        IF (atoms%nz(n).EQ.68) atoms%bmu(n) = 3.1
        IF (atoms%nz(n).EQ.69) atoms%bmu(n) = 2.1
      ENDDO
      IF ( ANY(atoms%bmu(:) > 0.0) ) input%jspins=2 

      input%delgau = input%tkb ; atoms%ntypd = atoms%ntype ; atoms%natd = atoms%nat
      DO i = 1, 10
        j = (i-1) * 8 + 1
        name(i) = title(j:j+7)
      ENDDO 
      IF (noco%l_noco) input%jspins = 2
       
      a1(:) = cell%amat(:,1) ; a2(:) = cell%amat(:,2) ; a3(:) = cell%amat(:,3) 

      CALL chkmt(&
     &           atoms,input,vacuum,cell,oneD,&
     &           l_gga,noel,l_test,&
     &           kmax,dtild,vacuum%dvac,atoms%lmax,atoms%jri,atoms%rmt,atoms%dx)

! --> read in (possibly) atomic info

      CALL atom_input(&
     &                infh,atoms%ntype,atoms%zatom,xl_buffer,buffer,atoms%nlod,&
     &                input%jspins,input%film,atoms%neq,idlist,&
     &                nline,atoms%jri,atoms%lmax,atoms%lnonsph,atoms%ncst,atoms%rmt,atoms%dx,atoms%bmu,&
     &                atoms%nlo,atoms%llo,nel)

! --> check once more

      l_test = .true.
      CALL chkmt(&
     &           atoms,input,vacuum,cell,oneD,&
     &           l_gga,noel,l_test,&
     &           kmax0,dtild0,dvac0,lmax0,jri0,atoms%rmt,dx0)

      IF ( ANY(atoms%nlo(:).NE.0) ) THEN
        input%ellow = -1.8
      ELSE
        input%ellow = -0.8  
      ENDIF
      IF (input%film) THEN
         input%elup = 0.5
      ELSE
         input%elup = 1.0
      ENDIF
      stars%gmax = 3.0 * kmax ; xcpot%gmaxxc = 2.5 * kmax ; input%rkmax = kmax
      atoms%lnonsph(:) = min( max( (atoms%lmax(:)-2),3 ), 8 ) 
      input%zelec = nel

      IF (.not.input%film) THEN
         vacuum%dvac = a3(3) ; dtild = vacuum%dvac
      ENDIF
      IF ( (abs(a1(3)).GT.eps).OR.(abs(a2(3)).GT.eps).OR.&
     &     (abs(a3(1)).GT.eps).OR.(abs(a3(2)).GT.eps) ) THEN          
        cell%latnam = 'any'
      ELSE
        IF ( (abs(a1(2)).LT.eps).AND.(abs(a2(1)).LT.eps) ) THEN
          IF (abs(a1(1)-a2(2)).LT.eps) THEN
            cell%latnam = 'squ'
          ELSE
            cell%latnam = 'p-r'
          ENDIF
        ELSE
          n1 = sqrt(a1(1)**2 + a1(2)**2); n2 = sqrt(a2(1)**2 + a2(2)**2)
          IF (abs(n1-n2).LT.eps) THEN
            gam = ( a1(1)*a2(1) + a1(2)*a2(2) ) / (n1 * n2)
            gam = 57.295779512*acos(gam)
            IF (abs(gam-60.).LT.eps) THEN
               cell%latnam = 'hex'
               a1(2) = n1 * 0.5
               a1(1) = a1(2) * sqrt(3.0)
            ELSEIF (abs(gam-120.).LT.eps) THEN
               cell%latnam = 'hx3'
               a1(1) = n1 * 0.5
               a1(2) = a1(1) * sqrt(3.0)
            ELSE
               cell%latnam = 'c-r'
               gam = 0.5 * gam / 57.295779512
               a1(1) =  n1 * cos(gam)
               a1(2) = -n1 * sin(gam)
            ENDIF
            a2(1) =   a1(1)
            a2(2) = - a1(2)
          ELSE
            cell%latnam = 'obl'
          ENDIF
        ENDIF
      ENDIF

!HF   added for HF and hybrid functionals
      gcutm       = input%rkmax - 0.5
      tolerance   = 1e-4
      hybrid%gcutm2      = input%rkmax - 0.5
      hybrid%tolerance2  = 1e-4
      taual_hyb   = atoms%taual
      selct(1,:)  = 4
      selct(2,:)  = 0
      selct(3,:)  = 4
      selct(4,:)  = 2
      lcutm       = 4
      selct2(1,:) = 4
      selct2(2,:) = 0
      selct2(3,:) = 4
      selct2(4,:) = 2
      hybrid%lcutm2      = 4
      hybrid%lcutwf      = atoms%lmax - atoms%lmax / 10
      hybrid%ewaldlambda = 3
      hybrid%lexp        = 16
      bands       = max( nint(input%zelec)*10, 60 )
      hybrid%bands2      = max( nint(input%zelec)*10, 60 )
      nkpt3       = (/ 4, 4, 4 /)
      l_gamma     = .true.
      IF ( l_hyb ) THEN
        input%ellow = input%ellow -  2.0
        input%elup  = input%elup  + 10.0
        input%gw_neigd = bands
      ELSE
        input%gw_neigd = 0
      END IF
!HF

! rounding
      atoms%rmt(:) = real(INT( atoms%rmt(:) * 100 ) / 100.)
      atoms%dx(:)   = real(INT( atoms%dx(:)   * 1000) / 1000.)
      stars%gmax    = real(INT( stars%gmax    * 10  ) / 10.)
      input%rkmax  = real(INT( input%rkmax  * 10  ) / 10.)
      xcpot%gmaxxc  = real(INT( xcpot%gmaxxc  * 10  ) / 10.)
      gcutm   = real(INT( gcutm   * 10  ) / 10.)
      hybrid%gcutm2  = real(INT( hybrid%gcutm2  * 10  ) / 10.)
      IF (input%film) THEN
       vacuum%dvac = real(INT(vacuum%dvac*100+1)/100.)
       dtild = real(INT(dtild*100+1)/100.)
      ENDIF
!
! read some lapw input
!
      CALL lapw_input(&
     &                infh,nline,xl_buffer,buffer,&
     &                input%jspins,input%kcrel,obsolete%ndvgrd,kpts%nkpt,div,&
     &                input%frcor,input%ctail,obsolete%chng,input%tria,input%rkmax,stars%gmax,xcpot%gmaxxc,&
     &                xcpot%igrd,vacuum%dvac,dtild,input%tkb,namex,relcor)
!
      IF (input%film) atoms%taual(3,:) = atoms%taual(3,:) * a3(3) / dtild

      CLOSE (6)
      inquire(file="inp",exist=l_exists)
      IF (l_exists) THEN
         CALL juDFT_error("Cannot overwrite existing inp-file ",calledby&
     &        ="set_inp")
      ENDIF
      
      nu = 8 
      input%gw = 0
      CALL rw_inp(&
     &            ch_rw,atoms,obsolete,vacuum,input,stars,sliceplot,banddos,&
     &                  cell,sym,xcpot,noco,jij,oneD,hybrid,kpts,&
     &                  noel,namex,relcor,a1,a2,a3,scale,dtild,name)
      iofile = 6
      OPEN (iofile,file='inp',form='formatted',status='old',position='append')
      
      IF (kpts%nkpt == 0) THEN     ! set some defaults for the k-points
        IF (input%film) THEN
          cell%area = cell%omtil / vacuum%dvac
          kpts%nkpt = nint((3600/cell%area)/sym%nop2)
        ELSE
          kpts%nkpt = nint((216000/cell%omtil)/sym%nop) 
        ENDIF
      ENDIF
      IF( l_hyb ) THEN
        WRITE (iofile,FMT=9999) product(nkpt3),nkpt3,l_gamma 
      ELSE IF( (div(1) == 0).OR.(div(2) == 0) ) THEN 
        WRITE (iofile,'(a5,i5)') 'kpts%nkpt=',kpts%nkpt
      ELSE
        WRITE (iofile,'(a5,i5,3(a4,i2))') 'nkpt=',kpts%nkpt,',nx=',div(1),&
     &                                   ',ny=',div(2),',nz=',div(3)
      ENDIF

      CLOSE (iofile)

!HF   create hybrid functional input file
      IF ( l_hyb ) THEN
        OPEN (iofile,file='inp_hyb',form='formatted',status='new',&
     &        iostat=iostat)
        IF (iostat /= 0) THEN
          STOP &
     &      'Cannot create new file "inp_hyb". Maybe it already exists?'
        ENDIF

        ! Changes for hybrid functionals
        input%strho = .false. ; input%isec1 = 999
        namex = 'hse '
        obsolete%pot8  = .true.
        input%frcor = .true. ; input%ctail = .false. ; atoms%l_geo = .false.
        input%itmax = 15 ; input%maxiter = 25 ; input%imix  = 17
      CALL rw_inp(&
     &            ch_rw,atoms,obsolete,vacuum,input,stars,sliceplot,banddos,&
     &                  cell,sym,xcpot,noco,jij,oneD,hybrid,kpts,&
     &                  noel,namex,relcor,a1,a2,a3,scale,dtild,name)

        IF ( ALL(div /= 0) ) nkpt3 = div
        WRITE (iofile,FMT=9999) product(nkpt3),nkpt3,l_gamma
9999    FORMAT ( 'nkpt=',i5,',nx=',i2,',ny=',i2,',nz=',i2,',gamma=',l1)
        CLOSE (iofile)
      END IF ! l_hyb
!HF
      END SUBROUTINE set_inp
      END MODULE m_setinp
