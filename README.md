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

## Usage

```crystal
require "crumble-web-push"
```

`crumble-web-push` provides:
- `Crumble::Web::Push::Client::Integration`
- `Crumble::Web::Push::Server::Integration`
- `Crumble::Web::Push::Server::Integration::Sender`
- `Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource`
- `Crumble::Web::Push::Server::SubscriptionAdapter`
- `Crumble::Web::Push::Server::SubscriptionContract`

### Push service worker connector

Use `Crumble::Web::Push::Client::Integration` to compose a push-capable service worker into Crumble's `service_worker(scope: "/") { ... }` pipeline:

```crystal
Crumble::Web::Push::Client::Integration.compose_push_service_worker(app_composition)
```

The default scope is `/`. You can override scope per connector:

```crystal
Crumble::Web::Push::Client::Integration.push_service_worker(scope: "/notifications").compose(app_composition)
```

Repeated composition for the same scope is idempotent and will not create competing registrations.

### Push subscription controller

This shard defines `CrumbleWebPush::SubscriptionController` via `stimulus_controller` and automatically attaches it to the `body` tag of `ToHtml::Layout`.

The shard also adds default body-level Stimulus values automatically:
- `endpoint_url` points at `Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource`
- `vapid_public_key` reads `ENV["CRUMBLE_WEB_PUSH_VAPID_PUBLIC_KEY"]` and defaults to an empty string

```crystal
ENV["CRUMBLE_WEB_PUSH_VAPID_PUBLIC_KEY"] = "your-vapid-public-key"
```

### Storage adapter interface

Use `Crumble::Web::Push::Server::SubscriptionAdapter` to plug in any persistence backend:

```crystal
abstract class Crumble::Web::Push::Server::SubscriptionAdapter
  abstract def save(subscription : Subscription) : Nil
  abstract def delete(user_id : String, device_id : String) : Bool
  abstract def list_by_user(user_id : String) : Array(Subscription)
  abstract def list_by_device(device_id : String) : Array(Subscription)
end
```

The shard intentionally does not ship a DB implementation.

Stored adapter entries wrap the upstream `WebPush::Subscription` while adding `user_id` and `device_id` for application-level ownership.

### Server-side sender facade

Use `Crumble::Web::Push::Server::Integration.sender` to bridge stored subscriptions into `WebPush::Client#send`:

```crystal
client = WebPush::Client.new(
  WebPush::VapidConfig.new(
    public_key: ENV["WEB_PUSH_PUBLIC_KEY"],
    private_key: ENV["WEB_PUSH_PRIVATE_KEY"],
    subject: "mailto:admin@example.com"
  )
)

sender = Crumble::Web::Push::Server::Integration.sender(adapter, client)
outcomes = sender.send_to_user("user-1", %({"title":"Hello"}), ttl: 60)

outcomes.each do |outcome|
  next unless outcome.cleanup?
  adapter.delete(outcome.subscription.user_id, outcome.subscription.device_id)
end
```

The facade converts `Crumble::Web::Push::Server::Subscription` entries into `WebPush::Subscription` values and exposes `WebPush::Client::SendResult` helpers like `cleanup?` and `retryable?` through each returned outcome.

### Subscription endpoint resource

`Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource` is the default endpoint used by the Stimulus controller. Configure it with your adapter plus a request-to-identity resolver:

```crystal
Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource.configure(adapter) do |ctx|
  Crumble::Web::Push::Server::Integration::SubscriptionEndpointResource::RequestIdentity.new(
    user_id: ctx.session.user_id.to_s,
    device_id: ctx.request.headers["X-Device-Id"]
  )
end
```

The browser posts `{action, subscription}` to this resource, and the resource resolves `user_id` / `device_id` server-side before calling the adapter.

### Subscription endpoint payload contract

`Crumble::Web::Push::Server::SubscriptionContract` validates and parses endpoint payloads:
- `parse_create(body : String)` for create payloads
- `parse_update(body : String)` for update payloads
- `parse_delete(body : String)` for delete payloads

Create/update payload:

```json
{
  "user_id": "user-1",
  "device_id": "device-1",
  "endpoint": "https://push.example/subscription",
  "keys": {
    "auth": "base64-auth",
    "p256dh": "base64-p256dh"
  }
}
```

Delete payload:

```json
{
  "user_id": "user-1",
  "device_id": "device-1"
}
```

`userId`/`deviceId` camelCase keys are also accepted for browser-facing payloads.

## Contributing

1. Fork it (<https://github.com/your-github-user/crumble-web-push/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Stefan Bilharz](https://github.com/your-github-user) - creator and maintainer
