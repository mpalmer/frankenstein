require 'frankenstein/collected_metric'

module Frankenstein
  # Allow registration of metrics for Ruby GC statistics.
  #
  module RubyGCMetrics
    # Register Ruby GC metrics.
    #
    # For every statistic provided by the Ruby VM under the module method
    # `GC.stat`, a metric is registered named `ruby_gc_<stat>`, which
    # provides a dimensionless metric with the value of the statistic.
    #
    # @param registry [Prometheus::Client::Registry] specify the metrics
    #    registry in which to register the GC-related metrics.
    #
    def self.register(registry = Prometheus::Client.registry)
      GC.stat.each do |k, v|
        Frankenstein::CollectedMetric.new(:"ruby_gc_#{k}", docstring: "Ruby GC parameter #{k}", registry: registry) do
          { {} => GC.stat[k] }
        end
      end
    end
  end
end
