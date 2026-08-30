# frozen_string_literal: true

require 'json'

module Amanuensis
  # Reads the vendored API contract fixture (spec/fixtures/plugin-api.v1.json
  # -- amanuensis's emitted PLUGIN_CONTRACT, see amanuensis#229) so specs can
  # resolve "which credential does this route expect" and "does this body
  # match its request shape" from the contract itself, rather than a literal
  # a spec picked on its own -- the same class of drift the ADMIN_SECRET /
  # PLUGIN_SECRET mismatch was.
  #
  # Deliberately dependency-free (no json_schemer, no Rails): the fixture's
  # schemas are TypeBox-emitted and stay flat and simple (required keys,
  # primitive types), so a small structural check covers what actually
  # matters -- has the plugin's request body drifted from what the route
  # requires -- without pinning a new gem in a repo with no local way to
  # verify it resolves cleanly against Discourse core's own bundle.
  module PluginContractFixture
    FIXTURE_PATH = File.expand_path('../fixtures/plugin-api.v1.json', __dir__)

    class UnknownRoute < StandardError; end

    def self.routes
      @routes ||= JSON.parse(File.read(FIXTURE_PATH))['routes']
    end

    # method/path name the route the same way the fixture declares it --
    # path is the fixture's own templated string (e.g.
    # '/v1/plugin/uploads/:upload_id/complete'), not a concrete URL. Callers
    # already know which route they mean, so there is no path-matching regex
    # to get wrong here.
    def self.route(method:, path:)
      routes.find { |r| r['method'] == method.to_s.upcase && r['path'] == path } ||
        raise(UnknownRoute, "#{method} #{path} is not in the vendored contract fixture")
    end

    # 'adminSecret' -> :admin, 'pluginSecret' -> :reader -- matches
    # ApiClient.admin / ApiClient.reader, the two constructors this is meant
    # to disambiguate between.
    def self.credential_for(method:, path:)
      case route(method: method, path: path)['credential']
      when 'adminSecret' then :admin
      when 'pluginSecret' then :reader
      else raise "unrecognised credential for #{method} #{path}"
      end
    end

    # Returns an array of human-readable violations; empty means the body
    # conforms (or the route declares no request schema at all).
    def self.schema_violations(method:, path:, body:)
      schema = route(method: method, path: path)['request']
      return [] if schema.nil?
      # A caller capturing a request body from a stub (e.g. one that only
      # matches on the right credential) gets nil here if the expected
      # request never happened at all -- report that as a clear violation
      # instead of crashing on transform_keys, so a missed request fails the
      # contract assertion with a readable message rather than a stack trace.
      return ["request body was missing or not an object (got #{body.class})"] unless body.is_a?(Hash)

      string_body = body.transform_keys(&:to_s)
      violations = []

      Array(schema['required']).each do |key|
        violations << "missing required field '#{key}'" unless string_body.key?(key)
      end

      schema.fetch('properties', {}).each do |key, prop|
        next unless string_body.key?(key)

        expected_type = prop['type']
        next if expected_type.nil?

        value = string_body[key]
        ok =
          case expected_type
          when 'string' then value.is_a?(String)
          when 'integer' then value.is_a?(Integer)
          when 'number' then value.is_a?(Numeric)
          when 'boolean' then [true, false].include?(value)
          else true # a type this checker doesn't model -- don't fail on it
          end

        violations << "field '#{key}' expected #{expected_type}, got #{value.class}" unless ok
      end

      violations
    end
  end
end
