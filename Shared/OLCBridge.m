#import "OLCBridge.h"
#import <Mobile/Mobile.h>

static NSMutableString *WLLogBuffer;
static NSObject *WLLogLock;
static const NSUInteger WLMaxLogLength = 262144;

@interface WLGoLogWriter : NSObject <MobileLogWriter>
@end

@implementation WLGoLogWriter
- (void)writeLog:(NSString *)message {
    if (message.length == 0) return;

    NSString *line = [NSString stringWithFormat:@"%@ %@",
                      [NSDate date].descriptionWithLocale,
                      message];

    @synchronized (WLLogLock) {
        [WLLogBuffer appendString:line];
        if (![line hasSuffix:@"\n"]) {
            [WLLogBuffer appendString:@"\n"];
        }

        if (WLLogBuffer.length > WLMaxLogLength) {
            NSUInteger removeLength = WLLogBuffer.length - WLMaxLogLength;
            [WLLogBuffer deleteCharactersInRange:NSMakeRange(0, removeLength)];
        }
    }

    NSLog(@"[olcRTC] %@", message);
}
@end

static WLGoLogWriter *WLWriter;

static void WLEnsureLogger(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        WLLogBuffer = [NSMutableString string];
        WLLogLock = [NSObject new];
        WLWriter = [WLGoLogWriter new];
        MobileSetLogWriter(WLWriter);
        MobileSetProviders();
    });
}

void WLOLCConfigure(BOOL debugEnabled,
                    NSInteger livenessIntervalMs,
                    NSInteger livenessTimeoutMs,
                    NSInteger failures,
                    NSInteger vp8FPS,
                    NSInteger vp8BatchSize,
                    NSString *dnsServer) {
    WLEnsureLogger();
    MobileSetDebug(debugEnabled);
    MobileSetSocksListenHost(@"127.0.0.1");
    MobileSetDNS(dnsServer);
    MobileSetLivenessOptions((long)livenessIntervalMs,
                             (long)livenessTimeoutMs,
                             (long)failures);
    MobileSetVP8Options((long)vp8FPS, (long)vp8BatchSize);
}

BOOL WLOLCStart(NSString *provider,
                NSString *transport,
                NSString *room,
                NSString *clientID,
                NSString *keyHex,
                NSInteger socksPort,
                NSString *socksUser,
                NSString *socksPassword,
                NSError **error) {
    WLEnsureLogger();
    return MobileStartWithTransport(provider,
                                    transport,
                                    room,
                                    clientID,
                                    keyHex,
                                    (long)socksPort,
                                    socksUser,
                                    socksPassword,
                                    error);
}

BOOL WLOLCWaitReady(NSInteger timeoutMs, NSError **error) {
    return MobileWaitReady((long)timeoutMs, error);
}

void WLOLCStop(void) {
    MobileStop();
}

BOOL WLOLCIsRunning(void) {
    return MobileIsRunning();
}

int64_t WLOLCCheck(NSString *provider,
                   NSString *transport,
                   NSString *room,
                   NSString *clientID,
                   NSString *keyHex,
                   NSInteger socksPort,
                   NSInteger timeoutMs,
                   NSInteger vp8FPS,
                   NSInteger vp8BatchSize,
                   NSError **error) {
    WLEnsureLogger();
    return MobileCheck(provider,
                       transport,
                       room,
                       clientID,
                       keyHex,
                       (long)socksPort,
                       (long)timeoutMs,
                       (long)vp8FPS,
                       (long)vp8BatchSize,
                       error);
}

int64_t WLOLCPing(NSString *provider,
                  NSString *transport,
                  NSString *room,
                  NSString *clientID,
                  NSString *keyHex,
                  NSInteger socksPort,
                  NSInteger timeoutMs,
                  NSString *pingURL,
                  NSInteger vp8FPS,
                  NSInteger vp8BatchSize,
                  NSError **error) {
    WLEnsureLogger();
    return MobilePing(provider,
                      transport,
                      room,
                      clientID,
                      keyHex,
                      (long)socksPort,
                      (long)timeoutMs,
                      pingURL,
                      (long)vp8FPS,
                      (long)vp8BatchSize,
                      error);
}

NSString *WLOLCLogs(void) {
    WLEnsureLogger();
    @synchronized (WLLogLock) {
        return [WLLogBuffer copy];
    }
}

void WLOLCClearLogs(void) {
    WLEnsureLogger();
    @synchronized (WLLogLock) {
        [WLLogBuffer setString:@""];
    }
}
