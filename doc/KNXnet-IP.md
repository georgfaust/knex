# KNXnetIP
## Reaction to incoming telegrams

### Core
  * SEARCH_REQUEST -> SEARCH_RESPONSE
  * DESCRIPTION_REQUEST -> DESCRIPTION_RESPONSE
  * CONNECT_REQUEST -> CONNECT_RESPONSE
  * CONNECTSTATE_REQUEST -> CONNECTSTATE_RESPONSE
  * DISCONNECT_REQUEST -> DISCONNECT_RESPONSE
  
--> [{:ethernet, :transmit, ip_frame}]

### Device Management
  * DEVICE_CONFIGURATION_REQUEST (.req) -> DEVICE_CONFIGURATION_ACK, DEVICE_CONFIGURATION_REQUEST (.con)
  
--> [{:ethernet, :transmit, ip_frame1}, {:ethernet, :transmit, ip_frame2}]

  * DEVICE_CONFIGURATION_ACK
  
--> increment sequence counter

### Tunneling
  * TUNNELING_REQUEST -> TUNNELING_ACK, tp_frame

--> [{:ethernet, :transmit, ip_frame}, {:dl, :req, %CEMIFrame{}}]

  * TUNNELING_ACK
  
--> increment sequence counter

--- 

## TODO
  * implement heartbeat monitoring
  * defend additional individual addresses (tunneling, 2.2.2)
  * generate Layer-2 ack frames for additional individual addresses (tunneling, 2.2.2)

---

## Open questions 
  * How does the server deal with ACKs?