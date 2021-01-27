# encoding: utf-8
require_relative "../spec_helper"
require "logstash/devutils/rspec/shared_examples"
require_relative "../support/client"
require "logstash/codecs/base"


class LogStash::Codecs::Crash < LogStash::Codecs::Base
  config_name "crash"

  def decode(data)
    raise("decode crash") if data == "crash"
    yield LogStash::Event.new({"message" => data })
  end
end

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

  shared_examples "use hostname field with ECS" do |ecs_compatibility, field_name|
    let(:config) { { "port" => port, "workers" => 1, "ecs_compatibility" => ecs_compatibility} }
    let(:localhost) { "127.0.0.1" }
    let(:client) { LogStash::Inputs::Test::UDPClient.new(port, localhost) }

    let(:events) do
      helper.input(subject, 1) do
        client.send("line1")
      end
    end

    before(:each) do
      subject.register
    end

    it "should receive event with source_ip_fieldname as '#{field_name}' when ecs #{ecs_compatibility}" do
      expect(events.size).to be(1)
      message = events.last
      expect(message.get(field_name)).to eq(client.host)
    end
  end

  it_behaves_like "use hostname field with ECS", :disabled, "host"
  it_behaves_like "use hostname field with ECS", :v1, "[host][ip]"



  describe "uses custom hostname field when ECS is enabled" do
    let(:config) { { "port" => port, "workers" => 1, "ecs_compatibility" => :v1, "source_ip_fieldname" => "custom_host_field"} }
    let(:localhost) { "127.0.0.1" }
    let(:client) { LogStash::Inputs::Test::UDPClient.new(port, localhost) }

    let(:events) do
      helper.input(subject, 1) do
        client.send("line1")
      end
    end

    before(:each) do
      subject.register
    end

    it "should receive event with user defined source_ip_fieldname" do
      expect(events.size).to be(1)
      message = events.last
      expect(message.get(config['source_ip_fieldname'])).to eq(client.host)
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

  describe "worker should ignore codec exception" do
    # see custom "crash" codec above which raises upon decoding the "crash" straing payload
    let(:config) { { "port" => port, "workers" => 1, "codec" => "crash" } }

    let(:events) do
      helper.input(subject, 3) do
        client.send("crash")
        client.send("foo")
        client.send("bar")
        client.send("crash")
        client.send("baz")
      end
    end

    before(:each) do
      subject.register
    end

    it "should receive events been generated" do
      expect(events.size).to be(3)
      expect(events[0].get("message")).to match("foo")
      expect(events[1].get("message")).to match("bar")
      expect(events[2].get("message")).to match("baz")
    end
  end
end
