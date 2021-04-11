# SystemB Profile 

This document lists all mandatory and some useful optional clauses for the SystemB profile.

## Unklar

- was heisst "except for the coding of the internal service primitives."

## TODO

- A.5 KNXnet/IP and KNX IP Profiles
- 3.5 KNX IP

## 2.2 Common Profile

### 2.2.3 Data Link Layer - general

[06]
    §1.1 Functions of the Data Link Layer
    §1.2 Possible Media and their Impact on Layer-2
    §1.3 Objective
    §1.4 Definitions
    §3 Data Link Layer Protocols
    §4 Parameters of Layer-2 (except TP1 Fast Polling)

### 2.2.6 Network Layer - general

[07]
    §1 Overview
    §2.1 NPDU
    §2.3 Parameters of Network Layer 
    hop_count: preferred value: 6.
    §2.4.1

### 2.2.13 Application Layer – Group Oriented

[09]
    §2 APDU
    A_GroupValue_Read-PDU
    A_GroupValue_Response-PDU
    A_GroupValue_Write-PDU

    data must be coded as indicated in §3.1
    Application Layer Services on Multicast
    Communication Mode

    Datapoint Types shall comply with Connection Codes used.

### 2.2.16 Application Interface Layer – Group Objects

[10]
    §3 Group Object Server

### 3 Medium dependent layers

TODO

## 4 Configuration & Management (S-Mode, Server)


### 4.1.1 TL - broadcast

[08] 
    All features of the following clauses are mandatory except for the coding of the 
    internal service primitives.

    §1.3 Point-to-all-Points Connectionless (Broadcast) Communication Mode
    §2 TPDU
    §3.4 T_Data_Broadcast
    §4 Parameters of Transport Layer

### 4.1.2 TL - connection oriented

[08]
    All features of the following clauses are mandatory except for the coding of the internal
    service primitives.

    §1.6 Point-to-Point, Connection-Oriented Communication Mode
    §2 TPDU
    §3.7 T_Connect service
    §3.8 T_Disconnect service
    §3.9 T_Data_Connected service
    §4 Parameters of Transport Layer
    §5.1 States
    §5.2 Actions
    §5.3.3 Style 3



### 4.1.4 TL - connectionless

[08] 
    All features of the following clauses are mandatory except for the coding of the
    internal service primitives:

    §1.5 Point-to-point connectionless Communication Mode
    §2 TPDU
    §3.6 T_Data_Individual

## 4.2 Device Management

### 4.2.1 Direct Memory Access

[12]
    §3.2.1 DMP_Connect_RCo
    §3.3.2 DMP_Disconnect_RCo
    §3.18.2 DMP_MemRead_RCo
    §3.16.2 DMP_MemWrite_RCo
[27]
    §2 Network Management Server Tests


### 4.2.2 DMA on user memory

[12]
    §3.19 DM_UserMemWrite

[27]
    §2 Network Management Server Tests


### 4.2.3 Verify Mode (for A_Memory_Write)

[11] 
    §4.2.14.7 "Verify Mode Control" management server part.

[27]
    §2 Network Management Server Tests Tests 7.1 to 7.7

### 4.2.4 Interface Object Handling

[12]
    §3.22.2 DMP_InterfaceObjectWrite_R
    §3.24.2 DM_InterfaceObjectRead_R
    §3.23.2 DMP_InterfaceObjectVerify_R
    §3.25.2 DM_InterfaceObjectScan_R

[10]
    §4 Interface Object Server

[27]
    §2 Network Management Server Tests

[Annex A]

#### 0 Device Object

PID_OBJECT_TYPE
PID_OBJECT_NAME (not mandatory)
PID_FIRMWARE_REVISION (not mandatory)
PID_SERIAL_NUMBER
PID_MANUFACTURER_ID
PID_DEVICE_CONTROL
PID_ORDER_INFO
PID_VERSION
PID_ROUTING_COUNT
PID_MAX_RETRY_COUNT
PID_PROG_MODE
PID_PRODUCT_ID (not mandatory)
PID_MAX_APDU_LENGTH (only mandatory if long frames are supported)
PID_SUBNET_ADDR (only mandatory for devices with EMI)
PID_DEVICE_ADDR (only mandatory for devices with EMI)

#### 1 Addresstable Object

PID_OBJECT_TYPE
PID_OBJECT_NAME (not mandatory)
PID_LOAD_STATE_CONTROL
PID_TABLE_REFERENCE
PID_TABLE
PID_MCB_TABLE (not mandatory)
PID_LOAD_STATE_CONTROL -- ???

#### 2 Association Table Object

(same as Addresstable Object)

#### 3 Applicationprogram Object

PID_OBJECT_TYPE
PID_OBJECT_NAME (not mandatory)
PID_LOAD_STATE_CONTROL
PID_RUN_STATE_CONTROL (not mandatory)
PID_TABLE_REFERENCE
PID_PROGRAM_VERSION
PID_PEI_TYPE
PID_MCB_TABLE (not mandatory)

#### Interfaceprogram Object (Object Type = 4) ???

PID_OBJECT_TYPE
PID_LOAD_STATE_CONTROL
PID_RUN_STATE_CONTROL
PID_TABLE_REFERENCE
PID_PROGRAM_VERSION
PID_PEI_TYPE
PID_MCB_TABLE (not mandatory)

#### 9 Group Object Table Object

