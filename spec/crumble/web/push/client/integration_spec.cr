require "../../../../spec_helper"

private class TestServiceWorkerComposition
  getter registrations = [] of NamedTuple(scope: String, source: String)

  def service_worker(scope : String, & : -> String) : Nil
    registrations << {scope: scope, source: yield}
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
end
