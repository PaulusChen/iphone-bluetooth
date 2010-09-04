import sys
import os
import re
import binascii
import struct
from datetime import datetime, timedelta

##// APPLE PacketLogger
##typedef struct {
##        uint32_t        len;
##        uint32_t        ts_sec;
##        uint32_t        ts_usec;
##        uint8_t         type;
##} __attribute__ ((packed)) pktlog_hdr;

def writePacket(fd, binData, isIncoming, delta):
    ## network byte order, 3 unsigned ints and an unsigned char
    headerFormat = "!IIIB"
    dataLen = len(binData) - 1 + 13 - 4
    typeByte = binData[0]
    packetType = None
    if typeByte == '\x01': ## command
        packetType = 0
    elif typeByte == '\x04': ## event
        packetType = 1
    elif typeByte == '\x02': ## ACL
        if isIncoming:
            packetType = 3
        else:
            packetType = 2
    if packetType == None:
        return
    fd.write(struct.pack(headerFormat, dataLen, delta.seconds, delta.microseconds, packetType))
    fd.write(binData[1:])

def log2pklg(logname):
    log = open(logname, "r")
    logLines = log.readlines()
    pklg = open(logname + ".pklg", 'wb')
    readData = False
    isIncoming = False
    previousRead = None
    hciFds = {}
    for line in logLines:
        if readData:
            data = re.search(r':([^\|]+)\|', line)
            if data:
                dataObj += binascii.unhexlify(data.group(1).replace(" ", ""))
            elif dataObj:
                if isIncoming:
                    if previousRead:
                        dataObj = previousRead + dataObj
                        previousRead = None
                    else:
                        previousRead = dataObj
                        dataObj = None
                if dataObj:
                    writePacket(pklg, dataObj, isIncoming, delta)
                    dataObj = None
                readData = False
        match = re.match(r"\[(?P<time>[^\.]+)(?P<fractime>\.\d+)\] IO\((?P<fd>\d+)\):.*",  line)   
        if match:
            fd = match.group('fd')
            isIncoming = line.find("_read") > -1
            if isIncoming:
                hciFds[fd] = True
            if fd in hciFds:
                if previousRead and not isIncoming:
                    writePacket(pklg, previousRead, True, delta)
                    previousRead = None
                    
                dataObj = ""
                delta = datetime.strptime(match.group('time'), "%H:%M:%S") - datetime.strptime("", "")
                delta = delta + timedelta(microseconds = float(match.group('fractime')) * 1E6)
                readData = True
    for fd in hciFds:
        print "List of FDs included:", hciFds.keys()

if len(sys.argv) < 2:
    print "Usage: log2pklg <log file>"
    exit(1)
    
log2pklg(sys.argv[1])
