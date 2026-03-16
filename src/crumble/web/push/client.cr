require "set"

module CrumbleWebPush
  class SubscriptionController < Stimulus::Controller
    values endpoint_url: String, vapid_public_key: String

    js_method :connect do
      this.dispatch("state", detail: {code: "ready"})
    end

    action :subscribe do |event|
      event.preventDefault._call if event
      return this.process_subscription_change._call("subscribe")
    end

    action :unsubscribe do |event|
      event.preventDefault._call if event
      return this.process_subscription_change._call("unsubscribe")
    end

    # Keep the browser flow in one promise chain so apps receive exactly one
    # success/failure event per attempted state transition.
    js_method :process_subscription_change do |action_name|
      unless this.ensure_support._call(action_name)
        return Promise.resolve(nil)
      end

      return navigator.serviceWorker.ready.then do |registration|
        if action_name == "subscribe"
          return Notification.requestPermission._call.then do |permission|
            if permission != "granted"
              if permission == "denied"
                this.emit_failure._call(action_name, "permission_denied", "Push permission was not granted.")
              else
                this.emit_failure._call(action_name, "permission_not_granted", "Push permission was not granted.")
              end
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
            unless existing_subscription
              this.emit_failure._call(action_name, "subscription_missing", "No push subscription is currently active.")
              return nil
            end

            return existing_subscription.unsubscribe._call.then do
              return existing_subscription
            end
          end
        end
      end.then do |subscription|
        return nil unless subscription

        return this.post_subscription_change._call(action_name, subscription).then do
          this.dispatch("success", detail: {action: action_name, subscription: this.subscription_payload._call(subscription)})
          return subscription
        end
      end.catch do |error|
        if error && error.code
          this.emit_failure._call(action_name, error.code, this.error_message._call(error))
        else
          this.emit_failure._call(action_name, "unexpected_error", this.error_message._call(error))
        end
        return nil
      end
    end

    js_method :ensure_support do |action_name|
      unless this.hasEndpointUrlValue
        this.emit_failure._call(action_name, "missing_configuration", "The endpoint URL value is missing.")
        return false
      end

      unless this.hasVapidPublicKeyValue
        this.emit_failure._call(action_name, "missing_configuration", "The VAPID public key value is missing.")
        return false
      end

      if window.Notification && navigator.serviceWorker && window.PushManager
        return true
      else
        this.emit_failure._call(action_name, "unsupported_browser", "This browser does not support Web Push.")
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

    js_method :emit_failure do |action_name, code, message|
      this.dispatch("failure", detail: {action: action_name, code: code, message: message})
    end

    js_method :error_message do |error|
      unless error
        return "Unexpected push subscription error."
      end

      if error.message
        return error.message
      elsif error.toString
        return error.toString._call
      else
        return "Unexpected push subscription error."
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
    DEFAULT_SERVICE_WORKER_SCOPE              = "/"
    DEFAULT_PUSH_SUBSCRIPTION_CONTROLLER_NAME = ::CrumbleWebPush::SubscriptionController.controller_name

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
    @@subscription_controller_registrations_by_target = Hash(UInt64, Set(String)).new { |registrations, target| registrations[target] = Set(String).new }

    class PushServiceWorkerConnector
      getter scope : String

      def initialize(scope : String = DEFAULT_SERVICE_WORKER_SCOPE)
        @scope = scope
      end

      def compose(target) : Nil
        Integration.compose_push_service_worker(target, scope: scope)
      end
    end

    class PushSubscriptionControllerConnector
      getter controller_name : String

      def initialize(controller_name : String = DEFAULT_PUSH_SUBSCRIPTION_CONTROLLER_NAME)
        @controller_name = Integration.resolve_controller_name(controller_name)
      end

      def compose(target) : Nil
        Integration.compose_push_subscription_controller(target, controller_name: controller_name)
      end
    end

    def self.push_service_worker(scope : String = DEFAULT_SERVICE_WORKER_SCOPE) : PushServiceWorkerConnector
      PushServiceWorkerConnector.new(scope)
    end

    def self.push_subscription_controller(controller_name : String = DEFAULT_PUSH_SUBSCRIPTION_CONTROLLER_NAME) : PushSubscriptionControllerConnector
      PushSubscriptionControllerConnector.new(controller_name: controller_name)
    end

    def self.subscription_controller(controller_name : String = DEFAULT_PUSH_SUBSCRIPTION_CONTROLLER_NAME) : PushSubscriptionControllerConnector
      push_subscription_controller(controller_name: controller_name)
    end

    def self.compose_push_service_worker(target, scope : String = DEFAULT_SERVICE_WORKER_SCOPE) : Nil
      resolved_scope = scope.strip.empty? ? DEFAULT_SERVICE_WORKER_SCOPE : scope

      # Track registrations per composition object to keep this helper idempotent for each scope.
      scopes = @@registrations_by_target[target.object_id]
      return if scopes.includes?(resolved_scope)

      scopes << resolved_scope
      target.service_worker(scope: resolved_scope) { push_service_worker_source }
    end

    def self.compose_push_subscription_controller(target, controller_name : String = DEFAULT_PUSH_SUBSCRIPTION_CONTROLLER_NAME) : Nil
      resolved_controller_name = resolve_controller_name(controller_name)

      # Keep controller registration idempotent for a given composition object + controller name.
      controller_names = @@subscription_controller_registrations_by_target[target.object_id]
      return if controller_names.includes?(resolved_controller_name)

      controller_names << resolved_controller_name
      target.stimulus_controller(resolved_controller_name) { push_subscription_controller_source(controller_name: resolved_controller_name) }
    end

    def self.compose_subscription_controller(target, controller_name : String = DEFAULT_PUSH_SUBSCRIPTION_CONTROLLER_NAME) : Nil
      compose_push_subscription_controller(target, controller_name: controller_name)
    end

    def self.push_service_worker_source : String
      PushServiceWorkerSource.to_js
    end

    def self.push_subscription_controller_source(controller_name : String = DEFAULT_PUSH_SUBSCRIPTION_CONTROLLER_NAME) : String
      resolved_controller_name = resolve_controller_name(controller_name)
      String.build do |io|
        io << ::CrumbleWebPush::SubscriptionController.to_js
        io << '\n'
        io << '\n'
        io << "if (window.Stimulus && window.Stimulus.register) {\n"
        io << "window.Stimulus.register("
        io << resolved_controller_name.dump
        io << ", "
        io << ::CrumbleWebPush::SubscriptionController.to_js_ref
        io << ");\n"
        io << "}"
      end
    end

    def self.subscription_controller_source(controller_name : String = DEFAULT_PUSH_SUBSCRIPTION_CONTROLLER_NAME) : String
      push_subscription_controller_source(controller_name: controller_name)
    end

    def self.push_subscription_controller_values(endpoint_url : String, vapid_public_key : String) : Array(Stimulus::Value)
      [
        ::CrumbleWebPush::SubscriptionController.endpoint_url_value(resolve_required_value("endpoint_url", endpoint_url)),
        ::CrumbleWebPush::SubscriptionController.vapid_public_key_value(resolve_required_value("vapid_public_key", vapid_public_key)),
      ]
    end

    def self.subscription_controller_values(endpoint_url : String, vapid_public_key : String) : Array(Stimulus::Value)
      push_subscription_controller_values(endpoint_url: endpoint_url, vapid_public_key: vapid_public_key)
    end

    def self.resolve_required_value(field_name : String, value : String) : String
      resolved_value = value.strip
      raise ArgumentError.new("#{field_name} must not be empty") if resolved_value.empty?
      resolved_value
    end

    def self.resolve_controller_name(controller_name : String) : String
      resolved_name = controller_name.strip
      resolved_name.empty? ? DEFAULT_PUSH_SUBSCRIPTION_CONTROLLER_NAME : resolved_name
    end
  end
end
