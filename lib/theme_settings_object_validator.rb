# frozen_string_literal: true

class ThemeSettingsObjectValidator
  class << self
    def validate_objects(schema:, objects:)
      error_messages = []

      objects.each_with_index do |object, index|
        humanize_error_messages(
          self.new(schema: schema, object: object).validate,
          index:,
          error_messages:,
        )
      end

      error_messages
    end

    private

    def humanize_error_messages(errors, index:, error_messages:)
      errors.each do |property_json_pointer, error_details|
        error_messages.push(*error_details.humanize_messages("/#{index}#{property_json_pointer}"))
      end
    end
  end

  class ThemeSettingsObjectErrors
    def initialize
      @errors = []
    end

    def add_error(error, i18n_opts = {})
      @errors << ThemeSettingsObjectError.new(error, i18n_opts)
    end

    def humanize_messages(property_json_pointer)
      @errors.map { |error| error.humanize_messages(property_json_pointer) }
    end

    def full_messages
      @errors.map(&:error_message)
    end
  end
  class ThemeSettingsObjectError
    def initialize(error, i18n_opts = {})
      @error = error
      @i18n_opts = i18n_opts
    end

    def humanize_messages(property_json_pointer)
      I18n.t(
        "themes.settings_errors.objects.humanize_#{@error}",
        @i18n_opts.merge(property_json_pointer:),
      )
    end

    def error_message
      I18n.t("themes.settings_errors.objects.#{@error}", @i18n_opts)
    end
  end

  def initialize(schema:, object:, valid_category_ids: nil, json_pointer_prefix: "", errors: {})
    @object = object
    @schema_name = schema[:name]
    @properties = schema[:properties]
    @errors = errors
    @valid_category_ids = valid_category_ids
    @json_pointer_prefix = json_pointer_prefix
  end

  def validate
    validate_properties

    @properties.each do |property_name, property_attributes|
      if property_attributes[:type] == "objects"
        @object[property_name]&.each_with_index do |child_object, index|
          self
            .class
            .new(
              schema: property_attributes[:schema],
              object: child_object,
              valid_category_ids:,
              json_pointer_prefix: "#{@json_pointer_prefix}#{property_name}/#{index}/",
              errors: @errors,
            )
            .validate
        end
      end
    end

    @errors
  end

  private

  def validate_properties
    @properties.each do |property_name, property_attributes|
      next if property_attributes[:type] == "objects"
      next if property_attributes[:required] && !is_property_present?(property_name)
      next if !has_valid_property_value_type?(property_attributes, property_name)
      next if !has_valid_property_value?(property_attributes, property_name)
    end
  end

  def has_valid_property_value_type?(property_attributes, property_name)
    value = @object[property_name]
    type = property_attributes[:type]

    return true if (value.nil? && type != "enum")

    is_value_valid =
      case type
      when "string"
        value.is_a?(String)
      when "integer", "category"
        value.is_a?(Integer)
      when "float"
        value.is_a?(Float) || value.is_a?(Integer)
      when "boolean"
        [true, false].include?(value)
      when "enum"
        property_attributes[:choices].include?(value)
      else
        add_error(property_name, :invalid_type, type:)
        return false
      end

    if is_value_valid
      true
    else
      add_error(property_name, "not_valid_#{type}_value", property_attributes)
      false
    end
  end

  def has_valid_property_value?(property_attributes, property_name)
    validations = property_attributes[:validations]
    type = property_attributes[:type]
    value = @object[property_name]

    case type
    when "category"
      if !valid_category_ids.include?(value)
        add_error(property_name, :not_valid_category_value)
        return false
      end
    when "string"
      if (min = validations&.dig(:min_length)) && value.length < min
        add_error(property_name, :string_value_not_valid_min, min:)
        return false
      end

      if (max = validations&.dig(:max_length)) && value.length > max
        add_error(property_name, :string_value_not_valid_max, max:)
        return false
      end

      if validations&.dig(:url) && !value.match?(URI.regexp)
        add_error(property_name, :string_value_not_valid_url)
        return false
      end
    when "integer", "float"
      if (min = validations&.dig(:min)) && value < min
        add_error(property_name, :number_value_not_valid_min, min:)
        return false
      end

      if (max = validations&.dig(:max)) && value > max
        add_error(property_name, :number_value_not_valid_max, max:)
        return false
      end
    end

    true
  end

  def is_property_present?(property_name)
    if @object[property_name].nil?
      add_error(property_name, :required)
      false
    else
      true
    end
  end

  def add_error(property_name, key, i18n_opts = {})
    pointer = json_pointer(property_name)
    @errors[pointer] ||= ThemeSettingsObjectErrors.new
    @errors[pointer].add_error(key, i18n_opts)
  end

  def json_pointer(property_name)
    "/#{@json_pointer_prefix}#{property_name}"
  end

  def valid_category_ids
    @valid_category_ids ||=
      Set.new(
        Category.where(id: fetch_property_values_of_type(@properties, @object, "category")).pluck(
          :id,
        ),
      )
  end

  def fetch_property_values_of_type(properties, object, type)
    values = Set.new

    properties.each do |property_name, property_attributes|
      if property_attributes[:type] == type
        values << object[property_name]
      elsif property_attributes[:type] == "objects"
        object[property_name]&.each do |child_object|
          values.merge(
            fetch_property_values_of_type(
              property_attributes[:schema][:properties],
              child_object,
              type,
            ),
          )
        end
      end
    end

    values
  end
end
