#define NEW_PRINTF_SEMANTICS // Suppress a warning

#include "printf.h"
#include "Challenge3.h"


configuration Challenge3AppC
{

}

implementation 
{
  components MainC, Challenge3C, LedsC;
  components new TimerMilliC();
  components PrintfC;				// For printf
  components SerialStartC;  // For printf
  components ActiveMessageC; 
	components new AMSenderC(AM_COUNTER_MSG_TYPE);
  components new AMReceiverC(AM_COUNTER_MSG_TYPE);
	
	
  Challenge3C.Boot -> MainC;
  
  Challenge3C.Timer -> TimerMilliC;
  Challenge3C.Leds -> LedsC;
  
  Challenge3C.Packet -> AMSenderC;
  Challenge3C.AMSend -> AMSenderC;
  Challenge3C.AMControl -> ActiveMessageC;  
  Challenge3C.Receive -> AMReceiverC;
}

