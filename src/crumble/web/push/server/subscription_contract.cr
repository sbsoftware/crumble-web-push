require "json"

module Crumble::Web::Push::Server::SubscriptionContract
  class ValidationError < Exception
    getter errors : Array(String)

    def initialize(@errors : Array(String))
      super(errors.join(", "))
    end
  end

  struct UpsertPayload
    getter user_id : String
    getter device_id : String
    getter endpoint : String
    getter auth : String
    getter p256dh : String

    def initialize(@user_id : String, @device_id : String, @endpoint : String, @auth : String, @p256dh : String)
      validate!
    end

    def to_subscription : Subscription
      Subscription.new(user_id: user_id, device_id: device_id, endpoint: endpoint, keys: SubscriptionKeys.new(auth: auth, p256dh: p256dh))
    end

    private def validate!
      raise ValidationError.new(validation_errors) unless validation_errors.empty?
    end

    private def validation_errors : Array(String)
      errors = [] of String
      errors << "user_id is required" if user_id.strip.empty?
      errors << "device_id is required" if device_id.strip.empty?
      errors << "endpoint is required" if endpoint.strip.empty?
      errors << "keys.auth is required" if auth.strip.empty?
      errors << "keys.p256dh is required" if p256dh.strip.empty?
      errors
    end
  end

  alias CreatePayload = UpsertPayload
  alias UpdatePayload = UpsertPayload

  struct DeletePayload
    getter user_id : String
    getter device_id : String

    def initialize(@user_id : String, @device_id : String)
      validate!
    end

    private def validate!
      raise ValidationError.new(validation_errors) unless validation_errors.empty?
    end

    private def validation_errors : Array(String)
      errors = [] of String
      errors << "user_id is required" if user_id.strip.empty?
      errors << "device_id is required" if device_id.strip.empty?
      errors
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

  private def self.parse_json(body : String) : JSON::Any
    JSON.parse(body)
  rescue ex : JSON::ParseException
    raise ValidationError.new(["request body must be valid JSON"])
  end

  private def self.parse_upsert(payload : JSON::Any) : UpsertPayload
    UpsertPayload.new(
      read_string(payload, "user_id", "userId"),
      read_string(payload, "device_id", "deviceId"),
      read_string(payload, "endpoint"),
      read_string(read_hash(payload, "keys"), "auth"),
      read_string(read_hash(payload, "keys"), "p256dh")
    )
  end

  private def self.parse_delete_payload(payload : JSON::Any) : DeletePayload
    DeletePayload.new(read_string(payload, "user_id", "userId"), read_string(payload, "device_id", "deviceId"))
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
