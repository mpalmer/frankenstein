require 'logger'

module Frankenstein
  class Server
    # Wrap a logger in behaviour that suits WEBrick's ideosyncratic style
    #
    # There are a few things in the way that WEBrick interacts with the standard
    # Logger class which don't suit modern logging practices:
    #
    # * It doesn't set a `progname` when logging, which makes it much harder to
    #   separate out WEBrick logs from other parts of your system.
    # * Logging calls use the direct-pass approach to passing in strings, which
    #   degrades performance.
    # * Access logging doesn't log with a priority, making it impossible to
    #   selectively log or not log access logs.
    # * Access logging doesn't respect the logger formatting, making it much harder
    #   to parse logs than it should need to be.
    #
    # This class is an attempt to capture all that aberrant behaviour and redirect
    # it into more socially-acceptable forms:
    #
    # * All of the "priority" methods (`warn`, `debug`, etc) are wrapped to inject
    #   `progname`.
    # * Access logging (or, more precisely, all calls to `#<<`) are intercepted
    #   and logged via the standard (format-respecting) calls, with the specified priority.
    #
    # This will *hopefully* provide a more palatable WEBrick logging experience.
    #
    class WEBrickLogger
      # @param logger [Logger] the *actual* Logger you want to send all of the log
      #    messages to.
      # @param progname [#to_s] the `progname` you want to pass to all log messages
      #    that come through this wrapper.
      # @param access_log_priority [Fixnum] the priority at which to log access log messages.
      #    Any of the `Logger::*` priority constants will work Just Fine.
      #
      def initialize(logger:, progname: "WEBrick", access_log_priority: Logger::DEBUG)
        @logger, @progname, @priority = logger, progname, access_log_priority
      end

      %i{debug error fatal info warn}.each do |sev|
        define_method(sev) do |msg = nil, &blk|
          if msg && blk
            # This never happens in webrick now, but they might get the memo
            # one day
            @logger.__send__(sev, msg, &blk)
          elsif blk
            # I can't find any of these, either, but I live in hope
            @logger.__send__(sev, @progname, &blk)
          else
            @logger.__send__(sev, @progname) { msg }
          end
        end
      end

      # Proxy the severity query methods too, because WEBrick likes to check
      # those directly for... reasons.
      %i{debug? error? fatal? info? warn?}.each do |sevp|
        defined_method(sevp) do
          @logger.__send__(sevp)
        end
      end

      # Simulate the "append literal message" feature
      #
      # Nothing goes into *my* logs without having appropriate metadata attached,
      # so this just funnels these messages into the proper priority-based system.
      #
      def <<(msg)
        @logger.add(@priority, msg, @progname)
      end
    end
  end
end
