require "set"

module Crumble::Web::Push::Client
  module Integration
    DEFAULT_SERVICE_WORKER_SCOPE                 = "/"
    DEFAULT_PUSH_SUBSCRIPTION_CONTROLLER_NAME    = "crumble-web-push--subscription"
    PUSH_SUBSCRIPTION_CONTROLLER_CLASS_NAME      = "CrumbleWebPushSubscriptionController"
    PUSH_SUBSCRIPTION_CONTROLLER_SOURCE_TEMPLATE = <<-JS
      (function() {
        if (!window.Stimulus || !window.Stimulus.register || typeof Controller === "undefined") {
          return;
        }

        class __CONTROLLER_CLASS__ extends Controller {
          connect() {
            this.dispatch("state", { detail: { code: "ready" } });
          }

          subscribe(event) {
            if (event) {
              event.preventDefault();
            }
            return this.processSubscriptionChange("subscribe");
          }

          unsubscribe(event) {
            if (event) {
              event.preventDefault();
            }
            return this.processSubscriptionChange("unsubscribe");
          }

          processSubscriptionChange(action) {
            if (!this.ensureSupport(action)) {
              return Promise.resolve(null);
            }

            const endpointUrl = __ENDPOINT_URL__;
            const vapidPublicKey = __VAPID_PUBLIC_KEY__;

            return navigator.serviceWorker.ready.then((registration) => {
              if (action === "subscribe") {
                return Notification.requestPermission().then((permission) => {
                  if (permission !== "granted") {
                    this.emitFailure(action, permission === "denied" ? "permission_denied" : "permission_not_granted", "Push permission was not granted.");
                    return null;
                  }

                  return registration.pushManager.getSubscription().then((existingSubscription) => {
                    if (existingSubscription) {
                      return existingSubscription;
                    }

                    return registration.pushManager.subscribe({
                      userVisibleOnly: true,
                      applicationServerKey: this.urlBase64ToUint8Array(vapidPublicKey)
                    });
                  });
                });
              }

              return registration.pushManager.getSubscription().then((existingSubscription) => {
                if (!existingSubscription) {
                  this.emitFailure(action, "subscription_missing", "No push subscription is currently active.");
                  return null;
                }

                return existingSubscription.unsubscribe().then(() => existingSubscription);
              });
            }).then((subscription) => {
              if (!subscription) {
                return null;
              }

              return this.postSubscriptionChange(endpointUrl, action, subscription).then(() => {
                this.dispatch("success", { detail: { action: action, subscription: this.subscriptionPayload(subscription) } });
                return subscription;
              });
            }).catch((error) => {
              this.emitFailure(action, error && error.code ? error.code : "unexpected_error", this.errorMessage(error));
              return null;
            });
          }

          ensureSupport(action) {
            if (!("Notification" in window) || !("serviceWorker" in navigator) || !("PushManager" in window)) {
              this.emitFailure(action, "unsupported_browser", "This browser does not support Web Push.");
              return false;
            }

            return true;
          }

          postSubscriptionChange(endpointUrl, action, subscription) {
            return fetch(endpointUrl, {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({ action: action, subscription: this.subscriptionPayload(subscription) })
            }).then((response) => {
              if (!response.ok) {
                return Promise.reject({ code: "sync_failed", message: "The subscription endpoint rejected the change." });
              }

              return response;
            });
          }

          subscriptionPayload(subscription) {
            if (subscription && subscription.toJSON) {
              return subscription.toJSON();
            }

            return subscription;
          }

          emitFailure(action, code, message) {
            this.dispatch("failure", { detail: { action: action, code: code, message: message } });
          }

          errorMessage(error) {
            if (!error) {
              return "Unexpected push subscription error.";
            }

            if (typeof error === "string") {
              return error;
            }

            if (error.message) {
              return error.message;
            }

            return "Unexpected push subscription error.";
          }

          urlBase64ToUint8Array(base64String) {
            const padding = "=".repeat((4 - (base64String.length % 4)) % 4);
            const normalizedBase64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/");
            const rawData = window.atob(normalizedBase64);
            const outputArray = new Uint8Array(rawData.length);

            for (let index = 0; index < rawData.length; index += 1) {
              outputArray[index] = rawData.charCodeAt(index);
            }

            return outputArray;
          }
        }

        window.Stimulus.register(__CONTROLLER_NAME__, __CONTROLLER_CLASS__);
      })();
    JS

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
      getter endpoint_url : String
      getter vapid_public_key : String
      getter controller_name : String

      def initialize(endpoint_url : String, vapid_public_key : String, controller_name : String = DEFAULT_PUSH_SUBSCRIPTION_CONTROLLER_NAME)
        @endpoint_url = Integration.resolve_required_value("endpoint_url", endpoint_url)
        @vapid_public_key = Integration.resolve_required_value("vapid_public_key", vapid_public_key)
        @controller_name = Integration.resolve_controller_name(controller_name)
      end

      def compose(target) : Nil
        Integration.compose_push_subscription_controller(target, endpoint_url: endpoint_url, vapid_public_key: vapid_public_key, controller_name: controller_name)
      end
    end

    def self.push_service_worker(scope : String = DEFAULT_SERVICE_WORKER_SCOPE) : PushServiceWorkerConnector
      PushServiceWorkerConnector.new(scope)
    end

    def self.push_subscription_controller(endpoint_url : String, vapid_public_key : String, controller_name : String = DEFAULT_PUSH_SUBSCRIPTION_CONTROLLER_NAME) : PushSubscriptionControllerConnector
      PushSubscriptionControllerConnector.new(endpoint_url: endpoint_url, vapid_public_key: vapid_public_key, controller_name: controller_name)
    end

    def self.subscription_controller(endpoint_url : String, vapid_public_key : String, controller_name : String = DEFAULT_PUSH_SUBSCRIPTION_CONTROLLER_NAME) : PushSubscriptionControllerConnector
      push_subscription_controller(endpoint_url: endpoint_url, vapid_public_key: vapid_public_key, controller_name: controller_name)
    end

    def self.compose_push_service_worker(target, scope : String = DEFAULT_SERVICE_WORKER_SCOPE) : Nil
      resolved_scope = scope.strip.empty? ? DEFAULT_SERVICE_WORKER_SCOPE : scope

      # Track registrations per composition object to keep this helper idempotent for each scope.
      scopes = @@registrations_by_target[target.object_id]
      return if scopes.includes?(resolved_scope)

      scopes << resolved_scope
      target.service_worker(scope: resolved_scope) { push_service_worker_source }
    end

    def self.compose_push_subscription_controller(target, endpoint_url : String, vapid_public_key : String, controller_name : String = DEFAULT_PUSH_SUBSCRIPTION_CONTROLLER_NAME) : Nil
      resolved_controller_name = resolve_controller_name(controller_name)

      # Keep controller registration idempotent for a given composition object + controller name.
      controller_names = @@subscription_controller_registrations_by_target[target.object_id]
      return if controller_names.includes?(resolved_controller_name)

      controller_names << resolved_controller_name
      target.stimulus_controller(resolved_controller_name) { push_subscription_controller_source(endpoint_url: endpoint_url, vapid_public_key: vapid_public_key, controller_name: resolved_controller_name) }
    end

    def self.compose_subscription_controller(target, endpoint_url : String, vapid_public_key : String, controller_name : String = DEFAULT_PUSH_SUBSCRIPTION_CONTROLLER_NAME) : Nil
      compose_push_subscription_controller(target, endpoint_url: endpoint_url, vapid_public_key: vapid_public_key, controller_name: controller_name)
    end

    def self.push_service_worker_source : String
      PushServiceWorkerSource.to_js
    end

    def self.push_subscription_controller_source(endpoint_url : String, vapid_public_key : String, controller_name : String = DEFAULT_PUSH_SUBSCRIPTION_CONTROLLER_NAME) : String
      resolved_controller_name = resolve_controller_name(controller_name)
      PUSH_SUBSCRIPTION_CONTROLLER_SOURCE_TEMPLATE.gsub("__CONTROLLER_CLASS__", PUSH_SUBSCRIPTION_CONTROLLER_CLASS_NAME).gsub("__CONTROLLER_NAME__", resolved_controller_name.dump).gsub("__ENDPOINT_URL__", resolve_required_value("endpoint_url", endpoint_url).dump).gsub("__VAPID_PUBLIC_KEY__", resolve_required_value("vapid_public_key", vapid_public_key).dump)
    end

    def self.subscription_controller_source(endpoint_url : String, vapid_public_key : String, controller_name : String = DEFAULT_PUSH_SUBSCRIPTION_CONTROLLER_NAME) : String
      push_subscription_controller_source(endpoint_url: endpoint_url, vapid_public_key: vapid_public_key, controller_name: controller_name)
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
