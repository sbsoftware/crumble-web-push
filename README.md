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

### Push subscription controller connector

Use `Crumble::Web::Push::Client::Integration` to compose a Stimulus controller that handles permission requests, subscribe/unsubscribe, and endpoint synchronization:

```crystal
Crumble::Web::Push::Client::Integration.compose_push_subscription_controller(app_composition)
```

Configure the endpoint URL and VAPID public key as Stimulus values on the element using the controller:

```crystal
div CrumbleWebPush::SubscriptionController,
  *Crumble::Web::Push::Client::Integration.push_subscription_controller_values(
    endpoint_url: "/push/subscriptions",
    vapid_public_key: ENV["VAPID_PUBLIC_KEY"]
  ),
  CrumbleWebPush::SubscriptionController.subscribe_action("click") do
  "Enable notifications"
end
```

The generated controller dispatches predictable Stimulus events for app-level UX handling:
- `success` with `detail.action` + `detail.subscription`
- `failure` with `detail.action` + `detail.code` + `detail.message`
- `state` with `detail.code = "ready"` on connect

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
