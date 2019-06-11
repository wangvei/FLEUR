!--------------------------------------------------------------------------------
! Copyright (c) 2016 Peter Grünberg Institut, Forschungszentrum Jülich, Germany
! This file is part of FLEUR and available as free software under the conditions
! of the MIT license as expressed in the LICENSE file in more detail.
!--------------------------------------------------------------------------------

MODULE m_make_defaults
  USE m_juDFT
!---------------------------------------------------------------------
!  Check muffin tin radii and determine a reasonable choice for MTRs.
!  Derive also other parameters for the input file, to provide some
!  help in the out-file.                                        gb`02
!---------------------------------------------------------------------
CONTAINS
  SUBROUTINE make_defaults(atoms,vacuum,input,stars,&
&                   cell,sym,xcpot,noco,hybrid,kpts)
     &                  title

      USE m_types
      USE iso_c_binding
      USE m_chkmt
      USE m_constants
      USE m_atominput
      USE m_lapwinput
      USE m_rwinp
      USE m_winpXML
      USE m_juDFT_init
      USE m_kpoints
      USE m_inv3
      USE m_types_xcpot_inbuild

      IMPLICIT NONE


    !-odim
!+odim
!      REAL, PARAMETER :: eps=0.00000001
!     ..
!HF   added for HF and hybrid functionals
      INTEGER  ::  bands
      INTEGER  :: nkpt3(3)
!HF

      INTEGER :: xmlElectronStates(29,atoms%ntype)
      LOGICAL :: xmlPrintCoreStates(29,atoms%ntype)
      REAL    :: xmlCoreOccs(2,29,atoms%ntype)
      REAL    :: xmlCoreRefOccs(29)

      interface
         function dropInputSchema() bind(C, name="dropInputSchema")
            use iso_c_binding
            INTEGER(c_int) dropInputSchema
         end function dropInputSchema
      end interface

   

      l_test = .false.
      l_gga  = .true.
   
      ! Set parameters to defaults that can not be given to inpgen
      ch_rw = 'w'
      sym%namgrp= 'any ' 
      vacuum%nstars = 0 ; vacuum%nstm = 0 
      nu = 5 ; vacuum%layerd = 1 ; iofile = 6
      ALLOCATE(vacuum%izlay(vacuum%layerd,2))
      vacuum%layers = 0  ; vacuum%izlay(:,:) = 0
      
      
      vacuum%tworkf = 0.0 ; scpos = 1.0
      zc = 0.0 ; vacuum%locx(:) = 0.0 ;  vacuum%locy(:) = 0.0
      kpts%numSpecialPoints = 0
     



      input%delgau = input%tkb
      input%comment = title
      IF (noco%l_noco) input%jspins = 2
       

      !defaults ...
      stars%gmax=merge(stars%gmax,3.0*input%rkmax,stars%gmax>0)
      xcpot%gmaxxc=merge(xcpot%gmaxxc,3.0*input%rkmax,xcpot%gmaxxc>0)
      
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

      IF (.not.input%film) THEN
         vacuum%dvac = a3(3) ; dtild = vacuum%dvac
      ENDIF

!HF   added for HF and hybrid functionals
      hybrid%gcutm1       = input%rkmax - 0.5
      ALLOCATE(hybrid%lcutwf(atoms%ntype))
      ALLOCATE(hybrid%lcutm1(atoms%ntype))
      ALLOCATE(hybrid%select1(4,atoms%ntype))
      hybrid%lcutwf      = atoms%lmax - atoms%lmax / 10
      hybrid%lcutm1      = 4
      hybrid%select1(1,:) = 4
      hybrid%select1(2,:) = 0
      hybrid%select1(3,:) = 4
      hybrid%select1(4,:) = 2
      bands       = max( nint(input%zelec)*10, 60 )
      hybrid%l_hybrid = l_hyb
      
      IF (l_hyb) THEN
         input%ellow = input%ellow -  2.0
         input%elup  = input%elup  + 10.0
         input%gw_neigd = bands
         kpts%l_gamma = .true.
         input%minDistance = 1.0e-5
      ELSE
        input%gw_neigd = 0
      END IF
!HF

! rounding
      stars%gmax    = real(NINT(stars%gmax    * 10  ) / 10.)
      input%rkmax   = real(NINT(input%rkmax   * 10  ) / 10.)
      xcpot%gmaxxc  = real(NINT(xcpot%gmaxxc  * 10  ) / 10.)
      hybrid%gcutm1 = real(NINT(hybrid%gcutm1 * 10  ) / 10.)
      IF (input%film) THEN
       vacuum%dvac = real(NINT(vacuum%dvac*100)/100.)
       dtild = real(NINT(dtild*100)/100.)
      ENDIF
!
! read some lapw input
!
      CALL lapw_input(&
     &                infh,nline,xl_buffer,bfh,buffer,&
     &                input%jspins,input%kcrel,obsolete%ndvgrd,kpts%nkpt,div,kpts%kPointDensity,&
     &                input%frcor,input%ctail,obsolete%chng,input%tria,input%rkmax,stars%gmax,xcpot%gmaxxc,&
     &                vacuum%dvac,dtild,input%tkb,namex,relcor)

      stars%gmaxInit = stars%gmax
!



      nu = 8 

      IF (kpts%nkpt == 0) THEN     ! set some defaults for the k-points
        IF (input%film) THEN
          cell%area = cell%omtil / vacuum%dvac
          kpts%nkpt = MAX(nint((3600/cell%area)/sym%nop2),1)
        ELSE
          kpts%nkpt = MAX(nint((216000/cell%omtil)/sym%nop),1)
        ENDIF
      ENDIF

      kpts%specificationType = 0
      IF((ANY(div(:).NE.0)).AND.(ANY(kpts%kPointDensity(:).NE.0.0))) THEN
         CALL juDFT_error('Double specification of k point set', calledby = 'set_inp')
      END IF
      IF (ANY(div(:).NE.0)) THEN
         kpts%specificationType = 2
      ELSE IF (ANY(kpts%kPointDensity(:).NE.0.0)) THEN
         kpts%specificationType = 4
      ELSE
         kpts%specificationType = 1
      END IF
      l_kpts = .FALSE.

      IF(TRIM(ADJUSTL(sym%namgrp)).EQ.'any') THEN
         sym%symSpecType = 1
      ELSE
         sym%symSpecType = 2
      END IF

      ! set vacuum%nvac
      vacuum%nvac = 2
      IF (sym%zrfs.OR.sym%invs) vacuum%nvac = 1
      IF (oneD%odd%d1) vacuum%nvac = 1
      
      ! Set defaults for noco  types
      ALLOCATE(noco%l_relax(atoms%ntype),noco%b_con(2,atoms%ntype))
      ALLOCATE(noco%alphInit(atoms%ntype),noco%alph(atoms%ntype),noco%beta(atoms%ntype))
   
      IF (noco%l_ss) input%ctail = .FALSE.
      noco%qss = merge(noco%qss,[0.0,0.0,0.0],noco%l_ss)

      noco%l_relax(:) = .FALSE.
      noco%alphInit(:) = 0.0
      noco%alph(:) = 0.0
      noco%beta(:) = 0.0
      noco%b_con(:,:) = 0.0

     
      kpts%nkpt3(:) = div(:)

      IF (kpts%specificationType.EQ.4) THEN
         DO i = 1, 3
            IF (kpts%kPointDensity(i).LE.0.0) THEN
               CALL juDFT_error('Error: Nonpositive kpointDensity provided', calledby = 'set_inp')
            END IF
            recVecLength = SQRT(cell%bmat(i,1)**2 + cell%bmat(i,2)**2 + cell%bmat(i,3)**2)
            kpts%nkpt3(i) = CEILING(kpts%kPointDensity(i) * recVecLength)
         END DO
         kpts%nkpt = kpts%nkpt3(1) * kpts%nkpt3(2) * kpts%nkpt3(3)
      END IF

      IF (l_hyb) THEN
         ! Changes for hybrid functionals
         namex = 'pbe0'
         input%ctail = .false. ; atoms%l_geo = .false.! ; input%frcor = .true.
         input%itmax = 15 ; input%maxiter = 25!; input%imix  = 17
         IF (ANY(kpts%nkpt3(:).EQ.0)) kpts%nkpt3(:) = 4
         div(:) = kpts%nkpt3(:)
         kpts%specificationType = 2
      END IF
latnamTemp = cell%latnam

         l_explicit = juDFT_was_argument("-explicit")

         IF(l_explicit) THEN
            ! kpts generation
         
            CALL kpoints(oneD,sym,cell,input,noco,banddos,kpts,l_kpts)

            kpts%specificationType = 3
            IF (l_hyb) kpts%specificationType = 2
         END IF


         errorStatus = 0
         errorStatus = dropInputSchema()
         IF(errorStatus.NE.0) THEN
            STOP 'Error: Cannot print out FleurInputSchema.xsd'
         END IF




       END SUBROUTINE make_defaults
     END MODULE m_make_defaults
