require "./spec_helper"

describe Crumble::Web::Push do
  it "exposes the shard version" do
    Crumble::Web::Push::VERSION.should eq("0.1.0")
  end

  it "loads required dependency namespaces" do
    Crumble::Resource.name.should eq("Crumble::Resource")
    Stimulus::Controller.name.should eq("Stimulus::Controller")
    WebPush.name.should eq("WebPush")
  end

  it "provides client and server integration namespaces" do
    Crumble::Web::Push::Client::Integration.name.should eq("Crumble::Web::Push::Client::Integration")
    Crumble::Web::Push::Client::Integration::PushServiceWorkerConnector.name.should eq("Crumble::Web::Push::Client::Integration::PushServiceWorkerConnector")
    Crumble::Web::Push::Server::Integration.name.should eq("Crumble::Web::Push::Server::Integration")
    Crumble::Web::Push::Server::Integration::Sender.name.should eq("Crumble::Web::Push::Server::Integration::Sender")
    Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource.name.should eq("Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource")
  end

  it "exposes server subscription contracts and adapter interface" do
    Crumble::Web::Push::Server::SubscriptionAdapter.name.should eq("Crumble::Web::Push::Server::SubscriptionAdapter")
    Crumble::Web::Push::Server::SubscriptionContract.name.should eq("Crumble::Web::Push::Server::SubscriptionContract")
    Crumble::Web::Push::Server::Integration::SendOutcome.name.should eq("Crumble::Web::Push::Server::Integration::SendOutcome")
  end
end
