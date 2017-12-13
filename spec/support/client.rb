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

    def send(msg)
      begin
        socket.connect(host, port) if socket.closed?
        socket.send(msg, 0)
      rescue  => e
        puts("send exception, retrying", e.inspect)
        retry
      end
    end

    def close
      socket.close unless socket.closed?
    end
  end
end
