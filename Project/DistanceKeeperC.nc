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
  	uint8_t probeCounters[MAX_MOTE_NUM] = 0;
  	message_t packet;

  	void sendProbe();
  
  	//***************** Send probe function ********************//
	void sendProbe() 
	{
		//Prepare the msg
		probe_msg_t* msg = (probe_msg_t*)call Packet.getPayload(&packet, sizeof(probe_msg_t));
		msg->senderId = TOS_NODE_ID;
	

		//Send the probe in BROADCAST
		if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(probe_msg_t)) == SUCCESS)
			locked = TRUE;
	}        


	//***************** Boot interface ********************//
	event void Boot.booted() 
	{
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
		printf("Mote %d was shut down at %s\n", TOS_NODE_ID, sim_time_string());
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
			locked = FALSE;
	}

	//***************************** Receive interface *****************//
	event message_t* Receive.receive(message_t* buf, void* payload, uint8_t len) 
	{
		if (len == sizeof(probe_msg_t)) 
		{
			my_msg_t* msg = (probe_msg_t*)payload;

			if (msg->senderId >= MAX_MOTE_NUM)
			{				
				printf("Unexpected sender mote!\n");
				return buf;
			}
			else
			{
				printf("Probe received from %d\n", msg->senderId);
				probeCounters[msg->senderId]++;
				// TODO: Check continuity of the msg
				
				
				printf("From %d) count = %d\n", msg->senderId, probeCounters[msg->senderId]);
			}
		}
		else 
			printf("Recieved an unknown msg!\n");

		printfflush();
		return buf;
	}
}

