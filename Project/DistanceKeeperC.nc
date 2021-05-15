#include "printf.h"	
#include "DistanceKeeper.h"
#include "Timer.h"

module DistanceKeeperC 
{
  uses 
  {
	interface Boot; 
	
    //interfaces for communication
	interface Packet;
	interface AMSend;
	interface SplitControl;
  	interface Receive;

	//interface for timer
	interface Timer<TMilli> as Timer;		
  }
} 
implementation 
{
	bool locked = FALSE;
  	uint32_t probeCounters[MAX_MOTE_NUM];
  	uint8_t lastIncrementalIds[MAX_MOTE_NUM];
  	uint8_t currentMsgId;
  	
  	message_t packet;

  	void sendProbe();
  
  	//***************** Send probe function ********************//
	void sendProbe() 
	{
		//Prepare the msg
		probe_msg_t* msg = (probe_msg_t*)call Packet.getPayload(&packet, sizeof(probe_msg_t));
		msg->senderId = TOS_NODE_ID;
		msg->incrementalId = currentMsgId;

		//Send the probe in BROADCAST
		if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(probe_msg_t)) == SUCCESS)
			locked = TRUE;
	}        


	//***************** Boot interface ********************//
	event void Boot.booted() 
	{
		uint16_t i;
		for (i = 0; i < MAX_MOTE_NUM; i++)
			probeCounters[i] = 0;
		
		currentMsgId = 0;
		
	
		call SplitControl.start();
	}

	//***************** SplitControl interface ********************//
	event void SplitControl.startDone(error_t err)
	{
		if (err == SUCCESS)     
			call Timer.startPeriodic(PROBE_PERIOD_MS);
		else
		{
			printf("Radio offline!\n");
			printfflush();
		}
	}
  
	event void SplitControl.stopDone(error_t err)
	{
		printf("Mote %d was shut down\n", TOS_NODE_ID);
		printfflush();
	}

	//***************** MilliTimer interface ********************//
	event void Timer.fired() 
	{
		if (!locked)
			sendProbe();
	}
  

	//********************* AMSend interface ****************//
	event void AMSend.sendDone(message_t* buf, error_t err) 
	{
		if (&packet == buf)
		{
			currentMsgId++;
			locked = FALSE;
		}
	}

	//***************************** Receive interface *****************//
	event message_t* Receive.receive(message_t* buf, void* payload, uint8_t len) 
	{
		if (len == sizeof(probe_msg_t)) 
		{
			probe_msg_t* msg = (probe_msg_t*)payload;
			if (msg->senderId >= MAX_MOTE_NUM)
			{				
				printf("Unexpected sender mote!\n");
				return buf;
			}
			else
			{
				if (lastIncrementalIds[msg->senderId] + 1 < msg->incrementalId) // Overflow is correctly handled (255 + 1 == 0) 
				{
					// Found a discontinuity
					probeCounters[msg->senderId] = 0;	
					printf("I skipped a msg! Reset\n");		
				}							
				
				// Update current state
				lastIncrementalIds[msg->senderId] = msg->incrementalId;
				probeCounters[msg->senderId]++;
				printf("From %d) continuos probes=%d\n", msg->senderId, probeCounters[msg->senderId]);
				
				if (probeCounters[msg->senderId] >= MIN_PROBE_COUNT_ALARM) // 10
				{
					
				}				
			}
		}
		else 
			printf("Received an unknown msg!\n");

		printfflush();
		return buf;
	}
}

