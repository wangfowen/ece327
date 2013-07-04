/*
 * Copyright 1991-2011 Mentor Graphics Corporation
 *
 * All Rights Reserved.
 *
 * THIS WORK CONTAINS TRADE SECRET AND PROPRIETARY INFORMATION WHICH IS THE PROPERTY OF 
 * MENTOR GRAPHICS CORPORATION OR ITS LICENSORS AND IS SUBJECT TO LICENSE TERMS.
 *
 * This program creates a process sensitive to two signals and
 * whenever one or both of the signals change it does an AND operation
 * and drives the value onto a third signal.
 */

#include <stdio.h>
#include "mti.h"

typedef struct {
    mtiSignalIdT in1;
    mtiSignalIdT in2;
    mtiDriverIdT out1;
} inst_rec;

void do_and( void * param )
{
    inst_rec * ip = (inst_rec *)param;
    mtiInt32T  val1, val2;
    mtiInt32T  result;

    val1   = mti_GetSignalValue( ip->in1 );
    val2   = mti_GetSignalValue( ip->in2 );
    result = val1 & val2;
    mti_ScheduleDriver( ip->out1, result, 0, MTI_INERTIAL );
}

void and_gate_init(
    mtiRegionIdT       region,
    char              *param,
    mtiInterfaceListT *generics,
    mtiInterfaceListT *ports
)
{
    inst_rec     *ip;
    mtiSignalIdT  outp;
    mtiProcessIdT proc;

    ip = (inst_rec *)mti_Malloc( sizeof(inst_rec) );
    ip->in1 = mti_FindPort( ports, "in1" );
    ip->in2 = mti_FindPort( ports, "in2" );
    outp = mti_FindPort( ports, "out1" );
    ip->out1 = mti_CreateDriver( outp );
    proc = mti_CreateProcess( "p1", do_and, ip );
    mti_Sensitize( proc, ip->in1, MTI_EVENT );
    mti_Sensitize( proc, ip->in2, MTI_EVENT );
}
