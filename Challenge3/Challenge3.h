#ifndef CHALLENGE3_H
#define CHALLENGE3_H

#define AM_COUNTER_MSG_TYPE 2

typedef nx_struct am_radio_count_msg_t 
{
	nx_uint16_t counter; 	// counter value
	nx_uint16_t senderId;	// From whom it has been sent
} am_radio_count_msg_t;

#endif
