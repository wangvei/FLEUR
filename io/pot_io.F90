!--------------------------------------------------------------------------------
! Copyright (c) 2017 Peter Grünberg Institut, Forschungszentrum Jülich, Germany
! This file is part of FLEUR and available as free software under the conditions
! of the MIT license as expressed in the LICENSE file in more detail.
!--------------------------------------------------------------------------------

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!
!!! This module is a wrapper for the potential I/O
!!!
!!!                             GM'17
!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

MODULE m_pot_io

   USE m_types
   USE m_juDFT
   USE m_loddop
   USE m_wrtdop
   USE m_cdnpot_io_hdf
   USE m_cdnpot_io_common
#ifdef CPP_HDF
   USE hdf5
#endif
   IMPLICIT NONE

   PRIVATE
   PUBLIC readPotential, writePotential
   PUBLIC POT_ARCHIVE_TYPE_TOT_const, POT_ARCHIVE_TYPE_COUL_const
   PUBLIC POT_ARCHIVE_TYPE_X_const

   INTEGER,          PARAMETER :: POT_ARCHIVE_TYPE_TOT_const = 1
   INTEGER,          PARAMETER :: POT_ARCHIVE_TYPE_COUL_const = 2
   INTEGER,          PARAMETER :: POT_ARCHIVE_TYPE_X_const = 3

   INTEGER,          PARAMETER :: POT_DIRECT_MODE = 1
   INTEGER,          PARAMETER :: POT_STREAM_MODE = 2
   INTEGER,          PARAMETER :: POT_HDF5_MODE   = 3

   CONTAINS

   SUBROUTINE readPotential(stars,noco,vacuum,atoms,sphhar,input,sym,archiveType,&
                            iter,fr,fpw,fz,fzxy)

      TYPE(t_stars),INTENT(IN)  :: stars
      TYPE(t_noco),INTENT(IN)       :: noco
      TYPE(t_vacuum),INTENT(IN) :: vacuum
      TYPE(t_atoms),INTENT(IN)  :: atoms
      TYPE(t_sphhar),INTENT(IN) :: sphhar
      TYPE(t_input),INTENT(IN)  :: input
      TYPE(t_sym),INTENT(IN)    :: sym

      INTEGER, INTENT (OUT)     :: iter
      INTEGER, INTENT (IN)      :: archiveType

      !     ..
      !     .. Array Arguments ..
      COMPLEX, INTENT (OUT) :: fpw(stars%ng3,input%jspins), fzxy(vacuum%nmzxyd,stars%ng2-1,2,input%jspins)
      REAL,    INTENT (OUT) :: fr(atoms%jmtd,0:sphhar%nlhd,atoms%ntype,input%jspins), fz(vacuum%nmzd,2,input%jspins)

      ! local variables
      INTEGER           :: mode, iUnit
      LOGICAL           :: l_exist
      CHARACTER(len=30) :: filename

#ifdef CPP_HDF
      INTEGER(HID_T)    :: fileID
#endif
      INTEGER           :: currentStarsIndex,currentLatharmsIndex
      INTEGER           :: currentStructureIndex,currentStepfunctionIndex
      INTEGER           :: potentialType
      CHARACTER(LEN=30) :: archiveName

      CALL getMode(mode)

      IF(mode.EQ.POT_HDF5_MODE) THEN
