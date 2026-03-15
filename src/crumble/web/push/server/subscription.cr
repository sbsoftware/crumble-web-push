module Crumble::Web::Push::Server
  record SubscriptionKeys, auth : String, p256dh : String

  record Subscription, user_id : String, device_id : String, endpoint : String, keys : SubscriptionKeys
end
