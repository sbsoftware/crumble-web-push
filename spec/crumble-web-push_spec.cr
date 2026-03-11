require "./spec_helper"

describe Crumble::Web::Push do
  it "exposes the shard version" do
    Crumble::Web::Push::VERSION.should eq("0.1.0")
  end

  it "loads required dependency namespaces" do
    Crumble::Resource.name.should eq("Crumble::Resource")
    Stimulus::Controller.name.should eq("Stimulus::Controller")
    Web::Push.name.should eq("Web::Push")
  end

  it "provides client and server integration placeholders" do
    Crumble::Web::Push::Client::Integration.name.should eq("Crumble::Web::Push::Client::Integration")
    Crumble::Web::Push::Server::Integration.name.should eq("Crumble::Web::Push::Server::Integration")
  end
end
