#ifndef DISTANCEKEEPER_H
#define DISTANCEKEEPER_H

#define MAX_MOTE_NUM 			5 
#define PROBE_PERIOD_MS 		500
#define CONSECUTIVE_TIMEOUT_MS	PROBE_PERIOD_MS + 100

//payload of the msg
typedef nx_struct probe_msg_t 
{
	nx_uint8_t senderId;
} probe_msg_t;


enum
{
	AM_PROBE_MSG = 6,
};

#endif
