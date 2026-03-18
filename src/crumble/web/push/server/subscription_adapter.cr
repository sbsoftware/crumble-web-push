module Crumble::Web::Push::Server
  abstract class SubscriptionAdapter
    abstract def save(subscription : Subscription) : Nil

    abstract def delete(session_id : String) : Bool

    abstract def list_by_session(session_id : String) : Array(Subscription)
  end
end
