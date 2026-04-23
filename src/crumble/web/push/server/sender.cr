module Crumble::Web::Push::Server::Integration
  record SendOutcome, subscription : Subscription, result : WebPush::Client::SendResult?, error : Exception? do
    def sent? : Bool
      result.try(&.success?) || false
    end

    def invalid_subscription? : Bool
      result.try(&.invalid_subscription?) || false
    end

    def cleanup? : Bool
      result.try(&.cleanup_subscription?) || false
    end

    def failed? : Bool
      !sent?
    end

    def retryable? : Bool
      result.try(&.retryable?) || false
    end

    def status_code : Int32?
      result.try(&.status_code)
    end

    def error_message : String?
      error.try(&.message)
    end
  end

  class Sender
    def initialize(@client : WebPush::Client)
    end

    def send_to_session(session_id : String, payload : String, *, ttl : Int32, expires_at : Time = Time.utc + WebPush::Vapid::DEFAULT_EXPIRATION, now : Time = Time.utc) : Array(SendOutcome)
      if subscription = Integration.subscription_adapter.get(session_id)
        [send_subscription(subscription, payload, ttl: ttl, expires_at: expires_at, now: now)]
      else
        [] of SendOutcome
      end
    end

    def send_subscriptions(subscriptions : Enumerable(Subscription), payload : String, *, ttl : Int32, expires_at : Time = Time.utc + WebPush::Vapid::DEFAULT_EXPIRATION, now : Time = Time.utc) : Array(SendOutcome)
      outcomes = [] of SendOutcome
      subscriptions.each { |subscription| outcomes << send_subscription(subscription, payload, ttl: ttl, expires_at: expires_at, now: now) }
      outcomes
    end

    def send_subscription(subscription : Subscription, payload : String, *, ttl : Int32, expires_at : Time = Time.utc + WebPush::Vapid::DEFAULT_EXPIRATION, now : Time = Time.utc) : SendOutcome
      SendOutcome.new(subscription: subscription, result: @client.send(subscription.to_web_push_subscription, payload, ttl: ttl, expires_at: expires_at, now: now), error: nil)
    rescue ex
      SendOutcome.new(subscription: subscription, result: nil, error: ex)
    end
  end
end
