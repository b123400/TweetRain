//
//  BRMastodonClient.m
//  TweetRain
//
//  Created by b123400 on 2021/06/27.
//

#import "BRMastodonClient.h"
#import "BRMastodonAccount.h"

@implementation BRMastodonClient

+ (instancetype)shared {
    static BRMastodonClient *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[BRMastodonClient alloc] init];
    });
    return instance;
}

- (void)registerAppFor:(NSString*)hostname completionHandler:(void (^)(BRMastodonApp *app, NSError *error))callback {
    if (![hostname hasPrefix:@"http://"] && ![hostname hasPrefix:@"https://"]) {
        hostname = [NSString stringWithFormat:@"https://%@", hostname];
    }
    if ([hostname hasSuffix:@"/"]) {
        hostname = [hostname substringToIndex:hostname.length - 1];
    }
    BRMastodonApp *existingApp = [BRMastodonApp appWithHostname:hostname];
    if (existingApp != nil) {
        callback(existingApp, nil);
        return;
    }
    
    NSURL *endpoint = [NSURL URLWithString:@"/api/v1/apps" relativeToURL:[NSURL URLWithString:hostname]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:endpoint];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:[[self httpBodyWithParams: @{
        @"client_name": @"Tootrain",
        @"redirect_uris": OAUTH_REDIRECT_DEST,
        @"scopes": @"read write",
        @"website": @"https://b123400.net",
    }] dataUsingEncoding:NSUTF8StringEncoding]];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
                                    completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"Error: %@", error);
            callback(nil, error);
            return;
        }
        NSLog(@"str %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
        NSError *decodeError = nil;
        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&decodeError];
        if (![result isKindOfClass:[NSDictionary class]] || decodeError != nil) {
            NSLog(@"Decode error: %@", decodeError);
            callback(nil, decodeError);
            return;
        }
        if (result[@"error"]) {
            NSError *responseError = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:@{@"response": result}];
            NSLog(@"responseError: %@", responseError);
            callback(nil, responseError);
            return;
        }
        BRMastodonApp *app  = [[BRMastodonApp alloc] initWithHostName:hostname
                                                             clientId:result[@"client_id"]
                                                         clientSecret:result[@"client_secret"]
                               ];
        [app save];
        callback(app, error);
    }];
    [task resume];
}

- (void)getAccessTokenWithApp:(BRMastodonApp *)app
                         code:(NSString *)code
            completionHandler:(void (^)(BRMastodonOAuthResult * _Nullable result, NSError * _Nullable error))callback {
    NSURL *url = [NSURL URLWithString:@"/oauth/token"
                            relativeToURL:[NSURL URLWithString:app.hostName]];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:[ [self httpBodyWithParams:@{
            @"client_id": app.clientId,
            @"client_secret": app.clientSecret,
            @"redirect_uri": OAUTH_REDIRECT_DEST,
            @"grant_type": @"authorization_code",
            @"code": code,
            @"scope": @"read write"
    }] dataUsingEncoding:NSUTF8StringEncoding]];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
                                    completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"Error: %@", error);
            callback(nil, error);
            return;
        }
        NSLog(@"str %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
        NSError *decodeError = nil;
        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&decodeError];
        if (![result isKindOfClass:[NSDictionary class]] || decodeError != nil) {
            NSLog(@"Decode error: %@", decodeError);
            callback(nil, decodeError);
            return;
        }
        if (result[@"error"]) {
            callback(nil,
                     [NSError errorWithDomain:NSCocoaErrorDomain
                                         code:0
                                     userInfo:@{@"response": result}]);
            return;
        }
        BRMastodonOAuthResult *oauthResult = [[BRMastodonOAuthResult alloc] init];
        oauthResult.accessToken = result[@"access_token"];
        oauthResult.refreshToken = result[@"refresh_token"];
        oauthResult.expiresIn = result[@"expires_in"];
        callback(oauthResult, error);
    }];
    [task resume];
}

- (NSString *)httpBodyWithParams:(NSDictionary<NSString*, NSString*>*) dict {
    NSMutableArray<NSString*> *parts = [NSMutableArray array];
    [dict enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
        [parts addObject:[NSString stringWithFormat:@"%@=%@", key, [obj stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]]]];
    }];
    return [parts componentsJoinedByString:@"&"];
}

- (void) verifyAccountWithApp:(BRMastodonApp *)app
                  oauthResult:(BRMastodonOAuthResult *)oauthResult
            completionHandler:(void (^)(BRMastodonAccount *account, NSError *error))callback {
    NSURL *url = [NSURL URLWithString:@"/api/v1/accounts/verify_credentials"
                            relativeToURL:[NSURL URLWithString:app.hostName]];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", oauthResult.accessToken] forHTTPHeaderField:@"Authorization"];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
                                    completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"Error: %@", error);
            callback(nil, error);
            return;
        }
        NSLog(@"str %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
        NSError *decodeError = nil;
        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&decodeError];
        if (![result isKindOfClass:[NSDictionary class]] || decodeError != nil) {
            NSLog(@"Decode error: %@", decodeError);
            callback(nil, decodeError);
            return;
        }
        if (result[@"error"]) {
            callback(nil, [NSError errorWithDomain:NSCocoaErrorDomain
                                              code:0
                                          userInfo:@{
                                              @"response": result,
                            }]);
            return;
        }
        NSString *accountId = result[@"id"];
        BRMastodonAccount *existingAccount = [BRMastodonAccount accountWithApp:app accountId:accountId];
        if (existingAccount) {
            // Update existing account's cred
            [existingAccount renew:oauthResult];
            callback(existingAccount, nil);
            return;
        }
        BRMastodonAccount *account = [[BRMastodonAccount alloc] initWithApp:app
                                                                  accountId:accountId
                                                                        url:result[@"url"]
                                                                oauthResult:oauthResult];
        [account save];
        callback(account, nil);
        
    }];
    [task resume];
}

- (void)refreshAccessTokenWithApp:(BRMastodonApp *)app
                     refreshToken:(NSString *)refreshToken
                completionHandler:(void (^)(BRMastodonOAuthResult *result, NSError *error))callback {
    NSURL *url = [NSURL URLWithString:@"/oauth/token"
                            relativeToURL:[NSURL URLWithString:app.hostName]];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:[ [self httpBodyWithParams:@{
            @"client_id": app.clientId,
            @"client_secret": app.clientSecret,
            @"redirect_uri": OAUTH_REDIRECT_DEST,
            @"grant_type": @"refresh_token",
            @"refresh_token": refreshToken,
            @"scope": @"read write"
    }] dataUsingEncoding:NSUTF8StringEncoding]];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
                                    completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"Error: %@", error);
            callback(nil, error);
            return;
        }
        NSLog(@"str %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
        NSError *decodeError = nil;
        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&decodeError];
        if (![result isKindOfClass:[NSDictionary class]] || decodeError != nil) {
            NSLog(@"Decode error: %@", decodeError);
            callback(nil, decodeError);
            return;
        }
        if (result[@"error"]) {
            callback(nil,
                     [NSError errorWithDomain:NSCocoaErrorDomain
                                         code:0
                                     userInfo:@{@"response": result}]);
            return;
        }
        BRMastodonOAuthResult *oauthResult = [[BRMastodonOAuthResult alloc] init];
        oauthResult.accessToken = result[@"access_token"];
        oauthResult.refreshToken = result[@"refresh_token"];
        oauthResult.expiresIn = result[@"expires_in"];
        callback(oauthResult, error);
    }];
    [task resume];
}

@end