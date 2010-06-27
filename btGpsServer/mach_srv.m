/*
 *  mach_srv.mm
 *  btTest
 *
 *  Created by msftguy on 6/25/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#include "mach_srv.h"

#include <mach/mach.h>
#include <mach/ndr.h>
#include <mach/mig.h>

#include <pthread.h>

#include "log.h"
#include "BtGpsDefs.h"
#include "btGpsServer.h"

mach_port_t m_port; 

static pthread_mutex_t queue_lock = PTHREAD_MUTEX_INITIALIZER;

void KQueueLock()
{
	pthread_mutex_lock(&queue_lock);
}

void KQueueUnlock()
{
	pthread_mutex_unlock(&queue_lock);
}

void mach_server_callback(CFMachPortRef port, void *msg, CFIndex size, void *info)
{
	mig_reply_error_t *request = msg;
	mig_reply_error_t *reply;
	mach_msg_return_t mr;
	int               options;
	(void)port;		// Unused
	(void)size;		// Unused
	(void)info;		// Unused
	
	KQueueLock();
	
	/* allocate a reply buffer */
	reply = CFAllocatorAllocate(NULL, srv_BtGps_subsystem.maxsize, 0);
	
	/* call the MiG server routine */
	(void) BtGps_server(&request->Head, &reply->Head);
	
	if (!(reply->Head.msgh_bits & MACH_MSGH_BITS_COMPLEX) && (reply->RetCode != KERN_SUCCESS))
	{
        if (reply->RetCode == MIG_NO_REPLY)
		{
            /*
             * This return code is a little tricky -- it appears that the
             * demux routine found an error of some sort, but since that
             * error would not normally get returned either to the local
             * user or the remote one, we pretend it's ok.
             */
            CFAllocatorDeallocate(NULL, reply);
            goto done;
		}
		
        /*
         * destroy any out-of-line data in the request buffer but don't destroy
         * the reply port right (since we need that to send an error message).
         */
        request->Head.msgh_remote_port = MACH_PORT_NULL;
        mach_msg_destroy(&request->Head);
	}
	
    if (reply->Head.msgh_remote_port == MACH_PORT_NULL)
	{
        /* no reply port, so destroy the reply */
        if (reply->Head.msgh_bits & MACH_MSGH_BITS_COMPLEX)
            mach_msg_destroy(&reply->Head);
        CFAllocatorDeallocate(NULL, reply);
        goto done;
	}
	
    /*
     * send reply.
     *
     * We don't want to block indefinitely because the client
     * isn't receiving messages from the reply port.
     * If we have a send-once right for the reply port, then
     * this isn't a concern because the send won't block.
     * If we have a send right, we need to use MACH_SEND_TIMEOUT.
     * To avoid falling off the kernel's fast RPC path unnecessarily,
     * we only supply MACH_SEND_TIMEOUT when absolutely necessary.
     */
	
    options = MACH_SEND_MSG;
    if (MACH_MSGH_BITS_REMOTE(reply->Head.msgh_bits) == MACH_MSG_TYPE_MOVE_SEND_ONCE)
        options |= MACH_SEND_TIMEOUT;
	
    mr = mach_msg(&reply->Head,		/* msg */
				  options,			/* option */
				  reply->Head.msgh_size,	/* send_size */
				  0,			/* rcv_size */
				  MACH_PORT_NULL,		/* rcv_name */
				  MACH_MSG_TIMEOUT_NONE,	/* timeout */
				  MACH_PORT_NULL);		/* notify */
	
    /* Has a message error occurred? */
    switch (mr)
	{
        case MACH_SEND_INVALID_DEST:
        case MACH_SEND_TIMED_OUT:
            /* the reply can't be delivered, so destroy it */
            mach_msg_destroy(&reply->Head);
            break;
			
        default :
            /* Includes success case. */
            break;
	}
	
    CFAllocatorDeallocate(NULL, reply);
	
done:
	KQueueUnlock();
}

void ClientDeathCallback(CFMachPortRef unusedport, void *voidmsg, CFIndex size, void *info)
{
	KQueueLock();
	mach_msg_header_t *msg = (mach_msg_header_t *)voidmsg;
	(void)unusedport; // Unused
	(void)size; // Unused
	(void)info; // Unused
	if (msg->msgh_id == MACH_NOTIFY_DEAD_NAME)
	{
		const mach_dead_name_notification_t *const deathMessage = (mach_dead_name_notification_t *)msg;
		//AbortClient(deathMessage->not_port, NULL);
		
		/* Deallocate the send right that came in the dead name notification */
		mach_port_destroy(mach_task_self(), deathMessage->not_port);
	}
	KQueueUnlock();
}

void SignalCallback(CFMachPortRef port, void *msg, CFIndex size, void *info)
{
	(void)port;		// Unused
	(void)size;		// Unused
	(void)info;		// Unused
	mach_msg_header_t *msg_header = (mach_msg_header_t *)msg;
	
	// We're running on the CFRunLoop (Mach port) thread, not the kqueue thread, so we need to grab the KQueueLock before proceeding
	KQueueLock();
	switch(msg_header->msgh_id)
	{
		case SIGINT:
		case SIGTERM:	exit(0); break;
		default: LogMsg("SignalCallback: Unknown signal %d", msg_header->msgh_id); break;
	}
	KQueueUnlock();
}

void start_mach_server(mach_port_t portNum) {
	CFMachPortContext *ctx = NULL;
	CFMachPortRef s_port = CFMachPortCreateWithPort(kCFAllocatorDefault, portNum, 
												 mach_server_callback, ctx, 
												 NO /* *shouldFreeInfo */);
	CFRunLoopSourceRef s_rls  = CFMachPortCreateRunLoopSource(NULL, s_port, 0);
	CFRunLoopRef CFRunLoop = CFRunLoopGetCurrent();
	CFRunLoopAddSource(CFRunLoop, s_rls, kCFRunLoopDefaultMode);
	CFRelease(s_rls);
}
