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
      channel_32_param: :generic_01
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
      channel_32_param: 132
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
      tunnelling_req: 0x0420,
      tunnelling_ack: 0x0421
    ]
  )


end
