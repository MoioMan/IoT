#include "Challenge4.h"

configuration Challenge4AppC {}

implementation {


/****** COMPONENTS *****/
  components MainC, Challenge4C as App;
  //add the other components here
  components new AMSenderC(AM_MY_MSG);
  components new AMReceiverC(AM_MY_MSG);
  components new TimerMilliC() as Timer;
  components ActiveMessageC;  
  components new FakeSensorC();
  
/****** INTERFACES *****/
  //Boot interface
  App.Boot -> MainC.Boot;

  /****** Wire the other interfaces down here *****/

  //Send and Receive interfaces
  App.AMSend -> AMSenderC;
  App.Packet -> AMSenderC;
  App.Receive -> AMReceiverC;

  //Radio Control
  App.SplitControl -> ActiveMessageC;

  //Interfaces to access package fields
  App.PacketAcknowledgements -> AMSenderC.Acks;

  //Timer interface
  App.Timer -> Timer;
  
  //Fake Sensor read
  App.Read -> FakeSensorC;

}

