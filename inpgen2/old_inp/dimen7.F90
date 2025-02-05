      MODULE m_dimen7
      use m_juDFT
      CONTAINS
      SUBROUTINE dimen7(&
     &                  input,sym,stars,&
     &                  atoms,sphhar,vacuum,&
     &                  kpts ,hybinp,cell)

!
! This program reads the input files of the flapw-programm (inp & kpts)
! and creates a file 'fl7para' that contains dimensions
! for the main flapw-programm.
!

      USE m_localsym
      USE m_socsym
      USE m_sssym
      USE m_spg2set
      USE m_constants
      USE m_rwinp
      USE m_inpnoco
!      USE m_julia
!       
      USE m_types_input
      USE m_types_sym
      USE m_types_stars
      USE m_types_atoms
      USE m_types_sphhar
      USE m_types_vacuum
      USE m_types_kpts
       
      USE m_types_hybinp
      USE m_types_cell
      USE m_types_noco
      USE m_types_banddos
      USE m_types_sliceplot
      USE m_types_xcpot_inbuild_nofunction


      USE m_firstglance
      USE m_inv3
      USE m_rwsymfile
      USE m_strgndim
      USE m_inpeigdim
      USE m_ylm
      IMPLICIT NONE
!
! dimension-parameters for flapw:
!
      TYPE(t_input),INTENT(INOUT)   :: input
      TYPE(t_sym),INTENT(INOUT)     :: sym
      TYPE(t_stars),INTENT(INOUT)   :: stars
      TYPE(t_atoms),INTENT(INOUT)   :: atoms
      TYPE(t_sphhar),INTENT(INOUT)  :: sphhar

      TYPE(t_vacuum),INTENT(INOUT)   :: vacuum
      TYPE(t_kpts),INTENT(INOUT)     :: kpts
       
      TYPE(t_hybinp),INTENT(INOUT)   :: hybinp
      TYPE(t_cell),INTENT(INOUT)     :: cell

      TYPE(t_noco)      :: noco
      TYPE(t_sliceplot) :: sliceplot
      TYPE(t_banddos)   :: banddos
      TYPE(t_xcpot_inbuild_nf)     :: xcpot

!
!
!-------------------------------------------------------------------
! ..  Local Scalars ..
      REAL   :: thetad,xa,epsdisp,epsforce ,rmtmax,arltv1,arltv2,arltv3
      REAL   :: s,r,d ,idsprs
      INTEGER :: ok,ilo,n,nstate,i,j,na,n1,n2,jrc,nopd,symfh
      INTEGER :: nmopq(3)

      CHARACTER(len=1) :: rw
      CHARACTER(len=4) :: namex
      CHARACTER(len=7) :: symfn
      CHARACTER(len=12):: relcor
      LOGICAL  ::l_kpts,l_qpts,l_inpexist,l_tmp(2)
! ..
      REAL    :: a1(3),a2(3),a3(3)
      REAL    :: q(3)

      CHARACTER(len=3), ALLOCATABLE :: noel(:)
      LOGICAL, ALLOCATABLE :: error(:)

      INTEGER ntp1,ii,grid(3)
      INTEGER, ALLOCATABLE :: lmx1(:), nq1(:), nlhtp1(:)

!     added for HF and hybinp functionals
      LOGICAL          ::  l_gamma=.false.
      character(len=4) :: latnam,namgrp
      real             :: scalecell
      EXTERNAL prp_xcfft_box!,parawrite
!     ..


!---> First, check whether an inp-file exists
!
      INQUIRE (file='inp',exist=l_inpexist)
      IF (.not.l_inpexist) THEN
         CALL juDFT_error("no inp- or input-file found!",calledby ="dimen7")
      ENDIF
