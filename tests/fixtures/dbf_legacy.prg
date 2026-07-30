* dbf_legacy.prg — Compatibilidad con xBASE DB clásico
USE customers NEW
INDEX ON name TO name_idx
SET ORDER TO name_idx

LOCATE FOR name = "ACME"
IF FOUND()
    ? "Cliente:", customers->name, customers->balance
    REPLACE balance WITH 0
ENDIF

USE
