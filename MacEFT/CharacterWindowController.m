//
//  CharacterWindowController.m
//  MacEFT
//
//  Created by ugo pozo on 4/29/11.
//  Copyright 2011 Netframe. All rights reserved.
//

#import "CharacterWindowController.h"
#import "CharacterDocument.h"
#import <QuartzCore/CoreAnimation.h>
#import "CharacterViews.h"
#import "EveCharacter.h"
#import "CharacterCreateSheetController.h"
#import "CharacterReloadController.h"

@implementation CharacterWindowController

@synthesize dynamicView, activeViewName, nextViewName, subviews, selectedTasks, reloadEnabled;

// Initialization

- (id)init {
    if ((self = [super initWithWindowNibName:@"Character"])) {

		requiresFullAPIPred = [[NSPredicate predicateWithFormat:@"requiresFullAPI == NO"] retain];
		skillTimer          = nil;
		
		[self setActiveViewName:nil];
		[self setNextViewName:nil];
		[self setSubviews:nil];
		[self setReloadEnabled:YES];
    }
    
    return self;
}

- (void)windowDidLoad {
	CAAnimation * newAnimation;
	NSString * startPath;
	
	[super windowDidLoad];
	
	// Presentation details

	[characterInfoItem setView:characterInfoView];
	[trainingSkillItem setView:trainingSkillView];
	[reloadItem setView:reloadView];

	newAnimation = [CABasicAnimation animation];
	[newAnimation setDelegate:self];
	[[self window] setAnimations:[NSDictionary dictionaryWithObject:newAnimation forKey:@"frame"]];

	// Loading the task list

	startPath = (self.document.currentTask) ? self.document.currentTask : @"0.0";

	[self loadTasks];
	[self populateSubviews];
	[self addAllObservers];
	
	self.selectedTasks = [NSArray arrayWithObject:NSIndexPathFromString(startPath)];

	if (!self.document.character) [self showCharacterSelectionSheet];
	else [self scheduleSkillTimer];


}

- (void)addAllObservers {
	[self addObserver:self forKeyPath:@"selectedTasks" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];
	[self addObserver:self forKeyPath:@"document.character.fullAPI" options:NSKeyValueObservingOptionNew context:nil];

}

- (void)removeAllObservers {
	[self removeObserver:self forKeyPath:@"selectedTasks"];
	[self removeObserver:self forKeyPath:@"document.character.fullAPI"];
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window {
	return [[self document] undoManager];
}

- (CharacterDocument *)document {
	return [super document];
}

- (void)setDocument:(CharacterDocument *)document {
	[super setDocument:document];
}


// Tasks functions


- (void)loadTasks {
	NSDictionary * item;
	NSString * tasksPath;
	NSDictionary * tasksDict;

	tasksPath = [[NSBundle mainBundle] pathForResource:@"CharacterTasks" ofType:@"plist"];
	tasksDict = [NSDictionary dictionaryWithContentsOfFile:tasksPath];

	[self setTasks:[NSMutableArray arrayWithArray:[tasksDict objectForKey:@"Tasks"]]];

	for (item in [[tasksController arrangedObjects] childNodes]){
		[tasksView expandItem:item expandChildren:NO];
	}
}


+ (NSMutableArray *)filteredTasks:(NSMutableArray *)tasks usingPredicate:(NSPredicate *)predicate {
	NSMutableArray * filtered, * children;
	NSMutableDictionary * dict;

	filtered = [NSMutableArray arrayWithArray:[tasks filteredArrayUsingPredicate:predicate]];
	
	for (dict in filtered) {
		children = [self filteredTasks:[dict objectForKey:@"children"] usingPredicate:predicate];
		[dict setObject:children forKey:@"children"];
	}

	return filtered;
}

- (NSMutableArray *)tasks {
	return tasks;
}

- (void)setTasks:(NSMutableArray *)newTasks {
	[tasks release];
	
	if (!self.document.character || self.document.character.fullAPI) tasks = [newTasks retain];
	else tasks = [[[self class] filteredTasks:newTasks usingPredicate:requiresFullAPIPred] retain];
}



// Actions


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if ([keyPath isEqualToString:@"selectedTasks"]) {
		[self selectedTaskChangedFrom:(NSArray *) [change objectForKey:NSKeyValueChangeOldKey] to:(NSArray *) [change objectForKey:NSKeyValueChangeNewKey]];
	}
	else if ([keyPath isEqualToString:@"document.character.fullAPI"]) {
		[self fullAPIChangedTo:[[change objectForKey:NSKeyValueChangeOldKey] boolValue]];
	}
}

