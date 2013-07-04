/*
 * Copyright 1991-2011 Mentor Graphics Corporation
 *
 * All Rights Reserved.
 *
 * THIS WORK CONTAINS TRADE SECRET AND PROPRIETARY INFORMATION WHICH IS THE PROPERTY OF 
 * MENTOR GRAPHICS CORPORATION OR ITS LICENSORS AND IS SUBJECT TO LICENSE TERMS.
 *
 * Prints a message whenever a top-level signal changes.
 */

#include <stdio.h>
#include "mti.h"

static void changed( void * param )
{
	mtiSignalIdT sig = param;
    mti_PrintFormatted( "Time %d: Signal %s changed\n",
                       mti_Now(), mti_GetSignalName(sig) );
}

void monitor_init(
    mtiRegionIdT       region,
    char              *param,
    mtiInterfaceListT *generics,
    mtiInterfaceListT *ports
)
{
    mtiSignalIdT  sig;
    mtiProcessIdT proc;

    sig = mti_FirstSignal( mti_GetTopRegion() );
    while ( sig ) {
        proc = mti_CreateProcess( "monitor", changed, sig );
        mti_Sensitize( proc, sig, MTI_EVENT );
        sig = mti_NextSignal();
    }
}
