/*
 * Copyright 1991-2011 Mentor Graphics Corporation
 *
 * All Rights Reserved.
 *
 * THIS WORK CONTAINS TRADE SECRET AND PROPRIETARY INFORMATION WHICH IS THE PROPERTY OF 
 * MENTOR GRAPHICS CORPORATION OR ITS LICENSORS AND IS SUBJECT TO LICENSE TERMS.
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "mti.h"

#define STRING2INT(str, int) sscanf(str, "%d", &int);

#define MAX_INPUT_LINE_SIZE 256
#define MAX_PORT_WIDTH       64
#define MAX_NUM_PORTS        64
#define DRIVE                 0
#define TEST                  1

/* This is the structure that contains the tester's port data. */
typedef struct {
    char *name;
    int   is_array_type;    /* true for arrays, false otherwise */
    int   number;           /* unique number for each port */
    int   width;
} portstruct;

/* The test data is stored in a linked list whose nodes are
 * described below. The list is terminated with a NULL.
 */
typedef struct tp {
    struct tp *nxt;
    char      *test_val;    /* either the value to drive out or the value
                               to test for at the given time. */
    int        portnum;
    int        type;        /* either DRIVE or TEST */
} testpoint;

typedef struct {
    mtiSignalIdT  ports[MAX_NUM_PORTS];
    mtiDriverIdT  drivers[MAX_NUM_PORTS];
    mtiProcessIdT test_values;
    FILE         *vectorfile_id;
    int           verbose;
} inst_rec, *inst_rec_ptr;

static portstruct tester_ports[MAX_NUM_PORTS];
static testpoint *testpoints = NULL;
static int        num_ports = 0;

/* This function frees all nodes in the list of testpoints. */
static void delete_testpoints( void )
{
    testpoint *tp, *p;

    tp = testpoints;
    while(tp != NULL) {
        p = tp->nxt;
        mti_Free(tp);
        tp = p;
    }
    testpoints = NULL;
}

/* This function scans the list of ports for a match and
 * returns the unique id number for that port.
 */
static int findportnum( char *portname )
{
    int i;
    for ( i = 0; i < num_ports; i++ ) {
        if ( strcmp(portname, tester_ports[i].name) == 0 ) {
            return tester_ports[i].number;
        }
    }
    return -1;
}

/*
 * The following set of routines is used for converting STD_LOGICs
 * and STD_LOGIC_VECTORs from their internal representations
 * (ordinal positions in the enerated type for std_logic)
 * to the character values (X, 0, 1, ...) and vice-versa.
 */

static int mvl9_char[] = { 'U', 'X', '0', '1', 'Z', 'W', 'L', 'H', '-' };

static char convert_enum_to_mvl9_char( int enum_bit )
{
    if ( enum_bit > 8 ) {
        return '?';
    }
    else {
        return mvl9_char[enum_bit];
    }
}

static void convert_enums_to_mvl9_string(
  char *enums,
  char *string,
  int   len
)
{
    int i;
    for ( i = 0; i < len; i++ ) {
        string[i] = convert_enum_to_mvl9_char( (int)enums[i] );
    }
    string[len] = '\0';
}

static void convert_mvl9_string_to_enums(
    char *string,
    char *enums,
    int   len
)
{
    int i;
    for ( i = 0; i < len; i++ ) {
        switch(string[i]) {
          case 'U':
            enums[i] = 0;
            break;
          case 'X':
            enums[i] = 1;
            break;
          case '0':
            enums[i] = 2;
            break;
          case '1':
            enums[i] = 3;
            break;
          case 'Z':
            enums[i] = 4;
            break;
          case 'W':
            enums[i] = 5;
            break;
          case 'L':
            enums[i] = 6;
            break;
          case 'H':
            enums[i] = 7;
            break;
          case '-':
            enums[i] = 8;
            break;
          default:
            mti_PrintMessage( "ERROR: a non-MVL9 character was found in "
                              "a signal value specification.\n" );
            break;
        }
    }
}

static int is_drive_or_test_statement( char *keyword )
{
    if ((strcmp(keyword, "drive") == 0) || (strcmp(keyword, "test") == 0)) {
        return 1;
    }
    return 0;
}

static int is_drive_statement( char *keyword )
{
    if ( strcmp(keyword, "drive") == 0 ) {
        return 1;
    }
    return 0;
}

