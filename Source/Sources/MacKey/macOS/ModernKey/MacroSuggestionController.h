//
//  MacroSuggestionController.h
//  MacKey
//

#ifndef MacroSuggestionController_h
#define MacroSuggestionController_h

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MacroSuggestionController : NSObject

+ (instancetype)sharedController;

- (void)showSuggestion:(NSString *)content shortcut:(NSString *)shortcut;
- (void)hideSuggestion;
- (void)dismissByUser;
- (BOOL)isVisible;

@end

NS_ASSUME_NONNULL_END

#endif /* MacroSuggestionController_h */
