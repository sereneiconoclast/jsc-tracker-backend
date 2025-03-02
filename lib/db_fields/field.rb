require 'reverse_markdown' # Convert HTML to Markdown

module DbFields
  class Field
    def initialize(
      owner:, name:, label:,
      text_field_class:, # normally JobSlog::InputField
      html_element_type:, # for rendering as 'text': :span, :link, :pre, :markdown
      &default_value
    )
      default_value ||= -> { nil }
      @owner, @name, @label, @default_value, @text_field_class, @html_element_type =
        owner, name, label, default_value, text_field_class, html_element_type
      raise "Needs an owner" unless owner
      raise "Needs a name" unless name
      raise "#{self}: Unknown html_element_type #{html_element_type}" unless
        [:span, :link, :pre, :markdown].include? @html_element_type
      @link = (html_element_type == :link)
      @mailto = link? && name == :email # This is pretty specific
    end

    # true for fields we do not store in DynamoDB: ID fields and
    # the pk field
    def metadata?
      false
    end

    def normal?
      !metadata?
    end

    # true for ID fields
    def id?
      false
    end

    def link?
      @link
    end

    def mailto?
      @mailto
    end

    def markdown?
      html_element_type == :markdown
    end

    attr_reader :owner, :name, :label, :text_field_class, :html_element_type

    def raw_default_value
      @default_value
    end

    def default_value
      @default_value.call
    end

    def define_accessor
      owner.attr_accessor name
    end

    # True for everything except the pk field
    def writable?
      true
    end

    def validate!(obj)
    end

    def from_dynamodb(dval)
      strip_if_string(dval)
    end

    def to_dynamodb(val)
      strip_if_string(val)
    end

    def strip_if_string(s)
      s.respond_to?(:strip) ? s.strip : s
    end

    def to_html_id(obj)
      "#{html_element_type}_#{obj.to_html_id}_#{name}"
    end

    def to_href(val)
      raise "#{self}: Not a link" unless link?
      mailto? ? "mailto:#{val}" : val
    end

    # Parse input from the user
    def from_user_input(s)
      markdown? ? convert_html_to_markdown(s) : s
    end

    # Pull the value of this field from 'obj' and render as non-editable HTML
    # This is either a link, or something like a span tag
    def to_html(obj)
      val = obj.public_send(name)
      # E.g.: span_company_5_street_address_1
      html_id = to_html_id(obj)
      if markdown?
        %Q{<div class="markdown-box" id="#{html_id}">#{$markdown.render(val)}</div>}
      elsif link?
        %Q{<a id="#{html_id}" href="#{to_href(val)}">#{to_inner_html(val)}</a>}
      else
        %Q{<#{html_element_type} id="#{html_id}">#{to_inner_html(val)}</#{html_element_type}>}
      end
    end

    # Most elements are rendered as-is
    # We do markdown interpretation here if the field calls for that
    def to_inner_html(val)
      markdown? ? $markdown.render(val) : val
    end

    def to_text_field(obj)
      raise "Illegal for #{self}" unless text_field_class
      text_field_class.new(
        name: name,
        label: label,
        # input_company_3_job_posting_3002_text
        id: "#{text_field_class.to_id_prefix}_#{obj.to_html_id}_#{name}",
        value: obj.public_send(name)
      )
    end

    def to_s
      "#{owner}##{name}"
    end

    ############################### REVERSE MARKDOWN ##############################

    def convert_html_to_markdown(str)
      str.gsub(%r{<JobSlog convertHtmlToMarkdown>(.*?)</JobSlog convertHtmlToMarkdown>}) do |_|
        ReverseMarkdown.convert($1)
      end
    end

  end
end
