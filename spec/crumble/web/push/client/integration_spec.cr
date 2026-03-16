require "../../../../spec_helper"
require "../../../../../lib/crumble/spec/test_handler_context"

private class TestServiceWorkerComposition
  getter registrations = [] of NamedTuple(scope: String, source: String)

  def service_worker(scope : String, & : -> String) : Nil
    registrations << {scope: scope, source: yield}
  end
end

private class TestLayout < ToHtml::Layout
  getter ctx : Crumble::Server::HandlerContext = test_handler_context

  def window_title
    "Push Client Integration Spec"
  end
end

describe Crumble::Web::Push::Client::Integration do
  it "composes push worker registration for the default scope" do
    composition = TestServiceWorkerComposition.new
    Crumble::Web::Push::Client::Integration.compose_push_service_worker(composition)

    composition.registrations.map(&.[:scope]).should eq(["/"])
    composition.registrations.first[:source].should contain("self.addEventListener(\"push\"")
    composition.registrations.first[:source].should contain("self.registration.showNotification")
  end

  it "supports overriding the push worker scope via connector helper" do
    composition = TestServiceWorkerComposition.new
    Crumble::Web::Push::Client::Integration.push_service_worker(scope: "/notifications").compose(composition)

    composition.registrations.map(&.[:scope]).should eq(["/notifications"])
  end

  it "prevents competing registrations for the same scope on the same composition" do
    composition = TestServiceWorkerComposition.new

    Crumble::Web::Push::Client::Integration.compose_push_service_worker(composition)
    Crumble::Web::Push::Client::Integration.compose_push_service_worker(composition)
    Crumble::Web::Push::Client::Integration.push_service_worker.compose(composition)
    Crumble::Web::Push::Client::Integration.push_service_worker(scope: "/notifications").compose(composition)
    Crumble::Web::Push::Client::Integration.compose_push_service_worker(composition, scope: "/notifications")

    composition.registrations.map(&.[:scope]).should eq(["/", "/notifications"])
  end

  it "emits a stimulus controller source built with stimulus.cr values" do
    source = Crumble::Web::Push::Client::Integration.subscription_controller_source
    source.should contain("static values = {endpointUrl: String, vapidPublicKey: String};")
    source.should contain("Notification.requestPermission()")
    source.should contain("registration.pushManager.subscribe")
    source.should contain("registration.pushManager.getSubscription()")
    source.should contain("this.endpointUrlValue")
    source.should contain("this.vapidPublicKeyValue")
    source.should contain("this.hasEndpointUrlValue")
    source.should contain("Promise.reject({code: \"sync_failed\"")
    source.should_not contain("/__crumble_web_push_subscriptions__")
  end

  it "automatically adds the subscription controller and default values to the layout body" do
    previous_vapid_key = ENV[Crumble::Web::Push::Client::Integration::VAPID_PUBLIC_KEY_ENV]?
    begin
      ENV[Crumble::Web::Push::Client::Integration::VAPID_PUBLIC_KEY_ENV] = "BKf6v4Nf3F9"

      html = String.build do |io|
        TestLayout.new(ctx: test_handler_context).to_html(io) { |_inner_io, _indent_level| }
      end

      html.should contain(%(data-controller="crumble-web-push--subscription"))
      html.should contain(%(data-crumble-web-push--subscription-endpoint-url-value="/__crumble_web_push_subscriptions__"))
      html.should contain(%(data-crumble-web-push--subscription-vapid-public-key-value="BKf6v4Nf3F9"))
    ensure
      if previous_vapid_key.nil?
        ENV.delete(Crumble::Web::Push::Client::Integration::VAPID_PUBLIC_KEY_ENV)
      else
        ENV[Crumble::Web::Push::Client::Integration::VAPID_PUBLIC_KEY_ENV] = previous_vapid_key
      end
    end
  end

  it "exposes the default endpoint stub and env-backed vapid key as stimulus values" do
    previous_vapid_key = ENV[Crumble::Web::Push::Client::Integration::VAPID_PUBLIC_KEY_ENV]?
    begin
      ENV[Crumble::Web::Push::Client::Integration::VAPID_PUBLIC_KEY_ENV] = "BKf6v4Nf3F9"

      values = Crumble::Web::Push::Client::Integration.subscription_controller_values
      values.map(&.attr_name).should eq({"data-crumble-web-push--subscription-endpoint-url-value", "data-crumble-web-push--subscription-vapid-public-key-value"})
      values.map(&.value).should eq({"/__crumble_web_push_subscriptions__", "BKf6v4Nf3F9"})
    ensure
      if previous_vapid_key.nil?
        ENV.delete(Crumble::Web::Push::Client::Integration::VAPID_PUBLIC_KEY_ENV)
      else
        ENV[Crumble::Web::Push::Client::Integration::VAPID_PUBLIC_KEY_ENV] = previous_vapid_key
      end
    end
  end
end