- (void)selectedTaskChangedFrom:(NSArray *)oldTaskPaths to:(NSArray *)newTaskPaths {
	NSIndexPath * newTaskPath;
	NSDictionary * newTask;
	
	if ((id) newTaskPaths != [NSNull null]) {
		newTaskPath = [newTaskPaths objectAtIndex:0];
		newTask = (NSDictionary *) [[[tasksController arrangedObjects] descendantNodeAtIndexPath:newTaskPath] representedObject];
		
		[self switchView:(NSString *) [newTask objectForKey:@"view"]];

		[[self document] setCurrentTask:NSStringFromIndexPath(newTaskPath)];
	}
}

- (void)fullAPIChangedTo:(BOOL)fullAPI {
	NSArray * currentTasks;

	currentTasks = self.selectedTasks;
	[self loadTasks];
	[[[subviews objectForKey:[self activeViewName]] view] removeFromSuperview];
	self.activeViewName = nil;
	self.selectedTasks = currentTasks;
}

- (void)showCharacterSelectionSheet {
	CharacterCreateSheetController * ccController;

	ccController = [[CharacterCreateSheetController alloc] init];

	[self.document addWindowController:ccController];

	[self.document showSheet:ccController];

	[ccController release];
}

- (IBAction)performReload:(id)sender {
	[self cancelSkillTimer];
	[self.document showSheet:self.document.reloadController];
}

- (void)scheduleSkillTimer {
	[self cancelSkillTimer];
	
	skillTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
												  target:self.document.character
												selector:@selector(updateSkillInTraining:)
												userInfo:nil
												 repeats:YES];
}

- (void)cancelSkillTimer {
	if (skillTimer) {
		[skillTimer invalidate];
		skillTimer = nil;
	}
}

// Notifications received

- (void)windowWillClose:(NSNotification *)notif {
	if ([self.document fileURL]) [self.document saveDocument:self];
	
	[self.document removeReloadController];
	
	[[[subviews objectForKey:[self activeViewName]] view] removeFromSuperview];
	[self setSubviews:nil];
	
	[self removeAllObservers];
	[[self window] setAnimations:nil];

}

// Delegated methods

