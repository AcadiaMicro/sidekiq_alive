# frozen_string_literal: true

module SidekiqAlive
  class Worker
    include Sidekiq::Worker
    sidekiq_options retry: true

    # Passing the hostname argument it's only for debugging enqueued jobs
    def perform(_hostname = SidekiqAlive.hostname)
      # Checks if custom liveness probe passes should fail or return false
      unless config.custom_liveness_probe.call
        Rails.logger.error("SidekiqAlive: failed liveness probe, returning")
        return
      end

      # Writes the liveness in Redis
      write_living_probe
      # schedules next living probe
      self.class.perform_in(config.time_to_live / 2, current_hostname)
    rescue => e
      Rails.logger.error("SidekiqAlive: exception raised: #{e}")
      raise e
    end

    def write_living_probe
      # Write liveness probe
      SidekiqAlive.store_alive_key
      # Increment ttl for current registered instance
      SidekiqAlive.register_current_instance
      # after callbacks
      begin
        config.callback.call
      rescue StandardError
        nil
      end
    end

    def current_hostname
      SidekiqAlive.hostname
    end

    def config
      SidekiqAlive.config
    end
  end
end
