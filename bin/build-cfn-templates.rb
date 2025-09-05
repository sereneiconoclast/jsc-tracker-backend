#!/usr/bin/env ruby
require 'pp'
require 'pathname'
require 'active_support/core_ext/string/inflections' # camelize

# Script to generate CloudFormation templates from Lambda handler metadata
#
# I considered using YAML (Psych) for this. Then you have to strip off the initial
# document separator ("---"). Assembling the raw string seems easier, frankly.
class CloudFormationTemplateBuilder
  def initialize
    @lib_dir = Pathname.new(__dir__).parent / 'lib'
    @path_to_resource = {}  # Cache for resource definitions by path
  end

  attr_accessor :debug
  alias_method :debug?, :debug

  def operations
    @operations ||= begin
      handler_files.map do |file|
        parse_operation_metadata(file.read, file.basename.to_s)
      end.compact.reduce(&:merge).tap { say("\n") }
    end
  end

  def lambda_function(operation_name)
    operation = operations[operation_name]
    raise "Operation '#{operation_name}' not found" unless operation

    function_name = "JSCTracker#{operation_name}"
    handler_name = "#{operation[:filename]}.lambda_handler"

    # Indented by 2 spaces
    <<YAML
  #{function_name}LambdaFunction:
    Type: 'AWS::Lambda::Function'
    Properties:
      FunctionName: '#{function_name}'
      Handler: '#{handler_name}'
      Role:
        !ImportValue 'jsc-tracker-dynamodb-JSCTrackerDynamoDBRoleArn'
      Code:
        S3Bucket: 'static.us-west-2.infinitequack.net'
        S3Key: 'lambda/jsc-tracker-lambda.zip'
      Runtime: ruby3.3
      Timeout: 30
      MemorySize: 128
YAML
  end

  def lambda_function_arn_stack_output(operation_name)
    operation = operations[operation_name]
    raise "Operation '#{operation_name}' not found" unless operation

    function_name = "JSCTracker#{operation_name}"

    # Indented by 2 spaces
    <<YAML
  #{function_name}LambdaFunctionArn:
    Description: 'ARN of the #{operation_name} Lambda function'
    Value: !GetAtt #{function_name}LambdaFunction.Arn
    Export:
      Name: !Sub '${AWS::StackName}-#{function_name}LambdaFunctionArn'
YAML
  end

  def main_method(operation_name)
    operation = operations[operation_name]
    raise "Operation '#{operation_name}' not found" unless operation

    method_name = "JSCTracker#{operation_name}Method"
    resource_name = resource_name_for_operation(operation_name)
    function_name = "JSCTracker#{operation_name}"

    # Build RequestParameters section
    request_params = build_request_parameters(operation)

    # Indented by 2 spaces
    out = <<YAML
  #{method_name}:
    Type: AWS::ApiGateway::Method
    Properties:
      RestApiId: !Ref JSCTrackerApi
      ResourceId: !Ref #{resource_name}
      HttpMethod: #{operation[:http_verb]}
      AuthorizationType: NONE
YAML
    out << request_params # may be empty

    # Indented by 6 spaces
    out << <<YAML
      Integration:
        Type: AWS_PROXY
        # This must be POST, per https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-apigateway-method-integration.html
        IntegrationHttpMethod: POST
        Uri: !Sub
          - "arn:aws:apigateway:us-west-2:lambda:path/2015-03-31/functions/${LambdaFunctionArn}/invocations"
          - LambdaFunctionArn: !ImportValue jsc-tracker-lambda-#{function_name}LambdaFunctionArn
YAML
    out
  end

  def options_method(operation_name)
    operation = operations[operation_name]
    raise "Operation '#{operation_name}' not found" unless operation

    method_name = "JSCTrackerOptions#{remove_verb_prefix_from_operation_name(operation_name)}Method"
    resource_name = resource_name_for_operation(operation_name)

    # Indented by 2 spaces
    <<YAML
  #{method_name}:
    Type: AWS::ApiGateway::Method
    Properties:
      RestApiId: !Ref JSCTrackerApi
      ResourceId: !Ref #{resource_name}
      HttpMethod: OPTIONS
      AuthorizationType: NONE
      RequestParameters:
        method.request.header.Origin: true
      Integration:
        Type: MOCK
        RequestTemplates:
          application/json: '{"statusCode": 200}'
        IntegrationResponses:
          - StatusCode: 200
            SelectionPattern: '.*'
            ResponseParameters:
              method.response.header.Access-Control-Allow-Origin: "'*'"
              method.response.header.Access-Control-Allow-Headers: "'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token'"
              method.response.header.Access-Control-Allow-Methods: "'GET,POST,PUT,DELETE,OPTIONS'"
              method.response.header.Access-Control-Max-Age: "'600'"
            ResponseTemplates:
              application/json: ''
      MethodResponses:
        - StatusCode: 200
          ResponseParameters:
            method.response.header.Access-Control-Allow-Origin: true
            method.response.header.Access-Control-Allow-Headers: true
            method.response.header.Access-Control-Allow-Methods: true
            method.response.header.Access-Control-Max-Age: true
          ResponseModels:
            application/json: Empty
