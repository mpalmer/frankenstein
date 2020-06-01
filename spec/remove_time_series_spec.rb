require_relative './spec_helper'
require 'frankenstein/remove_time_series'

require 'prometheus/client/registry'

describe "Frankenstein::RemoveTimeSeries" do
  let(:registry) { Prometheus::Client::Registry.new }
  let(:metric) { registry.gauge(:rts, labels: %i{foo}, docstring: "RemoveTimeSeries") }

  before(:each) do
    metric.set(42, labels: { foo: "mystery" })
    metric.set(24, labels: { foo: "junk" })
  end

  describe "#remove" do
    it "removes the time series with the specified labels" do
      metric.remove(foo: "junk")

		expect(metric.values).to eq({ foo: "mystery" } => 42.0)
    end

    it "doesn't get upset with non-existent time series" do
      expect { metric.remove(foo: "booblee") }.to_not raise_error
    end
  end
end
