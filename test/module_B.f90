MODULE B
!
!
IMPLICIT NONE

PRIVATE

PUBLIC :: construct, destruct
PUBLIC :: transfer
PUBLIC :: allocate_int_state

INTERFACE xfer_var_B
  MODULE PROCEDURE xfer_var_r2_B
  MODULE PROCEDURE xfer_var_r3_B
  MODULE PROCEDURE xfer_var_r4_B
  MODULE PROCEDURE xfer_var_i2_B
END INTERFACE

INTERFACE xfer_idx_B
  MODULE PROCEDURE xfer_idx_2_B
  MODULE PROCEDURE xfer_idx_3_B
END INTERFACE


CONTAINS

!-------------------------------------------------------------------------
!
!
SUBROUTINE allocate_int_state_B()
!

END SUBROUTINE allocate_int_state_B


SUBROUTINE construct_B()
!
  !-----------------------------------------------------------------------

DO jg = 1,n


  CALL allocate_int_state_B( )

  !
  CALL scalar_int_coeff_B()

ENDDO

END SUBROUTINE construct_B

!-------------------------------------------------------------------------
!

SUBROUTINE xfer_var_r2_B()

END SUBROUTINE xfer_var_r2_B

!-------------------------------------------------------------------------

SUBROUTINE xfer_var_r3_B()

END SUBROUTINE xfer_var_r3_B

!-------------------------------------------------------------------------

SUBROUTINE xfer_var_r4_B()

END SUBROUTINE xfer_var_r4_B
!-------------------------------------------------------------------------

SUBROUTINE xfer_var_i2_B()

  CALL xfer_var_r2_B()

END SUBROUTINE xfer_var_i2_B

!-------------------------------------------------------------------------
!

SUBROUTINE xfer_idx_2_B()


  CALL xfer_var_r2_B()


END SUBROUTINE xfer_idx_2_B

!-------------------------------------------------------------------------

SUBROUTINE xfer_idx_3_B()

  IF_B(a==1 .and. s==2) THEN
    DO j = 1, UBOUND_B(idxi,3)
      CALL xfer_idx_2_B()
    ENDDO
  ENDIF

END SUBROUTINE xfer_idx_3_B

!-------------------------------------------------------------------------
SUBROUTINE transfer_B()
!

  CALL allocate_int_state_B(p)
  CALL xfer_var_B()

!  ENDIF
  CALL xfer_idx_B()
END SUBROUTINE transfer_interpol_state_B
!-------------------------------------------------------------------------
END MODULE B
MODULE C

END MODULE C
