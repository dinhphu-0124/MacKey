
#import "MacKeyManager.h"
#import "MacroViewController.h"
#import <pthread.h>

extern void MacKeyInit(void);

extern CGEventRef MacKeyCallback(CGEventTapProxy proxy,
                                  CGEventType type,
                                  CGEventRef event,
                                  void *refcon);

extern NSString* ConvertUtil(NSString* str);

@interface MacKeyManager ()

@end

@implementation MacKeyManager {

}
static BOOL _isInited = NO;

static CFMachPortRef      eventTap;
static CGEventMask        eventMask;
static CFRunLoopSourceRef runLoopSource;

// Recursive mutex bảo vệ state toàn cục của engine, xem giải thích ở MacKeyManager.h.
static pthread_mutex_t _stateMutex;
static dispatch_once_t _stateMutexOnceToken;

void MacKeyStateLock(void) {
    dispatch_once(&_stateMutexOnceToken, ^{
        pthread_mutexattr_t attr;
        pthread_mutexattr_init(&attr);
        pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
        pthread_mutex_init(&_stateMutex, &attr);
        pthread_mutexattr_destroy(&attr);
    });
    pthread_mutex_lock(&_stateMutex);
}

void MacKeyStateUnlock(void) {
    pthread_mutex_unlock(&_stateMutex);
}

+(BOOL)isInited {
    return _isInited;
}

+(BOOL)initEventTap {
#ifdef DEBUG
    // In DEBUG mode, do NOT hook keyboard events or start Telex engine
    // to allow safe UI editing and previewing without conflicting with /Applications/MacKey.app
    return YES;
#else
    if (_isInited)
        return true;
    
    //init modernKey
    MacKeyInit();
    
    // Create an event tap. We are interested in key presses.
    eventMask = ((1 << kCGEventKeyDown) |
                 (1 << kCGEventKeyUp) |
                 (1 << kCGEventFlagsChanged) |
                 (1 << kCGEventLeftMouseDown) |
                 (1 << kCGEventRightMouseDown) |
                 (1 << kCGEventLeftMouseDragged) |
                 (1 << kCGEventRightMouseDragged));
    
    eventTap = CGEventTapCreate(kCGSessionEventTap,
                                kCGHeadInsertEventTap,
                                0,
                                eventMask,
                                MacKeyCallback,
                                NULL);
    
    if (!eventTap) {
        
        fprintf(stderr, "failed to create event tap\n");
        return NO;
    }
    
    _isInited = YES;
    
    // Create a run loop source.
    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
    
    // Add to the current run loop.
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
    
    // Enable the event tap.
    CGEventTapEnable(eventTap, true);

    return YES;
#endif
}

+(void)reEnableEventTap {
    // macOS tự tắt event tap khi callback xử lý chậm (timeout) hoặc khi có
    // app khác bật Secure Input (kCGEventTapDisabledByTimeout /
    // kCGEventTapDisabledByUserInput). Phải chủ động bật lại, nếu không
    // MacKey sẽ mất khả năng gõ vĩnh viễn cho tới khi khởi động lại app.
    if (eventTap) {
        CGEventTapEnable(eventTap, true);
    }
}

+(BOOL)stopEventTap {
    if (_isInited) { //release all object
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
        CFRelease(runLoopSource);
        runLoopSource = nil;
        
        CFMachPortInvalidate(eventTap);
        CFRelease(eventTap);
        eventTap = nil;
        
        _isInited = false;
    }
    return YES;
}

+(NSArray*)getTableCodes {
    return [[NSArray alloc] initWithObjects:
            @"Unicode",
            @"TCVN3 (ABC)",
            @"VNI Windows",
            @"Unicode tổ hợp",
            @"Vietnamese Locale CP 1258", nil];
}

+(NSString*)getBuildDate {
    return [NSString stringWithUTF8String:__DATE__];
}

#pragma mark -Convert feature
+(BOOL)quickConvert {
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    NSString *htmlString = [pasteboard stringForType:NSPasteboardTypeHTML];
    NSString *rawString = [pasteboard stringForType:NSPasteboardTypeString];
    bool converted = false;
    if (htmlString != nil) {
        htmlString = ConvertUtil(htmlString);
        converted = true;
    }
    if (rawString != nil) {
        rawString = ConvertUtil(rawString);
        converted = true;
    }
    if (converted) {
        [pasteboard clearContents];
        if (htmlString != nil)
            [pasteboard setString:htmlString forType:NSPasteboardTypeHTML];
        if (rawString != nil)
            [pasteboard setString:rawString forType:NSPasteboardTypeString];
        
        return YES;
    }
    return NO;
}

