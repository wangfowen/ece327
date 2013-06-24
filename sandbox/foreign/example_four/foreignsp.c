/*
 * Copyright 1991-2011 Mentor Graphics Corporation
 *
 * All Rights Reserved.
 *
 * THIS WORK CONTAINS TRADE SECRET AND PROPRIETARY INFORMATION WHICH IS THE PROPERTY OF 
 * MENTOR GRAPHICS CORPORATION OR ITS LICENSORS AND IS SUBJECT TO LICENSE TERMS.
 */

#include <mti.h>
#include <stdio.h>
#include <stdlib.h>

char * stdLogicLiterals[] =
{ "'U'", "'X'", "'O'", "'1'", "'Z'", "'W'", "'L'", "'H'", "'-'" };

typedef enum {
    STD_LOGIC_U,
    STD_LOGIC_X,
    STD_LOGIC_0,
    STD_LOGIC_1,
    STD_LOGIC_Z,
    STD_LOGIC_W,
    STD_LOGIC_L,
    STD_LOGIC_H,
    STD_LOGIC_D
} stdLogicEnumT;

/* Convert a VHDL String array into a NULL terminated string.
 * The caller is responsible for freeing the returned string.
 */
static char *get_string( mtiVariableIdT id )
{
    char *      buf;
    int         len;
    mtiTypeIdT  type;

    type = mti_GetVarType(id);
    len  = mti_TickLength(type);
    buf  = malloc( sizeof(char) * (len+1) );
    mti_GetArrayVarValue(id, buf);
    buf[len] = 0;
    return buf;
}

/* Print the value of the specified variable.  Called recursively
 * for composites.
 */
static void PrintVarValue( mtiVariableIdT varid, int indent )
{
    int              i;
    mtiVariableIdT * elem_list;
    mtiTypeIdT       vartype;

    vartype = mti_GetVarType( varid );
    switch ( mti_GetTypeKind( vartype ) ) {
      case MTI_TYPE_ENUM:
        {
            char ** enum_values;
            mtiInt32T scalar_val;
            enum_values = mti_GetEnumValues( vartype );
            scalar_val = mti_GetVarValue( varid );
            mti_PrintFormatted( "%*c%s\n", indent, ' ',
                               enum_values[scalar_val] );
        }
        break;
      case MTI_TYPE_PHYSICAL:
      case MTI_TYPE_SCALAR:
        {
            mtiInt32T scalar_val;
            scalar_val = mti_GetVarValue( varid );
            mti_PrintFormatted( "%*c%d\n", indent, ' ', scalar_val );
        }
        break;
      case MTI_TYPE_ARRAY:
        mti_PrintFormatted( "%*cArray =\n", indent, ' ' );
        elem_list = mti_GetVarSubelements( varid, 0 );
        for ( i = 0; i < mti_TickLength( vartype ); i++ ) {
            PrintVarValue( elem_list[i], indent + 2 );
        }
        mti_VsimFree( elem_list );
        break;
      case MTI_TYPE_RECORD:
        mti_PrintFormatted( "%*cRecord =\n", indent, ' ' );
        elem_list = mti_GetVarSubelements( varid, 0 );
        for ( i = 0; i < mti_TickLength( vartype ); i++ ) {
            PrintVarValue( elem_list[i], indent + 2 );
        }
        mti_VsimFree( elem_list );
        break;
      case MTI_TYPE_REAL:
        {
            double real_val;
            mti_GetVarValueIndirect( varid, &real_val );
            mti_PrintFormatted( "%*c%g\n", indent, ' ', real_val );
        }
        break;
      case MTI_TYPE_TIME:
        {
            mtiTime64T time_val;
            mti_GetVarValueIndirect( varid, &time_val );
            mti_PrintFormatted( "%*c[%d,%d]\n", indent, ' ',
                               MTI_TIME64_HI32(time_val),
                               MTI_TIME64_LO32(time_val) );
        }
        break;
      default:
        mti_PrintFormatted( "%*cUnknown type\n", indent);
        break;
    }
}