!
!---> determine ntype,nop,natd,nwdd,nlod and layerd
!
      CALL first_glance(atoms%ntype,sym%nop,atoms%nat,atoms%nlod,banddos%layers,&
                        input%itmax,l_kpts,l_qpts,l_gamma,kpts%nkpt,grid,nmopq)
      atoms%ntype=atoms%ntype
      atoms%nlod = max(atoms%nlod,1)

      ALLOCATE (&
     & atoms%lmax(atoms%ntype),sym%ntypsy(atoms%nat),atoms%neq(atoms%ntype),atoms%nlhtyp(atoms%ntype),&
     & atoms%rmt(atoms%ntype),atoms%zatom(atoms%ntype),atoms%jri(atoms%ntype),atoms%dx(atoms%ntype), &
     & atoms%nlo(atoms%ntype),atoms%llo(atoms%nlod,atoms%ntype),atoms%bmu(atoms%ntype),&
     & noel(atoms%ntype),banddos%izlay(banddos%layers,2),atoms%econf(atoms%ntype),atoms%lnonsph(atoms%ntype),&
     & atoms%taual(3,atoms%nat),atoms%pos(3,atoms%nat),&
     & atoms%nz(atoms%ntype),atoms%relax(3,atoms%ntype),&
     & atoms%l_geo(atoms%ntype),noco%alph_inp(atoms%ntype),noco%beta_inp(atoms%ntype),&
     & atoms%lda_u(atoms%ntype),&
     & sphhar%clnu(1,1,1),sphhar%nlh(1),sphhar%llh(1,1),sphhar%nmem(1,1),sphhar%mlh(1,1,1),&
     & hybinp%select1(4,atoms%ntype),hybinp%lcutm1(atoms%ntype),&
     & hybinp%lcutwf(atoms%ntype), STAT=ok)
!
!---> read complete input and calculate nvacd,llod,lmaxd,jmtd,neigd and
!
      CALL rw_inp('r',&
     &            atoms,vacuum,input,stars,sliceplot,banddos,&
     &                  cell,sym,xcpot,noco ,hybinp,kpts,&
     &                  noel,namex,relcor,a1,a2,a3,latnam,grid,namgrp,scalecell)

!---> pk non-collinear
!---> read the angle and spin-spiral information from nocoinp
      noco%qss_inp = 0.0
      noco%l_ss = .false.
      IF (noco%l_noco) THEN
         CALL inpnoco(atoms,input,sym,vacuum,noco)
      ENDIF

      vacuum%nvacd = 2
      atoms%llod  = 0
      atoms%lmaxd = 0
      atoms%jmtd  = 0
      rmtmax      = 0.0
      input%neig = 0
      atoms%lmaxd = maxval(atoms%lmax)
      atoms%jmtd  = maxval(atoms%jri)
      rmtmax      = maxval(atoms%rmt)
      DO n = 1,atoms%ntype
        DO ilo = 1,atoms%nlo(n)
!+apw
          IF (atoms%llo(ilo,n).LT.0) THEN
             atoms%llo(ilo,n) = -atoms%llo(ilo,n) - 1
          ELSE
             input%neig = input%neig + atoms%neq(n)*(2*abs(atoms%llo(ilo,n)) +1)
          ENDIF
!-apw
          atoms%llod = max(abs(atoms%llo(ilo,n)),atoms%llod)
        ENDDO
        nstate = 4
        IF ((atoms%nz(n).GE.21.AND.atoms%nz(n).LE.29) .OR. &
     &      (atoms%nz(n).GE.39.AND.atoms%nz(n).LE.47) .OR.&
     &      (atoms%nz(n).GE.57.AND.atoms%nz(n).LE.79)) nstate = 9
        IF ((atoms%nz(n).GE.58.AND.atoms%nz(n).LE.71) .OR.&
     &      (atoms%nz(n).GE.90.AND.atoms%nz(n).LE.103)) nstate = 16
        input%neig = input%neig + nstate*atoms%neq(n)
!
      ENDDO
      !CALL ylmnorm_init(atoms%lmaxd)
!      IF (mod(lmaxd,2).NE.0) lmaxd = lmaxd + 1
      IF (2*input%neig.LT.MAX(5.0,input%zelec)) THEN
        WRITE(oUnit,*) input%neig,' states estimated in dimen7 ...'
        input%neig = MAX(5,NINT(0.75*input%zelec))
        WRITE(oUnit,*) 'changed input%neig to ',input%neig
      ENDIF
      IF (noco%l_soc .and. (.not. noco%l_noco)) input%neig=2*input%neig
      IF (noco%l_soc .and. noco%l_ss) input%neig=(3*input%neig)/2
       ! not as accurate, but saves much time

      rmtmax = rmtmax*stars%gmax