YAML
  end

  def lambda_permission(operation_name)
    operation = operations[operation_name]
    raise "Operation '#{operation_name}' not found" unless operation

    permission_name = "JSCTrackerLambdaPermission#{operation_name}"
    function_name = "JSCTracker#{operation_name}"

    # Indented by 2 spaces
    <<YAML
  #{permission_name}:
    Type: AWS::Lambda::Permission
    Properties:
      Action: lambda:InvokeFunction
      FunctionName:
        !ImportValue 'jsc-tracker-lambda-#{function_name}LambdaFunctionArn'
      Principal: apigateway.amazonaws.com
YAML
  end

  def resource_name_for_path(path)
    return "!GetAtt JSCTrackerApi.RootResourceId" if path == "/"

    return @path_to_resource[path][:name] if @path_to_resource[path]

    # Calculate parent path
    parent_path = path.gsub(/\/[^\/]*$/, '')
    parent_path = "/" if parent_path.empty?

    # Recursively ensure parent exists
    parent_resource_name = resource_name_for_path(parent_path)

    # Generate resource name and definition
    resource_name = path_to_resource_name(path)
    path_part = path.split('/').last

    # Create resource definition
    resource_def = {
      name: resource_name,
      path: path,
      path_part: path_part,
      parent_resource_name: parent_resource_name
    }

    @path_to_resource[path] = resource_def
    resource_name
  end

  def resource_for_path(path)
    resource_name_for_path(path)  # Ensure cache is populated
    @path_to_resource[path]
  end

  def resource_definition(path)
    resource_info = resource_for_path(path)
    return nil if resource_info.nil?

    resource_name = resource_info[:name]
    path_part = resource_info[:path_part]
    parent_resource_name = resource_info[:parent_resource_name]

    # Indented by 2 spaces
    <<YAML
  #{resource_name}:
    Type: AWS::ApiGateway::Resource
    Properties:
      ParentId: #{parent_resource_name}
      PathPart: "#{path_part}"
      RestApiId: !Ref JSCTrackerApi
