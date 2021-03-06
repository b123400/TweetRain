//
//  Status.h
//  Canvas
//
//  Created by b123400 Chan on 10/4/12.
//  Copyright (c) 2012 home. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "User.h"
#import "BRMastodonStatus.h"

@interface Status : NSObject{
	User *user;
	
	NSString *statusID;
	NSDate *createdAt;
	NSString *text;
	
	BOOL liked;
	
	NSMutableDictionary *entities;
	NSMutableDictionary *otherInfos;
}
@property (strong,nonatomic) User *user;
@property (strong,nonatomic) NSString *statusID;
@property (strong,nonatomic) NSDate *createdAt;
@property (strong,nonatomic) NSString *text;

@property (assign,nonatomic) BOOL favourited;
@property (assign,nonatomic) BOOL bookmarked;
@property (assign,nonatomic) BOOL reblogged;

@property (strong,nonatomic) NSAttributedString *attributedText;

- (BOOL)canReply;
- (void)replyToStatusWithText:(NSString *)text
            completionHandler:(void (^_Nonnull)(NSError * _Nullable error))callback;

- (BOOL)canBookmark;
- (void)bookmarkStatusWithCompletionHandler:(void (^_Nonnull)(NSError * _Nullable error))callback;

- (BOOL)canFavourite;
- (void)favouriteStatusWithCompletionHandler:(void (^_Nonnull)(NSError * _Nullable error))callback;

- (BOOL)canReblog;
- (void)reblogStatusWithCompletionHandler:(void (^_Nonnull)(NSError * _Nullable error))callback;

@end
