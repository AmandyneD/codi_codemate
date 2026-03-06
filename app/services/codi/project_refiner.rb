# frozen_string_literal: true

require "openai"
require "json"

module Codi
  class ProjectRefiner
    def self.system_prompt
      <<~SYS
        You are Codi, a senior tech lead refining a software project specification through chat.

        You must ALWAYS return valid JSON only.
        No markdown.
        No prose outside JSON.
        No backticks.

        Your JSON must contain exactly these keys:
        - full_description (string)
        - tech_stack (array of strings)
        - team_roles (array of strings)
        - objectives (array of strings)
        - timeline (array of strings)

        Critical rules:
        - You are given the CURRENT complete project state.
        - You must always return the FULL updated project spec, not only the changed field.
        - Never remove existing information unless the user explicitly asks to remove or replace it.
        - If the user asks to add one technology, keep the rest of the stack.
        - If the user asks to refine one section, preserve all other sections.
        - Avoid duplicates.
        - Keep output concrete, realistic, and presentation-ready.
        - If a field is not mentioned by the user, keep it as-is.
      SYS
    end

    def self.seed_user_prompt(project)
      <<~TXT
        CURRENT PROJECT STATE

        Title: #{project.title}
        Category: #{project.category}
        Level: #{project.level}
        Duration: #{project.duration}
        Max team members: #{project.max_team_members}
        Short description: #{project.short_description}

        CURRENT full_description:
        #{project.full_description}

        CURRENT tech_stack:
        #{Array(project.tech_stack).join(", ")}

        CURRENT team_roles:
        #{Array(project.team_roles).join(", ")}

        CURRENT objectives:
        #{Array(project.objectives).join(", ")}

        CURRENT timeline:
        #{Array(project.timeline).join(", ")}

        The next user message is a refinement request.
        Return the FULL UPDATED JSON specification.
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
        temperature: 0.2,
        messages: serialized_messages
      )

      content = extract_content(res)
      raise "Empty content from OpenAI" if content.blank?

      data = JSON.parse(content)
      normalize_and_fill_missing(data)
    rescue JSON::ParserError => e
      Rails.logger.warn("[CODI][Refiner] JSON parse failed: #{e.message}")
      fallback_from_project
    rescue StandardError => e
      Rails.logger.error("[CODI][Refiner] ERROR: #{e.class} #{e.message}")
      fallback_from_project
    end

    private

    def serialized_messages
      history = @chat.messages.order(:created_at).last(12).map do |m|
        { role: m.role, content: m.content.to_s }
      end

      latest_user_message = history.reverse.find { |m| m[:role] == "user" }

      [
        { role: "system", content: self.class.system_prompt },
        { role: "user", content: self.class.seed_user_prompt(@project) },
        latest_user_message || { role: "user", content: "Keep the current project state unchanged and return the full JSON." }
      ]
    end

    def chat_create(model:, temperature:, messages:)
      params = {
        model: model,
        temperature: temperature,
        messages: messages
      }

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

    def normalize_and_fill_missing(data)
      full_description = clean_text(data["full_description"])
      tech_stack = clean_array(data["tech_stack"])
      team_roles = clean_array(data["team_roles"])
      objectives = clean_array(data["objectives"])
      timeline = clean_array(data["timeline"])

      {
        "full_description" => full_description.presence || @project.full_description.to_s,
        "tech_stack" => tech_stack.presence || Array(@project.tech_stack),
        "team_roles" => team_roles.presence || Array(@project.team_roles),
        "objectives" => objectives.presence || Array(@project.objectives),
        "timeline" => timeline.presence || Array(@project.timeline)
      }
    end

    def clean_text(value)
      value.to_s.strip
    end

    def clean_array(value)
      Array(value).map(&:to_s).map(&:strip).reject(&:empty?).uniq
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
