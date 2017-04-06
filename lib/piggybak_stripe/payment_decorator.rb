module PiggybakStripe
  module PaymentDecorator
    extend ActiveSupport::Concern

    included do
      attr_accessor :stripe_token

      validates_presence_of :stripe_token, :on => :create
      removed_validations = [:month, :year, :payment_method_id]

      removed_validations.each do |field|
        _validators.delete field
      end

      _validate_callbacks.each do |callback|
        if callback.raw_filter.respond_to? :attributes
          removed_validations.each { |field| callback.raw_filter.attributes.delete field }
        end
      end

      define_method :process do |order|
        return true if !self.new_record?

        calculator = ::PiggybakStripe::PaymentCalculator::Stripe.new(self.payment_method)
        Stripe.api_key = calculator.secret_key
        begin
          charge = Stripe::Charge.create({
           :amount => (order.total_due * 100).to_i,
           :card => self.stripe_token,
           :currency => "aud"
          })

          self.attributes = { :transaction_id => charge.id,
                              :masked_number => charge.source.last4 }
          return true
        rescue Stripe::CardError, Stripe::InvalidRequestError => e
          self.errors.add :payment_method_id, e.message
          return false
        end
      end
    end
  end
end
