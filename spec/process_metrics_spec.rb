require_relative './spec_helper'
require 'frankenstein/process_metrics'

require 'prometheus/client/registry'

describe Frankenstein::ProcessMetrics do
  let(:registry) { Prometheus::Client::Registry.new }
  let(:mock_logger) { double(Logger).tap { |l| allow(l).to receive(:debug) } }
  # Ignored numeric values are 0; useful values are
  #
  # 42      -> utime (user-mode CPU time)
  # 314159  -> stime (kernel-mode CPU time)
  # 1048576 -> vsize (virtual memory in bytes)
  # 44      -> rss (number of pages in main memory)
  let(:proc_stat_data) { "12345 (spec) R 0 0 0 0 0 0 0 0 0 0 42 314159 0 0 0 0 0 0 0 1048576 44" }

  before(:each) do
    allow(File).to receive(:exist?).and_return(false)
    allow(Process).to receive(:pid).and_return(12345)

    # Hard-code these just to make sure we don't bust our tests when run on
    # a different sort of system
    allow(Etc).to receive(:sysconf).with(Etc::SC_PAGESIZE).and_return(4096)
    allow(Etc).to receive(:sysconf).with(Etc::SC_CLK_TCK).and_return(100)
  end

  describe "process_cpu_seconds_total metric" do
    let(:metric) { :process_cpu_seconds_total }

    before :each do
      allow(File).to receive(:exist?).with("/proc/12345/stat").and_return(true)
      allow(File).to receive(:open).with("/proc/12345/stat") { StringIO.new(proc_stat_data) }
    end

    it "gets registered" do
      Frankenstein::ProcessMetrics.register(registry, logger: mock_logger)

      expect(registry.get(metric)).to be_a(Frankenstein::CollectedMetric)
      expect(registry.get(metric).type).to eq(:gauge)
    end

    it "retrieves the CPU statistics" do
      Frankenstein::ProcessMetrics.register(registry, logger: mock_logger)

      expect(registry.get(metric).get(mode: "user")).to eq(0.42)
      expect(registry.get(metric).get(mode: "system")).to eq(3141.59)
    end

    it "doesn't get registered if the stats file doesn't exist" do
      allow(File).to receive(:exist?).with("/proc/12345/stat").and_return(false)

      Frankenstein::ProcessMetrics.register(registry, logger: mock_logger)

      expect(registry.get(metric)).to be_nil
    end
  end

  describe "process_open_fds metric" do
    let(:metric) { :process_open_fds }

    before :each do
      allow(File).to receive(:exist?).with("/proc/12345/fd").and_return(true)
      allow(Dir).to receive(:[]).with("/proc/12345/fd/*").and_return(["/proc/12345/fd/1", "proc/12345/fd/3"])
    end

    it "gets registered" do
      Frankenstein::ProcessMetrics.register(registry, logger: mock_logger)

      expect(registry.get(metric)).to be_a(Frankenstein::CollectedMetric)
      expect(registry.get(metric).type).to eq(:gauge)
    end

    it "retrieves the metric value" do
      Frankenstein::ProcessMetrics.register(registry, logger: mock_logger)

      expect(registry.get(metric).get).to eq(2)
    end

    it "doesn't get registered if the stats file doesn't exist" do
      allow(File).to receive(:exist?).with("/proc/12345/fd").and_return(false)

      Frankenstein::ProcessMetrics.register(registry, logger: mock_logger)

      expect(registry.get(metric)).to be_nil
    end
  end

  describe "process_max_fds metric" do
    let(:metric) { :process_max_fds }

    before :each do
      allow(Process).to receive(:respond_to?).with(:getrlimit).and_return(true)
      allow(Process).to receive(:getrlimit).with(:NOFILE).and_return([1536, 1_000_000])
    end

    it "gets registered" do
      Frankenstein::ProcessMetrics.register(registry, logger: mock_logger)

      expect(registry.get(metric)).to be_a(Frankenstein::CollectedMetric)
      expect(registry.get(metric).type).to eq(:gauge)
    end

    it "retrieves the metric value" do
      Frankenstein::ProcessMetrics.register(registry, logger: mock_logger)

      expect(registry.get(metric).get).to eq(1536)
    end

    it "doesn't get registered if getrlimit doesn't exist" do
      allow(Process).to receive(:respond_to?).with(:getrlimit).and_return(false)

      Frankenstein::ProcessMetrics.register(registry, logger: mock_logger)

      expect(registry.get(metric)).to be_nil
    end
  end

  describe "process_virtual_memory_bytes metric" do
    let(:metric) { :process_virtual_memory_bytes }

    before :each do
      allow(File).to receive(:exist?).with("/proc/12345/stat").and_return(true)
      allow(File).to receive(:open).with("/proc/12345/stat") { StringIO.new(proc_stat_data) }
    end

    it "gets registered" do
      Frankenstein::ProcessMetrics.register(registry, logger: mock_logger)

      expect(registry.get(metric)).to be_a(Frankenstein::CollectedMetric)
      expect(registry.get(metric).type).to eq(:gauge)
    end

    it "retrieves the metric value" do
      Frankenstein::ProcessMetrics.register(registry, logger: mock_logger)

      expect(registry.get(metric).get).to eq(1048576)
    end

    it "doesn't get registered if the stats file doesn't exist" do
      allow(File).to receive(:exist?).with("/proc/12345/stat").and_return(false)

      Frankenstein::ProcessMetrics.register(registry, logger: mock_logger)

      expect(registry.get(metric)).to be_nil
    end
  end

  describe "process_virtual_memory_max_bytes metric" do
    let(:metric) { :process_virtual_memory_max_bytes }

    before :each do
      allow(Process).to receive(:respond_to?).with(:getrlimit).and_return(true)
      allow(Process).to receive(:getrlimit).with(:AS).and_return([2_147_483_648, 1_000_000])
    end

    it "gets registered" do
      Frankenstein::ProcessMetrics.register(registry, logger: mock_logger)

      expect(registry.get(metric)).to be_a(Frankenstein::CollectedMetric)
      expect(registry.get(metric).type).to eq(:gauge)
    end

    it "retrieves the metric value" do
      Frankenstein::ProcessMetrics.register(registry, logger: mock_logger)

      expect(registry.get(metric).get).to eq(2_147_483_648)
    end

    it "doesn't get registered if getrlimit doesn't exist" do
      allow(Process).to receive(:respond_to?).with(:getrlimit).and_return(false)

      Frankenstein::ProcessMetrics.register(registry, logger: mock_logger)

      expect(registry.get(metric)).to be_nil
    end
  end

  describe "process_resident_memory_bytes metric" do
    let(:metric) { :process_resident_memory_bytes }

    before :each do
      allow(File).to receive(:exist?).with("/proc/12345/stat").and_return(true)
      allow(File).to receive(:open).with("/proc/12345/stat") { StringIO.new(proc_stat_data) }
    end

    it "gets registered" do
      Frankenstein::ProcessMetrics.register(registry, logger: mock_logger)

      expect(registry.get(metric)).to be_a(Frankenstein::CollectedMetric)
      expect(registry.get(metric).type).to eq(:gauge)
    end

    it "retrieves the metric value" do
      Frankenstein::ProcessMetrics.register(registry, logger: mock_logger)

      expect(registry.get(metric).get).to eq(44 * 4096)
    end

    it "doesn't get registered if the stats file doesn't exist" do
      allow(File).to receive(:exist?).with("/proc/12345/stat").and_return(false)

      Frankenstein::ProcessMetrics.register(registry, logger: mock_logger)

      expect(registry.get(metric)).to be_nil
    end
  end

  describe "process_heap_bytes metric" do
    let(:metric) { :process_heap_bytes }

    before :each do
      allow(GC).to receive(:stat).and_return(heap_allocated_pages: 16)
    end

    it "gets registered" do
      Frankenstein::ProcessMetrics.register(registry, logger: mock_logger)

      expect(registry.get(metric)).to be_a(Frankenstein::CollectedMetric)
      expect(registry.get(metric).type).to eq(:gauge)
    end

    it "retrieves the metric value" do
      Frankenstein::ProcessMetrics.register(registry, logger: mock_logger)

      expect(registry.get(metric).get).to eq(16 * 4096)
    end
  end

  describe "process_start_time_seconds metric" do
    let(:metric) { :process_start_time_seconds }

    it "retrieves the start time" do
      Frankenstein::ProcessMetrics.register(registry, logger: mock_logger)

      expect(registry.get(metric).get).to be_within(1).of(Time.now.to_f)
    end
  end
end
