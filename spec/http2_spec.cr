require "./spec_helper"

describe HTTP2 do
  it "has a version number" do
    HTTP2::VERSION.should_not be_nil
  end
end
