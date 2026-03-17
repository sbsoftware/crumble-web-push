require "./server/subscription"
require "./server/subscription_adapter"
require "./server/subscription_contract"
require "./server/subscription_endpoint_resource"
require "./server/sender"

module Crumble::Web::Push::Server
  # Namespace for server-side integration with Crumble + WebPush.
  module Integration
    def self.sender(adapter : SubscriptionAdapter, client : WebPush::Client) : Sender
      Sender.new(adapter, client)
    end

    def self.subscription_endpoint_resource : SubscriptionEndpointResource.class
      SubscriptionEndpointResource
    end
  end
end
