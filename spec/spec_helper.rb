# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require 'logstash/inputs/udp'

module UdpHelpers

  def input(plugin, size, &block)
    queue = Queue.new
    input_thread = Thread.new do
      plugin.run(queue)
    end
    block.call
    sleep 0.1 while queue.size != size
    result = nevents.times.inject([]) do |acc|
      acc << queue.pop
    end
    plugin.stop
    result
  end

end

RSpec.configure do |c|
  c.include UdpHelpers
end
