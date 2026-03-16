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

  it "provides client and server integration namespaces" do
    Crumble::Web::Push::Client::Integration.name.should eq("Crumble::Web::Push::Client::Integration")
    Crumble::Web::Push::Client::Integration::PushServiceWorkerConnector.name.should eq("Crumble::Web::Push::Client::Integration::PushServiceWorkerConnector")
    Crumble::Web::Push::Server::Integration.name.should eq("Crumble::Web::Push::Server::Integration")
  end

  it "exposes server subscription contracts and adapter interface" do
    Crumble::Web::Push::Server::SubscriptionAdapter.name.should eq("Crumble::Web::Push::Server::SubscriptionAdapter")
    Crumble::Web::Push::Server::SubscriptionContract.name.should eq("Crumble::Web::Push::Server::SubscriptionContract")
  end
end
