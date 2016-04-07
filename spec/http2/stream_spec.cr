require "../spec_helper"

describe HTTP2::Stream do
  context "in the IDLE state" do
    stream = HTTP2::Stream.new(1_u32, HTTP2::Stream::State::IDLE)

    context "after receiving a HEADERS frame" do
      it "transitions to the OPEN state" do
        stream.receive(HTTP2::Frame.new(HTTP2::Frame::Type::Headers, stream.id, HTTP2::Frame::Flags::None, "".to_slice))
        stream.state.should eq HTTP2::Stream::State::OPEN
      end
    end

    context "after receiving a HEADERS frame w/ END_STREAM flag" do
      it "transitions to the HALF_CLOSED_REMOTE state" do
        stream.receive(HTTP2::Frame.new(HTTP2::Frame::Type::Headers, stream.id, HTTP2::Frame::Flags::EndStream, "".to_slice))
        stream.state.should eq HTTP2::Stream::State::HALF_CLOSED_REMOTE
      end
    end

    context "after receiving a PRIORITY frame" do
      pending "transitions to the RESERVED_REMOTE state" do
      end
    end
  end

  context "in the RESERVED_LOCAL state" do
  end

  context "in the RESERVED_REMOTE state" do
  end

  context "in the OPEN state" do
  end

  context "in the HALF_CLOSED_LOCAL state" do
  end

  context "in the HALF_CLOSED_REMOTE state" do
  end

  context "in the CLOSED state" do
  end
end
