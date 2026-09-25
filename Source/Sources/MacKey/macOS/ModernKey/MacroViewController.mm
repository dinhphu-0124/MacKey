
#import "MacroViewController.h"
#import "MacKeyManager.h"
#include "Engine.h"

#define MACRO_ADD_TEXT @"Thêm"
#define MACRO_EDIT_TEXT @"Sửa"

static NSColor* MakeDynamicColor(NSColor* lightColor, NSColor* darkColor) {
    if (@available(macOS 10.15, *)) {
        return [NSColor colorWithName:nil dynamicProvider:^NSColor * _Nonnull(NSAppearance * _Nonnull appearance) {
            NSAppearanceName best = [appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
            if ([best isEqualToString:NSAppearanceNameDarkAqua]) {
                return darkColor;
            }
            return lightColor;
        }];
    }
    return lightColor;
}

static NSImage* GetWarningSquircleIcon(void) {
    return [NSImage imageNamed:NSImageNameCaution];
}

@interface DuplicateDetailSheetController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, strong) NSArray<NSDictionary*>* duplicates;
@property (nonatomic, strong) NSArray<NSDictionary*>* added;
@property (nonatomic, copy) NSString* alertTitleText;
@property (nonatomic, copy) NSString* alertSubtitleText;
@property (nonatomic, weak) NSWindow* parentWindow;
@property (nonatomic, strong) id selfRetain;

@property (nonatomic, assign) NSInteger currentTab; // 0: Duplicates, 1: Added
@property (nonatomic, assign) BOOL isExpanded;

@property (nonatomic, strong) NSView* cardView;
@property (nonatomic, strong) NSSegmentedControl* segmentedControl;
@property (nonatomic, strong) NSTextField* infoHeaderLabel;
@property (nonatomic, strong) NSTextField* col1Label;
@property (nonatomic, strong) NSTextField* col2Label;
@property (nonatomic, strong) NSScrollView* expandedScrollView;
@property (nonatomic, strong) NSTableView* expandedTableView;
@property (nonatomic, strong) NSTextField* moreLabel;
@property (nonatomic, strong) NSButton* btnDetail;
@property (nonatomic, strong) NSButton* btnOk;

+ (void)showWithParentWindow:(NSWindow*)parent
                       title:(NSString*)title
                    subtitle:(NSString*)subtitle
                  duplicates:(NSArray<NSDictionary*>*)duplicates
                       added:(NSArray<NSDictionary*>*)added;
@end

@implementation DuplicateDetailSheetController

+ (void)showWithParentWindow:(NSWindow*)parent
                       title:(NSString*)title
                    subtitle:(NSString*)subtitle
                  duplicates:(NSArray<NSDictionary*>*)duplicates
                       added:(NSArray<NSDictionary*>*)added {
    DuplicateDetailSheetController* controller = [[DuplicateDetailSheetController alloc] initWithDuplicates:duplicates
                                                                                                      added:added
                                                                                                      title:title
                                                                                                   subtitle:subtitle
                                                                                                     parent:parent];
    controller.selfRetain = controller;
    [parent beginSheet:controller.window completionHandler:^(NSModalResponse returnCode) {
        controller.selfRetain = nil;
    }];
}

- (instancetype)initWithDuplicates:(NSArray*)dups added:(NSArray*)added title:(NSString*)title subtitle:(NSString*)subtitle parent:(NSWindow*)parent {
    CGFloat width = 460;
    CGFloat height = 360;
    NSWindow* win = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, width, height)
                                                styleMask:NSWindowStyleMaskTitled
                                                  backing:NSBackingStoreBuffered
                                                    defer:NO];
    [win setTitleVisibility:NSWindowTitleHidden];
    [win setTitlebarAppearsTransparent:YES];
    [win setMovableByWindowBackground:YES];
    
    self = [super initWithWindow:win];
    if (self) {
        _duplicates = dups ?: @[];
        _added = added ?: @[];
        _alertTitleText = title ?: @"Cảnh báo trùng lặp";
        _alertSubtitleText = subtitle ?: @"";
        _parentWindow = parent;
        _currentTab = 0;
        _isExpanded = NO;
        
        [self buildUI];
    }
    return self;
}

- (NSArray<NSDictionary*>*)currentItems {
    return (self.currentTab == 0) ? self.duplicates : self.added;
}

