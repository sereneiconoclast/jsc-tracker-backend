require_relative 'model/require_all'
require 'json'

# POST /admin/jsc/new
# Creates a new JSC and returns its number
def lambda_handler(event:, context:)
  standard_json_handling(event: event) do |input|
    # Read the current next_jsc number from global state
    global = Model::Global.instance
    next_jsc_record = db.read(pk: '$next_jsc') || {}
    next_jsc = next_jsc_record['next_jsc'] || '1'

    # Create the new JSC with the current number
    jsc_record = {
      pk: "#{next_jsc}_members",
      members: [],
      created_at: Time.now.to_i.to_s,
      modified_at: Time.now.to_i.to_s,
      deactivated_at: '0'
    }

    # Write the new JSC to DynamoDB
    db.write(item: jsc_record)

    # Increment the next_jsc number
    next_jsc_record['next_jsc'] = (next_jsc.to_i + 1).to_s
    next_jsc_record['pk'] = '$next_jsc'
    next_jsc_record['created_at'] = Time.now.to_i.to_s
    next_jsc_record['modified_at'] = Time.now.to_i.to_s
    next_jsc_record['deactivated_at'] = '0'

    # Write the updated next_jsc to DynamoDB
    db.write(item: next_jsc_record)

    # Return the created JSC number
    {
      jsc_number: next_jsc
    }
  end
end # lambda_handler
