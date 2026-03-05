# frozen_string_literal: true

require "openai"
require "json"

module Codi
  class ProjectRefiner
    def self.system_prompt
      <<~SYS
        You are Codi, a senior tech lead.
        You are refining a project spec iteratively through a chat.

        Output MUST be valid JSON ONLY (no markdown, no backticks, no prose).
        JSON must include exactly these keys:
        full_description (string),
        tech_stack (array of strings),
        team_roles (array of strings),
        objectives (array of strings),
        timeline (array of strings).

        Rules:
        - Keep existing information unless the user asks to change it.
        - If user requests tone/language changes, adjust wording but keep meaning.
        - Use concrete tech items (not vague).
        - Avoid duplicates.
      SYS
    end

    def self.seed_user_prompt(project)
      <<~TXT
        Here is the current project context:

        Title: #{project.title}
        Category: #{project.category}
        Level: #{project.level}
        Duration: #{project.duration}
        Max team members: #{project.max_team_members}
        Short description: #{project.short_description}

        Current full_description:
        #{project.full_description}

        Current tech_stack: #{Array(project.tech_stack).join(", ")}
        Current team_roles: #{Array(project.team_roles).join(", ")}
        Current objectives: #{Array(project.objectives).join(", ")}
        Current timeline: #{Array(project.timeline).join(", ")}

        From now on, the user will ask refinements. Apply them and return the updated JSON.
      TXT
    end

    def initialize(project:, chat:)
      @project = project
      @chat = chat
      @client = OpenAI::Client.new(api_key: ENV.fetch("OPENAI_API_KEY"))
    end

    def call
      res = chat_create(
        model: "gpt-4o-mini",
        temperature: 0.3,
        messages: serialized_messages
      )

      content = extract_content(res)
      raise "Empty content from OpenAI" if content.blank?

      data = JSON.parse(content)
      normalize(data)
    rescue JSON::ParserError => e
      Rails.logger.warn("[CODI][Refiner] JSON parse failed: #{e.message}")
      fallback_from_project
    rescue => e
      Rails.logger.error("[CODI][Refiner] ERROR: #{e.class} #{e.message}")
      fallback_from_project
    end

    private

    def serialized_messages
      # On prend l'historique du chat, mais on limite pour éviter de grossir à l’infini
      msgs = @chat.messages.order(:created_at).last(20).map do |m|
        { role: m.role, content: m.content.to_s }
      end

      # Si jamais le chat a été créé sans seed, on injecte le contexte
      if msgs.none? { |m| m[:role] == "system" }
        msgs.unshift({ role: "system", content: self.class.system_prompt })
      end

      msgs
    end

    def chat_create(model:, temperature:, messages:)
      params = { model: model, temperature: temperature, messages: messages }
      begin
        @client.chat.completions.create(**params, response_format: { type: "json_object" })
      rescue ArgumentError
        @client.chat.completions.create(**params)
      end
    end

    def extract_content(res)
      if res.respond_to?(:choices) && res.choices.is_a?(Array) && res.choices.first
        choice = res.choices.first
        if choice.respond_to?(:message) && choice.message
          msg = choice.message
          return msg.respond_to?(:content) ? msg.content.to_s.strip : ""
        end
        if choice.is_a?(Hash)
          return (choice.dig(:message, :content) || choice.dig("message", "content")).to_s.strip
        end
      end

      h = res.respond_to?(:to_h) ? res.to_h : res
      choices = h[:choices] || h["choices"] || []
      first = choices.first
      first = first.to_h if first.respond_to?(:to_h)
      (first.dig(:message, :content) || first.dig("message", "content")).to_s.strip
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

    def fallback_from_project
      {
        "full_description" => @project.full_description.to_s,
        "tech_stack" => Array(@project.tech_stack),
        "team_roles" => Array(@project.team_roles),
        "objectives" => Array(@project.objectives),
        "timeline" => Array(@project.timeline)
      }
    end
  end
end
