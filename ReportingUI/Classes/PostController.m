
#import "PostController.h"

#include <sys/socket.h>
#include <unistd.h>

#include <CFNetwork/CFNetwork.h>


        
#pragma mark * PostController

enum {
    kPostBufferSize = 32768
};

//#if TARGET_IPHONE_SIMULATOR
//    static NSString * kDefaultPostURLText = @"http://localhost:9000/cgi-bin/PostIt.py";
//#else
//    static NSString * kDefaultPostURLText = @"";
//#endif

@interface PostController ()

// Properties that don't need to be seen by the outside world.

@property (nonatomic, readonly) BOOL              isSending;
@property (nonatomic, retain)   NSURLConnection * connection;
@property (nonatomic, retain)   NSData*			  mappedFile;
//@property (nonatomic, retain)   NSOutputStream *  producerStream;
//@property (nonatomic, retain)   NSInputStream *   consumerStream;
@property (nonatomic, retain)   NSString*		  boundaryStr;
@property (nonatomic, retain)   NSURL*			  serverUrl;
@property (nonatomic, retain)   NSURL*		      uploadUrl;
@property (nonatomic, retain)   NSArray*		  filesToSend;
@property (nonatomic, retain)   DataReadStream*	  dataStream;


@end

@implementation PostController

+ (void)releaseObj:(id)obj
    // +++ See comment in -_stopSendWithStatus:.
{
    [obj release];
}

#pragma mark * Status management

// These methods are used by the core transfer code to update the UI.

- (void)_sendDidStopWithStatus:(NSString *)statusString
{
	NSLog(@"_sendDidStopWithStatus: %@", statusString);
}

#pragma mark * Core transfer code

// This is the code that actually does the networking.

@synthesize connection      = _connection;
@synthesize mappedFile      = _mappedFile;
//@synthesize producerStream  = _producerStream;
//@synthesize consumerStream  = _consumerStream;
@synthesize boundaryStr		= _boundaryStr;
@synthesize serverUrl		= _serverUrl;
@synthesize uploadUrl		= _uploadUrl;
@synthesize filesToSend		= _filesToSend;
@synthesize dataStream		= _dataStream;

- (BOOL)isSending
{
    return (self.connection != nil);
}

- (NSString *)_generateBoundaryString
{
    CFUUIDRef       uuid;
    CFStringRef     uuidStr;
    NSString *      result;
    
    uuid = CFUUIDCreate(NULL);
    assert(uuid != NULL);
    
    uuidStr = CFUUIDCreateString(NULL, uuid);
    assert(uuidStr != NULL);
    
    result = [NSString stringWithFormat:@"Boundary-%@", uuidStr];
    
    CFRelease(uuidStr);
    CFRelease(uuid);
    
    return result;
}

- (void)startUpload
{
	if (self.isSending ) {
		NSLog(@"Already sending..");
		return;
	}

	if (self.uploadUrl == nil) {
		NSLog(@"startUpload: getting upload URL from server URL %@", self.serverUrl);
		_getUploadUrl = YES;
		NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL:self.serverUrl];
		[req setHTTPMethod:@"GET"];
		[req setHTTPBody:[NSData data]];
		[req setCachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData];
		[req setValue:[[UIDevice currentDevice] uniqueIdentifier] forHTTPHeaderField:@"Udid"];
		
		[NSURLConnection connectionWithRequest:req delegate:self];
		return;
	}
	
    BOOL                    success;
    NSMutableURLRequest *   request;
    
	assert(self.connection == nil);         // don't tap send twice in a row!
    assert(self.mappedFile == nil);         // ditto

    // If the URL is bogus, let the user know.  Otherwise kick off the connection.

	NSLog(@"_startUpload: %@", self.uploadUrl);

    if ( ! success) {
        NSLog(@"Invalid URL");
    } else {        
		self.boundaryStr = [self _generateBoundaryString];
		assert(self.boundaryStr != nil);
		
		self.dataStream = [[[DataReadStream alloc] initWithDataSource:self userInfo:self]autorelease];
        // Open a connection for the URL, configured to POST the file.

        request = [NSMutableURLRequest requestWithURL:self.uploadUrl];
        assert(request != nil);
        
        [request setHTTPMethod:@"POST"];
        
		[request setHTTPBodyStream:self.dataStream];
        
        [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=\"%@\"", self.boundaryStr] forHTTPHeaderField:@"Content-Type"];
		[request setValue:@"chunked" forHTTPHeaderField:@"Transfer-Encoding"];
		[request setValue:@"100-continue" forHTTPHeaderField:@"Expect"];
		
		//[request setValue:[NSString stringWithFormat:@"%llu", ???] forHTTPHeaderField:@"Content-Length"];
        
        self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
        assert(self.connection != nil);
        
        // Tell the UI we're sending.
    }
}

