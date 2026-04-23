require "../../../../spec_helper"
require "../../../../../lib/crumble/spec/test_request_context"

describe Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource do
  after_each do
    Crumble::Web::Push::Server::Integration.reset!
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
end
