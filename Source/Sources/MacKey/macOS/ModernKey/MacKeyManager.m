
#import "MacKeyManager.h"
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
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:msg];
    [alert setInformativeText:subMsg];
    [alert addButtonWithTitle:@"OK"];
    if (window) {
        [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
        }];
    } else {
        [alert runModal];
    }
}

#pragma mark -AutoUpdate feature

+(void)checkNewVersion:(NSWindow*)parent callbackFunc:(CheckNewVersionCallback) callback {
    //load new version config
    NSURLSession *aSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    [[aSession dataTaskWithURL:[NSURL URLWithString:@"https://raw.githubusercontent.com/dinhphu-0124/MacKey/main/Source/version.json"] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        // callback phải LUÔN được gọi đúng 1 lần, kể cả khi request thất bại
        // (mất mạng, DNS lỗi, status khác 200, JSON hỏng...). Trước đây chỉ
        // gọi ở nhánh thành công, khiến nút "Kiểm tra bản mới" ở UI kẹt vĩnh
        // viễn vì nó chỉ tự bật lại bên trong callback.
        BOOL checkSucceeded = NO;
        BOOL needUpdating = NO;
        NSString *versionName = nil;

        if (((NSHTTPURLResponse *)response).statusCode == 200 && data) {
            NSError *jsonError = nil;
            id object = [NSJSONSerialization JSONObjectWithData:data
                                                          options:0
                                                            error:&jsonError];
            if (!jsonError && [object isKindOfClass:[NSDictionary class]]) {
                NSDictionary *results = object;
                NSDictionary *ver = [results valueForKey:@"latestVersion"];
                NSString *versionCodeString = [ver valueForKey:@"versionCode"];
                int versionCode = (int)[versionCodeString integerValue];
                int currentVersionCode = (int)[((NSString*)[[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleVersion"]) integerValue];
                needUpdating = versionCode > currentVersionCode;
                versionName = [ver valueForKey:@"versionName"];
                checkSucceeded = YES;
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (callback != nil) {
                callback();
            }
            if (!checkSucceeded && callback != nil) {
                // Chỉ báo lỗi khi người dùng chủ động bấm "Kiểm tra bản mới"
                // (callback != nil); lúc tự kiểm tra ngầm khi khởi động thì im
                // lặng như trước, tránh phiền người dùng mỗi lần mất mạng.
                [self showMessage:parent
                           message:@"Không thể kiểm tra bản cập nhật"
                            subMsg:@"Vui lòng kiểm tra kết nối mạng và thử lại."];
            } else if (needUpdating || callback != nil) {
                [self showUpdateMessage:parent needUpdating:needUpdating newVersion:versionName];
            }
        });
    }] resume];
}

+(void)showUpdateMessage:(NSWindow*)parent needUpdating:(BOOL)needUpdating newVersion:(NSString*)versionString {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:(needUpdating ? [NSString stringWithFormat:@"MacKey Có phiên bản mới (%@), bạn có muốn cập nhật không?", versionString] : @"Bạn đang dùng phiên bản mới nhất!")];
    [alert setInformativeText:(needUpdating ? @"Bấm 'Có' để cập nhật MacKey." : @"")];
    
    if (!needUpdating) {
        [alert addButtonWithTitle:@"OK"];
    } else {
        [alert addButtonWithTitle:@"Có"];
        [alert addButtonWithTitle:@"Không"];
    }
    if (parent == nil) {
        [alert.window makeKeyAndOrderFront:nil];
        [alert.window setLevel:NSStatusWindowLevel];
        NSModalResponse res = [alert runModal];
        if (res == 1000 && needUpdating) {
            [self launchUpdateHelper];
        }
    } else {
        [alert beginSheetModalForWindow:parent completionHandler:^(NSModalResponse returnCode) {
            if (returnCode == 1000 && needUpdating) {
                [self launchUpdateHelper];
            }
        }];
    }
}

+(void)launchUpdateHelper {
    //check update app has exist or not
    NSError *copyError = nil;
    NSString* target = [NSString stringWithFormat:@"%@/MacKeyUpdate.app", [self getApplicationSupportFolder]];
    [[NSFileManager defaultManager] removeItemAtPath:target error:&copyError];
    if (![[NSFileManager defaultManager] fileExistsAtPath:target]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:[self getApplicationSupportFolder] withIntermediateDirectories:YES attributes:nil error:nil];

        if (![[NSFileManager defaultManager] copyItemAtPath:[self getUpdateBundlePath] toPath:target error:&copyError]) {
            NSLog(@"Error on copy");
        }
    }

    // Bản build này không đóng gói MacKeyUpdate.app (xem README), nên không
    // được phép thoát ứng dụng nếu helper cập nhật không thực sự tồn tại —
    // trước đây làm vậy khiến MacKey tự tắt mà không cập nhật được gì.
    if (![[NSFileManager defaultManager] fileExistsAtPath:target]) {
        [self showMessage:nil
                   message:@"Không thể tự cập nhật"
                    subMsg:@"Bản này chưa hỗ trợ tự cập nhật. Vui lòng tải bản mới thủ công."];
        return;
    }

    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    NSURL *url = [NSURL fileURLWithPath:[workspace fullPathForApplication:target]];
    NSWorkspaceOpenConfiguration *configuration = [NSWorkspaceOpenConfiguration configuration];
    configuration.arguments = @[@"yeah"];

    [workspace openApplicationAtURL:url
                       configuration:configuration
                   completionHandler:^(NSRunningApplication * _Nullable app, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (app && !error) {
                [NSApp terminate:0]; //exit main app so the update helper can replace it
            } else {
                [self showMessage:nil
                           message:@"Không thể tự cập nhật"
                            subMsg:@"Vui lòng tải bản mới thủ công."];
            }
        });
    }];
}

+(NSString*)getApplicationSupportFolder {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *applicationSupportDirectory = [paths firstObject];
    return [NSString stringWithFormat:@"%@/MacKey", applicationSupportDirectory];
}

+(NSString*)getUpdateBundlePath {
    NSString *currentpath = [[NSBundle mainBundle] bundlePath];
    return [NSString stringWithFormat:@"%@/Contents/Library/LoginItems/MacKeyUpdate.app", currentpath];
}
@end