- (void)_stopSendWithStatus:(NSString *)statusString
{
    [_buffers removeAllObjects];
    if (self.connection != nil) {
        [self.connection cancel];
        self.connection = nil;
    }
	
	if (self.mappedFile != nil) {
		self.mappedFile = nil;
		if (_bzStream.next_in != NULL) {
			BZ2_bzCompressEnd(&_bzStream);
			memset(&_bzStream, 0 ,sizeof(_bzStream));
		}
	}

	[self _sendDidStopWithStatus:statusString];
}

- (BOOL) openDataStream:(id)userInfo
{
	NSLog(@"openDataStream");
	return YES;
}

- (void) closeDataStream:(id)userInfo
{
	NSLog(@"closeDataStream");
}

- (NSInteger) readDataFromStream:(id)userInfo buffer:(void*)buffer maxLength:(NSUInteger)length
//Return num read bytes on success, 0 at end or <0 on error
{
	NSLog(@"readDataFromStream: length=%u", length);
	
	NSInteger bytesRead = 0;
	#pragma unused(userInfo)
	do {
		// Check to see if we've run off the end of our buffer.  If we have, 
		// work out the next buffer of data to send.
		
		if ([_buffers count] != 0) {
			NSData* currentBuffer = [_buffers objectAtIndex:0];
			if (_bufferOffset == [currentBuffer length]) {
				[_buffers removeObjectAtIndex:0];
				_bufferOffset = 0;
			}
		}
		if ([_buffers count] == 0) {
			_bufferOffset = 0;
			
			if (self.mappedFile == nil) {
				
				if (_currentFileIndex >= [self.filesToSend count]) {
					// If we've failed to produce any more data, we close the stream 
					// to indicate to NSURLConnection that we're all done.  We only do 
					// this if producerStream is still valid to avoid running it in the 
					// file read error case.
					
					break;			
				}
				
				memset(&_bzStream, 0, sizeof(_bzStream));

				NSString* currentFilePath;
				BOOL isDataObject = NO;
				id currentObj = [self.filesToSend objectAtIndex:_currentFileIndex];
				if ([currentObj isKindOfClass:[NSString class]]) {
					currentFilePath = currentObj;
				} else if ([NSPropertyListSerialization propertyList:currentObj isValidForFormat:NSPropertyListXMLFormat_v1_0]) { 
					currentFilePath = @"ReportMetadata.plist";
					isDataObject = YES;
				} else {
					NSLog(@"readDataFromStream: Skipping unknown object type: %@", [currentObj class]);
					goto nextfile;
				}

				
				
				NSString* bodyPrefixStr = [NSString stringWithFormat:
								 @"--%@\r\n"
								 "Content-Disposition: form-data; name=\"file\"; filename=\"%@%@\"\r\n"
								 "Content-Type: %@\r\n"
								 "\r\n",
								 self.boundaryStr,
								 [currentFilePath lastPathComponent],       // +++ very broken for non-ASCII
								 isDataObject ? @"" : @".bz2",
								 @"binary/octet-stream"
								 ];
				
				NSData* prefixData = [bodyPrefixStr dataUsingEncoding:NSASCIIStringEncoding];
				assert(prefixData != nil);
				
				if (isDataObject) {
					[_buffers addObject:prefixData];
					[_buffers addObject:[NSPropertyListSerialization dataFromPropertyList:currentObj format:NSPropertyListXMLFormat_v1_0 errorDescription:nil]];
					goto nextfile;
				}
				
				self.mappedFile = [NSData dataWithContentsOfMappedFile:currentFilePath];					
				
				if (self.mappedFile == nil) {
					NSLog(@"readDataFromStream: dataWithContentsOfMappedFile(%@) Failed!", currentFilePath);
					goto nextfile;
				}
			
				const int BZ2_BLOCKSIZE = 9;
				int bzErr = BZ2_bzCompressInit(&_bzStream, BZ2_BLOCKSIZE, 0, 0);
				if (bzErr != BZ_OK) {
					NSLog(@"readDataFromStream: BZ2_bzCompressInit failed (%i)!", bzErr);
				}
				
				const NSUInteger MAX_FILESIZE = 1 * 1024 * 1024;
				const NSUInteger skip = [self.mappedFile length] < MAX_FILESIZE ? 0 : [self.mappedFile length] - MAX_FILESIZE;
				
				_bzStream.next_in = (char*)[self.mappedFile bytes] + skip;
				_bzStream.avail_in = [self.mappedFile length] - skip;
				
				[_buffers addObject:prefixData];
			}
			
			// If we still have file data to send, read the next chunk. 
			if (self.mappedFile != nil) {
				char bz2Buf[kPostBufferSize];

				_bzStream.next_out = bz2Buf;
				_bzStream.avail_out = sizeof(bz2Buf);
				
				int bzErr = BZ2_bzCompress(&_bzStream, _bzStream.avail_in != 0 ? BZ_RUN : BZ_FINISH);	
				if (bzErr < BZ_OK) {
					NSLog(@"readDataFromStream: BZ2_bzCompress failed (%i)!", bzErr);
					NSLog(@"avail_in: %u; filesize: %u; ", _bzStream.avail_in, [self.mappedFile length]);
				}
				
				if (_bzStream.next_out != bz2Buf) {
					[_buffers addObject:[NSData dataWithBytes:bz2Buf length:_bzStream.next_out - bz2Buf]];
				}
				if (bzErr == BZ_STREAM_END) {
					// If we hit the end of the file, transition to sending the 
					// next one
nextfile:
					self.mappedFile = nil; 
					if (_bzStream.next_in != NULL) {
						BZ2_bzCompressEnd(&_bzStream);
						memset(&_bzStream, 0, sizeof(_bzStream));
					}
					++_currentFileIndex;
					
					NSString* suffixString;
					if (_currentFileIndex >= [self.filesToSend count]) {
						suffixString = [NSString stringWithFormat:@"\r\n--%@--", self.boundaryStr];
					} else {
						suffixString = [NSString stringWithFormat:@"\r\n", self.boundaryStr];
					}
					[_buffers addObject:[suffixString dataUsingEncoding:NSASCIIStringEncoding]];

				}
			}
		}
		
		// Send the next chunk of data in our buffer.
		
		if ([_buffers count] != 0) {
			NSData* currentBuffer = [_buffers objectAtIndex:0];
			if (_bufferOffset != [currentBuffer length]) {
				NSInteger bytesWritten = MIN(length - bytesRead, [currentBuffer length] - _bufferOffset);
				memcpy((unsigned char*)buffer + bytesRead, (unsigned char*)[currentBuffer bytes] + _bufferOffset, bytesWritten);
				_bufferOffset += bytesWritten;
				bytesRead += bytesWritten;
			}
		}
		NSLog(@"stream:readDataFromStream(loop): file %u, bufOffs=%u, ret=%u", _currentFileIndex, _bufferOffset, bytesRead);
	} while (bytesRead < length);
	NSLog(@"stream:readDataFromStream(leaving): file %u, bufOffs=%u, ret=%u", _currentFileIndex, _bufferOffset, bytesRead);
	return bytesRead;
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response
// redirect delegate
// set upload url for blob storage thingie
{
	if (_getUploadUrl && response != nil) {
		_getUploadUrl = NO;
		self.uploadUrl = [request URL];
		
		[connection cancel];
		NSLog(@"Redirect: %@ -> %@", self.serverUrl, self.uploadUrl);
		[self startUpload];
		return nil;
	}
	return request;
}

- (void)connection:(NSURLConnection *)theConnection didReceiveResponse:(NSURLResponse *)response
    // A delegate method called by the NSURLConnection when the request/response 
    // exchange is complete.  We look at the response to check that the HTTP 
    // status code is 2xx.  If it isn't, we fail right now.
{
    #pragma unused(theConnection)
    NSHTTPURLResponse * httpResponse;

    assert(theConnection == self.connection);
    
    httpResponse = (NSHTTPURLResponse *) response;
    assert( [httpResponse isKindOfClass:[NSHTTPURLResponse class]] );
    
    if ((httpResponse.statusCode / 100) != 2) {
        [self _stopSendWithStatus:[NSString stringWithFormat:@"HTTP error %zd", (ssize_t) httpResponse.statusCode]];
    } else {
        NSLog(@"Response OK.");
    }    
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)data
    // A delegate method called by the NSURLConnection as data arrives.  The 
    // response data for a POST is only for useful for debugging purposes, 
    // so we just drop it on the floor.
{
    #pragma unused(theConnection)
    #pragma unused(data)

    assert(theConnection == self.connection);

    // do nothing
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
    // A delegate method called by the NSURLConnection if the connection fails. 
    // We shut down the connection and display the failure.  Production quality code 
    // would either display or log the actual error.
{
    #pragma unused(theConnection)
    #pragma unused(error)
    assert(theConnection == self.connection);
    
    [self _stopSendWithStatus:@"Connection failed"];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection
    // A delegate method called by the NSURLConnection when the connection has been 
    // done successfully.  We shut down the connection with a nil status, which 
    // causes the image to be displayed.
{
    #pragma unused(theConnection)
    assert(theConnection == self.connection);
    
    [self _stopSendWithStatus:nil];
}

#pragma mark * Actions

- (void) addFiles:(NSArray*) p_filesToSend
{
	self.filesToSend = p_filesToSend;
	_currentFileIndex = 0;
}

- (IBAction)cancelAction:(id)sender
{
    #pragma unused(sender)
    [self _stopSendWithStatus:@"Cancelled"];
}

- (PostController*) init
{
	NSLog(@"[PostController init]");
	_buffers = [[NSMutableArray alloc] init];
	_inited = YES;
	//self.serverUrl = [NSURL URLWithString:@"http://192.168.0.185/report"];
	self.serverUrl = [NSURL URLWithString:@"http://icrashrep.appspot.com/report"];
	return self;
}

- (void)dealloc
{
    [self _stopSendWithStatus:@"Stopped"];

	[_buffers release];
	[_connection release];
	[_fileStream release];
	[_producerStream release];
	[_consumerStream release];
	[_boundaryStr release];
	[_serverUrl release];
	[_uploadUrl release];
	[_filesToSend release];
	
    [super dealloc];
}

@end