#ifdef CPP_HDF
         INQUIRE(FILE='pot.hdf',EXIST=l_exist)
         IF (l_exist) THEN
            CALL openPOT_HDF(fileID,currentStarsIndex,currentLatharmsIndex,&
                             currentStructureIndex,currentStepfunctionIndex)

            archiveName = 'illegalPotentialArchive'
            IF (archiveType.EQ.POT_ARCHIVE_TYPE_TOT_const) THEN
               archiveName = 'pottot'
            END IF
            IF (archiveType.EQ.POT_ARCHIVE_TYPE_COUL_const) THEN
               archiveName = 'potcoul'
            END IF
            IF (archiveType.EQ.POT_ARCHIVE_TYPE_X_const) THEN
               archiveName = 'potx'
            END IF

            potentialType = POTENTIAL_TYPE_IN_const

            l_exist = isPotentialEntryPresentHDF(fileID,archiveName,potentialType)

            CALL closeCDNPOT_HDF(fileID)
         END IF

         IF(l_exist) THEN
            CALL openPOT_HDF(fileID,currentStarsIndex,currentLatharmsIndex,&
                             currentStructureIndex,currentStepfunctionIndex)

            CALL readPotentialHDF(fileID, archiveName, potentialType,&
                                  iter,fr,fpw,fz,fzxy,any(noco%l_unrestrictMT))

            CALL closeCDNPOT_HDF(fileID)
         ELSE
            WRITE(*,*) 'Potential entry or pot.hdf file not found.'
            WRITE(*,*) 'Falling back to stream access file pot.str.'
            mode = POT_STREAM_MODE
         END IF
#else
         WRITE(*,*) 'Not compiled for pot.hdf file usage.'
         WRITE(*,*) 'Falling back to stream access file pot.str.'
         mode = POT_STREAM_MODE
