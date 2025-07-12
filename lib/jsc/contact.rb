require 'dynamo_object'

module Jsc
  class Contact < DynamoObject
    # Primary key: "#{sub}-#{contact_id}"
    field(:sub, id: true) # User's Google sub
    field(:contact_id, id: true) # e.g., "c0000"

    field(:name) { '' }
    field(:contact_info) { '' } # Markdown string
    field(:notes) { '' }        # URL string
    field(:status) { '' }       # Markdown string

    # Timestamps and deactivation handled by DynamoObject

    # Fields allowed to be updated via POST /user/{user_id}/contact/{contact_id}
    ALLOWED_IN_CONTACT_POST = %i(
      name
      contact_info
      notes
      status
    )

    class << self
      def pk(sub:, contact_id:)
        "#{sub}-#{contact_id}"
      end

      def fields_from_pk(pk)
        # pk is "#{sub}-#{contact_id}"
        if pk =~ /^(\d+)-c\d{4}$/
          sub, contact_id = pk.split('-', 2)
          { sub: sub, contact_id: contact_id }
        else
          raise "Invalid pk format for Contact: #{pk}"
        end
      end

      def read(sub:, contact_id:, ok_if_missing: false)
        check_for_nil!("sub: #{sub}, contact_id: #{contact_id}", ok_if_nil: ok_if_missing) do
          from_dynamodb(dynamodb_record: db.read(pk: pk(sub: sub, contact_id: contact_id)))
        end
      end
    end

    def pk
      @pk ||= self.class.pk(sub: sub, contact_id: contact_id)
    end

    def to_s
      "#{super} (#{name})"
    end
  end
end
