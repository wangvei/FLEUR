!--------------------------------------------------------------------------------
! Copyright (c) 2016 Peter Grünberg Institut, Forschungszentrum Jülich, Germany
! This file is part of FLEUR and available as free software under the conditions
! of the MIT license as expressed in the LICENSE file in more detail.
!--------------------------------------------------------------------------------

MODULE m_types_noco
  use m_judft
  IMPLICIT NONE
  PRIVATE
 TYPE t_noco
    LOGICAL:: l_ss= .FALSE.
    LOGICAL:: l_soc= .FALSE.
    LOGICAL:: l_noco = .FALSE.
    LOGICAL:: l_mperp = .FALSE.
    LOGICAL:: l_constr = .FALSE.
    LOGICAL:: l_mtNocoPot = .FALSE.
    REAL   :: qss(3)=[0.,0.,0.]
    REAL   :: mix_b=0.0
    LOGICAL:: l_spav= .FALSE.
    REAL   :: theta=0.0
    REAL   :: phi=0.0
    
    LOGICAL, ALLOCATABLE :: l_relax(:)
    REAL, ALLOCATABLE    :: alphInit(:)
    REAL, ALLOCATABLE    :: alph(:)
    REAL, ALLOCATABLE    :: beta(:)
    REAL, ALLOCATABLE    :: b_con(:, :)
    REAL, ALLOCATABLE    :: socscale(:)

  CONTAINS
    PROCEDURE :: read_xml=>read_xml_noco
   END TYPE t_noco

   public t_noco

 CONTAINS
   SUBROUTINE read_xml_noco(noco,xml)
     USE m_types_xml
     CLASS(t_noco),INTENT(out):: noco
     TYPE(t_xml),INTENT(IN)   :: xml
     
     INTEGER:: numberNodes,ntype,itype
     CHARACTER(len=100)::xpathA,xpathB,valueString

      noco%l_noco = evaluateFirstBoolOnly(xml%GetAttributeValue('/fleurInput/calculationSetup/magnetism/@l_noco'))
   
      ! Read in optional SOC parameters if present
      xPathA = '/fleurInput/calculationSetup/soc'
      numberNodes = xml%GetNumberOfNodes(xPathA)
      IF (numberNodes.EQ.1) THEN
         noco%theta=evaluateFirstOnly(xml%GetAttributeValue(TRIM(ADJUSTL(xPathA))//'/@theta'))
         noco%phi=evaluateFirstOnly(xml%GetAttributeValue(TRIM(ADJUSTL(xPathA))//'/@phi'))
         noco%l_soc = evaluateFirstBoolOnly(xml%GetAttributeValue(TRIM(ADJUSTL(xPathA))//'/@l_soc'))
         noco%l_spav = evaluateFirstBoolOnly(xml%GetAttributeValue(TRIM(ADJUSTL(xPathA))//'/@spav'))
      END IF

      ! Read in optional noco parameters if present
      xPathA = '/fleurInput/calculationSetup/nocoParams'
      numberNodes = xml%GetNumberOfNodes(xPathA)
      IF ((noco%l_noco).AND.(numberNodes.EQ.0)) THEN
         CALL juDFT_error('Error: l_noco is true but no noco parameters set in xml input file!')
      END IF

      IF (numberNodes.EQ.1) THEN
         noco%l_ss = evaluateFirstBoolOnly(xml%GetAttributeValue(TRIM(ADJUSTL(xPathA))//'/@l_ss'))
         noco%l_mperp = evaluateFirstBoolOnly(xml%GetAttributeValue(TRIM(ADJUSTL(xPathA))//'/@l_mperp'))
         noco%l_constr = evaluateFirstBoolOnly(xml%GetAttributeValue(TRIM(ADJUSTL(xPathA))//'/@l_constr'))
         noco%l_mtNocoPot = evaluateFirstBoolOnly(xml%GetAttributeValue(TRIM(ADJUSTL(xPathA))//'/@l_mtNocoPot'))
         noco%mix_b = evaluateFirstOnly(xml%GetAttributeValue(TRIM(ADJUSTL(xPathA))//'/@mix_b'))
         valueString = TRIM(ADJUSTL(xml%GetAttributeValue(TRIM(ADJUSTL(xPathA))//'/qss')))
         READ(valueString,*) noco%qss(1), noco%qss(2), noco%qss(3)
      END IF

      ntype=xml%GetNumberOfNodes('/fleurInput/atomGroups/atomGroup')
      ALLOCATE(noco%l_relax(ntype),noco%b_con(2,ntype))
      ALLOCATE(noco%alphInit(ntype),noco%alph(ntype),noco%beta(ntype))
      ALLOCATE(noco%socscale(ntype))

      DO itype=1,ntype
         noco%socscale(iType)=evaluateFirstOnly(xml%GetAttributeValue(TRIM(ADJUSTL(xml%speciesPath(itype)))//'/special/@socscale'))
         !Read in atom group specific noco parameters
         xPathB = TRIM(ADJUSTL(xml%groupPath(itype)))//'/nocoParams'
         numberNodes = xml%GetNumberOfNodes(TRIM(ADJUSTL(xPathB)))
         IF (numberNodes.GE.1) THEN
            noco%l_relax(iType) = evaluateFirstBoolOnly(xml%GetAttributeValue(TRIM(ADJUSTL(xPathB))//'/@l_relax'))
            noco%alphInit(iType) = evaluateFirstOnly(xml%GetAttributeValue(TRIM(ADJUSTL(xPathB))//'/@alpha'))
            noco%alph(iType) = noco%alphInit(iType)
            noco%beta(iType) = evaluateFirstOnly(xml%GetAttributeValue(TRIM(ADJUSTL(xPathB))//'/@beta'))
            noco%b_con(1,iType) = evaluateFirstOnly(xml%GetAttributeValue(TRIM(ADJUSTL(xPathB))//'/@b_cons_x'))
            noco%b_con(2,iType) = evaluateFirstOnly(xml%GetAttributeValue(TRIM(ADJUSTL(xPathB))//'/@b_cons_y'))
         END IF
      ENDDO
    END SUBROUTINE read_xml_noco
 END MODULE m_types_noco