!
! determine core mesh
!
      atoms%msh = 0
      DO n = 1,atoms%ntype
         r = atoms%rmt(n)
         d = exp(atoms%dx(n))
         jrc = atoms%jri(n)
         DO WHILE (r < atoms%rmt(n) + 20.0)
            jrc = jrc + 1
            r = r*d
         ENDDO
         atoms%msh = max( atoms%msh, jrc )
      ENDDO
!
! ---> now, set the lattice harmonics, determine nlhd
!
      cell%amat(:,1) = a1(:)*scaleCell
      cell%amat(:,2) = a2(:)*scaleCell
      cell%amat(:,3) = a3(:)*scaleCell
      CALL inv3(cell%amat,cell%bmat,cell%omtil)
      IF (input%film) cell%omtil = cell%omtil/cell%amat(3,3)*vacuum%dvac
      cell%bmat=tpi_const*cell%bmat

      na = 0
      DO n = 1,atoms%ntype
        DO n1 = 1,atoms%neq(n)
            na = na + 1
            IF (input%film) atoms%taual(3,na) = atoms%taual(3,na)/a3(3)
            atoms%pos(:,na) = matmul(cell%amat,atoms%taual(:,na))
        ENDDO
        atoms%zatom(n) = real( atoms%nz(n) )
      ENDDO
      ALLOCATE (sym%mrot(3,3,sym%nop),sym%tau(3,sym%nop))
      IF (namgrp.EQ.'any ') THEN
         nopd = sym%nop ; rw = 'R'
         symfh = 94 ; symfn = 'sym.out'
         CALL rw_symfile(rw,symfh,symfn,nopd,cell%bmat,sym%mrot,sym%tau,sym%nop,sym%nop2,sym%symor)
      ELSE
         CALL spg2set(sym%nop,.false.,sym%invs,namgrp,latnam,sym%mrot,sym%tau,sym%nop2,sym%symor)
      ENDIF
      sphhar%ntypsd = 0
        CALL local_sym(.false.,atoms%lmaxd,atoms%lmax,sym%nop,sym%mrot,sym%tau,&
                       atoms%nat,atoms%ntype,atoms%neq,cell%amat,cell%bmat,&
                       atoms%taual,sphhar%nlhd,sphhar%memd,sphhar%ntypsd,.true.,&
                       atoms%nlhtyp,sphhar%nlh,sphhar%llh,&
                       sphhar%nmem,sphhar%mlh,sphhar%clnu)

!
! Check if symmetry is compatible with SOC or SSDW
!
      IF (noco%l_soc .and. (.not.noco%l_noco)) THEN
        ! test symmetry for spin-orbit coupling
        ALLOCATE ( error(sym%nop) )
        CALL soc_sym(sym%nop,sym%mrot,noco%theta_inp,noco%phi_inp,cell%amat,error)
        IF ( ANY(error(:)) ) THEN
          WRITE(*,fmt='(1x)')
          WRITE(*,fmt='(A)') 'Symmetry incompatible with SOC spin-quantization axis ,'
          WRITE(*,fmt='(A)') 'do not perform self-consistent calculations !'
          WRITE(*,fmt='(1x)')
          IF ( input%eonly .or. (noco%l_soc.and.noco%l_ss) .or. input%gw.ne.0 ) THEN  ! .or. .
            CONTINUE
          ELSE
            IF (input%itmax>1) THEN
               CALL juDFT_error("symmetry & SOC",calledby ="dimen7")
            ENDIF
          ENDIF
        ENDIF
        DEALLOCATE ( error )
      ENDIF
      IF (noco%l_ss) THEN  ! test symmetry for spin-spiral
        ALLOCATE ( error(sym%nop) )
        CALL ss_sym(sym%nop,sym%mrot,noco%qss_inp,error)
        IF ( ANY(error(:)) )  CALL juDFT_error("symmetry & SSDW", calledby="dimen7")
        DEALLOCATE ( error )
      ENDIF
