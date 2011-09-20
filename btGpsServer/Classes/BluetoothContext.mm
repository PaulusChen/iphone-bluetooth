//
//  BluetoothContext.m
//  btTest
//
//  Created by msftguy on 6/25/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "BluetoothContext.h"
#include "bt_main.h"
#include "bt_helpers.h"
#include "gps_thread.h"
#include "log.h"

int sessionEventCallback(BTSESSION session, BTSessionEvent sessionEvent, BTResult result, void* ctx);

void localStatusEventCallback(BTLOCALDEVICE* localDevice, BT_LOCAL_DEVICE_EVENT event, void* unk1, void* ctx);

void serviceEventCallback(BTDEVICE device, BT_SERVICE_TYPE serviceType, SERVICE_EVENT_TYPE eventType, SERVICE_EVENT event, int result, void* ctx);

void discoveryStatusCallback(BTDISCOVERYAGENT agent, BT_DISCOVERY_STATUS status, BTDEVICE device, int result, void* ctx);
void discoveryEventCallback(BTDISCOVERYAGENT agent, BT_DISCOVERY_EVENT event, 
                            BTDEVICE device, BTDeviceAttributes attr, void* ctx);

void pairingAgentStatusCallback(PAIRING_AGENT agent, BT_PAIRING_AGENT_STATUS status, BTDEVICE device, int PairingResult, void* ctx);
void pairingPincodeCallback(PAIRING_AGENT agent, BTDEVICE device, uint8_t unk1, void* ctx);
void pairingAuthorizationCallback(PAIRING_AGENT agent, BTDEVICE device, BTServiceMask serviceMask, void* ctx);
void pairingUserConfirmationCallback(PAIRING_AGENT agent, BTDEVICE device, uint32_t unk1, BTBool unk2, void* ctx);
void pairingPasskeyDisplayCallback(PAIRING_AGENT agent, BTDEVICE device, uint32_t unk1, void* ctx);

const char* stateString(BtState state)
{
    static char buf[BUFSIZ];
    switch (state) {
        case BtStateIdle:
            return "Idle";
            break;
        case BtStatePowerOff:
            return "PowerOff";
            break;
        case BtStatePowerOn:
            return "PowerOn";
            break;
        case BtStateScan:
            return "Scan";
            break;
        case BtStateConnecting:
            return "Connecting";
            break;
        case BtStateConnected:
            return "Connected";
            break;
        default:
            snprintf(buf, sizeof(buf), "%u", state);
            return buf;
            break;
    }
}

@implementation BluetoothContext

@synthesize session = _session;
@synthesize device = _device;
@synthesize discoveryAgent = _discoveryAgent;
@synthesize pairingAgent = _pairingAgent;
@synthesize pairingAgentStarted = _pairingAgentStarted;
@synthesize localDevice = _localDevice;
@synthesize targetName = _targetName;
@synthesize targetAddr = _targetAddr;
@synthesize targetPin = _targetPin;
@synthesize foundDevices = _foundDevices;
@synthesize targetState = _targetState;
@synthesize currentState = _currentState;

@synthesize magic;

+ (void) postNotificationWithKey:(NSString*)key value:(id)value
{
    
    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    
    NSDictionary* userInfo = 
    [NSDictionary dictionaryWithObjectsAndKeys:value, key, nil];
    [nc postNotificationName:BluetoothConfigChangeNotification object:g_bc userInfo:userInfo];
}

- (id) init
{
    self = [super init];
    self.session = NULL;
    self.device = NULL;
    self.discoveryAgent = NULL;
    self.pairingAgent = NULL;
    self.localDevice = NULL;
    self.currentState = BtStateIdle;
    self.targetState = BtStateIdle;
    self.targetName = @"";
    _foundDevices = [[NSMutableDictionary alloc] init];

    _targetAddr = (NSString*)CFPreferencesCopyAppValue(kBtDeviceAddress, kAppId);
    if (_targetAddr == nil) {
        _targetAddr = @"";
    }

    _targetPin = (NSString*)CFPreferencesCopyAppValue(kBtDevicePasscode, kAppId);	
    if (_targetPin == nil) {
        _targetPin = @"";
    }

    magic = 0xdeadbeef;
    
    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    [nc
        addObserver:self
            selector:@selector(BluetoothConfigChanged:) 
                name:BluetoothConfigChangeNotification
              object:nil];
    return self;
}

