module Crumble::Web::Push::Server
  abstract class SubscriptionAdapter
    abstract def save(session_id : String, subscription : Subscription) : Nil
    abstract def get(session_id : String) : Subscription?
    abstract def delete(session_id : String) : Bool
  end
end
