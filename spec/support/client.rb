# encoding: utf-8
require "socket"

module LogStash::Inputs::Test

  class UDPClient

    attr_reader :host, :port, :socket

    def initialize(port)
      @port = port
      @host = "0.0.0.0"
      @socket = UDPSocket.new
      socket.connect(host, port)
    end

    def send(msg="")
      begin
        send(msg)
      rescue Exception => e
        puts "send.exception", e
        retry
      end
    end

    def send(msg)
      socket.connect(host, port) if socket.closed?
      socket.send(msg, 0)
    end

    def close
      socket.close
    end

  end

end
