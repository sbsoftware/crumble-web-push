require "../../../../spec_helper"

describe Crumble::Web::Push::Server::SubscriptionContract do
  it "parses create payload and converts it to a subscription" do
    payload = Crumble::Web::Push::Server::SubscriptionContract.parse_create(%({"session_id":"s-1","endpoint":"https://push.example/1","keys":{"auth":"auth-1","p256dh":"p256dh-1"}}))
    payload.to_subscription.should eq(Crumble::Web::Push::Server::Subscription.new(session_id: "s-1", web_push_subscription: WebPush::Subscription.new(endpoint: "https://push.example/1", auth: "auth-1", p256dh: "p256dh-1")))
  end

  it "parses update payload with a camelCase session id" do
    payload = Crumble::Web::Push::Server::SubscriptionContract.parse_update(%({"sessionId":"s-2","endpoint":"https://push.example/2","keys":{"auth":"auth-2","p256dh":"p256dh-2"}}))
    payload.session_id.should eq("s-2")
    payload.endpoint.should eq("https://push.example/2")
    payload.auth.should eq("auth-2")
    payload.p256dh.should eq("p256dh-2")
  end

  it "parses delete payload" do
    payload = Crumble::Web::Push::Server::SubscriptionContract.parse_delete(%({"session_id":"s-3"}))
    payload.session_id.should eq("s-3")
  end

  it "parses sync payloads into a web-push subscription" do
    payload = Crumble::Web::Push::Server::SubscriptionContract.parse_sync(%({"action":"subscribe","subscription":{"endpoint":"https://push.example/5","keys":{"auth":"auth-5","p256dh":"p256dh-5"}}}))
    payload.action.should eq(Crumble::Web::Push::Server::SubscriptionContract::SyncAction::Subscribe)
    payload.to_subscription("s-5").should eq(Crumble::Web::Push::Server::Subscription.new(session_id: "s-5", web_push_subscription: WebPush::Subscription.new(endpoint: "https://push.example/5", auth: "auth-5", p256dh: "p256dh-5")))
  end

  it "rejects invalid json" do
    error = expect_raises(Crumble::Web::Push::Server::SubscriptionContract::ValidationError) { Crumble::Web::Push::Server::SubscriptionContract.parse_create("not json") }
    error.errors.should eq(["request body must be valid JSON"])
  end

  it "rejects missing required fields" do
    error = expect_raises(Crumble::Web::Push::Server::SubscriptionContract::ValidationError) { Crumble::Web::Push::Server::SubscriptionContract.parse_create(%({"endpoint":"https://push.example/4","keys":{"auth":"auth-4","p256dh":"p256dh-4"}})) }
    error.errors.should eq(["session_id is required"])
  end

  it "rejects non-object keys payloads" do
    error = expect_raises(Crumble::Web::Push::Server::SubscriptionContract::ValidationError) { Crumble::Web::Push::Server::SubscriptionContract.parse_create(%({"session_id":"s-4","endpoint":"https://push.example/4","keys":"invalid"})) }
    error.errors.should eq(["keys must be an object"])
  end

  it "rejects blank values" do
    error = expect_raises(Crumble::Web::Push::Server::SubscriptionContract::ValidationError) { Crumble::Web::Push::Server::SubscriptionContract.parse_create(%({"session_id":"  ","endpoint":" ","keys":{"auth":" ","p256dh":""}})) }
    error.errors.should eq(["session_id is required", "endpoint is required", "keys.auth is required", "keys.p256dh is required"])
  end

  it "rejects unsupported sync actions" do
    error = expect_raises(Crumble::Web::Push::Server::SubscriptionContract::ValidationError) { Crumble::Web::Push::Server::SubscriptionContract.parse_sync(%({"action":"refresh","subscription":{"endpoint":"https://push.example/6","keys":{"auth":"auth-6","p256dh":"p256dh-6"}}})) }
    error.errors.should eq(["action must be subscribe or unsubscribe"])
  end
end
