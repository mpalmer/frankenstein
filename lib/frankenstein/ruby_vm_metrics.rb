require 'frankenstein/collected_metric'

module Frankenstein
  # Allow registration of metrics for Ruby VM statistics.
  #
  module RubyVMMetrics
    # Register Ruby VM metrics.
    #
    # For every statistic provided by the Ruby VM under the module method
    # `RubyVM.stat`, a metric is registered named `ruby_vm_<stat>`, which
    # provides a dimensionless metric with the value of the statistic.
    #
    # @param registry [Prometheus::Client::Registry] specify the metrics
    #    registry in which to register the GC-related metrics.
    #
    def self.register(registry = Prometheus::Client.registry)
      RubyVM.stat.each do |k, v|
        Frankenstein::CollectedMetric.new(:"ruby_vm_#{k}", docstring: "Ruby VM parameter #{k}", registry: registry) do
          { {} => RubyVM.stat[k] }
        end
      end
    end
  end
end
