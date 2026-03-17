require "../../../../spec_helper"

private class SenderSpecSubscriptionAdapter < Crumble::Web::Push::Server::SubscriptionAdapter
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

private record FakePushResponse, status_code : Int32

private class FakePushError < Exception
  getter status_code : Int32

  def initialize(@status_code : Int32, message : String)
    super(message)
  end
end

private class FakePushClient
  getter sent_requests = [] of NamedTuple(subscription: Crumble::Web::Push::Server::Subscription, payload: String)

  def initialize(@status_codes_by_endpoint : Hash(String, Int32) = {} of String => Int32, @errors_by_endpoint : Hash(String, Int32) = {} of String => Int32)
  end

  def send(subscription : Crumble::Web::Push::Server::Subscription, payload : String) : FakePushResponse
    @sent_requests << {subscription: subscription, payload: payload}
    raise FakePushError.new(@errors_by_endpoint[subscription.endpoint], "push failed for #{subscription.device_id}") if @errors_by_endpoint.has_key?(subscription.endpoint)
    FakePushResponse.new(status_code: @status_codes_by_endpoint[subscription.endpoint]? || 201)
  end
end

describe Crumble::Web::Push::Server::Integration::Sender do
  it "sends to every subscription loaded for a user" do
    adapter = SenderSpecSubscriptionAdapter.new
    first_subscription = Crumble::Web::Push::Server::Subscription.new(user_id: "user-1", device_id: "device-1", endpoint: "https://push.example/1", keys: Crumble::Web::Push::Server::SubscriptionKeys.new(auth: "auth-1", p256dh: "p256dh-1"))
    second_subscription = Crumble::Web::Push::Server::Subscription.new(user_id: "user-1", device_id: "device-2", endpoint: "https://push.example/2", keys: Crumble::Web::Push::Server::SubscriptionKeys.new(auth: "auth-2", p256dh: "p256dh-2"))
    adapter.save(first_subscription)
    adapter.save(second_subscription)
    client = FakePushClient.new
    sender = Crumble::Web::Push::Server::Integration.sender(adapter, client)

    outcomes = sender.send_to_user("user-1", %({"title":"Hello"}))

    outcomes.map(&.status).should eq([Crumble::Web::Push::Server::Integration::SendOutcomeStatus::Sent, Crumble::Web::Push::Server::Integration::SendOutcomeStatus::Sent])
    client.sent_requests.should eq([{subscription: first_subscription, payload: %({"title":"Hello"})}, {subscription: second_subscription, payload: %({"title":"Hello"})}])
  end

  it "marks invalid subscriptions for cleanup when the push client rejects them" do
    adapter = SenderSpecSubscriptionAdapter.new
    invalid_subscription = Crumble::Web::Push::Server::Subscription.new(user_id: "user-2", device_id: "device-3", endpoint: "https://push.example/invalid", keys: Crumble::Web::Push::Server::SubscriptionKeys.new(auth: "auth-3", p256dh: "p256dh-3"))
    adapter.save(invalid_subscription)
    sender = Crumble::Web::Push::Server::Integration.sender(adapter, FakePushClient.new(errors_by_endpoint: {"https://push.example/invalid" => 410}))

    outcomes = sender.send_to_device("device-3", %({"title":"Cleanup"}))

    outcomes.should eq([Crumble::Web::Push::Server::Integration::SendOutcome.new(subscription: invalid_subscription, status: Crumble::Web::Push::Server::Integration::SendOutcomeStatus::InvalidSubscription, status_code: 410, error_message: "push failed for device-3")])
    outcomes.first.invalid_subscription?.should be_true
    outcomes.first.cleanup?.should be_true
    outcomes.first.sent?.should be_false
  end
end
