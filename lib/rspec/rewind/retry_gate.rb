# frozen_string_literal: true

module RSpec
  module Rewind
    RetryGateDecision = Struct.new(
      :allowed,
      :reason,
      :policy_decision,
      :budget_decision,
      keyword_init: true
    ) do
      def allowed?
        allowed
      end
    end

    class RetryGate
      def initialize(configuration:, retry_policy:, debug:)
        @configuration = configuration
        @retry_policy = retry_policy
        @debug = debug
      end

      def allow?(
        exception:,
        retry_number:,
        resolved_retries:,
        retry_on:,
        skip_retry_on:,
        retry_if:,
        example_id:,
        elapsed_time: nil,
        sleep_total: nil
      )
        decision(
          exception: exception,
          retry_number: retry_number,
          resolved_retries: resolved_retries,
          retry_on: retry_on,
          skip_retry_on: skip_retry_on,
          retry_if: retry_if,
          example_id: example_id,
          elapsed_time: elapsed_time,
          sleep_total: sleep_total
        ).allowed?
      end

      def decision(
        exception:,
        retry_number:,
        resolved_retries:,
        retry_on:,
        skip_retry_on:,
        retry_if:,
        example_id:,
        elapsed_time: nil,
        sleep_total: nil
      )
        return rejected(:retries_exhausted) unless retry_number <= resolved_retries
        return rejected(:max_elapsed_time_exceeded) if exceeded?(@configuration.max_elapsed_time, elapsed_time)
        return rejected(:max_total_sleep_exceeded) if exceeded?(@configuration.max_total_sleep, sleep_total)

        policy_decision = @retry_policy.decision(
          exception: exception,
          retry_on: retry_on,
          skip_retry_on: skip_retry_on,
          retry_if: retry_if,
          retry_number: retry_number,
          resolved_retries: resolved_retries,
          budget_remaining: budget_remaining,
          elapsed_time: elapsed_time,
          sleep_total: sleep_total
        )
        return rejected(policy_decision.reason, policy_decision: policy_decision) unless policy_decision.allowed?

        return rejected(:dry_run, policy_decision: policy_decision) if @configuration.dry_run

        budget_decision = consume_budget
        return allowed(policy_decision: policy_decision, budget_decision: budget_decision) if budget_decision.allowed?

        debug("retry budget exhausted for #{example_id}")
        rejected(:budget_exhausted, policy_decision: policy_decision, budget_decision: budget_decision)
      end

      private

      def allowed(policy_decision: nil, budget_decision: nil)
        RetryGateDecision.new(
          allowed: true,
          reason: :allowed,
          policy_decision: policy_decision,
          budget_decision: budget_decision
        )
      end

      def rejected(reason, policy_decision: nil, budget_decision: nil)
        RetryGateDecision.new(
          allowed: false,
          reason: reason,
          policy_decision: policy_decision,
          budget_decision: budget_decision
        )
      end

      def consume_budget
        budget = @configuration.retry_budget
        return budget.consume if budget.respond_to?(:consume)

        allowed = budget.consume!
        BudgetDecision.new(
          allowed: allowed,
          limit: read_budget_value(budget, :limit),
          used: read_budget_value(budget, :used),
          remaining: read_budget_value(budget, :remaining)
        )
      end

      def budget_remaining
        read_budget_value(@configuration.retry_budget, :remaining)
      end

      def read_budget_value(budget, field)
        return budget.public_send(field) if budget.respond_to?(field)

        nil
      end

      def exceeded?(limit, value)
        !limit.nil? && !value.nil? && value >= limit
      end

      def debug(message)
        @debug.call(message)
      end
    end
  end
end
