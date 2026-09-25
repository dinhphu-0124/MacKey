
#import "MyTextField.h"
#include <Carbon/Carbon.h>

@implementation MyTextField {
    BOOL _isRecording;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self setEditable:NO];
    [self setSelectable:NO];
    [self setBezeled:NO];
    [self setBordered:NO];
    [self setDrawsBackground:NO];
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (NSTextInputContext *)inputContext {
    return nil;
}

- (BOOL)canBecomeKeyView {
    return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
    return YES;
}

- (BOOL)needsPanelToBecomeKey {
    return YES;
}

- (BOOL)becomeFirstResponder {
    [self setNeedsDisplay:YES];
    return YES;
}

- (BOOL)resignFirstResponder {
    _isRecording = NO;
    [self setNeedsDisplay:YES];
    return YES;
}

- (void)resetCursorRects {
    [super resetCursorRects];
    [self addCursorRect:[self bounds] cursor:[NSCursor pointingHandCursor]];
}

- (void)mouseDown:(NSEvent *)event {
    _isRecording = YES;
    [self.window makeFirstResponder:self];
    [self setNeedsDisplay:YES];
}

static char charFromKeyCode(unsigned short keyCode) {
    switch (keyCode) {
        case 0: return 'a';
        case 1: return 's';
        case 2: return 'd';
        case 3: return 'f';
        case 4: return 'h';
        case 5: return 'g';
        case 6: return 'z';
        case 7: return 'x';
        case 8: return 'c';
        case 9: return 'v';
        case 11: return 'b';
        case 12: return 'q';
        case 13: return 'w';
        case 14: return 'e';
        case 15: return 'r';
        case 16: return 'y';
        case 17: return 't';
        case 18: return '1';
        case 19: return '2';
        case 20: return '3';
        case 21: return '4';
        case 22: return '6';
        case 23: return '5';
        case 24: return '=';
        case 25: return '9';
        case 26: return '7';
        case 27: return '-';
        case 28: return '8';
        case 29: return '0';
        case 30: return ']';
        case 31: return 'o';
        case 32: return 'u';
        case 33: return '[';
        case 34: return 'i';
        case 35: return 'p';
        case 37: return 'l';
        case 38: return 'j';
        case 39: return '\'';
        case 40: return 'k';
        case 41: return ';';
        case 42: return '\\';
        case 43: return ',';
        case 44: return '/';
        case 45: return 'n';
        case 46: return 'm';
        case 47: return '.';
        case 49: return ' ';
        case 50: return '`';
        default: return 0;
    }
}

- (void)keyDown:(NSEvent *)event {
    if (!_isRecording) {
        return;
    }
    
    unsigned short kc = event.keyCode;
    
    // Tab -> chuyển sang ô tiếp theo
    if (kc == kVK_Tab) {
        _isRecording = NO;
        [self setNeedsDisplay:YES];
        [self.window selectKeyViewFollowingView:self];
        return;
    }
    
    // Escape -> huỷ ghi phím
    if (kc == kVK_Escape) {
        _isRecording = NO;
        [self setNeedsDisplay:YES];
        return;
    }
    
    // Space
    if (kc == kVK_Space) {
        self.LastKeyCode = kVK_Space;
        self.LastKeyChar = ' ';
        _isRecording = NO;
        [self setNeedsDisplay:YES];
        if ([self.Parent respondsToSelector:@selector(onMyTextFieldKeyChange:character:)]) {
            [self.Parent onMyTextFieldKeyChange:kVK_Space character:' '];
        }
        return;
    }
    
    // Delete / Backspace -> xoá phím (chỉ dùng phím bổ trợ modifier)
    if (kc == kVK_Delete || kc == kVK_ForwardDelete) {
        self.LastKeyCode = 0xFE;
        self.LastKeyChar = 0xFE;
        _isRecording = NO;
        [self setNeedsDisplay:YES];
        if ([self.Parent respondsToSelector:@selector(onMyTextFieldKeyChange:character:)]) {
            [self.Parent onMyTextFieldKeyChange:0xFE character:0xFE];
        }
        return;
    }
    
    // Ưu tiên tra cứu từ keyCode phần cứng để không bị bộ gõ tiếng Việt làm biến đổi
    char mappedChar = charFromKeyCode(kc);
    if (mappedChar >= 32 && mappedChar < 127) {
        self.LastKeyCode = kc;
        self.LastKeyChar = (unsigned short)mappedChar;
        _isRecording = NO;
        [self setNeedsDisplay:YES];
        if ([self.Parent respondsToSelector:@selector(onMyTextFieldKeyChange:character:)]) {
            [self.Parent onMyTextFieldKeyChange:kc character:(unsigned short)mappedChar];
        }
        return;
    }
    
    // Fallback: Ký tự từ event
    NSString *chars = event.charactersIgnoringModifiers;
    if (chars.length == 0) {
        chars = event.characters;
    }
    if (chars.length > 0) {
        unsigned short chr = (unsigned short)[chars lowercaseString].UTF8String[0];
        if (chr >= 32 && chr < 127) {
            self.LastKeyCode = kc;
            self.LastKeyChar = chr;
            _isRecording = NO;
            [self setNeedsDisplay:YES];
            if ([self.Parent respondsToSelector:@selector(onMyTextFieldKeyChange:character:)]) {
                [self.Parent onMyTextFieldKeyChange:kc character:chr];
            }
            return;
        }
    }
}

