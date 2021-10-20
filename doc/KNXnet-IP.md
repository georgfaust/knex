# KnxnetIp
## Reaction to incoming telegrams

### Core
  * SEARCH_REQUEST -> SEARCH_RESPONSE
  * DESCRIPTION_REQUEST -> DESCRIPTION_RESPONSE
  * CONNECT_REQUEST -> CONNECT_RESPONSE
  * CONNECTSTATE_REQUEST -> CONNECTSTATE_RESPONSE
  * DISCONNECT_REQUEST -> DISCONNECT_RESPONSE
  
--> [{:ip, :transmit, knip_frame}]

### Device Management
  * DEVICE_CONFIGURATION_REQUEST (.req) -> DEVICE_CONFIGURATION_ACK, DEVICE_CONFIGURATION_REQUEST (.con)
  
--> [{:ip, :transmit, ip_frame1}, {:ip, :transmit, ip_frame2}]

  * DEVICE_CONFIGURATION_ACK
  
--> increment sequence counter

### Tunnelling
  * TUNNELING_REQUEST -> TUNNELING_ACK, tp_frame

--> [{:ip, :transmit, knip_frame}, {:dl, :req, %DataCemiFrame{}}]

  * TUNNELING_ACK
  
--> increment sequence counter

--- 

## TODO
  * implement heartbeat monitoring
  * defend additional individual addresses (tunnelling, 2.2.2)
  * generate Layer-2 ack frames for additional individual addresses (tunnelling, 2.2.2)

---

## Open questions 
  * How does the server deal with ACKs?