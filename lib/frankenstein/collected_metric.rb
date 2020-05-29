require 'prometheus/client'
require 'prometheus/client/metric'
require 'logger'

module Frankenstein
  # Populate metric data at scrape time
  #
  # The usual implementation of a Prometheus registry is to create and
  # register a suite of metrics at program initialization, and then instrument
  # the running code by setting/incrementing/decrementing the metrics and
  # their label sets as the program runs.
  #
  # Sometimes, however, your program itself doesn't actually interact with the
  # values that you want to return in your metrics, such as the counts of some
  # external resource.  You can hack around this by running something
  # periodically in a thread to poll the external resource and update the
  # value, but that's icky.
  #
  # Instead, this class provides you with a way to say, "whenever we're
  # scraped, run this block of code to generate the label sets and current
  # values, and return that as part of the scrape data".  This allows you to
  # do away with ugly polling threads, and instead just write a simple "gather
  # some data and return some numbers" block.
  #
  # The block to run is passed to the Frankenstein::CollectedMetric
  # constructor, and *must* return a hash, containing the labelsets and
  # associated numeric values you want to return for the scrape.  If your
  # block doesn't send back a hash, or raises an exception during execution,
  # no values will be returned for the metric, an error will be logged (if a
  # logger was specified), and the value of the
  # `<metric>_collection_errors_total` counter, labelled by the exception
  # `class`, will be incremented.
  #
  # @example Returning a database query
  #
  #    Frankenstein::CollectedMetric.new(:my_db_query, "The results of a DB query") do
  #      ActiveRecord::Base.connection.execute("SELECT name,class,value FROM some_table").each_with_object do |row, h|
  #        h[name: row['name'], class: row['class']] = row['value']
  #      end
  #    end
  #
  #
  # # Performance & Concurrency
  #
  # Bear in mind that the code that you specify for the collection action will
  # be run *on every scrape*; if you've got two Prometheus servers, with a
  # scrape interval of 30 seconds, you'll be running this code once every 15
  # seconds, forever.  Also, Prometheus scrapes have a default timeout of five
  # seconds.  So, whatever your collection code does, make it snappy and
  # low-overhead.
  #
  # On a related note, remember that scrapes can arrive in parallel, so your
  # collection code could potentially be running in parallel, too (depending
  # on your metrics server).  Thus, it must be thread-safe -- preferably, it
  # should avoid mutating shared state at all.
  #
  class CollectedMetric < Prometheus::Client::Metric
    # The type of the metric being collected.
    attr_reader :type

    # @param name [Symbol] the name of the metric to collect for.  This must
    #   follow all the normal rules for a Prometheus metric name, and should
    #   meet [the guidelines for metric naming](https://prometheus.io/docs/practices/naming/),
    #   unless you like being shunned at parties.
    #
    # @param docstring [#to_s] the descriptive help text for the metric.
    #
    # @param labels [Array<Symbol>] the labels which all time series for this
    #   metric must possess.
    #
    # @param type [Symbol] what type of metric you're returning.  It's uncommon
    #   to want anything other than `:gauge` here (the default), because
    #   when you're collecting external data it's unlikely you'll be able to
    #   trust that your external data source will behave like a proper
    #   counter (or histogram or summary), but if you want the flexibility,
    #   it's there for you.  If you do decide to try your hand at collecting
    #   a histogram or summary, bear in mind that the value that you need to
    #   return is not a number, or even a hash -- it's a Prometheus-internal
    #   class instance, and dealing with the intricacies of that is entirely
    #   up to you.
    #
    # @param logger [Logger] if you want to know what's going on inside your
    #   metric, you can pass a logger and see what's going on.  Otherwise,
    #   you'll be blind if anything goes badly wrong.  Up to you.
    #
    # @param registry [Prometheus::Client::Registry] the registry in which
    #   this metric will reside.  The `<metric>_collection_errors_total`
    #   metric will also be registered here, so you'll know if a collection
    #   fails.
    #
    # @param collector [Proc] the code to run on every scrape request.
    #
    def initialize(name, docstring:, labels: [], type: :gauge, logger: Logger.new('/dev/null'), registry: Prometheus::Client.registry, &collector)
      @validator = Prometheus::Client::LabelSetValidator.new(expected_labels: labels)

      validate_name(name)
      validate_docstring(docstring)

      @name = name
      @docstring = docstring
      @base_labels = {}

      validate_type(type)

      @type      = type
      @logger    = logger
      @registry  = registry
      @collector = collector

      @errors_metric = @registry.counter(:"#{@name}_collection_errors_total", docstring: "Errors encountered while collecting for #{@name}")
      @registry.register(self)
    end

    # Retrieve the value for the given labelset.
    #
    def get(labels = {})
      @validator.validate_labelset!(labels)

      values[labels]
    end

    # Retrieve a complete set of labels and values for the metric.
    #
    def values
      begin
        @collector.call(self).tap do |results|
          unless results.is_a?(Hash)
            @logger.error(progname) { "Collector proc did not return a hash, got #{results.inspect}" }
            @errors_metric.increment(class: "NotAHashError")
            return {}
          end
          results.keys.each { |labelset| @validator.validate_labelset!(labelset) }
        end
      rescue StandardError => ex
        @logger.error(progname) { (["Exception in collection: #{ex.message} (#{ex.class})"] + ex.backtrace).join("\n  ") }
        @errors_metric.increment(class: ex.class.to_s)

        {}
      end
    end

    private

    # Make sure that the type we were passed is one Prometheus is known to accept.
    #
    def validate_type(type)
      unless %i{gauge counter histogram summary}.include?(type)
        raise ArgumentError, "type must be one of :gauge, :counter, :histogram, or :summary (got #{type.inspect})"
      end
    end

    # Generate the logger progname.
    #
    def progname
      @progname ||= "Frankenstein::CollectedMetric(#{@name})".freeze
    end
  end
end
