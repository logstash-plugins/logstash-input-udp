# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require 'logstash/inputs/udp'

# expose the udp socket so that we can assert, during
# a spec, that it is open and we can start sending data
class LogStash::Inputs::Udp
  attr_reader :udp
end

class UdpHelpers

  def input(plugin, size, &block)
    queue = Queue.new
    input_thread = Thread.new do
      plugin.run(queue)
    end
    # because the udp socket is created and bound during #run
    # we must ensure that it is open before sending data
    sleep 0.1 until (plugin.udp && !plugin.udp.closed?)
    block.call
    sleep 0.1 while queue.size != size
    result = size.times.inject([]) do |acc|
      acc << queue.pop
    end
    plugin.do_stop
    result
  end

end