- (void)buildUI {
    CGFloat width = 460;
    CGFloat height = 360;
    CGFloat padX = 20;
    
    NSView* cv = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, width, height)];
    cv.wantsLayer = YES;
    cv.layer.backgroundColor = MakeDynamicColor([NSColor windowBackgroundColor], [NSColor colorWithCalibratedRed:0.13 green:0.15 blue:0.19 alpha:1.0]).CGColor;
    self.window.contentView = cv;
    
    // 1. Icon (Amber warning triangle with no squircle background)
    CGFloat iconSize = 38;
    NSImageView* iconView = [[NSImageView alloc] initWithFrame:NSMakeRect(padX, height - 18 - iconSize, iconSize, iconSize)];
    [iconView setImage:GetWarningSquircleIcon()];
    [iconView setImageScaling:NSImageScaleProportionallyUpOrDown];
    [cv addSubview:iconView];
    
    // 2. Title & Subtitle
    CGFloat textX = padX + iconSize + 12;
    CGFloat textW = width - textX - padX;
    
    NSTextField* titleLbl = [NSTextField labelWithString:self.alertTitleText];
    titleLbl.frame = NSMakeRect(textX, height - 18 - 20, textW, 20);
    titleLbl.font = [NSFont systemFontOfSize:15 weight:NSFontWeightBold];
    titleLbl.textColor = [NSColor labelColor];
    [cv addSubview:titleLbl];
    
    NSTextField* subLbl = [NSTextField wrappingLabelWithString:self.alertSubtitleText];
    subLbl.frame = NSMakeRect(textX, height - 18 - 20 - 32, textW, 32);
    subLbl.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    subLbl.textColor = [NSColor secondaryLabelColor];
    [cv addSubview:subLbl];
    
    // 3. Card View (Native grouped background & border)
    CGFloat cardW = width - padX * 2; // 420
    CGFloat cardH = 214;
    CGFloat cardY = 56;
    
    self.cardView = [[NSView alloc] initWithFrame:NSMakeRect(padX, cardY, cardW, cardH)];
    self.cardView.wantsLayer = YES;
    self.cardView.layer.backgroundColor = MakeDynamicColor([NSColor controlBackgroundColor], [NSColor colorWithCalibratedRed:0.10 green:0.12 blue:0.16 alpha:1.0]).CGColor;
    self.cardView.layer.cornerRadius = 8;
    self.cardView.layer.borderColor = MakeDynamicColor([NSColor separatorColor], [NSColor colorWithCalibratedRed:0.20 green:0.23 blue:0.30 alpha:1.0]).CGColor;
    self.cardView.layer.borderWidth = 1.0;
    [cv addSubview:self.cardView];
    
    // Tabs or Info Header (Native segmented control)
    if (self.added.count > 0) {
        self.segmentedControl = [NSSegmentedControl segmentedControlWithLabels:@[
            [NSString stringWithFormat:@"Mục trùng lặp (%lu)", (unsigned long)self.duplicates.count],
            [NSString stringWithFormat:@"Mục đã thêm (%lu)", (unsigned long)self.added.count]
        ] trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(onSegmentChanged:)];
        self.segmentedControl.segmentStyle = NSSegmentStyleTexturedRounded;
        self.segmentedControl.selectedSegment = 0;
        self.segmentedControl.frame = NSMakeRect(14, cardH - 12 - 24, 260, 24);
        [self.cardView addSubview:self.segmentedControl];
    } else {
        self.infoHeaderLabel = [NSTextField labelWithString:[NSString stringWithFormat:@"Chi tiết các mục trùng lặp (%lu)", (unsigned long)self.duplicates.count]];
        self.infoHeaderLabel.frame = NSMakeRect(14, cardH - 12 - 20, 350, 20);
        self.infoHeaderLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold];
        self.infoHeaderLabel.textColor = [NSColor secondaryLabelColor];
        [self.cardView addSubview:self.infoHeaderLabel];
    }
    
    // Column Dimensions & Layout
    CGFloat colY = (self.added.count > 0) ? (cardH - 12 - 24 - 18) : (cardH - 12 - 20 - 18); // 160
    CGFloat tableX = 14;
    CGFloat col0W = 110;
    CGFloat colArrowW = 36;
    CGFloat col1W = (cardW - tableX * 2) - col0W - colArrowW; // 246
    
    self.col1Label = [NSTextField labelWithString:@"Trường"];
    self.col1Label.frame = NSMakeRect(tableX, colY, col0W, 14);
    self.col1Label.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    self.col1Label.textColor = [NSColor secondaryLabelColor];
    [self.cardView addSubview:self.col1Label];
    
    self.col2Label = [NSTextField labelWithString:@"Giá trị trùng lặp"];
    self.col2Label.frame = NSMakeRect(tableX + col0W + colArrowW, colY, col1W, 14);
    self.col2Label.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    self.col2Label.textColor = [NSColor secondaryLabelColor];
    [self.cardView addSubview:self.col2Label];
    
    NSView* div = [[NSView alloc] initWithFrame:NSMakeRect(tableX, colY - 5, cardW - tableX * 2, 0.5)];
    div.wantsLayer = YES;
    div.layer.backgroundColor = MakeDynamicColor([NSColor separatorColor], [NSColor colorWithCalibratedRed:0.20 green:0.24 blue:0.32 alpha:1.0]).CGColor;
    [self.cardView addSubview:div];
    
    // TableView & ScrollView
    CGFloat rowH = 22.0;
    CGFloat topY = colY - 7;
    CGFloat fullH = topY - 6;
    
    self.expandedScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(tableX, 6, cardW - tableX * 2, fullH)];
    self.expandedScrollView.hasVerticalScroller = YES;
    self.expandedScrollView.autohidesScrollers = YES;
    self.expandedScrollView.drawsBackground = NO;
    
    self.expandedTableView = [[NSTableView alloc] initWithFrame:self.expandedScrollView.bounds];
    if (@available(macOS 11.0, *)) {
        self.expandedTableView.style = NSTableViewStylePlain;
    }
    self.expandedTableView.intercellSpacing = NSMakeSize(0, 0);
    self.expandedTableView.headerView = nil;
    self.expandedTableView.dataSource = self;
    self.expandedTableView.delegate = self;
    self.expandedTableView.backgroundColor = [NSColor clearColor];
    self.expandedTableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;
    self.expandedTableView.rowHeight = rowH;
    self.expandedTableView.gridStyleMask = NSTableViewSolidHorizontalGridLineMask;
    self.expandedTableView.gridColor = MakeDynamicColor([NSColor separatorColor], [NSColor colorWithCalibratedRed:0.16 green:0.19 blue:0.25 alpha:1.0]);
    
    NSTableColumn* c1 = [[NSTableColumn alloc] initWithIdentifier:@"col1"];
    c1.width = col0W;
    [self.expandedTableView addTableColumn:c1];
    
    NSTableColumn* cArrow = [[NSTableColumn alloc] initWithIdentifier:@"arrow"];
    cArrow.width = colArrowW;
    [self.expandedTableView addTableColumn:cArrow];
    
    NSTableColumn* c2 = [[NSTableColumn alloc] initWithIdentifier:@"col2"];
    c2.width = col1W;
    [self.expandedTableView addTableColumn:c2];
    
    self.expandedScrollView.documentView = self.expandedTableView;
    [self.cardView addSubview:self.expandedScrollView];
    
    self.moreLabel = [NSTextField labelWithString:@""];
    self.moreLabel.frame = NSMakeRect(tableX, 5, 200, 14);
    self.moreLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightRegular];
    self.moreLabel.textColor = [NSColor secondaryLabelColor];
    [self.cardView addSubview:self.moreLabel];
    
    // Bottom Buttons (Standard macOS rounded buttons matching project design)
    self.btnOk = [[NSButton alloc] initWithFrame:NSMakeRect(width - padX - 84, 15, 84, 26)];
    self.btnOk.title = @"Đã hiểu";
    self.btnOk.bezelStyle = NSBezelStyleRounded;
    self.btnOk.keyEquivalent = @"\r";
    self.btnOk.target = self;
    self.btnOk.action = @selector(onClose:);
    [cv addSubview:self.btnOk];
    
    self.btnDetail = [[NSButton alloc] initWithFrame:NSMakeRect(width - padX - 84 - 8 - 106, 15, 106, 26)];
    self.btnDetail.title = @"Xem chi tiết";
    self.btnDetail.bezelStyle = NSBezelStyleRounded;
    self.btnDetail.target = self;
    self.btnDetail.action = @selector(onToggleExpand:);
    [cv addSubview:self.btnDetail];
    
    [self reloadRows];
}

- (void)onSegmentChanged:(NSSegmentedControl*)sender {
    self.currentTab = sender.selectedSegment;
    if (self.currentTab == 0) {
        self.col1Label.stringValue = @"Trường";
        self.col2Label.stringValue = @"Giá trị trùng lặp";
    } else {
        self.col1Label.stringValue = @"Từ viết tắt";
        self.col2Label.stringValue = @"Nội dung gõ tắt";
    }
    [self reloadRows];
}

- (void)reloadRows {
    NSArray* items = self.currentItems;
    CGFloat width = 460;
    CGFloat padX = 20;
    CGFloat cardW = width - padX * 2; // 420
    CGFloat tableX = 14;
    CGFloat tableW = cardW - tableX * 2; // 392
    CGFloat colY = (self.added.count > 0) ? (214 - 12 - 24 - 18) : (214 - 12 - 20 - 18);
    CGFloat topY = colY - 7;
    CGFloat fullH = topY - 6;
    CGFloat rowH = 22.0;
    
    if (items.count > 6) {
        self.btnDetail.hidden = NO;
        self.btnDetail.title = self.isExpanded ? @"Thu gọn" : @"Xem chi tiết";
        if (self.isExpanded) {
            self.moreLabel.hidden = YES;
            self.expandedScrollView.frame = NSMakeRect(tableX, 6, tableW, fullH);
        } else {
            self.moreLabel.hidden = NO;
            self.moreLabel.stringValue = [NSString stringWithFormat:@"+ %lu mục khác...", (unsigned long)(items.count - 6)];
            self.moreLabel.frame = NSMakeRect(tableX, 5, 200, 14);
            CGFloat compactH = 6 * rowH;
            self.expandedScrollView.frame = NSMakeRect(tableX, topY - compactH, tableW, compactH);
        }
    } else {
        self.moreLabel.hidden = YES;
        self.btnDetail.hidden = !self.isExpanded;
        if (self.isExpanded) {
            self.expandedScrollView.frame = NSMakeRect(tableX, 6, tableW, fullH);
        } else {
            CGFloat compactH = MAX(1, (NSInteger)items.count) * rowH;
            self.expandedScrollView.frame = NSMakeRect(tableX, topY - compactH, tableW, compactH);
        }
    }
    self.expandedScrollView.hasVerticalScroller = self.isExpanded;
    self.expandedTableView.frame = self.expandedScrollView.bounds;
    
    [self.expandedTableView reloadData];
}

