//
//  CmdRunner.m
//  ReportingUI
//
//  Created by svp on 8/24/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "CmdRunner.h"


@implementation CmdRunner

@synthesize command = _command;
@synthesize args = _args;
@synthesize completionObject = _completionObject;
@synthesize completionCallback = _completionCallback;
@synthesize result = _result;
@synthesize completionContext = _completionContext;


- (void) invokeCompletionCallback
{
	[self.completionObject performSelector:self.completionCallback withObject:(id)self.result withObject:self.completionContext];
}

- (const char**) prepExecArgs
{
	NSLog(@"prepExecArgs enter");
	int numArgs = [self.args count];
	const char** cargs = malloc(sizeof(char*) * (numArgs + 2));
	cargs[0] = [self.command UTF8String];
	for (int i = 0; i < numArgs; ++i) {		
		cargs[i + 1] = [[[self args] objectAtIndex:i] UTF8String];
	}
	cargs[numArgs + 1] = NULL;
	return cargs;
}


void doExec(const char** cargs)
{
	NSLog(@"doExec() enter");
	setuid(0);
	NSLog(@"About to call execv(%s)", cargs[0]);
	execv(cargs[0], (char* const*)cargs);
	NSLog(@"BUGBUG: doExec: execv returned!!");
	exit(-1);
}

- (int) forkAndExec
{
	pid_t child_pid, wpid;
	int status;
	
	const char** cargs = [self prepExecArgs];
	
	child_pid = fork();
	if (child_pid == -1) {      /* fork() failed */
		return -1;
	}
	
	if (child_pid == 0) {       /* This is the child */
		/* Child does some work and then terminates */
		doExec(cargs);
		assert(false);
		return -1;
		
	} else {
		/* This is the parent */
		NSLog(@"Waiting for child PID %u", child_pid);
		for(;;) {
			wpid = waitpid(child_pid, &status, WUNTRACED
#ifdef WCONTINUED       /* Not all implementations support this */
						   | WCONTINUED
#endif
						   );
			if (wpid == -1) {
				NSLog(@"waitpid error");
				return -1;
			}
			
			
			if (WIFEXITED(status)) {
				NSLog(@"Child process %@ exited with code %u", [self command], WEXITSTATUS(status));
				return WEXITSTATUS(status);
			}	
			if (WIFSIGNALED(status)) {
				NSLog(@"Child process %@ exited with signal %u", [self command], WTERMSIG(status));
				return 0x8F;
			}	
//			} else if (WIFSTOPPED(status)) {
//				printf("child stopped (signal %d)\n", WSTOPSIG(status));
//				
//				
//#ifdef WIFCONTINUED     /* Not all implementations support this */
//			} else if (WIFCONTINUED(status)) {
//				printf("child continued\n");
//#endif
//			} else {    /* Non-standard case -- may never happen */
//				printf("Unexpected status (0x%x)\n", status);
//			}
		}// while (!WIFEXITED(status) && !WIFSIGNALED(status));
	}
}

- (void) bgThread
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	self.result = [self forkAndExec];
	
	[self performSelectorOnMainThread:@selector(invokeCompletionCallback) withObject:nil waitUntilDone:YES];
	[self release];
	[pool release];
}

- (void) runInBackground
{
	[self retain];
	[self performSelectorInBackground:@selector(bgThread) withObject:self];
}

+ (void) runCommandInBackground:(NSString*)command withArguments:(NSArray*)args completionObject:(id)obj andCallback:(SEL)completionCallback andContext:(id)context
{
	CmdRunner* cr = [[[CmdRunner alloc] init] autorelease];
	cr.command = command;
	cr.args = args;
	cr.completionObject = obj;
	cr.completionCallback = completionCallback;
	cr.completionContext = context;
	[cr runInBackground];
}

@end
