# frozen_string_literal: true

require_relative './id'
require 'ddtrace'
require 'logger'
require 'pp'

DD_AGENT_HOST = ENV['DD_AGENT_HOST']
DD_AGENT_PORT = ENV['DD_AGENT_PORT']

Datadog.configure do |c|
  c.agent.host = DD_AGENT_HOST
  c.agent.port = DD_AGENT_PORT

  c.logger.instance = Logger.new($stdout)
  c.logger.level = ::Logger::DEBUG

  c.tracing.sampler = Datadog::Tracing::Sampling::RateSampler.new(1.0)
  c.diagnostics.startup_logs.enabled = false
end

REPO = 'repo'
PR_NUM = 2111

id = ZenGithub::Id.generate(REPO, PR_NUM)

trace_digest = Datadog::Tracing::TraceDigest.new(
  span_id: id,
  span_name: 'pr',
  span_resource: 'pr',
  span_service: 'z-github-pr',
  trace_id: id,
  trace_name: 'pr',
  trace_resource: 'pr',
  trace_service: 'z-github-pr',
  trace_process_id: Random.new.rand(50_000),
  trace_runtime_id: Datadog::Core::Environment::Identity.id,
  trace_sampling_priority: 1
)

# Monkey Patch
module Datadog
  module Tracing
    class SpanOperation
      def change_id(id)
        @id = id
        @trace_id = id
      end
    end
  end
end

start = Datadog::Core::Utils::Time.now.utc

Datadog::Tracing.trace('unit-tests',
                       continue_from: trace_digest,
                       service: 'z-github-workflow',
                       resource: 'unit-tests') do |span, _trace|
  sleep rand(5)
  span.set_tag('repository', REPO)
  span.set_tag('pr_num', PR_NUM)
end

sleep rand(5)

Datadog::Tracing.trace('build-image',
                       continue_from: trace_digest,
                       service: 'z-github-workflow',
                       resource: 'build-image') do |span, _trace|
  sleep rand(5)
  span.set_tag('repository', REPO)
  span.set_tag('pr_num', PR_NUM)
end

span = Datadog::Tracing.trace('pr',
                              service: 'z-github-pr',
                              resource: 'z-github-pr',
                              start_time: start,
                              tags: { "repository": REPO, "pr_num": PR_NUM })
# Patch
span.change_id(id)
span.finish(Datadog::Core::Utils::Time.now.utc)
