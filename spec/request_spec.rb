require_relative './spec_helper'
require 'frankenstein/request'

describe Frankenstein::Request do
  let(:registry) { Prometheus::Client::Registry.new }
  let!(:request) { Frankenstein::Request.new("ohai", registry: registry, labels: labels, duration_labels: duration_labels) }
  let(:labels) { [] }
  let(:duration_labels) { nil }

  context "#new" do
    it "registers metrics" do
      expect(registry.get(:ohai_requests_total)).to be_a(Prometheus::Client::Counter)
      expect(registry.get(:ohai_exceptions_total)).to be_a(Prometheus::Client::Counter)
      expect(registry.get(:ohai_request_duration_seconds)).to be_a(Prometheus::Client::Histogram)
      expect(registry.get(:ohai_in_progress_count)).to be_a(Prometheus::Client::Gauge)
    end
  end

  context "#measure" do
    it "manages the in-progress count" do
      request.measure do
        expect(registry.get(:ohai_in_progress_count).get).to eq(1)
      end

      expect(registry.get(:ohai_in_progress_count).get).to eq(0)
    end

    it "doesn't like it if you don't pass a block" do
      expect { request.measure }.to raise_error(Frankenstein::Request::NoBlockError)
    end

    it "returns the last value of the block" do
      v = request.measure { 2 + 2; 4 + 4; "wombat" }
      expect(v).to eq("wombat")
    end

    it "re-raises any raised exception" do
      expect { request.measure { raise RuntimeError } }.to raise_error(RuntimeError)
    end

    it "decrements the in-progress count after an exception" do
      expect do
        request.measure do
          expect(registry.get(:ohai_in_progress_count).get).to eq(1)
          raise Errno::ENOENT
        end
      end.to raise_error(Errno::ENOENT)

      expect(registry.get(:ohai_in_progress_count).get).to eq(0)
    end

    context "with labels" do
      let(:labels) { [:foo] }

      it "applies provided labels to all the metrics" do
        request.measure(foo: "bar") do
          expect(registry.get(:ohai_in_progress_count).get(labels: { foo: "bar" })).to eq(1)
        end

        expect(registry.get(:ohai_in_progress_count).get(labels: { foo: "bar" })).to eq(0)
        expect(registry.get(:ohai_requests_total).get(labels: { foo: "bar" })).to eq(1)
        expect(registry.get(:ohai_request_duration_seconds).get(labels: { foo: "bar" })["+Inf"]).to eq(1)
      end

      it "applies provided labels to the exception metric" do
        expect do
          request.measure(foo: "bar") do
            raise ArgumentError
          end
        end.to raise_error(ArgumentError)

        expect(registry.get(:ohai_in_progress_count).get(labels: { foo: "bar" })).to eq(0)
        expect(registry.get(:ohai_requests_total).get(labels: { foo: "bar" })).to eq(1)
        expect(registry.get(:ohai_exceptions_total).get(labels: { foo: "bar", class: "ArgumentError" })).to eq(1)
        expect(registry.get(:ohai_request_duration_seconds).get(labels: { foo: "bar" })["+Inf"]).to eq(0)
      end

      context "on the response time metric, too" do
        let(:duration_labels) { [:foo, :baz] }

        it "allows additional labels on (only) the response metric" do
          request.measure(foo: "bar") do |labels|
            labels[:baz] = "wombat"
          end

          expect(registry.get(:ohai_in_progress_count).get(labels: { foo: "bar" })).to eq(0)
          expect(registry.get(:ohai_requests_total).get(labels: { foo: "bar" })).to eq(1)
          expect(registry.get(:ohai_request_duration_seconds).get(labels: { foo: "bar", baz: "wombat" })["+Inf"]).to eq(1)
        end

        it "allows label value override on (only) the response metric" do
          request.measure(foo: "bar") do |labels|
            labels[:foo] = "lolol"
				labels[:baz] = "wombat"
          end

          expect(registry.get(:ohai_in_progress_count).get(labels: { foo: "bar" })).to eq(0)
          expect(registry.get(:ohai_requests_total).get(labels: { foo: "bar" })).to eq(1)
          expect(registry.get(:ohai_request_duration_seconds).get(labels: { foo: "bar", baz: "wombat" })["+Inf"]).to eq(0)
          expect(registry.get(:ohai_request_duration_seconds).get(labels: { foo: "lolol", baz: "wombat" })["+Inf"]).to eq(1)
        end
      end
    end
  end
end
