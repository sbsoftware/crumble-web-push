module Crumble::Web::Push::Server
  record Subscription, session_id : String, web_push_subscription : WebPush::Subscription do
    def to_web_push_subscription : WebPush::Subscription
      web_push_subscription
    end

    def endpoint : String
      web_push_subscription.endpoint
    end

    def p256dh : String
      web_push_subscription.p256dh
    end

    def auth : String
      web_push_subscription.auth
    end
  end
end
