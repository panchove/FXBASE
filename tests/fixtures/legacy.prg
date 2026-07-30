* legacy.prg — Modo Clipper/Harbour clásico
PROCEDURE Main
    LOCAL cName := SPACE(20)
    LOCAL nAge  := 0

    ACCEPT "Nombre: " TO cName
    ACCEPT "Edad:   " TO nAge

    IF nAge >= 18
        ? cName + " es mayor de edad."
    ELSE
        ? cName + " es menor de edad."
    ENDIF

    DO WHILE .NOT. EOF()
        SKIP
    ENDDO
RETURN
