
#ifndef MacKeyManager_h
#define MacKeyManager_h

#import <Cocoa/Cocoa.h>

typedef void (^CheckNewVersionCallback)(void);

@interface MacKeyManager : NSObject
+(BOOL)isInited;
+(BOOL)initEventTap;
+(BOOL)stopEventTap;
+(void)reEnableEventTap;

+(NSArray*)getTableCodes;

+(NSString*)getBuildDate;
+(void)showMessage:(NSWindow*)window message:(NSString*)msg subMsg:(NSString*)subMsg;

+(BOOL)quickConvert;

+(void)checkNewVersion:(NSWindow*)parent callbackFunc:(CheckNewVersionCallback) callback;
@end

// Khóa bảo vệ state toàn cục của engine (vLanguage, vCodeTable, vSwitchKeyStatus...)
// vốn được đọc trong MacKeyCallback (xử lý mỗi lần gõ phím) và ghi từ các màn hình
// Cài đặt. Hiện tại cả hai phía đều chạy trên main thread nên chưa có race thật,
// nhưng khóa (recursive, an toàn khi gọi lồng nhau trên cùng thread) giúp phòng
// ngừa nếu sau này việc xử lý phím được chuyển sang thread riêng.
#ifdef __cplusplus
extern "C" {
#endif
void MacKeyStateLock(void);
void MacKeyStateUnlock(void);
#ifdef __cplusplus
}
#endif

#endif /* MacKeyManager_h */