- (void)onToggleExpand:(id)sender {
    self.isExpanded = !self.isExpanded;
    [self reloadRows];
    if (!self.isExpanded && self.currentItems.count > 0) {
        [self.expandedTableView scrollRowToVisible:0];
    }
}

- (void)onClose:(id)sender {
    [self.parentWindow endSheet:self.window];
    [self.window orderOut:nil];
    self.selfRetain = nil;
}

- (void)cancelOperation:(id)sender {
    [self onClose:sender];
}

#pragma mark - NSTableViewDataSource & Delegate
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (self.isExpanded) {
        return self.currentItems.count;
    } else {
        return MIN(6, (NSInteger)self.currentItems.count);
    }
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row < 0 || row >= self.currentItems.count) return nil;
    NSDictionary* it = self.currentItems[row];
    NSString* k = it[@"key"] ?: @"";
    NSString* v = it[@"val"] ?: @"";
    
    if ([tableColumn.identifier isEqualToString:@"col1"]) {
        NSTextField* tf = [NSTextField labelWithString:k];
        tf.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
        tf.textColor = [NSColor labelColor];
        return tf;
    } else if ([tableColumn.identifier isEqualToString:@"arrow"]) {
        NSTextField* tf = [NSTextField labelWithString:@"→"];
        tf.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
        tf.textColor = [NSColor tertiaryLabelColor];
        tf.alignment = NSTextAlignmentCenter;
        return tf;
    } else {
        NSTextField* tf = [NSTextField labelWithString:v];
        tf.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
        tf.textColor = [NSColor labelColor];
        return tf;
    }
}

@end

@interface MacroViewController ()
@property (nonatomic, strong) NSView *countContainerView;
@property (nonatomic, strong) NSImageView *countIconView;
@property (nonatomic, strong) NSTextField *countLabel;
@property (nonatomic, strong) NSButton *deleteAllButton;
@end

@implementation MacroViewController{
    vector<vector<Uint32>> keys;
    vector<string> macroText;
    vector<string> macroReplacements;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    
    self.macroName.delegate = self;
    self.macroContent.delegate = self;
    
    self.AutoCapsMacro.state = vAutoCapsMacro ? NSControlStateValueOn : NSControlStateValueOff;
    [self.AutoCapsMacro sizeToFit];
    NSRect capFrame = self.AutoCapsMacro.frame;
    capFrame.origin.x = 252;
    capFrame.origin.y = 17;
    self.AutoCapsMacro.frame = capFrame;
    
    // Configure table column resizing
    self.tableView.columnAutoresizingStyle = NSTableViewLastColumnOnlyAutoresizingStyle;
    if (self.tableView.tableColumns.count >= 2) {
        self.tableView.tableColumns[0].resizingMask = NSTableColumnUserResizingMask;
        self.tableView.tableColumns[1].resizingMask = NSTableColumnAutoresizingMask | NSTableColumnUserResizingMask;
        self.tableView.tableColumns[0].width = 137.0;
    }
    
    // Autoresizing masks for responsive layout
    self.macroContent.autoresizingMask = NSViewMinYMargin;
    self.buttonAdd.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin;
    self.buttonDelete.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin;
    
    // Setup "Thêm mới" button (displayed directly above "Xoá" when an existing macro is selected)
    self.buttonAddNew = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 80, 32)];
    self.buttonAddNew.bezelStyle = NSBezelStyleRounded;
    self.buttonAddNew.title = @"Thêm mới";
    if (self.buttonDelete.font) {
        self.buttonAddNew.font = self.buttonDelete.font;
    }
    self.buttonAddNew.target = self;
    self.buttonAddNew.action = @selector(onAddNewMacro:);
    self.buttonAddNew.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin;
    self.buttonAddNew.toolTip = @"Xoá dữ liệu đang chọn để nhập và thêm từ gõ tắt mới";
    self.buttonAddNew.hidden = YES;
    [self.view addSubview:self.buttonAddNew];
    
    // Setup bottom-right shortcut count badge
    [self setupCountBadge];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onMacroDataResetNotification:)
                                                 name:@"MacroDataDidReset"
                                               object:nil];
    
    //load data
    getAllMacro(keys, macroText, macroReplacements);
    
    // Normalize any legacy NFD/decomposed macros in storage to standard NFC
    BOOL needsReSave = NO;
    for (size_t i = 0; i < macroText.size(); i++) {
        NSString *sText = [NSString stringWithUTF8String:macroText[i].c_str()];
        NSString *sContent = [NSString stringWithUTF8String:macroReplacements[i].c_str()];
        if (sText && sContent) {
            NSString *nText = [sText precomposedStringWithCanonicalMapping];
            NSString *nContent = [sContent precomposedStringWithCanonicalMapping];
            if (![sText isEqualToString:nText] || ![sContent isEqualToString:nContent]) {
                deleteMacro(macroText[i]);
                addMacro([nText UTF8String], [nContent UTF8String]);
                needsReSave = YES;
            }
        }
    }
    if (needsReSave) {
        [self saveAndReload];
    } else {
        [self layoutSubviewsResponsive];
        [self updateMacroCount];
    }
}

- (void)setupCountBadge {
    self.countContainerView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 120, 20)];
    self.countContainerView.autoresizingMask = NSViewMinXMargin | NSViewMaxYMargin;
    
    self.countIconView = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 2, 16, 16)];
    self.countIconView.imageScaling = NSImageScaleProportionallyUpOrDown;
    self.countIconView.image = [MacroViewController macroCountIcon];
    if (@available(macOS 10.14, *)) {
        [self.countIconView setContentTintColor:[NSColor secondaryLabelColor]];
    }
    
    self.countLabel = [NSTextField labelWithString:@""];
    self.countLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    self.countLabel.textColor = [NSColor secondaryLabelColor];
    self.countLabel.lineBreakMode = NSLineBreakByClipping;
    
    self.deleteAllButton = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 16, 16)];
    self.deleteAllButton.bordered = NO;
    self.deleteAllButton.imagePosition = NSImageOnly;
    self.deleteAllButton.image = [MacroViewController trashCanBarIcon];
    self.deleteAllButton.imageScaling = NSImageScaleProportionallyUpOrDown;
    if (@available(macOS 10.14, *)) {
        [self.deleteAllButton setContentTintColor:[NSColor secondaryLabelColor]];
    }
    self.deleteAllButton.toolTip = @"Xoá tất cả dữ liệu gõ tắt hiện tại đang có";
    self.deleteAllButton.target = self;
    self.deleteAllButton.action = @selector(onDeleteAllMacros:);
    
    [self.countContainerView addSubview:self.countIconView];
    [self.countContainerView addSubview:self.countLabel];
    [self.countContainerView addSubview:self.deleteAllButton];
    [self.view addSubview:self.countContainerView];
}

