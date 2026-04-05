require "./server/subscription"
require "./server/subscription_adapter"
require "./server/subscription_contract"
require "./server/subscription_endpoint_resource"
require "./server/sender"

module Crumble::Web::Push::Server
  # Namespace for server-side integration with Crumble + WebPush.
  module Integration
    class ConfigurationError < Exception
    end

    VAPID_PRIVATE_KEY_ENV = "CRUMBLE_WEB_PUSH_VAPID_PRIVATE_KEY"
    VAPID_SUBJECT_ENV     = "CRUMBLE_WEB_PUSH_VAPID_SUBJECT"

    @@subscription_adapter : SubscriptionAdapter?
    @@sender_override : Sender?

    def self.sender(adapter : SubscriptionAdapter, client : WebPush::Client) : Sender
      self.subscription_adapter = adapter
      sender(client)
    end

    def self.sender(adapter : SubscriptionAdapter) : Sender
      self.subscription_adapter = adapter
      sender
    end

    def self.sender : Sender
      return @@sender_override.not_nil! if @@sender_override

      sender(
        WebPush::Client.new(
          WebPush::VapidConfig.new(
            public_key: ENV.fetch(::Crumble::Web::Push::Client::Integration::VAPID_PUBLIC_KEY_ENV),
            private_key: ENV.fetch(VAPID_PRIVATE_KEY_ENV),
            subject: ENV.fetch(VAPID_SUBJECT_ENV)
          )
        )
      )
    end

    def self.sender(client : WebPush::Client) : Sender
      Sender.new(client)
    end

    def self.subscription_adapter=(adapter : SubscriptionAdapter) : SubscriptionAdapter
      @@subscription_adapter = adapter
      adapter
    end

    def self.subscription_adapter : SubscriptionAdapter
      @@subscription_adapter || raise ConfigurationError.new("Push subscription adapter is not configured")
    end

    def self.reset! : Nil
      @@subscription_adapter = nil
      @@sender_override = nil
    end

    def self.subscription_endpoint_resource : SubscriptionEndpointResource.class
      SubscriptionEndpointResource
    end

    def self.sender_override=(sender : Sender?) : Sender?
      @@sender_override = sender
    end
  end
end
