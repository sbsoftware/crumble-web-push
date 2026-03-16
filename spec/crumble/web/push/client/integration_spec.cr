require "../../../../spec_helper"

private class TestServiceWorkerComposition
  getter registrations = [] of NamedTuple(scope: String, source: String)

  def service_worker(scope : String, & : -> String) : Nil
    registrations << {scope: scope, source: yield}
  end
end

private class TestStimulusControllerComposition
  getter registrations = [] of NamedTuple(controller_name: String, source: String)

  def stimulus_controller(controller_name : String, & : -> String) : Nil
    registrations << {controller_name: controller_name, source: yield}
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

  it "composes a stimulus controller source built with stimulus.cr values" do
    composition = TestStimulusControllerComposition.new
    Crumble::Web::Push::Client::Integration.compose_push_subscription_controller(composition)

    composition.registrations.map(&.[:controller_name]).should eq(["crumble-web-push--subscription"])
    source = composition.registrations.first[:source]
    source.should contain("static values = {endpointUrl: String, vapidPublicKey: String};")
    source.should contain("Notification.requestPermission()")
    source.should contain("registration.pushManager.subscribe")
    source.should contain("registration.pushManager.getSubscription()")
    source.should contain("this.endpointUrlValue")
    source.should contain("this.vapidPublicKeyValue")
    source.should contain("this.hasEndpointUrlValue")
    source.should contain("window.Stimulus.register(\"crumble-web-push--subscription\"")
    source.should contain("Promise.reject({code: \"sync_failed\"")
    source.should_not contain("/push/subscriptions")
    source.should_not contain("BKf6v4Nf3F9")
  end

  it "exposes endpoint and vapid configuration as stimulus values" do
    values = Crumble::Web::Push::Client::Integration.push_subscription_controller_values(endpoint_url: "/push/subscriptions", vapid_public_key: "BKf6v4Nf3F9")

    values.map(&.attr_name).should eq(["data-crumble-web-push--subscription-endpoint-url-value", "data-crumble-web-push--subscription-vapid-public-key-value"])
    values.map(&.value).should eq(["/push/subscriptions", "BKf6v4Nf3F9"])
  end

  it "supports custom controller names via the connector helper" do
    composition = TestStimulusControllerComposition.new
    Crumble::Web::Push::Client::Integration.push_subscription_controller(controller_name: "notifications--subscription").compose(composition)

    composition.registrations.map(&.[:controller_name]).should eq(["notifications--subscription"])
    composition.registrations.first[:source].should contain("window.Stimulus.register(\"notifications--subscription\"")
  end

  it "prevents competing stimulus controller registrations for the same name on the same composition" do
    composition = TestStimulusControllerComposition.new

    Crumble::Web::Push::Client::Integration.compose_push_subscription_controller(composition)
    Crumble::Web::Push::Client::Integration.compose_push_subscription_controller(composition)
    Crumble::Web::Push::Client::Integration.push_subscription_controller.compose(composition)
    Crumble::Web::Push::Client::Integration.push_subscription_controller(controller_name: "notifications--subscription").compose(composition)
    Crumble::Web::Push::Client::Integration.compose_subscription_controller(composition, controller_name: "notifications--subscription")

    composition.registrations.map(&.[:controller_name]).should eq(["crumble-web-push--subscription", "notifications--subscription"])
  end

  it "rejects blank endpoint or vapid key values" do
    expect_raises(ArgumentError, "endpoint_url must not be empty") { Crumble::Web::Push::Client::Integration.push_subscription_controller_values(endpoint_url: " ", vapid_public_key: "BKf6v4Nf3F9") }
    expect_raises(ArgumentError, "vapid_public_key must not be empty") { Crumble::Web::Push::Client::Integration.push_subscription_controller_values(endpoint_url: "/push/subscriptions", vapid_public_key: " ") }
  end
end