- (void)updateMacroCountLayout {
    if (!self.countContainerView || !self.countLabel) return;
    
    CGFloat labelW = self.countLabel.frame.size.width;
    CGFloat iconW = 16;
    CGFloat gap1 = 5;
    CGFloat gap2 = 8;
    CGFloat trashW = 16;
    CGFloat totalW = iconW + gap1 + labelW + gap2 + trashW;
    CGFloat rightMargin = 20;
    CGFloat parentW = self.view.bounds.size.width;
    CGFloat originX = parentW - rightMargin - totalW;
    CGFloat originY = 16;
    
    self.countContainerView.frame = NSMakeRect(originX, originY, totalW, 20);
    self.countIconView.frame = NSMakeRect(0, 2, iconW, iconW);
    self.countLabel.frame = NSMakeRect(iconW + gap1, 1, labelW, 18);
    self.deleteAllButton.frame = NSMakeRect(iconW + gap1 + labelW + gap2, 2, trashW, trashW);
}

- (void)updateMacroCount {
    NSUInteger count = macroText.size();
    NSString *countStr = [NSString stringWithFormat:@"%lu từ tắt", (unsigned long)count];
    self.countLabel.stringValue = countStr;
    [self.countLabel sizeToFit];
    
    NSString *tooltip = [NSString stringWithFormat:@"Tổng số từ gõ tắt hiện có: %lu", (unsigned long)count];
    self.countContainerView.toolTip = tooltip;
    [self.countIconView setToolTip:tooltip];
    [self.countLabel setToolTip:tooltip];
    [self updateMacroCountLayout];
}

- (void)updateTableColumnWidths {
    if (self.tableView.tableColumns.count >= 2) {
        CGFloat totalTableW = self.tableView.superview ? self.tableView.superview.bounds.size.width : self.tableView.bounds.size.width;
        if (totalTableW > 200) {
            CGFloat col0W = 137.0;
            CGFloat col1W = MAX(200.0, totalTableW - col0W - 3.0);
            self.tableView.tableColumns[0].width = col0W;
            self.tableView.tableColumns[1].width = col1W;
            [self.tableView sizeLastColumnToFit];
        }
    }
}

- (void)layoutSubviewsResponsive {
    CGFloat W = self.view.bounds.size.width;
    CGFloat H = self.view.bounds.size.height;
    if (W < 100 || H < 100) return;
    
    CGFloat topBtnY = H - 68;
    CGFloat topNewY = H - 36;
    CGFloat topFieldY = H - 64;
    CGFloat btnW = 80;
    CGFloat btnH = 32;
    CGFloat btnGap = 10;
    CGFloat rightMargin = 20;
    
    self.macroName.frame = NSMakeRect(20, topFieldY, 130, 25);
    
    NSString *nameText = [self.macroName stringValue];
    std::string text = [nameText UTF8String];
    BOOL exists = hasMacro(text);
    
    CGFloat contentX = 160;
    if (exists) {
        // Mode: Editing
        CGFloat delX = W - rightMargin - btnW;
        CGFloat addX = delX - btnGap - btnW;
        
        // Button "Thêm mới" directly above "Xoá" (equal size: 80x32)
        self.buttonAddNew.frame = NSMakeRect(delX, topNewY, btnW, btnH);
        self.buttonAddNew.hidden = NO;
        [self.buttonAddNew setTitle:@"Thêm mới"];
        
        self.buttonDelete.frame = NSMakeRect(delX, topBtnY, btnW, btnH);
        self.buttonDelete.hidden = NO;
        [self.buttonDelete setTitle:@"Xoá"];
        
        self.buttonAdd.frame = NSMakeRect(addX, topBtnY, btnW, btnH);
        self.buttonAdd.hidden = NO;
        [self.buttonAdd setTitle:@"Cập nhật"];
        
        CGFloat contentW = MAX(100.0, addX - btnGap - contentX);
        self.macroContent.frame = NSMakeRect(contentX, topFieldY, contentW, 25);
    } else {
        // Mode: Adding
        CGFloat addX = W - rightMargin - btnW;
        
        self.buttonAddNew.hidden = YES;
        self.buttonDelete.hidden = YES;
        
        self.buttonAdd.frame = NSMakeRect(addX, topBtnY, btnW, btnH);
        self.buttonAdd.hidden = NO;
        [self.buttonAdd setTitle:@"Thêm"];
        
        CGFloat contentW = MAX(100.0, addX - btnGap - contentX);
        self.macroContent.frame = NSMakeRect(contentX, topFieldY, contentW, 25);
    }
    
    [self updateTableColumnWidths];
    [self updateMacroCountLayout];
}

- (void)viewDidLayout {
    [super viewDidLayout];
    [self layoutSubviewsResponsive];
}

-(void)saveAndReload {
    getAllMacro(keys, macroText, macroReplacements);
    [self.tableView reloadData];
    
    vector<Byte> macroData;
    getMacroSaveData(macroData);
    NSData* _data = [NSData dataWithBytes:macroData.data() length:macroData.size()];
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject:_data forKey:@"macroData"];
    [self updateButtonStates];
    [self updateMacroCount];
}

+ (NSImage *)successIcon {
    static NSImage *sharedSuccessIcon = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSSize size = NSMakeSize(64, 64);
        sharedSuccessIcon = [NSImage imageWithSize:size flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
            NSRect circleRect = NSInsetRect(dstRect, 3, 3);
            NSBezierPath *circlePath = [NSBezierPath bezierPathWithOvalInRect:circleRect];
            [[NSColor colorWithCalibratedRed:0.20 green:0.78 blue:0.35 alpha:1.0] setFill];
            [circlePath fill];
            
            NSBezierPath *check = [NSBezierPath bezierPath];
            [check setLineWidth:5.0];
            [check setLineCapStyle:NSLineCapStyleRound];
            [check setLineJoinStyle:NSLineJoinStyleRound];
            [check moveToPoint:NSMakePoint(19.0, 32.0)];
            [check lineToPoint:NSMakePoint(27.0, 22.0)];
            [check lineToPoint:NSMakePoint(46.0, 43.0)];
            [[NSColor whiteColor] setStroke];
            [check stroke];
            return YES;
        }];
    });
    return sharedSuccessIcon;
}

