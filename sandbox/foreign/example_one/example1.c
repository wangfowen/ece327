/*
 * Copyright 1991-2011 Mentor Graphics Corporation
 *
 * All Rights Reserved.
 *
 * THIS WORK CONTAINS TRADE SECRET AND PROPRIETARY INFORMATION WHICH IS THE PROPERTY OF 
 * MENTOR GRAPHICS CORPORATION OR ITS LICENSORS AND IS SUBJECT TO LICENSE TERMS.
 */

#include <stdio.h>
#include "mti.h"

typedef struct {
    mtiSignalIdT enum_a;
    mtiSignalIdT enum_b;
    mtiDriverIdT enum_out;
    mtiSignalIdT int_a;
    mtiSignalIdT int_b;
    mtiDriverIdT int_out;
    mtiSignalIdT float_a;
    mtiSignalIdT float_b;
    mtiDriverIdT float_out;
    mtiSignalIdT array_a;
    mtiSignalIdT array_b;
    mtiDriverIdT array_out;
} inst_rec;

typedef enum boolean_tag {
    BOOL_FALSE,
    BOOL_TRUE
} boolean;

static char msgbuf[256];

static void eval_enum(void *param);
static void eval_int(void *param);
static void eval_float(void *param);
static void eval_array(void *param);

void cif_init(
  mtiRegionIdT       region,
  char              *param,
  mtiInterfaceListT *generics,
  mtiInterfaceListT *ports
)
{
    inst_rec     *ip;
    mtiProcessIdT proc;

    ip = (inst_rec *)mti_Malloc(sizeof(inst_rec));
    mti_AddRestartCB(mti_Free, ip);

    /* Process for: enum_out <= enum_a and enum_b */
    ip->enum_a = mti_FindPort(ports, "enum_a");
    ip->enum_b = mti_FindPort(ports, "enum_b");
    ip->enum_out = mti_CreateDriver(mti_FindPort(ports, "enum_out"));
    proc = mti_CreateProcess("p1", eval_enum, ip);
    mti_Sensitize(proc, ip->enum_a, MTI_EVENT);
    mti_Sensitize(proc, ip->enum_b, MTI_EVENT);

    /* Process for: int_out <= int_a + int_b */
    ip->int_a = mti_FindPort(ports, "int_a");
    ip->int_b = mti_FindPort(ports, "int_b");
    ip->int_out = mti_CreateDriver(mti_FindPort(ports, "int_out"));
    proc = mti_CreateProcess("p2", eval_int, ip);
    mti_Sensitize(proc, ip->int_a, MTI_EVENT);
    mti_Sensitize(proc, ip->int_b, MTI_EVENT);

    /* Process for: float_out <= float_a + float_b */
    ip->float_a = mti_FindPort(ports, "float_a");
    ip->float_b = mti_FindPort(ports, "float_b");
    ip->float_out = mti_CreateDriver(mti_FindPort(ports, "float_out"));
    proc = mti_CreateProcess("p3", eval_float, ip);
    mti_Sensitize(proc, ip->float_a, MTI_EVENT);
    mti_Sensitize(proc, ip->float_b, MTI_EVENT);

    /* Process for: array_out <= array_a and array_b */
    ip->array_a = mti_FindPort(ports, "array_a");
    ip->array_b = mti_FindPort(ports, "array_b");
    ip->array_out = mti_CreateDriver(mti_FindPort(ports, "array_out"));
    proc = mti_CreateProcess("p4", eval_array, ip);
    mti_Sensitize(proc, ip->array_a, MTI_EVENT);
    mti_Sensitize(proc, ip->array_b, MTI_EVENT);
}

