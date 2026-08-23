
#import "AppDelegate.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // containsObject: so sánh NSRunningApplication với NSString sẽ luôn NO,
    // khiến điều kiện !NO = YES luôn đúng -> helper cứ mở lại MacKey.app mỗi
    // lần chạy dù app đã đang chạy sẵn. Dùng đúng API tra theo bundle identifier.
    NSArray<NSRunningApplication *> *runningApp =
        [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.dinhphu.mackey"];
    if (runningApp.count == 0) {
        NSString* path = [[NSBundle mainBundle] bundlePath];
        for (int i = 0; i < 4; i++)
            path = [path stringByDeletingLastPathComponent];
        [[NSWorkspace sharedWorkspace] launchApplication:path];
    }
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
