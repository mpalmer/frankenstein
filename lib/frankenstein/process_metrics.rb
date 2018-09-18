require 'frankenstein/collected_metric'
require 'etc'

module Frankenstein
  # Allow registration of metrics for Ruby GC statistics.
  #
  module ProcessMetrics
    # Register generic process metrics.
    #
    # Generates collected metric objects for all of the [recommended process
    # metrics](https://prometheus.io/docs/instrumenting/writing_clientlibs/#process-metrics)
    # that can be reasonably obtained using Ruby on the platform that the process
    # is running on.
    #
    # @param registry [Prometheus::Client::Registry] specify the metrics
    #    registry in which to register the GC-related metrics.
    #
    # @param logger [Logger] where to log any problems which some sort of
    #
    def self.register(registry = Prometheus::Client.registry, logger: Logger.new("/dev/null"))
      registry.gauge(:process_start_time_seconds, "Start time of the process since unix epoch in seconds").set({}, Time.now.to_f)

      page_size = Etc.sysconf(Etc::SC_PAGESIZE)
      hz        = Etc.sysconf(Etc::SC_CLK_TCK)

      stat_file = "/proc/#{Process.pid}/stat".freeze

      if File.exist?(stat_file)
        Frankenstein::CollectedMetric.new(:process_cpu_seconds_total, "Total user and system CPU time spent in seconds", registry: registry, logger: logger) do
          stats = File.open(stat_file).read.split(" ")
          { { mode: "user" } => stats[13].to_f / hz, { mode: "system" } => stats[14].to_f / hz }
        end

        Frankenstein::CollectedMetric.new(:process_virtual_memory_bytes, "Virtual memory size in bytes", registry: registry, logger: logger) do
          stats = File.open(stat_file).read.split(" ")
          { {} => stats[22].to_i }
        end

        Frankenstein::CollectedMetric.new(:process_resident_memory_bytes, "Resident memory size in bytes", registry: registry, logger: logger) do
          stats = File.open(stat_file).read.split(" ")
          { {} => stats[23].to_i * page_size }
        end
      end

      fd_dir = "/proc/#{Process.pid}/fd".freeze

      if File.exist?(fd_dir)
        Frankenstein::CollectedMetric.new(:process_open_fds, "Number of open file descriptors", registry: registry, logger: logger) do
          { {} => Dir["#{fd_dir}/*"].length }
        end
      end

      if Process.respond_to?(:getrlimit)
        Frankenstein::CollectedMetric.new(:process_max_fds, "Maximum number of open file descriptors", registry: registry, logger: logger) do
          { {} => Process.getrlimit(:NOFILE).first }
        end

        Frankenstein::CollectedMetric.new(:process_virtual_memory_max_bytes, "Maximum amount of virtual memory available in bytes", registry: registry, logger: logger) do
          { {} => Process.getrlimit(:AS).first }
        end
      end

      if GC.respond_to?(:stat) && GC.stat[:heap_allocated_pages]
        Frankenstein::CollectedMetric.new(:process_heap_bytes, "Process heap size in bytes", registry: registry, logger: logger) do
          { {} => GC.stat[:heap_allocated_pages] * page_size }
        end
      end
    end
  end
end
