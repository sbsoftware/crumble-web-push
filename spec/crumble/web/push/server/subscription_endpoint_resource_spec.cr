require "../../../../spec_helper"
require "../../../../../lib/crumble/spec/test_request_context"

private class ResourceSpecSubscriptionAdapter < Crumble::Web::Push::Server::SubscriptionAdapter
  @subscriptions = [] of Crumble::Web::Push::Server::Subscription

  def save(subscription : Crumble::Web::Push::Server::Subscription) : Nil
    @subscriptions.reject! { |entry| entry.user_id == subscription.user_id && entry.device_id == subscription.device_id }
    @subscriptions << subscription
  end

  def delete(user_id : String, device_id : String) : Bool
    size_before_delete = @subscriptions.size
    @subscriptions.reject! { |entry| entry.user_id == user_id && entry.device_id == device_id }
    @subscriptions.size < size_before_delete
  end

  def list_by_user(user_id : String) : Array(Crumble::Web::Push::Server::Subscription)
    @subscriptions.select { |entry| entry.user_id == user_id }
  end

  def list_by_device(device_id : String) : Array(Crumble::Web::Push::Server::Subscription)
    @subscriptions.select { |entry| entry.device_id == device_id }
  end
end

describe Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource do
  after_each do
    Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource.reset!
  end

  it "saves a configured user's browser subscription on subscribe" do
    adapter = ResourceSpecSubscriptionAdapter.new
    Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource.configure(adapter) { |_ctx| Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource::RequestIdentity.new(user_id: "user-1", device_id: "device-1") }

    body = %({"action":"subscribe","subscription":{"endpoint":"https://push.example/1","keys":{"auth":"auth-1","p256dh":"p256dh-1"}}})
    response = String.build do |io|
      ctx = Crumble::Server::TestRequestContext.new(response_io: io, resource: Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource.uri_path, method: "POST", body: body)
      Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource.handle(ctx)
      ctx.response.flush
      ctx.response.status_code.should eq(204)
    end

    response.should eq("")
    adapter.list_by_user("user-1").should eq([Crumble::Web::Push::Server::Subscription.new(user_id: "user-1", device_id: "device-1", web_push_subscription: WebPush::Subscription.new(endpoint: "https://push.example/1", auth: "auth-1", p256dh: "p256dh-1"))])
  end

  it "deletes a configured user's browser subscription on unsubscribe" do
    adapter = ResourceSpecSubscriptionAdapter.new
    adapter.save(Crumble::Web::Push::Server::Subscription.new(user_id: "user-2", device_id: "device-2", web_push_subscription: WebPush::Subscription.new(endpoint: "https://push.example/2", auth: "auth-2", p256dh: "p256dh-2")))
    Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource.configure(adapter) { |_ctx| Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource::RequestIdentity.new(user_id: "user-2", device_id: "device-2") }

    body = %({"action":"unsubscribe","subscription":{"endpoint":"https://push.example/2","keys":{"auth":"auth-2","p256dh":"p256dh-2"}}})
    String.build do |io|
      ctx = Crumble::Server::TestRequestContext.new(response_io: io, resource: Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource.uri_path, method: "POST", body: body)
      Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource.handle(ctx)
      ctx.response.flush
      ctx.response.status_code.should eq(204)
    end

    adapter.list_by_user("user-2").should be_empty
  end
end