PID_OBJECT_TYPE
PID_OBJECT_NAME (not mandatory)
PID_LOAD_STATE_CONTROL
PID_TABLE_REFERENCE
PID_TABLE
PID_MCB_TABLE (not mandatory)


### 4.2.5 Reduced Interface Objects

(not mandatory)

### 4.2.6 Function Properties

(not mandatory/not yet defined)

### 4.2.7 Load - and Run State Machines

#### 4.2.7.1 Load State Machine a) Realisation Type 1 - Property based

[11] records

[12]
    §3.27.3 DMP_LoadStateMachineWrite_Rco_IO
    §3.28.3 DM_LoadStateMachineVerify_R_IO
    §3.29.3 DMP_LoadStateMachineRead_R_IO

[27]
    §2 Network Management Tests

#### 4.2.7.1 Load State Machine b) Realisation Type 2 – Memory mapped

(not mandatory)


### 4.2.7.2 Run State Machine a) Realisation Type 1 - Property based

[11]
    records

[12]
    §3.30.3 DMP_RunStateMachineWrite_R_IO
    §3.31.3 DMP_RunStateMachineVerify_R_IO
    §3.32.3 DMP_RunStateMachineRead_R_IO
    
[27]
    §2 Network Management Tests

### 4.2.7.2 Run State Machine b) Realisation Type 2 – Memory mapped

(not mandatory)


### 4.2.8 Hardware specific Parameters

??? 0100h (RW)

[11] 
    §4.18 OptionReg

### 4.2.9 RAM cleared

(not applicable)

### 4.2.10 User EEPROM

[11]
    memory allocation mechanisms for
    - Device Object
    - Address table object
    - Association table object
    - Group Object Table Interface Object
    - Application object (1)
    - Application object 2
    - The memory range is implementation
    specific; for the mechanisms see
    System B Configuration Procedures in
    [13].


### 4.2.11 Restart

#### 4.2.11.1 Restart connectionless

(not mandatory)


#### 4.2.11.2 Restart connection-oriented

[12] 
    §3.2.1 DMP_Connect_RCo
    §3.7.3 DM_Restart_RCo

[Test 27???]
    §2.9.1 Send Restart

### 4.2.11.3 Master Reset

(not mandatory)

### 4.2.12 Authorization

[12]
    §3.5.1 DM_Authorize_RCo
    §3.5.2 DM_Authorize2_RCo
    §3.6 DM_SetKey

### 4.2.13 Memory Control Table

(not mandatory)


### 4.3 Device Identification

3 Device Descriptor Type 0
8 Identification of Application

### 1 Device Descriptor Service - connection oriented

[09] - §3.4.2.1 A_DeviceDescriptor_Read-service

### 2 Device Descriptor Service - connectionless

[09] - §3.4.2.1 A_DeviceDescriptor_Read-service
[12] - §3.2.2 DMP_Connect_RCl


## References

[01] Chapter 3/2/2 - Twisted Pair 1  v1.1 AS of 2008.12.19 
[02] Chapter 3/2/3 - Powerline 110 V1.1 AS of 2008.12.16
[03] Chapter 3/2/5 - Communication Medium RF v0.3 DV of 2004.12.22
[04] Chapter 3/2/6 - Communication Medium IP v1.0.00 AS of 2010.07.23
[05] Chapter 3/3/1 - Physical Layer General v1.1 AS of 2008.12.19
[06] Chapter 3/3/2 - Data Link Layer General v1.1 AS of 2008.12.19
[07] Chapter 3/3/3 - Network Layer v1.1 AS of 2008.12.22
[08] Chapter 3/3/4 - Transport Layer v1.1 AS of 2008.12.22
[09] Chapter 3/3/7 - Application Layer v1.1 AS of 2008.12.24
[10] Chapter 3/4/1 - Application Interface Layer v1.1 AS of 2009.01.05
[11] Chapter 3/5/1 - Resources v1.2 AS of 2009.03.31
[12] Chapter 3/5/2 - Management Procedures V1.4 AS of 2009.01.14
[13] Chapter 3/5/3 - Configuration Procedures v1.0 AS of 2009.02.06
[14] Chapter 3/6/2 - Physical External Interface v1.1 AS of 2009.02.09
[15] Chapter 3/6/3 - External Message Interface
[16] Chapter 3/8/1 - Overview (KNXnet/IP) v1.4 AS of 2009.06.29
[17] Chapter 3/8/2 - Core (KNXnet/IP)
[18] Chapter 3/8/3 - Device Management (KNXnet/IP)
[19] Chapter 3/8/4 - Tunnelling (KNXnet/IP)
[20] Chapter 3/8/5 - Routing (KNXnet/IP)
[21] Volume 7      - Application Descriptions
[22] Chapter 8/2/2 - TP1 Physical and Link Layer Tests
[23] Chapter 8/2/3 - PL110 Physical and Link Layer Tests V1.0 AS of 2002.02.05
[24] Chapter 8/2/5 - Radio Frequency v1.0 RfV of 2003.12.03
[25] Chapter 8/3/3 - Network Layer Tests v1.0 AS of 2002.02.05
[26] Chapter 8/3/4 - Transport Layer Tests v1.0 AS of 2002.02.05
[27] Chapter 8/3/7 - Application (Interface) Layer Testing – Network Management Server/Client
[28] Part 8/7      - Testing v1.0 AS of 2002.02.05 Interworking Tests v1.1 FV of 2003.10.15