-(void)setTextByChar:(unsigned short)chr {
    [self setTextByKeyCode:0 character:chr];
}

-(void)setTextByKeyCode:(unsigned short)keyCode character:(unsigned short)chr {
    self.LastKeyCode = keyCode;
    self.LastKeyChar = chr;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    NSRect bounds = NSInsetRect(self.bounds, 1.0, 1.0);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:6.0 yRadius:6.0];
    
    if (_isRecording) {
        [[NSColor.controlAccentColor colorWithAlphaComponent:0.15] setFill];
    } else {
        [[NSColor controlBackgroundColor] setFill];
    }
    [path fill];
    
    if (_isRecording) {
        [NSColor.controlAccentColor setStroke];
        path.lineWidth = 2.0;
    } else {
        [[NSColor separatorColor] setStroke];
        path.lineWidth = 1.0;
    }
    [path stroke];
    
    NSString *text = @"";
    NSColor *color = [NSColor controlTextColor];
    
    if (_isRecording) {
        text = @"···";
        color = [NSColor controlAccentColor];
    } else if (self.LastKeyCode == kVK_Space || self.LastKeyChar == ' ') {
        text = @"Space";
        color = [NSColor labelColor];
    } else if (self.LastKeyCode == 0xFE || self.LastKeyChar == 0xFE || (self.LastKeyChar == 0 && self.LastKeyCode == 0)) {
        text = @"Phím";
        color = [NSColor placeholderTextColor];
    } else if (self.LastKeyChar >= 32 && self.LastKeyChar < 127) {
        text = [NSString stringWithFormat:@"%c", (char)toupper((int)self.LastKeyChar)];
        color = [NSColor labelColor];
    } else {
        char ch = charFromKeyCode(self.LastKeyCode);
        if (ch >= 32 && ch < 127) {
            text = [NSString stringWithFormat:@"%c", (char)toupper((int)ch)];
            color = [NSColor labelColor];
        } else {
            text = @"Phím";
            color = [NSColor placeholderTextColor];
        }
    }
    
    NSFont *font = [NSFont systemFontOfSize:12.0 weight:NSFontWeightSemibold];
    NSDictionary *attrs = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: color
    };
    
    NSSize textSize = [text sizeWithAttributes:attrs];
    NSRect textRect = NSMakeRect(
        NSMidX(self.bounds) - textSize.width / 2.0,
        NSMidY(self.bounds) - textSize.height / 2.0 - 0.5,
        textSize.width,
        textSize.height
    );
    [text drawInRect:textRect withAttributes:attrs];
}

@end

