MODULE LOGGER

!////////////////
!GLOBAL VARIABLES
!////////////////
!PC communication
VAR socketdev clientSocket;
VAR socketdev serverSocket;
PERS string ipController;
PERS num loggerPort:= 5001;

!Robot configuration	
PERS tooldata currentTool;    
PERS wobjdata currentWobj;
VAR speeddata currentSpeed;
VAR zonedata currentZone;

PERS num BUFFER_POS;
PERS num BUFFER_LEFT;
PERS bool BUFFER_LOCKED;
PERS bool MOVING;
CONST num MAX_BUFFER := 128;


!//Logger sampling rate
!PERS num loggerWaitTime:= 0.01;  !Recommended for real controller
PERS num loggerWaitTime:= 0.1;    !Recommended for virtual controller

PROC ServerCreateAndConnect(string ip, num port)
	VAR string clientIP;
	
	SocketCreate serverSocket;
	SocketBind serverSocket, ip, port;
	SocketListen serverSocket;
	TPWrite "LOGGER: Logger waiting for incomming connections ...";
	WHILE SocketGetStatus(clientSocket) <> SOCKET_CONNECTED DO
		SocketAccept serverSocket,clientSocket \ClientAddress:=clientIP \Time:=WAIT_MAX;
		IF SocketGetStatus(clientSocket) <> SOCKET_CONNECTED THEN
			TPWrite "LOGGER: Problem serving an incomming connection.";
			TPWrite "LOGGER: Try reconnecting.";
		ENDIF
		 !Wait 0.5 seconds for the next reconnection
		 WaitTime 0.5;
	ENDWHILE
	TPWrite "LOGGER: Connected to IP " + clientIP;
ENDPROC

PROC main()
	VAR string data;
	VAR robtarget position;
	VAR jointtarget joints;
    VAR string sendString;
	VAR bool connected;
    
    VAR num bufferLeft;

	VAR string date;
	VAR string time;
	VAR clock timer;

	date:= CDate();
	time:= CTime();
    ClkStart timer;
    
	connected:=FALSE;
	ServerCreateAndConnect ipController,loggerPort;	
	connected:=TRUE;
    
    SetDO mMoving, 0;
    
	WHILE TRUE DO
        
        
        
        !WaitDO mMoving, 0;
        !bufferLeft := MAX_BUFFER - BUFFER_POS;
        !SetDO mMoving, 1;
        !TPWrite NumToStr(bufferLeft, 0);
!		position := CRobT(\Tool:=currentTool \WObj:=currentWObj);
		data := "# 0 ";
!        data := data + NumToStr(position.trans.x,1) + " ";
!		data := data + NumToStr(position.trans.y,1) + " ";
!        data := data + NumToStr(position.trans.z,1) + " ";
!		data := data + NumToStr(position.rot.q1,3) + " ";
!		data := data + NumToStr(position.rot.q2,3) + " ";
!		data := data + NumToStr(position.rot.q3,3) + " ";
!        data := data + NumToStr(position.rot.q4,3) + " ";
        !data := data + NumToStr(bufferLeft, 0) + " ";
        data := data + NumToStr(BUFFER_LEFT, 0) + " ";
        
		IF connected = TRUE THEN
			SocketSend clientSocket \Str:=data;
		ENDIF
        
        WaitTime loggerWaitTime;
        
	ENDWHILE
	ERROR
	IF ERRNO=ERR_SOCK_CLOSED THEN
		TPWrite "LOGGER: Client has closed connection.";
	ELSE
		TPWrite "LOGGER: Connection lost: Unknown problem.";
	ENDIF
	connected:=FALSE;
	!Closing the server
	SocketClose clientSocket;
	SocketClose serverSocket;
	!Reinitiate the server
	ServerCreateAndConnect ipController,loggerPort;
	connected:= TRUE;
	RETRY;
ENDPROC


ENDMODULE