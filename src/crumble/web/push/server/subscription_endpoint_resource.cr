require "json"

module Crumble::Web::Push::Server::Integration
  class SubscriptionEndpointResource < Crumble::Resource
    record RequestIdentity, user_id : String, device_id : String

    class ConfigurationError < Exception
    end

    @@adapter : SubscriptionAdapter?
    @@identity_resolver : Proc(Crumble::Server::HandlerContext, RequestIdentity)?

    def self.root_path
      "/__crumble_web_push_subscriptions__"
    end

    def self.configure(adapter : SubscriptionAdapter, &identity_resolver : Crumble::Server::HandlerContext -> RequestIdentity) : Nil
      @@adapter = adapter
      @@identity_resolver = identity_resolver
    end

    def self.reset! : Nil
      @@adapter = nil
      @@identity_resolver = nil
    end

    def create
      payload = SubscriptionContract.parse_sync(ctx.request.body.try(&.gets_to_end) || "")
      identity = self.class.identity_for(ctx)

      case payload.action
      when .subscribe?
        self.class.subscription_adapter.save(payload.to_subscription(identity.user_id, identity.device_id))
      when .unsubscribe?
        self.class.subscription_adapter.delete(identity.user_id, identity.device_id)
      end

      ctx.response.status = :no_content
    rescue ex : SubscriptionContract::ValidationError
      ctx.response.status = :unprocessable_entity
      ctx.response.headers["Content-Type"] = "application/json"
      ctx.response.print({errors: ex.errors}.to_json)
    rescue ex : ConfigurationError
      ctx.response.status = :internal_server_error
      ctx.response.print(ex.message || "Push subscription endpoint is not configured")
    end

    def self.subscription_adapter : SubscriptionAdapter
      @@adapter || raise ConfigurationError.new("Push subscription endpoint adapter is not configured")
    end

    def self.identity_for(ctx : Crumble::Server::HandlerContext) : RequestIdentity
      @@identity_resolver.try(&.call(ctx)) || raise ConfigurationError.new("Push subscription endpoint identity resolver is not configured")
    end
  end
end
