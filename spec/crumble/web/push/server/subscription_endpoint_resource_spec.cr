require "../../../../spec_helper"
require "../../../../../lib/crumble/spec/test_request_context"

describe Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource do
  after_each do
    Crumble::Web::Push::Server::Integration.reset!
  end

  it "accepts the advertised default endpoint through the resource matcher" do
    adapter = Crumble::Web::Push::Server::InMemorySubscriptionAdapter.new
    Crumble::Web::Push::Server::Integration.subscription_adapter = adapter

    body = %({"action":"subscribe","subscription":{"endpoint":"https://push.example/0","keys":{"auth":"auth-0","p256dh":"p256dh-0"}}})
    response = String.build do |io|
      ctx = Crumble::Server::TestRequestContext.new(response_io: io, resource: Crumble::Web::Push::Client::Integration::DEFAULT_SUBSCRIPTION_ENDPOINT, method: "POST", body: body)
      Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource.handle(ctx).should be_true
      ctx.response.flush
      ctx.response.status_code.should eq(204)
      adapter.get(ctx.session.id.to_s).should_not be_nil
    end

    response.should eq("")
  end

  it "saves the current session's browser subscription on subscribe" do
    adapter = Crumble::Web::Push::Server::InMemorySubscriptionAdapter.new
    Crumble::Web::Push::Server::Integration.subscription_adapter = adapter

    body = %({"action":"subscribe","subscription":{"endpoint":"https://push.example/1","keys":{"auth":"auth-1","p256dh":"p256dh-1"}}})
    response = String.build do |io|
      ctx = Crumble::Server::TestRequestContext.new(response_io: io, resource: Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource.uri_path, method: "POST", body: body)
      session_id = ctx.session.id.to_s
      Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource.handle(ctx)
      ctx.response.flush
      ctx.response.status_code.should eq(204)
      adapter.get(session_id).should eq(Crumble::Web::Push::Server::Subscription.new(session_id: session_id, web_push_subscription: WebPush::Subscription.new(endpoint: "https://push.example/1", auth: "auth-1", p256dh: "p256dh-1")))
    end

    response.should eq("")
  end

  it "deletes the current session's browser subscription on unsubscribe" do
    adapter = Crumble::Web::Push::Server::InMemorySubscriptionAdapter.new
    Crumble::Web::Push::Server::Integration.subscription_adapter = adapter

    body = %({"action":"unsubscribe","subscription":{"endpoint":"https://push.example/2","keys":{"auth":"auth-2","p256dh":"p256dh-2"}}})
    String.build do |io|
      ctx = Crumble::Server::TestRequestContext.new(response_io: io, resource: Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource.uri_path, method: "POST", body: body)
      session_id = ctx.session.id.to_s
      adapter.save(Crumble::Web::Push::Server::Subscription.new(session_id: session_id, web_push_subscription: WebPush::Subscription.new(endpoint: "https://push.example/2", auth: "auth-2", p256dh: "p256dh-2")))
      Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource.handle(ctx)
      ctx.response.flush
      ctx.response.status_code.should eq(204)
      adapter.get(session_id).should be_nil
    end
  end

  it "returns validation errors for invalid payloads at the advertised endpoint" do
    response = String.build do |io|
      ctx = Crumble::Server::TestRequestContext.new(response_io: io, resource: Crumble::Web::Push::Client::Integration::DEFAULT_SUBSCRIPTION_ENDPOINT, method: "POST", body: %({"action":"subscribe"}))
      Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource.handle(ctx).should be_true
      ctx.response.flush
      ctx.response.status_code.should eq(422)
    end

    response.should contain("errors")
  end

  it "returns an error when no subscription adapter is configured at the advertised endpoint" do
    body = %({"action":"subscribe","subscription":{"endpoint":"https://push.example/3","keys":{"auth":"auth-3","p256dh":"p256dh-3"}}})
    response = String.build do |io|
      ctx = Crumble::Server::TestRequestContext.new(response_io: io, resource: Crumble::Web::Push::Client::Integration::DEFAULT_SUBSCRIPTION_ENDPOINT, method: "POST", body: body)
      Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource.handle(ctx).should be_true
      ctx.response.flush
      ctx.response.status_code.should eq(500)
    end

    response.should contain("Push subscription adapter is not configured")
  end
end
