!--------------------------------------------------------------------------------
! Copyright (c) 2017 Peter Grünberg Institut, Forschungszentrum Jülich, Germany
! This file is part of FLEUR and available as free software under the conditions
! of the MIT license as expressed in the LICENSE file in more detail.
!--------------------------------------------------------------------------------

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!
!!! This module contains common subroutines required for density IO
!!! as well as for potential IO
!!!
!!!                             GM'17
!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

MODULE m_cdnpot_io_common


   USE m_juDFT
   USE m_cdnpot_io_hdf
#ifdef CPP_HDF
   USE hdf5
#endif

   IMPLICIT NONE

   CONTAINS

   SUBROUTINE compareStars(stars, refStars,   l_same)
      use m_types_stars
       

      TYPE(t_stars),INTENT(IN)  :: stars
      TYPE(t_stars),INTENT(IN)  :: refStars
       
       

      LOGICAL,      INTENT(OUT) :: l_same

      l_same = .TRUE.

      !IF(ABS(stars%gmaxInit-refStars%gmaxInit).GT.1e-10) l_same = .FALSE.
      IF(stars%ng3.NE.refStars%ng3) l_same = .FALSE.
      IF(stars%ng2.NE.refStars%ng2) l_same = .FALSE.
      IF(stars%mx1.NE.refStars%mx1) l_same = .FALSE.
      IF(stars%mx2.NE.refStars%mx2) l_same = .FALSE.
      IF(stars%mx3.NE.refStars%mx3) l_same = .FALSE.
     
   END SUBROUTINE compareStars

   SUBROUTINE compareStepfunctions(stars, refStars, l_same)
      use m_types_stars
      TYPE(t_stars),INTENT(IN)  :: stars
      TYPE(t_stars),INTENT(IN)  :: refStars

      LOGICAL,      INTENT(OUT) :: l_same

      l_same = .TRUE.

      IF(stars%ng3.NE.refStars%ng3) l_same = .FALSE.
      IF(stars%mx1.NE.refStars%mx1) l_same = .FALSE.
      IF(stars%mx2.NE.refStars%mx2) l_same = .FALSE.
      IF(stars%mx3.NE.refStars%mx3) l_same = .FALSE.

   END SUBROUTINE compareStepfunctions

   SUBROUTINE compareStructure(input, atoms, vacuum, cell, sym, refInput, refAtoms, refVacuum,&
                               refCell, refSym, l_same,l_shift_only)
      use m_types_input
      use m_types_atoms
      use m_types_vacuum
      use m_types_cell
      use m_types_sym


      TYPE(t_input),INTENT(IN)  :: input, refInput
      TYPE(t_atoms),INTENT(IN)  :: atoms, refAtoms
      TYPE(t_vacuum),INTENT(IN) :: vacuum, refVacuum
      TYPE(t_cell),INTENT(IN)   :: cell, refCell
      TYPE(t_sym),INTENT(IN)    :: sym, refSym

      LOGICAL,      INTENT(OUT) :: l_same
      LOGICAL,OPTIONAL,INTENT(OUT) ::l_shift_only

      INTEGER                   :: i

      l_same = .TRUE.


      IF(atoms%ntype.NE.refAtoms%ntype) l_same = .FALSE.
      IF(atoms%nat.NE.refAtoms%nat) l_same = .FALSE.
      IF(atoms%lmaxd.NE.refAtoms%lmaxd) l_same = .FALSE.
      IF(atoms%jmtd.NE.refAtoms%jmtd) l_same = .FALSE.
      IF(atoms%n_u.NE.refAtoms%n_u) l_same = .FALSE.
      IF(atoms%n_hia.NE.refAtoms%n_hia) l_same = .FALSE.
      IF(atoms%n_opc.NE.refAtoms%n_opc) l_same = .FALSE.
      IF(input%ldauSpinoffd.NEQV.refInput%ldauSpinoffd) l_same = .FALSE.
      IF(vacuum%dvac.NE.refVacuum%dvac) l_same = .FALSE.
      IF(sym%nop.NE.refSym%nop) l_same = .FALSE.
      IF(sym%nop2.NE.refSym%nop2) l_same = .FALSE.

      IF(atoms%n_u.EQ.refAtoms%n_u.AND.atoms%n_hia.EQ.refAtoms%n_hia) THEN
         DO i = 1, atoms%n_u+atoms%n_hia
            IF (atoms%lda_u(i)%atomType.NE.refAtoms%lda_u(i)%atomType) l_same = .FALSE.
            IF (atoms%lda_u(i)%l.NE.refAtoms%lda_u(i)%l) l_same = .FALSE.
         END DO
      END IF

      IF(atoms%n_opc.EQ.refAtoms%n_opc) THEN
         DO i = 1, atoms%n_opc
            IF (atoms%lda_opc(i)%atomType.NE.refAtoms%lda_opc(i)%atomType) l_same = .FALSE.
            IF (atoms%lda_opc(i)%l.NE.refAtoms%lda_opc(i)%l) l_same = .FALSE.
            IF (atoms%lda_opc(i)%n.NE.refAtoms%lda_opc(i)%n) l_same = .FALSE.
         END DO
      END IF

      IF(ANY(ABS(cell%amat(:,:)-refCell%amat(:,:)).GT.1e-10)) l_same = .FALSE.
      IF(l_same) THEN
         IF(ANY(atoms%nz(:).NE.refAtoms%nz(:))) l_same = .FALSE.
         IF(ANY(sym%mrot(:,:,:sym%nop).NE.refSym%mrot(:,:,:sym%nop))) l_same = .FALSE.
         IF(ANY(ABS(sym%tau(:,:sym%nop)-refSym%tau(:,:sym%nop)).GT.1e-10)) l_same = .FALSE.
      END IF

      IF (PRESENT(l_shift_only)) l_shift_only=l_same
      !Now the positions are checked...
      IF(l_same) THEN
         DO i = 1, atoms%nat
            IF(ANY(ABS(atoms%pos(:,i)-refAtoms%pos(:,i)).GT.1e-10)) l_same = .FALSE.
         END DO
         IF(ANY(ABS(atoms%rmt(:atoms%ntype)-refAtoms%rmt(:atoms%ntype)).GT.1e-10)) l_same = .FALSE.
      END IF

      ! NOTE: This subroutine certainly is not yet complete. Especially symmetry should
      !       also be stored and compared for structure considerations.

   END SUBROUTINE compareStructure

   SUBROUTINE compareLatharms(latharms, refLatharms, l_same)
      use m_types_sphhar
      TYPE(t_sphhar)       :: latharms, refLatharms

      LOGICAL,      INTENT(OUT) :: l_same

      l_same = .TRUE.

      IF(latharms%ntypsd.NE.refLatharms%ntypsd) l_same = .FALSE.
      IF(latharms%memd.NE.refLatharms%memd) l_same = .FALSE.
      IF(latharms%nlhd.NE.refLatharms%nlhd) l_same = .FALSE.

   END SUBROUTINE compareLatharms

