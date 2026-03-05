# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Codi
  class ProjectGenerator
    def initialize(project)
      @project = project
      @token = ENV.fetch("GITHUB_TOKEN")
      @base  = ENV.fetch("AI_API_BASE", "https://models.inference.ai.azure.com")
    end

    def call
      raw = ask_model
      Rails.logger.info("[CODI] RAW:\n#{raw}")

      data = JSON.parse(raw)
      normalize(data)
    rescue JSON::ParserError => e
      Rails.logger.warn("[CODI] JSON parse failed: #{e.message}")

      repaired = repair_json(raw)
      Rails.logger.info("[CODI] REPAIRED:\n#{repaired}")

      data = JSON.parse(repaired)
      normalize(data)
    rescue => e
      Rails.logger.error("[CODI] ERROR: #{e.class} #{e.message}")
      fallback_payload
    end

    private

    def ask_model
      payload = {
        model: "gpt-4o-mini",
        temperature: 0.7,
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: user_prompt }
        ]
      }

      res = post_chat(payload)
      res.fetch("choices").dig(0, "message", "content").to_s.strip
    end

    def repair_json(raw)
      payload = {
        model: "gpt-4o-mini",
        temperature: 0,
        messages: [
          {
            role: "system",
            content: "Return ONLY valid JSON. No markdown, no extra text. Keys must be: full_description, tech_stack, team_roles, objectives, timeline."
          },
          { role: "user", content: "Fix this into valid JSON with the required keys.\n\n#{raw}" }
        ]
      }

      res = post_chat(payload)
      res.fetch("choices").dig(0, "message", "content").to_s.strip
    end

    def post_chat(payload)
      url = URI.join(@base.end_with?("/") ? @base : "#{@base}/", "v1/chat/completions")

      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = (url.scheme == "https")

      req = Net::HTTP::Post.new(url)
      req["Content-Type"]  = "application/json"
      req["Authorization"] = "Bearer #{@token}"
      req.body = JSON.generate(payload)

      resp = http.request(req)
      body = resp.body.to_s

      unless resp.is_a?(Net::HTTPSuccess)
        raise "GitHub Models error #{resp.code}: #{body}"
      end

      JSON.parse(body)
    end

    def system_prompt
      <<~SYS
        You are Codi, a senior tech lead.
        Output MUST be valid JSON ONLY (no markdown, no backticks, no prose).
        JSON must include exactly these keys:
        full_description (string),
        tech_stack (array of strings),
        team_roles (array of strings),
        objectives (array of strings),
        timeline (array of strings).
      SYS
    end

    def user_prompt
      <<~TXT
        INPUT:
        Title: #{@project.title}
        Category: #{@project.category}
        Level: #{@project.level}
        Duration: #{@project.duration}
        Max team members: #{@project.max_team_members}
        Short description: #{@project.short_description}
        Full description: #{@project.full_description}

        Requirements:
        - Rewrite full_description in a structured way (sections + bullet points).
        - tech_stack: 5-10 concrete items (frameworks, DB, auth, hosting, testing).
        - team_roles: 3-8 roles.
        - objectives: 4-8 concrete objectives.
        - timeline: 4-8 phases, week-based if possible.

        Return ONLY JSON with keys:
        full_description, tech_stack, team_roles, objectives, timeline
      TXT
    end

    def normalize(data)
      {
        "full_description" => data["full_description"].to_s,
        "tech_stack" => Array(data["tech_stack"]).map(&:to_s).map(&:strip).reject(&:empty?),
        "team_roles" => Array(data["team_roles"]).map(&:to_s).map(&:strip).reject(&:empty?),
        "objectives" => Array(data["objectives"]).map(&:to_s).map(&:strip).reject(&:empty?),
        "timeline" => Array(data["timeline"]).map(&:to_s).map(&:strip).reject(&:empty?)
      }
    end

    def fallback_payload
      {
        "full_description" => <<~DESC.strip,
          #{(@project.full_description.presence || @project.short_description)}

          MVP scope:
          - User onboarding + profile
          - Core catalog & search
          - Order / booking flow
          - Admin backoffice
          - Deployment + monitoring
        DESC
        "tech_stack" => [ "Ruby on Rails", "PostgreSQL", "Redis", "Sidekiq", "Bootstrap", "Hotwire", "RSpec", "Heroku" ],
        "team_roles" => [ "Product Owner", "Backend Developer (Rails)", "Frontend Developer", "UX/UI Designer", "QA/Tester" ],
        "objectives" => [
          "Define MVP and user journeys",
          "Build core domain models & CRUD",
          "Implement authentication + roles",
          "Implement main workflow (order/booking)",
          "Deploy to production with monitoring"
        ],
        "timeline" => [
          "Week 1: Setup, DB schema, auth, core models",
          "Week 2: Core features + UI",
          "Week 3: Workflow end-to-end + background jobs",
          "Week 4: Tests, polish, deploy, demo"
        ]
      }
    end
  end
end
