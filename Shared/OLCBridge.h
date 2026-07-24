#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

void WLOLCConfigure(BOOL debugEnabled,
                    NSInteger livenessIntervalMs,
                    NSInteger livenessTimeoutMs,
                    NSInteger failures,
                    NSInteger vp8FPS,
                    NSInteger vp8BatchSize,
                    NSString *dnsServer);

BOOL WLOLCStart(NSString *provider,
                NSString *transport,
                NSString *room,
                NSString *clientID,
                NSString *keyHex,
                NSInteger socksPort,
                NSString *socksUser,
                NSString *socksPassword,
                NSError **error);

BOOL WLOLCWaitReady(NSInteger timeoutMs, NSError **error);
void WLOLCStop(void);
BOOL WLOLCIsRunning(void);

int64_t WLOLCCheck(NSString *provider,
                   NSString *transport,
                   NSString *room,
                   NSString *clientID,
                   NSString *keyHex,
                   NSInteger socksPort,
                   NSInteger timeoutMs,
                   NSInteger vp8FPS,
                   NSInteger vp8BatchSize,
                   NSError **error);

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
                  NSError **error);

NSString *WLOLCLogs(void);
void WLOLCClearLogs(void);

NS_ASSUME_NONNULL_END