!
! Dimensioning of the stars
!
!      IF (input%film.OR.(namgrp.ne.'any ')) THEN
!         CALL strgn1_dim(.false.,stars%gmax,cell%bmat,sym%invs,sym%zrfs,sym%mrot,&
!                    sym%tau,sym%nop,sym%nop2,stars%mx1,stars%mx2,stars%mx3,&
!                    stars%ng3,stars%ng2 %odd)

!      ELSE
!         CALL strgn2_dim(.false.,stars%gmax,cell%bmat,sym%invs,sym%zrfs,sym%mrot,&
!                    sym%tau,sym%nop,stars%mx1,stars%mx2,stars%mx3,&
!                    stars%ng3,stars%ng2)
!      ENDIF

      IF ( xcpot%gmaxxc .le. 10.0**(-6) ) THEN
         WRITE (oUnit,'(" xcpot%gmaxxc=0 : xcpot%gmaxxc=stars%gmax choosen as default value")')
         WRITE (oUnit,'(" concerning memory, you may want to choose a smaller value for stars%gmax")')
         xcpot%gmaxxc=stars%gmax
      END IF

      !CALL prp_xcfft_box(xcpot%gmaxxc,cell%bmat,stars%kxc1_fft,stars%kxc2_fft,stars%kxc3_fft)
!
! k-point generator provides kpts-file, if it's missing:
!
      IF (.not.l_kpts) THEN
         IF(l_gamma ) THEN
         call judft_error("gamma swtich not supported in old inp file anymore",calledby="dimen7")
         ELSE
!         CALL julia(sym,cell,input,noco,banddos,kpts,.false.,.FALSE.)
         ENDIF
      ELSE
        IF(input%gw.eq.2) THEN
          INQUIRE(file='QGpsi',exist=l_kpts) ! Use QGpsi if it exists ot
          IF(l_kpts) THEN
            WRITE(oUnit,*) 'QGpsi exists and will be used to generate kpts-file'
            OPEN (15,file='QGpsi',form='unformatted',status='old',action='read')
            OPEN (41,file='kpts',form='formatted',status='unknown')
            REWIND(41)
            READ (15) kpts%nkpt
            WRITE (41,'(i5,f20.10)') kpts%nkpt,1.0
            DO n = 1, kpts%nkpt
              READ (15) q
              WRITE (41,'(4f10.5)') MATMUL(TRANSPOSE(cell%amat),q)/scaleCell,1.0
              READ (15)
            ENDDO
            CLOSE (15)
            CLOSE (41)
          ENDIF
        ENDIF
      ENDIF

      input%neig = max(input%neig,input%gw_neigd)

!
! Using the k-point generator also for creation of q-points for the
! J-constants calculation:
!      IF(.not.l_qpts)THEN
!        kpts%nkpt3=nmopq
!        l_tmp=(/noco%l_ss,noco%l_soc/)
!        noco%l_ss=.false.
!        noco%l_soc=.false.
!        CALL julia(sym,cell,input,noco,banddos,kpts,.true.,.FALSE.)
!        noco%l_ss=l_tmp(1); noco%l_soc=l_tmp(2)
!      ENDIF

!
! now proceed as usual
!
      CALL inpeig_dim(input,cell,noco ,kpts,stars,latnam)
      banddos%layers = max(banddos%layers,1)
      atoms%ntype = atoms%ntype
      IF (noco%l_noco) input%neig = 2*input%neig

      atoms%nlod = max(atoms%nlod,2) ! for chkmt
      input%jspins=input%jspins
      !CALL parawrite(sym,stars,atoms,sphhar,vacuum,kpts ,input)

      DEALLOCATE( sym%mrot,sym%tau,&
     & atoms%lmax,sym%ntypsy,atoms%neq,atoms%nlhtyp,atoms%rmt,atoms%zatom,atoms%jri,atoms%dx,atoms%nlo,atoms%llo,atoms%bmu,noel,&
     & banddos%izlay,atoms%econf,atoms%lnonsph,atoms%taual,atoms%pos,atoms%nz,atoms%relax,&
     & sphhar%llh,sphhar%nmem,sphhar%mlh,hybinp%select1,hybinp%lcutm1,&
     & hybinp%lcutwf)

      RETURN
      END SUBROUTINE dimen7
      END MODULE m_dimen7
