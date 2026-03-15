module Crumble::Web::Push::Server
  abstract class SubscriptionAdapter
    abstract def save(subscription : Subscription) : Nil

    abstract def delete(user_id : String, device_id : String) : Bool

    abstract def list_by_user(user_id : String) : Array(Subscription)

    abstract def list_by_device(device_id : String) : Array(Subscription)
  end
end
