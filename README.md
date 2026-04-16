# crumble-web-push

`crumble-web-push` adds a session-scoped subscription endpoint and sender flow for `crumble` apps using [`web-push`](https://github.com/sbsoftware/web-push).

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     crumble-web-push:
       github: sbsoftware/crumble-web-push
   ```

2. Run `shards install`

## Usage

```crystal
require "crumble-web-push"
```

### Store subscriptions with the built-in in-memory adapter

`Crumble::Web::Push::Server::InMemorySubscriptionAdapter` stores one subscription per session ID inside the current process:

```crystal
adapter = Crumble::Web::Push::Server::InMemorySubscriptionAdapter.new
subscription = Crumble::Web::Push::Subscription.from_json(subscription_json)

adapter.save("session-123", subscription)
adapter.get("session-123") # => subscription
adapter.delete("session-123") # => true
```

This adapter is process-local and non-durable. It works for development and simple single-process deployments, but subscriptions are lost on process restarts.

### Expose a subscription endpoint

Subclass `SubscriptionResource` and return the adapter you want to use:

```crystal
class PushSubscriptionResource < Crumble::Web::Push::Server::SubscriptionResource
  root_path "/push/subscription"

  ADAPTER = Crumble::Web::Push::Server::InMemorySubscriptionAdapter.new

  def subscription_adapter : Crumble::Web::Push::Server::SubscriptionAdapter
    ADAPTER
  end
end
```

`POST /push/subscription` stores or replaces the current session’s subscription, `GET` returns the current session’s stored subscription as JSON, and `DELETE` removes it.

### Send to the current session

```crystal
adapter = PushSubscriptionResource::ADAPTER
client = WebPush::Client.new(vapid_config)
sender = Crumble::Web::Push::Server::Sender.new(client, adapter)

if result = sender.send(ctx.session.id.to_s, %({"title":"Hello"}), ttl: 60)
  puts result.status_code
end
```

`Sender` now uses `SubscriptionAdapter#get(session_id)` because the adapter contract stores at most one subscription per session. If the push provider reports an invalid subscription (`404` / `410`), the sender removes it from the adapter.

## Development

- Install dependencies with `shards install`
- Run specs with `crystal spec`
- Format with `crystal tool format`

## Contributing

1. Fork it (<https://github.com/sbsoftware/crumble-web-push/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Stefan Bilharz](https://github.com/stefan-bilharz) - creator and maintainer
