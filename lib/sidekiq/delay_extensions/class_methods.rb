# frozen_string_literal: true

require "sidekiq/delay_extensions/generic_proxy"

module Sidekiq
  module DelayExtensions
    ##
    # Adds `delay`, `delay_for` and `delay_until` methods to all Classes to offload class method
    # execution to Sidekiq.
    #
    # @example
    #   User.delay.delete_inactive
    #   Wikipedia.delay.download_changes_for(Date.today)
    #
    class DelayedClass
      include Sidekiq::Worker

      def perform(yml)
        data = YAML.load(yml, permitted_classes: [Symbol, Date, Time], aliases: true)

        if data.length == 4
          (target, method_name, args, kwargs) = data
          target.__send__(method_name, *args, **kwargs)
        else
          (target, method_name, args) = data
          target.__send__(method_name, *args)
        end
      end
    end

    module Klass
      def sidekiq_delay(options = {})
        Proxy.new(DelayedClass, self, options)
      end

      def sidekiq_delay_for(interval, options = {})
        Proxy.new(DelayedClass, self, options.merge("at" => Time.now.to_f + interval.to_f))
      end

      def sidekiq_delay_until(timestamp, options = {})
        Proxy.new(DelayedClass, self, options.merge("at" => timestamp.to_f))
      end
      alias_method :delay, :sidekiq_delay
      alias_method :delay_for, :sidekiq_delay_for
      alias_method :delay_until, :sidekiq_delay_until
    end
  end
end

Module.__send__(:include, Sidekiq::DelayExtensions::Klass) unless defined?(::Rails)
