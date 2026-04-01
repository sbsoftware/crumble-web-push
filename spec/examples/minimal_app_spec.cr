require "../spec_helper"
require "../../examples/minimal_app/app"
require "../../lib/crumble/spec/test_request_context"

private EXAMPLE_TEST_PUBLIC_KEY  = "BNpReHjFgbvl8tsrMoRJl-eKTIhYQXUsVPgIMGB2AUUG-ufq4N6F4FRsBiphNVCrkXGB5EPExzQoa6Qzng0yxyU"
private EXAMPLE_TEST_PRIVATE_KEY = "79Om5Okowk6Tkd-1moexy7bIXuQQb5o2J9SWPq75Wnw"
private EXAMPLE_TEST_SUBJECT     = "mailto:admin@example.com"
private EXAMPLE_TEST_P256DH      = "BNnjgxL7iRJVGG2WfKoCcEas8uXFYFw4b6ivLqWsMp8pMhmdN3LRYQTyFWuE_MOCSD_OLdj2K2gtH3ggUe4nYeY"
private EXAMPLE_TEST_AUTH        = "KsWb025fekARlsIkDa5Vnw"

private struct ExampleCapturedRequest
  getter endpoint : String
  getter body : String

  def initialize(@endpoint : String, @body : String)
  end
end

private class ExampleStubPushEndpoint
  def initialize(@status_code : Int32, @response_body : String = %({"status":"ok"}))
  end

  def response : HTTP::Client::Response
    HTTP::Client::Response.new(@status_code, body: @response_body)
  end
end

private class ExampleStubSenderClient < WebPush::Client
  getter requests = [] of ExampleCapturedRequest

  def initialize(@stub_push_endpoint : ExampleStubPushEndpoint)
    super(WebPush::VapidConfig.new(public_key: EXAMPLE_TEST_PUBLIC_KEY, private_key: EXAMPLE_TEST_PRIVATE_KEY, subject: EXAMPLE_TEST_SUBJECT))
  end

  private def send_request(request : WebPush::PushRequest) : HTTP::Client::Response
    @requests << ExampleCapturedRequest.new(endpoint: request.endpoint, body: request.body)
    @stub_push_endpoint.response
  end
end

describe Crumble::Web::Push::Examples::MinimalApp do
  after_each do
    Crumble::Web::Push::Server::Integration.reset!
  end

  it "renders the example page with the integration-owned worker, subscription controls, and test push form" do
    previous_vapid_key = ENV[Crumble::Web::Push::Client::Integration::VAPID_PUBLIC_KEY_ENV]?
    begin
      ENV[Crumble::Web::Push::Client::Integration::VAPID_PUBLIC_KEY_ENV] = EXAMPLE_TEST_PUBLIC_KEY
      Crumble::Web::Push::Examples::MinimalApp.configure!(adapter: Crumble::Web::Push::Examples::MinimalApp::MemorySubscriptionAdapter.new, sender: Crumble::Web::Push::Server::Integration.sender(ExampleStubSenderClient.new(ExampleStubPushEndpoint.new(201))))

      html = String.build do |io|
        ctx = Crumble::Server::TestRequestContext.new(response_io: io, resource: Crumble::Web::Push::Examples::MinimalApp::NotificationsPage.uri_path)
        Crumble::Web::Push::Examples::MinimalApp::NotificationsPage.handle(ctx).should eq(true)
        ctx.response.flush
      end

      html.should contain(%(data-controller="crumble-web-push--subscription"))
      html.should contain(%(data-crumble-web-push--subscription-endpoint-url-value="#{Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource.uri_path}"))
      html.should contain(%(data-crumble-web-push--subscription-vapid-public-key-value="#{EXAMPLE_TEST_PUBLIC_KEY}"))
      html.should contain("navigator.serviceWorker.register")
      html.should contain(%(navigator.serviceWorker.register("/service_worker.js", {scope: "/"})))
      html.should contain(%(click->crumble-web-push--subscription#subscribe))
      html.should contain(%(click->crumble-web-push--subscription#unsubscribe))
      html.should contain(%(action="#{Crumble::Web::Push::Examples::MinimalApp::TestPushesResource.uri_path}"))
    ensure
      if previous_vapid_key.nil?
        ENV.delete(Crumble::Web::Push::Client::Integration::VAPID_PUBLIC_KEY_ENV)
      else
        ENV[Crumble::Web::Push::Client::Integration::VAPID_PUBLIC_KEY_ENV] = previous_vapid_key
      end
    end
  end

  it "supports the local subscribe then send test-push flow" do
    adapter = Crumble::Web::Push::Examples::MinimalApp::MemorySubscriptionAdapter.new
    client = ExampleStubSenderClient.new(ExampleStubPushEndpoint.new(201))
    Crumble::Web::Push::Examples::MinimalApp.configure!(adapter: adapter, sender: Crumble::Web::Push::Server::Integration.sender(client))
    session_store = Crumble::Server::MemorySessionStore.new
    subscribe_body = %({"action":"subscribe","subscription":{"endpoint":"https://push.example/test","keys":{"auth":"#{EXAMPLE_TEST_AUTH}","p256dh":"#{EXAMPLE_TEST_P256DH}"}}})
    session_cookie = nil

    subscribe_response = IO::Memory.new
    ctx = Crumble::Server::TestRequestContext.new(response_io: subscribe_response, session_store: session_store, resource: Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource.uri_path, method: "POST", body: subscribe_body)
    Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource.handle(ctx)
    ctx.response.close
    ctx.response.status_code.should eq(204)
    session_cookie = ctx.response.cookies.first?

    test_push_response = IO::Memory.new
    headers = HTTP::Headers{"Cookie" => "#{session_cookie.not_nil!.name}=#{session_cookie.not_nil!.value}"}
    ctx = Crumble::Server::TestRequestContext.new(response_io: test_push_response, session_store: session_store, headers: headers, resource: Crumble::Web::Push::Examples::MinimalApp::TestPushesResource.uri_path, method: "POST")
    Crumble::Web::Push::Examples::MinimalApp::TestPushesResource.handle(ctx).should eq(true)
    ctx.response.close
    ctx.response.status_code.should eq(200)

    test_push_response.rewind
    parsed = JSON.parse(HTTP::Client::Response.from_io(test_push_response).body)
    parsed["delivered"].as_i.should eq(1)
    parsed["failed"].as_i.should eq(0)
    parsed["outcomes"].as_a.first["endpoint"].as_s.should eq("https://push.example/test")
    client.requests.map(&.endpoint).should eq(["https://push.example/test"])
    client.requests.first.body.bytesize.should be > 0
  end
end
