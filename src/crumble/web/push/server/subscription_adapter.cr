module Crumble::Web::Push::Server
  abstract class SubscriptionAdapter
    abstract def save(subscription : Subscription) : Nil

    abstract def delete(session_id : String) : Bool

    abstract def get(session_id : String) : Subscription?
  end
end
