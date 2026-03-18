require "json"

module Crumble::Web::Push::Server::Integration
  class SubscriptionEndpointResource < Crumble::Resource
    def self.root_path
      "/__crumble_web_push_subscriptions__"
    end

    def create
      payload = SubscriptionContract.parse_sync(ctx.request.body.try(&.gets_to_end) || "")
      session_id = ctx.session.id.to_s

      case payload.action
      when .subscribe?
        Integration.subscription_adapter.save(payload.to_subscription(session_id))
      when .unsubscribe?
        Integration.subscription_adapter.delete(session_id)
      end

      ctx.response.status = :no_content
    rescue ex : SubscriptionContract::ValidationError
      ctx.response.status = :unprocessable_entity
      ctx.response.headers["Content-Type"] = "application/json"
      ctx.response.print({errors: ex.errors}.to_json)
    rescue ex : Integration::ConfigurationError
      ctx.response.status = :internal_server_error
      ctx.response.print(ex.message || "Push subscription endpoint is not configured")
    end
  end
end
