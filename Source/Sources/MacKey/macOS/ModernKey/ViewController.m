
#import "ViewController.h"
#import "AppDelegate.h"
#import "MyTextField.h"
#import "MacKeyManager.h"
#import "MacroViewController.h"

extern AppDelegate *appDelegate;
extern void OnSpellCheckingChanged(void);

ViewController *viewController;
extern int vFreeMark;
extern int vCheckSpelling;
extern int vUseModernOrthography;
extern int vSwitchKeyStatus;
extern int vQuickTelex;
extern int vRestoreIfWrongSpelling;
extern int vUseMacro;
extern int vUseMacroInEnglishMode;
extern int vSuggestMacro;
extern int vUpperCaseFirstChar;
extern int vTempOffSpelling;
extern int vAllowConsonantZFWJ;
extern int vQuickStartConsonant;
extern int vQuickEndConsonant;
extern int vShowIconOnDock;
extern int vAutoCapsMacro;
extern int vPerformLayoutCompat;

@implementation ViewController {
  __weak IBOutlet NSButton *CustomSwitchCommand;
  __weak IBOutlet NSButton *CustomSwitchOption;
  __weak IBOutlet NSButton *CustomSwitchControl;
  __weak IBOutlet NSButton *CustomSwitchShift;
  __weak IBOutlet MyTextField *CustomSwitchKey;
  __weak IBOutlet NSButton *CustomBeepSound;
  NSArray *tabviews, *tabbuttons;
  NSRect tabViewRect;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  viewController = self;
  CustomSwitchKey.Parent = self;

  self.appOK.hidden = YES;
  self.permissionWarning.hidden = YES;
  self.retryButton.enabled = NO;

  NSRect parentRect = self.viewParent.frame;
  parentRect.size.width = 640;
  parentRect.size.height = 540;
  self.viewParent.frame = parentRect;

  // set correct tabgroup
  tabviews =
      [NSArray arrayWithObjects:self.tabviewPrimary, self.tabviewMacro,
                                self.tabviewSystem, self.tabviewInfo, nil];
  tabbuttons =
      [NSArray arrayWithObjects:self.tabbuttonPrimary, self.tabbuttonMacro,
                                self.tabbuttonSystem, self.tabbuttonInfo, nil];

  // Dùng icon SF Symbol chuẩn macOS thay cho icon cũ không đúng ngữ nghĩa
  // (NSQuickLookTemplate / NSTouchBarTextListTemplate) hoặc icon bitmap đời cũ.
  if (@available(macOS 11.0, *)) {
    self.tabbuttonPrimary.image =
        [NSImage imageWithSystemSymbolName:@"keyboard"
                   accessibilityDescription:@"Bộ gõ"];
    self.tabbuttonMacro.image =
        [NSImage imageWithSystemSymbolName:@"list.bullet.rectangle"
                   accessibilityDescription:@"Gõ tắt"];
    self.tabbuttonSystem.image =
        [NSImage imageWithSystemSymbolName:@"gearshape"
                   accessibilityDescription:@"Hệ thống"];
    self.tabbuttonInfo.image =
        [NSImage imageWithSystemSymbolName:@"info.circle"
                   accessibilityDescription:@"Thông tin"];
  }

  tabViewRect = self.tabviewPrimary.frame;
  for (NSBox *b in tabviews) {
    b.frame = tabViewRect;
  }

  [self showTab:0];

  NSArray *inputTypeData =
      [[NSArray alloc] initWithObjects:@"Telex", @"VNI", @"Simple Telex", nil];
  NSArray *codeData = [MacKeyManager getTableCodes];

  // preset data
  [_popupInputType removeAllItems];
  [_popupInputType addItemsWithTitles:inputTypeData];

  [self.popupCode removeAllItems];
  [self.popupCode addItemsWithTitles:codeData];

  [self initKey];

  [self fillData];

  // set version info
  self.VersionInfo.stringValue = [NSString
      stringWithFormat:
          @"Phiên bản %@ (build %@) - Ngày cập nhật %@",
          [[NSBundle mainBundle]
              objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
          [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"],
          [MacKeyManager getBuildDate]];
}

- (void)viewDidAppear {
  [super viewDidAppear];
#ifdef DEBUG
  self.view.window.title = [NSString
      stringWithFormat:
          @"MacKey %@ [Debug UI Preview] - Bộ gõ Tiếng Việt",
          [[NSBundle mainBundle]
              objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
#else
  NSString *str = @"MacKey %@ - Bộ gõ Tiếng Việt";
  self.view.window.title = [NSString
      stringWithFormat:
          str, [[NSBundle mainBundle]
                   objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
#endif
}

- (void)viewWillAppear {
  [self initKey];
}

- (void)initKey {
  dispatch_async(dispatch_get_main_queue(), ^{
    if (![MacKeyManager initEventTap]) {
      // self.permissionWarning.hidden = NO;
      // self.retryButton.enabled = YES;
    } else {
      // self.appOK.hidden = NO;
    }
  });
}

- (void)setRepresentedObject:(id)representedObject {
  [super setRepresentedObject:representedObject];

  // Update the view, if already loaded.
}

- (void)showTab:(NSInteger)index {
  NSRect tempRect = tabViewRect;
  tempRect.origin.y = 1000;
  for (NSBox *b in tabviews) {
    [b setHidden:YES];
    b.frame = tempRect;
  }
  for (NSButton *b in tabbuttons) {
    [b setState:NSControlStateValueOff];
    b.wantsLayer = YES;
    b.layer.cornerRadius = 8.0;
    b.layer.backgroundColor = [NSColor clearColor].CGColor;
  }
  if (index >= 0 && index < tabviews.count) {
    NSBox *b = [tabviews objectAtIndex:index];
    [b setHidden:NO];
    b.frame = tabViewRect;

    NSButton *button = [tabbuttons objectAtIndex:index];
    [button setState:NSControlStateValueOn];
    button.wantsLayer = YES;
    button.layer.cornerRadius = 8.0;
    button.layer.backgroundColor =
        [NSColor colorWithWhite:1.0 alpha:0.15].CGColor;
  }
}

- (IBAction)onTabButton:(NSButton *)sender {
  [self showTab:sender.tag];
}

- (IBAction)onInputTypeChanged:(NSPopUpButton *)sender {
  [appDelegate
      onInputTypeSelectedIndex:(int)[self.popupInputType indexOfSelectedItem]];
}

- (IBAction)onCodeTableChanged:(NSPopUpButton *)sender {
  [appDelegate onCodeTableChanged:(int)[self.popupCode indexOfSelectedItem]];
}

- (IBAction)onLanguageChanged:(id)sender {
  [appDelegate onInputMethodSelected];
}

- (IBAction)onRestart:(id)sender {
  self.appOK.hidden = YES;
  self.permissionWarning.hidden = YES;
  self.retryButton.enabled = NO;

  [self initKey];
}

- (IBAction)onFreeMark:(NSButton *)sender {
  NSInteger val = [self setCustomValue:sender keyToSet:@"FreeMark"];
  MacKeyStateLock();
  vFreeMark = (int)val;
  MacKeyStateUnlock();
}

- (IBAction)onModernOrthography:(NSButton *)sender {
  NSInteger val = [self setCustomValue:sender keyToSet:@"ModernOrthography"];
  MacKeyStateLock();
  vUseModernOrthography = (int)val;
  MacKeyStateUnlock();
}

- (IBAction)onCheckSpelling:(NSButton *)sender {
  NSInteger val = [self setCustomValue:sender keyToSet:@"Spelling"];
  MacKeyStateLock();
  vCheckSpelling = (int)val;
  MacKeyStateUnlock();
  [self.RestoreIfInvalidWord setEnabled:val];
  [self.AllowZWJF setEnabled:val];
  [self.TempOffSpellChecking setEnabled:val];
  OnSpellCheckingChanged();
}

- (IBAction)onShowUIOnStartup:(NSButton *)sender {
  [self setCustomValue:sender keyToSet:@"ShowUIOnStartup"];
}

- (IBAction)onRunOnStartup:(NSButton *)sender {
  NSInteger val = [self setCustomValue:sender keyToSet:@"RunOnStartup"];
  [appDelegate setRunOnStartup:val];
}

- (IBAction)onGrayIcon:(id)sender {
  NSInteger val = [self setCustomValue:sender keyToSet:@"GrayIcon"];
  [appDelegate setGrayIcon:val];
}

- (IBAction)onQuickTelex:(id)sender {
  NSInteger val = [self setCustomValue:sender keyToSet:@"QuickTelex"];
  MacKeyStateLock();
  vQuickTelex = (int)val;
  MacKeyStateUnlock();
}

- (IBAction)onRestoreIfInvalidWord:(id)sender {
  NSInteger val = [self setCustomValue:sender keyToSet:@"RestoreIfInvalidWord"];
  MacKeyStateLock();
  vRestoreIfWrongSpelling = (int)val;
  MacKeyStateUnlock();
}

- (IBAction)onTempOffSpellChecking:(id)sender {
  NSInteger val = [self setCustomValue:sender keyToSet:@"vTempOffSpelling"];
  MacKeyStateLock();
  vTempOffSpelling = (int)val;
  MacKeyStateUnlock();
}

- (IBAction)onAllowZFWJ:(id)sender {
  NSInteger val = [self setCustomValue:sender keyToSet:@"vAllowConsonantZFWJ"];
  MacKeyStateLock();
  vAllowConsonantZFWJ = (int)val;
  MacKeyStateUnlock();
}

- (IBAction)onControlSwitchKey:(NSButton *)sender {
  NSInteger val = [self setCustomValue:sender keyToSet:nil];
  MacKeyStateLock();
  vSwitchKeyStatus &= (~0x100);
  vSwitchKeyStatus |= val << 8;
  MacKeyStateUnlock();
  [[NSUserDefaults standardUserDefaults] setInteger:vSwitchKeyStatus
                                             forKey:@"SwitchKeyStatus"];
}

- (IBAction)onOptionSwitchKey:(NSButton *)sender {
  NSInteger val = [self setCustomValue:sender keyToSet:nil];
  MacKeyStateLock();
  vSwitchKeyStatus &= (~0x200);
  vSwitchKeyStatus |= val << 9;
  MacKeyStateUnlock();
  [[NSUserDefaults standardUserDefaults] setInteger:vSwitchKeyStatus
                                             forKey:@"SwitchKeyStatus"];
}

- (IBAction)onCommandSwitchKey:(NSButton *)sender {
  NSInteger val = [self setCustomValue:sender keyToSet:nil];
  MacKeyStateLock();
  vSwitchKeyStatus &= (~0x400);
  vSwitchKeyStatus |= val << 10;
  MacKeyStateUnlock();
  [[NSUserDefaults standardUserDefaults] setInteger:vSwitchKeyStatus
                                             forKey:@"SwitchKeyStatus"];
}

- (IBAction)onShiftSwitchKey:(NSButton *)sender {
  NSInteger val = [self setCustomValue:sender keyToSet:nil];
  MacKeyStateLock();
  vSwitchKeyStatus &= (~0x800);
  vSwitchKeyStatus |= val << 11;
  MacKeyStateUnlock();
  [[NSUserDefaults standardUserDefaults] setInteger:vSwitchKeyStatus
                                             forKey:@"SwitchKeyStatus"];
}

- (void)onMyTextFieldKeyChange:(unsigned short)keyCode
                     character:(unsigned short)character {
  MacKeyStateLock();
  vSwitchKeyStatus &= 0xFFFFFF00;
  vSwitchKeyStatus |= keyCode;
  vSwitchKeyStatus &= 0x00FFFFFF;
  vSwitchKeyStatus |= ((unsigned int)character << 24);
  MacKeyStateUnlock();
  [[NSUserDefaults standardUserDefaults] setInteger:vSwitchKeyStatus
                                             forKey:@"SwitchKeyStatus"];
}

- (IBAction)onBeepSound:(NSButton *)sender {
  unsigned int val = (unsigned int)[self setCustomValue:sender keyToSet:nil];
  MacKeyStateLock();
  vSwitchKeyStatus &= (~0x8000);
  vSwitchKeyStatus |= val << 15;
  MacKeyStateUnlock();
  [[NSUserDefaults standardUserDefaults] setInteger:vSwitchKeyStatus
                                             forKey:@"SwitchKeyStatus"];
}

- (IBAction)onPerformLayoutCompat:(id)sender {
  NSInteger val = [self setCustomValue:sender keyToSet:@"vPerformLayoutCompat"];
  MacKeyStateLock();
  vPerformLayoutCompat = (int)val;
  MacKeyStateUnlock();
}

- (NSInteger)setCustomValue:(NSButton *)sender keyToSet:(NSString *)key {
  NSInteger val = 0;
  if (sender.state == NSControlStateValueOn) {
    val = 1;
  } else {
    val = 0;
  }
  if (key != nil)
    [[NSUserDefaults standardUserDefaults] setInteger:val forKey:key];
  return val;
}

- (IBAction)onMacroButton:(id)sender {
  [appDelegate onMacroSelected];
}

- (IBAction)onMacroChanged:(NSButton *)sender {
  NSInteger val = [self setCustomValue:sender keyToSet:@"UseMacro"];
  MacKeyStateLock();
  vUseMacro = (int)val;
  MacKeyStateUnlock();
}

- (IBAction)onUseMacroInEnglishModeChanged:(NSButton *)sender {
  NSInteger val = [self setCustomValue:sender
                              keyToSet:@"UseMacroInEnglishMode"];
  MacKeyStateLock();
  vUseMacroInEnglishMode = (int)val;
  MacKeyStateUnlock();
}

- (IBAction)onSuggestMacroChanged:(NSButton *)sender {
  NSInteger val = [self setCustomValue:sender keyToSet:@"suggestMacro"];
  MacKeyStateLock();
  vSuggestMacro = (int)val;
  MacKeyStateUnlock();
}

- (IBAction)onUpperCaseFirstChar:(NSButton *)sender {
  NSInteger val = [self setCustomValue:sender keyToSet:@"UpperCaseFirstChar"];
  MacKeyStateLock();
  vUpperCaseFirstChar = (int)val;
  MacKeyStateUnlock();
}
- (IBAction)onQuickStartConsonant:(id)sender {
  NSInteger val = [self setCustomValue:sender keyToSet:@"vQuickStartConsonant"];
  MacKeyStateLock();
  vQuickStartConsonant = (int)val;
  MacKeyStateUnlock();
}

- (IBAction)onQuickEndConsonant:(id)sender {
  NSInteger val = [self setCustomValue:sender keyToSet:@"vQuickEndConsonant"];
  MacKeyStateLock();
  vQuickEndConsonant = (int)val;
  MacKeyStateUnlock();
}

- (IBAction)onAutoCapsMacro:(id)sender {
  NSInteger val = [self setCustomValue:sender keyToSet:@"vAutoCapsMacro"];
  MacKeyStateLock();
  vAutoCapsMacro = (int)val;
  MacKeyStateUnlock();
}

- (IBAction)onShowIconOnDock:(id)sender {
  NSInteger val = [self setCustomValue:sender keyToSet:@"vShowIconOnDock"];
  vShowIconOnDock = (int)val;
  if (!vShowIconOnDock) {
    [self.view.window close];
  }
  [appDelegate showIconOnDock:vShowIconOnDock];
}

- (IBAction)onCheckNewVersionOnStartup:(NSButton *)sender {
  NSInteger val = sender.state == NSControlStateValueOn ? 0 : 1;
  [[NSUserDefaults standardUserDefaults] setInteger:val
                                             forKey:@"DontCheckUpdate"];
}

- (IBAction)onTerminateApp:(id)sender {
  [NSApp terminate:0];
}

- (void)fillData {
  NSInteger value;

  NSInteger intInputMethod =
      [[NSUserDefaults standardUserDefaults] integerForKey:@"InputMethod"];
  if (intInputMethod == 1) {
    self.VietButton.state = NSControlStateValueOn;
    self.EngButton.state = NSControlStateValueOff;
  } else {
    self.VietButton.state = NSControlStateValueOff;
    self.EngButton.state = NSControlStateValueOn;
  }

  NSInteger intInputType =
      [[NSUserDefaults standardUserDefaults] integerForKey:@"InputType"];
  [self.popupInputType selectItemAtIndex:intInputType];

  NSInteger intCodeTable =
      [[NSUserDefaults standardUserDefaults] integerForKey:@"CodeTable"];
  [self.popupCode selectItemAtIndex:intCodeTable];

  // option
  NSInteger showui =
      [[NSUserDefaults standardUserDefaults] integerForKey:@"ShowUIOnStartup"];
  self.ShowUIButton.state =
      showui ? NSControlStateValueOn : NSControlStateValueOff;

  NSInteger freeMark =
      [[NSUserDefaults standardUserDefaults] integerForKey:@"FreeMark"];
  self.FreeMarkButton.state =
      freeMark ? NSControlStateValueOn : NSControlStateValueOff;

  NSInteger useModernOrthography = [[NSUserDefaults standardUserDefaults]
      integerForKey:@"ModernOrthography"];
  self.UseModernOrthography.state =
      useModernOrthography ? NSControlStateValueOn : NSControlStateValueOff;

  NSInteger spelling =
      [[NSUserDefaults standardUserDefaults] integerForKey:@"Spelling"];
  self.CheckSpellingButton.state =
      spelling ? NSControlStateValueOn : NSControlStateValueOff;

  NSInteger runOnStartup =
      [[NSUserDefaults standardUserDefaults] integerForKey:@"RunOnStartup"];
  self.RunOnStartupButton.state =
      runOnStartup ? NSControlStateValueOn : NSControlStateValueOff;

  NSInteger useGrayIcon =
      [[NSUserDefaults standardUserDefaults] integerForKey:@"GrayIcon"];
  self.UseGrayIcon.state =
      useGrayIcon ? NSControlStateValueOn : NSControlStateValueOff;

  NSInteger quicTelex =
      [[NSUserDefaults standardUserDefaults] integerForKey:@"QuickTelex"];
  self.QuickTelex.state =
      quicTelex ? NSControlStateValueOn : NSControlStateValueOff;

  NSInteger restoreIfInvalidWord = [[NSUserDefaults standardUserDefaults]
      integerForKey:@"RestoreIfInvalidWord"];
  self.RestoreIfInvalidWord.state =
      restoreIfInvalidWord ? NSControlStateValueOn : NSControlStateValueOff;
  [self.RestoreIfInvalidWord setEnabled:spelling];

  NSInteger tempOffSpelling =
      [[NSUserDefaults standardUserDefaults] integerForKey:@"vTempOffSpelling"];
  self.TempOffSpellChecking.state =
      tempOffSpelling ? NSControlStateValueOn : NSControlStateValueOff;
  [self.TempOffSpellChecking setEnabled:spelling];

  NSInteger allowZFWJ = [[NSUserDefaults standardUserDefaults]
      integerForKey:@"vAllowConsonantZFWJ"];
  self.AllowZWJF.state =
      allowZFWJ ? NSControlStateValueOn : NSControlStateValueOff;
  [self.AllowZWJF setEnabled:spelling];

  NSInteger useMacro =
      [[NSUserDefaults standardUserDefaults] integerForKey:@"UseMacro"];
  self.UseMacro.state =
      useMacro ? NSControlStateValueOn : NSControlStateValueOff;

  NSInteger useMacroInEnglish = [[NSUserDefaults standardUserDefaults]
      integerForKey:@"UseMacroInEnglishMode"];
  self.UseMacroInEnglishMode.state =
      useMacroInEnglish ? NSControlStateValueOn : NSControlStateValueOff;

  NSInteger suggestMacro = 1;
  if ([[NSUserDefaults standardUserDefaults] objectForKey:@"suggestMacro"] != nil) {
    suggestMacro = [[NSUserDefaults standardUserDefaults] integerForKey:@"suggestMacro"];
  }
  self.SuggestMacro.state =
      suggestMacro ? NSControlStateValueOn : NSControlStateValueOff;

  NSInteger upperCaseFirstChar = [[NSUserDefaults standardUserDefaults]
      integerForKey:@"UpperCaseFirstChar"];
  self.UpperCaseFirstChar.state =
      upperCaseFirstChar ? NSControlStateValueOn : NSControlStateValueOff;

  NSInteger quickStartConsonant = [[NSUserDefaults standardUserDefaults]
      integerForKey:@"vQuickStartConsonant"];
  self.QuickStartConsonant.state =
      quickStartConsonant ? NSControlStateValueOn : NSControlStateValueOff;

  NSInteger quickEndConsonant = [[NSUserDefaults standardUserDefaults]
      integerForKey:@"vQuickEndConsonant"];
  self.QuickEndConsonant.state =
      quickEndConsonant ? NSControlStateValueOn : NSControlStateValueOff;

  value =
      [[NSUserDefaults standardUserDefaults] integerForKey:@"vAutoCapsMacro"];
  self.AutoCapsMacro.state =
      value ? NSControlStateValueOn : NSControlStateValueOff;

  value =
      [[NSUserDefaults standardUserDefaults] integerForKey:@"vShowIconOnDock"];
  self.ShowIconOnDock.state =
      value ? NSControlStateValueOn : NSControlStateValueOff;

  value =
      [[NSUserDefaults standardUserDefaults] integerForKey:@"DontCheckUpdate"];
  self.CheckNewVersionOnStartup.state =
      value ? NSControlStateValueOff : NSControlStateValueOn;

  value = [[NSUserDefaults standardUserDefaults]
      integerForKey:@"vPerformLayoutCompat"];
  self.PerformLayoutCompat.state =
      value ? NSControlStateValueOn : NSControlStateValueOff;

  CustomSwitchControl.state = (vSwitchKeyStatus & 0x100)
                                  ? NSControlStateValueOn
                                  : NSControlStateValueOff;
  CustomSwitchOption.state = (vSwitchKeyStatus & 0x200)
                                 ? NSControlStateValueOn
                                 : NSControlStateValueOff;
  CustomSwitchCommand.state = (vSwitchKeyStatus & 0x400)
                                  ? NSControlStateValueOn
                                  : NSControlStateValueOff;
  CustomSwitchShift.state = (vSwitchKeyStatus & 0x800) ? NSControlStateValueOn
                                                       : NSControlStateValueOff;
  CustomBeepSound.state = (vSwitchKeyStatus & 0x8000) ? NSControlStateValueOn
                                                      : NSControlStateValueOff;
  [CustomSwitchKey setTextByKeyCode:(vSwitchKeyStatus & 0xFF)
                          character:((vSwitchKeyStatus >> 24) & 0xFF)];
}

- (IBAction)onOK:(id)sender {
  [self.view.window close];
}

- (IBAction)onDefaultConfig:(id)sender {
  NSUInteger macroCount = [MacroViewController currentMacroCount];
  NSString *macroWarning = @"";
  if (macroCount > 0) {
    macroWarning = [NSString stringWithFormat:@" và XOÁ SẠCH TOÀN BỘ %lu từ gõ tắt hiện có", (unsigned long)macroCount];
  } else {
    macroWarning = @" và xoá sạch toàn bộ dữ liệu gõ tắt";
  }

  NSString *msg = [NSString stringWithFormat:@"Thao tác này sẽ đưa tất cả thiết lập về trạng thái mặc định ban đầu%@.\n\nThao tác này không thể hoàn tác. Bạn có chắc chắn muốn tiếp tục?", macroWarning];

  NSAlert *alert = [MacroViewController styledAlertWithTitle:@"Khôi phục cài đặt gốc?"
                                                     message:msg
                                                        icon:[MacroViewController warningSquircleIcon]
                                                       style:NSAlertStyleInformational
                                                buttonTitles:@[@"Khôi phục & Xoá", @"Huỷ"]];
  [alert beginSheetModalForWindow:self.view.window
                completionHandler:^(NSModalResponse returnCode) {
                  if (returnCode == NSAlertFirstButtonReturn) {
                    // 1. Khôi phục toàn bộ thiết lập bộ gõ mặc định
                    [appDelegate loadDefaultConfig];

                    // 2. Xóa sạch dữ liệu gõ tắt
                    [MacroViewController resetAllMacroData];

                    // 3. Đưa các công tắc hệ thống về mặc định
                    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"ShowUIOnStartup"];
                    self.ShowUIButton.state = NSControlStateValueOff;

                    [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:@"RunOnStartup"];
                    self.RunOnStartupButton.state = NSControlStateValueOn;

                    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"DontCheckUpdate"];
                    self.CheckNewVersionOnStartup.state = NSControlStateValueOn;

                    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"vPerformLayoutCompat"];
                    self.PerformLayoutCompat.state = NSControlStateValueOff;

                    // 4. Reset công cụ chuyển mã
                    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"convertToolToAllCaps"];
                    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"convertToolToAllNonCaps"];
                    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"convertToolToCapsFirstLetter"];
                    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"convertToolToCapsEachWord"];
                    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"convertToolRemoveMark"];
                    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"convertToolFromCode"];
                    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"convertToolToCode"];
                    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"convertToolHotKey"];
                    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"convertToolDontAlertWhenCompleted"];

                    // 5. Cập nhật lại toàn bộ giao diện bảng điều khiển
                    [self fillData];

                    // 6. Hiển thị thông báo xác nhận thành công
                    NSAlert *successAlert = [MacroViewController styledAlertWithTitle:@"Khôi phục thành công"
                                                                              message:@"Đã đưa tất cả cài đặt về mặc định ban đầu và xoá toàn bộ dữ liệu gõ tắt."
                                                                                 icon:[MacroViewController successIcon]
                                                                                style:NSAlertStyleInformational
                                                                         buttonTitles:@[@"OK"]];
                    [successAlert beginSheetModalForWindow:self.view.window completionHandler:nil];
                  }
                }];
}

- (IBAction)onHomePageLink:(id)sender {
  [[NSWorkspace sharedWorkspace]
      openURL:[NSURL URLWithString:@"https://open-key.org"]];
}

- (IBAction)onFanpageLink:(id)sender {
  [[NSWorkspace sharedWorkspace]
      openURL:[NSURL URLWithString:@"https://github.com/dinhphu-0124/MacKey"]];
}

- (IBAction)onEmailLink:(id)sender {
  [[NSWorkspace sharedWorkspace]
      openURL:[NSURL URLWithString:@"mailto:dinhphuhcmus15@gmail.com"]];
}

- (IBAction)onSourceCode:(id)sender {
  [[NSWorkspace sharedWorkspace]
      openURL:[NSURL URLWithString:@"https://github.com/dinhphu-0124/MacKey"]];
}

- (IBAction)onCheckNewVersionButton:(id)sender {
  self.CheckNewVersionButton.title = @"Đang kiểm tra...";
  self.CheckNewVersionButton.enabled = false;

  [MacKeyManager checkNewVersion:self.view.window
                     callbackFunc:^{
                       self.CheckNewVersionButton.enabled = true;
                       self.CheckNewVersionButton.title =
                           @"Kiểm tra bản mới...";
                     }];
}

@end
