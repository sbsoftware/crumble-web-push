require "../../../../spec_helper"

private class TestSubscriptionAdapter < Crumble::Web::Push::Server::SubscriptionAdapter
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

describe Crumble::Web::Push::Server::SubscriptionAdapter do
  it "supports save, list by user, list by device and delete" do
    adapter = TestSubscriptionAdapter.new
    first_subscription = Crumble::Web::Push::Server::Subscription.new(user_id: "user-1", device_id: "device-1", endpoint: "https://push.example/1", keys: Crumble::Web::Push::Server::SubscriptionKeys.new(auth: "auth-1", p256dh: "p256dh-1"))
    second_subscription = Crumble::Web::Push::Server::Subscription.new(user_id: "user-1", device_id: "device-2", endpoint: "https://push.example/2", keys: Crumble::Web::Push::Server::SubscriptionKeys.new(auth: "auth-2", p256dh: "p256dh-2"))
    third_subscription = Crumble::Web::Push::Server::Subscription.new(user_id: "user-2", device_id: "device-1", endpoint: "https://push.example/3", keys: Crumble::Web::Push::Server::SubscriptionKeys.new(auth: "auth-3", p256dh: "p256dh-3"))

    adapter.save(first_subscription)
    adapter.save(second_subscription)
    adapter.save(third_subscription)

    adapter.list_by_user("user-1").should eq([first_subscription, second_subscription])
    adapter.list_by_device("device-1").should eq([first_subscription, third_subscription])

    adapter.delete("user-1", "device-2").should be_true
    adapter.delete("user-1", "device-2").should be_false
    adapter.list_by_user("user-1").should eq([first_subscription])
  end

  it "allows save to replace a subscription for the same user and device" do
    adapter = TestSubscriptionAdapter.new
    first_subscription = Crumble::Web::Push::Server::Subscription.new(user_id: "user-1", device_id: "device-1", endpoint: "https://push.example/1", keys: Crumble::Web::Push::Server::SubscriptionKeys.new(auth: "auth-1", p256dh: "p256dh-1"))
    updated_subscription = Crumble::Web::Push::Server::Subscription.new(user_id: "user-1", device_id: "device-1", endpoint: "https://push.example/1-updated", keys: Crumble::Web::Push::Server::SubscriptionKeys.new(auth: "auth-1-updated", p256dh: "p256dh-1-updated"))

    adapter.save(first_subscription)
    adapter.save(updated_subscription)

    adapter.list_by_user("user-1").should eq([updated_subscription])
    adapter.list_by_device("device-1").should eq([updated_subscription])
  end
end
