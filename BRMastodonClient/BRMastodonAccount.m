//
//  BRMastodonAccount.m
//  TweetRain
//
//  Created by b123400 on 2021/07/02.
//

#import "BRMastodonAccount.h"

@interface BRMastodonAccount ()
- (instancetype)initWithApp:(BRMastodonApp *)app
                  accountId:(NSString *)accountId
                        url:(NSString *)url
                displayName:(NSString *)displayName
                accessToken:(NSString *)accessToken
               refreshToken:(NSString *)refreshToken
                    expires:(NSDate *)expires;
@end

@implementation BRMastodonAccount

+ (NSArray<BRMastodonAccount*> *)allAccounts {
    NSMutableArray *result = [NSMutableArray array];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *servers = (NSDictionary*)[defaults objectForKey:@"BRMastodonAccount"];
    if (!servers) {
        return result;
    }
    for (NSString *host in servers) {
        NSDictionary *server = servers[host];
        for (NSString *accountId in server) {
            NSDictionary *accountDict = server[accountId];
            BRMastodonApp *app = [BRMastodonApp appWithHostname:accountDict[@"host"]];
            BRMastodonAccount *account = [BRMastodonAccount accountWithApp:app accountId:accountId];
            if (!account) continue;
            [result addObject:account];
        }
    }
    return result;
}

+ (instancetype)accountWithApp:(BRMastodonApp *)app
                     accountId:(NSString *)accountId {
    if (!app) return nil;
    
    // Access token
    NSDictionary *dict = @{
        (id)kSecClass: (id)kSecClassInternetPassword,
        (id)kSecAttrServer: app.hostName,
        (id)kSecReturnAttributes: (id)kCFBooleanTrue,
        (id)kSecAttrType: [NSNumber numberWithUnsignedInt:'otok'],
        (id)kSecAttrAccount: accountId,
        (id)kSecReturnData: (id)kCFBooleanTrue
    };

    // Look up server in the keychain
    NSDictionary *found = nil;
    CFDictionaryRef foundCF;
    OSStatus err = SecItemCopyMatching((__bridge CFDictionaryRef) dict, (CFTypeRef*)&foundCF);

    // Check if found
    found = (__bridge NSDictionary*)(foundCF);
    if (!found)
        return nil;

    // Found
    NSString *accessToken = [[NSString alloc] initWithData:found[(id)kSecValueData] encoding:NSUTF8StringEncoding];

    NSString *refreshTokenAccountId = [NSString stringWithFormat:@"%@|refresh-token", accountId];
    dict = @{
        (id)kSecClass: (id)kSecClassInternetPassword,
        (id)kSecAttrServer: app.hostName,
        (id)kSecReturnAttributes: (id)kCFBooleanTrue,
        (id)kSecAttrType: [NSNumber numberWithUnsignedInt:'otok'],
        (id)kSecAttrAccount: refreshTokenAccountId,
        (id)kSecReturnData: (id)kCFBooleanTrue
    };

    // Look up server in the keychain
    NSDictionary *refreshTokenFound = nil;
    CFDictionaryRef refreshTokenFoundCF;
    err = SecItemCopyMatching((__bridge CFDictionaryRef) dict, (CFTypeRef*)&refreshTokenFoundCF);

    // Check if found
    refreshTokenFound = (__bridge NSDictionary*)(refreshTokenFoundCF);
    NSString *refreshToken = nil;
    if (refreshTokenFound) {
        refreshToken = [[NSString alloc] initWithData:refreshTokenFound[(id)kSecValueData] encoding:NSUTF8StringEncoding];
    }

    // Found
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *servers = (NSDictionary*)[defaults objectForKey:@"BRMastodonAccount"];
    NSDictionary *accounts = (NSDictionary*)servers[app.hostName];
    NSString *url = accounts[accountId][@"url"];
    NSString *displayName = accounts[accountId][@"displayName"];
    NSString *host = accounts[accountId][@"host"];
    NSDate *expires = accounts[accountId][@"expires"];
    if (!url || !host) {
        return nil;
    }
    return [[BRMastodonAccount alloc] initWithApp:app
                                        accountId:accountId
                                              url:url
                                      displayName:displayName
                                      accessToken:accessToken
                                     refreshToken:refreshTokenFound ? refreshToken : nil
                                          expires:expires];
}

- (instancetype)initWithApp:(BRMastodonApp *)app
                  accountId:(NSString *)accountId
                        url:(NSString *)url
                displayName:(NSString *)displayName
                accessToken:(NSString *)accessToken
               refreshToken:(NSString *)refreshToken
                    expires:(NSDate *)expires {
    if (self = [super init]) {
        self.app = app;
        self.accountId = accountId;
        self.url = url;
        self.displayName = displayName;
        self.accessToken = accessToken;
        self.refreshToken = refreshToken;
        self.expires = expires;
    }
    return self;
}

- (instancetype)initWithApp:(BRMastodonApp *)app
                  accountId:(NSString *)accountId
                        url:(NSString *)url
                displayName:(NSString *)displayName
                oauthResult:(BRMastodonOAuthResult *)oauthResult {
    if (self = [super init]) {
        self.app = app;
        self.accountId = accountId;
        self.url = url;
        self.displayName = displayName;
        self.accessToken = oauthResult.accessToken;
        self.refreshToken = oauthResult.refreshToken;
        self.expires = oauthResult.expiresIn == nil
            ? [NSDate dateWithTimeIntervalSince1970:4765132800] // 2099: ~ never expire
            : [[NSDate date] dateByAddingTimeInterval:[oauthResult.expiresIn doubleValue]];
    }
    return self;
}