static void schedule_testpoint(
    inst_rec_ptr ip,
    int          portnum,
    char        *values,
    int          time,
    int          type
)
{
    static testpoint *last_testpoint;

    int        now;
    testpoint *this_testpoint;

    /* Create a new testpoint. */
    this_testpoint = (testpoint *) mti_Malloc(sizeof(testpoint));
    this_testpoint->type     = type;
    this_testpoint->portnum  = portnum;
	this_testpoint->test_val = (char*)mti_Malloc(strlen(values)+1);
	strcpy(this_testpoint->test_val, values);

    /* Link in the new testpoint on the end of the list. */
    if ( ! testpoints ) {
        testpoints = this_testpoint;
    } else {
        last_testpoint->nxt = this_testpoint;
    }
    this_testpoint->nxt = NULL;
    last_testpoint      = this_testpoint;

    /* Schedule a wakeup at this time to check the value then. */
    now = mti_Now();
    mti_ScheduleWakeup( ip->test_values, abs(time-now) );
}

/* This function reads the next statement in the vectors file and
 * schedules a wakeup in the future to process the data.
 */
static void read_next_statement( inst_rec_ptr ip )
{
    char  buf[100];
    char  line[MAX_INPUT_LINE_SIZE];
    char *kw, *timestamp, *signame, *sigval;
    char  values[MAX_PORT_WIDTH];
    int   done = 0;
    int   time, test_type, portnum;

    while ( ! done ) {
        if ( fgets(line, MAX_INPUT_LINE_SIZE, ip->vectorfile_id) != NULL ) {
            kw = strtok(line, " \t\r\n");
            if ( kw && is_drive_or_test_statement(kw) ) {
                timestamp = strtok(NULL, " \t\r\n");
                STRING2INT(timestamp, time);
                while ( (signame = strtok(NULL, " =\t\r\n")) != NULL ) {
                    sigval  = strtok(NULL, " \t\r\n");
                    portnum = findportnum(signame);
                    if ( portnum >= 0 ) {
                        convert_mvl9_string_to_enums( sigval, values,
                                                   tester_ports[portnum].width);
                        test_type = is_drive_statement(kw) ? DRIVE : TEST;
                        schedule_testpoint( ip, portnum, values, time,
                                           test_type );
                    } else {
                        sprintf(buf, "Can't find port named \"%s\".\n",
                                signame);
                        mti_PrintMessage(buf);
                    }
                }
                done = 1;
            }
        } else {
            done = 1; /* found end of file */
        }
    }
}

/*
 * This procedure is called by the simulator as a result of an
 * mti_ScheduleWakeup() call. Its purpose is to process all drive/test
 * data specified for the current timestep. It schedules drivers for
 * drive points by calling mti_ScheduleDriver(). For test points, it
 * reads the port values by calling either mti_GetSignalValue() or
 * mti_GetArraySignalValue(). It then compares the current values with the
 * expected values and prints an error message if they don't match.
 */
