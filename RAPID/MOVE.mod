MODULE move
    CONST num MAX_BUFFER := 512;
    PERS robtarget bufferTargets{MAX_BUFFER};
    PERS speeddata bufferSpeeds{MAX_BUFFER};
    PERS num BUFFER_POS;
    PERS tooldata currentTool;    
    PERS wobjdata currentWobj;   
    PERS speeddata currentSpeed;
    PERS zonedata currentZone;
    PERS bool BUFFER_LOCKED;
    PERS bool MOVING;
    VAR triggdata Movement;
    
    PROC main()
        
        TriggIO Movement, 0 \DOp:=mMoving, 0;
        
        MOVING := FALSE;
        BUFFER_LOCKED := FALSE;
        ConfL \Off;
        SingArea \Wrist;
        
        BUFFER_POS := 0;
        WHILE TRUE DO
            IF BUFFER_POS > 0 THEN
                movePoint;
            ENDIF
        ENDWHILE
    ENDPROC
    
    
    PROC movePoint()
        TriggL bufferTargets{1}, bufferSpeeds{1}, Movement, currentZone, currentTool \WObj:=currentWobj;
        moveBuffer;
    ENDPROC
    
    PROC moveBuffer()
        IF BUFFER_POS > 1 THEN
            FOR i FROM 2 TO BUFFER_POS DO
                bufferTargets{i-1} := bufferTargets{i};
                bufferSpeeds{i-1} := bufferSpeeds{i};
            ENDFOR
        ENDIF
        IF BUFFER_POS > 0 THEN
            BUFFER_POS := BUFFER_POS - 1;
        ENDIF
    ENDPROC
ENDMODULE