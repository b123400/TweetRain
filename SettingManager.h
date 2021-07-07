//
//  SettingManager.h
//  Canvas
//
//  Created by b123400 Chan on 4/2/12.
//  Copyright (c) 2012 home. All rights reserved.
//

#import "User.h"
#import "BRMastodonAccount.h"

#define kRainDropAppearanceChangedNotification @"kRainDropAppearanceChangedNotification"
#define kWindowLevelChanged @"kWindowLevelChanged"

#if TARGET_OS_IPHONE
#else
#define AUTO_SELECT_FIRST_ACCOUNT
#endif

@interface SettingManager : NSObject{
    
}

@property (nonatomic) BOOL hideStatusAroundCursor;
@property (nonatomic) BOOL showProfileImage;
@property (nonatomic) BOOL removeLinks;
@property (nonatomic) BOOL truncateStatus;
@property (nonatomic) float opacity;

#if TARGET_OS_IPHONE

@property (nonatomic) UIColor *textColor;
@property (nonatomic) UIColor *shadowColor;
@property (nonatomic) UIColor *hoverBackgroundColor;
@property (nonatomic) UIFont *font;
@property (nonatomic) float fontSize;
@property (nonatomic) NSString *fontName;

#elif TARGET_OS_MAC

@property (nonatomic) NSColor *textColor;
@property (nonatomic) NSColor *shadowColor;
@property (nonatomic) NSColor *hoverBackgroundColor;
@property (nonatomic) NSFont *font;
@property (nonatomic) NSNumber *windowLevel;

#endif

+(SettingManager*)sharedManager;

- (BRMastodonAccount*)selectedAccount;
- (void)setSelectedAccount:(BRMastodonAccount*)account;
- (NSArray<BRMastodonAccount*> *)accounts;
- (void)reloadAccounts;

@end