#endif
      END IF

      IF(mode.EQ.POT_STREAM_MODE) THEN
         INQUIRE(FILE='pot.str',EXIST=l_exist)
         IF (l_exist) THEN
            !load density from cdn.str and exit subroutine

            RETURN
         ELSE
            WRITE(*,*) 'pot.str file not found.'
            WRITE(*,*) 'Falling back to direct access file.'
            mode = POT_DIRECT_MODE
         END IF
      END IF

      IF (mode.EQ.POT_DIRECT_MODE) THEN
         filename = 'illegalPotentialArchive'
         IF (archiveType.EQ.POT_ARCHIVE_TYPE_TOT_const) THEN
            filename = 'pottot'
         END IF
         IF (archiveType.EQ.POT_ARCHIVE_TYPE_COUL_const) THEN
            filename = 'potcoul'
         END IF
         IF (archiveType.EQ.POT_ARCHIVE_TYPE_X_const) THEN
            filename = 'potx'
         END IF

         INQUIRE(file=TRIM(ADJUSTL(filename)),EXIST=l_exist)
         IF(.NOT.l_exist) THEN
            CALL juDFT_error("potential file "//TRIM(ADJUSTL(filename))//" missing",calledby ="readPotential")
         END IF

         iUnit = 11
         OPEN (iUnit,file=TRIM(ADJUSTL(filename)),form='unformatted',status='unknown')

         CALL loddop(stars,vacuum,atoms,sphhar,input,sym,&
                     iUnit,iter,fr,fpw,fz,fzxy)

         CLOSE(iUnit)
      END IF

   END SUBROUTINE readPotential

   SUBROUTINE writePotential(stars,noco,vacuum,atoms,cell,sphhar,input,sym ,archiveType,&
                             iter,pot,fpw)

      TYPE(t_stars),INTENT(IN)      :: stars
      TYPE(t_vacuum),INTENT(IN)     :: vacuum
      TYPE(t_atoms),INTENT(IN)      :: atoms
      TYPE(t_cell), INTENT(IN)      :: cell
      TYPE(t_sphhar),INTENT(IN)     :: sphhar
      TYPE(t_input),INTENT(IN)      :: input
      TYPE(t_sym),INTENT(IN)        :: sym
      TYPE(t_noco),INTENT(IN)       :: noco
       
      TYPE(t_potden), INTENT(INOUT) :: pot

      INTEGER, INTENT (IN)      :: iter
      INTEGER, INTENT (IN)      :: archiveType
      !     ..
      !     .. Array Arguments ..
      COMPLEX, INTENT (IN) :: fpw(stars%ng3,input%jspins)

      ! local variables
      INTEGER           :: mode, iUnit
      LOGICAL           :: l_exist, l_storeIndices
      CHARACTER(len=30) :: filename

#ifdef CPP_HDF
      INTEGER(HID_T)    :: fileID
#endif
      INTEGER           :: currentStarsIndex,currentLatharmsIndex
      INTEGER           :: currentStructureIndex,currentStepfunctionIndex
      INTEGER           :: potentialType
      CHARACTER(LEN=30) :: archiveName

      CALL getMode(mode)

      IF(mode.EQ.POT_HDF5_MODE) THEN
#ifdef CPP_HDF
         CALL openPOT_HDF(fileID,currentStarsIndex,currentLatharmsIndex,&
                          currentStructureIndex,currentStepfunctionIndex)

         CALL checkAndWriteMetadataHDF(fileID, input, atoms, cell, vacuum,   stars, sphhar, sym,&
                                       currentStarsIndex,currentLatharmsIndex,currentStructureIndex,&
                                       currentStepfunctionIndex,l_storeIndices,.TRUE.)

         archiveName = 'illegalPotentialArchive'
         IF (archiveType.EQ.POT_ARCHIVE_TYPE_TOT_const) THEN
            archiveName = 'pottot'
         END IF
         IF (archiveType.EQ.POT_ARCHIVE_TYPE_COUL_const) THEN
            archiveName = 'potcoul'
         END IF
         IF (archiveType.EQ.POT_ARCHIVE_TYPE_X_const) THEN
            archiveName = 'potx'
         END IF

         potentialType = POTENTIAL_TYPE_IN_const

         IF(vacuum%nvac.EQ.1) THEN
            pot%vacz(:,2,:) = pot%vacz(:,1,:)
            IF (sym%invs) THEN
               pot%vacxy(:,:,2,:) = CONJG(pot%vacxy(:,:,1,:))
            ELSE
               pot%vacxy(:,:,2,:) = pot%vacxy(:,:,1,:)
            END IF
         END IF
         CALL writePotentialHDF(input, fileID, archiveName, potentialType,&
                                currentStarsIndex, currentLatharmsIndex, currentStructureIndex,&
                                currentStepfunctionIndex,iter,pot,fpw,any(noco%l_unrestrictMT))

         IF(l_storeIndices) THEN
            CALL writePOTHeaderData(fileID,currentStarsIndex,currentLatharmsIndex,&
                                    currentStructureIndex,currentStepfunctionIndex)
         END IF

         CALL closeCDNPOT_HDF(fileID)
#endif
      ELSE IF(mode.EQ.POT_STREAM_MODE) THEN
         ! Write potential to pot.str file
         STOP 'POT_STREAM_MODE not yet implemented!'
      ELSE
         ! Direct mode
         filename = 'illegalPotentialArchive'
         IF (archiveType.EQ.POT_ARCHIVE_TYPE_TOT_const) THEN
            filename = 'pottot'
         END IF
         IF (archiveType.EQ.POT_ARCHIVE_TYPE_COUL_const) THEN
            filename = 'potcoul'
         END IF
         IF (archiveType.EQ.POT_ARCHIVE_TYPE_X_const) THEN
            filename = 'potx'
         END IF

         iUnit = 11
         OPEN (iUnit,file=TRIM(ADJUSTL(filename)),form='unformatted',status='unknown')
         CALL wrtdop(stars,vacuum,atoms,sphhar,input,sym,&
                     iUnit,iter,pot%mt,fpw,pot%vacz(:,:,:input%jspins),pot%vacxy(:,:,:,:input%jspins))
         CLOSE(iUnit)
      END IF

   END SUBROUTINE writePotential

   SUBROUTINE getMode(mode)
      INTEGER, INTENT(OUT) :: mode

      mode = POT_DIRECT_MODE
      !IF (juDFT_was_argument("-stream_cdn")) mode=POT_STREAM_MODE
      IF (.NOT.juDFT_was_argument("-no_cdn_hdf")) THEN !juDFT_was_argument("-hdf_cdn")) THEN
#ifdef CPP_HDF
         mode=POT_HDF5_MODE
#else
!         WRITE(*,*) 'Code not compiled with HDF5 support.'
!         WRITE(*,*) 'Falling back to direct access.'
#endif
      END IF
   END SUBROUTINE getMode

END MODULE m_pot_io
