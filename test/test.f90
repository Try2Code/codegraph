MODULE A

USE B
USE C
!
IMPLICIT NONE

PRIVATE

PUBLIC :: construct, destruct
PUBLIC :: transfer
PUBLIC :: allocate_int_state

INTERFACE xfer_var
  MODULE PROCEDURE xfer_var_r2
  MODULE PROCEDURE xfer_var_r3
  MODULE PROCEDURE xfer_var_r4
  MODULE PROCEDURE xfer_var_i2
END INTERFACE

INTERFACE xfer_idx
  MODULE PROCEDURE xfer_idx_2
  MODULE PROCEDURE xfer_idx_3
END INTERFACE


CONTAINS

!-------------------------------------------------------------------------
!
!
SUBROUTINE allocate_int_state()
!

END SUBROUTINE allocate_int_state


SUBROUTINE construct()
!
  !-----------------------------------------------------------------------

DO jg = 1,n


  CALL allocate_int_state( )

  !
  CALL scalar_int_coeff()

ENDDO

END SUBROUTINE construct

!-------------------------------------------------------------------------
!

SUBROUTINE xfer_var_r2()

END SUBROUTINE xfer_var_r2

!-------------------------------------------------------------------------

SUBROUTINE xfer_var_r3()

END SUBROUTINE xfer_var_r3

!-------------------------------------------------------------------------

SUBROUTINE xfer_var_r4()

END SUBROUTINE xfer_var_r4
!-------------------------------------------------------------------------

SUBROUTINE xfer_var_i2()

  CALL xfer_var_r2()

END SUBROUTINE xfer_var_i2

!-------------------------------------------------------------------------
!

SUBROUTINE xfer_idx_2()


  CALL xfer_var_r2()


END SUBROUTINE xfer_idx_2

!-------------------------------------------------------------------------

SUBROUTINE xfer_idx_3()

  IF(a==1 .and. s==2) THEN
    DO j = 1, UBOUND(idxi,3)
      CALL xfer_idx_2()
    ENDDO
  ENDIF

END SUBROUTINE xfer_idx_3

!-------------------------------------------------------------------------
SUBROUTINE transfer()
!

  CALL allocate_int_state(p)
  CALL xfer_var()

!  ENDIF
  CALL xfer_idx()
  CALL transfer_B()
END SUBROUTINE transfer_interpol_state
!-------------------------------------------------------------------------
END MODULE A
