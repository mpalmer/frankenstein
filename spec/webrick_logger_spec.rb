require_relative './spec_helper'
require 'frankenstein/server/webrick_logger'
require 'rack/test'

describe Frankenstein::Server::WEBrickLogger do
  let(:mock_logger) { double(Logger) }
  let(:access_log_priority) { Logger::DEBUG }
  let(:webrick_logger) { Frankenstein::Server::WEBrickLogger.new(logger: mock_logger, progname: "SpecLogger", access_log_priority: access_log_priority) }

  %i{debug error fatal info warn}.each do |sev|
    describe "##{sev}" do
      before(:each) { allow(mock_logger).to receive(sev) }

      it "passes on string-literal log messages with default progname" do
        webrick_logger.__send__(sev, "This is a #{sev} log message")

        expect(mock_logger).to have_received(sev) do |progname, &blk|
          expect(progname).to eq("SpecLogger")
          expect(blk.call).to eq("This is a #{sev} log message")
        end
      end

      it "passes on block-passed log messages with default progname" do
        webrick_logger.__send__(sev) { "This is a #{sev} log message INNA BLOCK" }

        expect(mock_logger).to have_received(sev) do |progname, &blk|
          expect(progname).to eq("SpecLogger")
          expect(blk.call).to eq("This is a #{sev} log message INNA BLOCK")
        end
      end

      it "passes on full-service logging calls correctly" do
        webrick_logger.__send__(sev, "FullService") { "#{sev} me!" }

        expect(mock_logger).to have_received(sev) do |progname, &blk|
          expect(progname).to eq("FullService")
          expect(blk.call).to eq("#{sev} me!")
        end
      end
    end

    describe "##{sev}?" do
      it "delegates to the logger" do
        expect(mock_logger).to receive(:"#{sev}?")
        webrick_logger.__send__(:"#{sev}?")
      end
    end
  end

  describe "#<<" do
    context "with default access log priority" do
      it "logs at debug" do
        expect(mock_logger).to receive(:add).with(Logger::DEBUG, "access plz?", "SpecLogger")

        webrick_logger.<<("access plz?")
      end
    end

    context "with custom access log priority" do
      let(:access_log_priority) { Logger::WARN }

      it "logs at warn" do
        expect(mock_logger).to receive(:add).with(Logger::WARN, "access plz!", "SpecLogger")

        webrick_logger.<<("access plz!")
      end
    end
  end
end