YAML
  end

  def lambda_template
    out = <<~YAML
      AWSTemplateFormatVersion: '2010-09-09'
      Description: 'CloudFormation template for JSCTracker Lambda functions'

      Resources:
    YAML
    out << (
      operations.keys.map(&method(:lambda_function)).join("\n")
    )

    out << "\nOutputs:\n"
    out << (
      operations.keys.map(&method(:lambda_function_arn_stack_output)).join('')
    )

    out
  end

  private

  def say(s)
    puts(s) if debug?
  end

  # Convert operation name to resource name
  # In CloudFormation, an AWS::ApiGateway::Resource is basically a path,
  # such as /user/{user_id}/contact/new
  # This method returns the name of the resource for the path where the given
  # operation_name may be reached
  # Examples: GetUserUserId -> JSCTrackerUserUserIdResource
  #           PostAdminJscNew -> JSCTrackerAdminJscNewResource
  #           GetAdminUsersSearch -> JSCTrackerAdminUsersSearchResource
  def resource_name_for_operation(operation_name)
    operation = operations[operation_name]
    raise "Operation '#{operation_name}' not found" unless operation

    resource_name_for_path(operation[:path])
  end

  def path_to_resource_name(path)
    return "RootResourceId" if path == "/"

    # Convert path to resource name
    # /user/{user_id}/contact/new -> JSCTrackerUserUserIdContactNewResource
    path_parts = path.split('/').reject(&:empty?)
    resource_name = path_parts.map do |part|
      if part.start_with?('{') && part.end_with?('}')
        # Path parameter like {user_id} -> UserUserId
        part[1..-2].split('_').map(&:capitalize).join
      else
        # Regular path part like "contact" -> Contact
        part.capitalize
      end
    end.join

    "JSCTracker#{resource_name}Resource"
  end

  # Remove the HTTP verb prefix (Get, Post, etc.)
  def remove_verb_prefix_from_operation_name(operation_name)
    operation_name.gsub(/^(Get|Post|Put|Delete|Options)/, '')
  end

  def build_request_parameters(operation)
    # Add path parameters based on the path - extract any {param_name} patterns
    path_params = operation[:path].scan(/\{([a-z0-9_]+)\}/).map(&:first).map do |path_param|
      "        method.request.path.#{path_param}: true"
    end

    # Add query parameters
    query_params = operation[:query].map do |param_name, required|
      "        method.request.querystring.#{param_name}: #{required}"
    end

    params = path_params + query_params
    return '' if params.empty?
    "      RequestParameters:\n" + params.join("\n") + "\n"
  end

  def handler_files
    @handler_files ||= begin
      say "Scanning for Lambda handler files in #{@lib_dir}..."

      @lib_dir.glob('*.rb').select do |file|
        file.read.include?('def lambda_handler')
      end.sort.tap do |found|
        if debug?
          puts "Found #{found.length} handler files:"
          found.each { |file| puts "  - #{file.basename}" }
          puts
        end
      end
    end
  end

  HTTP_VERB_PATTERN = %r!^HttpVerb:\s*([A-Z]+)$!
  PATH_PATTERN = %r!^Path:\s*(/[a-z_{}/]+)$!
  QUERY_PATTERN = %r!^Query:\s*(REQUIRED|OPTIONAL)\s+([a-z_]+)$!

  def parse_operation_metadata(content, filename)
    say "Parsing #{filename}..."

    # Extract the operation name from filename (remove .rb extension and CamelCase)
    filename = filename.gsub(/\.rb$/, '')
    operation_name = filename.camelize

    # Find the =begin / =end block
    metadata_block = content.match(/=begin\nOPERATION METADATA:\n(.*?)\n=end/m)
    return say("  ✗ No operation metadata found") unless metadata_block

    metadata_text = metadata_block[1]

    # Parse the metadata into a hash
    operation = { filename: filename, query: {} }

    metadata_text.each_line do |line|
      line = line.strip
      next if line.empty? || line.start_with?('#') # allow embedded comments

      if (verb = line.match(HTTP_VERB_PATTERN)&.match(1))
        raise "Double verb in #{metadata_text}" if operation[:http_verb]
        operation[:http_verb] = verb
      elsif (path = line.match(PATH_PATTERN)&.match(1))
        raise "Double path in #{metadata_text}" if operation[:path]
        operation[:path] = path
      elsif (m = line.match(QUERY_PATTERN))
        required = m.match(1) == 'REQUIRED'
        param_name = m.match(2)
        raise "Double param '#{param_name}' in #{metadata_text}" if operation[:query][param_name]
        operation[:query][param_name] = required
      else
        raise "Unexpected line '#{line}' in #{metadata_text}"
      end
    end

    say "  ✓ Parsed: #{operation_name} #{operation[:http_verb]} #{operation[:path]}"

    { operation_name => operation }
  end
end

# Run the script
if __FILE__ == $0
  builder = CloudFormationTemplateBuilder.new
  case ARGV[0]
  when 'operations'
    builder.debug = true
    raise "No argument expected" if ARGV[1]
    operations = builder.operations
    puts "Parsed Operations:"
    puts "=" * 50
    pp (operations)
    puts
    puts "Total operations: #{operations.size}"
  when 'template'
    case ARGV[1]
    when 'lambda'
      puts(builder.lambda_template)
    else raise "Expected 'lambda'"
    end
  when 'operation'
    case ARGV[1]
    when 'lambda'
      puts(builder.lambda_function(ARGV[2]))
    when 'output'
      puts(builder.lambda_function_arn_stack_output(ARGV[2]))
    when 'main-method'
      puts(builder.main_method(ARGV[2]))
      say(builder.resource_definition(builder.operations[ARGV[2]][:path]))
    when 'options-method'
      puts(builder.options_method(ARGV[2]))
    when 'lambda-permission'
      puts(builder.lambda_permission(ARGV[2]))
    else raise "Expected 'lambda', 'output', 'main-method', 'options-method', or 'lambda-permission'"
    end
  when 'path'
    puts(builder.resource_definition(ARGV[1]))
  else raise "Expected 'operations', 'template', 'operation', or 'path'"
  end
end
