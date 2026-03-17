module Crumble::Web::Push::Server::Integration
  enum SendOutcomeStatus
    Sent
    InvalidSubscription
    Failed
  end

  record SendOutcome, subscription : Subscription, status : SendOutcomeStatus, status_code : Int32?, error_message : String? do
    def sent? : Bool
      status.sent?
    end

    def invalid_subscription? : Bool
      status.invalid_subscription?
    end

    def cleanup? : Bool
      invalid_subscription?
    end

    def failed? : Bool
      status.failed?
    end
  end

  class Sender(ClientType)
    INVALID_SUBSCRIPTION_STATUS_CODES = [404, 410] of Int32

    def initialize(@adapter : SubscriptionAdapter, @client : ClientType)
    end

    def send_to_user(user_id : String, payload, **send_options) : Array(SendOutcome)
      send_subscriptions(@adapter.list_by_user(user_id), payload, **send_options)
    end

    def send_to_device(device_id : String, payload, **send_options) : Array(SendOutcome)
      send_subscriptions(@adapter.list_by_device(device_id), payload, **send_options)
    end

    def send_subscriptions(subscriptions : Enumerable(Subscription), payload, **send_options) : Array(SendOutcome)
      outcomes = [] of SendOutcome
      subscriptions.each { |subscription| outcomes << send_subscription(subscription, payload, **send_options) }
      outcomes
    end

    def send_subscription(subscription : Subscription, payload, **send_options) : SendOutcome
      normalize_success(subscription, @client.send(subscription, payload, **send_options))
    rescue ex
      normalize_failure(subscription, ex)
    end

    # Normalize HTTP-ish status codes without coupling the facade to any specific
    # response/error class from the underlying web-push client.
    private def normalize_success(subscription : Subscription, response) : SendOutcome
      status_code = status_code(response)
      return SendOutcome.new(subscription: subscription, status: SendOutcomeStatus::InvalidSubscription, status_code: status_code, error_message: nil) if invalid_subscription_status_code?(status_code)
      return SendOutcome.new(subscription: subscription, status: SendOutcomeStatus::Failed, status_code: status_code, error_message: nil) if status_code && !successful_status_code?(status_code)
      SendOutcome.new(subscription: subscription, status: SendOutcomeStatus::Sent, status_code: status_code, error_message: nil)
    end

    private def normalize_failure(subscription : Subscription, error : Exception) : SendOutcome
      status_code = status_code(error)
      SendOutcome.new(subscription: subscription, status: invalid_subscription_status_code?(status_code) ? SendOutcomeStatus::InvalidSubscription : SendOutcomeStatus::Failed, status_code: status_code, error_message: error.message)
    end

    private def status_code(value) : Int32?
      return nil unless value.responds_to?(:status_code)
      return nil unless value.status_code.responds_to?(:to_i)
      value.status_code.to_i
    end

    private def invalid_subscription_status_code?(status_code : Int32?) : Bool
      status_code ? INVALID_SUBSCRIPTION_STATUS_CODES.includes?(status_code) : false
    end

    private def successful_status_code?(status_code : Int32) : Bool
      status_code >= 200 && status_code < 300
    end
  end
end