static void eval_enum(void *param)
{
    boolean val_a, val_b, val_out;
    char **enum_literals;
    inst_rec * ip = param;

    /* Evalaute: enum_out <= enum_a and enum_b */
    val_a = mti_GetSignalValue(ip->enum_a);
    val_b = mti_GetSignalValue(ip->enum_b);
    if ( (val_a == BOOL_TRUE) && (val_b == BOOL_TRUE) ) {
        val_out = BOOL_TRUE;
    } else {
        val_out = BOOL_FALSE;
    }
    mti_ScheduleDriver(ip->enum_out, (long)val_out, 0, MTI_INERTIAL);

    /* Display the values */
    enum_literals = mti_GetEnumValues(mti_GetSignalType(ip->enum_a));
    sprintf(msgbuf, "enum_a = %s\n", enum_literals[val_a]);
    mti_PrintMessage(msgbuf);
    sprintf(msgbuf, "enum_b = %s\n", enum_literals[val_b]);
    mti_PrintMessage(msgbuf);
    sprintf(msgbuf, "enum_out = %s\n", enum_literals[val_out]);
    mti_PrintMessage(msgbuf);
}

static void eval_int(void *param)
{
    inst_rec * ip = param;
    long val_a, val_b, val_out;

    /* Evalaute: int_out <= int_a + int_b */
    val_a = mti_GetSignalValue(ip->int_a);
    val_b = mti_GetSignalValue(ip->int_b);
    val_out = val_a + val_b;
    mti_ScheduleDriver(ip->int_out, val_out, 0, MTI_INERTIAL);

    /* Display the values */
    sprintf(msgbuf, "int_a = %ld\n", val_a);
    mti_PrintMessage(msgbuf);
    sprintf(msgbuf, "int_b = %ld\n", val_b);
    mti_PrintMessage(msgbuf);
    sprintf(msgbuf, "int_out = %ld\n", val_out);
    mti_PrintMessage(msgbuf);
}

static void eval_float(void *param)
{
    double val_a, val_b, val_out;
    inst_rec * ip = param;

    /* Evaluate: float_out <= float_a + float_b */
    mti_GetSignalValueIndirect(ip->float_a, &val_a);
    mti_GetSignalValueIndirect(ip->float_b, &val_b);
    val_out = val_a + val_b;
    mti_ScheduleDriver(ip->float_out, (mtiLongT)(&val_out), 0, MTI_INERTIAL);

    /* Display the values */
    sprintf(msgbuf, "float_a = %g\n", val_a);
    mti_PrintMessage(msgbuf);
    sprintf(msgbuf, "float_b = %g\n", val_b);
    mti_PrintMessage(msgbuf);
    sprintf(msgbuf, "float_out = %g\n", val_out);
    mti_PrintMessage(msgbuf);
}

static void eval_array(void *param)
{
    typedef enum { BIT_0, BIT_1 } bit;
    char val_a[8], val_b[8], val_out[8];
    char **enum_literals;
    inst_rec * ip = param;
    int i;

    /* Evaluate: array_out <= array_a and array_b */
    mti_GetArraySignalValue(ip->array_a, val_a);
    mti_GetArraySignalValue(ip->array_b, val_b);
    for (i=0; i<8; i++) {
        if ( (val_a[i] == BIT_1) && (val_b[i] == BIT_1) ) {
            val_out[i] = BIT_1;
        } else {
            val_out[i] = BIT_0;
        }
    }
    mti_ScheduleDriver(ip->array_out, (mtiLongT) val_out, 0, MTI_INERTIAL);

    /* Display the values */
    enum_literals = mti_GetEnumValues(
                      mti_GetArrayElementType(mti_GetSignalType(ip->array_a)));
    for (i=7; i>=0; i--) {
        sprintf(msgbuf, "array_a(%d) = %s\n", i, enum_literals[(int)val_a[7-i]]);
        mti_PrintMessage(msgbuf);
        sprintf(msgbuf, "array_b(%d) = %s\n", i, enum_literals[(int)val_b[7-i]]);
        mti_PrintMessage(msgbuf);
        sprintf(msgbuf, "array_out(%d) = %s\n", i, enum_literals[(int)val_out[7-i]]);
        mti_PrintMessage(msgbuf);
    }
}