- (void) dealloc
{
    [_foundDevices release];
    [super dealloc];
}

- (void) BluetoothConfigChanged:(NSNotification*)notification
{
    NSDictionary* userInfo = [notification userInfo];
    NSNumber* newTsVal = [userInfo valueForKey:BtTargetStateKey];
    NSString* pin = [userInfo valueForKey:BtPinKey];
    NSString* name = [userInfo valueForKey:BtNameKey];
    NSString* addr = [userInfo valueForKey:BtAddressKey];
    if ([pin length] != 0) {
        self.targetPin = pin;
    }
    if ([name length] != 0) {
        self.targetName = name;
    }
    if ([addr length] != 0) {
        self.targetAddr = addr;
    }
    if (newTsVal != nil) {
        BtState newTargetState = (BtState)[newTsVal intValue];
        self.targetState = newTargetState;
        switch (self.targetState) {
            case BtStateIdle:
                self.targetState = self.currentState < BtStatePowerOn ? BtStatePowerOff : BtStatePowerOn;
                break;
            case BtStateScan:
                [_foundDevices removeAllObjects];
                break;	
            default:
                break;
        }
        [self onStateChange:self.currentState];
    }	
}

- (BOOL) isStickyState:(BtState)state
{
    switch (state) {
        case BtStatePowerOff:
        case BtStatePowerOn:
        case BtStateConnecting:
            return NO;
        case BtStateIdle:
        case BtStateScan:
        case BtStateConnected:
            return YES;
    }
    assert(FALSE); //state not in switch()
    return NO;    
}

- (BtState) powerAdjustedTargetState
{
    switch (self.currentState) {
        case BtStateIdle:
            return self.targetState;
        case BtStatePowerOff:
            return BtStatePowerOff;
        default: // power on, etc
            if (self.targetState == BtStatePowerOff) {
                return BtStatePowerOn;
            } else
                return self.targetState;
    }
}

- (void) onStateChange:(BtState)newState
{
    LogMsg("onStateChange: %s -> %s", stateString(self.currentState), stateString(newState));
    self.currentState = newState;
    BtState powerAdjustedTargetState = [self powerAdjustedTargetState];
    int direction = self.currentState > powerAdjustedTargetState ? -1 : self.currentState == powerAdjustedTargetState ? 0 : 1;
    if (direction == 0 && ![self isStickyState:self.targetState]) {
        self.targetState = BtStateIdle;
    }
    if (self.targetState == BtStateIdle) {
        return;
    }

    switch (self.currentState) {
        case BtStateIdle:
            [self onStateChange: [self getPowerState] ? BtStatePowerOn : BtStatePowerOff];
            break;
        case BtStatePowerOff:
            if (direction > 0) {
                [self fsmPowerOff2On];
            }
            break;
        case BtStatePowerOn:
            if (direction < 0) {
                [self fsmPowerOn2Off];
            } else if (direction > 0) {
                [self fsmPowerOn2Scan];
            }
            break;
        case BtStateScan:
            if (direction < 0) {
                [self fsmScan2PowerOn];
            } else if (direction > 0) {
                [self fsmScan2Connecting];
            }
            break;
        case BtStateConnecting:
            if (direction < 0) {
                [self fsmConnecting2Scan];
            } else if (direction > 0) {
                [self fsmConnecting2Connected];
            }
        case BtStateConnected:
            if (direction < 0) {
                [self fsmConnected2Connecting];
            } else {
                [self fsmConnected];
            }
            break;
        default:
            LogMsg("Invalid state: %u", self.currentState);
            assert(FALSE);
            break;
        }
}

- (void) fsmPowerOff2On
{
    [self setPowerState:YES];
}

- (void) fsmPowerOn2Off
{
    [self setPowerState:NO];
}

- (void) fsmPowerOn2Scan
{
//	if (![self tryCreateTargetDevice]) {
    [self scanNeeded:YES];
}

- (void) fsmScan2PowerOn
{
    [self scanNeeded:NO];	
    [self onStateChange:BtStatePowerOn];
}

