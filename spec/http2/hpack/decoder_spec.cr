require "../../spec_helper"

describe HTTP2::HPACK::Decoder do
  it "does not allow dynamic table size updates after common header fields" do
    decoder = HTTP2::HPACK::Decoder.new
    data = [130, 135, 132, 65, 140, 34, 244, 30, 99, 218, 149, 232, 77, 199, 154, 105, 159, 32, 63, 225, 31]
    slice = Slice(UInt8).new(data.size) { |i| data[i].to_u8 }
    expect_raises(HTTP2::Error) do
      decoder.decode(slice)
    end
  end
end
