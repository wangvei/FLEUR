!--------------------------------------------------------------------------------
! Copyright (c) 2016 Peter Grünberg Institut, Forschungszentrum Jülich, Germany
! This file is part of FLEUR and available as free software under the conditions
! of the MIT license as expressed in the LICENSE file in more detail.
!--------------------------------------------------------------------------------

MODULE m_xmlOutput
  USE m_judft_xmlOutput !most functionality is actually there
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!
!!!   XML output service routines
!!!
!!!   This module provides several subroutines that simplify the
!!!   generation of the out.xml file.
!!!                                         GM'16
!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

   IMPLICIT NONE
 
   CONTAINS

   SUBROUTINE startfleur_XMLOutput(filename_add)
     USE m_judft_xmloutput
      USE m_juDFT_args
      USE m_juDFT_usage
      USE m_constants
      USE m_utility
      USE m_compile_descr
#ifdef CPP_MPI
      use mpi
#endif
!$    use omp_lib
      
      IMPLICIT NONE

      CHARACTER(len=100), INTENT(IN) :: filename_add

      INTEGER           :: err, isize
      INTEGER           :: numFlags
      INTEGER           :: nOMPThreads
      CHARACTER(LEN=8)  :: date
      CHARACTER(LEN=10) :: time
      CHARACTER(LEN=10) :: zone
      CHARACTER(LEN=10) :: dateString
      CHARACTER(LEN=10) :: timeString
      CHARACTER(LEN=6)  :: precisionString
      CHARACTER(LEN=9)  :: flags(11)
      CHARACTER(LEN=20) :: structureSpecifiers(11)
      CHARACTER(:), ALLOCATABLE :: gitdesc,githash,gitbranch,compile_date,compile_user,compile_host
      CHARACTER(:), ALLOCATABLE :: compile_flags,link_flags
      CHARACTER(LEN=1000) :: gitdescTemp,githashTemp,gitbranchTemp,compile_dateTemp,compile_userTemp,compile_hostTemp
      CHARACTER(LEN=1000) :: compile_flagsTemp,link_flagsTemp,line
      CHARACTER(LEN=20) :: attributes(7)
      
      CALL startxmloutput(TRIM(filename_add)//"out.xml","fleurOutput")
      CALL openXMLElement('programVersion',(/'version'/),(/version_const/))
      CALL get_compile_desc(gitdesc,githash,gitbranch,compile_date,compile_user,compile_host,compile_flags,link_flags)
      gitdescTemp = gitdesc
      githashTemp = githash
      CALL add_usage_data("githash", githash)
      gitbranchTemp = gitbranch
      compile_dateTemp = compile_date
      compile_userTemp = compile_user
      compile_hostTemp = compile_host
      compile_flagsTemp = compile_flags
      link_flagsTemp = link_flags
      CALL writeXMLElement('compilationInfo',(/'date','user','host','flag','link'/),(/compile_dateTemp,compile_userTemp,compile_hostTemp,compile_flagsTemp,link_flagsTemp/))
      CALL writeXMLElement('gitInfo',(/'version       ','branch        ','lastCommitHash'/),(/gitdescTemp,gitbranchTemp,githashTemp/))
      CALL getComputerArchitectures(flags, numFlags)
      IF (numFlags.EQ.0) THEN
         numFlags = 1
         flags(numFlags) = 'GEN'
      END IF
      CALL writeXMLElementNoAttributes('targetComputerArchitectures',flags(1:numFlags))
      IF (numFlags.GT.1) THEN 
         STOP "ERROR: Define only one system architecture! (called by xmlOutput)"
      END IF
      CALL getPrecision(precisionString)
      CALL writeXMLElement('precision',(/'type'/),(/precisionString/))
      CALL getTargetStructureProperties(structureSpecifiers, numFlags)
      CALL writeXMLElementNoAttributes('targetStructureClass',structureSpecifiers(1:numFlags))
      CALL getAdditionalCompilationFlags(flags, numFlags)
      IF (numFlags.GE.1) THEN
         CALL writeXMLElementNoAttributes('additionalCompilerFlags',flags(1:numFlags))
      END IF
      CALL closeXMLElement('programVersion')

      CALL openXMLElementNoAttributes('parallelSetup')
      nOMPThreads = -1
      !$ nOMPThreads=omp_get_max_threads()
      IF(nOMPThreads.NE.-1) THEN
         WRITE(attributes(1),'(i0)') nOMPThreads
         CALL writeXMLElementFormPoly('openMP',(/'ompThreads'/),&
                                      attributes(:1),reshape((/10,8/),(/1,2/)))
      END IF

#ifdef CPP_MPI
      CALL MPI_COMM_SIZE(MPI_COMM_WORLD,isize,err)
      WRITE(attributes(1),'(i0)') isize
      CALL writeXMLElementFormPoly('mpi',(/'mpiProcesses'/),&
                                   attributes(:1),reshape((/13,8/),(/1,2/)))
#endif

      line="MemTotal: unknown"
      OPEN(544,FILE="/proc/meminfo",status='old',action='read',iostat=err)
      IF (err==0) THEN
         DO
            READ(544,'(a)',iostat=err) line
            IF (err.NE.0) EXIT
            IF (INDEX(line,"MemTotal:")>0) EXIT
         ENDDO
         CLOSE(544)
      END IF
      IF (INDEX(line,"MemTotal:")>0) THEN
         attributes(1)=ADJUSTL(TRIM(line(10:)))
         CALL writeXMLElementFormPoly('mem',(/'memoryPerNode'/),&
                                   attributes(:1),reshape((/14,15/),(/1,2/)))
      ENDIF

      CALL closeXMLElement('parallelSetup')
      
      CALL DATE_AND_TIME(date,time,zone)
      WRITE(dateString,'(a4,a1,a2,a1,a2)') date(1:4),'/',date(5:6),'/',date(7:8)
      WRITE(timeString,'(a2,a1,a2,a1,a2)') time(1:2),':',time(3:4),':',time(5:6)
      CALL writeXMLElement('startDateAndTime',(/'date','time','zone'/),(/dateString,timeString,zone/))
    END SUBROUTINE startfleur_XMLOutput

END MODULE m_xmlOutput