/* Update the value of the specified variable. */
static void SetValue( mtiVariableIdT varid )
{
    mtiTypeIdT vartype = mti_GetVarType( varid );

    switch ( mti_GetTypeKind( vartype ) ) {
      case MTI_TYPE_ENUM:
        {
            mtiInt32T scalar_val;
            scalar_val = mti_GetVarValue( varid );
            scalar_val++;
            if (( scalar_val < mti_TickLow( vartype )) ||
                ( scalar_val > mti_TickHigh( vartype ))) {
                scalar_val = mti_TickLeft( vartype );
            }
            mti_SetVarValue( varid, (long)scalar_val );
        }
        break;
      case MTI_TYPE_PHYSICAL:
      case MTI_TYPE_SCALAR:
        {
            mtiInt32T scalar_val;
            scalar_val = mti_GetVarValue( varid );
            scalar_val++;
            mti_SetVarValue( varid, (long)scalar_val );
        }
        break;
      case MTI_TYPE_ARRAY:
      case MTI_TYPE_RECORD:
        {
            int              i;
            mtiVariableIdT * elem_list;
            elem_list = mti_GetVarSubelements( varid, 0 );
            for ( i = 0; i < mti_TickLength( vartype ); i++ ) {
                SetValue( elem_list[i] );
            }
            mti_VsimFree( elem_list );
        }
        break;
      case MTI_TYPE_REAL:
        {
            double real_val;
            mti_GetVarValueIndirect( varid, &real_val );
            real_val += 1.1;
            mti_SetVarValue( varid, (mtiLongT)(&real_val) );
        }
        break;
      case MTI_TYPE_TIME:
        {
            mtiTime64T time_val;
            mti_GetVarValueIndirect( varid, &time_val );
            MTI_TIME64_ASGN( time_val, MTI_TIME64_HI32(time_val),
                            MTI_TIME64_LO32(time_val) + 1 );
            mti_SetVarValue( varid, (mtiLongT)(&time_val) );
        }
        break;
      default:
        break;
    }
}

/* ********** C code for VHDL in_params procedure. ********** */
void in_params (
  int             vhdl_integer,     /* IN integer        */
  int             vhdl_enum,        /* IN std_logic      */
  double         *vhdl_real,        /* IN real           */
  mtiVariableIdT  vhdl_array,       /* IN string         */
  mtiVariableIdT  vhdl_rec,         /* IN record         */
  mtiVariableIdT *vhdl_ptr          /* IN access to std_logic_vector */
)
{
    char * string_val;

    mti_PrintFormatted( " Integer = %d\n", vhdl_integer );
    mti_PrintFormatted( " Enum    = %s\n", stdLogicLiterals[vhdl_enum] );
    mti_PrintFormatted( " Real    = %g\n", *vhdl_real );
    string_val = get_string(vhdl_array);
    mti_PrintFormatted( " String  = %s\n", string_val );
    free( string_val );
    PrintVarValue( vhdl_array, 1 );
    PrintVarValue( vhdl_rec, 1 );
    PrintVarValue( *vhdl_ptr, 1);
}

/* ********** C code for VHDL out_params procedure. ********** */
void out_params (
  int            *vhdl_integer,     /* OUT integer        */
  char           *vhdl_enum,        /* OUT std_logic      */
  double         *vhdl_real,        /* OUT real           */
  mtiVariableIdT  vhdl_array,       /* OUT string         */
  mtiVariableIdT  vhdl_rec,         /* OUT record         */
  mtiVariableIdT *vhdl_ptr          /* OUT access to std_logic_vector */
)
{
    char *val;
    int   i, len, first;

    *vhdl_integer += 1;

    *vhdl_enum += 1;
    if (*vhdl_enum > STD_LOGIC_D) {
        *vhdl_enum = STD_LOGIC_U;
    }

    *vhdl_real += 1.01;

    /* Rotate the array. */
    val = mti_GetArrayVarValue( vhdl_array, NULL );
    len = mti_TickLength( mti_GetVarType( vhdl_array ) );
    first = val[0];
    for (i = 0; i < len - 1; i++) {
        val[i] = val[i+1];
    }
    val[len - 1] = first;

    SetValue( vhdl_rec );
    SetValue( *vhdl_ptr );
}

/* ********** C code for VHDL incr_integer function. ********** */
int incrInteger(
  int  ivar       /* IN integer */
)
{
    int value = ivar;

    value++;

    return value;
}

/* ********** C code for VHDL incr_real function. ********** */
mtiRealT incrReal(
  double * rvar       /* IN real */
)
{
    mtiRealT value;

    MTI_ASSIGN_TO_REAL(value,(*rvar + 1.3));

    return value;
}

/* ********** C code for VHDL incr_time function. ********** */
mtiTime64T incrTime(
  mtiTime64T * tvar       /* IN time */
)
{
    mtiTime64T value;

    MTI_TIME64_ASGN(value,
                    MTI_TIME64_HI32(*tvar),
                    MTI_TIME64_LO32(*tvar) + 2);

    return value;
}
