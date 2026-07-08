require "../../../../spec_helper"
require "file_utils"

describe Crumble::Web::Push::Server::InMemorySubscriptionAdapter do
  it "supports save, get and delete" do
    adapter = Crumble::Web::Push::Server::InMemorySubscriptionAdapter.new
    first_subscription = Crumble::Web::Push::Server::Subscription.new(session_id: "session-1", web_push_subscription: WebPush::Subscription.new(endpoint: "https://push.example/1", auth: "auth-1", p256dh: "p256dh-1"))
    second_subscription = Crumble::Web::Push::Server::Subscription.new(session_id: "session-2", web_push_subscription: WebPush::Subscription.new(endpoint: "https://push.example/2", auth: "auth-2", p256dh: "p256dh-2"))
    third_subscription = Crumble::Web::Push::Server::Subscription.new(session_id: "session-3", web_push_subscription: WebPush::Subscription.new(endpoint: "https://push.example/3", auth: "auth-3", p256dh: "p256dh-3"))

    adapter.save(first_subscription)
    adapter.save(second_subscription)
    adapter.save(third_subscription)

    adapter.get("session-1").should eq(first_subscription)
    adapter.get("session-2").should eq(second_subscription)

    adapter.delete("session-2").should be_true
    adapter.delete("session-2").should be_false
    adapter.get("session-2").should be_nil
  end

  it "allows save to replace a subscription for the same session" do
    adapter = Crumble::Web::Push::Server::InMemorySubscriptionAdapter.new
    first_subscription = Crumble::Web::Push::Server::Subscription.new(session_id: "session-1", web_push_subscription: WebPush::Subscription.new(endpoint: "https://push.example/1", auth: "auth-1", p256dh: "p256dh-1"))
    updated_subscription = Crumble::Web::Push::Server::Subscription.new(session_id: "session-1", web_push_subscription: WebPush::Subscription.new(endpoint: "https://push.example/1-updated", auth: "auth-1-updated", p256dh: "p256dh-1-updated"))

    adapter.save(first_subscription)
    adapter.save(updated_subscription)

    adapter.get("session-1").should eq(updated_subscription)
  end
end

describe Crumble::Web::Push::Server::FileSubscriptionAdapter do
  before_each do
    FileUtils.rm_r("spec/tmp") if Dir.exists?("spec/tmp")
  end

  after_each do
    FileUtils.rm_r("spec/tmp") if Dir.exists?("spec/tmp")
  end

  it "persists saved subscriptions across adapter instances" do
    path = "spec/tmp/push/subscriptions.json"
    first_adapter = Crumble::Web::Push::Server::FileSubscriptionAdapter.new(path)
    first_subscription = Crumble::Web::Push::Server::Subscription.new(session_id: "session-1", web_push_subscription: WebPush::Subscription.new(endpoint: "https://push.example/1", auth: "auth-1", p256dh: "p256dh-1"))
    second_subscription = Crumble::Web::Push::Server::Subscription.new(session_id: "session-2", web_push_subscription: WebPush::Subscription.new(endpoint: "https://push.example/2", auth: "auth-2", p256dh: "p256dh-2"))

    first_adapter.save(first_subscription)
    first_adapter.save(second_subscription)

    second_adapter = Crumble::Web::Push::Server::FileSubscriptionAdapter.new(path)
    second_adapter.get("session-1").should eq(first_subscription)
    second_adapter.get("session-2").should eq(second_subscription)
  end

  it "supports delete across adapter instances" do
    path = "spec/tmp/push/subscriptions.json"
    first_adapter = Crumble::Web::Push::Server::FileSubscriptionAdapter.new(path)
    subscription = Crumble::Web::Push::Server::Subscription.new(session_id: "session-1", web_push_subscription: WebPush::Subscription.new(endpoint: "https://push.example/1", auth: "auth-1", p256dh: "p256dh-1"))

    first_adapter.save(subscription)

    second_adapter = Crumble::Web::Push::Server::FileSubscriptionAdapter.new(path)
    second_adapter.delete("session-1").should be_true
    second_adapter.delete("session-1").should be_false
    first_adapter.get("session-1").should be_nil
  end

  it "allows save to replace a subscription for the same session" do
    adapter = Crumble::Web::Push::Server::FileSubscriptionAdapter.new("spec/tmp/push/subscriptions.json")
    first_subscription = Crumble::Web::Push::Server::Subscription.new(session_id: "session-1", web_push_subscription: WebPush::Subscription.new(endpoint: "https://push.example/1", auth: "auth-1", p256dh: "p256dh-1"))
    updated_subscription = Crumble::Web::Push::Server::Subscription.new(session_id: "session-1", web_push_subscription: WebPush::Subscription.new(endpoint: "https://push.example/1-updated", auth: "auth-1-updated", p256dh: "p256dh-1-updated"))

    adapter.save(first_subscription)
    adapter.save(updated_subscription)

    adapter.get("session-1").should eq(updated_subscription)
  end

  it "treats a missing storage file as empty" do
    adapter = Crumble::Web::Push::Server::FileSubscriptionAdapter.new("spec/tmp/push/subscriptions.json")

    adapter.get("missing-session").should be_nil
    adapter.delete("missing-session").should be_false
  end
end
