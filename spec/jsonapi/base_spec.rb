require "spec_helper"

RSpec.describe Jsonapi::Base do
  it "has a version number" do
    expect(Jsonapi::Base::VERSION).not_to be nil
  end

  it "does something useful" do
    expect(false).to eq(true)
  end
end