- (void) fsmScan2Connecting
{
    [self connectDisconnect:YES];
}

- (void) fsmConnecting2Scan
{
    [self connectDisconnect:NO];
    if (self.targetState >= BtStateScan) {
        [self scanNeeded:YES];
    } else {
        [self scanNeeded:NO];		
        //going down; skip scan state
        [self onStateChange:BtStateScan];
    }
}

- (void) fsmConnecting2Connected
{
    [self connectDisconnect:YES];
}

- (void) fsmConnected2Connecting
{
    [self connectDisconnect:NO];
}

- (void) fsmConnected
{
    [self scanNeeded:NO];
}

- (BOOL) getPowerState
{
    int currentPowerState = 0;

    int err = BTLocalDeviceGetModulePower(self.localDevice, 1, &currentPowerState);
    if (err !=  0) {
        LogMsg("getPowerState: BTLocalDeviceGetModulePower error: 0x%x", err);
        return NO;
    }
    return !!currentPowerState;
}

- (void) setPowerState:(BOOL)targetPowerState
{	
    BOOL currentPowerState = [self getPowerState];
    if (targetPowerState != currentPowerState) {
        int err = BTLocalDeviceSetModulePower(self.localDevice, 1, targetPowerState ? POWER_STATE_ON : POWER_STATE_OFF);
        if (err !=  0) {
            LogMsg("setPowerState: BTLocalDeviceSetModulePower(%i->%i) error: 0x%x", 
                   currentPowerState, targetPowerState, err);
            return;
        }
    }
}

- (BOOL) doLocalScan
{
    int err = 0;
    const size_t MAX_DEVS = 0x100;
    BTDEVICE devBuf[MAX_DEVS];
    unsigned int cntOut = 0;
    err = BTLocalDeviceGetPairedDevices(self.localDevice, devBuf, &cntOut, MAX_DEVS);
    if (err != 0) {
        LogMsg("BTLocalDeviceGetPairedDevices error: %X", err);
    } else {
        for (unsigned int i = 0; i < cntOut; ++i) {
            BTDEVICE dev = devBuf[i];
            char cName[BUFSIZ] = ""; 
            err = BTDeviceGetName(dev, cName, BUFSIZ);
            if (err != 0)
                strcpy(cName, "!error!");
            char cAddr[BUFSIZ] = "";
            err = BTDeviceGetAddressString(dev, cAddr, sizeof(cAddr));
            if (err != 0)
                strcpy(cAddr, "!error!");
            LogMsg("Paired device #%u: %s [%s]", i + 1, cName, cAddr);
            if ([self onDiscoveryFoundDevice:(BTDEVICE)dev]) {
                LogMsg("Cached device %s matched the description", cName);                
                return YES;
            }
        }
    }
    return NO;
}

- (BOOL) createAndStartDiscoveryAgent
{
    int err = 0;

    if (self.discoveryAgent == nil) {
        BTDISCOVERYAGENT btDiscoveryAgent;
        DISCOVERY_CALLBACKS discoveryCallbacks = {discoveryStatusCallback, discoveryEventCallback};
        
        err = BTDiscoveryAgentCreate(self.session, &discoveryCallbacks, self, &btDiscoveryAgent);
        if (err != 0) {
            LogMsg("createAgentAndStartScan: BTDiscoveryAgentCreate error: %X", err);
            return NO;
        }
        LogMsg("createAgentAndStartScan: BTDiscoveryAgentCreate OK (%p)", btDiscoveryAgent);
        
        self.discoveryAgent = btDiscoveryAgent;
    }
    
    err = BTDiscoveryAgentStartScan(self.discoveryAgent, 1, ~0x0);
    if (err != 0) {
        LogMsg("createAgentAndStartScan: BTDiscoveryAgentStartScan error: 0x%x", err);
        return NO;
    }	
    return YES;
}

