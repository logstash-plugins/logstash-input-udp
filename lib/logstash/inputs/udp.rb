# encoding: utf-8
require "date"
require "logstash/inputs/base"
require "logstash/namespace"
require "socket"
require "stud/interval"
require "ipaddr"

# Read messages as events over the network via udp. The only required
# configuration item is `port`, which specifies the udp port logstash
# will listen on for event streams.
#
class LogStash::Inputs::Udp < LogStash::Inputs::Base
  config_name "udp"

  default :codec, "plain"

  # The address which logstash will listen on.
  config :host, :validate => :string, :default => "0.0.0.0"

  # The port which logstash will listen on. Remember that ports less
  # than 1024 (privileged ports) may require root or elevated privileges to use.
  config :port, :validate => :number, :required => true

  # The maximum packet size to read from the network
  config :buffer_size, :validate => :number, :default => 65536

  # The socket receive buffer size in bytes.
  # If option is not set, the operating system default is used.
  # The operating system will use the max allowed value if receive_buffer_bytes is larger than allowed.
  # Consult your operating system documentation if you need to increase this max allowed value.
  config :receive_buffer_bytes, :validate => :number

  # Number of threads processing packets
  config :workers, :validate => :number, :default => 2

  # This is the number of unprocessed UDP packets you can hold in memory
  # before packets will start dropping.
  config :queue_size, :validate => :number, :default => 2000

  HOST_FIELD = "host".freeze

  def initialize(params)
    super
    BasicSocket.do_not_reverse_lookup = true
  end

  def register
    @udp = nil
    @metric_errors = metric.namespace(:errors)
  end # def register

  def run(output_queue)
    @output_queue = output_queue

    begin
      # udp server
      udp_listener(output_queue)
    rescue => e
      @logger.warn("UDP listener died", :exception => e, :backtrace => e.backtrace)
      @metric_errors.increment(:listener)
      Stud.stoppable_sleep(5) { stop? }
      retry unless stop?
    end
  end

  def close
    if @udp && !@udp.isClosed
      @udp.close()
    end
  end

  def stop
    if @udp && !@udp.isClosed
      @udp.close()
    end
  end

  private

  def udp_listener(output_queue)
    @logger.info("Starting UDP listener", :address => "#{@host}:#{@port}")

    if @udp && !@udp.isClosed
      @udp.close
    end

    # Bind to nil to defer binding until later
    @udp = java.net.DatagramSocket.new(nil)

    # set socket receive buffer size if configured
    if @receive_buffer_bytes
      @udp.setReceiveBufferSize(@receive_buffer_bytes)

      actual_receive_buffer_bytes = @udp.getReceiveBufferBytes
      if  actual_receive_buffer_bytes != @receive_buffer_bytes
        @logger.warn("Unable to set receive_buffer_bytes to desired size. Requested #{@receive_buffer_bytes} but obtained #{actual_receive_buffer_bytes} bytes.")
      end
    end
    
    @udp.bind(java.net.InetSocketAddress.new(@host, @port))

    @udp.setSoTimeout(10) # only block for 10ms per read

    @logger.info("UDP listener started", :address => "#{@host}:#{@port}", :receive_buffer_bytes => "#{@receive_buffer_bytes}", :queue_size => "#{@queue_size}")

    @input_to_worker = SizedQueue.new(@queue_size)
    metric.gauge(:queue_size, @queue_size)
    metric.gauge(:workers, @workers)

    @input_workers = @workers.times do |i|
      @logger.debug("Starting UDP worker thread", :worker => i)
      Thread.new(i, @codec.clone) { |i, codec| inputworker(i, codec) }
    end

    packet_buf = @buffer_size.times.map { 0 }.to_java :byte
    packet = java.net.DatagramPacket.new(packet_buf, packet_buf.length, java.net.InetAddress.getByName(@host), @port)
    while !stop?
      100.times do # No need to check the stop? 
        begin
          @udp.receive(packet)
        rescue java.net.SocketTimeoutException
          next
        end

        # Create a ruby string of the correct size
        packet_str = packet.getData[0...packet.getLength].to_s
        @input_to_worker.push([packet_str, packet.getAddress])
      end
    end
  ensure
    if @udp && !@udp.isClosed
      @udp.close
    end
  end

  def inputworker(number, codec)
    LogStash::Util::set_thread_name("<udp.#{number}")

    begin
      while true
        payload, host = @input_to_worker.pop

        codec.decode(payload) { |event| push_decoded_event(host, event) }
        codec.flush { |event| push_decoded_event(host, event) }
      end
    rescue => e
      @logger.error("Exception in inputworker", "exception" => e, "backtrace" => e.backtrace)
      @metric_errors.increment(:worker)
    end
  end

  def push_decoded_event(host, event)
    decorate(event)
    event.set(HOST_FIELD, host) if event.get(HOST_FIELD).nil?
    @output_queue.push(event)
    metric.increment(:events)
  end

  def ignore_close_and_log(e)
    @logger.debug("ignoring close exception", "exception" => e)
  end
end
