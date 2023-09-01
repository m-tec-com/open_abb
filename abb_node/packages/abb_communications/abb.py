'''
Michael Dawson-Haggerty

abb.py: contains classes and support functions which interact with an ABB Robot running our software stack (RAPID code module SERVER)


For functions which require targets (XYZ positions with quaternion orientation),
targets can be passed as [[XYZ], [Quats]] OR [XYZ, Quats]

'''

import socket
import json 
import time
import inspect
import threading
import logging
import signal

log = logging.getLogger(__name__)
log.addHandler(logging.NullHandler())


class Timeout:
    def __init__(self, seconds=1, error_message='Timeout'):
        self.seconds = seconds
        self.error_message = error_message
    def handle_timeout(self, signum, frame):
        raise TimeoutError(self.error_message)
    def __enter__(self):
        signal.signal(signal.SIGALRM, self.handle_timeout)
        signal.alarm(self.seconds)
    def __exit__(self, type, value, traceback):
        signal.alarm(0)


class Robot:
    def __init__(self, 
                 ip          = '20.20.20.21', 
                 port_motion = 5000,
                 port_logger = 5001,
                 callback = None):

        self.delay   = .04
        self.callback = callback

        self.sendQue = []
        self.prioritySendQue = []
        self.isSending = False

        self.ip = ip
        self.port_motion = port_motion
        self.port_logger = port_logger
        self.connect()

        self.set_units('millimeters', 'degrees')
        self.set_tool()
        self.set_workobject()
        self.set_speed()
        self.set_zone()

    def connect(self):
        threading.Thread(target=self.preConnectMotion).start()
        self.preConnectLogger()

    def preConnectMotion(self):
        self.connect_motion((self.ip, self.port_motion))
        pass

    def preConnectLogger(self):
        self.connect_logger((self.ip, self.port_logger))

    def connect_motion(self, remote):        
        log.info('Attempting to connect to robot motion server at %s', self.ip)
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.settimeout(2.5)
        self.sock.connect(remote)
        self.sock.settimeout(None)
        log.info('Connected to robot motion server at %s', self.ip)

    def connect_logger(self, remote):
        
        self.s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.s.connect(remote)
        self.s.setblocking(1)
        self.readLogger()
        threading.Thread(target=self.readLoggerLoop).start()

    def readLoggerLoop(self):
        try:
            while True:
                self.readLogger()
        finally:
            self.s.shutdown(socket.SHUT_RDWR)
        

    def readLogger(self):
        data = self.s.recv(4096).split()
        if(len(data) > 0):
            if int(data[1]) == 0:
                #for i in range(2,9):
                #    data[i] = float(data[i])
                #self.pose = [data[2:5], data[5:9]]
                #self.bufferLeft = int(data[9])
                self.pose = []
                self.bufferLeft = int(data[2])

                print(self.pose, self.bufferLeft)
                if self.callback != None:
                    self.callback(self.pose, self.bufferLeft)


    def set_units(self, linear, angular):
        units_l = {'millimeters': 1.0,
                   'meters'     : 1000.0,
                   'inches'     : 25.4}
        units_a = {'degrees' : 1.0,
                   'radians' : 57.2957795}
        self.scale_linear = units_l[linear]
        self.scale_angle  = units_a[angular]

    def set_tool(self, tool=[[0,0,0], [1,0,0,0]]):
        '''
        Sets the tool centerpoint (TCP) of the robot. 
        When you command a cartesian move, 
        it aligns the TCP frame with the requested frame.
        
        Offsets are from tool0, which is defined at the intersection of the
        tool flange center axis and the flange face.
        '''
        msg       = "06 " + self.format_pose(tool) # 7*9+1 +3 = 67  
        self.send(msg, priority=True)
        self.tool = tool

    def set_workobject(self, work_obj=[[0,0,0],[1,0,0,0]]):
        '''
        The workobject is a local coordinate frame you can define on the robot,
        then subsequent cartesian moves will be in this coordinate frame. 
        '''
        msg = "07 " + self.format_pose(work_obj)  # 67
        self.send(msg, priority=True)

    def set_speed(self, speed=[100,50,50,50]):
        '''
        speed: [robot TCP linear speed (mm/s), TCP orientation speed (deg/s),
                external axis linear, external axis orientation]
        '''

        if len(speed) != 4: return False
        msg = "08 " #3
        msg += format(speed[0], "+08.1f") + " " #9
        msg += format(speed[1], "+08.2f") + " " #9
        msg += format(speed[2], "+08.1f") + " " #9
        msg += format(speed[3], "+08.2f") + " #" #10    
        self.send(msg) #40

    def set_zone(self, 
                 zone_key     = 'z1', 
                 point_motion = False, 
                 manual_zone  = []):
        zone_dict = {'z0'  : [.3,.3,.03], 
                    'z1'  : [1,1,.1], 
                    'z5'  : [5,8,.8], 
                    'z10' : [10,15,1.5], 
                    'z15' : [15,23,2.3], 
                    'z20' : [20,30,3], 
                    'z30' : [30,45,4.5], 
                    'z50' : [50,75,7.5], 
                    'z100': [100,150,15], 
                    'z200': [200,300,30]}
        '''
        Sets the motion zone of the robot. This can also be thought of as
        the flyby zone, AKA if the robot is going from point A -> B -> C,
        how close do we have to pass by B to get to C
        
        zone_key: uses values from RAPID handbook (stored here in zone_dict)
        with keys 'z*', you should probably use these

        point_motion: go to point exactly, and stop briefly before moving on

        manual_zone = [pzone_tcp, pzone_ori, zone_ori]
        pzone_tcp: mm, radius from goal where robot tool centerpoint 
                   is not rigidly constrained
        pzone_ori: mm, radius from goal where robot tool orientation 
                   is not rigidly constrained
        zone_ori: degrees, zone size for the tool reorientation
        '''

        if point_motion: 
            zone = [0,0,0]
        elif len(manual_zone) == 3: 
            zone = manual_zone
        elif zone_key in zone_dict.keys(): 
            zone = zone_dict[zone_key]
        else: return False
        
        msg = "09 " #3
        msg += str(int(point_motion)) + " " #2
        msg += format(zone[0], "+08.4f") + " " #9
        msg += format(zone[1], "+08.4f") + " " #9
        msg += format(zone[2], "+08.4f") + " " #10
        self.send(msg) #33

    def buffer_add(self, pose):
        '''
        Appends single pose to the remote buffer
        Move will execute at current speed (which you can change between buffer_add calls)
        '''
        msg = "30 " + self.format_pose(pose)
        self.send(msg, False)

    def clear_buffer(self):
        msg = "31 "
        self.send(msg)

    def pause(self):
        self.send("90 ", priority=True)

    def resume(self):
        self.send("91 ", priority=True)
    
    def calculateWobj(self, code, pose):
        msg = "8" + str(code) + " " + self.format_pose(pose)
        self.send(msg)
        
    def send(self, message, wait_for_response=True, priority=False):
        msg = {
            "message":message,
            "wait_for_response": wait_for_response
            }
        if priority:
            self.prioritySendQue.append(msg)
        else:
            self.sendQue.append(msg)
        self.sender()

    def sender(self):
        '''
        Send a formatted message to the robot socket.
        if wait_for_response, we wait for the response
        '''
        
        if self.isSending:
            print("isSending")
            return
        self.isSending = True
        #print("send", message)

        if len(self.prioritySendQue) == 0 and len(self.sendQue) == 0:
            self.isSending = False
            return

        if len(self.prioritySendQue) != 0:
            msg = self.prioritySendQue.pop()
        else:
            msg = self.sendQue.pop()
        message = msg["message"]
        wait_for_response = msg["wait_for_response"]

        while len(message) < 66:
            message += "*"
        message += "#"

        caller = inspect.stack()[1][3]
        log.debug('%-14s sending: %s', caller, message)
        self.sock.send(message.encode())
        time.sleep(self.delay)
        if wait_for_response:
            data = self.sock.recv(4096).decode()
            log.debug('%-14s recieved: %s', caller, data)
        self.isSending = False
        self.sender()
        
    def format_pose(self, pose):
        pose = check_coordinates(pose)
        msg  = ''
        for cartesian in pose[0]:
            msg += format(cartesian * self.scale_linear,  "+08.1f") + " " #9
        for quaternion in pose[1]:
            msg += format(quaternion, "+08.5f") + " " #9
        msg += "" #1
        return msg       
        
    def close(self):
        self.send("99 ", False)
        self.sock.shutdown(socket.SHUT_RDWR)
        self.sock.close()
        log.info('Disconnected from ABB robot.')

    def __enter__(self):
        return self
        
    def __exit__(self):
        self.close()

def check_coordinates(coordinates):
    if ((len(coordinates) == 2) and
        (len(coordinates[0]) == 3) and 
        (len(coordinates[1]) == 4)): 
        return coordinates
    elif (len(coordinates) == 7):
        return [coordinates[0:3], coordinates[3:7]]
    log.warn('Recieved malformed coordinate: %s', str(coordinates))
    raise NameError('Malformed coordinate!')

if __name__ == '__main__':
    formatter = logging.Formatter("[%(asctime)s] %(levelname)-7s (%(filename)s:%(lineno)3s) %(message)s", "%Y-%m-%d %H:%M:%S")
    handler_stream = logging.StreamHandler()
    handler_stream.setFormatter(formatter)
    handler_stream.setLevel(logging.DEBUG)
    log = logging.getLogger('abb')
    log.setLevel(logging.DEBUG)
    log.addHandler(handler_stream)
    
