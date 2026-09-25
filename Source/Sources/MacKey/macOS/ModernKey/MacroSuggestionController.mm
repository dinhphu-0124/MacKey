//
//  MacroSuggestionController.mm
//  MacKey
//

#import "MacroSuggestionController.h"
#import "Engine.h"
#import <ApplicationServices/ApplicationServices.h>

@interface MacroSuggestionView : NSView
@property (nonatomic, strong) NSTextField *contentLabel;
@property (nonatomic, strong) NSButton *closeButton;
@property (nonatomic, copy) void (^onCloseAction)(void);
@end

@implementation MacroSuggestionView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self setWantsLayer:YES];
        
        _contentLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];
        _contentLabel.editable = NO;
        _contentLabel.selectable = NO;
        _contentLabel.bordered = NO;
        _contentLabel.drawsBackground = NO;
        _contentLabel.font = [NSFont systemFontOfSize:14.0 weight:NSFontWeightMedium];
        _contentLabel.textColor = [NSColor labelColor];
        _contentLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self addSubview:_contentLabel];
        
        _closeButton = [[NSButton alloc] initWithFrame:NSZeroRect];
        _closeButton.bordered = NO;
        _closeButton.title = @"✕";
        _closeButton.font = [NSFont systemFontOfSize:11.0 weight:NSFontWeightBold];
        _closeButton.contentTintColor = [NSColor tertiaryLabelColor];
        _closeButton.target = self;
        _closeButton.action = @selector(onCloseClicked:);
        _closeButton.toolTip = @"Bỏ qua gợi ý (Esc)";
        [self addSubview:_closeButton];
    }
    return self;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
    return YES;
}

- (void)onCloseClicked:(id)sender {
    if (self.onCloseAction) {
        self.onCloseAction();
    }
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    NSRect bounds = NSInsetRect(self.bounds, 0.5, 0.5);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:10.0 yRadius:10.0];
    
    BOOL isDark = NO;
    if (@available(macOS 10.14, *)) {
        NSAppearanceName appearanceName = [self.effectiveAppearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
        if ([appearanceName isEqualToString:NSAppearanceNameDarkAqua]) {
            isDark = YES;
        }
    }
    
    if (isDark) {
        [[NSColor colorWithCalibratedWhite:0.18 alpha:0.96] setFill];
        [[NSColor colorWithCalibratedWhite:0.35 alpha:1.0] setStroke];
    } else {
        [[NSColor colorWithCalibratedWhite:0.99 alpha:0.98] setFill];
        [[NSColor colorWithCalibratedWhite:0.82 alpha:1.0] setStroke];
    }
    
    [path fill];
    [path setLineWidth:1.0];
    [path stroke];
}

- (void)layout {
    [super layout];
    CGFloat paddingH = 14.0;
    CGFloat closeWidth = 18.0;
    CGFloat boundsW = self.bounds.size.width;
    CGFloat boundsH = self.bounds.size.height;
    
    CGFloat labelW = boundsW - (paddingH + closeWidth + 8.0 + paddingH);
    if (labelW < 10) labelW = 10;
    
    _contentLabel.frame = NSMakeRect(paddingH, (boundsH - 20.0) / 2.0, labelW, 20.0);
    _closeButton.frame = NSMakeRect(boundsW - paddingH - closeWidth, (boundsH - 18.0) / 2.0, closeWidth, 18.0);
}

@end

@interface MacroSuggestionController ()
@property (nonatomic, strong) NSPanel *window;
@property (nonatomic, strong) MacroSuggestionView *contentView;
@property (nonatomic, copy, nullable) NSString *currentShortcut;
@property (nonatomic, assign) BOOL isVisible;
@end

@implementation MacroSuggestionController

+ (instancetype)sharedController {
    static MacroSuggestionController *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MacroSuggestionController alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isVisible = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setupWindow];
        });
    }
    return self;
}