+ (NSImage *)trashIcon {
    static NSImage *sharedTrashIcon = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGFloat size = 64.0;
        sharedTrashIcon = [NSImage imageWithSize:NSMakeSize(size, size) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
            // Circle with soft crimson/red fill matching Apple alert palette
            NSRect circleRect = NSInsetRect(dstRect, 3, 3);
            NSBezierPath *circlePath = [NSBezierPath bezierPathWithOvalInRect:circleRect];
            [[NSColor colorWithCalibratedRed:0.92 green:0.28 blue:0.28 alpha:1.0] setFill];
            [circlePath fill];
            
            // Crisp white trash can
            [[NSColor whiteColor] setFill];
            
            // Lid handle
            NSBezierPath *handle = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(28, 44, 8, 3) xRadius:1.5 yRadius:1.5];
            [handle fill];
            
            // Lid
            NSBezierPath *lid = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(20, 40, 24, 3.5) xRadius:1.5 yRadius:1.5];
            [lid fill];
            
            // Bin body
            NSBezierPath *body = [NSBezierPath bezierPath];
            [body moveToPoint:NSMakePoint(22, 38)];
            [body lineToPoint:NSMakePoint(24, 18)];
            [body appendBezierPathWithArcFromPoint:NSMakePoint(24, 15) toPoint:NSMakePoint(27, 15) radius:3];
            [body lineToPoint:NSMakePoint(37, 15)];
            [body appendBezierPathWithArcFromPoint:NSMakePoint(40, 15) toPoint:NSMakePoint(40, 18) radius:3];
            [body lineToPoint:NSMakePoint(42, 38)];
            [body closePath];
            [body fill];
            
            // 3 vertical cutouts
            [[NSColor colorWithCalibratedRed:0.92 green:0.28 blue:0.28 alpha:1.0] setFill];
            for (CGFloat x : {26.5, 31.0, 35.5}) {
                NSBezierPath *line = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(x, 19, 2.0, 15) xRadius:1.0 yRadius:1.0];
                [line fill];
            }
            return YES;
        }];
    });
    return sharedTrashIcon;
}

+ (NSImage *)macroCountIcon {
    static NSImage *sharedCountIcon = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (@available(macOS 11.0, *)) {
            NSImageSymbolConfiguration *config = [NSImageSymbolConfiguration configurationWithPointSize:12 weight:NSFontWeightMedium];
            NSImage *sym = [NSImage imageWithSystemSymbolName:@"character.book.closed" accessibilityDescription:nil];
            if (!sym) {
                sym = [NSImage imageWithSystemSymbolName:@"list.bullet" accessibilityDescription:nil];
            }
            if (sym) {
                sharedCountIcon = [sym imageWithSymbolConfiguration:config];
                [sharedCountIcon setTemplate:YES];
            }
        }
        if (!sharedCountIcon) {
            // High-resolution vector fallback for earlier macOS
            sharedCountIcon = [NSImage imageWithSize:NSMakeSize(16, 16) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
                [[NSColor secondaryLabelColor] setStroke];
                NSBezierPath *book = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(1.5, 1.5, 13, 13) xRadius:2 yRadius:2];
                [book setLineWidth:1.2];
                [book stroke];
                
                NSBezierPath *spine = [NSBezierPath bezierPath];
                [spine moveToPoint:NSMakePoint(4.5, 1.5)];
                [spine lineToPoint:NSMakePoint(4.5, 14.5)];
                [spine setLineWidth:1.2];
                [spine stroke];
                return YES;
            }];
            [sharedCountIcon setTemplate:YES];
        }
    });
    return sharedCountIcon;
}

+ (NSImage *)trashCanBarIcon {
    static NSImage *sharedBarTrashIcon = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (@available(macOS 11.0, *)) {
            NSImageSymbolConfiguration *config = [NSImageSymbolConfiguration configurationWithPointSize:12 weight:NSFontWeightMedium];
            NSImage *sym = [NSImage imageWithSystemSymbolName:@"trash" accessibilityDescription:@"Xoá tất cả dữ liệu gõ tắt hiện tại đang có"];
            if (sym) {
                sharedBarTrashIcon = [sym imageWithSymbolConfiguration:config];
                [sharedBarTrashIcon setTemplate:YES];
            }
        }
        if (!sharedBarTrashIcon) {
            sharedBarTrashIcon = [NSImage imageWithSize:NSMakeSize(16, 16) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
                NSBezierPath *path = [NSBezierPath bezierPath];
                [path setLineWidth:1.2];
                [path setLineCapStyle:NSLineCapStyleRound];
                [path setLineJoinStyle:NSLineJoinStyleRound];
                
                // Handle
                [path moveToPoint:NSMakePoint(6.0, 13.5)];
                [path lineToPoint:NSMakePoint(6.0, 15.0)];
                [path lineToPoint:NSMakePoint(10.0, 15.0)];
                [path lineToPoint:NSMakePoint(10.0, 13.5)];
                
                // Lid line
                [path moveToPoint:NSMakePoint(2.5, 13.5)];
                [path lineToPoint:NSMakePoint(13.5, 13.5)];
                
                // Bin body
                [path moveToPoint:NSMakePoint(4.0, 13.5)];
                [path lineToPoint:NSMakePoint(4.8, 3.0)];
                [path appendBezierPathWithArcFromPoint:NSMakePoint(5.0, 1.5) toPoint:NSMakePoint(6.5, 1.5) radius:1.5];
                [path lineToPoint:NSMakePoint(9.5, 1.5)];
                [path appendBezierPathWithArcFromPoint:NSMakePoint(11.0, 1.5) toPoint:NSMakePoint(11.2, 3.0) radius:1.5];
                [path lineToPoint:NSMakePoint(12.0, 13.5)];
                
                // Slits
                [path moveToPoint:NSMakePoint(6.8, 11.0)];
                [path lineToPoint:NSMakePoint(6.8, 4.5)];
                [path moveToPoint:NSMakePoint(9.2, 11.0)];
                [path lineToPoint:NSMakePoint(9.2, 4.5)];
                
                [[NSColor secondaryLabelColor] setStroke];
                [path stroke];
                return YES;
            }];
            [sharedBarTrashIcon setTemplate:YES];
        }
    });
    return sharedBarTrashIcon;
}

+ (NSImage *)warningSquircleIcon {
    return GetWarningSquircleIcon();
}

+ (NSUInteger)currentMacroCount {
    return (NSUInteger)getMacroCount();
}

+ (void)resetAllMacroData {
    clearAllMacros();
    vector<Byte> emptyData;
    getMacroSaveData(emptyData);
    NSData *d = [NSData dataWithBytes:emptyData.data() length:emptyData.size()];
    [[NSUserDefaults standardUserDefaults] setObject:d forKey:@"macroData"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MacroDataDidReset" object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)onMacroDataResetNotification:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.macroName.stringValue = @"";
        self.macroContent.stringValue = @"";
        [self.tableView deselectAll:nil];
        getAllMacro(self->keys, self->macroText, self->macroReplacements);
        [self.tableView reloadData];
        [self updateButtonStates];
        [self updateMacroCount];
    });
}

