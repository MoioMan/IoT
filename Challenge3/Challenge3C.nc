#include "printf.h"	
#include "Challenge3.h"

module Challenge3C 
{
  uses interface Boot;
  
  uses interface Timer<TMilli> as Timer;  
  uses interface Leds;
  
  uses interface Packet; 
	uses interface AMSend;
	uses interface Receive; 
	uses interface SplitControl as AMControl;
}

implementation 
{
	message_t packet;
	bool locked;
	uint16_t counter;
  
  // 1. At boot, start the AM Controller
  event void Boot.booted() 
  { 
		counter = 0;
		call AMControl.start(); 
	} 
	
	// 2. When the controller is started, start the timer
	event void AMControl.startDone(error_t err) 
	{ 
		uint16_t period_ms = 1000;
		switch (TOS_NODE_ID)
		{
			case 1:
			{
				period_ms = 1000;	// 1 Hz
				break;
			}
			case 2:
			{
				period_ms = 333;	// 3 Hz
				break;
			}
			case 3:
			{
				period_ms = 200;	// 5 Hz
				break;
			}
		}
		
		
		if (err == SUCCESS)  
			call Timer.startPeriodic(period_ms);
		else
			call AMControl.start(); 
	} 
	event void AMControl.stopDone(error_t err) { }

  // ...When the timer fires, send a message in broadcast
  event void Timer.fired() 
  {  	
  	if (!locked) 
  	{
  	  // get the reference to the payload of the packet
			am_radio_count_msg_t* payload = (am_radio_count_msg_t*)call Packet.getPayload(&packet, sizeof(am_radio_count_msg_t));
			payload->counter = counter; 
			payload->senderId = TOS_NODE_ID;
			
			// Send the message with the defined payload and the specified type
			if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(am_radio_count_msg_t)) == SUCCESS) 
			{
  			printf("Msg sent");
				locked = TRUE; 
			}
		}
		
		counter++;
  	printfflush();
  }
  event void AMSend.sendDone(message_t* msg, error_t error)
	{
		// Unlock if correctly sent
		if (&packet == msg) 
			locked = FALSE; 
	}
	
	
	// Receiving Inteface
	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len)
	{
		if (len == sizeof(am_radio_count_msg_t)) 
		{ 
			// Something is received
			am_radio_count_msg_t* rcm = (am_radio_count_msg_t*)payload; 
			if (rcm->counter % 10 == 0)
			{
  			printf("Reset msg!");
				call Leds.led0Off();
				call Leds.led1Off();
				call Leds.led2Off();
			}
			else
			{
  			printf("Msg recvd [from %d]", rcm->senderId);
				switch(TOS_NODE_ID)
				{
					case 1:
					{
						call Leds.led0Toggle();
						break;
					}
					case 2:
					{
						call Leds.led1Toggle();
						break;
					}
					case 3:
					{					
						call Leds.led2Toggle();
						break;
					}
					default:
					{					
  					printf("Err [from %d]", rcm->senderId);
					}
				}
				
			}
		} 
		
  	printfflush();
		return msg; 
	} 

	
}

