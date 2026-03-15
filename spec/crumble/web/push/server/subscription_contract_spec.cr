require "../../../../spec_helper"

describe Crumble::Web::Push::Server::SubscriptionContract do
  it "parses create payload and converts it to a subscription" do
    payload = Crumble::Web::Push::Server::SubscriptionContract.parse_create(%({"user_id":"u-1","device_id":"d-1","endpoint":"https://push.example/1","keys":{"auth":"auth-1","p256dh":"p256dh-1"}}))
    payload.to_subscription.should eq(Crumble::Web::Push::Server::Subscription.new(user_id: "u-1", device_id: "d-1", endpoint: "https://push.example/1", keys: Crumble::Web::Push::Server::SubscriptionKeys.new(auth: "auth-1", p256dh: "p256dh-1")))
  end

  it "parses update payload with camelCase ids" do
    payload = Crumble::Web::Push::Server::SubscriptionContract.parse_update(%({"userId":"u-2","deviceId":"d-2","endpoint":"https://push.example/2","keys":{"auth":"auth-2","p256dh":"p256dh-2"}}))
    payload.user_id.should eq("u-2")
    payload.device_id.should eq("d-2")
    payload.endpoint.should eq("https://push.example/2")
    payload.auth.should eq("auth-2")
    payload.p256dh.should eq("p256dh-2")
  end

  it "parses delete payload" do
    payload = Crumble::Web::Push::Server::SubscriptionContract.parse_delete(%({"user_id":"u-3","device_id":"d-3"}))
    payload.user_id.should eq("u-3")
    payload.device_id.should eq("d-3")
  end

  it "rejects invalid json" do
    error = expect_raises(Crumble::Web::Push::Server::SubscriptionContract::ValidationError) { Crumble::Web::Push::Server::SubscriptionContract.parse_create("not json") }
    error.errors.should eq(["request body must be valid JSON"])
  end

  it "rejects missing required fields" do
    error = expect_raises(Crumble::Web::Push::Server::SubscriptionContract::ValidationError) { Crumble::Web::Push::Server::SubscriptionContract.parse_create(%({"device_id":"d-4","endpoint":"https://push.example/4","keys":{"auth":"auth-4","p256dh":"p256dh-4"}})) }
    error.errors.should eq(["user_id is required"])
  end

  it "rejects non-object keys payloads" do
    error = expect_raises(Crumble::Web::Push::Server::SubscriptionContract::ValidationError) { Crumble::Web::Push::Server::SubscriptionContract.parse_create(%({"user_id":"u-4","device_id":"d-4","endpoint":"https://push.example/4","keys":"invalid"})) }
    error.errors.should eq(["keys must be an object"])
  end

  it "rejects blank values" do
    error = expect_raises(Crumble::Web::Push::Server::SubscriptionContract::ValidationError) { Crumble::Web::Push::Server::SubscriptionContract.parse_create(%({"user_id":"  ","device_id":"","endpoint":" ","keys":{"auth":" ","p256dh":""}})) }
    error.errors.should eq(["user_id is required", "device_id is required", "endpoint is required", "keys.auth is required", "keys.p256dh is required"])
  end
end
