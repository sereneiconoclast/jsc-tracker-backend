require_relative 'model/require_all'
require 'json'

=begin
OPERATION METADATA:
HttpVerb: POST
Path: /admin/jsc/new
=end
# Creates a new JSC and returns its number
def lambda_handler(event:, context:)
  standard_json_handling(event: event) do |input|
    # Get the next JSC ID and increment it atomically
    jsc_id = $g.increment_next_jsc!

    # Create the new JSC using the Model::Jsc class
    jsc = Model::Jsc.create!(jsc_id: jsc_id)

    # Return the created JSC information
    {
      jsc_id: jsc_id
    }
  end
end # lambda_handler
