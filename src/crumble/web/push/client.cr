require "set"

module CrumbleWebPush
  stimulus_controller SubscriptionController do
    values endpoint_url: String, vapid_public_key: String

    action :subscribe do |event|
      event.preventDefault._call if event
      return this.process_subscription_change._call("subscribe")
    end

    action :unsubscribe do |event|
      event.preventDefault._call if event
      return this.process_subscription_change._call("unsubscribe")
    end

    # Keep the browser flow in one promise chain so subscribe/unsubscribe actions
    # resolve to either a subscription object or `null`.
    js_method :process_subscription_change do |action_name|
      unless this.ensure_support._call
        return Promise.resolve(nil)
      end

      return navigator.serviceWorker.ready.then do |registration|
        if action_name == "subscribe"
          return Notification.requestPermission._call.then do |permission|
            if permission != "granted"
              return nil
            end

            return registration.pushManager.getSubscription._call.then do |existing_subscription|
              if existing_subscription
                return existing_subscription
              else
                return registration.pushManager.subscribe(userVisibleOnly: true, applicationServerKey: this.url_base64_to_uint8_array._call(this.vapidPublicKeyValue))
              end
            end
          end
        else
          return registration.pushManager.getSubscription._call.then do |existing_subscription|
            return nil unless existing_subscription

            return existing_subscription.unsubscribe._call.then do
              return existing_subscription
            end
          end
        end
      end.then do |subscription|
        return nil unless subscription

        return this.post_subscription_change._call(action_name, subscription).then do
          return subscription
        end
      end.catch do
        return nil
      end
    end

    js_method :ensure_support do
      return false unless this.hasEndpointUrlValue
      return false unless this.hasVapidPublicKeyValue

      if window.Notification && navigator.serviceWorker && window.PushManager
        return true
      else
        return false
      end
    end

    js_method :post_subscription_change do |action_name, subscription|
      return fetch(this.endpointUrlValue, method: "POST", headers: {"Content-Type" => "application/json"}, body: JSON.stringify({action: action_name, subscription: this.subscription_payload._call(subscription)})).then do |response|
        unless response.ok
          return Promise.reject(code: "sync_failed", message: "The subscription endpoint rejected the change.")
        end

        return response
      end
    end

    js_method :subscription_payload do |subscription|
      if subscription && subscription.toJSON
        return subscription.toJSON._call
      else
        return subscription
      end
    end

    # The Push API expects the VAPID key as a byte array, not URL-safe base64.
    js_method :url_base64_to_uint8_array do |base64_string|
      padding = "=".repeat((4 - (base64_string.length % 4)) % 4)
      normalized_base64 = (base64_string + padding).split("-").join("+").split("_").join("/")
      raw_data = window.atob(normalized_base64)
      return Uint8Array.from(Array.from(raw_data), ->(char) { return char.charCodeAt(0) })
    end
  end
end

module Crumble::Web::Push::Client
  module Integration
    DEFAULT_SERVICE_WORKER_SCOPE    = "/"
    DEFAULT_SUBSCRIPTION_ENDPOINT   = ::Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource.root_path
    VAPID_PUBLIC_KEY_ENV            = "CRUMBLE_WEB_PUSH_VAPID_PUBLIC_KEY"
    DEFAULT_VAPID_PUBLIC_KEY        = ""
    DEFAULT_SUBSCRIPTION_CONTROLLER = ::CrumbleWebPush::SubscriptionController

    class PushServiceWorkerSource < JS::Code
      def_to_js do
        self.addEventListener("push") do |event|
          if event && event.data
            payload = event.data.json._call
            self.registration.showNotification(payload.title || "Notification", {body: payload.body || "", icon: payload.icon, data: payload.data})
          end
        end

        self.addEventListener("notificationclick") do |event|
          event.notification.close._call
          event.waitUntil(clients.matchAll(type: "window", includeUncontrolled: true).then do |client_list|
            if client_list.length > 0
              client_list[0].focus._call
            else
              clients.openWindow("/")
            end
          end)
        end
      end
    end

    @@registrations_by_target = Hash(UInt64, Set(String)).new { |registrations, target| registrations[target] = Set(String).new }

    class PushServiceWorkerConnector
      getter scope : String

      def initialize(scope : String = DEFAULT_SERVICE_WORKER_SCOPE)
        @scope = scope
      end

      def compose(target) : Nil
        Integration.compose_push_service_worker(target, scope: scope)
      end
    end

    def self.push_service_worker(scope : String = DEFAULT_SERVICE_WORKER_SCOPE) : PushServiceWorkerConnector
      PushServiceWorkerConnector.new(scope)
    end

    def self.compose_push_service_worker(target, scope : String = DEFAULT_SERVICE_WORKER_SCOPE) : Nil
      resolved_scope = scope.strip.empty? ? DEFAULT_SERVICE_WORKER_SCOPE : scope

      # Track registrations per composition object to keep this helper idempotent for each scope.
      scopes = @@registrations_by_target[target.object_id]
      return if scopes.includes?(resolved_scope)

      scopes << resolved_scope
      target.service_worker(scope: resolved_scope) { push_service_worker_source }
    end

    def self.push_service_worker_source : String
      PushServiceWorkerSource.to_js
    end
  end
end

class ToHtml::Layout
  body_attributes Crumble::Web::Push::Client::Integration::DEFAULT_SUBSCRIPTION_CONTROLLER, Crumble::Web::Push::Client::Integration::DEFAULT_SUBSCRIPTION_CONTROLLER.endpoint_url_value(Crumble::Web::Push::Client::Integration::DEFAULT_SUBSCRIPTION_ENDPOINT), Crumble::Web::Push::Client::Integration::DEFAULT_SUBSCRIPTION_CONTROLLER.vapid_public_key_value(ENV.fetch(Crumble::Web::Push::Client::Integration::VAPID_PUBLIC_KEY_ENV, Crumble::Web::Push::Client::Integration::DEFAULT_VAPID_PUBLIC_KEY))
end
