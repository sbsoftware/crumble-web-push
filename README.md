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

`crumble-web-push` currently provides only a bootstrap integration surface:
- `Crumble::Web::Push::Client::Integration`
- `Crumble::Web::Push::Server::Integration`

No push protocol or delivery logic is implemented yet.

## Contributing

1. Fork it (<https://github.com/your-github-user/crumble-web-push/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Stefan Bilharz](https://github.com/your-github-user) - creator and maintainer