static void test_value_proc( void * param )
{
    inst_rec_ptr ip = (inst_rec_ptr)param;
    char       actual_val[MAX_PORT_WIDTH];
    char       buf[100];
    char       expected_val[MAX_PORT_WIDTH];
    char      *sig_array_val;
    int        portnum, i, width, is_array;
    long       now;
    long       sigval;
    testpoint *cur_testpoint;

    now = mti_Now();
    for ( cur_testpoint=testpoints; cur_testpoint;
          cur_testpoint=cur_testpoint->nxt) {
        portnum  = cur_testpoint->portnum;
        width    = tester_ports[portnum].width;
        is_array = tester_ports[portnum].is_array_type;
        if ( cur_testpoint->type == DRIVE ) {
            if ( ! is_array ) {
                if ( ip->verbose ) {
                    sprintf(buf,"TIME %ld: drive signal %s with value %c\n",
                           now, tester_ports[portnum].name,
                           convert_enum_to_mvl9_char(*cur_testpoint->test_val));
                    mti_PrintMessage(buf);
                }
                mti_ScheduleDriver( ip->drivers[portnum],
                                   (mtiLongT) *cur_testpoint->test_val,
                                   0, MTI_INERTIAL );
            } else {
                char tmpstring[MAX_PORT_WIDTH];
                convert_enums_to_mvl9_string( cur_testpoint->test_val,
                                             tmpstring, width );
                if ( ip->verbose ) {
                    sprintf(buf,"TIME %ld: drive signal array %s with value %s\n",
                           now, tester_ports[portnum].name, tmpstring);
                    mti_PrintMessage(buf);
                }
                mti_ScheduleDriver( ip->drivers[portnum],
                                   (mtiLongT)(cur_testpoint->test_val),
                                    0, MTI_INERTIAL );
            }
        } else {
            if ( ! is_array ) {
                char exp, act;
                sigval = mti_GetSignalValue(ip->ports[portnum]);
                exp    = convert_enum_to_mvl9_char(*cur_testpoint->test_val);
                act    = convert_enum_to_mvl9_char(sigval);
                if ( ip->verbose ) {
                    sprintf(buf,"TIME %ld: test signal %s for value %c\n",
                           now, tester_ports[portnum].name, exp);
                    mti_PrintMessage(buf);
                }
                if ( sigval != (long) *cur_testpoint->test_val ) {
                    sprintf( buf,
                            "Miscompare at time %ld, signal %s. "
                            "Expected \'%c\', Actual \'%c\'\n",
                            now, tester_ports[portnum].name, exp, act);
                    mti_PrintMessage(buf);
                }
            } else {
                sig_array_val = mti_GetArraySignalValue(ip->ports[portnum],
                                                        NULL);
                convert_enums_to_mvl9_string(cur_testpoint->test_val,
                                             expected_val, width);
                convert_enums_to_mvl9_string(sig_array_val, actual_val, width);
                if ( ip->verbose ) {
                    sprintf(buf,"TIME %ld: test signal %s for value %s\n",
                           now, tester_ports[portnum].name, expected_val);
                    mti_PrintMessage(buf);
                }
                for ( i = 0; i < width; i++ ) {
                    if ( sig_array_val[i] != cur_testpoint->test_val[i] ) {
                        sprintf( buf,
                                "Miscompare at time %ld, signal %s. "
                                "Expected \"%s\", Actual \"%s\"\n",
                                now, tester_ports[portnum].name,
                                expected_val, actual_val);
                        mti_PrintMessage( buf );
                        break;
                    }
                }
            }
        }
    }
    delete_testpoints();
    read_next_statement(ip);
}

static int open_vector_file( inst_rec_ptr ip )
{
    char               buf[100];
    if ( (ip->vectorfile_id = fopen("vectors", "r")) ) {
        return 1;
    } else {
        mti_PrintMessage("Can't open the file \"vectors\"\n");
        if ( ip->verbose ) {
            sprintf(buf,"Can't open the file \"vectors\"\n");
            mti_PrintMessage(buf);
        }
        return 0;
    }
}

/* This function is called by the simulator to initialize the
 * tester module. It makes a data structure of the tester's ports
 * (taken from the entity's port list) and creates a process which
 * will handle all the signal changes.
 */
void tester_init(
    mtiRegionIdT       region,
    char              *param,
    mtiInterfaceListT *generics,
    mtiInterfaceListT *ports
)
{
    inst_rec_ptr       ip;
    mtiInterfaceListT *p;
    int                is_array_type;
 
    ip = (inst_rec_ptr)mti_Malloc(sizeof(inst_rec));
    mti_AddRestartCB( mti_Free, ip );

    /* Traverse the list of ports and get port names and widths. */
    num_ports = 0;
    for ( p = ports; p; p = p->nxt ) {
        tester_ports[num_ports].name = p->name;
        is_array_type = (mti_GetTypeKind(p->type) == MTI_TYPE_ARRAY);
        tester_ports[num_ports].is_array_type = is_array_type;
        if ( is_array_type ) {
            tester_ports[num_ports].width = mti_TickLength(p->type);
        } else {
            tester_ports[num_ports].width = 1;
        }
        ip->ports[   num_ports] = p->u.port;
        ip->drivers[ num_ports] = mti_CreateDriver(p->u.port);
        tester_ports[num_ports].number = num_ports;
        num_ports++;
    }
    ip->test_values = mti_CreateProcess("test", test_value_proc, ip);

    /* Check for an optional parameter on the FOREIGN attribute that
     * indicates whether or not to display debug messages.
     */

    if ( param && (strcmp(param, "verbose") == 0) ) {
        ip->verbose = 1;
    } else {
        ip->verbose = 0;
    }

    /* Open the vector file and process the first test/drive statement. */

    if ( open_vector_file(ip) ) {
        read_next_statement(ip);
    }
}