- (void) stopScanAndDestroyAgent
{
    int err = 0;
    
    if (self.discoveryAgent != nil) {
        err = BTDiscoveryAgentStopScan(self.discoveryAgent);
        if (err != 0) {
            LogMsg("stopScanAndDestroyAgent: BTDiscoveryAgentStopScan error: 0x%x", err);            
        }
        err = BTDiscoveryAgentDestroy(&_discoveryAgent);
        if (err != 0) {
            LogMsg("stopScanAndDestroyAgent: BTDiscoveryAgentDestroy failed: 0x%x",  err);
        }
        self.discoveryAgent = nil;
    }
}

- (void) scanNeeded:(BOOL)needScan
{
    if (needScan) {
        BOOL localScanResult = [self doLocalScan];
        if (localScanResult && self.targetState != BtStateScan) {
            LogMsg("setScanEnabled: Skipping scan, device already in paired DB");            
        } else {
            BOOL pairingAgentStarted = [self pairingAgentEnable:YES];
            if (!pairingAgentStarted) {
                LogMsg("setScanEnabled: createAndStartPairingAgent failed");
            }
            BOOL scanStarted = [self createAndStartDiscoveryAgent];
            if (!scanStarted) {
                LogMsg("setScanEnabled: createAgentAndStartScan failed");
                return;
            }
        }
        LogMsg("setScanEnabled: BTDiscoveryAgentStartScan OK");
    } else {
        [self stopScanAndDestroyAgent];
        [self pairingAgentEnable:NO];
        LogMsg("setScanEnabled: BTDiscoveryAgentStopScan OK");
    }
}

- (BOOL) createAndStartPairingAgent
{
    int err = 0;
    if (self.pairingAgent == nil) {
        PAIRING_AGENT btPairingAgent;
        PAIRING_AGENT_CALLBACKS pairingAgentCallbacks = {pairingAgentStatusCallback, pairingPincodeCallback, pairingAuthorizationCallback, 
            pairingUserConfirmationCallback, pairingPasskeyDisplayCallback};
        
        err = BTPairingAgentCreate(self.session, &pairingAgentCallbacks, self, &btPairingAgent);
        if (err != 0) {
            LogMsg("BTPairingAgentCreate error: %X", err);
            return NO;
        } else {
            LogMsg("BTPairingAgentCreate OK (%p)", btPairingAgent);
            self.pairingAgent = btPairingAgent;
        }
    }
    if (!self.pairingAgentStarted) {
        err = BTPairingAgentStart(self.pairingAgent);
        if (err != 0) {
            LogMsg("BTPairingAgentStart error: %X", err);
            return NO;
        } else {
            self.pairingAgentStarted = YES;
        }
    }    
    return YES;
}

- (void) stopPairingAndDestroyAgent
{
    int err = 0;
    if (self.pairingAgentStarted) {
        err = BTPairingAgentCancelPairing(self.pairingAgent);
        if (err != 0) {
            LogMsg("stopPairingAndDestroyAgent: BTPairingAgentCancelPairing failed: 0x%x",  err);
        }
    }
    if (self.pairingAgent != nil) {
        err = BTPairingAgentStop(self.pairingAgent);
        if (err != 0) {
            LogMsg("stopPairingAndDestroyAgent: BTPairingAgentStop failed: 0x%x",  err);
        }
        
        err = BTPairingAgentDestroy(&_pairingAgent);
        if (err != 0) {
            LogMsg("stopPairingAndDestroyAgent: BTPairingAgentDestroy failed: 0x%x",  err);
        }
        self.pairingAgent = nil;
    }
}

- (BOOL) pairingAgentEnable:(BOOL)start
{
    if (start) {
        return [self createAndStartPairingAgent];
    } else {
        [self stopPairingAndDestroyAgent];
        return YES;
    }
}

- (void) connectDisconnect:(BOOL)fConnect
{
    if (fConnect) {
        [self connect];
    } else {
        int err = BTDeviceDisconnect(self.device);
        if (err != 0) {
            LogMsg("connectDisconnect: BTDeviceDisconnect error: %X", err);
        }
    }
}

extern "C" CFDictionaryRef _CFCopySystemVersionDictionary();
extern CFStringRef const _kCFSystemVersionProductVersionKey;


