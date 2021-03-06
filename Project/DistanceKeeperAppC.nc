#define NEW_PRINTF_SEMANTICS // Suppress a warning

#include "printf.h"
#include "DistanceKeeper.h"

configuration DistanceKeeperAppC {}

implementation {

/****** COMPONENTS *****/
  components MainC, DistanceKeeperC as App;
  
  components new AMSenderC(AM_PROBE_MSG);
  components new AMReceiverC(AM_PROBE_MSG);
  components new TimerMilliC() as SenderTimer;
  components new TimerMilliC() as CheckTimer;
  components ActiveMessageC;  

  components SerialPrintfC; // For serial printf
  
  
/****** INTERFACES *****/
  //Boot interface
  App.Boot -> MainC.Boot;


  //Send and Receive interfaces
  App.AMSend -> AMSenderC;
  App.Packet -> AMSenderC;
  App.Receive -> AMReceiverC;

  //Radio Control
  App.SplitControl -> ActiveMessageC;

  //Timer interface
  App.SenderTimer -> SenderTimer;
  App.CheckTimer -> CheckTimer;
}