- (BOOL)isTitleItem:(NSDictionary *)item {
	return [[item objectForKey:@"groupItem"] boolValue];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item {
	return [self isTitleItem:[item representedObject]];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldShowOutlineCellForItem:(id)item {
	return ![self isTitleItem:[item representedObject]];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldCollapseItem:(id)item {
	return ![self isTitleItem:[item representedObject]];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
	return ![self isTitleItem:[item representedObject]];
}

- (BOOL)shouldCascadeWindows {
	return NO;
}

// Subviews handling 

- (void)populateSubviews {
	EveViewController * viewController;
	NSMutableDictionary * mSubviews;
	NSDictionary * savedFrame;
	NSString * viewName;
	NSUInteger i;

	mSubviews = [NSMutableDictionary dictionary];

	
	for (i = 0; subviewsNames[i]; i++) {
		viewName       = [NSString stringWithUTF8String:subviewsNames[i]];
		viewController = [NSClassFromString(viewName) viewController];

		[viewController setDocument:[self document]];

		[mSubviews setValue:viewController
					 forKey:viewName];

		if (self.document.viewSizes && (savedFrame = [self.document.viewSizes objectForKey:viewName])) {
			[[viewController view] setFrame:NSRectFromDictionary(savedFrame)];
		}
	}

	[self setSubviews:[NSDictionary dictionaryWithDictionary:mSubviews]];
}


- (void)switchView:(NSString *)newViewName {
	NSView * newView, * activeView;
	NSViewController * newController;
	NSRect windowFrame, currentFrame, newDynFrame;

	newController = [[self subviews] objectForKey:newViewName];
	
	if (![self nextViewName] && newController) {
		newView = [newController view];

		if ([self activeViewName]) {
			activeView = [[[self subviews] objectForKey:[self activeViewName]] view];
			[activeView removeFromSuperview];
		}
		else activeView = nil;

		newDynFrame = [newView frame];
		
		newDynFrame.origin.x = 0;
		newDynFrame.origin.y = 0;
		
		[newView setFrame:newDynFrame];

		windowFrame  = [[self window] frame];
		currentFrame = [dynamicView frame];

		windowFrame.size.width  += newDynFrame.size.width  - currentFrame.size.width;
		windowFrame.size.height += newDynFrame.size.height - currentFrame.size.height;
		windowFrame.origin.y    -= newDynFrame.size.height - currentFrame.size.height;

		if (activeView) {
			[self setNextViewName:newViewName];
			
			[[[self window] animator] setFrame:windowFrame display:YES];
		}
		else {
			if (self.document.windowOrigin) {
				windowFrame.origin.y = [[self.document.windowOrigin objectForKey:@"y"] integerValue];
				windowFrame.origin.x = [[self.document.windowOrigin objectForKey:@"x"] integerValue];
			}
			
			[[self window] setFrame:windowFrame display:YES];
			[dynamicView addSubview:newView];

			[self setActiveViewName:newViewName];
		}
	}
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)finished {
	if ([self nextViewName]) {
		[[self dynamicView] addSubview:[[[self subviews] objectForKey:[self nextViewName]] view]];

		[self setActiveViewName:[self nextViewName]];
		[self setNextViewName:nil];
		[self windowDidMove:nil];
	}
}


- (void)windowDidResize:(NSNotification *)notification {
	__block NSMutableDictionary * windowSizes;


	if (self.subviews) {
		windowSizes = [NSMutableDictionary dictionary];

		[self.subviews enumerateKeysAndObjectsUsingBlock:^(NSString * key, NSViewController * viewController, BOOL * stop) {
			[windowSizes setObject:NSDictionaryFromRect([[viewController view] frame]) forKey:key];
			
		}];
		
		self.document.viewSizes = [NSDictionary dictionaryWithDictionary:windowSizes];


	}
}

- (void)windowDidMove:(NSNotification *)notification {
	NSNumber * x, * y;
	NSRect frame;
	
	frame = [self window].frame;
	
	x = [NSNumber numberWithInteger:frame.origin.x];
	y = [NSNumber numberWithInteger:frame.origin.y];
	
	self.document.windowOrigin = [NSDictionary dictionaryWithObjectsAndKeys:x, @"x", y, @"y", nil];
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName {
	if (self.document.character && [self.document fileURL]) {
		displayName = [NSString stringWithFormat:@"%@ (%@)", self.document.character.name, displayName];
	}
	
	return displayName;
}


- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
	BOOL enabled;
	
	enabled = YES;
	
	if ([menuItem tag] == 1) {
		enabled = reloadEnabled;
	}
	
	return enabled;
}

// Cleanup

- (void)dealloc {
	[requiresFullAPIPred release];
	
	tasksView.delegate = nil;
	/* WTF, Cocoa?! I shouldn't be responsible for cleaning delegates that
	 * were set in the Interface Builder! But if I don't this, tasksView
	 * go apeshit calling methods on CharacterWindowController's zombie
	 * left and right.
	 */
	
	if (skillTimer) [skillTimer invalidate];
	
	[self setTasks:nil];
	[self setSubviews:nil];
	[self setActiveViewName:nil];
	[self setNextViewName:nil];

    [super dealloc];
}

@end

NSString * NSStringFromIndexPath(NSIndexPath * path) {
	NSMutableArray * pathArr;
	NSUInteger i;
	
	pathArr = [NSMutableArray array];

	if (!pathArr) return nil;

	for (i = 0; i < [path length]; i++) {
		[pathArr addObject:[NSNumber numberWithInteger:[path indexAtPosition:i]]];
	}
	
	return [pathArr componentsJoinedByString:@"."];
}

NSIndexPath * NSIndexPathFromString(NSString * str) {
	NSArray * pathArr;
	NSString * component;
	NSUInteger * indexes, count, i;
	NSIndexPath * path;

	pathArr = [str componentsSeparatedByString:@"."];
	count   = [pathArr count];
	indexes = calloc(sizeof(NSUInteger), count);

	for (i = 0; i < count; i++) {
		component = [pathArr objectAtIndex:i];

		if (!sscanf([component UTF8String], "%u", indexes + i)) {
			free(indexes);	
			return nil;
		}
	}

	path = [NSIndexPath indexPathWithIndexes:indexes length:count];

	free(indexes);
	
	return path;

}
NSDictionary * NSDictionaryFromRect(NSRect rect) {
	NSDictionary * rectDict;

	rectDict = [NSDictionary dictionaryWithObjectsAndKeys:
					[NSNumber numberWithDouble:(double) rect.origin.x], @"ox",
					[NSNumber numberWithDouble:(double) rect.origin.y], @"oy",
					[NSNumber numberWithDouble:(double) rect.size.width], @"sw",
					[NSNumber numberWithDouble:(double) rect.size.height], @"sh",
					nil];

	return rectDict;
}

NSRect NSRectFromDictionary(NSDictionary * rectDict) {
	CGFloat ox, oy, sw, sh;
	NSNumber * oxn, * oyn, * swn, * shn;

	oxn = [rectDict objectForKey:@"ox"];
	ox  = (oxn) ? (CGFloat) [oxn doubleValue] : 0.0;

	oyn = [rectDict objectForKey:@"oy"];
	oy  = (oyn) ? (CGFloat) [oyn doubleValue] : 0.0;

	swn = [rectDict objectForKey:@"sw"];
	sw  = (swn) ? (CGFloat) [swn doubleValue] : 0.0;

	shn = [rectDict objectForKey:@"sh"];
	sh  = (shn) ? (CGFloat) [shn doubleValue] : 0.0;
	
	return NSMakeRect(ox, oy, sw, sh);
}