- (void)setupWindow {
    if (_window) return;
    
    _window = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 150, 36)
                                        styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                                          backing:NSBackingStoreBuffered
                                            defer:NO];
    _window.level = NSPopUpMenuWindowLevel;
    _window.opaque = NO;
    _window.backgroundColor = [NSColor clearColor];
    _window.hasShadow = YES;
    _window.hidesOnDeactivate = NO;
    _window.canHide = NO;
    [_window setAcceptsMouseMovedEvents:YES];
    [_window setBecomesKeyOnlyIfNeeded:YES];
    _window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorTransient;
    
    __weak typeof(self) weakSelf = self;
    _contentView = [[MacroSuggestionView alloc] initWithFrame:NSMakeRect(0, 0, 150, 36)];
    _contentView.onCloseAction = ^{
        [weakSelf dismissByUser];
    };
    _window.contentView = _contentView;
}

- (CGRect)currentCaretRectForShortcut:(NSString *)shortcut {
    NSRunningApplication *frontApp = [[NSWorkspace sharedWorkspace] frontmostApplication];
    if (!frontApp) return CGRectNull;
    
    AXUIElementRef appRef = AXUIElementCreateApplication(frontApp.processIdentifier);
    if (!appRef) return CGRectNull;
    
    AXUIElementRef focusedElement = NULL;
    AXError err = AXUIElementCopyAttributeValue(appRef, kAXFocusedUIElementAttribute, (CFTypeRef *)&focusedElement);
    if (err != kAXErrorSuccess || !focusedElement) {
        CFRelease(appRef);
        return CGRectNull;
    }
    
    CGRect resultRect = CGRectNull;
    CFTypeRef rangeValue = NULL;
    if (AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextRangeAttribute, &rangeValue) == kAXErrorSuccess && rangeValue) {
        CFRange selectedRange;
        if (AXValueGetValue((AXValueRef)rangeValue, kAXValueTypeCFRange, &selectedRange)) {
            NSUInteger shortcutLen = shortcut.length;
            if (shortcutLen > 0 && selectedRange.location >= shortcutLen) {
                CFRange wordRange = CFRangeMake(selectedRange.location - shortcutLen, shortcutLen);
                AXValueRef wordRangeVal = AXValueCreate(kAXValueTypeCFRange, &wordRange);
                if (wordRangeVal) {
                    CFTypeRef wordBoundsVal = NULL;
                    if (AXUIElementCopyParameterizedAttributeValue(focusedElement, kAXBoundsForRangeParameterizedAttribute, wordRangeVal, &wordBoundsVal) == kAXErrorSuccess && wordBoundsVal) {
                        CGRect wordRect = CGRectNull;
                        if (AXValueGetValue((AXValueRef)wordBoundsVal, kAXValueTypeCGRect, &wordRect) && wordRect.size.height > 0) {
                            CFRelease(wordBoundsVal);
                            CFRelease(wordRangeVal);
                            CFRelease(rangeValue);
                            CFRelease(focusedElement);
                            CFRelease(appRef);
                            return wordRect;
                        }
                        if (wordBoundsVal) CFRelease(wordBoundsVal);
                    }
                    CFRelease(wordRangeVal);
                }
            }
        }
        
        CFTypeRef boundsValue = NULL;
        if (AXUIElementCopyParameterizedAttributeValue(focusedElement, kAXBoundsForRangeParameterizedAttribute, rangeValue, &boundsValue) == kAXErrorSuccess && boundsValue) {
            AXValueGetValue((AXValueRef)boundsValue, kAXValueTypeCGRect, &resultRect);
            CFRelease(boundsValue);
        }
        CFRelease(rangeValue);
    }
    
    if (CGRectIsNull(resultRect) || (resultRect.size.width == 0 && resultRect.size.height == 0)) {
        CGPoint pt = CGPointZero;
        CGSize sz = CGSizeZero;
        CFTypeRef posVal = NULL;
        CFTypeRef szVal = NULL;
        if (AXUIElementCopyAttributeValue(focusedElement, kAXPositionAttribute, &posVal) == kAXErrorSuccess && posVal) {
            AXValueGetValue((AXValueRef)posVal, kAXValueTypeCGPoint, &pt);
            CFRelease(posVal);
        }
        if (AXUIElementCopyAttributeValue(focusedElement, kAXSizeAttribute, &szVal) == kAXErrorSuccess && szVal) {
            AXValueGetValue((AXValueRef)szVal, kAXValueTypeCGSize, &sz);
            CFRelease(szVal);
        }
        if (sz.width > 0 && sz.height > 0) {
            resultRect = CGRectMake(pt.x, pt.y, sz.width, sz.height);
        }
    }
    
    CFRelease(focusedElement);
    CFRelease(appRef);
    return resultRect;
}

