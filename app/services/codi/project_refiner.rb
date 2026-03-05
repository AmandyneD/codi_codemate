# frozen_string_literal: true

require "openai"
require "json"

module Codi
  class ProjectRefiner
    def initialize(project:, chat:)
      @project = project
      @chat = chat
      @client = OpenAI::Client.new(api_key: ENV.fetch("OPENAI_API_KEY"))
    end

    def call
      raw = ask_model
      data = JSON.parse(raw)

      normalized = normalize(data)

      @chat.messages.create!(role: "assistant", content: raw)

      @project.update!(
        full_description: normalized["full_description"].presence || @project.full_description,
        tech_stack: normalized["tech_stack"],
        team_roles: normalized["team_roles"],
        objectives: normalized["objectives"],
        timeline: normalized["timeline"]
      )

      normalized
    rescue JSON::ParserError => e
      Rails.logger.warn("[CODI] refine JSON parse failed: #{e.message}")
      @chat.messages.create!(role: "assistant", content: "Désolé, je n’ai pas réussi à formater proprement la réponse. Peux-tu reformuler en 1 phrase simple ?")
      {}
    end

    private

    def ask_model
      res = @client.chat.completions.create(
        model: "gpt-4o-mini",
        temperature: 0.4,
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: context_prompt },
          { role: "user", content: "User feedback: #{last_user_message}" }
        ]
      )

      extract_content(res).tap do |content|
        raise "Empty response from model" if content.blank?
      end
    end

    def system_prompt
      <<~SYS
        You are Codi, a senior tech lead.
        You receive a project (current state) and user feedback to refine it.

        Output MUST be valid JSON ONLY (no markdown, no prose).
        JSON must include exactly these keys:
        full_description (string),
        tech_stack (array of strings),
        team_roles (array of strings),
        objectives (array of strings),
        timeline (array of strings).

        Keep it consistent with the user's constraints.
      SYS
    end

    def context_prompt
      <<~TXT
        CURRENT PROJECT:
        Title: #{@project.title}
        Category: #{@project.category}
        Level: #{@project.level}
        Duration: #{@project.duration}
        Max team members: #{@project.max_team_members}

        CURRENT OUTPUT:
        full_description: #{@project.full_description}
        tech_stack: #{Array(@project.tech_stack).join(", ")}
        team_roles: #{Array(@project.team_roles).join(", ")}
        objectives: #{Array(@project.objectives).join(", ")}
        timeline: #{Array(@project.timeline).join(", ")}

        Task:
        Update the output according to the user feedback.
        Return ONLY JSON with keys: full_description, tech_stack, team_roles, objectives, timeline.
      TXT
    end

    def last_user_message
      @chat.messages.where(role: "user").order(:created_at).last&.content.to_s
    end

    # Reprend ta logique robuste
    def extract_content(res)
      if res.respond_to?(:choices) && res.choices.respond_to?(:first)
        choice = res.choices.first
        return choice.message.content.to_s.strip if choice.respond_to?(:message) && choice.message.respond_to?(:content)
      end

      if res.respond_to?(:to_h)
        h = res.to_h
        return h.dig(:choices, 0, :message, :content).to_s.strip if h.is_a?(Hash)
      end

      if res.is_a?(Hash)
        return res.dig("choices", 0, "message", "content").to_s.strip
      end

      ""
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
  end
end
