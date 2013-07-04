/*
 * Copyright 1991-2011 Mentor Graphics Corporation
 *
 * All Rights Reserved.
 *
 * THIS WORK CONTAINS TRADE SECRET AND PROPRIETARY INFORMATION WHICH IS THE PROPERTY OF 
 * MENTOR GRAPHICS CORPORATION OR ITS LICENSORS AND IS SUBJECT TO LICENSE TERMS.
 *
 * Prints the signal hierarchy to the transcript.
 *
 * The entry point is dump_design_init().
 */

#include <stdio.h>
#include "mti.h"

static void dump_type( mtiTypeIdT type )
{
    char **enum_vals;
    long   left, right;
    long   i;
    int    kind;

    kind = mti_GetTypeKind(type);
    switch ( kind ) {
      case MTI_TYPE_ARRAY:
        left  = mti_TickLeft(type);
        right = mti_TickRight(type);
        mti_PrintFormatted( "Array(%ld to %ld) of ", left, right );
        dump_type( mti_GetArrayElementType( type ) );
        break;
      case MTI_TYPE_ENUM:
        mti_PrintFormatted( "(" );
        enum_vals = mti_GetEnumValues( type );
        right = mti_TickRight( type );
        for ( i = 0; i <= right; i++ ) {
            mti_PrintFormatted( enum_vals[i] );
            if ( i != right ) {
                mti_PrintFormatted( ", " );
            }
        }
        mti_PrintFormatted( ")" );
        break;
      case MTI_TYPE_SCALAR:
      case MTI_TYPE_INTEGER:
        mti_PrintFormatted( "Integer" );
        break;
      case MTI_TYPE_REAL:
        mti_PrintFormatted( "Real" );
        break;
      case MTI_TYPE_TIME:
        mti_PrintFormatted( "Time" );
        break;
      default:
        mti_PrintFormatted( "Unknown type: %d", kind );
        break;
    }
}

static void dump_signal( mtiSignalIdT sig, int margin )
{
    mti_PrintFormatted( "%*sSignal %s : ", margin, " ",
                       mti_GetSignalName( sig ) );
    switch ( mti_GetSignalMode( sig ) ) {
      case MTI_INTERNAL:
        break;
      case MTI_DIR_IN:
        mti_PrintFormatted( "IN " );
        break;
      case MTI_DIR_OUT:
        mti_PrintFormatted( "OUT " );
        break;
      case MTI_DIR_INOUT:
        mti_PrintFormatted( "INOUT " );
        break;
      default:
        mti_PrintFormatted( "?MODE? " );
        break;
    }
    dump_type( mti_GetSignalType( sig ) );
    mti_PrintFormatted( "\n" );
}

static void dump_region( mtiRegionIdT region, int margin )
{
    mtiSignalIdT sig;

    if ( region ) {
        mti_PrintFormatted( "%*sRegion: %s\n", margin, " ",
                           mti_GetRegionName( region ) );
        margin += 2;

        /* Print the signals in this region */
        for ( sig = mti_FirstSignal( region ); sig; sig = mti_NextSignal() ) {
            dump_signal( sig, margin );
        }

        /* Do the lower level regions */
        for ( region = mti_FirstLowerRegion( region ); region;
             region = mti_NextRegion( region ) ) {
            dump_region( region, margin );
        }
    }
}

static void dump_design( void * param )
{
    dump_region( mti_GetTopRegion(), 1 );
}

/* Initialization Function */
void dump_design_init(
  mtiRegionIdT       region,
  mtiInterfaceListT *generics,
  mtiInterfaceListT *ports,
  char              *param
)
{
    mti_AddLoadDoneCB( dump_design, NULL );
}
