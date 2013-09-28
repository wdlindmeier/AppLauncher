//
//  ITPDocument.h
//  AppLauncher
//
//  Created by William Lindmeier on 9/21/13.
//  Copyright (c) 2013 ITP. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ITPDocument : NSDocument <
NSXMLParserDelegate,
NSTableViewDataSource,
NSTableViewDelegate>

@property (nonatomic, strong) IBOutlet NSButton *buttonStart;
@property (nonatomic, strong) IBOutlet NSButton *buttonStop;
@property (nonatomic, strong) IBOutlet NSButton *buttonAutoAdvance;
@property (nonatomic, strong) IBOutlet NSButton *buttonLoop;

@property (nonatomic, strong) IBOutlet NSTableView *tableView;

@property (nonatomic, assign) BOOL shouldLoop;
@property (nonatomic, assign) BOOL shouldAutoAdvance;

@property (nonatomic, assign) NSString *currentAppName;
@property (nonatomic, assign) NSString *currentTimeRemaining;

- (IBAction)buttonStartPressed:(id)sender;
- (IBAction)buttonStopPressed:(id)sender;

@end
