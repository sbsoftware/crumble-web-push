module Crumble::Web::Push::Server
  class InMemorySubscriptionAdapter < SubscriptionAdapter
    @subscriptions = {} of String => Subscription

    def save(subscription : Subscription) : Nil
      @subscriptions[subscription.session_id] = subscription
    end

    def delete(session_id : String) : Bool
      !@subscriptions.delete(session_id).nil?
    end

    def get(session_id : String) : Subscription?
      @subscriptions[session_id]?
    end

    def each_subscription(&block : Subscription ->) : Nil
      @subscriptions.each_value do |subscription|
        yield subscription
      end
    end
  end
end