static NSString* const getIosVer()
{
    static NSString* iosVer = nil;
    if (iosVer == nil) {
        CFDictionaryRef verDict = _CFCopySystemVersionDictionary();
        if (verDict != nil) {
            CFStringRef verStr = (CFStringRef)CFDictionaryGetValue(verDict, _kCFSystemVersionProductVersionKey);
            if (verStr != nil) {
                iosVer = [[NSString alloc] initWithString:(NSString*)verStr];
                LogMsg("iOS version: %s", [iosVer UTF8String]);
            }
            CFRelease(verDict);
        }
    }
    return iosVer;
}

- (void) connect 
{	
    int err; 
    
    if ([getIosVer() compare:@"5"] == NSOrderedAscending) { // iOS ver < 5.x
        err = BTDeviceSetAuthorizedServices(self.device, BT_SERVICE_BRAILLE | BT_SERVICE_A2DP);
        if (err != 0) {
            LogMsg("connect: BTDeviceSetAuthorizedServices error: 0x%x", err);
            return;
        }
        LogMsg("connect: BTDeviceSetAuthorizedServices OK");
    }
    
    err = BTDeviceDisconnect(self.device);
    if (err != 0) {
        LogMsg("connect: BTDeviceDisconnect error: 0x%x", err);
    }
        
    err = BTDeviceConnectServices(self.device, BT_SERVICE_BRAILLE | BT_SERVICE_A2DP);
    if (err != 0) {
        LogMsg("BTDeviceConnect error: %X", err);
		if (err == 0xA4 && self.pairingAgent != NULL) {
			BTPairingAgentCancelPairing(self.pairingAgent);
			
			err = BTDeviceConnect(self.device);
			if (err != 0)
			{
				LogMsg("BTDeviceConnect error: %X", err);
				return;
			}
		} else {
            return;
        }
    }
    LogMsg("BTDeviceConnect OK");
    
    
    int svc;
    err = BTDeviceGetSupportedServices(self.device, &svc);
    if (err != 0) {
        LogMsg("BTDeviceGetSupportedServices error: %X", err);
        return;
    }	
    LogMsg("BTDeviceGetSupportedServices OK, svc=0x%X", svc);
}

- (BOOL) isTargetDeviceName:(NSString*)name addr:(NSString*)addr
{
    if ([self.targetName length] != 0) {
        if (0 == [self.targetName compare:name options:NSCaseInsensitiveSearch]) {
            return YES;
        }
    }
    if ([self.targetAddr length] != 0) {
        if (0 == [self.targetAddr compare:addr options:NSCaseInsensitiveSearch]) {
            return YES;
        }
    }
    return NO;
}

- (void) onSessionConnected:(BTSESSION)btSession
{	
    self.session = btSession;
    
    int err;
    
    BTLOCALDEVICE btLocalDevice;
    err = BTLocalDeviceGetDefault(self.session, &btLocalDevice);
    if (err != 0) {
        LogMsg("BTLocalDeviceGetDefault error: %X", err);
        return;
    }
    LogMsg("BTLocalDeviceGetDefault OK(%p)", btLocalDevice);	
    
    LOCAL_DEVICE_CALLBACKS localDeviceCallbacks = {localStatusEventCallback};
    err = BTLocalDeviceAddCallbacks(btLocalDevice, &localDeviceCallbacks, self);
    if (err != 0) {
        LogMsg("BTLocalDeviceAddCallbacks error: %X", err);
        return;
    }
    LogMsg("BTLocalDeviceAddCallbacks OK");
    
    self.localDevice = btLocalDevice;

    err = BTServiceAddCallbacks(self.session, serviceEventCallback, self);
    if (err != 0) {
        LogMsg("BTServiceAddCallbacks error: %X", err);
        return;
    }
    LogMsg("BTServiceAddCallbacks OK");	
        
    BOOL powerState = [self getPowerState];
    LogMsg("Power state: %s", powerState ? "ON" : "OFF");
    BtState newState = powerState ? BtStatePowerOn : BtStatePowerOff;
    
    [self onStateChange:newState];
}

- (void) onSessionDisconnected
{
    int err;
    
    self.currentState = BtStateIdle;
    self.device = nil;
    
    if (self.session == nil) {
        return;
    }
    
    [self stopPairingAndDestroyAgent];

    [self stopScanAndDestroyAgent];
    
    self.localDevice = nil;
    
    err = BTSessionDetachWithRunLoopAsync(CFRunLoopGetCurrent(), self.session);
    if (err != 0) {
        LogMsg("onSessionDisconnected: BTSessionDetachWithRunLoopAsync failed: 0x%x", err);
    }

    self.session = nil;
}