+ (NSAlert *)styledAlertWithTitle:(nullable NSString *)title
                          message:(nullable NSString *)msg
                             icon:(nullable NSImage *)icon
                            style:(NSAlertStyle)style
                     buttonTitles:(NSArray<NSString *> *)buttonTitles
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @" ";
    alert.informativeText = @"";
    if (icon) {
        alert.alertStyle = NSAlertStyleInformational;
        alert.icon = icon;
    } else {
        alert.alertStyle = style;
    }
    alert.showsSuppressionButton = NO;
    for (NSString *bTitle in buttonTitles) {
        [alert addButtonWithTitle:bTitle];
    }
    
    CGFloat contentWidth = 280.0;
    NSFont *titleFont = [NSFont boldSystemFontOfSize:14];
    NSFont *msgFont = [NSFont systemFontOfSize:12];
    
    CGFloat titleHeight = 0;
    if (title && title.length > 0) {
        NSRect titleRect = [title boundingRectWithSize:NSMakeSize(contentWidth, CGFLOAT_MAX)
                                               options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                            attributes:@{NSFontAttributeName: titleFont}];
        titleHeight = MAX(20.0, ceil(titleRect.size.height + 2.0));
    }
    
    CGFloat msgHeight = 0;
    CGFloat spacing = (titleHeight > 0 && msg && msg.length > 0) ? 8.0 : 0.0;
    if (msg && msg.length > 0) {
        NSRect msgRect = [msg boundingRectWithSize:NSMakeSize(contentWidth, CGFLOAT_MAX)
                                           options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                        attributes:@{NSFontAttributeName: msgFont}];
        msgHeight = ceil(msgRect.size.height + 4.0);
    }
    
    CGFloat totalHeight = titleHeight + spacing + msgHeight;
    NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, contentWidth, totalHeight)];
    
    if (title && title.length > 0) {
        NSTextField *titleLabel = [NSTextField wrappingLabelWithString:title];
        titleLabel.font = titleFont;
        titleLabel.alignment = NSTextAlignmentCenter;
        titleLabel.textColor = [NSColor labelColor];
        titleLabel.frame = NSMakeRect(0, totalHeight - titleHeight, contentWidth, titleHeight);
        [container addSubview:titleLabel];
    }
    
    if (msg && msg.length > 0) {
        NSTextField *msgLabel = [NSTextField wrappingLabelWithString:msg];
        msgLabel.font = msgFont;
        msgLabel.alignment = NSTextAlignmentLeft;
        msgLabel.textColor = [NSColor secondaryLabelColor];
        msgLabel.frame = NSMakeRect(0, 0, contentWidth, msgHeight);
        [container addSubview:msgLabel];
    }
    
    alert.accessoryView = container;
    return alert;
}

- (void)showSuccessMessage:(NSString*)msg withTitle:(NSString*)title {
    NSAlert* alert = [MacroViewController styledAlertWithTitle:title ? title : @"Gõ tắt"
                                                       message:msg
                                                          icon:[MacroViewController successIcon]
                                                         style:NSAlertStyleInformational
                                                  buttonTitles:@[@"OK"]];
    [alert beginSheetModalForWindow:self.view.window completionHandler:nil];
}

- (void)showDeleteSuccessMessage:(NSString*)msg withTitle:(NSString*)title {
    NSAlert* alert = [MacroViewController styledAlertWithTitle:title ? title : @"Gõ tắt"
                                                       message:msg
                                                          icon:[MacroViewController trashIcon]
                                                         style:NSAlertStyleInformational
                                                  buttonTitles:@[@"OK"]];
    [alert beginSheetModalForWindow:self.view.window completionHandler:nil];
}

- (void)showWarningMessage:(NSString*)msg withTitle:(NSString*)title {
    NSAlert* alert = [MacroViewController styledAlertWithTitle:title ? title : @"Gõ tắt"
                                                       message:msg
                                                          icon:GetWarningSquircleIcon()
                                                         style:NSAlertStyleWarning
                                                  buttonTitles:@[@"OK"]];
    [alert beginSheetModalForWindow:self.view.window completionHandler:nil];
}

- (void)showMessage:(NSString*)msg {
    [self showWarningMessage:msg withTitle:@"Gõ tắt"];
}

- (IBAction)onAddNewMacro:(id)sender {
    self.macroName.stringValue = @"";
    self.macroContent.stringValue = @"";
    [self.tableView deselectAll:nil];
    [self.macroName becomeFirstResponder];
    [self updateButtonStates];
}

- (IBAction)onDeleteMacro:(id)sender {
    if ([[self.macroName stringValue] compare:@""] == 0) {
        [self showWarningMessage:@"Bạn hãy chọn từ cần xoá!" withTitle:@"Gõ tắt"];
        return;
    }
    NSString *deletedName = [self.macroName stringValue];
    string text = [deletedName UTF8String];
    if (deleteMacro(text)) {
        self.macroName.stringValue = @"";
        self.macroContent.stringValue = @"";
        [self saveAndReload];
        [self.macroName becomeFirstResponder];
        [self showDeleteSuccessMessage:[NSString stringWithFormat:@"Đã xoá mục gõ tắt \"%@\" thành công.", deletedName] withTitle:@"Gõ tắt"];
    } else {
        [self showWarningMessage:[NSString stringWithFormat:@"Không tìm thấy mục gõ tắt \"%@\" để xoá.", deletedName] withTitle:@"Gõ tắt"];
    }
}

- (IBAction)onDeleteAllMacros:(id)sender {
    if (macroText.empty()) {
        [self showWarningMessage:@"Danh sách gõ tắt hiện đang trống." withTitle:@"Gõ tắt"];
        return;
    }
    
    NSString *bodyMsg = [NSString stringWithFormat:@"Bạn có chắc chắn muốn xoá tất cả dữ liệu gõ tắt\nhiện tại đang có (%lu mục)?\nThao tác này không thể hoàn tác.", (unsigned long)macroText.size()];
    
    NSAlert *alert = [MacroViewController styledAlertWithTitle:@"Xoá tất cả gõ tắt?"
                                                       message:bodyMsg
                                                          icon:[MacroViewController trashIcon]
                                                         style:NSAlertStyleCritical
                                                  buttonTitles:@[@"Xoá tất cả", @"Huỷ"]];
    
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            clearAllMacros();
            self.macroName.stringValue = @"";
            self.macroContent.stringValue = @"";
            [self.tableView deselectAll:nil];
            [self saveAndReload];
            [self.macroName becomeFirstResponder];
            [self showDeleteSuccessMessage:@"Đã xoá tất cả dữ liệu gõ tắt thành công." withTitle:@"Gõ tắt"];
        }
    }];
}

- (IBAction)onAddMacro:(id)sender {
    NSString *rawName = [self.macroName stringValue];
    NSString *rawContent = [self.macroContent stringValue];
    
    NSString *nameStr = [[rawName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] precomposedStringWithCanonicalMapping];
    NSString *contentStr = [[rawContent stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] precomposedStringWithCanonicalMapping];
    
    if (nameStr.length == 0 || contentStr.length == 0) {
        [self showWarningMessage:@"Bạn hãy nhập từ cần gõ tắt và nội dung thay thế!" withTitle:@"Gõ tắt"];
        return;
    }
    
    string text = [nameStr UTF8String];
    string content = [contentStr UTF8String];
    
    string existingContent;
    if (getMacroContent(text, existingContent)) {
        if (existingContent == content) {
            // Cảnh báo trùng lặp hoàn toàn
            [DuplicateDetailSheetController showWithParentWindow:self.view.window
                                                          title:@"Cảnh báo trùng lặp"
                                                       subtitle:[NSString stringWithFormat:@"Mục gõ tắt \"%@\" với nội dung \"%@\" đã có trong danh sách từ trước.", nameStr, contentStr]
                                                     duplicates:@[@{@"key": nameStr, @"val": contentStr}]
                                                          added:@[]];
            return;
        } else {
            // Cập nhật nội dung cho từ tắt đã tồn tại
            addMacro(text, content);
            self.macroName.stringValue = @"";
            self.macroContent.stringValue = @"";
            [self saveAndReload];
            [self.macroName becomeFirstResponder];
            [self showSuccessMessage:[NSString stringWithFormat:@"Đã cập nhật mục gõ tắt \"%@\" thành công.", nameStr] withTitle:@"Gõ tắt"];
            return;
        }
    }
    
    // Thêm mới thành công
    addMacro(text, content);
    self.macroName.stringValue = @"";
    self.macroContent.stringValue = @"";
    [self saveAndReload];
    [self.macroName becomeFirstResponder];
    [self showSuccessMessage:[NSString stringWithFormat:@"Đã thêm mục gõ tắt \"%@\" thành công.", nameStr] withTitle:@"Gõ tắt"];
}

