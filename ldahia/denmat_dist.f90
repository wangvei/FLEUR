MODULE m_denmat_dist

   USE m_types
   USE m_constants

   IMPLICIT NONE

   CONTAINS
   SUBROUTINE n_mmp_dist(n_mmp_in,n_mmp_out,input,gfinp,results)

      TYPE(t_input),       INTENT(IN)     :: input
      TYPE(t_gfinp),       INTENT(IN)     :: gfinp
      COMPLEX,             INTENT(IN)     :: n_mmp_in(-lmaxU_const:,-lmaxU_const:,:)
      COMPLEX,             INTENT(IN)     :: n_mmp_out(-lmaxU_const:,-lmaxU_const:,:)
      TYPE(t_results),     INTENT(INOUT)  :: results

      INTEGER ispin,j,k
      REAL n_in,n_out

      !Calculates the distance for two density matrices (maximum distance between two elements)
      n_out = 0.0
      n_in = 0.0
      DO ispin = 1, MERGE(3,input%jspins,gfinp%l_mperp)
         DO j = -3,3
            DO k = -3,3
               IF((ABS(n_mmp_out(k,j,ispin) - n_mmp_in(k,j,ispin))).GT.results%last_mmpMatdistance) THEN
                  results%last_mmpMatdistance = ABS(n_mmp_out(k,j,ispin) - n_mmp_in(k,j,ispin))
               ENDIF
               IF(j.EQ.k.AND.ispin<3) THEN
                  n_out = n_out + REAL(n_mmp_out(k,k,ispin))
                  n_in = n_in + REAL(n_mmp_in(k,k,ispin))
               ENDIF
            END DO
         END DO
      ENDDO
      results%last_occdistance = results%last_occdistance + ABS(n_out-n_in)
      WRITE(oUnit,*) "Occupation distance: ", results%last_occdistance
      WRITE(oUnit,*) "Density matrix distance: ", results%last_mmpMatdistance

   END SUBROUTINE n_mmp_dist
END MODULE m_denmat_dist
