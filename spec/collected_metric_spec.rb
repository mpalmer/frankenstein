require_relative './spec_helper'
require 'frankenstein/collected_metric'

require 'prometheus/client/registry'

describe Frankenstein::CollectedMetric do
  let(:mock_registry) { double(Prometheus::Client::Registry) }
  let(:mock_counter) { double(Prometheus::Client::Counter) }
  let(:mock_logger) { double(Logger).tap { |l| allow(l).to receive(:debug) } }
  let(:metric_name) { :test_metric }
  let(:metric_docstring) { "A test metric" }
  let(:collector_proc) { Proc.new { value_set } }
  let(:metric) { Frankenstein::CollectedMetric.new(metric_name, metric_docstring, logger: mock_logger, registry: mock_registry, &collector_proc) }

  before(:each) do
    allow(mock_registry).to receive(:register).with(instance_of(Frankenstein::CollectedMetric))
    allow(mock_registry).to receive(:counter).and_return(mock_counter)
  end

  describe "#new" do
    it "registers itself" do
      expect(mock_registry).to have_received(:register).with(metric)
    end

    it "registers an errors metric" do
      expect(mock_registry).to receive(:counter).with(:test_metric_collection_errors_total, instance_of(String))

      metric
    end

    it "explodes if you give an invalid type" do
      expect { Frankenstein::CollectedMetric.new(:bad_type, "Bad type", type: :lulz) }.to raise_error(ArgumentError)
    end
  end

  describe "#values" do
    context "when the collector returns an empty value set" do
      let(:value_set) { {} }

      it "returns an empty hash" do
        expect(metric.values).to eq({})
      end
    end

    context "when the collector returns a populated value set" do
      let(:value_set) do
        {
         { foo: "bar", baz: "wombat" } => 42,
         { foo: "something", baz: "funny" } => 21,
        }
      end

      it "returns the populated value set" do
        expect(metric.values).to eq(value_set)
      end
    end

    context "when the collector returns data with varying label names" do
      let(:value_set) do
        {
         { foo: "bar", baz: "wombat" } => 42,
         { lol: "cats" } => 180,
        }
      end

      before(:each) do
        allow(mock_logger).to receive(:error)
        allow(mock_counter).to receive(:increment)
      end

      it "logs an error" do
        expect(mock_logger).to receive(:error).with("Frankenstein::CollectedMetric(test_metric)")

        metric.values
      end

      it "increments the error counter" do
        expect(mock_counter).to receive(:increment).with(class: "Prometheus::Client::LabelSetValidator::InvalidLabelSetError")

        metric.values
      end

      it "returns an empty value set" do
        expect(metric.values).to eq({})
      end
    end

    context "when the collector returns mystery values" do
      let(:value_set) { "MYSTERY MEAT" }

      before(:each) do
        allow(mock_logger).to receive(:error)
        allow(mock_counter).to receive(:increment)
      end

      it "logs an error" do
        expect(mock_logger).to receive(:error).with("Frankenstein::CollectedMetric(test_metric)")

        metric.values
      end

      it "increments the error counter" do
        expect(mock_counter).to receive(:increment).with(class: "NotAHashError")

        metric.values
      end

      it "returns an empty value set" do
        expect(metric.values).to eq({})
      end
    end

    context "when the collector raises an exception" do
      let(:collector_proc) { Proc.new { raise Errno::ERANGE } }

      before(:each) do
        allow(mock_logger).to receive(:error)
        allow(mock_counter).to receive(:increment)
      end

      it "logs an error" do
        expect(mock_logger).to receive(:error).with("Frankenstein::CollectedMetric(test_metric)")

        metric.values
      end

      it "increments the error counter" do
        expect(mock_counter).to receive(:increment).with(class: "Errno::ERANGE")

        metric.values
      end

      it "returns an empty value set" do
        expect(metric.values).to eq({})
      end
    end
  end

  describe "#get" do
    context "with some values" do
      let(:value_set) do
        {
         { foo: "bar", baz: "wombat" } => 42,
         { foo: "something", baz: "funny" } => 21
        }
      end

      it "returns the value for an existent label set" do
        expect(metric.get(foo: "bar", baz: "wombat")).to eq(42)
      end

      it "returns nil for an unknown label set" do
        expect(metric.get(foo: "lol", baz: "cats")).to eq(nil)
      end

      it "raises an exception for different label names" do
        # Need to "prime the pump", as it were, so that the LabelSetValidator
        # knows what the "correct" labels are
        metric.values

        expect { metric.get(why: "not") }.to raise_error(Prometheus::Client::LabelSetValidator::InvalidLabelSetError)
      end
    end
  end
end
