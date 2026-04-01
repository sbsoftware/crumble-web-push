require "../../src/crumble-web-push"
require "json"

module Crumble::Web::Push::Examples
  module MinimalApp
    VAPID_PRIVATE_KEY_ENV = "CRUMBLE_WEB_PUSH_VAPID_PRIVATE_KEY"
    VAPID_SUBJECT_ENV     = "CRUMBLE_WEB_PUSH_VAPID_SUBJECT"

    class MemorySubscriptionAdapter < ::Crumble::Web::Push::Server::SubscriptionAdapter
      @subscriptions = {} of String => ::Crumble::Web::Push::Server::Subscription

      def save(subscription : ::Crumble::Web::Push::Server::Subscription) : Nil
        @subscriptions[subscription.session_id] = subscription
      end

      def delete(session_id : String) : Bool
        !@subscriptions.delete(session_id).nil?
      end

      def list_by_session(session_id : String) : Array(::Crumble::Web::Push::Server::Subscription)
        if subscription = @subscriptions[session_id]?
          [subscription]
        else
          [] of ::Crumble::Web::Push::Server::Subscription
        end
      end
    end

    @@subscription_adapter : MemorySubscriptionAdapter?
    @@sender : ::Crumble::Web::Push::Server::Integration::Sender?

    def self.configure!(adapter : MemorySubscriptionAdapter = MemorySubscriptionAdapter.new, sender : ::Crumble::Web::Push::Server::Integration::Sender = build_sender) : Nil
      @@subscription_adapter = adapter
      @@sender = sender
      ::Crumble::Web::Push::Server::Integration.subscription_adapter = adapter
    end

    def self.subscription_adapter : MemorySubscriptionAdapter
      @@subscription_adapter || raise ::Crumble::Web::Push::Server::Integration::ConfigurationError.new("Minimal push example subscription adapter is not configured")
    end

    def self.sender : ::Crumble::Web::Push::Server::Integration::Sender
      @@sender || raise ::Crumble::Web::Push::Server::Integration::ConfigurationError.new("Minimal push example sender is not configured")
    end

    def self.build_sender : ::Crumble::Web::Push::Server::Integration::Sender
      ::Crumble::Web::Push::Server::Integration.sender(
        WebPush::Client.new(
          WebPush::VapidConfig.new(
            public_key: ENV.fetch(::Crumble::Web::Push::Client::Integration::VAPID_PUBLIC_KEY_ENV),
            private_key: ENV.fetch(VAPID_PRIVATE_KEY_ENV),
            subject: ENV.fetch(VAPID_SUBJECT_ENV)
          )
        )
      )
    end

    def self.test_payload : String
      %({"title":"Crumble push example","body":"Triggered from the local test app","url":"#{NotificationsPage.uri_path}"})
    end

    class NotificationsPage < ::Crumble::Page
      root_path "/push_example"

      layout ToHtml::Layout

      template do
        main do
          h1 { "Crumble Web Push Example" }
          p { "This page wires worker registration, the shared subscription endpoint, and a server-side test push trigger." }
          ul do
            li { "Subscription endpoint: #{::Crumble::Web::Push::Server::Integration.subscription_endpoint_resource.uri_path}" }
            li { "Test push endpoint: #{::Crumble::Web::Push::Examples::MinimalApp::TestPushesResource.uri_path}" }
          end
          button ::CrumbleWebPush::SubscriptionController.subscribe_action("click"), type: "button" do
            "Subscribe this browser"
          end
          button ::CrumbleWebPush::SubscriptionController.unsubscribe_action("click"), type: "button" do
            "Unsubscribe this browser"
          end
          form action: ::Crumble::Web::Push::Examples::MinimalApp::TestPushesResource.uri_path, method: "POST" do
            button type: "submit" do
              "Send test push"
            end
          end
        end
      end

      def window_title : String?
        "Crumble Web Push Example"
      end
    end

    class TestPushesResource < ::Crumble::Resource
      def self.root_path
        "/push_example/test_pushes"
      end

      def create
        outcomes = ::Crumble::Web::Push::Examples::MinimalApp.sender.send_to_session(ctx.session.id.to_s, ::Crumble::Web::Push::Examples::MinimalApp.test_payload, ttl: 60)

        # Invalid subscriptions should be dropped immediately so the demo stays repeatable.
        outcomes.each { |outcome| ::Crumble::Web::Push::Examples::MinimalApp.subscription_adapter.delete(outcome.subscription.session_id) if outcome.cleanup? }

        ctx.response.headers["Content-Type"] = "application/json"
        ctx.response.print(
          {
            session_id: ctx.session.id.to_s,
            delivered:  outcomes.count(&.sent?),
            failed:     outcomes.count(&.failed?),
            outcomes:   outcomes.map { |outcome|
              {
                endpoint:      outcome.subscription.endpoint,
                sent:          outcome.sent?,
                cleanup:       outcome.cleanup?,
                retryable:     outcome.retryable?,
                status_code:   outcome.status_code,
                error_message: outcome.error_message,
              }
            },
          }.to_json
        )
      rescue ex : ::Crumble::Web::Push::Server::Integration::ConfigurationError
        ctx.response.status = :internal_server_error
        ctx.response.headers["Content-Type"] = "application/json"
        ctx.response.print({error: ex.message || "Minimal push example sender is not configured"}.to_json)
      end
    end

    def self.run : Nil
      configure!
      puts "Open http://localhost:#{::Crumble::Server.port}#{NotificationsPage.uri_path}"
      ::Crumble::Server.start
    end
  end
end
