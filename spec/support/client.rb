# encoding: utf-8
require "socket"
require "ipaddr"

module LogStash::Inputs::Test

  class UDPClient
    attr_reader :host, :port, :socket

    def initialize(port, host = "0.0.0.0")
      @host = host
      @port = port
      if IPAddr.new(@host).ipv6?
        @socket = UDPSocket.new(Socket::AF_INET6)
      elsif IPAddr.new(@host).ipv4?
        @socket = UDPSocket.new(Socket::AF_INET)
      end
      @socket.connect(host, port)
    end

    def send(msg)
      begin
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
