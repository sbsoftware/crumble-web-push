require "./spec_helper"
require "../lib/crumble/spec/test_request_context"

README_TEST_SUBSCRIPTION_JSON = %({"endpoint":"https://push.example/subscriptions/1","keys":{"p256dh":"p256dh-key-1","auth":"auth-key-1"}})

describe "README examples" do
  it "uses the built-in in-memory adapter with get" do
    adapter = Crumble::Web::Push::Server::InMemorySubscriptionAdapter.new
    subscription = Crumble::Web::Push::Subscription.from_json(README_TEST_SUBSCRIPTION_JSON)

    adapter.save("session-1", subscription)

    adapter.get("session-1").should eq(subscription)
  end

  it "lets a concrete resource expose the built-in adapter" do
    resource = READMEPushSubscriptionResource.new(Crumble::Server::TestRequestContext.new(resource: "/push/subscription"))

    resource.subscription_adapter.should be_a(Crumble::Web::Push::Server::InMemorySubscriptionAdapter)
  end
end

class READMEPushSubscriptionResource < Crumble::Web::Push::Server::SubscriptionResource
  ADAPTER = Crumble::Web::Push::Server::InMemorySubscriptionAdapter.new

  def subscription_adapter : Crumble::Web::Push::Server::SubscriptionAdapter
    ADAPTER
  end
end
