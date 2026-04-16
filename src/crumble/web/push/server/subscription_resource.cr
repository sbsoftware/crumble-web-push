module Crumble::Web::Push::Server
  abstract class SubscriptionResource < ::Crumble::Resource
    abstract def subscription_adapter : SubscriptionAdapter

    def create
      return bad_request("Subscription request body is required") unless body = ctx.request.body

      subscription_adapter.save(session_id, Subscription.from_json(body.gets_to_end))
      ctx.response.status = :created
    rescue ex : ::WebPush::ValidationError
      bad_request(ex.message || "Invalid subscription")
    end

    def index
      return not_found unless subscription = subscription_adapter.get(session_id)

      ctx.response.content_type = "application/json"
      ctx.response.print subscription.to_json
    end

    def destroy
      return not_found unless subscription_adapter.delete(session_id)

      ctx.response.status = :no_content
    end

    private def session_id : String
      ctx.session.id.to_s
    end

    private def bad_request(message : String) : Nil
      ctx.response.status = :bad_request
      ctx.response.print message
    end

    private def not_found : Nil
      ctx.response.status = :not_found
      ctx.response.print "Not Found"
    end
  end
end