+(void)showMessage:(NSWindow*)window message:(NSString*)msg subMsg:(NSString*)subMsg {
    NSAlert *alert = [MacroViewController styledAlertWithTitle:msg
                                                       message:subMsg
                                                          icon:nil
                                                         style:NSAlertStyleInformational
                                                  buttonTitles:@[@"OK"]];
    if (window) {
        [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
        }];
    } else {
        [alert runModal];
    }
}

#pragma mark - AutoUpdate feature

+ (BOOL)isRemoteVersion:(NSString *)remoteVer newerThanCurrent:(NSString *)currentVer {
    if (!remoteVer || remoteVer.length == 0) return NO;
    if (!currentVer || currentVer.length == 0) return YES;
    
    NSString *cleanCur = [currentVer stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([cleanCur hasPrefix:@"v"] || [cleanCur hasPrefix:@"V"]) {
        cleanCur = [cleanCur substringFromIndex:1];
    }
    NSString *cleanRem = [remoteVer stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([cleanRem hasPrefix:@"v"] || [cleanRem hasPrefix:@"V"]) {
        cleanRem = [cleanRem substringFromIndex:1];
    }
    
    NSArray *curParts = [cleanCur componentsSeparatedByString:@"."];
    NSArray *remParts = [cleanRem componentsSeparatedByString:@"."];
    NSInteger maxLen = MAX(curParts.count, remParts.count);
    for (NSInteger i = 0; i < maxLen; i++) {
        NSInteger cVal = (i < curParts.count) ? [curParts[i] integerValue] : 0;
        NSInteger rVal = (i < remParts.count) ? [remParts[i] integerValue] : 0;
        if (rVal > cVal) return YES;
        if (rVal < cVal) return NO;
    }
    return NO;
}

+ (void)checkNewVersion:(NSWindow*)parent callbackFunc:(CheckNewVersionCallback)callback {
    NSString *currentVer = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"1.0.2";
    
    NSURL *githubAPIUrl = [NSURL URLWithString:@"https://api.github.com/repos/dinhphu-0124/MacKey/releases/latest"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:githubAPIUrl
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:10.0];
    [request setValue:@"MacKey-App" forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"application/vnd.github.v3+json" forHTTPHeaderField:@"Accept"];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        BOOL checkSucceeded = NO;
        BOOL needUpdating = NO;
        NSString *remoteVersion = nil;
        NSString *htmlUrl = nil;
        NSString *downloadUrl = nil;
        
        NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
        if (httpResp && httpResp.statusCode == 200 && data) {
            NSError *jsonErr = nil;
            NSDictionary *releaseDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
            if (!jsonErr && [releaseDict isKindOfClass:[NSDictionary class]]) {
                remoteVersion = releaseDict[@"tag_name"] ?: releaseDict[@"name"];
                htmlUrl = releaseDict[@"html_url"];
                
                NSArray *assets = releaseDict[@"assets"];
                if ([assets isKindOfClass:[NSArray class]]) {
                    for (NSDictionary *asset in assets) {
                        NSString *name = asset[@"name"];
                        if ([name hasSuffix:@".dmg"]) {
                            downloadUrl = asset[@"browser_download_url"];
                            break;
                        }
                    }
                    if (!downloadUrl) {
                        for (NSDictionary *asset in assets) {
                            NSString *name = asset[@"name"];
                            if ([name hasSuffix:@".zip"]) {
                                downloadUrl = asset[@"browser_download_url"];
                                break;
                            }
                        }
                    }
                }
                if (!downloadUrl) {
                    downloadUrl = htmlUrl ?: @"https://github.com/dinhphu-0124/MacKey/releases";
                }
                
                needUpdating = [self isRemoteVersion:remoteVersion newerThanCurrent:currentVer];
                checkSucceeded = YES;
            }
        }
        
        // If GitHub Releases API failed (status code != 200, rate limited, or connection error),
        // fallback to raw version.json on main branch
        if (!checkSucceeded) {
            NSURL *fallbackUrl = [NSURL URLWithString:@"https://raw.githubusercontent.com/dinhphu-0124/MacKey/main/Source/version.json"];
            NSURLRequest *fbReq = [NSURLRequest requestWithURL:fallbackUrl
                                                   cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                               timeoutInterval:10.0];
            [[session dataTaskWithRequest:fbReq completionHandler:^(NSData *fbData, NSURLResponse *fbResp, NSError *fbErr) {
                BOOL fbSuccess = NO;
                BOOL fbNeedUpdate = NO;
                NSString *fbVerName = nil;
                
                NSHTTPURLResponse *fbHttp = (NSHTTPURLResponse *)fbResp;
                if (fbHttp && fbHttp.statusCode == 200 && fbData) {
                    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:fbData options:0 error:nil];
                    if ([json isKindOfClass:[NSDictionary class]]) {
                        NSDictionary *latest = json[@"latestVersion"];
                        if ([latest isKindOfClass:[NSDictionary class]]) {
                            fbVerName = latest[@"versionName"];
                            NSString *codeStr = latest[@"versionCode"];
                            int versionCode = (int)[codeStr integerValue];
                            int curCode = (int)[((NSString*)[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]) integerValue];
                            
                            fbNeedUpdate = [self isRemoteVersion:fbVerName newerThanCurrent:currentVer] || (versionCode > curCode);
                            fbSuccess = YES;
                        }
                    }
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (callback) callback();
                    if (!fbSuccess && callback) {
                        [self showMessage:parent
                                  message:@"Không thể kiểm tra bản cập nhật"
                                   subMsg:@"Không thể kết nối đến GitHub để đối chiếu phiên bản mới. Vui lòng kiểm tra lại kết nối mạng."];
                    } else if (fbNeedUpdate || callback != nil) {
                        [self showUpdateMessage:parent
                                   needUpdating:fbNeedUpdate
                                     currentVer:currentVer
                                      remoteVer:fbVerName ?: currentVer
                                    downloadUrl:@"https://github.com/dinhphu-0124/MacKey/releases"
                                     releaseUrl:@"https://github.com/dinhphu-0124/MacKey/releases"];
                    }
                });
            }] resume];
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (callback) callback();
            if (needUpdating || callback != nil) {
                [self showUpdateMessage:parent
                           needUpdating:needUpdating
                             currentVer:currentVer
                              remoteVer:remoteVersion ?: currentVer
                            downloadUrl:downloadUrl
                             releaseUrl:htmlUrl ?: @"https://github.com/dinhphu-0124/MacKey/releases"];
            }
        });
    }] resume];
}

