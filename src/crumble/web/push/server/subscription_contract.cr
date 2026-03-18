require "json"

module Crumble::Web::Push::Server::SubscriptionContract
  enum SyncAction
    Subscribe
    Unsubscribe
  end

  class ValidationError < Exception
    getter errors : Array(String)

    def initialize(@errors : Array(String))
      super(errors.join(", "))
    end
  end

  struct UpsertPayload
    getter session_id : String
    getter endpoint : String
    getter auth : String
    getter p256dh : String

    def initialize(@session_id : String, @endpoint : String, @auth : String, @p256dh : String)
      validate!
    end

    def to_subscription : Subscription
      Subscription.new(session_id: session_id, web_push_subscription: WebPush::Subscription.new(endpoint: endpoint, p256dh: p256dh, auth: auth))
    end

    private def validate!
      raise ValidationError.new(validation_errors) unless validation_errors.empty?
    end

    private def validation_errors : Array(String)
      errors = [] of String
      errors << "session_id is required" if session_id.strip.empty?
      errors << "endpoint is required" if endpoint.strip.empty?
      errors << "keys.auth is required" if auth.strip.empty?
      errors << "keys.p256dh is required" if p256dh.strip.empty?
      errors
    end
  end

  alias CreatePayload = UpsertPayload
  alias UpdatePayload = UpsertPayload

  struct DeletePayload
    getter session_id : String

    def initialize(@session_id : String)
      validate!
    end

    private def validate!
      raise ValidationError.new(validation_errors) unless validation_errors.empty?
    end

    private def validation_errors : Array(String)
      errors = [] of String
      errors << "session_id is required" if session_id.strip.empty?
      errors
    end
  end

  struct SyncPayload
    getter action : SyncAction
    getter web_push_subscription : WebPush::Subscription

    def initialize(@action : SyncAction, @web_push_subscription : WebPush::Subscription)
    end

    def to_subscription(session_id : String) : Subscription
      Subscription.new(session_id: session_id, web_push_subscription: web_push_subscription)
    end
  end

  def self.parse_create(body : String) : CreatePayload
    parse_upsert(parse_json(body))
  end

  def self.parse_update(body : String) : UpdatePayload
    parse_upsert(parse_json(body))
  end

  def self.parse_delete(body : String) : DeletePayload
    parse_delete_payload(parse_json(body))
  end

  def self.parse_sync(body : String) : SyncPayload
    parse_sync_payload(parse_json(body))
  end

  private def self.parse_json(body : String) : JSON::Any
    JSON.parse(body)
  rescue ex : JSON::ParseException
    raise ValidationError.new(["request body must be valid JSON"])
  end

  private def self.parse_upsert(payload : JSON::Any) : UpsertPayload
    UpsertPayload.new(
      read_string(payload, "session_id", "sessionId"),
      read_string(payload, "endpoint"),
      read_string(read_hash(payload, "keys"), "auth"),
      read_string(read_hash(payload, "keys"), "p256dh")
    )
  end

  private def self.parse_delete_payload(payload : JSON::Any) : DeletePayload
    DeletePayload.new(read_string(payload, "session_id", "sessionId"))
  end

  private def self.parse_sync_payload(payload : JSON::Any) : SyncPayload
    SyncPayload.new(read_sync_action(payload), read_web_push_subscription(payload, "subscription"))
  end

  private def self.read_sync_action(payload : JSON::Any) : SyncAction
    case read_string(payload, "action")
    when "subscribe"   then SyncAction::Subscribe
    when "unsubscribe" then SyncAction::Unsubscribe
    else
      raise ValidationError.new(["action must be subscribe or unsubscribe"])
    end
  end

  private def self.read_web_push_subscription(payload : JSON::Any, key : String) : WebPush::Subscription
    WebPush::Subscription.from_json(read_hash(payload, key))
  rescue ex : WebPush::ValidationError
    raise ValidationError.new([ex.message || "#{key} is invalid"])
  end

  private def self.read_hash(payload : JSON::Any, key : String) : JSON::Any
    value = payload[key]?
    raise ValidationError.new(["#{key} is required"]) if value.nil?
    raise ValidationError.new(["#{key} must be an object"]) if value.as_h?.nil?
    value
  end

  # Accept both snake_case and camelCase keys to keep the contract stable for Crystal and browser clients.
  private def self.read_string(payload : JSON::Any, key : String, fallback_key : String? = nil) : String
    value = payload[key]? || fallback_key.try { |fallback| payload[fallback]? }
    raise ValidationError.new(["#{key} is required"]) if value.nil?

    string_value = value.as_s?
    raise ValidationError.new(["#{key} must be a string"]) if string_value.nil?
    string_value
  end
end
