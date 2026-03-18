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

    @@subscription_adapter : SubscriptionAdapter?

    def self.sender(adapter : SubscriptionAdapter, client : WebPush::Client) : Sender
      self.subscription_adapter = adapter
      sender(client)
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
    end

    def self.subscription_endpoint_resource : SubscriptionEndpointResource.class
      SubscriptionEndpointResource
    end
  end
end
