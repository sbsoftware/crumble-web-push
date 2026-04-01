require "../../../../spec_helper"
require "../../../../../lib/crumble/spec/test_handler_context"

private class TestLayout < ToHtml::Layout
  getter ctx : Crumble::Server::HandlerContext = test_handler_context

  def window_title
    "Push Client Integration Spec"
  end
end

describe Crumble::Web::Push::Client::Integration do
  it "emits a stimulus controller source built with stimulus.cr values" do
    source = CrumbleWebPush::SubscriptionController.to_js
    source.should contain("static values = {endpointUrl: String, vapidPublicKey: String};")
    source.should contain("Notification.requestPermission()")
    source.should contain("registration.pushManager.subscribe")
    source.should contain("registration.pushManager.getSubscription()")
    source.should contain("this.endpointUrlValue")
    source.should contain("this.vapidPublicKeyValue")
    source.should contain("this.hasEndpointUrlValue")
    source.should contain("Promise.reject({code: \"sync_failed\"")
    source.should_not contain("dispatch(\"")
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
      html.should contain(%(data-crumble-web-push--subscription-endpoint-url-value="#{Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource.root_path}"))
      html.should contain(%(data-crumble-web-push--subscription-vapid-public-key-value="BKf6v4Nf3F9"))
      html.should contain(%(navigator.serviceWorker.register("/service_worker.js", {scope: "/"})))
    ensure
      if previous_vapid_key.nil?
        ENV.delete(Crumble::Web::Push::Client::Integration::VAPID_PUBLIC_KEY_ENV)
      else
        ENV[Crumble::Web::Push::Client::Integration::VAPID_PUBLIC_KEY_ENV] = previous_vapid_key
      end
    end
  end
end
