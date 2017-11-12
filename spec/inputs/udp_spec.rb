# encoding: utf-8
require_relative "../spec_helper"
require_relative "../support/client"

describe LogStash::Inputs::Udp do

  before do
    srand(RSpec.configuration.seed)
  end

  let!(:helper) { UdpHelpers.new }
  let(:client) { LogStash::Inputs::Test::UDPClient.new(port) }
  let(:port) { rand(1024..65535) }
  let(:host) { "0.0.0.0" }
  let(:config) { { "port" => port, "host" => host } }
  subject { LogStash::Plugin.lookup("input","udp").new(config) }

  after :each do
    subject.close rescue nil
  end

  describe "register" do
    it "should register without errors" do
      expect { subject.register }.to_not raise_error
    end
  end

  describe "receive" do
  	shared_examples "receiving" do
      before(:each) do
        subject.register
      end

      let(:nevents) { 10 }

      let(:events) do
        helper.input(subject, nevents) do
          nevents.times do |i|
            client.send("msg #{i}")
          end
        end
      end

      it "should receive events been generated" do
        expect(events.size).to be(nevents)
        messages = events.map { |event| event.get("message")}
        messages.each do |message|
          expect(message).to match(/msg \d+/)
        end
      end
    end

    context "ipv4" do
      let(:client) { LogStash::Inputs::Test::UDPClient.new(port, "127.0.0.1") }
      include_examples "receiving"
    end
    context "ipv6" do
      let(:host) { "::1" }
      let(:client) { LogStash::Inputs::Test::UDPClient.new(port, "::1") }
      include_examples "receiving"
    end
  end

  describe "multiple lines per datagram using line codec" do
    # 3 workers for 3 datagrams send below
    let(:config) { { "port" => port, "workers" => 3, "codec" => "line" } }

    let(:events) do
      helper.input(subject, 8) do
        client.send("line1\nline2")
        client.send("line3\nline4")
        client.send("line5\nline6\nline7\nline8")
      end
    end

    before(:each) do
      subject.register
    end

    it "should receive events been generated" do
      expect(events.size).to be(8)
      messages = events.map { |event| event.get("message") }.sort # important to sort here because order is unpredictable
      messages.each_index {|i| expect(messages[i]).to match("line#{i + 1}")}
    end
  end

  it_behaves_like "an interruptible input plugin" do
    # see https://github.com/elastic/logstash-devutils/blob/9c4a1fbf2b0c4547e428c5a40ed84f60aad17f97/lib/logstash/devutils/rspec/shared_examples.rb
  end
end
