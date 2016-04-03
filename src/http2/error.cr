module HTTP2
  class Error < Exception
    enum Code : UInt32
      NO_ERROR            = 0x0_u32
      PROTOCOL_ERROR      = 0x1_u32
      INTERNAL_ERROR      = 0x2_u32
      FLOW_CONTROL_ERROR  = 0x3_u32
      SETTINGS_TIMEOUT    = 0x4_u32
      STREAM_CLOSED       = 0x5_u32
      FRAME_SIZE_ERROR    = 0x6_u32
      REFUSED_STREAM      = 0x7_u32
      CANCEL              = 0x8_u32
      COMPRESSION_ERROR   = 0x9_u32
      CONNECT_ERROR       = 0xa_u32
      ENHANCE_YOUR_CALM   = 0xb_u32
      INADEQUATE_SECURITY = 0xc_u32
      HTTP_1_1_REQUIRED   = 0xd_u32
    end

    getter error_code : Code

    def initialize(error_code : Code)
      @error_code = error_code
      super(error_code.to_s)
    end
  end

  # For all the nice features that aren't implemented yet
  class NotImplementedError < Exception
  end
end