+ (void)showUpdateMessage:(NSWindow*)parent
             needUpdating:(BOOL)needUpdating
               currentVer:(NSString*)currentVer
                remoteVer:(NSString*)remoteVer
              downloadUrl:(NSString*)downloadUrl
               releaseUrl:(NSString*)releaseUrl
{
    NSImage *icon = nil;
    if (@available(macOS 11.0, *)) {
        NSImageSymbolConfiguration *cfg = [NSImageSymbolConfiguration configurationWithPointSize:44 weight:NSFontWeightRegular];
        NSImage *sym = needUpdating ? [NSImage imageWithSystemSymbolName:@"arrow.down.circle" accessibilityDescription:nil]
                                    : [NSImage imageWithSystemSymbolName:@"checkmark.circle" accessibilityDescription:nil];
        if (sym) {
            icon = [sym imageWithSymbolConfiguration:cfg];
        }
    }
    
    NSString *cleanRemoteVer = remoteVer;
    if ([cleanRemoteVer hasPrefix:@"v"] || [cleanRemoteVer hasPrefix:@"V"]) {
        cleanRemoteVer = [cleanRemoteVer substringFromIndex:1];
    }
    
    NSString *title = nil;
    NSString *sub = nil;
    NSArray *btns = nil;
    
    if (needUpdating) {
        title = [NSString stringWithFormat:@"Đã có bản cập nhật mới (%@)", remoteVer];
        sub = [NSString stringWithFormat:@"Phiên bản hiện tại: %@\nPhiên bản mới nhất trên GitHub: %@\n\nBạn có muốn cập nhật phiên bản mới từ GitHub không?", currentVer, cleanRemoteVer];
        btns = @[@"Cập nhật ngay", @"Xem trên GitHub", @"Để sau"];
    } else {
        title = @"Bạn đang dùng bản mới nhất";
        sub = [NSString stringWithFormat:@"Phiên bản hiện tại (%@) đã là phiên bản mới nhất trên GitHub.", currentVer];
        btns = @[@"OK"];
    }
    
    NSAlert *alert = [MacroViewController styledAlertWithTitle:title
                                                       message:sub
                                                          icon:icon
                                                         style:NSAlertStyleInformational
                                                  buttonTitles:btns];
    
    void (^handleResponse)(NSModalResponse) = ^(NSModalResponse res) {
        if (!needUpdating) return;
        
        if (res == NSAlertFirstButtonReturn) {
            // "Cập nhật ngay": Open direct download URL (.dmg / .zip / release)
            NSString *target = downloadUrl ?: (releaseUrl ?: @"https://github.com/dinhphu-0124/MacKey/releases");
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:target]];
        } else if (res == NSAlertSecondButtonReturn) {
            // "Xem trên GitHub": Open GitHub Releases page
            NSString *target = releaseUrl ?: @"https://github.com/dinhphu-0124/MacKey/releases";
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:target]];
        }
    };
    
    if (parent == nil) {
        [alert.window makeKeyAndOrderFront:nil];
        [alert.window setLevel:NSStatusWindowLevel];
        NSModalResponse res = [alert runModal];
        handleResponse(res);
    } else {
        [alert beginSheetModalForWindow:parent completionHandler:^(NSModalResponse returnCode) {
            handleResponse(returnCode);
        }];
    }
}
@end
