defmodule Knx.Defs do
  use Const

  enum(object_type,
    do: [
      device: 0,
      addr_tab: 1,
      assoc_tab: 2,
      app_prog: 3,
      interface_prog: 4,
      router: 6,
      cemi_server: 8,
      go_tab: 9,
      knxnet_ip_parameter: 11,
      file_server: 13
    ]
  )

  enum(pdt_id,
    do: [
      ctrl: 0x00,
      char: 0x01,
      unsigned_char: 0x02,
      int: 0x03,
      unsigned_int: 0x04,
      knx_float: 0x05,
      date: 0x06,
      time: 0x07,
      long: 0x08,
      unsigned_long: 0x09,
      float: 0x0A,
      double: 0x0B,
      # TODO how to handle this?
      char_block: 0x0C,
      poll_group_setting: 0x0D,
      # TODO how to handle this?
      short_char_block: 0x0E,
      # TODO dpt not implemented
      date_time: 0x0F,
      # TODO
      # variable_length: 0x10,
      generic_01: 0x11,
      generic_02: 0x12,
      generic_03: 0x13,
      generic_04: 0x14,
      generic_05: 0x15,
      generic_06: 0x16,
      generic_07: 0x17,
      generic_08: 0x18,
      generic_09: 0x19,
      generic_10: 0x1A,
      generic_11: 0x1B,
      generic_12: 0x1C,
      generic_13: 0x1D,
      generic_14: 0x1E,
      generic_15: 0x1F,
      generic_16: 0x20,
      generic_17: 0x21,
      generic_18: 0x22,
      generic_19: 0x23,
      generic_20: 0x24,
      utf8: 0x2F,
      version: 0x30,
      alarm_info: 0x31,
      binary_information: 0x32,
      bitset8: 0x33,
      bitset16: 0x34,
      enum8: 0x35,
      scaling: 0x36,
      ne_vl: 0x3C,
      ne_fl: 0x3D,
      function: 0x3E,
      escape: 0x3F
    ]
  )

  enum(pid_pdt,
    do: [
      object_type: :unsigned_int,
      object_name: :unsigned_char,
      semaphor: :none,
      group_object_reference: :none,
      load_state_ctrl: :ctrl,
      run_state_ctrl: :ctrl,
      table_reference: :unsigned_long,
      service_ctrl: :unsigned_int,
      firmware_revision: :unsigned_char,
      serial: :generic_06,
      manu_id: :unsigned_int,
      prog_version: :generic_05,
      device_ctrl: :bitset8,
      order_info: :generic_10,
      pei_type: :unsigned_char,
      port_configuration: :unsigned_char,
      table: :unsigned_int,
      version: :version,
      mcb_table: :generic_07,
      error_code: :generic_01,
      object_index: :unsigned_char,
      routing_count: :unsigned_char,
      prog_mode: :bitset8,
      max_apdu_length: :unsigned_int,
      subnet_addr: :unsigned_char,
      device_addr: :unsigned_char,
      hw_type: :generic_06,
      device_descriptor: :generic_02,
      channel_01_param: :generic_01,
      channel_02_param: :generic_01,
      channel_03_param: :generic_01,
      channel_04_param: :generic_01,
      channel_05_param: :generic_01,
      channel_06_param: :generic_01,
      channel_07_param: :generic_01,
      channel_08_param: :generic_01,
      channel_09_param: :generic_01,
      channel_10_param: :generic_01,
      channel_11_param: :generic_01,
      channel_12_param: :generic_01,
      channel_13_param: :generic_01,
      channel_14_param: :generic_01,
      channel_15_param: :generic_01,
      channel_16_param: :generic_01,
      channel_17_param: :generic_01,
      channel_18_param: :generic_01,
      channel_19_param: :generic_01,
      channel_20_param: :generic_01,
      channel_21_param: :generic_01,
      channel_22_param: :generic_01,
      channel_23_param: :generic_01,
      channel_24_param: :generic_01,
      channel_25_param: :generic_01,
      channel_26_param: :generic_01,
      channel_27_param: :generic_01,
      channel_28_param: :generic_01,
      channel_29_param: :generic_01,
      channel_30_param: :generic_01,
      channel_31_param: :generic_01,
      channel_32_param: :generic_01,
      # KNXnet/IP Parameter Object
      project_installation_id: :unsigned_int,
      knx_individual_address: :unsigned_int,
      additional_individual_addresses: :unsigned_int,
      current_ip_assignment_method: :unsigned_char,
      ip_assignment_method: :unsigned_char,
      ip_capabilities: :bitset8,
      current_ip_address: :unsigned_long,
      current_subnet_mask: :unsigned_long,
      current_default_gateway: :unsigned_long,
      ip_address: :unsigned_long,
      subnet_mask: :unsigned_long,
      default_gateway: :unsigned_long,
      dhcp_bootp_server: :unsigned_long,
      mac_address: :generic_06,
      system_setup_multicast_address: :unsigned_long,
      routing_multicast_address: :unsigned_long,
      ttl: :unsigned_char,
      knxnetip_device_capabilities: :bitset16,
      knxnetip_device_state: :unsigned_char,
      knxnetip_routing_capabilities: :unsigned_char,
      priority_fifo_enabled: :binary_information,
      queue_overflow_to_ip: :unsigned_int,
      queue_overflow_to_knx: :unsigned_int,
      msg_transmit_to_ip: :unsigned_long,
      msg_transmit_to_knx: :unsigned_long,
      friendly_name: :unsigned_char,
      routing_busy_wait_time: :unsigned_int
    ]
  )

  enum(prop_id,
    do: [
      object_type: 1,
      object_name: 2,
      semaphor: 3,
      group_object_reference: 4,
      load_state_ctrl: 5,
      run_state_ctrl: 6,
      table_reference: 7,
      service_ctrl: 8,
      firmware_revision: 9,
      serial: 11,
      manu_id: 12,
      prog_version: 13,
      device_ctrl: 14,
      order_info: 15,
      pei_type: 16,
      port_configuration: 17,
      table: 23,
      version: 25,
      mcb_table: 27,
      error_code: 28,
      object_index: 29,
      routing_count: 51,
      prog_mode: 54,
      max_apdu_length: 56,
      subnet_addr: 57,
      device_addr: 58,
      hw_type: 78,
      device_descriptor: 83,
      channel_01_param: 101,
      channel_02_param: 102,
      channel_03_param: 103,
      channel_04_param: 104,
      channel_05_param: 105,
      channel_06_param: 106,
      channel_07_param: 107,
      channel_08_param: 108,
      channel_09_param: 109,
      channel_10_param: 110,
      channel_11_param: 111,
      channel_12_param: 112,
      channel_13_param: 113,
      channel_14_param: 114,
      channel_15_param: 115,
      channel_16_param: 116,
      channel_17_param: 117,
      channel_18_param: 118,
      channel_19_param: 119,
      channel_20_param: 120,
      channel_21_param: 121,
      channel_22_param: 122,
      channel_23_param: 123,
      channel_24_param: 124,
      channel_25_param: 125,
      channel_26_param: 126,
      channel_27_param: 127,
      channel_28_param: 128,
      channel_29_param: 129,
      channel_30_param: 130,
      channel_31_param: 131,
      channel_32_param: 132,
      # KNXnet/IP Parameter Object
      project_installation_id: 51,
      knx_individual_address: 52,
      additional_individual_addresses: 53,
      current_ip_assignment_method: 54,
      ip_assignment_method: 55,
      ip_capabilities: 56,
      current_ip_address: 57,
      current_subnet_mask: 58,
      current_default_gateway: 59,
      ip_address: 60,
      subnet_mask: 61,
      default_gateway: 62,
      dhcp_bootp_server: 63,
      mac_address: 64,
      system_setup_multicast_address: 65,
      routing_multicast_address: 66,
      ttl: 67,
      knxnetip_device_capabilities: 68,
      knxnetip_device_state: 69,
      knxnetip_routing_capabilities: 70,
      priority_fifo_enabled: 71,
      queue_overflow_to_ip: 72,
      queue_overflow_to_knx: 73,
      msg_transmit_to_ip: 74,
      msg_transmit_to_knx: 75,
      friendly_name: 76,
      routing_busy_wait_time: 78
    ]
  )

  enum(addr_t,
    do: [
      ind: 0,
      grp: 1
    ]
  )

  enum(load_state,
    do: [
      unloaded: 0,
      loaded: 1,
      loading: 2,
      error: 3
    ]
  )

  enum(load_event,
    do: [
      noop: 0,
      start_loading: 1,
      load_completed: 2,
      additional_lc: 3,
      unload: 4
    ]
  )

  enum(additional_lc,
    do: [
      data_rel_alloc: 0x0B
    ]
  )

  enum(apci,
    do: [
      group_read: <<0b0000_000000::10>>,
      group_resp: <<0b0001::4>>,
      group_write: <<0b0010::4>>,
      ind_addr_write: <<0b0011_000000::10>>,
      ind_addr_read: <<0b0100_000000::10>>,
      ind_addr_resp: <<0b0101_000000::10>>,
      mem_read: <<0b1000::4>>,
      mem_resp: <<0b1001::4>>,
      mem_write: <<0b1010::4>>,
      user_mem_read: <<0b1011_000000::10>>,
      user_mem_resp: <<0b1011_000001::10>>,
      user_mem_write: <<0b1011_000010::10>>,
      user_manu_info_read: <<0b1011_000101::10>>,
      user_manu_info_resp: <<0b1011_000110::10>>,
      fun_prop_command: <<0b1011_000111::10>>,
      fun_prop_state_read: <<0b1011_001000::10>>,
      fun_prop_state_resp: <<0b1011_001001::10>>,
      device_desc_read: <<0b1100::4>>,
      device_desc_resp: <<0b1101::4>>,
      restart_basic: <<0b1110_000000::10>>,
      restart_master: <<0b1110_000001::10>>,
      restart_resp: <<0b1110_100001::10>>,
      auth_req: <<0b1111_010001::10>>,
      auth_resp: <<0b1111_010010::10>>,
      key_write: <<0b1111_010011::10>>,
      key_resp: <<0b1111_010100::10>>,
      prop_read: <<0b1111_010101::10>>,
      prop_resp: <<0b1111_010110::10>>,
      prop_write: <<0b1111_010111::10>>,
      prop_desc_read: <<0b1111_011000::10>>,
      prop_desc_resp: <<0b1111_011001::10>>,
      ind_addr_serial_read: <<0b1111_011100::10>>,
      ind_addr_serial_resp: <<0b1111_011101::10>>,
      ind_addr_serial_write: <<0b1111_011110::10>>
    ]
  )

  enum(knxnetip_constant,
    do: [
      port: 3671,
      system_setup_multicast_addr: 0xE000_170C,
      reserved: 0x00
    ]
  )

  enum(knx_medium_code,
  do: [
    tp1: 0x02,
    knx_ip: 0x20,
  ]
)

  enum(structure_length,
    do: [
      header: 0x06,
      hpai: 0x08,
      dib_device_info: 0x36,
      dib_supp_svc_families: 0x08,
      connection_header: 0x04,
      device_configuration_ack: 0x0A,
      tunneling_ack: 0x0A,
      cemi_l_data_without_data: 0x09
    ]
  )

  enum(service_type_id,
    do: [
      search_req: 0x0201,
      search_resp: 0x0202,
      description_req: 0x0203,
      description_resp: 0x0204,
      connect_req: 0x0205,
      connect_resp: 0x0206,
      connectionstate_req: 0x0207,
      connectionstate_resp: 0x0208,
      disconnect_req: 0x0209,
      disconnect_resp: 0x020A,
      device_configuration_req: 0x0310,
      device_configuration_ack: 0x0311,
      tunneling_req: 0x0420,
      tunneling_ack: 0x0421
    ]
  )

  enum(service_family_id,
    do: [
      core: 0x02,
      device_management: 0x03,
      tunneling: 0x04
    ]
  )

  enum(protocol_version,
    do: [
      knxnetip: 0x10,
      core: 0x01,
      device_management: 0x01,
      tunneling: 0x01
    ]
  )

  enum(protocol_code,
    do: [
      udp: 1,
      tcp: 2
    ]
  )

  enum(description_type_code,
    do: [
      device_info: 1,
      supp_svc_families: 2,
      ip_config: 3,
      ip_cur_config: 4,
      knx_addresses: 5
    ]
  )

  enum(connection_type_code,
    do: [
      device_mgmt_con: 3,
      tunnel_con: 4,
      remlog_con: 6,
      remconf_con: 7,
      objsvr_con: 8
    ]
  )

  enum(common_error_code,
    do: [
      no_error: 0x00,
      host_protocol_type: 0x01,
      version_not_supported: 0x02,
      sequence_number: 0x04
    ]
  )

  enum(connect_response_status_code,
    do: [
      no_error: 0x00,
      connection_type: 0x22,
      connection_option: 0x23,
      no_more_connections: 0x24
    ]
  )

  enum(connectionstate_response_status_code,
    do: [
      no_error: 0x00,
      connection_id: 0x21,
      data_connection: 0x26,
      knx_connection: 0x27
    ]
  )

  # TODO is this correct? (not specified)
  enum(disconnect_response_status_code,
    do: [
      no_error: 0x00,
      connection_id: 0x21
    ]
  )

  # TODO is this correct? (not specified)
  enum(device_configuration_ack_status_code,
    do: [
      no_error: 0x00,
      connection_id: 0x21
    ]
  )

  # TODO is this correct? (not specified)
  enum(tunneling_ack_status_code,
    do: [
      no_error: 0x00,
      connection_id: 0x21
    ]
  )

  enum(tunneling_connect_ack_error_code,
    do: [
      no_error: 0x00,
      tunneling_layer: 0x29
    ]
  )

  enum(tunneling_knx_layer,
    do: [
      tunnel_linklayer: 0x02,
      tunnel_raw: 0x04,
      tunnel_busmonitor: 0x80
    ]
  )

  # TODO why are there 2 identical codes?
  enum(cemi_message_code,
    do: [
      l_data_req: 0x11,
      l_data_con: 0x2E,
      l_data_ind: 0x29,
      m_propread_req: 0xFC,
      m_propread_con: 0xFB,
      m_propwrite_req: 0xF6,
      m_propwrite_con: 0xF5,
      m_propinfo_ind: 0xF7,
      m_funcpropcommand_req: 0xF8,
      m_funcpropcommand_con: 0xFA,
      m_funcpropstateread_req: 0xF9,
      m_funcpropstateread_con: 0xFA,
      m_reset_req: 0xF1,
      m_reset_ind: 0xF0
    ]
  )

  enum(cemi_error_code,
    do: [
      unspecific: 0x00,
      out_of_range: 0x01,
      out_of_max_range: 0x02,
      out_of_min_range: 0x03,
      memory_error: 0x04,
      read_only: 0x05,
      illegal_command: 0x06,
      void_dp: 0x07,
      type_conflict: 0x08,
      prop_index_range: 0x09,
      value_temporarily_not_writeable: 0x0A
    ]
  )
end
