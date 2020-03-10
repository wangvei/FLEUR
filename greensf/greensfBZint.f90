MODULE m_greensfBZint

   USE m_types
   USE m_juDFT
   USE m_constants
   USE m_greensfSpinDiag
   USE m_greensfSpinOffDiag

   IMPLICIT NONE

   CONTAINS

   SUBROUTINE greensfBZint(ikpt_i,ikpt,nBands,ev_list,jspin,l_mperp,&
                           gfinp,sym,atoms,kpts,usdus,denCoeffsOffDiag,eigVecCoeffs,greensfBZintCoeffs)

      INTEGER,                   INTENT(IN)     :: ikpt_i,ikpt        !current k-point index in cdnvaljob%k_list and current k-point
      INTEGER,                   INTENT(IN)     :: nBands, ev_list(:) !Bands handled on this rank
      INTEGER,                   INTENT(IN)     :: jspin              !spin index
      LOGICAL,                   INTENT(IN)     :: l_mperp
      TYPE(t_gfinp),             INTENT(IN)     :: gfinp
      TYPE(t_sym),               INTENT(IN)     :: sym
      TYPE(t_atoms),             INTENT(IN)     :: atoms
      TYPE(t_kpts),              INTENT(IN)     :: kpts
      TYPE(t_usdus),             INTENT(IN)     :: usdus
      TYPE(t_denCoeffsOffDiag),  INTENT(IN)     :: denCoeffsOffdiag
      TYPE(t_eigVecCoeffs),      INTENT(IN)     :: eigVecCoeffs
      TYPE(t_greensfBZintCoeffs),INTENT(INOUT)  :: greensfBZintCoeffs

      INTEGER :: i_gf,l,lp,atomType,atomTypep,natom,natomp,natomp_start,natomp_end
      INTEGER :: spin1,spin2
      COMPLEX :: phase

      IF(l_mperp) THEN
         spin1 = 2
         spin2 = 1
      ELSE
         spin1 = jspin
         spin2 = jspin
      ENDIF

      !$OMP PARALLEL DEFAULT(NONE) &
      !$OMP SHARED(gfinp,atoms,sym,kpts,ev_list,usdus,denCoeffsOffdiag,eigVecCoeffs,greensfBZintCoeffs) &
      !$OMP SHARED(ikpt_i,ikpt,nBands,spin1,spin2) &
      !$OMP PRIVATE(i_gf,l,lp,atomType,atomTypep,natom,natomp,natomp_start,natomp_end,phase)
      !$OMP DO
      DO i_gf = 1, gfinp%n

         !Get the information about the current element
         l  = gfinp%elem(i_gf)%l
         lp = gfinp%elem(i_gf)%lp
         atomType  = gfinp%elem(i_gf)%atomType
         atomTypep = gfinp%elem(i_gf)%atomTypep

         IF(l.NE.lp) CALL juDFT_error("l-offdiagonal elements not implemented",calledby="greensfBZint")
         IF(atomType.NE.atomTypep) CALL juDFT_error("intersite elements not implemented",calledby="greensfBZint")

         !Loop over equivalent atoms
         DO natom = SUM(atoms%neq(:atomType-1)) + 1, SUM(atoms%neq(:atomType))

            !Only perform the second atom loop if we calculate intersite elements
            natomp_start = MERGE(natom,SUM(atoms%neq(:atomType-1)) + 1,atomType==atomTypep)
            natomp_end   = MERGE(natom,SUM(atoms%neq(:atomTypep))     ,atomType==atomTypep)

            DO natomp = natomp_start, natomp_end

               !Phase factor for intersite elements (Does nothing atm)
               IF(natom.NE.natomp) THEN
                  IF(sym%nop>1) CALL juDFT_error("Symmetries and intersite Green's Function not implemented",calledby="greensfBZint")
                  IF(gfinp%l_sphavg) CALL juDFT_error("Spherical average and intersite Green's Function not implemented",calledby="greensfBZint")
                  phase = exp(ImagUnit*dot_product(kpts%bk(:,ikpt),atoms%taual(:,natom)-atoms%taual(:,natomp)))
               ELSE
                  phase = 1.0
               ENDIF

               !which scalar products for intersite (IF l_sphavg)
               !Can these be unified ?
               !Spin diagonal elements
               CALL greensfSpinDiag(ikpt_i,nBands,ev_list,i_gf,l,lp,natom,natomp,atomType,atomTypep,spin1,&
                                    gfinp%l_sphavg,sym,atoms,usdus,eigVecCoeffs,greensfBZintCoeffs)
               IF(spin1/=spin2) THEN
                  !Spin offdiagonal elements
                  CALL greensfSpinOffDiag(ikpt_i,nBands,ev_list,i_gf,l,lp,natom,natomp,atomType,atomTypep,spin1,spin2,&
                                          gfinp%l_sphavg,sym,atoms,denCoeffsOffdiag,eigVecCoeffs,greensfBZintCoeffs)
               ENDIF

            ENDDO !natomp
         ENDDO !natom

      ENDDO !i_gf
      !$OMP END DO
      !$OMP END PARALLEL


   END SUBROUTINE greensfBZint

END MODULE m_greensfBZint