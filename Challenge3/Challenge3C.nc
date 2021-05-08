#include "printf.h"	
#include "Challenge3.h"

#define LED0_FLAG 0x01
#define LED1_FLAG 0x02
#define LED2_FLAG	0x04
#define NO_LEDS		0x00

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
	uint8_t leds_flags;
	uint8_t recv_msg_count;
  
  // 1. At boot, start the AM Controller
  event void Boot.booted() 
  { 
		counter = 0;
		leds_flags = 0;
		recv_msg_count = 0;
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
  			printf("Msg sent\n");
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
			
			recv_msg_count++;
			if (rcm->counter % 10 == 0)
			{
  			printf("Reset msg!\n");
				call Leds.led0Off();
				call Leds.led1Off();
				call Leds.led2Off();
				leds_flags = NO_LEDS;
			}
			else
			{
  			printf("Msg recvd [from %d]\n", rcm->senderId);
				switch(rcm->senderId)
				{
					case 1:
					{
						call Leds.led0Toggle();
						leds_flags = (leds_flags & ~LED0_FLAG) | (~leds_flags & LED0_FLAG);
						break;
					}
					case 2:
					{
						call Leds.led1Toggle();
						leds_flags = (leds_flags & ~LED1_FLAG) | (~leds_flags & LED1_FLAG);
						break;
					}
					case 3:
					{					
						call Leds.led2Toggle();
						leds_flags = (leds_flags & ~LED2_FLAG) | (~leds_flags & LED2_FLAG);
						break;
					}
					default:
					{					
  					printf("Err [from %d]\n", rcm->senderId);
					}
				}
				
			}
			
			if (TOS_NODE_ID == 2 && recv_msg_count <= 20) // Print Mote2 led status up to 20 times
				printf("%d%d%d\n", (leds_flags & LED0_FLAG) > 0, (leds_flags & LED1_FLAG) > 0, (leds_flags & LED2_FLAG) > 0);
				
		} 
		
  	printfflush();
		return msg; 
	} 

	
}

