require_relative './spec_helper'
require 'frankenstein/ruby_gc_metrics'

require 'prometheus/client/registry'

describe Frankenstein::RubyGCMetrics do
  let(:mock_registry) { double(Prometheus::Client::Registry) }
  let(:mock_logger) { double(Logger).tap { |l| allow(l).to receive(:debug) } }
  let(:gc_stats) { GC.stat }

  before :each do
    allow(GC).to receive(:stat).and_return(gc_stats)
    # For registering the error counters
    allow(mock_registry).to receive(:counter)
  end

  describe ".register" do
    context "with basic test metrics" do
      let(:gc_stats) do
        {
          count: 16,
          heap_allocated_pages: 42
        }
      end

      it "registers metrics with the registry" do
        expect(mock_registry).to receive(:register) do |metric|
          expect(metric.name).to eq(:ruby_gc_count)
          expect(metric.type).to eq(:gauge)
          expect(metric.values).to eq({} => 16)
        end
        expect(mock_registry).to receive(:register) do |metric|
          expect(metric.name).to eq(:ruby_gc_heap_allocated_pages)
          expect(metric.type).to eq(:gauge)
          expect(metric.values).to eq({} => 42)
        end

        Frankenstein::RubyGCMetrics.register(mock_registry)
      end
    end
  end
end
