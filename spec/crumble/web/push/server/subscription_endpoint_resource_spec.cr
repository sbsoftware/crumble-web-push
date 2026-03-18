require "../../../../spec_helper"
require "../../../../../lib/crumble/spec/test_request_context"

private class ResourceSpecSubscriptionAdapter < Crumble::Web::Push::Server::SubscriptionAdapter
  @subscriptions = [] of Crumble::Web::Push::Server::Subscription

  def save(subscription : Crumble::Web::Push::Server::Subscription) : Nil
    @subscriptions.reject! { |entry| entry.session_id == subscription.session_id }
    @subscriptions << subscription
  end

  def delete(session_id : String) : Bool
    size_before_delete = @subscriptions.size
    @subscriptions.reject! { |entry| entry.session_id == session_id }
    @subscriptions.size < size_before_delete
  end

  def list_by_session(session_id : String) : Array(Crumble::Web::Push::Server::Subscription)
    @subscriptions.select { |entry| entry.session_id == session_id }
  end
end

describe Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource do
  after_each do
    Crumble::Web::Push::Server::Integration.reset!
  end

  it "saves the current session's browser subscription on subscribe" do
    adapter = ResourceSpecSubscriptionAdapter.new
    Crumble::Web::Push::Server::Integration.subscription_adapter = adapter

    body = %({"action":"subscribe","subscription":{"endpoint":"https://push.example/1","keys":{"auth":"auth-1","p256dh":"p256dh-1"}}})
    response = String.build do |io|
      ctx = Crumble::Server::TestRequestContext.new(response_io: io, resource: Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource.uri_path, method: "POST", body: body)
      session_id = ctx.session.id.to_s
      Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource.handle(ctx)
      ctx.response.flush
      ctx.response.status_code.should eq(204)
      adapter.list_by_session(session_id).should eq([Crumble::Web::Push::Server::Subscription.new(session_id: session_id, web_push_subscription: WebPush::Subscription.new(endpoint: "https://push.example/1", auth: "auth-1", p256dh: "p256dh-1"))])
    end

    response.should eq("")
  end

  it "deletes the current session's browser subscription on unsubscribe" do
    adapter = ResourceSpecSubscriptionAdapter.new
    Crumble::Web::Push::Server::Integration.subscription_adapter = adapter

    body = %({"action":"unsubscribe","subscription":{"endpoint":"https://push.example/2","keys":{"auth":"auth-2","p256dh":"p256dh-2"}}})
    String.build do |io|
      ctx = Crumble::Server::TestRequestContext.new(response_io: io, resource: Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource.uri_path, method: "POST", body: body)
      session_id = ctx.session.id.to_s
      adapter.save(Crumble::Web::Push::Server::Subscription.new(session_id: session_id, web_push_subscription: WebPush::Subscription.new(endpoint: "https://push.example/2", auth: "auth-2", p256dh: "p256dh-2")))
      Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource.handle(ctx)
      ctx.response.flush
      ctx.response.status_code.should eq(204)
      adapter.list_by_session(session_id).should be_empty
    end
  end
end
