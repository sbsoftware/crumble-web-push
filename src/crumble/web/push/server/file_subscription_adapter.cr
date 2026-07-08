require "file_utils"
require "json"

module Crumble::Web::Push::Server
  class FileSubscriptionAdapter < SubscriptionAdapter
    @@mutex = Mutex.new

    @path : Path

    def initialize(path : String)
      @path = Path.new(path).normalize
    end

    def save(subscription : Subscription) : Nil
      synchronize do
        with_file_lock do
          subscriptions = load_subscriptions
          subscriptions[subscription.session_id] = subscription
          store_subscriptions(subscriptions)
        end
      end
    end

    def delete(session_id : String) : Bool
      synchronize do
        with_file_lock do
          subscriptions = load_subscriptions
          deleted_subscription = subscriptions.delete(session_id)
          store_subscriptions(subscriptions) if deleted_subscription
          !deleted_subscription.nil?
        end
      end
    end

    def get(session_id : String) : Subscription?
      synchronize do
        with_file_lock do
          load_subscriptions[session_id]?
        end
      end
    end

    private def synchronize(&)
      @@mutex.synchronize do
        yield
      end
    end

    private def with_file_lock(&)
      FileUtils.mkdir_p(@path.parent.to_s)
      File.open(lock_path, "a") do |file|
        raise "Failed to lock subscription storage file" unless LibC.flock(file.fd, LibC::FlockOp::EX) == 0

        begin
          yield
        ensure
          LibC.flock(file.fd, LibC::FlockOp::UN)
        end
      end
    end

    private def load_subscriptions : Hash(String, Subscription)
      return {} of String => Subscription unless File.exists?(@path)

      subscriptions = {} of String => Subscription
      JSON.parse(File.read(@path)).as_h.each do |session_id, payload|
        subscriptions[session_id] = Subscription.new(session_id: session_id, web_push_subscription: WebPush::Subscription.from_json(payload))
      end
      subscriptions
    end

    private def store_subscriptions(subscriptions : Hash(String, Subscription)) : Nil
      temp_path = "#{@path}.tmp.#{Process.pid}.#{object_id}"

      # Write to a sibling temp file first so readers never observe partially written JSON.
      File.open(temp_path, "w") do |io|
        JSON.build(io) do |json|
          json.object do
            subscriptions.each do |session_id, subscription|
              json.field session_id do
                subscription.web_push_subscription.to_json(json)
              end
            end
          end
        end
      end

      File.rename(temp_path, @path)
    ensure
      File.delete(temp_path) if temp_path && File.exists?(temp_path)
    end

    private def lock_path : String
      "#{@path}.lock"
    end
  end
end