- (IBAction)onImportFromExcel:(id)sender {
    NSOpenPanel* openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseFiles:YES];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setAllowedFileTypes:@[@"xlsx", @"csv"]];
    
    [openPanel beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse result) {
        if (result != NSModalResponseOK) {
            return;
        }
        
        NSURL* fileURL = [[openPanel URLs] firstObject];
        if (!fileURL) {
            return;
        }
        
        [self importFromExcelOrCSV:fileURL.path];
    }];
}

- (void)importFromExcelOrCSV:(NSString*)filePath {
    NSString* scriptPath = [[NSBundle mainBundle] pathForResource:@"xlsx_parser" ofType:@"py"];
    if (!scriptPath) {
        NSString* resPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"xlsx_parser.py"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:resPath]) {
            scriptPath = resPath;
        }
    }
    if (!scriptPath) {
        [self showWarningMessage:@"Không tìm thấy bộ phân tích tệp Excel trong ứng dụng." withTitle:@"Lỗi"];
        return;
    }
    
    NSString* pythonPath = @"/usr/bin/python3";
    if (![[NSFileManager defaultManager] fileExistsAtPath:pythonPath]) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:@"/opt/homebrew/bin/python3"]) {
            pythonPath = @"/opt/homebrew/bin/python3";
        } else if ([[NSFileManager defaultManager] fileExistsAtPath:@"/usr/local/bin/python3"]) {
            pythonPath = @"/usr/local/bin/python3";
        }
    }
    
    NSTask* task = [[NSTask alloc] init];
    [task setLaunchPath:pythonPath];
    [task setArguments:@[scriptPath, filePath]];
    
    NSMutableDictionary* env = [[[NSProcessInfo processInfo] environment] mutableCopy];
    env[@"LC_ALL"] = @"en_US.UTF-8";
    env[@"PYTHONIOENCODING"] = @"utf-8";
    [task setEnvironment:env];
    
    NSPipe* outputPipe = [NSPipe pipe];
    NSPipe* errorPipe = [NSPipe pipe];
    [task setStandardOutput:outputPipe];
    [task setStandardError:errorPipe];
    
    @try {
        [task launch];
        [task waitUntilExit];
    } @catch (NSException *exception) {
        [self showWarningMessage:[NSString stringWithFormat:@"Không thể chạy bộ phân tích Python. Lỗi: %@", exception.reason] withTitle:@"Lỗi"];
        return;
    }
    
    int status = [task terminationStatus];
    if (status != 0) {
        NSData* errorData = [[errorPipe fileHandleForReading] readDataToEndOfFile];
        NSString* errorMsg = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];
        [self showWarningMessage:[NSString stringWithFormat:@"Lỗi khi đọc file Excel/CSV: %@", errorMsg] withTitle:@"Lỗi"];
        return;
    }
    
    NSData* outputData = [[outputPipe fileHandleForReading] readDataToEndOfFile];
    NSError* jsonError = nil;
    NSArray* parsedMacros = [NSJSONSerialization JSONObjectWithData:outputData options:kNilOptions error:&jsonError];
    
    if (jsonError || ![parsedMacros isKindOfClass:[NSArray class]]) {
        [self showWarningMessage:@"Dữ liệu Excel/CSV không đúng định dạng." withTitle:@"Lỗi"];
        return;
    }
    
    NSMutableArray<NSDictionary*>* duplicateList = [NSMutableArray array];
    NSMutableArray<NSDictionary*>* addedList = [NSMutableArray array];
    
    // Tập hợp các mục gõ tắt hiện có để đối chiếu trùng lặp
    std::map<string, string> knownMacros;
    for (size_t i = 0; i < macroText.size(); i++) {
        knownMacros[macroText[i]] = macroReplacements[i];
    }
    
    for (id item in parsedMacros) {
        if ([item isKindOfClass:[NSArray class]] && [item count] >= 2) {
            NSString* key = [item[0] description];
            NSString* val = [item[1] description];
            key = [[key stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] precomposedStringWithCanonicalMapping];
            val = [[val stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] precomposedStringWithCanonicalMapping];
            
            if (key.length == 0 || val.length == 0) {
                continue;
            }
            
            std::string text = [key UTF8String];
            std::string content = [val UTF8String];
            
            // Kiểm tra trùng lặp với danh sách đã có hoặc các mục trước trong file
            auto it = knownMacros.find(text);
            if (it != knownMacros.end()) {
                [duplicateList addObject:@{@"key": key, @"val": val, @"existing": [NSString stringWithUTF8String:it->second.c_str()]}];
                continue;
            }
            
            string existingContent;
            if (getMacroContent(text, existingContent)) {
                [duplicateList addObject:@{@"key": key, @"val": val, @"existing": [NSString stringWithUTF8String:existingContent.c_str()]}];
                continue;
            }
            
            if (addMacro(text, content)) {
                knownMacros[text] = content;
                [addedList addObject:@{@"key": key, @"val": val}];
            }
        }
    }
    
    if (addedList.count > 0) {
        [self saveAndReload];
    }
    
    if (duplicateList.count > 0) {
        // CÓ MỤC TRÙNG LẶP -> HIỂN THỊ GIAO DIỆN CẢNH BÁO CHI TIẾT THEO ẢNH 1
        NSString* subtitle = @"";
        if (addedList.count > 0) {
            subtitle = [NSString stringWithFormat:@"Đã bỏ qua %lu mục bị trùng lặp và thêm thành công\n%lu mục mới vào danh sách.", (unsigned long)duplicateList.count, (unsigned long)addedList.count];
        } else {
            subtitle = [NSString stringWithFormat:@"Tất cả %lu mục trong tệp đều đã có từ trước trong danh sách.\nKhông có mục mới nào được thêm.", (unsigned long)duplicateList.count];
        }
        
        [DuplicateDetailSheetController showWithParentWindow:self.view.window
                                                      title:@"Cảnh báo trùng lặp"
                                                   subtitle:subtitle
                                                 duplicates:duplicateList
                                                      added:addedList];
    } else if (addedList.count > 0) {
        // THÊM THÀNH CÔNG KHÔNG TRÙNG -> HIỂN THỊ ICON TÍCH XANH ĐẸP
        [self showSuccessMessage:[NSString stringWithFormat:@"Đã thêm thành công %lu mục gõ tắt vào danh sách.", (unsigned long)addedList.count] withTitle:@"Gõ tắt"];
    } else {
        [self showWarningMessage:@"Không tìm thấy mục gõ tắt hợp lệ nào trong tệp Excel/CSV." withTitle:@"Gõ tắt"];
    }
}


