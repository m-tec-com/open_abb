MODULE move
    CONST num MAX_BUFFER := 128;
    PERS robtarget bufferTargets{MAX_BUFFER};
    PERS speeddata bufferSpeeds{MAX_BUFFER};
    PERS num BUFFER_POS;
    PERS num BUFFER_LEFT;
    PERS num POINTS_DONE;
    PERS tooldata currentTool;    
    PERS wobjdata currentWobj;   
    PERS speeddata currentSpeed;
    PERS zonedata currentZone;
    PERS bool BUFFER_LOCKED;
    PERS bool MOVING;
    VAR triggdata Movement;
    
    PERS robtarget target := [[700,500,10],[1,0,0,0], [0,0,0,0], [ 11, 12.3, 9E+09, 9E+09, 9E+09, 9E+09]];
    TASK PERS wobjdata wobjTest:=[FALSE,TRUE,"",[[1000,-1000,1000],[0.5,0.5,-0.5,0.5]],[[0,0,0],[1,0,0,0]]];
    CONST robtarget positionZero:=[[0,0,300],[1,0,0,0],[-1,1,1,0],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    
    PROC main()
        BUFFER_LEFT := MAX_BUFFER;
        BUFFER_POS := 1;
        BUFFER_LOCKED := FALSE;
        !TriggIO Movement, 0.1 \Time \DOp:=mMoving, 0;
        
        MOVING := FALSE;
        BUFFER_LOCKED := FALSE;
        ConfL \Off;
        !SingArea \LockAxis4;
        !SingArea \Wrist;
        
        !BUFFER_POS := 0;
        WHILE TRUE DO
            IF BUFFER_LEFT < MAX_BUFFER AND BUFFER_POS > 0 THEN
                MOVING := TRUE;
                movePoint;
                MOVING := FALSE;
            ENDIF
        ENDWHILE
    ENDPROC
    
    
    
    PROC movePoint()
        MoveL bufferTargets{BUFFER_POS}, bufferSpeeds{BUFFER_POS}, currentZone, currentTool \WObj:=currentWobj;
        WHILE BUFFER_LOCKED DO
            !wait
        ENDWHILE
        BUFFER_LOCKED := TRUE;
        BUFFER_LEFT := BUFFER_LEFT + 1;
        IF BUFFER_LEFT > MAX_BUFFER THEN
            BUFFER_LEFT := MAX_BUFFER;
        ENDIF
        BUFFER_POS := BUFFER_POS + 1;
        IF BUFFER_POS > MAX_BUFFER THEN
            BUFFER_POS := BUFFER_POS - MAX_BUFFER;
        ENDIF
        BUFFER_LOCKED := FALSE;
        POINTS_DONE := POINTS_DONE + 1;
        IF BUFFER_LEFT = MAX_BUFFER THEN
            POINTS_DONE := 0;
        ENDIF
        !TriggL bufferTargets{1}, bufferSpeeds{1}, Movement, currentZone, currentTool \WObj:=currentWobj;
        !moveBuffer;
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