static NSString* const BtSessionKey = @"BtSessionKey";

- (void) reconnectSessionTimerProc:(NSTimer*)theTimer
{
    NSValue* nsVal = [[theTimer userInfo] valueForKey:BtSessionKey];
    BTSESSION btSession = (BTSESSION) [nsVal pointerValue];
    assert(btSession == self.session);
    [self reconnectSession];
}

- (BOOL) reconnectSession
{
    int err;
    if (self.session != nil) 
        [self onSessionDisconnected];

    BTSESSION ses;
    SESSION_CALLBACKS sessionCallbacks = {sessionEventCallback};
    err = BTSessionAttachWithRunLoopAsync(CFRunLoopGetCurrent(), "com.apple.something2", &sessionCallbacks, self, &ses);
    if (err != 0) {
        LogMsg("BTSessionAttachWithRunLoop error: 0x%x", err);
        return NO;
    }
    return YES;
}

- (void) onLocalPowerChanged
{
    BOOL newPowerState = [self getPowerState];
    BtState newState = self.currentState;
    if (newPowerState) {
        if (self.currentState < BtStatePowerOn) {
            newState = BtStatePowerOn;
        }
    } else {
        newState = BtStatePowerOff;
    }
    [self onStateChange:newState];
}

- (void) onServiceConnected:(BT_SERVICE_TYPE)serviceType result:(int)result
{
    if (serviceType == BT_SERVICE_BRAILLE && result == 0) {
        char buf[0x100] = "";
        int err = BTDeviceGetComPortForService(self.device, BT_SERVICE_BRAILLE, buf, sizeof(buf));
        if (err != 0) {
            LogMsg("BTDeviceGetComPortForService error: 0x%x", err);
            return;
        }
        LogMsg("BTDeviceGetComPortForService OK: %s", buf);
        NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
        NSDictionary* userInfo = [NSDictionary 
                                  dictionaryWithObject:[NSString stringWithFormat:@"%s", buf] 
                                  forKey:GpsTty];
        [nc postNotificationName:GpsConnectedNotification object:g_gpsThread userInfo:userInfo];  
        [self onStateChange:BtStateConnected];
        CFPreferencesSetAppValue(kBtDeviceAddress, self.targetAddr, kAppId);
        CFPreferencesSetAppValue(kBtDevicePasscode, self.targetPin, kAppId);		
        if (!CFPreferencesAppSynchronize(kAppId)) {
            LogMsg("BTDeviceGetComPortForService: could not save preferences!");
        }
    } else if (result != 0 && 
               (serviceType == BT_SERVICE_BRAILLE || serviceType == BT_SERVICE_A2DP || serviceType == BT_SERVICE_ANY))
    {
        if (self.currentState == BtStateConnected || self.currentState == BtStateConnecting) {
            [self onStateChange:BtStateConnecting];
        }
    }
}

- (void) onServiceDisconnected:(BT_SERVICE_TYPE)serviceType result:(int)result
{
    if ((serviceType == BT_SERVICE_BRAILLE || serviceType == BT_SERVICE_A2DP) && self.currentState == BtStateConnected) {
        [self onStateChange:BtStateConnecting];
    }
}

- (void) postScanNotification
{
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), 
                                         BtGpsScanNotificationName, 
                                         nil, nil, TRUE);
}

- (void) addDeviceAddr:(NSString*)address name:(NSString*)name
{
    [_foundDevices setValue:name forKey:address];
}

- (void) onDiscoveryStarted
{
    if (self.currentState != BtStateConnected) {
        [self onStateChange:BtStateScan];
        [self postScanNotification];
    }
}

- (void) onDiscoveryStopped
{
    BtState newState = self.currentState;
    if (newState == BtStateScan) {
        newState = BtStatePowerOn; 
    }
    [self onStateChange:newState];
    [self postScanNotification];
}

