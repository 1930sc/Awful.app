//
//  AwfulUser.h
//  Awful
//
//  Created by Sean Berry on 11/21/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AwfulUser : NSObject

@property (nonatomic, strong) NSString *userName;
@property (nonatomic, assign) int postsPerPage;
@property (nonatomic, strong) NSNumber *userID;

+(AwfulUser *)currentUser;

-(void)loadUser;
-(void)saveUser;
-(void)killUser;
-(NSString *)getPath;

@end
