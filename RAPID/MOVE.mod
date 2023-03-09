MODULE move
    CONST num MAX_BUFFER := 512;
    PERS robtarget bufferTargets{MAX_BUFFER};
    PERS speeddata bufferSpeeds{MAX_BUFFER};
    PERS num BUFFER_POS;
    PERS tooldata currentTool;    
    PERS wobjdata currentWobj;   
    PERS speeddata currentSpeed;
    PERS zonedata currentZone;
    
    PROC main()
        ConfL \Off;
        SingArea \Wrist;
        
        BUFFER_POS := 0;
        WHILE TRUE DO
            IF BUFFER_POS > 0 THEN
                movePoint;
            ENDIF
        ENDWHILE
        !WaitTime 300;
    ENDPROC
    
    
    PROC movePoint() 
        TPWrite NumToStr(bufferTargets{1}.trans.x,0) + "/" + NumToStr(bufferTargets{1}.trans.y,0) + "/" + NumToStr(bufferTargets{1}.trans.z,0);
        MoveL bufferTargets{1}, bufferSpeeds{1}, currentZone, currentTool \WObj:=currentWobj ;
        moveBuffer;
    ENDPROC
    
    PROC moveBuffer()
        IF BUFFER_POS > 1 THEN
            FOR i FROM 2 TO BUFFER_POS DO
                bufferTargets{i-1} := bufferTargets{i};
                bufferSpeeds{i-1} := bufferSpeeds{i};
            ENDFOR
        ENDIF
        BUFFER_POS := BUFFER_POS - 1;
    ENDPROC
ENDMODULE