void pruneNonAscii(char* buf, size_t cb)
{
    for (int i = 0; i < cb; ++i) {
        unsigned char c = (unsigned)buf[i];
        if (c == '\0')
            break;
        if (c < ' ' || c > '\x7F')
            buf[i] = '?';
    }	
}

- (BOOL) onDiscoveryFoundDevice:(BTDEVICE)foundDevice
{
    int svc;
    char cName[BUFSIZ] = "";
    int err = BTDeviceGetName(foundDevice, cName, sizeof(cName));
    if (err != 0) {
        LogMsg("BTDeviceGetName error: %X", err);
    } else {
        pruneNonAscii(cName, sizeof(cName));
        cName[sizeof(cName) - 1] = '\0';
        LogMsg("BTDeviceGetName()=%s", cName);	
    }
    NSString* name = [NSString stringWithCString:cName encoding:NSASCIIStringEncoding];
    
    char cAddr[BUFSIZ] = "";
    err = BTDeviceGetAddressString(foundDevice, cAddr, sizeof(cAddr));
    if (err != 0) {
        LogMsg("BTDeviceGetAddressString error: 0x%x", err);
    } else {
        LogMsg("BTDeviceGetAddressString()=%s", cAddr);	
    }
    NSString* address = [NSString stringWithCString:cAddr encoding:NSASCIIStringEncoding];

    [self addDeviceAddr:address name:name];
    
    [self postScanNotification];

    if (![self isTargetDeviceName:name addr:address]) {
        return NO;
    }

    self.device = foundDevice;
        
    err = BTDeviceGetSupportedServices(foundDevice, &svc);
    if (err != 0) {
        LogMsg("BTDeviceGetSupportedServices error: 0x%x", err);
    } else {
        LogMsg("BTDeviceGetSupportedServices(): 0x%x", svc);
    }
    
    if (self.targetState != BtStateScan) {
        [self onStateChange:BtStateConnecting];
    }
    return YES;
}

- (void) onPairingStatus:(BT_PAIRING_AGENT_STATUS)status
{
    switch (status)
    {
        case BT_PAIRING_AGENT_STARTED:
            self.pairingAgentStarted = YES;
            break;
        case BT_PAIRING_AGENT_STOPPED:
            self.pairingAgentStarted = NO;
            break;
        case BT_PAIRING_ATTEMPT_COMPLETE:
            break;
        default:
            break;
    }
}

- (void) onPairingPincodeCallback
{
    const char* pin = [self.targetPin cStringUsingEncoding:NSASCIIStringEncoding];
    int err = BTPairingAgentSetPincode(self.pairingAgent, self.device, pin);
    if (err != 0) {
        LogMsg("BTPairingAgentSetPincode error: 0x%x", err);
        return;
    }
    LogMsg("onPairingPincodeCallback: BTPairingAgentSetPincode(%s) OK", pin);
}

@end


const static int SessionReconnectInterval = 10;

/// session callback ///

int sessionEventCallback(BTSESSION session, BTSessionEvent sessionEvent, BTResult result, void* ctx)
{
    BluetoothContext* bc = (BluetoothContext*)ctx;
    assert(bc == g_bc);
    
    LogMsg("sessionEventCallback( session:%p, BTSessionEvent:%x, BTResult:%x, magic:%x )",
           session, sessionEvent, result, bc.magic);
    switch (sessionEvent) {
        case BTSessionEventConnectedSession:
            [bc onSessionConnected:session];
            break;
        case BTSessionEventDisconnectedSession:
            [NSTimer scheduledTimerWithTimeInterval:SessionReconnectInterval
                                             target:bc
                                           selector:@selector(reconnectSessionTimerProc:)
                                           userInfo:[NSDictionary 
                                                     dictionaryWithObject:[NSValue valueWithPointer:session]
                                                     forKey:BtSessionKey]
                                            repeats:NO];
             break;
        default:
            break;
    }
    
    return 0;
}

/// local device callback ///

void localStatusEventCallback(BTLOCALDEVICE* localDevice, BT_LOCAL_DEVICE_EVENT event, void* unk1, void* ctx)
{
    BluetoothContext* bc = (BluetoothContext*)ctx;
    assert(bc == g_bc);
    
    LogMsg("localStatusEventCallback(localdev:%p, event:%s, unk1:%p, ctx:%p)", 
           localDevice, LocalEventString(event), unk1, ctx);
    if (event == BT_LOCAL_DEVICE_POWER_STATE_CHANGED) {
        [bc onLocalPowerChanged];
    }
}

