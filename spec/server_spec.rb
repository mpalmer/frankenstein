require_relative './spec_helper'
require 'frankenstein/server'
require 'rack/test'

describe Frankenstein::Server do
  include Rack::Test::Methods

  let(:server) { Frankenstein::Server.new }
  let(:app)    { server.send(:app) }
  before { allow(Logger).to receive(:new).and_call_original }

  it "creates a Prometheus registry" do
    expect(server.registry).to be_a(Prometheus::Client::Registry)
  end

  it "creates a NULL logger" do
    l = server.instance_variable_get(:@logger)
    expect(l).to be_a(Logger)
    expect(Logger).to have_received(:new).with(RbConfig::CONFIG['host_os'] =~ /mingw|mswin/ ? 'NUL' : '/dev/null')
  end

  it "fires up webrick" do
    expect(WEBrick::HTTPServer).to receive(:new).with(Logger: instance_of(Frankenstein::Server::WEBrickLogger), BindAddress: nil, Port: 8080, AccessLog: instance_of(Array)).and_return(mock_server = double(WEBrick::HTTPServer))
    expect(mock_server).to receive(:mount).with("/", Rack::Handler::WEBrick, instance_of(Rack::Deflater))
    expect(mock_server).to receive(:start)
    expect(mock_server).to receive(:shutdown)

    server.run; server.shutdown
  end

  context "with a custom port" do
    let(:server) { Frankenstein::Server.new(port: 1337) }

    it "fires up webrick with a different port" do
      expect(WEBrick::HTTPServer).to receive(:new).with(Logger: instance_of(Frankenstein::Server::WEBrickLogger), BindAddress: nil, Port: 1337, AccessLog: instance_of(Array)).and_return(mock_server = double(WEBrick::HTTPServer))
      expect(mock_server).to receive(:mount).with("/", Rack::Handler::WEBrick, instance_of(Rack::Deflater))
      expect(mock_server).to receive(:start)
      expect(mock_server).to receive(:shutdown)

      server.run; server.shutdown
    end
  end

  context "with a custom logger" do
    let(:mock_logger) { double(Logger) }
    let(:server) { Frankenstein::Server.new(logger: mock_logger) }

    it "fires up webrick with a different logger" do
      expect(Frankenstein::Server::WEBrickLogger).to receive(:new).with(logger: mock_logger, progname: "Frankenstein::Server").and_return(mock_webrick_logger = double(Frankenstein::Server::WEBrickLogger))
      expect(WEBrick::HTTPServer).to receive(:new).with(Logger: mock_webrick_logger, BindAddress: nil, Port: 8080, AccessLog: instance_of(Array)).and_return(mock_server = double(WEBrick::HTTPServer))
      expect(mock_server).to receive(:mount).with("/", Rack::Handler::WEBrick, instance_of(Rack::Deflater))
      expect(mock_server).to receive(:start)
      expect(mock_server).to receive(:shutdown)

      server.run; server.shutdown
    end
  end

  it "records stats for requests to /metrics" do
    10.times { get "/metrics" }

    expect(server.registry.get(:frankenstein_server_requests_total).get).to eq(10)
  end
end
