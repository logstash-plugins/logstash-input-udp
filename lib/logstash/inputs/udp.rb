# encoding: utf-8
require "date"
require "logstash/inputs/base"
require "logstash/namespace"
require "socket"
require "stud/interval"

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
  end

  def run(output_queue)
    @output_queue = output_queue

    begin
      # udp server
      udp_listener(output_queue)
    rescue => e
      @logger.warn("UDP listener died", :exception => e, :backtrace => e.backtrace)
      Stud.stoppable_sleep(5) { stop? }
      retry unless stop?
    end
  end

  def close
    if @udp && !@udp.closed?
      @udp.close rescue ignore_close_and_log($!)
    end
  end

  def stop
    if @udp && !@udp.closed?
      @udp.close rescue ignore_close_and_log($!)
    end
  end

  private

  def udp_listener(output_queue)
    @logger.info("Starting UDP listener", :address => "#{@host}:#{@port}")

    if @udp && !@udp.closed?
      @udp.close
    end

    @udp = UDPSocket.new(Socket::AF_INET)
    # set socket receive buffer size if configured
    if @receive_buffer_bytes
      @udp.setsockopt(Socket::SOL_SOCKET, Socket::SO_RCVBUF, @receive_buffer_bytes)
    end
    rcvbuf = @udp.getsockopt(Socket::SOL_SOCKET, Socket::SO_RCVBUF).unpack("i")[0]
    if @receive_buffer_bytes && rcvbuf != @receive_buffer_bytes
      @logger.warn("Unable to set receive_buffer_bytes to desired size. Requested #{@receive_buffer_bytes} but obtained #{rcvbuf} bytes.")
    end

    @udp.bind(@host, @port)
    @logger.info("UDP listener started", :address => "#{@host}:#{@port}", :receive_buffer_bytes => "#{rcvbuf}", :queue_size => "#{@queue_size}")

    @input_to_worker = SizedQueue.new(@queue_size)

    @input_workers = @workers.times do |i|
      @logger.debug("Starting UDP worker thread", :worker => i)
      Thread.new(i, @codec.clone) { |i, codec| inputworker(i, codec) }
    end

    while !stop?
      next if IO.select([@udp], [], [], 0.5).nil?
      # collect datagram messages and add to inputworker queue
      @queue_size.times do
        begin
          payload, client = @udp.recvfrom_nonblock(@buffer_size)
          break if payload.empty?
          @input_to_worker.push([payload, client])
        rescue IO::EAGAINWaitReadable
          break
        end
      end
    end
  ensure
    if @udp
      @udp.close_read rescue ignore_close_and_log($!)
      @udp.close_write rescue ignore_close_and_log($!)
    end
  end

  def inputworker(number, codec)
    LogStash::Util::set_thread_name("<udp.#{number}")

    begin
      while true
        payload, client = @input_to_worker.pop
        host = client[3]

        codec.decode(payload) { |event| push_decoded_event(host, event) }
        codec.flush { |event| push_decoded_event(host, event) }
      end
    rescue => e
      @logger.error("Exception in inputworker", "exception" => e, "backtrace" => e.backtrace)
    end
  end

  def push_decoded_event(host, event)
    decorate(event)
    event.set(HOST_FIELD, host) if event.get(HOST_FIELD).nil?
    @output_queue.push(event)
  end

  def ignore_close_and_log(e)
    @logger.debug("ignoring close exception", "exception" => e)
  end
end