/// service callback ///

void serviceEventCallback(BTDEVICE device, BT_SERVICE_TYPE serviceType, SERVICE_EVENT_TYPE eventType, SERVICE_EVENT event, int result, void* ctx)
{
    BluetoothContext* bc = (BluetoothContext*)ctx;
    assert(bc == g_bc);
    
    LogMsg("serviceEventCallback( device:%p, service:%X, eventType:%i, event:%s, result:%i, magic:%x )",
           device, serviceType, eventType, ServiceEventString(event), result, bc.magic);

    if (device != [bc device]) {
        return;
    }
    if (eventType == SERVICE_EVENT_TYPE_CONNECTED && event == SERVICE_EVENT_CONNECTED) {
        [bc onServiceConnected:serviceType result:result];
    } else if (eventType == SERVICE_EVENT_TYPE_DISCONNECTED && event == SERVICE_EVENT_DISCONNECTION_RESULT) {
        [bc onServiceDisconnected:serviceType result:result];
    }

}

/// discovery callbacks ///

void discoveryStatusCallback(BTDISCOVERYAGENT agent, BT_DISCOVERY_STATUS status, BTDEVICE device, int result, void* ctx)
{
    BluetoothContext* bc = (BluetoothContext*)ctx;
    assert(bc == g_bc);
    
    LogMsg("discoveryStatusCallback( agent:%p, status:%s, magic: %x )", agent, DiscoveryStatusString(status), bc.magic);

    if (status == BT_DISCOVERY_STATUS_STARTED) {
        [bc onDiscoveryStarted];
    } else if (status == BT_DISCOVERY_STATUS_FINISHED) {
        [bc onDiscoveryStopped];	
    }
}

void discoveryEventCallback(BTDISCOVERYAGENT agent, BT_DISCOVERY_EVENT event, 
                            BTDEVICE device, BTDeviceAttributes attr, void* ctx)
{
    BluetoothContext* bc = (BluetoothContext*)ctx;
    assert(bc == g_bc);

    LogMsg("discoveryEventCallback( agent:%p, event:%s, device:%p, attr:%x )", agent, DiscoveryEventString(event), device, attr);

    [bc onDiscoveryFoundDevice:device];
}

/// pairing callbacks ///

void pairingAgentStatusCallback(PAIRING_AGENT agent, BT_PAIRING_AGENT_STATUS status, BTDEVICE device, int PairingResult, void* ctx) 
{
    BluetoothContext* bc = (BluetoothContext*) ctx;
    assert(bc == g_bc);
    
    LogMsg("pairingAgentStatusCallback( agent:%p, status:%s, device:%p, PairingResult:%i, magic:%x )", 
           agent, PairingStatusString(status), device, PairingResult, bc.magic);
    
    [bc onPairingStatus:status];
    return;
}

void pairingPincodeCallback(PAIRING_AGENT agent, BTDEVICE device, uint8_t unk1, void* ctx) 
{
    BluetoothContext* bc = (BluetoothContext*) ctx;
    assert(bc == g_bc);
    LogMsg("pairingPincodeCallback( agent:%p, device:%p, unk1:%x, magic:%x )", agent, device, unk1, bc.magic);

    [bc onPairingPincodeCallback];
    return;
}

void pairingAuthorizationCallback(PAIRING_AGENT agent, BTDEVICE device, BTServiceMask serviceMask, void* ctx) 
{
    LogMsg("pairingAuthorizationCallback");
    return;
}

void pairingUserConfirmationCallback(PAIRING_AGENT agent, BTDEVICE device, uint32_t unk1, BTBool unk2, void* ctx) 
{
    LogMsg("pairingUserConfirmationCallback");
    return;
}

void pairingPasskeyDisplayCallback(PAIRING_AGENT agent, BTDEVICE device, uint32_t unk1, void* ctx) 
{
    LogMsg("pairingPasskeyDisplayCallback");
    return;
}