- (void)controlTextDidChange:(NSNotification *)notification {
    NSTextField *textField = [notification object];
    if (textField == self.macroName) {
        [self updateButtonStates];
    }
}

- (IBAction)onAutoCapButton:(NSButton *)sender {
    NSInteger val = sender.state == NSControlStateValueOn ? 1 : 0;
    MacKeyStateLock();
    vAutoCapsMacro = (int)val;
    MacKeyStateUnlock();
    [[NSUserDefaults standardUserDefaults] setInteger:vAutoCapsMacro forKey:@"vAutoCapsMacro"];
}

#pragma mark TableView
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return keys.size();
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    NSString* cellId;
    NSTableCellView* v = nil;
    if (tableColumn == tableView.tableColumns[0]) {
        cellId = @"MacroCell";
        v = [tableView makeViewWithIdentifier:cellId owner:self];
        [v.textField setStringValue:[NSString stringWithUTF8String:macroText[row].c_str()]];
    } else if (tableColumn == tableView.tableColumns[1]) {
        cellId = @"ContentCell";
        v = [tableView makeViewWithIdentifier:cellId owner:self];
        [v.textField setStringValue:[NSString stringWithUTF8String:macroReplacements[row].c_str()]];
    }
    return v;
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
    [self.macroName setStringValue:[NSString stringWithUTF8String:macroText[row].c_str()]];
    [self.macroContent setStringValue:[NSString stringWithUTF8String:macroReplacements[row].c_str()]];
    [self updateButtonStates];
    return YES;
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if (commandSelector == @selector(insertNewline:)) {
        if (control == self.macroName) {
            [self.macroContent becomeFirstResponder];
            return YES;
        } else if (control == self.macroContent) {
            [self onAddMacro:control];
            return YES;
        }
    }
    return NO;
}

- (void)updateButtonStates {
    [self layoutSubviewsResponsive];
}


- (IBAction)onExportFile:(id)sender {
    NSImage *exportIcon = nil;
    if (@available(macOS 11.0, *)) {
        NSImageSymbolConfiguration *config = [NSImageSymbolConfiguration configurationWithPointSize:44 weight:NSFontWeightRegular];
        NSImage *sym = [NSImage imageWithSystemSymbolName:@"square.and.arrow.up" accessibilityDescription:nil];
        if (sym) {
            exportIcon = [sym imageWithSymbolConfiguration:config];
        }
    }
    NSAlert* alert = [MacroViewController styledAlertWithTitle:@"Xuất bảng gõ tắt"
                                                       message:@"Bạn muốn xuất danh sách gõ tắt ra định dạng nào?"
                                                          icon:exportIcon
                                                         style:NSAlertStyleInformational
                                                  buttonTitles:@[@"Excel (.xlsx)", @"CSV", @"Huỷ"]];
    
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertThirdButtonReturn) {
            return; // Cancelled
        }
        
        BOOL isExcel = (returnCode == NSAlertFirstButtonReturn);
        NSString* ext = isExcel ? @"xlsx" : @"csv";
        
        NSSavePanel* savePanel = [NSSavePanel savePanel];
        [savePanel setAllowedFileTypes:@[ext]];
        [savePanel setNameFieldStringValue:[NSString stringWithFormat:@"GoTat_Export.%@", ext]];
        
        [savePanel beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse result) {
            if (result != NSModalResponseOK) {
                return;
            }
            
            NSURL* fileURL = [savePanel URL];
            if (!fileURL) {
                return;
            }
            
            [self performExportToPath:fileURL.path isExcel:isExcel];
        }];
    }];
}

- (void)performExportToPath:(NSString*)filePath isExcel:(BOOL)isExcel {
    NSString* scriptPath = [[NSBundle mainBundle] pathForResource:@"xlsx_exporter" ofType:@"py"];
    if (!scriptPath) {
        NSString* resPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"xlsx_exporter.py"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:resPath]) {
            scriptPath = resPath;
        }
    }
    if (!scriptPath) {
        [self showWarningMessage:@"Không tìm thấy bộ xuất tệp Excel/CSV trong ứng dụng." withTitle:@"Lỗi"];
        return;
    }
    
    // Build data array with precomposed Unicode (NFC)
    NSMutableArray* dataArray = [NSMutableArray array];
    for (size_t i = 0; i < macroText.size(); i++) {
        NSString* shortcut = [NSString stringWithUTF8String:macroText[i].c_str()];
        NSString* replacement = [NSString stringWithUTF8String:macroReplacements[i].c_str()];
        if (shortcut && replacement) {
            shortcut = [shortcut precomposedStringWithCanonicalMapping];
            replacement = [replacement precomposedStringWithCanonicalMapping];
            [dataArray addObject:@[shortcut, replacement]];
        }
    }
    
    NSError* err = nil;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:dataArray options:0 error:&err];
    if (err) {
        [self showWarningMessage:@"Không thể chuyển dữ liệu sang định dạng JSON." withTitle:@"Lỗi"];
        return;
    }
    
    NSString* pythonPath = @"/usr/bin/python3";
    if (![[NSFileManager defaultManager] fileExistsAtPath:pythonPath]) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:@"/opt/homebrew/bin/python3"]) {
            pythonPath = @"/opt/homebrew/bin/python3";
        } else if ([[NSFileManager defaultManager] fileExistsAtPath:@"/usr/local/bin/python3"]) {
            pythonPath = @"/usr/local/bin/python3";
        }
    }
    
    NSTask* task = [[NSTask alloc] init];
    [task setLaunchPath:pythonPath];
    // Pass "-" as argument so xlsx_exporter reads JSON cleanly from stdin (avoids NSTask argument decomposition)
    [task setArguments:@[scriptPath, @"-", filePath]];
    
    NSMutableDictionary* env = [[[NSProcessInfo processInfo] environment] mutableCopy];
    env[@"LC_ALL"] = @"en_US.UTF-8";
    env[@"PYTHONIOENCODING"] = @"utf-8";
    [task setEnvironment:env];
    
    NSPipe* inputPipe = [NSPipe pipe];
    NSPipe* errorPipe = [NSPipe pipe];
    [task setStandardInput:inputPipe];
    [task setStandardError:errorPipe];
    
    @try {
        [task launch];
        [[inputPipe fileHandleForWriting] writeData:jsonData];
        [[inputPipe fileHandleForWriting] closeFile];
        [task waitUntilExit];
    } @catch (NSException *exception) {
        [self showWarningMessage:[NSString stringWithFormat:@"Không thể chạy bộ xuất dữ liệu Python. Lỗi: %@", exception.reason] withTitle:@"Lỗi"];
        return;
    }
    
    int status = [task terminationStatus];
    if (status != 0) {
        NSData* errorData = [[errorPipe fileHandleForReading] readDataToEndOfFile];
        NSString* errorMsg = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];
        [self showWarningMessage:[NSString stringWithFormat:@"Lỗi khi xuất tệp: %@", errorMsg] withTitle:@"Lỗi"];
    } else {
        [self showSuccessMessage:[NSString stringWithFormat:@"Danh sách gõ tắt đã được xuất ra tại:\n%@", filePath] withTitle:@"Xuất file thành công!"];
    }
}

@end
