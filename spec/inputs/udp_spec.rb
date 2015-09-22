# encoding: utf-8
require_relative "../spec_helper"
require_relative "../support/client"

describe LogStash::Inputs::Udp do

  let(:port)       { rand(1024..65535) }

  it "should register without errors" do
    plugin = LogStash::Plugin.lookup("input", "udp").new({ "port" => port })
    expect { plugin.register }.to_not raise_error
  end

  describe "receive" do

    let(:client) { LogStash::Inputs::Test::UDPClient.new(port) }
    subject      { LogStash::Inputs::Udp.new("port" => port ) }

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

    after(:each) do
      subject.close
    end

    it "should receive events been generated" do
      expect(events.size).to be(nevents)
      messages = events.map { |event| event["message"]}
      messages.each do |message|
        expect(message).to match(/msg \d+/)
      end
    end

  end

end
