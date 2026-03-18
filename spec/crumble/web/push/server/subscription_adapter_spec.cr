require "../../../../spec_helper"

private class TestSubscriptionAdapter < Crumble::Web::Push::Server::SubscriptionAdapter
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

describe Crumble::Web::Push::Server::SubscriptionAdapter do
  it "supports save, list by session and delete" do
    adapter = TestSubscriptionAdapter.new
    first_subscription = Crumble::Web::Push::Server::Subscription.new(session_id: "session-1", web_push_subscription: WebPush::Subscription.new(endpoint: "https://push.example/1", auth: "auth-1", p256dh: "p256dh-1"))
    second_subscription = Crumble::Web::Push::Server::Subscription.new(session_id: "session-2", web_push_subscription: WebPush::Subscription.new(endpoint: "https://push.example/2", auth: "auth-2", p256dh: "p256dh-2"))
    third_subscription = Crumble::Web::Push::Server::Subscription.new(session_id: "session-3", web_push_subscription: WebPush::Subscription.new(endpoint: "https://push.example/3", auth: "auth-3", p256dh: "p256dh-3"))

    adapter.save(first_subscription)
    adapter.save(second_subscription)
    adapter.save(third_subscription)

    adapter.list_by_session("session-1").should eq([first_subscription])
    adapter.list_by_session("session-2").should eq([second_subscription])

    adapter.delete("session-2").should be_true
    adapter.delete("session-2").should be_false
    adapter.list_by_session("session-2").should be_empty
  end

  it "allows save to replace a subscription for the same session" do
    adapter = TestSubscriptionAdapter.new
    first_subscription = Crumble::Web::Push::Server::Subscription.new(session_id: "session-1", web_push_subscription: WebPush::Subscription.new(endpoint: "https://push.example/1", auth: "auth-1", p256dh: "p256dh-1"))
    updated_subscription = Crumble::Web::Push::Server::Subscription.new(session_id: "session-1", web_push_subscription: WebPush::Subscription.new(endpoint: "https://push.example/1-updated", auth: "auth-1-updated", p256dh: "p256dh-1-updated"))

    adapter.save(first_subscription)
    adapter.save(updated_subscription)

    adapter.list_by_session("session-1").should eq([updated_subscription])
  end
end