- (void)renew:(BRMastodonOAuthResult *)oauthResult {
    self.accessToken = oauthResult.accessToken;
    self.refreshToken = oauthResult.refreshToken;
    self.expires = [[NSDate date] dateByAddingTimeInterval:[oauthResult.expiresIn doubleValue]];
    [self save];
}

- (void)save {
    // Access token
    NSDictionary *dict = @{
        (id)kSecClass: (id)kSecClassInternetPassword,
        (id)kSecReturnAttributes: (id)kCFBooleanTrue,
        (id)kSecAttrServer: self.app.hostName,
        (id)kSecAttrAccount: self.accountId,
    };

    // Remove any old values from the keychain
    OSStatus err = SecItemDelete((__bridge CFDictionaryRef) dict);
    NSLog(@"Access token delete: %d", err);
    
    // Create dictionary of parameters to add
    dict = @{
        (id)kSecClass: (id)kSecClassInternetPassword,
        (id)kSecAttrType: [NSNumber numberWithUnsignedInt:'otok'],
        (id)kSecAttrServer: self.app.hostName,
        (id)kSecValueData: [self.accessToken dataUsingEncoding:NSUTF8StringEncoding],
        (id)kSecAttrAccount: self.accountId,
    };

    // Try to save to keychain
    err = SecItemAdd((__bridge CFDictionaryRef) dict, NULL);
    NSLog(@"Access token save: %d", err);
    
    if (self.refreshToken) {
        // Refresh token
        NSString *refreshTokenAccountId = [NSString stringWithFormat:@"%@|refresh-token", self.accountId];
        dict = @{
            (id)kSecClass: (id)kSecClassInternetPassword,
            (id)kSecReturnAttributes: (id)kCFBooleanTrue,
            (id)kSecAttrServer: self.app.hostName,
            (id)kSecAttrAccount: refreshTokenAccountId,
        };

        // Remove any old values from the keychain
        err = SecItemDelete((__bridge CFDictionaryRef) dict);
        NSLog(@"Refresh token delete: %d", err);
        // Create dictionary of parameters to add
        dict = @{
            (id)kSecClass: (id)kSecClassInternetPassword,
            (id)kSecAttrType: [NSNumber numberWithUnsignedInt:'otok'],
            (id)kSecAttrServer: self.app.hostName,
            (id)kSecValueData: [self.refreshToken dataUsingEncoding:NSUTF8StringEncoding],
            (id)kSecAttrAccount: refreshTokenAccountId,
        };

        // Try to save to keychain
        err = SecItemAdd((__bridge CFDictionaryRef) dict, NULL);
        NSLog(@"Refresh token save: %d", err);
    }
    
    // @{
    //   "hostname.com": @{
    //     @"user12345": @{
    //       @"accountId": @"user12345",
    //       @"url": @"https://.......",
    //       @"host": @"https://joinmastodon.org",
    //     }
    //   }
    // };
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *servers = [(NSDictionary*)[defaults objectForKey:@"BRMastodonAccount"] mutableCopy] ?: [NSMutableDictionary dictionary];
    NSMutableDictionary *accounts = [(NSDictionary*)servers[self.app.hostName] mutableCopy] ?: [NSMutableDictionary dictionary];
    accounts[self.accountId] = [self dictionaryRepresentation];
    servers[self.app.hostName] = accounts;
    [defaults setObject:servers forKey:@"BRMastodonAccount"];
    [defaults synchronize];
}

- (NSDictionary *)dictionaryRepresentation {
    return @{
        @"accountId": self.accountId,
        @"url": self.url,
        @"displayName": self.displayName,
        @"host": self.app.hostName,
        @"expires": self.expires,
    };
}

- (void)deleteAccount {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *servers = [(NSDictionary*)[defaults objectForKey:@"BRMastodonAccount"] mutableCopy] ?: [NSMutableDictionary dictionary];
    NSMutableDictionary *accounts = [(NSDictionary*)servers[self.app.hostName] mutableCopy] ?: [NSMutableDictionary dictionary];
    [accounts removeObjectForKey:self.accountId];
    servers[self.app.hostName] = accounts;
    [defaults setObject:servers forKey:@"BRMastodonAccount"];
    [defaults synchronize];
    
    // Access token
    NSDictionary *dict = @{
        (id)kSecClass: (id)kSecClassInternetPassword,
        (id)kSecReturnAttributes: (id)kCFBooleanTrue,
        (id)kSecAttrServer: self.app.hostName,
        (id)kSecAttrAccount: self.accountId,
    };

    // Remove any old values from the keychain
    OSStatus err = SecItemDelete((__bridge CFDictionaryRef) dict);
    NSLog(@"Access token delete: %d", err);
    
    NSString *refreshTokenAccountId = [NSString stringWithFormat:@"%@|refresh-token", self.accountId];
    // Refresh token
    dict = @{
        (id)kSecClass: (id)kSecClassInternetPassword,
        (id)kSecReturnAttributes: (id)kCFBooleanTrue,
        (id)kSecAttrServer: self.app.hostName,
        (id)kSecAttrAccount: refreshTokenAccountId,
    };

    // Remove any old values from the keychain
    err = SecItemDelete((__bridge CFDictionaryRef) dict);
    NSLog(@"Refresh token delete: %d", err);
}

- (NSString *)identifier {
    return [NSString stringWithFormat:@"%@:%@", self.app.hostName, self.accountId];
}

@end
