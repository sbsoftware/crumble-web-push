module Crumble::Web::Push::Server
  record SubscriptionKeys, auth : String, p256dh : String

  record Subscription, user_id : String, device_id : String, endpoint : String, keys : SubscriptionKeys do
    def to_web_push_subscription : WebPush::Subscription
      WebPush::Subscription.new(endpoint: endpoint, p256dh: keys.p256dh, auth: keys.auth)
    end
  end
end
