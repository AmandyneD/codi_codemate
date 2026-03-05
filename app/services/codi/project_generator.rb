# frozen_string_literal: true

require "openai"
require "json"

module Codi
  class ProjectGenerator
    def initialize(project)
      @project = project
      @client = OpenAI::Client.new(api_key: ENV.fetch("OPENAI_API_KEY"))
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
      res = @client.chat.completions.create(
        model: "gpt-4o-mini",
        temperature: 0.7,
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: user_prompt }
        ]
      )

      content = extract_content(res)
      raise "Empty response from model" if content.blank?

      content
    end

    def repair_json(raw)
      res = @client.chat.completions.create(
        model: "gpt-4o-mini",
        temperature: 0,
        messages: [
          { role: "system", content: "Return ONLY valid JSON. No markdown, no extra text. Keys must be: full_description, tech_stack, team_roles, objectives, timeline." },
          { role: "user", content: "Fix this into valid JSON with the required keys.\n\n#{raw}" }
        ]
      )

      content = extract_content(res)
      raise "Empty response from repair" if content.blank?

      content
    end

    # ✅ Supporte les retours "objets" et "hash" selon versions du gem
    def extract_content(res)
      # objet
      if res.respond_to?(:choices) && res.choices.respond_to?(:first)
        choice = res.choices.first
        if choice.respond_to?(:message) && choice.message.respond_to?(:content)
          return choice.message.content.to_s.strip
        end
      end

      # hash (symbol keys)
      if res.respond_to?(:to_h)
        h = res.to_h
        return h.dig(:choices, 0, :message, :content).to_s.strip if h.is_a?(Hash)
      end

      # hash (string keys)
      if res.is_a?(Hash)
        return res.dig("choices", 0, "message", "content").to_s.strip
      end

      ""
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

          FALLBACK MVP scope:
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
