require 'logger'
require 'prometheus/client'
require 'prometheus/middleware/collector'
require 'prometheus/middleware/exporter'
require 'rack'
require 'rack/builder'
require 'rack/handler/webrick'
require 'rack/deflater'

require 'frankenstein/error'
require 'frankenstein/server/webrick_logger'

module Frankenstein
  # A straightforward Prometheus metrics server.
  #
  # When you're looking to instrument your application which isn't, itself, a
  # HTTP service, you need this class.  It spawns a WEBrick server on a port you
  # specify, and gives you a registry to put your metrics into.  That's pretty
  # much it.
  #
  # The simplest example possible:
  #
  #     stats_server = Frankenstein::Server.new
  #     stats_server.run   # We are now serving stats on port 8080!
  #     counter = stats_server.registry.counter(:seconds_count, "Number of seconds")
  #     # Give the counter something to count
  #     loop { sleep 1; counter.increment({}) }
  #
  # Now if you hit http://localhost:8080/metrics you should see a counter
  # gradually going up, along with stats about the Frankenstein HTTP server
  # itself.  Neato!
  #
  # You can change how the webserver logs, and the port it listens on, with options
  # to #new.  If for some reason you need to shut down the webserver manually, use
  # #shutdown.
  #
  class Server
    # Indicate that the server is already running
    class AlreadyRunningError < Frankenstein::Error; end

    # The instance of Prometheus::Client::Registry that contains the metrics
    # that will be presented by this instance of Frankenstein::Server.
    attr_reader :registry

    # Create a new server instance.
    #
    # @param port [Integer] the TCP to listen on.
    #
    # @param logger [Logger] send log messages from WEBrick to this logger.
    #   If not specified, all log messages will be silently eaten.
    #
    # @param metrics_prefix [#to_s] The prefix to apply to the metrics exposed
    #   instrumenting the metrics server itself.
    #
    # @param registry [Prometheus::Client::Registry] if you want to use an existing
    #   metrics registry for this server, pass it in here.  Otherwise, a new one
    #   will be created for you, and be made available via #registry.
    #
    def initialize(port: 8080, logger: nil, metrics_prefix: "frankenstein_server", registry: Prometheus::Client::Registry.new)
      @port           = port
      @logger         = logger || Logger.new(RbConfig::CONFIG['host_os'] =~ /mingw|mswin/ ? 'NUL' : '/dev/null')
      @metrics_prefix = metrics_prefix
      @registry       = registry

      @op_mutex = Mutex.new
      @op_cv    = ConditionVariable.new
    end

    # Start the server instance running in a separate thread.
    #
    # This method returns once the server is just about ready to start serving
    # requests.
    #
    def run
      @op_mutex.synchronize do
        return AlreadyRunningError if @server

        @server_thread = Thread.new do
          @op_mutex.synchronize do
            begin
              wrapped_logger = Frankenstein::Server::WEBrickLogger.new(logger: @logger, progname: "Frankenstein::Server")
              @server = WEBrick::HTTPServer.new(Logger: wrapped_logger, BindAddress: nil, Port: @port, AccessLog: [[wrapped_logger, WEBrick::AccessLog::COMMON_LOG_FORMAT]])
              @server.mount "/", Rack::Handler::WEBrick, app
            rescue => ex
              #:nocov:
              @logger.fatal("Frankenstein::Server#run") { (["Exception while trying to create WEBrick::HTTPServer: #{ex.message} (#{ex.class})"] + ex.backtrace).join("\n  ") }
              #:nocov:
            ensure
              @op_cv.signal
            end
          end

          begin
            @server.start if @server
          rescue => ex
            #:nocov:
            @logger.fatal("Frankenstein::Server#run") { (["Exception while running WEBrick::HTTPServer: #{ex.message} (#{ex.class})"] + ex.backtrace).join("\n  ") }
            #:nocov:
          end
        end
      end

      @op_mutex.synchronize { @op_cv.wait(@op_mutex) until @server }
    end

    # Terminate a running server instance.
    #
    # If the server isn't currently running, this call is a no-op.
    #
    def shutdown
      @op_mutex.synchronize do
        return nil if @server.nil?
        @server.shutdown
        @server = nil
        @server_thread.join
        @server_thread = nil
      end
    end

    private

    def app
      @app ||= begin
        builder = Rack::Builder.new
        builder.use Rack::Deflater, if: ->(_, _, _, body) { body.any? && body[0].length > 512 }
        builder.use Prometheus::Middleware::Collector,
          registry: @registry,
          metrics_prefix: @metrics_prefix
        builder.use Prometheus::Middleware::Exporter, registry: @registry
        builder.run ->(_) { [301, { 'Location' => "/metrics", 'Content-Type' => 'text/plain' }, ["Try /metrics"]] }
        builder.to_app
      end
    end
  end
end
