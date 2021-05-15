#ifndef DISTANCEKEEPER_H
#define DISTANCEKEEPER_H

#define MAX_MOTE_NUM 			5 
#define PROBE_PERIOD_MS 		500
#define MIN_PROBE_COUNT_ALARM   10

//payload of the msg
typedef nx_struct probe_msg_t 
{
	nx_uint8_t senderId;
	nx_uint8_t incrementalId;
} probe_msg_t;


enum
{
	AM_PROBE_MSG = 6,
};

#endif
