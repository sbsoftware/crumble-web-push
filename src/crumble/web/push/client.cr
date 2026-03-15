require "set"

module Crumble::Web::Push::Client
  module Integration
    DEFAULT_SERVICE_WORKER_SCOPE = "/"
    PUSH_SERVICE_WORKER_SOURCE   = <<-JS
      self.addEventListener("push", function(event) {
        if (!event || !event.data) { return; }
        var payload = {};
        try {
          payload = event.data.json();
        } catch (error) {
          payload = { title: event.data.text() };
        }
        self.registration.showNotification(payload.title || "Notification", {
          body: payload.body || "",
          icon: payload.icon,
          data: payload.data
        });
      });

      self.addEventListener("notificationclick", function(event) {
        event.notification.close();
        event.waitUntil(clients.matchAll({ type: "window", includeUncontrolled: true }).then(function(client_list) {
          if (client_list.length > 0) { return client_list[0].focus(); }
          return clients.openWindow("/");
        }));
      });
    JS

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
      PUSH_SERVICE_WORKER_SOURCE
    end
  end
end
