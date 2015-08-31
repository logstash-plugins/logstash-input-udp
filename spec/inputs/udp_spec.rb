# encoding: utf-8
require_relative "../spec_helper"
require_relative "../support/client"

describe LogStash::Inputs::Udp do

  before do
    srand(RSpec.configuration.seed)
  end

  let(:port)       { rand(1024..65535) }
  subject { LogStash::Plugin.lookup("input", "udp").new({ "port" => port }) }

  after :each do
    subject.close rescue nil
  end

  describe "register" do
    it "should register without errors" do
      expect { subject.register }.to_not raise_error
    end
  end

  describe "receive" do

    let(:client) { LogStash::Inputs::Test::UDPClient.new(port) }
    let(:nevents) { 10 }

    let(:events) do
      input(subject, nevents) do
        nevents.times do |i|
          client.send("msg #{i}")
        end
      end
    end

    before(:each) do
      subject.register
    end

    it "should receive events been generated" do
      expect(events.size).to be(nevents)
      messages = events.map { |event| event["message"]}
      messages.each do |message|
        expect(message).to match(/msg \d+/)
      end
    end

  end

  it_behaves_like "an interruptible input plugin" do
    let(:config) { { "port" => port } }
  end
end
