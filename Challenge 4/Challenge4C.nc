#include "Challenge4.h"
#include "Timer.h"

module Challenge4C {

  uses {
  /****** INTERFACES *****/
	interface Boot; 
	
    //interfaces for communication
	interface Packet;
	interface AMSend;
	interface SplitControl;
  	interface Receive;

	//interface for timer
	interface Timer<TMilli> as Timer;	

    //other interfaces, if needed
	interface PacketAcknowledgements;
	
	//interface used to perform sensor reading (to get the value from a sensor)
	interface Read<uint16_t>;
  }

} implementation {

  uint8_t counter=0;
  uint8_t rec_id;
  message_t packet;

  void sendReq();
  void sendResp();
  
  
  //***************** Send request function ********************//
  void sendReq() {
	//Prepare the msg
	my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
	dbg("radio_send", "Creating message\n");

	msg->msg_type = REQ;
	msg->msg_counter = counter;
	msg->value = 0;
	dbg("radio_send", "Sending request (counter is %hhu\n)", msg->msg_counter);

	//Set the ACK flag for the message using the PacketAcknowledgements interface
	if (call PacketAcknowledgements.requestAck(&packet) == SUCCESS) {
		dbg("radio_send", "ACK requested\n");
	}
	else {
    	dbgerror("radio_send", "Error enabling ACK (counter is %hhu)\n", msg->msg_counter);
	}

	//Send an UNICAST message to the correct node
	if(call AMSend.send(2, &packet,sizeof(my_msg_t)) == SUCCESS){
	    dbg("radio_pack",">>>Pack sent:\n \t Payload length %hhu \n", call Packet.payloadLength(&packet));
	    dbg_clear("radio_pack","\t Payload Sent\n");
		dbg_clear("radio_pack", "\t\t type: %s\n", msg->msg_type);
		dbg_clear("radio_pack", "\t\t counter: %hhu\n", msg->msg_counter);
		dbg_clear("radio_pack", "\t\t value: %hhu\n", msg->value);	 
  	}
 }        

  //****************** Task send response *****************//
  void sendResp() {
	dbg("radio_send", "Sensor reading\n");
	call Read.read();
  }

  //***************** Boot interface ********************//
  event void Boot.booted() {
	dbg("boot","Interface booted\n");
	call SplitControl.start();
  }

  //***************** SplitControl interface ********************//
  event void SplitControl.startDone(error_t err){
    if ( err == SUCCESS) {
		dbg("radio", "Radio is on.\n");
		if (TOS_NODE_ID == 1) {
			dbg("radio", "NodeID %d: timer started.\n", TOS_NODE_ID);
			call Timer.startPeriodic(1000);
		}
	}
  }
  
  event void SplitControl.stopDone(error_t err){
    dbg("role", "Mote %d was shut down \n", TOS_NODE_ID);
  }

  //***************** MilliTimer interface ********************//
  event void Timer.fired() {
	dbg("boot", "Timer was fired\n");
	sendReq();
  }
  

  //********************* AMSend interface ****************//
  event void AMSend.sendDone(message_t* buf,error_t err) {

	my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));

	//Check if the packet is sent
	if (&packet == buf && err == SUCCESS) {
      	dbg("radio_send", "Packet sent at time %s \n", sim_time_string());
		counter++;
		if(msg->msg_type == REQ){
			dbg("radio_send", "Counter increased to %hhu\n", counter);
		}
    }
    else{
      	dbgerror("radio_send", "Send done error");
    }

	//Check if the ACK is received 
	if (call PacketAcknowledgements.wasAcked(&packet)) {
      	dbg_clear("radio_ack", "\t\tAck received at time %s (counter is %hhu)\n", sim_time_string(), msg->msg_counter);

		if(msg->msg_type == RESP){
			call SplitControl.stop();
		}
		else{
			dbg("radio", "Timer stopped.\n");
			call Timer.stop();
		}
    }
    else{
      	dbgerror("radio_ack", "Receiving error (no ack)\n");
    }
  }

  //***************************** Receive interface *****************//
  event message_t* Receive.receive(message_t* buf,void* payload, uint8_t len) {

	if (len == sizeof(my_msg_t)) {

		my_msg_t* msg = (my_msg_t*)payload;

		//Read the content of the message
    	dbg("radio_rec", "Received packet at time %s\n", sim_time_string());
    	dbg("radio_pack",">>>Pack \n \t Payload length %hhu \n", call Packet.payloadLength(buf));
    	dbg_clear("radio_pack","\t\t Payload Received\n" );
    	dbg_clear("radio_pack", "\t\t type: %s \n", msg->msg_type);
		dbg_clear("radio_pack", "\t\t counter: %hhu\n", msg->msg_counter);
		dbg_clear("radio_pack", "\t\t value: %hhu\n", msg->value);

		// Check if the type is request (REQ)
		if (msg->msg_type == REQ) {

			dbg("radio_rec", "Request received\n");
			rec_id = msg->msg_counter;
			sendResp();

		} else {

			dbg("radio_rec", "Response received (sensor value is %hhu)\n", msg->value);
			call Timer.startOneShot(1);
		}
	}
    else {
		dbgerror("radio_rec", "Receiving error \n");
    }

	return buf;
  }
  
  //************************* Read interface **********************//
  event void Read.readDone(error_t result, uint16_t data) {
	//Prepare the response (RESP)
	my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));

	msg->msg_type = RESP;
	msg->msg_counter = rec_id;
	msg->value = data;
	dbg("radio_send", "Sending response from mote 2 to 1\n");

	if (call PacketAcknowledgements.requestAck(&packet) == SUCCESS) {
		dbg("radio_send", "ACK requested\n");
	}
	else {
    	dbgerror("radio_send", "Error enabling ACK (counter is %hhu)\n", msg->msg_counter);
	}

	//Send back (with a unicast message) the response
	if(call AMSend.send(1, &packet,sizeof(my_msg_t)) == SUCCESS){
	    dbg("radio_pack",">>>Pack sent\n \t Payload length %hhu \n", call Packet.payloadLength(&packet));
	    dbg_clear("radio_pack","\t Payload Sent\n");
		dbg_clear("radio_pack", "\t\t type: %s\n", msg->msg_type);
		dbg_clear("radio_pack", "\t\t counter: %hhu\n", msg->msg_counter);
		dbg_clear("radio_pack", "\t\t value: %hhu\n", msg->value); 
  	}
}

