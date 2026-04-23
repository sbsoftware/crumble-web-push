require "../../../../spec_helper"

private SENDER_TEST_PUBLIC_KEY  = "BNpReHjFgbvl8tsrMoRJl-eKTIhYQXUsVPgIMGB2AUUG-ufq4N6F4FRsBiphNVCrkXGB5EPExzQoa6Qzng0yxyU"
private SENDER_TEST_PRIVATE_KEY = "79Om5Okowk6Tkd-1moexy7bIXuQQb5o2J9SWPq75Wnw"
private SENDER_TEST_SUBJECT     = "mailto:admin@example.com"
private SENDER_TEST_P256DH      = "BNnjgxL7iRJVGG2WfKoCcEas8uXFYFw4b6ivLqWsMp8pMhmdN3LRYQTyFWuE_MOCSD_OLdj2K2gtH3ggUe4nYeY"
private SENDER_TEST_AUTH        = "KsWb025fekARlsIkDa5Vnw"

private struct CapturedSenderRequest
  getter endpoint : String
  getter body : String

  def initialize(@endpoint : String, @body : String)
  end
end

private class StubPushEndpoint
  def initialize(@status_code : Int32, @response_body : String = %({"status":"ok"}))
  end

  def response : HTTP::Client::Response
    HTTP::Client::Response.new(@status_code, body: @response_body)
  end
end

private class StubSenderClient < WebPush::Client
  getter requests = [] of CapturedSenderRequest

  def initialize(@stub_push_endpoint : StubPushEndpoint)
    super(WebPush::VapidConfig.new(public_key: SENDER_TEST_PUBLIC_KEY, private_key: SENDER_TEST_PRIVATE_KEY, subject: SENDER_TEST_SUBJECT))
  end

  private def send_request(request : WebPush::PushRequest) : HTTP::Client::Response
    @requests << CapturedSenderRequest.new(endpoint: request.endpoint, body: request.body)
    @stub_push_endpoint.response
  end
end

describe Crumble::Web::Push::Server::Integration::Sender do
  after_each do
    Crumble::Web::Push::Server::Integration.reset!
  end

  it "sends the subscription loaded for a session through WebPush::Client" do
    adapter = Crumble::Web::Push::Server::InMemorySubscriptionAdapter.new
    first_subscription = Crumble::Web::Push::Server::Subscription.new(session_id: "session-1", web_push_subscription: WebPush::Subscription.new(endpoint: "https://push.example/1", auth: SENDER_TEST_AUTH, p256dh: SENDER_TEST_P256DH))
    adapter.save(first_subscription)
    client = StubSenderClient.new(StubPushEndpoint.new(201))
    Crumble::Web::Push::Server::Integration.subscription_adapter = adapter
    sender = Crumble::Web::Push::Server::Integration.sender(client)

    outcomes = sender.send_to_session("session-1", %({"title":"Hello"}), ttl: 60)

    outcomes.size.should eq(1)
    outcomes.all?(&.sent?).should be_true
    outcomes.all? { |outcome| outcome.result.not_nil!.state == WebPush::Client::SendState::Success }.should be_true
    client.requests.map(&.endpoint).should eq(["https://push.example/1"])
    client.requests.all? { |request| request.body.bytesize > 0 }.should be_true
  end

  it "returns no outcomes when the session has no stored subscription" do
    Crumble::Web::Push::Server::Integration.subscription_adapter = Crumble::Web::Push::Server::InMemorySubscriptionAdapter.new
    client = StubSenderClient.new(StubPushEndpoint.new(201))
    sender = Crumble::Web::Push::Server::Integration.sender(client)

    sender.send_to_session("missing-session", %({"title":"Hello"}), ttl: 60).should be_empty
    client.requests.should be_empty
  end

  it "surfaces invalid-subscription cleanup from WebPush::Client send results" do
    adapter = Crumble::Web::Push::Server::InMemorySubscriptionAdapter.new
    invalid_subscription = Crumble::Web::Push::Server::Subscription.new(session_id: "session-2", web_push_subscription: WebPush::Subscription.new(endpoint: "https://push.example/invalid", auth: SENDER_TEST_AUTH, p256dh: SENDER_TEST_P256DH))
    adapter.save(invalid_subscription)
    Crumble::Web::Push::Server::Integration.subscription_adapter = adapter
    sender = Crumble::Web::Push::Server::Integration.sender(StubSenderClient.new(StubPushEndpoint.new(410)))

    outcome = sender.send_to_session("session-2", %({"title":"Cleanup"}), ttl: 30).first

    outcome.subscription.should eq(invalid_subscription)
    outcome.result.not_nil!.state.should eq(WebPush::Client::SendState::InvalidSubscription)
    outcome.invalid_subscription?.should be_true
    outcome.cleanup?.should be_true
    outcome.status_code.should eq(410)
    outcome.error_message.should be_nil
  end
end
