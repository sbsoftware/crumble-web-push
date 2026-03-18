# crumble-web-push

Bridge shard that wires Crumble applications to generic Web Push primitives.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     crumble-web-push:
       github: your-github-user/crumble-web-push
   ```

2. Run `shards install`

3. Require the shard:

   ```crystal
   require "crumble-web-push"
   ```

## Setup Checklist

- Generate one VAPID key pair and keep it stable for active subscriptions.
- Set `CRUMBLE_WEB_PUSH_VAPID_PUBLIC_KEY` for the browser-facing controller.
- Configure a `Crumble::Web::Push::Server::SubscriptionAdapter` for persistence.
- Build a `WebPush::Client` with your VAPID public key, private key, and subject.
- Trigger sends through `Crumble::Web::Push::Server::Integration.sender(...)`.
- Remove stored subscriptions when a send outcome reports `cleanup?`.

## Responsibilities

`crumble-web-push` owns the Crumble-facing integration points:
- service worker source generation through `Crumble::Web::Push::Client::Integration`
- the Stimulus subscription controller attached to `ToHtml::Layout`
- the default subscription sync endpoint at `Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource`
- adapting stored Crumble subscriptions into `WebPush::Client#send` via `Crumble::Web::Push::Server::Integration::Sender`

`web-push` owns the delivery primitives:
- `WebPush::Subscription` parsing and validation
- `WebPush::VapidConfig` and auth headers
- `WebPush::Client#send`
- provider response semantics such as invalid-subscription cleanup and retryability

## Minimal Example

A runnable local example lives in `examples/minimal_app/`:

- `examples/minimal_app/app.cr` defines the page, the test-push resource, the in-memory adapter, and the worker registration bridge.
- `examples/minimal_app/run.cr` boots the example with env-based VAPID config.

Start it locally with:

```bash
export CRUMBLE_WEB_PUSH_VAPID_PUBLIC_KEY=...
export CRUMBLE_WEB_PUSH_VAPID_PRIVATE_KEY=...
export CRUMBLE_WEB_PUSH_VAPID_SUBJECT=mailto:admin@example.com
crystal run examples/minimal_app/run.cr -- --port 3000
```

Then open `http://localhost:3000/push_example`.

The example shows the complete local flow:
1. The client connector composes a push-capable worker and registers it in the example layout.
2. The body-level Stimulus controller posts subscribe/unsubscribe changes to `SubscriptionEndpointResource`.
3. `TestPushesResource` loads the current session's stored subscription and sends a test push through the sender facade.

## API Overview

### Push worker connector

Use `Crumble::Web::Push::Client::Integration` to compose the push worker into an app-level composition target that implements `service_worker(scope : String, & : -> String)`:

```crystal
Crumble::Web::Push::Client::Integration.push_service_worker.compose(app_composition)
```

Override the scope when needed:

```crystal
Crumble::Web::Push::Client::Integration.push_service_worker(scope: "/notifications").compose(app_composition)
```

### Subscription controller

The shard defines `CrumbleWebPush::SubscriptionController` and automatically attaches it to the `body` tag of `ToHtml::Layout`.

Default body-level values:
- `endpoint_url` points at `Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource`
- `vapid_public_key` reads `ENV["CRUMBLE_WEB_PUSH_VAPID_PUBLIC_KEY"]` and defaults to `""`

Buttons or links can trigger the controller directly:

```crystal
button CrumbleWebPush::SubscriptionController.subscribe_action("click"), type: "button" do
  "Subscribe"
end
```

### Storage adapter

Use `Crumble::Web::Push::Server::SubscriptionAdapter` to plug in any persistence backend:

```crystal
abstract class Crumble::Web::Push::Server::SubscriptionAdapter
  abstract def save(subscription : Subscription) : Nil
  abstract def delete(session_id : String) : Bool
  abstract def list_by_session(session_id : String) : Array(Subscription)
end
```

The shard intentionally does not ship a database implementation.

### Sender facade

Use `Crumble::Web::Push::Server::Integration.sender` to bridge stored subscriptions into `WebPush::Client#send`:

```crystal
client = WebPush::Client.new(
  WebPush::VapidConfig.new(
    public_key: ENV["CRUMBLE_WEB_PUSH_VAPID_PUBLIC_KEY"],
    private_key: ENV["CRUMBLE_WEB_PUSH_VAPID_PRIVATE_KEY"],
    subject: ENV["CRUMBLE_WEB_PUSH_VAPID_SUBJECT"]
  )
)

Crumble::Web::Push::Server::Integration.subscription_adapter = adapter
sender = Crumble::Web::Push::Server::Integration.sender(client)
outcomes = sender.send_to_session("session-id", %({"title":"Hello"}), ttl: 60)

outcomes.each do |outcome|
  adapter.delete(outcome.subscription.session_id) if outcome.cleanup?
end
```

Each outcome exposes the upstream `WebPush::Client::SendResult` helpers through:
- `sent?`
- `cleanup?`
- `retryable?`
- `status_code`
- `error_message`

### Subscription endpoint

Point the shared integration adapter at your persistence backend:

```crystal
Crumble::Web::Push::Server::Integration.subscription_adapter = adapter
```

The browser posts `{action, subscription}` to `Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource`, and the resource always stores the current `ctx.session.id.to_s` as the subscription owner.

## Development

- Install dependencies: `shards install`
- Run specs: `crystal spec`
- Format code: `crystal tool format`