- (void)showSuggestion:(NSString *)content shortcut:(NSString *)shortcut {
    if (!content || content.length == 0) {
        [self hideSuggestion];
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setupWindow];
        
        self->_currentShortcut = [shortcut copy];
        self->_contentView.contentLabel.stringValue = content;
        
        NSDictionary *attrs = @{ NSFontAttributeName : self->_contentView.contentLabel.font };
        NSSize textSize = [content sizeWithAttributes:attrs];
        CGFloat paddingH = 14.0;
        CGFloat closeWidth = 18.0;
        CGFloat winWidth = ceil(paddingH + textSize.width + 12.0 + closeWidth + paddingH);
        if (winWidth < 90.0) winWidth = 90.0;
        if (winWidth > 550.0) winWidth = 550.0;
        CGFloat winHeight = 36.0;
        
        CGRect axRect = [self currentCaretRectForShortcut:shortcut];
        NSScreen *primaryScreen = [NSScreen screens].firstObject;
        CGFloat primaryHeight = primaryScreen ? primaryScreen.frame.size.height : 900.0;
        
        CGFloat winX = 0;
        CGFloat winY = 0;
        
        if (!CGRectIsNull(axRect) && axRect.size.height > 0) {
            CGFloat caretCocoaX = axRect.origin.x;
            CGFloat caretCocoaY = primaryHeight - (axRect.origin.y + axRect.size.height);
            if (axRect.size.width <= 2.0 && shortcut.length > 0) {
                caretCocoaX -= (shortcut.length * 8.5);
            }
            winX = caretCocoaX - 4.0;
            winY = caretCocoaY + axRect.size.height + 6.0;
        } else {
            NSPoint mouse = [NSEvent mouseLocation];
            winX = mouse.x;
            winY = mouse.y + 20.0;
        }
        
        NSScreen *targetScreen = nil;
        for (NSScreen *scr in [NSScreen screens]) {
            if (NSPointInRect(NSMakePoint(winX, winY), scr.frame)) {
                targetScreen = scr;
                break;
            }
        }
        if (!targetScreen) targetScreen = primaryScreen;
        
        if (targetScreen) {
            NSRect visible = targetScreen.visibleFrame;
            if (winY + winHeight > NSMaxY(visible)) {
                if (!CGRectIsNull(axRect) && axRect.size.height > 0) {
                    CGFloat caretCocoaY = primaryHeight - (axRect.origin.y + axRect.size.height);
                    winY = caretCocoaY - winHeight - 6.0;
                } else {
                    winY = NSMaxY(visible) - winHeight - 4.0;
                }
            }
            if (winX + winWidth > NSMaxX(visible)) {
                winX = NSMaxX(visible) - winWidth - 4.0;
            }
            if (winX < NSMinX(visible)) {
                winX = NSMinX(visible) + 4.0;
            }
        }
        
        [self->_window setFrame:NSMakeRect(winX, winY, winWidth, winHeight) display:YES];
        [self->_contentView setNeedsDisplay:YES];
        [self->_window orderFront:nil];
        self->_isVisible = YES;
    });
}

- (void)hideSuggestion {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_window) {
            [self->_window orderOut:nil];
        }
        self->_isVisible = NO;
        self->_currentShortcut = nil;
    });
}

- (void)dismissByUser {
    vDismissMacroSuggestion();
    [self hideSuggestion];
}

@end
