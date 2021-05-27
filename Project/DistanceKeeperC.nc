#include "printf.h"
#include "DistanceKeeper.h"
#include "Timer.h"
#include "string.h"

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
	interface Timer<TMilli> as SenderTimer;
	interface Timer<TMilli> as CheckTimer;
  }
} 
implementation 
{
	bool locked = FALSE;
	
  	uint32_t probeCounters[MAX_MOTE_NUM];		// For each mote id, store the counter of continuous probes received
  	uint32_t lastProbeCounters[MAX_MOTE_NUM];	// For each mote id, store a snapshot of the previous counters, to know if an external mote is still near
  	uint8_t lastIncrementalIds[MAX_MOTE_NUM];	// For each mote id, store the sequence number of the last probe received 
  	
  	uint8_t currentMsgId;						// Current sequence number of this mote  	
  	char lastMsg [2 * MAX_MOTE_NUM + 1];		// String representation of the nodes near this mote related to the last alarm sent  	
  	message_t packet;
	
	
#ifndef SERIAL_DEBUG
#define printf emptyPrintf
#endif	
	void emptyPrintf(char* buff, ...) { }	// Disable printf if not debugging


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

	void sendAlert()
	{				
		uint16_t i, j;		
		char msgBuff[2 * MAX_MOTE_NUM + 1];
		// Build alarm in such a way: {this id},{near mote ids},...
		msgBuff[0] = TOS_NODE_ID + '0';
		msgBuff[1] = ',';
		j = 2;
		for (i = 0; i < MAX_MOTE_NUM; i++)
		{
			if (probeCounters[i] >= MIN_PROBE_COUNT_ALARM && (i + 1) != TOS_NODE_ID)
			{
				msgBuff[j] = (i + 1) + '0';
				msgBuff[j + 1] = ',';
				j += 2;
			}
		}
		msgBuff[j - 1] = 0x00;	// remove last comma
			
		// Avoid sending the same alert (same near motes = same message)
		// Send it only when it changes
		if (strncmp(msgBuff, lastMsg, 2 * MAX_MOTE_NUM + 1) != 0)
		{		
			strncpy(lastMsg, msgBuff, 2 * MAX_MOTE_NUM + 1);	// Store the actual cluster	
		
// Enable only this printf
#undef printf 
			printf("%s\n", msgBuff);	// ex: 1,2,5		
#ifndef SERIAL_DEBUG
#define printf emptyPrintf
#endif				
		}
	}

	//***************** Boot interface ********************//
	event void Boot.booted() 
	{
		uint16_t i;
		for (i = 0; i < MAX_MOTE_NUM; i++)
		{
			probeCounters[i] = 0;
			lastProbeCounters[i] = 0;
		}		
		currentMsgId = 0;	
	
		call SplitControl.start();
	}

	//***************** SplitControl interface ********************//
	event void SplitControl.startDone(error_t err)
	{
		if (err == SUCCESS) 
		{    
			call SenderTimer.startPeriodic(PROBE_PERIOD_MS);
			call CheckTimer.startPeriodic(PROBE_TIMEOUT_PERIOD_MS);
		}
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
	//***************** MilliTimer interfaces ********************//
	event void SenderTimer.fired() 
	{
		if (!locked)
			sendProbe();
	}
	
    event void CheckTimer.fired() 
	{
		int i;
		// Check if there is a mote from which I did not receive a new probe (= same counters)
		for (i = 0; i < MAX_MOTE_NUM; i++)
		{
			if (probeCounters[i] != 0 && lastProbeCounters[i] == probeCounters[i] && i + 1 != TOS_NODE_ID)
			{
				probeCounters[i] = 0; // No more near -> Reset
				printf("Node %d is no more near\n", i + 1);	
			}
		
			// Update last state
			lastProbeCounters[i] = probeCounters[i];
		}
		printfflush();
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
			
			uint8_t senderId = msg->senderId;
			uint8_t senderIndex = senderId - 1;
			if (senderId > MAX_MOTE_NUM)
			{				
				printf("Unexpected sender mote!\n");
				return buf;
			}
			else
			{
				if (lastIncrementalIds[senderIndex] + 1 != msg->incrementalId) // Overflow is correctly handled (255 + 1 == 0) 
				{
					// Found a discontinuity
					probeCounters[senderIndex] = 0;	
					printf("Node %d is approaching\n", senderId);		
				}							
				
				// Update current state
				lastIncrementalIds[senderIndex] = msg->incrementalId;
				probeCounters[senderIndex]++;
				//printf("From %d) continuos probes=%d\n", senderId, probeCounters[senderIndex]);
				
				if (probeCounters[senderIndex] >= MIN_PROBE_COUNT_ALARM) // 10
				{
					sendAlert();
				}				
			}
		}
		else 
			printf("Received an unknown msg!\n");

		printfflush();
		return buf;
	}
}

