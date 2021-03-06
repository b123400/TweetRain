//
//  StreamController.h
//  flood
//
//  Created by b123400 on 2/11/14.
//
//

#import <Foundation/Foundation.h>
#import "BRMastodonAccount.h"
#import "MastodonStatus.h"

@protocol StreamControllerDelegate <NSObject>

@optional
- (void)streamController:(id)controller didReceivedStatus:(Status *)status;

@end

@interface StreamController : NSObject

@property (nonatomic, weak) id<StreamControllerDelegate> delegate;
@property (nonatomic, strong) NSString *searchTerm;

+ (instancetype)shared;

- (void)startStreaming;

@end
