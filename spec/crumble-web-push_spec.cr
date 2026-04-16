require "./spec_helper"
require "../lib/crumble/spec/test_request_context"
require "../lib/crumble/spec/test_view_handler"
require "http/client/response"

TEST_SUBSCRIPTION_JSON        = %({"endpoint":"https://push.example/subscriptions/1","keys":{"p256dh":"p256dh-key-1","auth":"auth-key-1"}})
REPLACEMENT_SUBSCRIPTION_JSON = %({"endpoint":"https://push.example/subscriptions/2","keys":{"p256dh":"p256dh-key-2","auth":"auth-key-2"}})

private def test_subscription(json : String = TEST_SUBSCRIPTION_JSON) : Crumble::Web::Push::Subscription
  Crumble::Web::Push::Subscription.from_json(json)
end

private def dispatch_subscription_request(method : String, session_store : Crumble::Server::MemorySessionStore, cookie_value : String? = nil, body : String? = nil) : HTTP::Client::Response
  response_io = IO::Memory.new
  request_context = Crumble::Server::TestRequestContext.new(response_io, session_store, resource: CWPSubscriptionResource.uri_path, method: method, body: body)
  request_context.request.cookies[Crumble::Server::RequestContext::SESSION_COOKIE_NAME] = cookie_value.not_nil! if cookie_value
  CWPSubscriptionResource.handle(request_context)
  request_context.response.close
  response_io.rewind
  HTTP::Client::Response.from_io(response_io)
end

class CWPSubscriptionResource < Crumble::Web::Push::Server::SubscriptionResource
  root_path "/push/subscription"

  @@subscription_adapter = Crumble::Web::Push::Server::InMemorySubscriptionAdapter.new

  def self.reset_subscription_adapter
    @@subscription_adapter = Crumble::Web::Push::Server::InMemorySubscriptionAdapter.new
  end

  def subscription_adapter : Crumble::Web::Push::Server::SubscriptionAdapter
    @@subscription_adapter
  end
end

class CWPFakePushClient
  getter sent_subscription : Crumble::Web::Push::Subscription?
  getter sent_payload : String?
  getter sent_ttl : Int32?

  def initialize(@state : WebPush::Client::SendState = WebPush::Client::SendState::Success, @status_code : Int32 = 201, @body : String = "")
  end

  def send(subscription : Crumble::Web::Push::Subscription, payload : String, *, ttl : Int32, expires_at : Time = Time.utc, now : Time = Time.utc) : WebPush::Client::SendResult
    @sent_subscription = subscription
    @sent_payload = payload
    @sent_ttl = ttl
    WebPush::Client::SendResult.new(@state, @status_code, @body)
  end
end

describe Crumble::Web::Push::Server::InMemorySubscriptionAdapter do
  it "returns nil for missing sessions" do
    Crumble::Web::Push::Server::InMemorySubscriptionAdapter.new.get("missing").should be_nil
  end

  it "replaces existing subscriptions for the same session" do
    adapter = Crumble::Web::Push::Server::InMemorySubscriptionAdapter.new
    adapter.save("session-1", test_subscription)
    adapter.save("session-1", test_subscription(REPLACEMENT_SUBSCRIPTION_JSON))

    adapter.get("session-1").should eq(test_subscription(REPLACEMENT_SUBSCRIPTION_JSON))
  end

  it "reports whether delete removed a stored subscription" do
    adapter = Crumble::Web::Push::Server::InMemorySubscriptionAdapter.new
    adapter.save("session-1", test_subscription)

    adapter.delete("session-1").should be_true
    adapter.delete("session-1").should be_false
  end
end

describe Crumble::Web::Push::Server::Sender do
  it "returns nil when no subscription is stored for the session" do
    sender = Crumble::Web::Push::Server::Sender.new(CWPFakePushClient.new, Crumble::Web::Push::Server::InMemorySubscriptionAdapter.new)

    sender.send("missing", %({"title":"Hello"}), ttl: 60).should be_nil
  end

  it "looks up the stored subscription with get and sends it" do
    adapter = Crumble::Web::Push::Server::InMemorySubscriptionAdapter.new
    client = CWPFakePushClient.new
    adapter.save("session-1", test_subscription)

    result = Crumble::Web::Push::Server::Sender.new(client, adapter).send("session-1", %({"title":"Hello"}), ttl: 60)

    result.not_nil!.status_code.should eq(201)
    client.sent_subscription.should eq(test_subscription)
    client.sent_payload.should eq(%({"title":"Hello"}))
    client.sent_ttl.should eq(60)
  end

  it "deletes invalid subscriptions after a failed send" do
    adapter = Crumble::Web::Push::Server::InMemorySubscriptionAdapter.new
    adapter.save("session-1", test_subscription)

    result = Crumble::Web::Push::Server::Sender.new(CWPFakePushClient.new(WebPush::Client::SendState::InvalidSubscription, 410), adapter).send("session-1", %({"title":"Hello"}), ttl: 60)

    result.not_nil!.state.should eq(WebPush::Client::SendState::InvalidSubscription)
    adapter.get("session-1").should be_nil
  end
end

describe CWPSubscriptionResource do
  before_each do
    CWPSubscriptionResource.reset_subscription_adapter
  end

  it "stores, returns, and deletes the current session subscription" do
    session_store = Crumble::Server::MemorySessionStore.new

    create_response = dispatch_subscription_request("POST", session_store, body: TEST_SUBSCRIPTION_JSON)
    cookie = create_response.cookies[Crumble::Server::RequestContext::SESSION_COOKIE_NAME]

    create_response.status_code.should eq(201)

    show_response = dispatch_subscription_request("GET", session_store, cookie.value)
    show_response.status_code.should eq(200)
    test_subscription(show_response.body).should eq(test_subscription)

    delete_response = dispatch_subscription_request("DELETE", session_store, cookie.value)
    delete_response.status_code.should eq(204)

    missing_response = dispatch_subscription_request("GET", session_store, cookie.value)
    missing_response.status_code.should eq(404)
  end

  it "returns 400 for invalid subscription payloads" do
    response = dispatch_subscription_request("POST", Crumble::Server::MemorySessionStore.new, body: %({"endpoint":"https://push.example/subscriptions/1"}))

    response.status_code.should eq(400)
    response.body.should contain("Subscription field 'p256dh' is required")
  end

  it "returns 404 when deleting a missing subscription" do
    response = dispatch_subscription_request("DELETE", Crumble::Server::MemorySessionStore.new)

    response.status_code.should eq(404)
  end
end
