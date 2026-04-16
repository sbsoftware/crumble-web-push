module Crumble::Web::Push::Server
  class Sender(ClientType)
    getter client : ClientType
    getter subscription_adapter : SubscriptionAdapter

    def initialize(@client : ClientType, @subscription_adapter : SubscriptionAdapter)
    end

    def send(session_id : String, payload : String, *, ttl : Int32, expires_at : Time = Time.utc + ::WebPush::Vapid::DEFAULT_EXPIRATION, now : Time = Time.utc)
      return unless subscription = subscription_adapter.get(session_id)

      result = client.send(subscription, payload, ttl: ttl, expires_at: expires_at, now: now)

      # Drop stale endpoints once the push provider reports the subscription is gone.
      subscription_adapter.delete(session_id) if result.state == ::WebPush::Client::SendState::InvalidSubscription
      result
    end
  end
end
