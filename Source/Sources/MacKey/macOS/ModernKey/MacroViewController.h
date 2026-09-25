
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MacroViewController : NSViewController<NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate>
@property (weak) IBOutlet NSTableView *tableView;
@property (weak) IBOutlet NSTextField *macroName;
@property (weak) IBOutlet NSTextField *macroContent;

@property (weak) IBOutlet NSButton *buttonAdd;
@property (weak) IBOutlet NSButton *buttonDelete;
@property (strong, nonatomic) NSButton *buttonAddNew;
@property (weak) IBOutlet NSButton *AutoCapsMacro;

- (IBAction)onAddNewMacro:(id)sender;
- (IBAction)onDeleteAllMacros:(id)sender;

+ (NSUInteger)currentMacroCount;
+ (void)resetAllMacroData;
+ (NSImage *)trashIcon;
+ (NSImage *)warningSquircleIcon;
+ (NSImage *)successIcon;

+ (NSAlert *)styledAlertWithTitle:(nullable NSString *)title
                          message:(nullable NSString *)msg
                             icon:(nullable NSImage *)icon
                            style:(NSAlertStyle)style
                     buttonTitles:(NSArray<NSString *> *)buttonTitles;

@end

NS_ASSUME_NONNULL_END
