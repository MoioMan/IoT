#ifndef DISTANCEKEEPER_H
#define DISTANCEKEEPER_H

#define SERIAL_DEBUG

#define MAX_MOTE_NUM 				6 			// Mote number in the environment
#define PROBE_PERIOD_MS 			500			// Probe sending period
#define PROBE_TIMEOUT_PERIOD_MS		500 + 350	// If no probe from X has been received within this period, X is considered not near  
#define MIN_PROBE_COUNT_ALARM   	10			// Number of probe received before considering a mote near

//payload of the msg
typedef nx_struct probe_msg
{
	nx_uint8_t senderId;
	nx_uint8_t incrementalId;
} probe_msg_t;


enum
{
	AM_PROBE_MSG = 6
};

#endif
