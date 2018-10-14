require_relative './spec_helper'
require 'frankenstein/ruby_vm_metrics'

require 'prometheus/client/registry'

describe Frankenstein::RubyVMMetrics do
  let(:mock_registry) { double(Prometheus::Client::Registry) }
  let(:mock_logger) { double(Logger).tap { |l| allow(l).to receive(:debug) } }
  let(:vm_stats) { RubyVM.stat }

  before :each do
    allow(RubyVM).to receive(:stat).and_return(vm_stats)
    # For registering the error counters
    allow(mock_registry).to receive(:counter)
  end

  describe ".register" do
    context "with basic test metrics" do
      let(:vm_stats) do
        {
          global_method_state: 42,
          class_serial:        12345,
        }
      end

      it "registers metrics with the registry" do
        expect(mock_registry).to receive(:register) do |metric|
          expect(metric.name).to eq(:ruby_vm_global_method_state)
          expect(metric.type).to eq(:gauge)
          expect(metric.values).to eq({} => 42)
        end
        expect(mock_registry).to receive(:register) do |metric|
          expect(metric.name).to eq(:ruby_vm_class_serial)
          expect(metric.type).to eq(:gauge)
          expect(metric.values).to eq({} => 12345)
        end

        Frankenstein::RubyVMMetrics.register(mock_registry)
      end
    end
  end
end