#ifdef CPP_HDF
   SUBROUTINE checkAndWriteMetadataHDF(fileID, input, atoms, cell, vacuum,   stars, latharms, sym,&
                                       currentStarsIndex,currentLatharmsIndex,currentStructureIndex,&
                                       currentStepfunctionIndex,l_storeIndices,l_CheckBroyd)
      use m_types_atoms
      use m_types_input
      use m_types_cell
      use m_types_vacuum
       
      use m_types_stars
      use m_types_sphhar
      use m_types_sym

      TYPE(t_input),INTENT(IN)  :: input
      TYPE(t_atoms),INTENT(IN)  :: atoms
      TYPE(t_cell), INTENT(IN)  :: cell
      TYPE(t_vacuum),INTENT(IN) :: vacuum
       
      TYPE(t_stars),INTENT(IN)  :: stars
      TYPE(t_sphhar),INTENT(IN) :: latharms
      TYPE(t_sym),INTENT(IN)    :: sym

      INTEGER(HID_T), INTENT(IN) :: fileID
      INTEGER, INTENT(INOUT)     :: currentStarsIndex,currentLatharmsIndex
      INTEGER, INTENT(INOUT)     :: currentStructureIndex,currentStepfunctionIndex
      LOGICAL, INTENT(IN)        :: l_CheckBroyd
      LOGICAL, INTENT(OUT)       :: l_storeIndices

      TYPE(t_stars)        :: starsTemp
      TYPE(t_vacuum)       :: vacuumTemp
      TYPE(t_atoms)        :: atomsTemp
      TYPE(t_sphhar)       :: latharmsTemp
      TYPE(t_input)        :: inputTemp
      TYPE(t_cell)         :: cellTemp
       
      TYPE(t_sym)          :: symTemp

      INTEGER                    :: starsIndexTemp, structureIndexTemp
      LOGICAL                    :: l_same, l_writeAll, l_exist

      l_storeIndices = .FALSE.
      l_writeAll = .FALSE.

      IF(currentStructureIndex.EQ.0) THEN
         currentStructureIndex = 1
         l_storeIndices = .TRUE.
         CALL writeStructureHDF(fileID, input, atoms, cell, vacuum,   sym,currentStructureIndex,l_CheckBroyd)
      ELSE
         CALL readStructureHDF(fileID, inputTemp, atomsTemp, cellTemp, vacuumTemp,  symTemp, currentStructureIndex)
         CALL compareStructure(input, atoms, vacuum, cell, sym, inputTemp, atomsTemp, vacuumTemp, cellTemp, symTemp, l_same)

         IF(.NOT.l_same) THEN
            currentStructureIndex = currentStructureIndex + 1
            l_storeIndices = .TRUE.
            l_writeAll = .TRUE.
            CALL writeStructureHDF(fileID, input, atoms, cell, vacuum,   sym, currentStructureIndex,l_CheckBroyd)
         END IF
      END IF
      IF (currentStarsIndex.EQ.0) THEN
         currentStarsIndex = 1
         l_storeIndices = .TRUE.
         CALL writeStarsHDF(fileID, currentStarsIndex, currentStructureIndex, stars,   l_CheckBroyd)
      ELSE
         CALL peekStarsHDF(fileID, currentStarsIndex, structureIndexTemp)
         l_same = structureIndexTemp.EQ.currentStructureIndex
         IF(l_same) THEN
            CALL readStarsHDF(fileID, currentStarsIndex, starsTemp)
            CALL compareStars(stars, starsTemp, l_same)
         END IF
         IF((.NOT.l_same).OR.l_writeAll) THEN
            currentStarsIndex = currentStarsIndex + 1
            l_storeIndices = .TRUE.
            CALL writeStarsHDF(fileID, currentStarsIndex, currentStructureIndex, stars,   l_CheckBroyd)
         END IF
      END IF
      IF (currentLatharmsIndex.EQ.0) THEN
         currentLatharmsIndex = 1
         l_storeIndices = .TRUE.
         CALL writeLatharmsHDF(fileID, currentLatharmsIndex, currentStructureIndex, latharms,l_checkBroyd)
      ELSE
         CALL peekLatharmsHDF(fileID, currentLatharmsIndex, structureIndexTemp)
         l_same = structureIndexTemp.EQ.currentStructureIndex
         IF(l_same) THEN
            CALL readLatharmsHDF(fileID, currentLatharmsIndex, latharmsTemp)
            CALL compareLatharms(latharms, latharmsTemp, l_same)
         END IF
         IF((.NOT.l_same).OR.l_writeAll) THEN
            currentLatharmsIndex = currentLatharmsIndex + 1
            l_storeIndices = .TRUE.
            CALL writeLatharmsHDF(fileID, currentLatharmsIndex, currentStructureIndex, latharms,l_CheckBroyd)
         END IF
      END IF
      IF(currentStepfunctionIndex.EQ.0) THEN
         IF (judft_was_argument("-storeSF")) THEN
            currentStepfunctionIndex = 1
            l_storeIndices = .TRUE.
            CALL writeStepfunctionHDF(fileID, currentStepfunctionIndex, currentStarsIndex,&
                                      currentStructureIndex, stars,l_CheckBroyd)
         END IF
      ELSE
         CALL peekStepfunctionHDF(fileID, currentStepfunctionIndex, starsIndexTemp, structureIndexTemp)
         l_same = (starsIndexTemp.EQ.currentStarsIndex).AND.(structureIndexTemp.EQ.currentStructureIndex)
         IF(l_same) THEN
            CALL readStepfunctionHDF(fileID, currentStepfunctionIndex, starsTemp)
            CALL compareStepfunctions(stars, starsTemp, l_same)
         END IF
         IF((.NOT.l_same).OR.l_writeAll) THEN
            l_storeIndices = .TRUE.
! I comment out the IF condition. At the moment the logic is if there already is a stepfunction stored, we store more.
!            IF (judft_was_argument("-storeSF")) THEN
               currentStepfunctionIndex = currentStepfunctionIndex + 1
               CALL writeStepfunctionHDF(fileID, currentStepfunctionIndex, currentStarsIndex,&
                                         currentStructureIndex, stars,l_CheckBroyd)
!            ELSE
!               currentStepfunctionIndex = 0 ! This is not safe, because one might resume to storing stepfunctions which would result in using index 1 twice.
!            END IF
         END IF
      END IF

   END SUBROUTINE checkAndWriteMetadataHDF
#endif


END MODULE m_cdnpot_io_common
