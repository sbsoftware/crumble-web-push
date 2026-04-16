module Crumble::Web::Push::Server
  class InMemorySubscriptionAdapter < SubscriptionAdapter
    @subscriptions = {} of String => Subscription

    def save(session_id : String, subscription : Subscription) : Nil
      @subscriptions[session_id] = subscription
    end

    def get(session_id : String) : Subscription?
      @subscriptions[session_id]?
    end

    def delete(session_id : String) : Bool
      !!@subscriptions.delete(session_id)
    end
  end
end
